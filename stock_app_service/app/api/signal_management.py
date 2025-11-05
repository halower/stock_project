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


@router.post("/api/signals/calculate", summary="手动计算买入信号（后台执行）", tags=["买入信号"], dependencies=[Depends(verify_token)])
async def calculate_buy_signals_manually():
    """手动触发买入信号计算（异步后台执行，不阻塞请求）"""
    try:
        # 快速检查数据完整性（不阻塞太久）
        from app.core.redis_client import get_redis_client
        redis_client = await get_redis_client()
        
        # 检查股票列表
        stock_codes = await redis_client.get("stocks:codes:all")
        if not stock_codes:
            return {
                "code": 400,
                "message": "股票清单数据不足，请先初始化股票数据",
                "data": {"stock_list_count": 0}
            }
        
        import json
        stock_list = json.loads(stock_codes)
        if len(stock_list) < 100:
            return {
                "code": 400,
                "message": f"股票清单数据不足（当前{len(stock_list)}只），请先初始化股票数据",
                "data": {"stock_list_count": len(stock_list)}
            }
        
        # 启动后台任务执行信号计算
        import threading
        
        def background_calculate():
            """后台执行信号计算"""
            try:
                loop = asyncio.new_event_loop()
                asyncio.set_event_loop(loop)
                
                async def _calc():
                    from app.services.signal.signal_manager import SignalManager
                    manager = SignalManager()
                    await manager.initialize()
                    result = await manager.calculate_buy_signals(force_recalculate=True)
                    await manager.close()
                    return result
                
                result = loop.run_until_complete(_calc())
                logger.info(f"后台信号计算完成: {result}")
            except Exception as e:
                logger.error(f"后台信号计算失败: {e}")
                import traceback
                logger.error(traceback.format_exc())
            finally:
                loop.close()
        
        # 启动后台线程
        thread = threading.Thread(target=background_calculate, daemon=True)
        thread.start()
        
        # 立即返回
        logger.info("信号计算任务已在后台启动，不会阻塞其他请求")
        return {
            "code": 200,
            "message": "信号计算任务已启动（后台执行）",
            "data": {
                "status": "running",
                "stock_count": len(stock_list),
                "note": "计算正在后台进行，不会阻塞其他API请求。请稍后通过 /api/stocks/signal/buy 查看结果"
            }
        }
            
    except Exception as e:
        logger.error(f"启动信号计算任务失败: {str(e)}")
        import traceback
        logger.error(f"详细错误: {traceback.format_exc()}")
        return {
            "code": 500,
            "message": f"启动信号计算任务失败: {str(e)}",
            "data": None
        }


@router.post("/api/scheduler/restart", summary="重启所有调度器", tags=["买入信号"], dependencies=[Depends(verify_token)])
async def restart_schedulers():
    """重启所有调度器"""
    try:
        restart_result = {
            "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "results": {}
        }
        
        # 重启新闻调度器
        try:
            from app.services.scheduler.news_scheduler import stop_news_scheduler, start_news_scheduler
            stop_news_scheduler()
            await asyncio.sleep(1)  # 等待1秒确保完全停止
            start_news_scheduler()
            restart_result["results"]["news_scheduler"] = {
                "name": "新闻调度器",
                "status": "success",
                "message": "重启成功"
            }
            logger.info("新闻调度器重启成功")
        except Exception as e:
            restart_result["results"]["news_scheduler"] = {
                "name": "新闻调度器",
                "status": "error",
                "message": str(e)
            }
            logger.error(f"新闻调度器重启失败: {e}")
        
        # 重启股票调度器
        try:
            from app.services.scheduler.stock_scheduler import stop_stock_scheduler, start_stock_scheduler
            stop_stock_scheduler()
            await asyncio.sleep(1)  # 等待1秒确保完全停止
            start_stock_scheduler()
            restart_result["results"]["stock_scheduler"] = {
                "name": "股票调度器",
                "status": "success",
                "message": "重启成功"
            }
            logger.info("股票调度器重启成功")
        except Exception as e:
            restart_result["results"]["stock_scheduler"] = {
                "name": "股票调度器",
                "status": "error",
                "message": str(e)
            }
            logger.error(f"股票调度器重启失败: {e}")
        
        # 重启图表清理调度器
        try:
            from app.tasks.scheduler import scheduler as chart_scheduler
            if chart_scheduler.scheduler and chart_scheduler.scheduler.running:
                chart_scheduler.shutdown()
            await asyncio.sleep(1)
            chart_scheduler.start()
            restart_result["results"]["chart_scheduler"] = {
                "name": "图表清理调度器",
                "status": "success",
                "message": "重启成功"
            }
            logger.info("图表清理调度器重启成功")
        except Exception as e:
            restart_result["results"]["chart_scheduler"] = {
                "name": "图表清理调度器",
                "status": "error",
                "message": str(e)
            }
            logger.error(f"图表清理调度器重启失败: {e}")
        
        # 统计结果
        success_count = sum(1 for r in restart_result["results"].values() if r.get("status") == "success")
        total_count = len(restart_result["results"])
        
        return {
            "code": 200,
            "message": f"调度器重启完成，成功: {success_count}/{total_count}",
            "data": restart_result
        }
        
    except Exception as e:
        logger.error(f"调度器重启失败: {str(e)}")
        import traceback
        logger.error(f"详细错误: {traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=f"调度器重启失败: {str(e)}") 