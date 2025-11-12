#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
买入信号管理API
提供买入信号的查询功能
"""

import asyncio
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any
from fastapi import APIRouter, Depends, HTTPException, Query
from app.api.dependencies import verify_token
from app.core.logging import logger
from app.services.signal.signal_manager import signal_manager
from app.services.stock.stock_data_manager import StockDataManager
import json

router = APIRouter()


async def _update_signals_with_latest_price(signals: List[Dict]) -> None:
    """
    更新信号中的价格为最新价格
    
    从Redis缓存中获取最新K线数据，更新信号中的价格、涨跌幅等信息
    """
    if not signals:
        return
    
    try:
        from app.db.session import RedisCache
        redis_cache = RedisCache()
        
        for signal in signals:
            try:
                code = signal.get('code')
                if not code:
                    continue
                
                # 构造ts_code
                if code.startswith('6'):
                    ts_code = f"{code}.SH"
                elif code.startswith(('43', '83', '87', '88')):
                    ts_code = f"{code}.BJ"
                else:
                    ts_code = f"{code}.SZ"
                
                # 从Redis获取K线数据
                cache_key = f"stock_trend:{ts_code}"
                cached_data = redis_cache.get_cache(cache_key)
                
                if not cached_data:
                    continue
                
                # 解析缓存数据
                kline_data = None
                if isinstance(cached_data, list):
                    kline_data = cached_data
                elif isinstance(cached_data, dict):
                    kline_data = cached_data.get('data', [])
                
                if not kline_data or len(kline_data) == 0:
                    continue
                
                # 获取最新一条K线数据
                latest = kline_data[-1]
                trade_date = latest.get('trade_date', '')
                
                # 更新价格信息
                close_price = float(latest.get('close', 0))
                pre_close = float(latest.get('pre_close', 0))
                
                # 更新K线日期（格式：20251111 -> 2025-11-11）
                if trade_date and len(str(trade_date)) == 8:
                    trade_date_str = str(trade_date)
                    formatted_date = f"{trade_date_str[:4]}-{trade_date_str[4:6]}-{trade_date_str[6:8]}"
                    signal['kline_date'] = formatted_date
                
                # 计算涨跌
                if close_price > 0:
                    old_price = signal.get('price', 0)
                    signal['price'] = close_price
                    
                    if pre_close > 0:
                        change = close_price - pre_close
                        change_pct = (change / pre_close) * 100
                        signal['change'] = round(change, 2)
                        signal['change_percent'] = round(change_pct, 2)
                
                # 更新成交量
                vol = latest.get('vol', 0)
                if vol:
                    # Tushare的vol单位是手，需要乘以100转为股
                    signal['volume'] = float(vol) * 100
                
                # 标记为已更新最新价格
                signal['price_updated'] = True
                
            except Exception as e:
                logger.warning(f"更新股票 {signal.get('code')} 最新价格失败: {e}")
                continue
        
        logger.info(f"成功更新 {sum(1 for s in signals if s.get('price_updated'))} 个信号的最新价格")
        
    except Exception as e:
        logger.error(f"批量更新信号价格失败: {e}")


@router.get("/api/stocks/signal/buy", summary="获取买入信号", tags=["买入信号"], dependencies=[Depends(verify_token)])
async def get_buy_signals(
    strategy: Optional[str] = Query(None, description="策略名称（可选）：volume_wave, trend_continuation")
):
    """获取买入信号"""
    try:
        # 确保signal_manager已初始化
        init_success = await signal_manager.initialize()
        if not init_success:
            raise HTTPException(status_code=500, detail="SignalManager初始化失败")
        
        # 检查并清理旧策略信号（一次性检查）
        # 使用独立的Redis客户端获取，避免事件循环冲突
        check_key = "signal_migration_checked"
        migration_checked = None
        
        try:
            # 每次都重新获取Redis客户端，避免事件循环冲突
            from app.core.redis_client import get_redis_client
            redis_client = await get_redis_client()
            migration_checked = await redis_client.get(check_key)
        except Exception as e:
            # 捕获所有异常，包括事件循环冲突
            logger.warning(f"检查迁移状态失败，跳过: {e}")
            migration_checked = "1"  # 跳过迁移检查
        
        if not migration_checked:
            logger.info("首次访问，检查是否有旧策略信号需要清理...")
            try:
                # 确保使用新获取的Redis客户端
                if 'redis_client' not in locals():
                    from app.core.redis_client import get_redis_client
                    redis_client = await get_redis_client()
                
                signals_data = await redis_client.hgetall(signal_manager.buy_signals_key)
                
                old_strategy_names = {"ma_breakout", "volume_price", "breakthrough"}
                has_old_signals = False
                
                if signals_data:
                    for key, value in signals_data.items():
                        try:
                            signal_data = json.loads(value)
                            if signal_data.get('strategy') in old_strategy_names:
                                has_old_signals = True
                                break
                        except json.JSONDecodeError:
                            continue
                
                if has_old_signals:
                    logger.info("发现旧策略信号，清空并重新计算...")
                    await redis_client.delete(signal_manager.buy_signals_key)
                    logger.info("已清空旧策略信号")
                    
                    # 重新计算信号
                    calc_result = await signal_manager.calculate_buy_signals(force_recalculate=True)
                    logger.info(f"重新计算结果: {calc_result}")
                
                # 标记已检查
                await redis_client.set(check_key, "1", ex=86400)  # 24小时过期
                logger.info("信号迁移检查完成")
            except Exception as e:
                logger.error(f"信号迁移检查失败: {e}")
                # 尝试标记已检查，避免重复尝试
                try:
                    if 'redis_client' not in locals():
                        from app.core.redis_client import get_redis_client
                        redis_client = await get_redis_client()
                    await redis_client.set(check_key, "1", ex=3600)  # 1小时过期
                except:
                    pass  # 如果还是失败就放弃
        
        # 获取信号（不再传递limit参数）
        signals = await signal_manager.get_buy_signals(strategy=strategy)
        
        logger.info(f"获取到 {len(signals)} 个信号，开始更新最新价格...")
        
        # 更新信号中的价格为最新价格
        await _update_signals_with_latest_price(signals)
        
        logger.info(f"价格更新完成")
        
        def clean_numeric_value(value, default=0):
            """清理数值，确保JSON序列化兼容"""
            import math
            if value is None:
                return default
            if isinstance(value, (int, float)):
                if math.isnan(value) or math.isinf(value):
                    return default
                return value
            try:
                num_value = float(value)
                if math.isnan(num_value) or math.isinf(num_value):
                    return default
                return num_value
            except (ValueError, TypeError):
                return default
        
        def format_volume_humanized(volume):
            """格式化成交量为人性化显示（A股习惯：股数单位）"""
            # 先清理数值
            volume = clean_numeric_value(volume, 0)
            if volume <= 0:
                return "无数据"
            elif volume < 10000:  # 小于1万股
                return f"{volume:,.0f}股"
            elif volume < 100000000:  # 小于1亿股
                wan = volume / 10000
                if wan >= 1000:  # 大于等于1000万股
                    return f"{wan/100:.1f}千万股"
                else:
                    return f"{wan:.1f}万股"
            else:  # 大于等于1亿股
                yi = volume / 100000000
                return f"{yi:.2f}亿股"
        
        # 清理信号数据中的无效数值
        for signal in signals:
            # 清理所有数值字段
            for key in ['price', 'volume', 'volume_ratio', 'change_percent', 'confidence']:
                if key in signal:
                    signal[key] = clean_numeric_value(signal[key], 0)
                
                # 添加人性化成交量显示
                volume = signal.get('volume', 0)
                signal['volume_display'] = format_volume_humanized(volume)
            
        
        return {
            "code": 200,
            "message": "获取买入信号成功",
            "data": {
                "strategy": strategy,
                "signals": signals,
                "count": len(signals)
            }
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取买入信号失败: {str(e)}")
        import traceback
        logger.error(f"详细错误: {traceback.format_exc()}")
        return {
            "code": 500,
            "message": f"获取买入信号失败: {str(e)}",
            "data": {
                "strategy": strategy,
                "signals": [],
                "count": 0
            }
        }


 