# -*- coding: utf-8 -*-
"""基于Redis的股票API接口"""

from fastapi import APIRouter, Depends, HTTPException, Query
from typing import Dict, Any, List, Optional
from datetime import datetime
import json
import asyncio
from pydantic import BaseModel

from app.core.redis_client import get_redis_client
from app.api.dependencies import verify_token
from app.core.logging import logger
from app.services.stock.redis_stock_service import get_stock_history

router = APIRouter(tags=["股票数据"])

# 定义响应模型
class StockHistoryData(BaseModel):
    trade_date: str
    open: float
    high: float
    low: float
    close: float
    volume: Optional[float] = 0
    amount: Optional[float] = 0

class StockHistoryResponse(BaseModel):
    stock_code: str
    data: List[StockHistoryData]
    total: int

@router.get("/api/stocks", summary="获取所有股票清单", dependencies=[Depends(verify_token)])
async def get_stocks_list() -> Dict[str, Any]:
    """
    从Redis获取所有股票清单（不分页，一次性返回所有数据）
        
    Returns:
        所有股票清单及总数
    """
    redis_client = None
    try:
        # 获取Redis连接 - 每次请求都重新获取，确保在正确的事件循环中
        redis_client = await get_redis_client()
        
        # 获取股票代码数据
        stock_codes_key = "stocks:codes:all"
        stock_codes_data = await redis_client.get(stock_codes_key)
        
        if not stock_codes_data:
            raise HTTPException(status_code=500, detail="股票代码数据不可用")
        
        stock_codes = json.loads(stock_codes_data)
        total = len(stock_codes)
        
        logger.info(f"一次性返回所有股票数据，共 {total} 只股票")
        
        return {
            "total": total,
            "returned": total,
            "stocks": stock_codes,
            "timestamp": datetime.now().isoformat()
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取股票清单失败: {str(e)}")
        raise HTTPException(status_code=500, detail=f"获取股票清单失败: {str(e)}")

@router.get("/api/stocks/search", summary="股票搜索", dependencies=[Depends(verify_token)])
async def search_stocks(
    keyword: str = Query(..., description="搜索关键词(代码或名称)"),
    limit: int = Query(50, description="返回数量限制，最大200")
) -> Dict[str, Any]:
    """
    根据关键词搜索股票
    
    Args:
        keyword: 搜索关键词
        limit: 返回数量限制
        
    Returns:
        匹配的股票列表
    """
    redis_client = None
    try:
        # 限制返回数量
        limit = min(limit, 200)
        
        # 获取Redis连接 - 每次请求都重新获取，确保在正确的事件循环中
        redis_client = await get_redis_client()
        
        # 获取股票代码数据
        stock_codes_key = "stocks:codes:all"
        stock_codes_data = await redis_client.get(stock_codes_key)
        
        if not stock_codes_data:
            raise HTTPException(status_code=500, detail="股票代码数据不可用")
        
        stock_codes = json.loads(stock_codes_data)
        
        # 搜索匹配的股票
        keyword_lower = keyword.lower()
        matched_stocks = []
        
        for stock in stock_codes:
            ts_code = stock.get('ts_code', '').lower()
            name = stock.get('name', '').lower()
        
            # 精确匹配优先
            if ts_code == keyword_lower:
                matched_stocks.insert(0, stock)
            elif name == keyword_lower:
                matched_stocks.insert(0, stock)
            # 前缀匹配次优先
            elif ts_code.startswith(keyword_lower):
                matched_stocks.append(stock)
            # 包含匹配最后
            elif keyword_lower in ts_code or keyword_lower in name:
                matched_stocks.append(stock)
            
            # 达到限制数量就停止
            if len(matched_stocks) >= limit:
                break
        
        return {
            "keyword": keyword,
            "total": len(matched_stocks),
            "limit": limit,
            "stocks": matched_stocks[:limit],
            "timestamp": datetime.now().isoformat()
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"搜索股票失败: {str(e)}")
        raise HTTPException(status_code=500, detail=f"搜索股票失败: {str(e)}")

@router.get("/api/stocks/history", 
           response_model=StockHistoryResponse, 
           summary="获取股票历史数据", 
           dependencies=[Depends(verify_token)])
async def get_stock_history_data(
    stock_code: str = Query(..., description="股票代码")
) -> StockHistoryResponse:
    """
    获取指定股票的历史行情数据（从Redis缓存或实时获取）
    保持与原有接口相同的响应格式
    """
    try:
        logger.info(f"获取股票 {stock_code} 的历史数据")
        
        # 首先尝试从Redis缓存获取
        from app.services.scheduler.stock_scheduler import STOCK_KEYS
        
        # 构造ts_code
        if stock_code.startswith('6'):
            ts_code = f"{stock_code}.SH"
        elif stock_code.startswith(('43', '83', '87', '88')):
            ts_code = f"{stock_code}.BJ"
        else:
            ts_code = f"{stock_code}.SZ"
        
        cache_key = STOCK_KEYS['stock_kline'].format(ts_code)
        
        # 使用同步Redis客户端获取缓存数据
        from app.db.session import RedisCache
        redis_cache = RedisCache()
        cached_data = redis_cache.get_cache(cache_key)
        
        if cached_data:
            # 转换缓存数据格式
            history_data = []
            
            # 检查数据类型，如果是字符串则解析为JSON
            if isinstance(cached_data, str):
                try:
                    cached_data = json.loads(cached_data)
                except json.JSONDecodeError:
                    logger.error(f"缓存数据JSON解析失败: {cached_data}")
                    cached_data = None
            
            # 处理不同的数据格式
            if cached_data:
                kline_data = None
                
                if isinstance(cached_data, list):
                    # 原始list格式（初始历史数据）
                    logger.info(f"处理list格式的K线数据，共 {len(cached_data)} 条")
                    kline_data = cached_data
                elif isinstance(cached_data, dict):
                    # 新的dict格式（实时更新后的格式）
                    logger.info(f"处理dict格式的K线数据")
                    kline_data = cached_data.get('data', [])
                    logger.info(f"从dict中提取data字段，共 {len(kline_data)} 条")
                else:
                    logger.warning(f"未知的缓存数据格式: {type(cached_data)}")
                    cached_data = None
                
                # 转换K线数据为API响应格式
                if kline_data:
                    for item in kline_data:
                        # 确保item是字典类型
                        if isinstance(item, dict):
                            # 智能字段映射：处理tushare和akshare的不同格式
                            trade_date_value = ''
                            volume_value = 0.0
                            
                            # 处理日期字段
                            if 'trade_date' in item:
                                # tushare格式：20250102
                                trade_date_raw = str(item['trade_date'])
                                if len(trade_date_raw) == 8:
                                    trade_date_value = f"{trade_date_raw[:4]}-{trade_date_raw[4:6]}-{trade_date_raw[6:8]}"
                                else:
                                    trade_date_value = trade_date_raw
                            elif 'date' in item:
                                # akshare格式：2025-01-02
                                trade_date_value = str(item['date'])
                            elif 'actual_trade_date' in item:
                                # 实际交易日期
                                trade_date_value = str(item['actual_trade_date'])[:10]
                            
                            # 处理成交量字段
                            if 'vol' in item:
                                # tushare格式：vol (单位：手，需要乘以100)
                                vol_raw = float(item['vol']) if item['vol'] else 0
                                volume_value = vol_raw * 100 if vol_raw > 0 else 0
                            elif 'volume' in item:
                                # akshare格式：volume (单位：股)
                                volume_value = float(item['volume']) if item['volume'] else 0
                            
                            # 处理成交额字段
                            amount_value = 0.0
                            if 'amount' in item:
                                # tushare格式：amount (单位：千元，需要乘以1000)
                                amount_raw = float(item['amount']) if item['amount'] else 0
                                # 如果金额小于1000000，认为是千元单位，需要乘以1000
                                if amount_raw > 0 and amount_raw < 1000000:
                                    amount_value = amount_raw * 1000
                                else:
                                    amount_value = amount_raw
                            
                            history_data.append(StockHistoryData(
                                trade_date=trade_date_value,
                                open=float(item.get('open', 0)),
                                high=float(item.get('high', 0)),
                                low=float(item.get('low', 0)),
                                close=float(item.get('close', 0)),
                                volume=volume_value,
                                amount=amount_value
                            ))
                        else:
                            logger.warning(f"缓存数据项格式错误: {type(item)} - {item}")
                else:
                    logger.warning(f"无法从缓存中提取K线数据")
                    cached_data = None
            
            # 只有当成功解析到历史数据时才返回缓存结果
            if history_data:
                logger.info(f"从Redis缓存获取到股票{stock_code} 的{len(history_data)} 条历史数据")
                
                return StockHistoryResponse(
                    stock_code=stock_code,
                    data=history_data,
                    total=len(history_data)
                )
            else:
                logger.warning(f"缓存数据为空或格式错误，将实时获取股票 {stock_code} 的历史数据")
        
        # 如果缓存中没有数据，实时获取
        logger.info(f"缓存中没有数据，实时获取股票 {stock_code} 的历史数据")
        
        history_result = get_stock_history(stock_code, days=180)
        
        if 'error' in history_result:
            raise HTTPException(status_code=500, detail=history_result['error'])
        
        # 转换数据格式
        history_data = []
        for item in history_result.get('data', []):
            # 智能字段映射：处理tushare和akshare的不同格式
            trade_date_value = ''
            volume_value = 0.0
            
            # 处理日期字段
            if 'trade_date' in item:
                # tushare格式：20250102
                trade_date_raw = str(item['trade_date'])
                if len(trade_date_raw) == 8:
                    trade_date_value = f"{trade_date_raw[:4]}-{trade_date_raw[4:6]}-{trade_date_raw[6:8]}"
                else:
                    trade_date_value = trade_date_raw
            elif 'date' in item:
                # akshare格式：2025-01-02
                trade_date_value = str(item['date'])
            elif 'actual_trade_date' in item:
                # 实际交易日期
                trade_date_value = str(item['actual_trade_date'])[:10]
            
            # 处理成交量字段
            if 'vol' in item:
                # tushare格式：vol (单位：手，需要乘以100)
                vol_raw = float(item['vol']) if item['vol'] else 0
                volume_value = vol_raw * 100 if vol_raw > 0 else 0
            elif 'volume' in item:
                # akshare格式：volume (单位：股)
                volume_value = float(item['volume']) if item['volume'] else 0
            
            # 处理成交额字段
            amount_value = 0.0
            if 'amount' in item:
                # tushare格式：amount (单位：千元，需要乘以1000)
                amount_raw = float(item['amount']) if item['amount'] else 0
                # 如果金额小于1000000，认为是千元单位，需要乘以1000
                if amount_raw > 0 and amount_raw < 1000000:
                    amount_value = amount_raw * 1000
                else:
                    amount_value = amount_raw
            
            history_data.append(StockHistoryData(
                trade_date=trade_date_value,
                open=float(item.get('open', 0)),
                high=float(item.get('high', 0)),
                low=float(item.get('low', 0)),
                close=float(item.get('close', 0)),
                volume=volume_value,
                amount=amount_value
            ))
        
        # 缓存数据
        if history_data:
            redis_cache.set_cache(cache_key, history_result.get('data', []), ttl=86400)  # 缓存1天
        
        logger.info(f"实时获取到股票{stock_code} 的{len(history_data)} 条历史数据")
        
        return StockHistoryResponse(
            stock_code=stock_code,
            data=history_data,
            total=len(history_data)
        )
        
    except Exception as e:
        logger.error(f"获取股票历史数据失败: {str(e)}")
        raise HTTPException(status_code=500, detail=f"获取股票历史数据失败: {str(e)}") 