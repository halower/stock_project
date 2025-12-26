# -*- coding: utf-8 -*-
"""
股票数据调度器 V2 - 重构版
按照DDD原则重新组织，分离启动任务和运行时任务
"""

import asyncio
import threading
from datetime import datetime, time
from typing import Dict, Any
from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger
from apscheduler.triggers.interval import IntervalTrigger

from app.core.logging import logger
from app.core.config import settings
from app.db.session import RedisCache
from app.services.stock.stock_atomic_service import stock_atomic_service

# Redis缓存客户端
redis_cache = RedisCache()

# 调度器实例
scheduler = None
job_logs = []  # 存储最近的任务执行日志

# 任务执行锁
_task_locks = {
    'realtime_update': threading.Lock(),
    'signal_calculation': threading.Lock(),
    'full_update': threading.Lock(),
}


def add_job_log(job_type: str, status: str, message: str, **kwargs):
    """添加任务执行日志"""
    log_entry = {
        'timestamp': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
        'job_type': job_type,
        'status': status,
        'message': message,
        **kwargs
    }
    
    # 内存日志（最近10条）
    global job_logs
    job_logs.insert(0, log_entry)
    job_logs = job_logs[:10]
    
    # Redis日志（最近20条）
    redis_logs = redis_cache.get_cache('stock:scheduler:log') or []
    redis_logs.insert(0, log_entry)
    redis_logs = redis_logs[:20]
    redis_cache.set_cache('stock:scheduler:log', redis_logs, ttl=86400)
    
    logger.info(f"[{job_type}] {message}")


def is_trading_time() -> bool:
    """
    判断是否为交易时间（包括盘后时间）
    
    交易时间: 9:15-12:00, 13:00-15:15
    - 9:15开始：提前15分钟准备
    - 12:00结束：上午收盘后30分钟
    - 15:15结束：下午收盘后15分钟
    """
    now = datetime.now()
    
    # 周末不交易
    if now.weekday() >= 5:
        return False
    
    current_time = now.time()
    
    # 上午时段（9:15-12:00）
    morning_start = time(9, 15)
    morning_end = time(12, 0)
    
    # 下午时段（13:00-15:15）
    afternoon_start = time(13, 0)
    afternoon_end = time(15, 15)
    
    return (
        (morning_start <= current_time <= morning_end) or
        (afternoon_start <= current_time <= afternoon_end)
    )


# ==================== 启动任务 ====================

