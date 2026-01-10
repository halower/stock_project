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

class StockPriceData(BaseModel):
    """股票价格数据"""
    code: str
    name: Optional[str] = None
    price: Optional[float] = None
    change: Optional[float] = None
    change_percent: Optional[float] = None  # 前端期望的字段名是 change_percent
    volume: Optional[float] = None  # 添加成交量字段
    error: Optional[str] = None

class BatchPriceResponse(BaseModel):
    """批量价格响应"""
    success: bool
    total: int
    data: List[StockPriceData]
    timestamp: str

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
        from app.api.data_validation import STOCK_KEYS
        
        # 构造ts_code
        if stock_code.startswith('6'):
            ts_code = f"{stock_code}.SH"
        elif stock_code.startswith('5'):
            # 5开头是上海ETF（如510300、512880、560050）
            ts_code = f"{stock_code}.SH"
        elif stock_code.startswith(('43', '83', '87', '88', '92')):
            # 北交所：43、83、87、88开头是股票，92开头是指数
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


@router.get("/api/stocks/batch-price",
           response_model=BatchPriceResponse,
           summary="批量获取股票最新价格",
           dependencies=[Depends(verify_token)])
async def get_batch_stock_price(
    codes: str = Query(..., description="股票代码列表，逗号分隔，如: 000001,600000,300001")
) -> BatchPriceResponse:
    """
    批量获取股票最新价格
    
    优先从Redis缓存获取，如果没有则实时从Tushare获取
    
    Args:
        codes: 股票代码列表，逗号分隔
    
    Returns:
        批量价格数据
    """
    try:
        # 解析股票代码列表
        code_list = [code.strip() for code in codes.split(',') if code.strip()]
        
        if not code_list:
            raise HTTPException(status_code=400, detail="股票代码列表不能为空")
        
        if len(code_list) > 100:
            raise HTTPException(status_code=400, detail="单次最多查询100只股票")
        
        logger.info(f"批量获取 {len(code_list)} 只股票的价格: {code_list}")
        
        # 使用Redis缓存获取数据
        from app.db.session import RedisCache
        redis_cache = RedisCache()
        
        result_data = []
        codes_need_realtime = []  # 需要实时获取的股票代码
        
        for code in code_list:
            try:
                # 构造ts_code
                if code.startswith('6'):
                    ts_code = f"{code}.SH"
                elif code.startswith('5'):
                    # 5开头是上海ETF（如510300、512880、560050）
                    ts_code = f"{code}.SH"
                elif code.startswith(('43', '83', '87', '88', '92')):
                    # 北交所：43、83、87、88开头是股票，92开头是指数
                    ts_code = f"{code}.BJ"
                else:
                    ts_code = f"{code}.SZ"
                
                # 从Redis获取K线数据
                cache_key = f"stock_trend:{ts_code}"
                cached_data = redis_cache.get_cache(cache_key)
                
                if not cached_data:
                    # 记录需要实时获取的股票
                    codes_need_realtime.append((code, ts_code))
                    continue
                
                # 解析缓存数据
                kline_data = None
                if isinstance(cached_data, list):
                    kline_data = cached_data
                elif isinstance(cached_data, dict):
                    kline_data = cached_data.get('data', [])
                
                if not kline_data or len(kline_data) == 0:
                    codes_need_realtime.append((code, ts_code))
                    continue
                
                # 获取最新一条K线数据
                latest = kline_data[-1]
                
                # 提取价格信息
                close_price = float(latest.get('close', 0))
                pre_close = float(latest.get('pre_close', 0))
                
                # 计算涨跌
                change = 0.0
                change_percent = 0.0
                if pre_close > 0:
                    change = close_price - pre_close
                    change_percent = (change / pre_close) * 100
                
                # 获取成交量
                volume = float(latest.get('vol', 0)) * 100  # vol是手，转为股
                
                # 获取股票名称（从股票列表中查找）
                stock_name = None
                try:
                    stock_codes_data = redis_cache.get_cache("stocks:codes:all")
                    if stock_codes_data:
                        if isinstance(stock_codes_data, str):
                            stock_codes = json.loads(stock_codes_data)
                        else:
                            stock_codes = stock_codes_data
                        
                        for stock in stock_codes:
                            if stock.get('symbol') == code or stock.get('ts_code') == ts_code:
                                stock_name = stock.get('name')
                                break
                except Exception as e:
                    logger.warning(f"获取股票名称失败: {e}")
                
                result_data.append(StockPriceData(
                    code=code,
                    name=stock_name,
                    price=close_price,
                    change=round(change, 2),
                    change_percent=round(change_percent, 2),
                    volume=volume if volume > 0 else None
                ))
                
            except Exception as e:
                logger.error(f"获取股票 {code} 价格失败: {e}")
                result_data.append(StockPriceData(
                    code=code,
                    error=str(e)
                ))
        
        # 对于Redis中没有数据的股票，尝试从Tushare实时获取
        if codes_need_realtime:
            logger.info(f"🔄 需要实时获取 {len(codes_need_realtime)} 只股票的价格")
            realtime_results = await _fetch_realtime_prices(codes_need_realtime, redis_cache)
            result_data.extend(realtime_results)
        
        logger.info(f"批量获取价格完成，成功 {sum(1 for d in result_data if d.price is not None)} 只")
        
        return BatchPriceResponse(
            success=True,
            total=len(result_data),
            data=result_data,
            timestamp=datetime.now().isoformat()
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"批量获取股票价格失败: {str(e)}")
        raise HTTPException(status_code=500, detail=f"批量获取股票价格失败: {str(e)}")


