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
    判断是否为交易时间（包括盘后30分钟）
    
    交易时间: 9:30-11:30, 13:00-15:00
    盘后时间: 15:00-15:30
    """
    now = datetime.now()
    
    # 周末不交易
    if now.weekday() >= 5:
        return False
    
    current_time = now.time()
    
    # 上午交易时间
    morning_start = time(9, 30)
    morning_end = time(11, 30)
    
    # 下午交易时间
    afternoon_start = time(13, 0)
    afternoon_end = time(15, 0)
    
    # 盘后时间（15:00-15:30）
    after_close_end = time(15, 30)
    
    return (
        (morning_start <= current_time <= morning_end) or
        (afternoon_start <= current_time <= after_close_end)
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
                - full_init: 全量初始化
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
            if init_mode == "full_init":
                await StartupTasks.task_full_init()
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
    async def task_full_init():
        """任务：全量初始化"""
        logger.info(">>> 执行任务: 全量初始化所有股票数据")
        start_time = datetime.now()
        
        try:
            result = await stock_atomic_service.full_update_all_stocks(
                days=180,
                batch_size=50,
                max_concurrent=5  # 降低并发数，从10降到5，减少API限流
            )
            
            elapsed = (datetime.now() - start_time).total_seconds()
            logger.info(
                f">>> 任务完成: 全量初始化完成，"
                f"成功={result['success_count']}, "
                f"失败={result['failed_count']}, "
                f"耗时 {elapsed:.2f}秒"
            )
            
            add_job_log(
                'full_init',
                'success',
                f"全量初始化完成，成功={result['success_count']}, 失败={result['failed_count']}",
                **result
            )
            
        except Exception as e:
            logger.error(f">>> 任务失败: 全量初始化失败: {e}")
            add_job_log('full_init', 'error', f'全量初始化失败: {str(e)}')
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
            
            add_job_log(
                'calculate_signals',
                'success' if result.get('success') else 'error',
                f"计算信号完成",
                **result
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
        """定时任务：实时更新所有股票数据"""
        # 检查是否为交易时间
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
                result = loop.run_until_complete(
                    stock_atomic_service.realtime_update_all_stocks()
                )
                
                elapsed = (datetime.now() - start_time).total_seconds()
                logger.info(f"========== 实时数据更新完成，耗时 {elapsed:.2f}秒 ==========")
                
                add_job_log(
                    'realtime_update',
                    'success',
                    f'实时数据更新完成',
                    elapsed_seconds=round(elapsed, 2),
                    **result
                )
                
                # 实时更新后自动触发信号计算
                RuntimeTasks.job_calculate_signals_after_update()
                
            finally:
                loop.close()
                
        except Exception as e:
            logger.error(f"实时数据更新失败: {e}")
            import traceback
            logger.error(traceback.format_exc())
            add_job_log('realtime_update', 'error', f'实时数据更新失败: {str(e)}')
        finally:
            _task_locks['realtime_update'].release()
    
    @staticmethod
    def job_calculate_signals_after_update():
        """实时更新后自动触发信号计算"""
        # 防止重复执行
        if not _task_locks['signal_calculation'].acquire(blocking=False):
            logger.warning("信号计算任务正在执行中，跳过本次")
            return
        
        try:
            logger.info(">>> 实时更新后触发信号计算")
            start_time = datetime.now()
            
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            
            try:
                result = loop.run_until_complete(
                    stock_atomic_service.calculate_strategy_signals(force_recalculate=False)
                )
                
                elapsed = (datetime.now() - start_time).total_seconds()
                logger.info(f">>> 信号计算完成，耗时 {elapsed:.2f}秒")
                
            finally:
                loop.close()
                
        except Exception as e:
            logger.error(f"信号计算失败: {e}")
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
                # 1. 全量更新（降低并发数）
                update_result = loop.run_until_complete(
                    stock_atomic_service.full_update_all_stocks(
                        days=180,
                        batch_size=50,
                        max_concurrent=5  # 降低并发数，减少API限流
                    )
                )
                
                logger.info(f"全量更新完成: 成功={update_result['success_count']}, 失败={update_result['failed_count']}")
                
                # 2. 计算信号
                signal_result = loop.run_until_complete(
                    stock_atomic_service.calculate_strategy_signals(force_recalculate=True)
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


# ==================== 调度器管理 ====================

def start_stock_scheduler(init_mode: str = "skip", calculate_signals: bool = False):
    """
    启动股票调度器
    
    Args:
        init_mode: 初始化模式
            - skip: 跳过初始化
            - full_init: 全量初始化
        calculate_signals: 是否在启动时计算信号
    """
    global scheduler
    
    if scheduler is not None and scheduler.running:
        logger.warning("股票调度器已在运行中")
        return
    
    logger.info("========== 启动股票调度器 ==========")
    logger.info(f"初始化模式: {init_mode}")
    logger.info(f"启动时计算信号: {calculate_signals}")
    
    # 1. 执行启动任务
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    try:
        loop.run_until_complete(
            StartupTasks.execute(init_mode=init_mode, calculate_signals=calculate_signals)
        )
    finally:
        loop.close()
    
    # 2. 创建调度器
    scheduler = BackgroundScheduler(timezone='Asia/Shanghai')
    
    # 3. 添加运行时任务
    
    # 实时数据更新：交易时间+盘后30分钟内每20分钟执行一次
    scheduler.add_job(
        func=RuntimeTasks.job_realtime_update,
        trigger=IntervalTrigger(minutes=20),
        id='realtime_update',
        name='实时数据更新',
        replace_existing=True
    )
    
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
    
    # 4. 启动调度器
    scheduler.start()
    logger.info("========== 股票调度器启动完成 ==========")
    logger.info("定时任务:")
    logger.info("  - 实时数据更新: 每20分钟（交易时间+盘后30分钟）")
    logger.info("  - 新闻爬取: 每2小时")
    logger.info("  - 全量更新并计算信号: 每个交易日17:35")
    logger.info("  - 图表文件清理: 每天00:00")


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