class StartupTasks:
    """启动时执行的任务"""
    
    @staticmethod
    async def execute(init_mode: str = "skip", calculate_signals: bool = False):
        """
        执行启动任务
        
        Args:
            init_mode: 初始化模式
                - skip: 跳过初始化
                - init: 全量初始化
            calculate_signals: 是否计算信号
        """
        logger.info(f"========== 开始执行启动任务 ==========")
        logger.info(f"初始化模式: {init_mode}")
        logger.info(f"是否计算信号: {calculate_signals}")
        
        start_time = datetime.now()
        
        try:
            # 1. 获取有效股票代码列表（必须执行）
            await StartupTasks.task_get_valid_stock_codes()
            
            # 2. 根据初始化模式执行相应操作
            if init_mode == "init":
                await StartupTasks.task_init()
            elif init_mode == "skip":
                logger.info("跳过数据初始化")
            else:
                logger.warning(f"未知的初始化模式: {init_mode}，跳过初始化")
            
            # 3. 爬取新闻（必须执行）
            await StartupTasks.task_crawl_news()
            
            # 4. 根据配置决定是否计算信号
            if calculate_signals:
                await StartupTasks.task_calculate_signals()
            else:
                logger.info("跳过信号计算")
            
            elapsed = (datetime.now() - start_time).total_seconds()
            logger.info(f"========== 启动任务完成，耗时 {elapsed:.2f}秒 ==========")
            
            add_job_log(
                'startup',
                'success',
                f'启动任务完成，模式={init_mode}，计算信号={calculate_signals}',
                elapsed_seconds=round(elapsed, 2)
            )
            
        except Exception as e:
            logger.error(f"启动任务执行失败: {e}")
            import traceback
            logger.error(traceback.format_exc())
            add_job_log('startup', 'error', f'启动任务失败: {str(e)}')
    
    @staticmethod
    async def task_get_valid_stock_codes():
        """任务：获取有效股票代码列表"""
        logger.info(">>> 执行任务: 获取有效股票代码列表")
        start_time = datetime.now()
        
        try:
            stock_list = await stock_atomic_service.get_valid_stock_codes(include_etf=True)
            
            elapsed = (datetime.now() - start_time).total_seconds()
            logger.info(f">>> 任务完成: 获取到 {len(stock_list)} 只股票（含ETF），耗时 {elapsed:.2f}秒")
            
            add_job_log(
                'get_stock_codes',
                'success',
                f'获取股票代码成功，共 {len(stock_list)} 只',
                count=len(stock_list),
                elapsed_seconds=round(elapsed, 2)
            )
            
        except Exception as e:
            logger.error(f">>> 任务失败: 获取股票代码失败: {e}")
            add_job_log('get_stock_codes', 'error', f'获取股票代码失败: {str(e)}')
            raise
    
    @staticmethod
    async def task_init():
        """任务：全量初始化"""
        logger.info(">>> 执行任务: 全量初始化所有股票数据")
        start_time = datetime.now()
        
        try:
            # 🔧 优化：降低并发以避免触发API限制
            # Tushare限制: 每分钟500次，每天20000次
            # 推荐配置: batch_size=30, max_concurrent=5 → ~300次/分钟
            result = await stock_atomic_service.full_update_all_stocks(
                days=180,
                batch_size=30,       # 从50降低至30，减少单批次压力
                max_concurrent=5     # 从10降低至5，减少API限流
            )
            
            elapsed = (datetime.now() - start_time).total_seconds()
            logger.info(
                f">>> 任务完成: 全量初始化完成，"
                f"成功={result['success_count']}, "
                f"失败={result['failed_count']}, "
                f"耗时 {elapsed:.2f}秒"
            )
            
            add_job_log(
                'init',
                'success',
                f"全量初始化完成，成功={result['success_count']}, 失败={result['failed_count']}",
                **result
            )
            
        except Exception as e:
            logger.error(f">>> 任务失败: 全量初始化失败: {e}")
            add_job_log('init', 'error', f'全量初始化失败: {str(e)}')
            raise
    
    @staticmethod
    async def task_crawl_news():
        """任务：爬取新闻"""
        start_time = datetime.now()
        
        try:
            result = await stock_atomic_service.crawl_news(days=1)
            
            elapsed = (datetime.now() - start_time).total_seconds()
            
            add_job_log(
                'crawl_news',
                'success' if result.get('success') else 'warning',
                f"爬取新闻完成，共 {result.get('news_count', 0)} 条",
                **result
            )
            
        except Exception as e:
            logger.error(f">>> 任务失败: 爬取新闻失败: {e}")
            add_job_log('crawl_news', 'error', f'爬取新闻失败: {str(e)}')
            # 新闻爬取失败不影响启动，不抛出异常
    
    @staticmethod
    async def task_calculate_signals():
        """任务：计算策略信号"""
        logger.info(">>> 执行任务: 计算策略信号")
        start_time = datetime.now()
        
        try:
            result = await stock_atomic_service.calculate_strategy_signals(
                force_recalculate=True
            )
            
            elapsed = (datetime.now() - start_time).total_seconds()
            logger.info(f">>> 任务完成: 计算信号完成，耗时 {elapsed:.2f}秒")
            
            # 从result中排除status字段，避免参数冲突
            result_data = {k: v for k, v in result.items() if k != 'status'}
            add_job_log(
                'calculate_signals',
                'success' if result.get('success') or result.get('status') == 'success' else 'error',
                f"计算信号完成",
                **result_data
            )
            
        except Exception as e:
            logger.error(f">>> 任务失败: 计算信号失败: {e}")
            add_job_log('calculate_signals', 'error', f'计算信号失败: {str(e)}')
            # 信号计算失败不影响启动，不抛出异常


# ==================== 运行时任务 ====================