async def _fetch_realtime_prices(codes_list: list, redis_cache) -> list:
    """
    从Tushare实时获取股票价格
    
    Args:
        codes_list: [(code, ts_code), ...] 股票代码列表
        redis_cache: Redis缓存实例
    
    Returns:
        StockPriceData列表
    """
    result_data = []
    
    try:
        import tushare as ts
        from app.core.config import settings
        
        # 初始化tushare
        pro = ts.pro_api(settings.TUSHARE_TOKEN)
        
        # 获取最近交易日
        from datetime import datetime, timedelta
        today = datetime.now()
        start_date = (today - timedelta(days=10)).strftime('%Y%m%d')
        end_date = today.strftime('%Y%m%d')
        
        for code, ts_code in codes_list:
            try:
                # 获取最近的日线数据
                df = pro.daily(ts_code=ts_code, start_date=start_date, end_date=end_date)
                
                if df is None or df.empty:
                    logger.warning(f"Tushare未返回 {ts_code} 的数据")
                    result_data.append(StockPriceData(
                        code=code,
                        error="暂无交易数据"
                    ))
                    continue
                
                # 获取最新一条数据
                latest = df.iloc[0]
                
                close_price = float(latest['close'])
                pre_close = float(latest['pre_close'])
                
                # 计算涨跌
                change = 0.0
                change_percent = 0.0
                if pre_close > 0:
                    change = close_price - pre_close
                    change_percent = (change / pre_close) * 100
                
                # 获取成交量
                volume = float(latest.get('vol', 0)) * 100  # vol是手，转为股
                
                # 获取股票名称
                stock_name = None
                try:
                    stock_codes_data = redis_cache.get_cache("stocks:codes:all")
                    if stock_codes_data:
                        if isinstance(stock_codes_data, str):
                            stock_codes = json.loads(stock_codes_data)
                        else:
                            stock_codes = stock_codes_data
                        
                        for stock in stock_codes:
                            if stock.get('symbol') == code or stock.get('ts_code') == ts_code:
                                stock_name = stock.get('name')
                                break
                except Exception as e:
                    logger.warning(f"获取股票名称失败: {e}")
                
                result_data.append(StockPriceData(
                    code=code,
                    name=stock_name,
                    price=close_price,
                    change=round(change, 2),
                    change_percent=round(change_percent, 2),
                    volume=volume if volume > 0 else None
                ))
                
                logger.info(f"✅ 实时获取 {ts_code} 价格成功: {close_price}")
                
                # 同时缓存到Redis，避免下次再查询
                try:
                    kline_list = []
                    for _, row in df.iterrows():
                        kline_list.append({
                            'trade_date': row['trade_date'],
                            'open': float(row['open']),
                            'high': float(row['high']),
                            'low': float(row['low']),
                            'close': float(row['close']),
                            'pre_close': float(row['pre_close']),
                            'vol': float(row['vol']),
                            'amount': float(row['amount']),
                        })
                    
                    # 按日期排序（从旧到新）
                    kline_list.reverse()
                    
                    cache_data = {
                        'ts_code': ts_code,
                        'data': kline_list,
                        'updated_at': datetime.now().isoformat(),
                        'data_count': len(kline_list),
                        'source': 'tushare_realtime'
                    }
                    
                    cache_key = f"stock_trend:{ts_code}"
                    redis_cache.set_cache(cache_key, cache_data, expire=3600)  # 缓存1小时
                    logger.info(f"📦 已缓存 {ts_code} 的K线数据")
                    
                except Exception as cache_error:
                    logger.warning(f"缓存 {ts_code} 数据失败: {cache_error}")
                
            except Exception as e:
                logger.error(f"实时获取 {ts_code} 价格失败: {e}")
                result_data.append(StockPriceData(
                    code=code,
                    error=f"获取失败: {str(e)}"
                ))
    
    except ImportError:
        logger.error("Tushare未安装，无法实时获取价格")
        for code, ts_code in codes_list:
            result_data.append(StockPriceData(
                code=code,
                error="服务暂不可用"
            ))
    except Exception as e:
        logger.error(f"实时获取价格失败: {e}")
        for code, ts_code in codes_list:
            result_data.append(StockPriceData(
                code=code,
                error=f"获取失败: {str(e)}"
            ))
    
    return result_data


