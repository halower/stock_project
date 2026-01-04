# -*- coding: utf-8 -*-
"""图表数据API - 前后端分离架构"""

from fastapi import APIRouter, Depends, HTTPException, Query
from typing import Dict, Any, List
from datetime import datetime
import json
import pandas as pd
import hashlib

from app.core.sync_redis_client import get_sync_redis_client
from app.api.dependencies import verify_token
from app.core.logging import logger
from app.trading.strategies import apply_strategy

router = APIRouter(tags=["图表数据"])

# Redis缓存配置
CACHE_TTL_SECONDS = 60  # 1分钟缓存（适合实时数据）
CACHE_PREFIX = "chart_data"


def _generate_cache_key(stock_code: str, strategy: str) -> str:
    """生成缓存键"""
    return f"{CACHE_PREFIX}:{stock_code}:{strategy}"


def _serialize_dataframe(df: pd.DataFrame) -> List[Dict]:
    """将DataFrame序列化为JSON可序列化的格式"""
    # 转换日期为字符串
    df_copy = df.copy()
    if 'date' in df_copy.columns:
        df_copy['date'] = df_copy['date'].astype(str)
    
    # 替换NaN为None
    return df_copy.where(pd.notnull(df_copy), None).to_dict('records')


@router.get(
    "/api/stocks/{stock_code}/chart-data",
    summary="获取图表数据（纯JSON）",
    dependencies=[Depends(verify_token)]
)
async def get_chart_data(
    stock_code: str,
    strategy: str = Query("volume_wave", description="策略类型"),
    force_refresh: bool = Query(False, description="强制刷新缓存")
) -> Dict[str, Any]:
    """
    获取股票图表数据（K线+指标+信号）
    
    优势：
    - 前后端分离，1个HTML模板服务所有股票
    - Redis缓存指标计算结果，1分钟TTL
    - 支持1000+并发，无HTML文件堆积
    
    Args:
        stock_code: 股票代码
        strategy: 策略类型
        force_refresh: 是否强制刷新缓存
        
    Returns:
        {
            "stock": {"code": "000001", "name": "平安银行"},
            "kline_data": [...],  # K线数据
            "indicators": {...},  # 指标数据
            "signals": [...],     # 买卖信号
            "strategy": "volume_wave",
            "cached": true,       # 是否来自缓存
            "generated_time": "2025-12-24T10:30:00"
        }
    """
    if strategy not in ["volume_wave", "volume_wave_enhanced", "volatility_conservation"]:
        raise HTTPException(status_code=400, detail=f"不支持的策略: {strategy}")
    
    try:
        redis_client = get_sync_redis_client()
        cache_key = _generate_cache_key(stock_code, strategy)
        
        # 1. 尝试从缓存获取
        if not force_refresh:
            cached_data = redis_client.get(cache_key)
            if cached_data:
                logger.info(f"✅ 使用缓存数据: {stock_code} ({strategy})")
                result = json.loads(cached_data)
                result['cached'] = True
                return result
        
        # 2. 获取股票基本信息
        stock_codes_key = "stocks:codes:all"
        stock_codes_data = redis_client.get(stock_codes_key)
        
        if not stock_codes_data:
            raise HTTPException(status_code=500, detail="股票代码数据不可用")
        
        stock_codes = json.loads(stock_codes_data)
        stock_info = None
        ts_code = None
        
        # 查找股票信息
        for stock in stock_codes:
            if (stock.get('ts_code') == stock_code or 
                stock.get('symbol') == stock_code or 
                stock.get('ts_code', '').split('.')[0] == stock_code):
                stock_info = stock
                ts_code = stock.get('ts_code')
                break
        
        if not stock_info or not ts_code:
            raise HTTPException(status_code=404, detail=f"股票 {stock_code} 不存在")
        
        # 3. 获取K线数据（带自动补偿）
        kline_key = f"stock_trend:{ts_code}"
        kline_data = redis_client.get(kline_key)
        
        if not kline_data:
            # 🔧 自动数据补偿机制：如果Redis中没有数据，立即从Tushare获取
            logger.warning(f"Redis中没有股票 {stock_code} 的历史数据")
            logger.info(f"🚀 启动自动数据补偿：从Tushare获取股票 {ts_code} 的历史数据...")
            
            try:
                from app.services.stock.unified_data_service import UnifiedDataService
                import tushare as ts
                from datetime import datetime
                
                unified_service = UnifiedDataService()
                
                # 判断是否为ETF
                is_etf = stock_info.get('market', '') == 'ETF' or ts_code.startswith(('51', '15', '16', '56'))
                
                # 获取180天数据
                logger.info(f"正在获取 {ts_code} 的180天K线数据（{'ETF' if is_etf else '股票'}）...")
                kline_list = unified_service.fetch_historical_data(
                    ts_code=ts_code,
                    days=180,
                    is_etf=is_etf
                )
                
                if not kline_list or len(kline_list) < 20:
                    logger.error(f"❌ 从Tushare获取的数据不足: {len(kline_list) if kline_list else 0} 条")
                    raise HTTPException(
                        status_code=404,
                        detail=f"股票 {stock_code} 历史数据不足（获取到{len(kline_list) if kline_list else 0}条）"
                    )
                
                # 存储到Redis
                trend_data_to_store = {
                    'ts_code': ts_code,
                    'data': kline_list,
                    'updated_at': datetime.now().isoformat(),
                    'data_count': len(kline_list),
                    'source': 'tushare_补偿'
                }
                
                redis_client.set(kline_key, json.dumps(trend_data_to_store, default=str))
                logger.info(f"✅ 数据补偿成功: {ts_code}，已存储 {len(kline_list)} 条K线数据")
                
                # 重新读取数据
                kline_data = redis_client.get(kline_key)
                
            except Exception as e:
                logger.error(f"❌ 自动数据补偿失败: {str(e)}")
                import traceback
                logger.error(traceback.format_exc())
                raise HTTPException(
                    status_code=404,
                    detail=f"股票 {stock_code} 无法获取历史数据。错误：{str(e)}"
                )
        
        # 4. 解析并处理数据
        trend_data = json.loads(kline_data)
        if isinstance(trend_data, dict):
            kline_json = trend_data.get('data', [])
        elif isinstance(trend_data, list):
            kline_json = trend_data
        else:
            raise HTTPException(status_code=400, detail="数据格式错误")
        
        if len(kline_json) < 20:
            raise HTTPException(status_code=400, detail="历史数据不足")
        
        # 5. 转换为DataFrame并标准化字段
        df = pd.DataFrame(kline_json)
        
        # 处理日期字段
        if 'date' not in df.columns:
            if 'trade_date' in df.columns:
                def convert_tushare_date(date_str):
                    date_str = str(date_str)
                    if len(date_str) == 8 and date_str.isdigit():
                        return f"{date_str[:4]}-{date_str[4:6]}-{date_str[6:8]}"
                    return date_str
                df['date'] = pd.to_datetime(df['trade_date'].apply(convert_tushare_date))
            elif 'actual_trade_date' in df.columns:
                df['date'] = pd.to_datetime(df['actual_trade_date'])
            else:
                df['date'] = pd.date_range(start='2024-01-01', periods=len(df), freq='D')
        else:
            df['date'] = pd.to_datetime(df['date'])
        
        # 处理成交量字段
        if 'volume' not in df.columns and 'vol' in df.columns:
            df['volume'] = df['vol'].fillna(0) * 100
        elif 'volume' not in df.columns:
            df['volume'] = 1000
        
        df['volume'] = df['volume'].fillna(1000)
        df['volume'] = df['volume'].apply(lambda x: max(x, 1) if x != 0 else 1000)
        
        # 验证必要列
        required_columns = ['close', 'open', 'high', 'low', 'volume']
        missing_columns = [col for col in required_columns if col not in df.columns]
        if missing_columns:
            raise HTTPException(status_code=400, detail=f"缺少必要列: {missing_columns}")
        
        # 6. 应用策略（耗时操作）
        logger.info(f"🔄 计算指标: {stock_code} ({strategy})")
        processed_df, signals = apply_strategy(strategy, df)
        
        # 7. 为volume_wave策略添加额外指标
        if strategy == 'volume_wave':
            try:
                close_values = processed_df['close'].to_numpy()
                from app.strategies.volume_wave_strategy import VolumeWaveStrategy
                
                if 'ema12' not in processed_df.columns:
                    processed_df['ema12'] = pd.Series(VolumeWaveStrategy.calculate_ema(close_values, 12))
                if 'ema144' not in processed_df.columns:
                    processed_df['ema144'] = pd.Series(VolumeWaveStrategy.calculate_ema(close_values, 144))
                if 'ema169' not in processed_df.columns:
                    processed_df['ema169'] = pd.Series(VolumeWaveStrategy.calculate_ema(close_values, 169))
            except Exception as e:
                logger.warning(f"添加EMA指标失败: {e}")
        
        # 8. 构建返回数据
        result = {
            "stock": {
                "code": stock_code,
                "name": stock_info.get('name', stock_code)
            },
            "kline_data": _serialize_dataframe(processed_df),
            "signals": [
                {
                    "date": str(sig['date']),
                    "type": sig['type'],
                    "price": float(sig['price']),
                    "reason": sig.get('reason', '')
                }
                for sig in signals
            ],
            "strategy": strategy,
            "cached": False,
            "generated_time": datetime.now().isoformat()
        }
        
        # 9. 缓存结果（1分钟）
        try:
            redis_client.setex(
                cache_key,
                CACHE_TTL_SECONDS,
                json.dumps(result, ensure_ascii=False)
            )
            logger.info(f"💾 缓存数据: {stock_code} ({strategy}), TTL={CACHE_TTL_SECONDS}s")
        except Exception as cache_error:
            logger.warning(f"缓存失败（不影响返回）: {cache_error}")
        
        return result
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取图表数据失败: {str(e)}")
        raise HTTPException(status_code=500, detail=f"数据获取错误: {str(e)}")


@router.delete(
    "/api/stocks/{stock_code}/chart-data/cache",
    summary="清除图表数据缓存",
    dependencies=[Depends(verify_token)]
)
async def clear_chart_cache(stock_code: str, strategy: str = Query("volume_wave")):
    """清除指定股票的图表数据缓存"""
    try:
        redis_client = get_sync_redis_client()
        cache_key = _generate_cache_key(stock_code, strategy)
        deleted = redis_client.delete(cache_key)
        
        return {
            "success": True,
            "deleted": deleted > 0,
            "message": f"已清除 {stock_code} ({strategy}) 的缓存"
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"清除缓存失败: {str(e)}")