class RuntimeTasks:
    """运行时定时任务"""
    
    @staticmethod
    def job_realtime_update():
        """定时任务：实时更新所有股票数据（仅交易时间）"""
        # 检查是否在交易时间
        if not is_trading_time():
            logger.debug("非交易时间，跳过实时数据更新")
            return
        
        # 防止重复执行
        if not _task_locks['realtime_update'].acquire(blocking=False):
            logger.warning("实时数据更新任务正在执行中，跳过本次")
            return
        
        try:
            logger.info("========== 开始实时数据更新 ==========")
            start_time = datetime.now()
            
            # 在新的事件循环中执行异步任务
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            
            try:
                # 1. 更新股票数据
                result = loop.run_until_complete(
                    stock_atomic_service.realtime_update_all_stocks()
                )
                
                elapsed = (datetime.now() - start_time).total_seconds()
                logger.info(f"========== 实时数据更新完成，耗时 {elapsed:.2f}秒 ==========")
                
                # result 中已包含 message 和 elapsed_seconds，直接使用
                add_job_log(
                    'realtime_update',
                    'success',
                    result.get('message', '实时数据更新完成'),
                    **{k: v for k, v in result.items() if k != 'message'}  # 排除message避免重复
                )
                
                # 2. 推送价格更新到WebSocket客户端
                try:
                    from app.services.websocket import price_publisher
                    
                    # 广播所有活跃策略的价格更新
                    client_count = loop.run_until_complete(
                        price_publisher.broadcast_all_prices()
                    )
                    
                    if client_count > 0:
                        logger.info(f"价格更新已推送到 {client_count} 个WebSocket客户端")
                    else:
                        logger.debug("没有活跃的WebSocket客户端，跳过价格推送")
                        
                except Exception as e:
                    logger.error(f"WebSocket价格推送失败: {e}")
                    # 价格推送失败不影响主流程
                
                # 注意：实时更新和信号计算已分离，不再自动触发信号计算
                # 信号计算由独立的定时任务触发
                
            finally:
                loop.close()
                
        except Exception as e:
            logger.error(f"实时数据更新失败: {e}")
            import traceback
            logger.error(traceback.format_exc())
            add_job_log(
                'realtime_update',
                'error',
                f'实时数据更新异常: {str(e)}'  # 使用不同的消息，避免与result中的message冲突
            )
        finally:
            _task_locks['realtime_update'].release()
    
    @staticmethod
    def job_calculate_signals():
        """
        定时任务：计算策略信号（盘中仅计算股票信号，不计算ETF）
        
        注意：此任务在独立线程中执行，不会阻塞API请求
        """
        # 检查是否为交易时间
        if not is_trading_time():
            logger.debug("非交易时间，跳过信号计算")
            return
        
        # 防止重复执行
        if not _task_locks['signal_calculation'].acquire(blocking=False):
            logger.warning("信号计算任务正在执行中，跳过本次")
            return
        
        try:
            logger.info("========== 开始计算策略信号（仅股票） ==========")
            start_time = datetime.now()
            
            # 使用独立的事件循环，在当前线程中执行
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            
            try:
                # 不设置超时，让信号计算自然完成
                result = loop.run_until_complete(
                    stock_atomic_service.calculate_strategy_signals(
                        force_recalculate=True,  # 盘中也需要强制重算，确保信号最新
                        stock_only=True  # 盘中仅计算股票信号
                    )
                )
                
                elapsed = (datetime.now() - start_time).total_seconds()
                logger.info(f"========== 信号计算完成（仅股票），耗时 {elapsed:.2f}秒 ==========")
                
                # 从result中排除status字段，避免参数冲突
                result_data = {k: v for k, v in result.items() if k != 'status'}
                add_job_log(
                    'signal_calculation',
                    'success' if result.get('success') or result.get('status') == 'success' else 'warning',
                    f'信号计算完成',
                    **result_data
                )
                
            finally:
                loop.close()
                
        except Exception as e:
            logger.error(f"信号计算失败: {e}")
            import traceback
            logger.error(traceback.format_exc())
            add_job_log(
                'signal_calculation',
                'error',
                f'信号计算失败: {str(e)}'
            )
        finally:
            _task_locks['signal_calculation'].release()
    
    @staticmethod
    def job_crawl_news():
        """定时任务：爬取新闻"""
        start_time = datetime.now()
        
        try:
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            
            try:
                result = loop.run_until_complete(
                    stock_atomic_service.crawl_news(days=1)
                )
                
                elapsed = (datetime.now() - start_time).total_seconds()
                
                add_job_log(
                    'crawl_news',
                    'success' if result.get('success') else 'warning',
                    f"爬取新闻完成，共 {result.get('news_count', 0)} 条",
                    **result
                )
                
            finally:
                loop.close()
                
        except Exception as e:
            logger.error(f"新闻爬取失败: {e}")
            add_job_log('crawl_news', 'error', f'新闻爬取失败: {str(e)}')
    
    @staticmethod
    def job_full_update_and_calculate():
        """定时任务：全量更新并计算信号"""
        # 防止重复执行
        if not _task_locks['full_update'].acquire(blocking=False):
            logger.warning("全量更新任务正在执行中，跳过本次")
            return
        
        try:
            logger.info("========== 开始全量更新并计算信号 ==========")
            start_time = datetime.now()
            
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            
            try:
                # 1. 全量更新（包含股票和ETF，降低并发数）
                update_result = loop.run_until_complete(
                    stock_atomic_service.full_update_all_stocks(
                        days=180,
                        batch_size=50,
                        max_concurrent=5  # 降低并发数，减少API限流
                    )
                )
                
                logger.info(f"全量更新完成（包含ETF）: 成功={update_result['success_count']}, 失败={update_result['failed_count']}")
                
                # 2. 计算信号（包含股票和ETF）
                signal_result = loop.run_until_complete(
                    stock_atomic_service.calculate_strategy_signals(
                        force_recalculate=True,
                        stock_only=False  # 全量更新包含ETF信号
                    )
                )
                
                elapsed = (datetime.now() - start_time).total_seconds()
                logger.info(f"========== 全量更新并计算信号完成，耗时 {elapsed:.2f}秒 ==========")
                
                add_job_log(
                    'full_update_and_calculate',
                    'success',
                    f"全量更新并计算信号完成",
                    elapsed_seconds=round(elapsed, 2),
                    update_result=update_result,
                    signal_result=signal_result
                )
                
            finally:
                loop.close()
                
        except Exception as e:
            logger.error(f"全量更新并计算信号失败: {e}")
            import traceback
            logger.error(traceback.format_exc())
            add_job_log('full_update_and_calculate', 'error', f'全量更新并计算信号失败: {str(e)}')
        finally:
            _task_locks['full_update'].release()
    
    @staticmethod
    def job_cleanup_charts():
        """定时任务：清理图表文件"""
        logger.info("========== 开始清理图表文件 ==========")
        start_time = datetime.now()
        
        try:
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            
            try:
                result = loop.run_until_complete(
                    stock_atomic_service.cleanup_chart_files()
                )
                
                elapsed = (datetime.now() - start_time).total_seconds()
                logger.info(f"========== 图表文件清理完成，耗时 {elapsed:.2f}秒 ==========")
                
                add_job_log(
                    'cleanup_charts',
                    'success',
                    f"清理图表文件完成，删除 {result.get('deleted_count', 0)} 个文件",
                    **result
                )
                
            finally:
                loop.close()
                
        except Exception as e:
            logger.error(f"清理图表文件失败: {e}")
            add_job_log('cleanup_charts', 'error', f'清理图表文件失败: {str(e)}')
    
    @staticmethod
    def job_websocket_price_push():
        """定时任务：WebSocket价格推送（仅在交易时间）"""
        try:
            from app.services.websocket import price_publisher, connection_manager
            
            # 检查是否在交易时间
            if not is_trading_time():
                logger.debug("WebSocket价格推送: 非交易时间，跳过")
                return
            
            # 检查是否有活跃连接
            connection_count = connection_manager.get_connection_count()
            if connection_count == 0:
                logger.debug("WebSocket价格推送: 没有活跃连接，跳过")
                return  # 没有连接，跳过
            
            logger.debug(f"WebSocket价格推送: 活跃连接数 {connection_count}")
            
            # 在新的事件循环中执行异步任务
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            
            try:
                client_count = loop.run_until_complete(
                    price_publisher.broadcast_all_prices()
                )
                
                if client_count > 0:
                    logger.debug(f"价格推送完成: {client_count} 个客户端")
                    
            finally:
                loop.close()
                
        except Exception as e:
            logger.error(f"WebSocket价格推送失败: {e}")