# ==================== 多周期K线API ====================

class MultiPeriodKlineData(BaseModel):
    """多周期K线数据项"""
    date: str
    open: float
    high: float
    low: float
    close: float
    volume: float
    amount: Optional[float] = None
    change_pct: Optional[float] = None


class MultiPeriodKlineResponse(BaseModel):
    """多周期K线响应"""
    success: bool
    data: Optional[List[MultiPeriodKlineData]] = None
    period: Optional[str] = None
    period_name: Optional[str] = None
    count: Optional[int] = None
    from_cache: Optional[bool] = None
    error: Optional[str] = None


class SupportedPeriodsResponse(BaseModel):
    """支持的周期列表响应"""
    success: bool
    periods: Dict[str, str]


@router.get("/api/stocks/{stock_code}/kline",
           response_model=MultiPeriodKlineResponse,
           summary="获取多周期K线数据",
           dependencies=[Depends(verify_token)])
async def get_multi_period_kline(
    stock_code: str,
    period: str = Query(
        default="daily",
        description="K线周期: daily(日线), weekly(周线), monthly(月线), 15min(15分钟), 30min(30分钟), 60min(60分钟)"
    ),
    limit: int = Query(
        default=200,
        ge=10,
        le=500,
        description="返回数据条数，范围10-500"
    )
) -> MultiPeriodKlineResponse:
    """
    获取指定股票的多周期K线数据
    
    支持的周期：
    - daily: 日线（数据源：Tushare）
    - weekly: 周线（数据源：AKShare）
    - monthly: 月线（数据源：AKShare）
    - 15min: 15分钟（数据源：AKShare）
    - 30min: 30分钟（数据源：AKShare）
    - 60min: 60分钟（数据源：AKShare）
    
    缓存策略：
    - 日线：24小时
    - 周线：1小时（非交易时间24小时）
    - 月线：2小时（非交易时间24小时）
    - 分钟级：5-15分钟（非交易时间1小时）
    
    Args:
        stock_code: 股票代码（如：000001 或 000001.SZ）
        period: K线周期
        limit: 返回数据条数
        
    Returns:
        K线数据列表
    """
    try:
        from app.services.stock.multi_period_kline_service import multi_period_kline_service
        
        logger.info(f"获取 {stock_code} {period} K线数据，limit={limit}")
        
        result = await multi_period_kline_service.get_kline_data(
            stock_code=stock_code,
            period=period,
            limit=limit
        )
        
        if not result['success']:
            return MultiPeriodKlineResponse(
                success=False,
                error=result.get('error', '获取K线数据失败')
            )
        
        return MultiPeriodKlineResponse(
            success=True,
            data=result['data'],
            period=result['period'],
            period_name=result['period_name'],
            count=result['count'],
            from_cache=result.get('from_cache', False)
        )
        
    except Exception as e:
        logger.error(f"获取多周期K线数据失败: {e}")
        import traceback
        logger.error(traceback.format_exc())
        return MultiPeriodKlineResponse(
            success=False,
            error=f"获取K线数据失败: {str(e)}"
        )


@router.get("/api/stocks/kline/periods",
           response_model=SupportedPeriodsResponse,
           summary="获取支持的K线周期列表",
           dependencies=[Depends(verify_token)])
async def get_supported_periods() -> SupportedPeriodsResponse:
    """
    获取支持的K线周期列表
    
    Returns:
        支持的周期字典，key为周期代码，value为周期名称
    """
    try:
        from app.services.stock.multi_period_kline_service import multi_period_kline_service
        
        periods = multi_period_kline_service.get_supported_periods()
        
        return SupportedPeriodsResponse(
            success=True,
            periods=periods
        )
        
    except Exception as e:
        logger.error(f"获取支持的周期列表失败: {e}")
        return SupportedPeriodsResponse(
            success=False,
            periods={}
        )