# ==================== 调度器管理 ====================

def start_stock_scheduler(init_mode: str = "skip", calculate_signals: bool = False):
    """
    启动股票调度器
    
    Args:
        init_mode: 初始化模式
            - skip: 跳过初始化
            - init: 全量初始化
        calculate_signals: 是否在启动时计算信号
    """
    global scheduler
    
    if scheduler is not None and scheduler.running:
        logger.warning("股票调度器已在运行中")
        return
    
    logger.info("========== 启动股票调度器 ==========")
    logger.info(f"初始化模式: {init_mode}")
    logger.info(f"启动时计算信号: {calculate_signals}")
    
    # 1. 创建调度器（增加线程池大小，避免长时间任务阻塞其他任务）
    from apscheduler.executors.pool import ThreadPoolExecutor
    executors = {
        'default': ThreadPoolExecutor(max_workers=10),  # 增加线程池大小
    }
    job_defaults = {
        'coalesce': True,  # 合并错过的任务
        'max_instances': 1,  # 每个任务最多同时运行1个实例
        'misfire_grace_time': 60,  # 错过执行时间后60秒内仍可执行
    }
    scheduler = BackgroundScheduler(
        timezone='Asia/Shanghai',
        executors=executors,
        job_defaults=job_defaults
    )
    
    # 3. 添加运行时任务
    
    # 实时数据更新：根据配置决定是否启用（可通过环境变量ENABLE_REALTIME_UPDATE控制）
    if settings.ENABLE_REALTIME_UPDATE:
        realtime_interval_seconds = settings.REALTIME_UPDATE_INTERVAL
        realtime_interval_minutes = realtime_interval_seconds / 60
        scheduler.add_job(
            func=RuntimeTasks.job_realtime_update,
            trigger=IntervalTrigger(seconds=realtime_interval_seconds),
            id='realtime_update',
            name='实时数据更新',
            replace_existing=True
        )
        logger.info(f"✅ 实时数据更新任务已启用，间隔: {realtime_interval_seconds}秒")
    else:
        logger.info(f"⚠️  实时数据更新任务已禁用（ENABLE_REALTIME_UPDATE=false）")
    
    # 信号计算：固定时间点触发（保持原有逻辑）
    # 9:30, 9:50, 10:10, 10:30, 10:50, 11:10, 11:30
    # 13:00, 13:20, 13:40, 14:00, 14:20, 14:40, 15:00, 15:20
    from datetime import datetime
    now = datetime.now()
    
    # 如果是交易时间且启动时计算信号，立即执行一次
    if is_trading_time() and calculate_signals:
        logger.info("启动时立即执行一次信号计算，确保有最新信号...")
        import threading
        # 在后台线程中执行，不阻塞启动
        threading.Thread(target=RuntimeTasks.job_calculate_signals, daemon=True).start()
    
    # 信号计算：从9:30开始，每20分钟执行一次
    # 9:30, 9:50, 10:10, 10:30, 10:50, 11:10, 13:10, 13:30, 13:50, 14:10, 14:30, 14:50, 15:10
    scheduler.add_job(
        func=RuntimeTasks.job_calculate_signals,
        trigger=CronTrigger(
            day_of_week='mon-fri',
            hour='9',
            minute='30,50'
        ),
        id='signal_calculation_morning_1',
        name='策略信号计算（9:30-9:50）',
        replace_existing=True,
        misfire_grace_time=300
    )
    scheduler.add_job(
        func=RuntimeTasks.job_calculate_signals,
        trigger=CronTrigger(
            day_of_week='mon-fri',
            hour='10-11',
            minute='10,30,50'
        ),
        id='signal_calculation_morning_2',
        name='策略信号计算（10:10-11:50）',
        replace_existing=True,
        misfire_grace_time=300
    )
    scheduler.add_job(
        func=RuntimeTasks.job_calculate_signals,
        trigger=CronTrigger(
            day_of_week='mon-fri',
            hour='13-14',
            minute='10,30,50'
        ),
        id='signal_calculation_afternoon_1',
        name='策略信号计算（13:10-14:50）',
        replace_existing=True,
        misfire_grace_time=300
    )
    scheduler.add_job(
        func=RuntimeTasks.job_calculate_signals,
        trigger=CronTrigger(
            day_of_week='mon-fri',
            hour='15',
            minute='10'
        ),
        id='signal_calculation_afternoon_2',
        name='策略信号计算（15:10）',
        replace_existing=True,
        misfire_grace_time=300
    )
    logger.info("信号计算任务已添加，从9:30开始，每20分钟执行一次（共13次）")
    
    # 新闻爬取：每2小时执行一次
    scheduler.add_job(
        func=RuntimeTasks.job_crawl_news,
        trigger=IntervalTrigger(hours=2),
        id='crawl_news',
        name='新闻爬取',
        replace_existing=True
    )
    
    # 全量更新并计算信号：每个交易日17:35执行一次
    scheduler.add_job(
        func=RuntimeTasks.job_full_update_and_calculate,
        trigger=CronTrigger(hour=17, minute=35, day_of_week='mon-fri'),
        id='full_update_and_calculate',
        name='全量更新并计算信号',
        replace_existing=True
    )
    
    # 图表文件清理：每天00:00执行一次
    scheduler.add_job(
        func=RuntimeTasks.job_cleanup_charts,
        trigger=CronTrigger(hour=0, minute=0),
        id='cleanup_charts',
        name='图表文件清理',
        replace_existing=True
    )
    
    # WebSocket价格推送：每5秒执行一次（仅在交易时间）
    scheduler.add_job(
        func=RuntimeTasks.job_websocket_price_push,
        trigger=IntervalTrigger(seconds=5),
        id='websocket_price_push',
        name='WebSocket价格推送',
        replace_existing=True
    )
    logger.info("WebSocket价格推送任务已添加，间隔: 5秒（仅交易时间）")
    
    # 4. 启动调度器
    scheduler.start()
    logger.info("========== 股票调度器启动完成 ==========")
    logger.info("定时任务:")
    logger.info(f"  - 实时数据更新: 每{realtime_interval}分钟（交易时间）")
    logger.info("  - 策略信号计算: 固定时间点（9:30/9:50/10:10/10:30/10:50/11:10/11:30/13:00/13:20/13:40/14:00/14:20/14:40/15:00/15:20，独立任务）")
    logger.info("  - WebSocket价格推送: 每5秒（仅交易时间）")
    logger.info("  - 新闻爬取: 每2小时")
    logger.info("  - 全量更新并计算信号: 每个交易日17:35")
    logger.info("  - 图表文件清理: 每天00:00")
    
    # 5. 在后台线程中执行启动任务（不阻塞调度器和API）
    def run_startup_tasks():
        """在后台线程中执行启动任务"""
        try:
            logger.info("========== 开始执行启动任务（后台） ==========")
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            try:
                loop.run_until_complete(
                    StartupTasks.execute(init_mode=init_mode, calculate_signals=calculate_signals)
                )
                logger.info("========== 启动任务执行完成 ==========")
            finally:
                loop.close()
        except Exception as e:
            logger.error(f"启动任务执行失败: {e}")
            import traceback
            logger.error(traceback.format_exc())
    
    # 启动后台任务
    import threading
    threading.Thread(target=run_startup_tasks, daemon=True, name="StartupTasksThread").start()
    logger.info("启动任务已在后台线程中执行，不阻塞API服务")


def stop_stock_scheduler():
    """停止股票调度器"""
    global scheduler
    
    if scheduler is not None and scheduler.running:
        scheduler.shutdown()
        scheduler = None
        logger.info("股票调度器已停止")
    else:
        logger.warning("股票调度器未运行")


def get_stock_scheduler_status() -> Dict[str, Any]:
    """获取调度器状态"""
    global scheduler, job_logs
    
    if scheduler is None:
        return {
            'running': False,
            'message': '调度器未启动'
        }
    
    jobs_info = []
    for job in scheduler.get_jobs():
        jobs_info.append({
            'id': job.id,
            'name': job.name,
            'next_run_time': job.next_run_time.isoformat() if job.next_run_time else None
        })
    
    return {
        'running': scheduler.running,
        'jobs': jobs_info,
        'recent_logs': job_logs[:10],
        'is_trading_time': is_trading_time()
    }

