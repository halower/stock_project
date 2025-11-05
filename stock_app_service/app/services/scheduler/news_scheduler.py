# -*- coding: utf-8 -*-
"""
简化的新闻调度服务
使用APScheduler替代Celery，提供更简单直接的定时任务解决方案
"""

import asyncio
import threading
from datetime import datetime, timedelta
from typing import Dict, Any, List
from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger
from apscheduler.triggers.interval import IntervalTrigger

from app.core.logging import logger
from app.db.session import RedisCache
from app.services.analysis.news_analysis_service import get_phoenix_finance_news

# Redis缓存客户端
redis_cache = RedisCache()

# 调度器实例
scheduler = None
job_logs = []  # 存储最近的任务执行日志

# Redis键名规则
NEWS_KEYS = {
    'news_latest': 'news:latest',           # 最新新闻列表
    'news_scheduler_log': 'news:scheduler:log',  # 调度器日志
    'news_last_update': 'news:last_update',     # 最后更新时间
}

def add_job_log(status: str, message: str, news_count: int = 0, execution_time: float = 0.0):
    """添加任务执行日志"""
    log_entry = {
        'timestamp': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
        'status': status,
        'message': message,
        'news_count': news_count,
        'execution_time': round(execution_time, 2)
    }
    
    # 内存日志（最近10条）
    global job_logs
    job_logs.insert(0, log_entry)
    job_logs = job_logs[:10]
    
    # Redis日志（最近20条）
    redis_logs = redis_cache.get_cache(NEWS_KEYS['news_scheduler_log']) or []
    redis_logs.insert(0, log_entry)
    redis_logs = redis_logs[:20]
    redis_cache.set_cache(NEWS_KEYS['news_scheduler_log'], redis_logs, ttl=86400)
    
    logger.info(f"{message}")

def crawl_and_cache_news():
    """
    爬取并缓存新闻数据
    """
    start_time = datetime.now()
    
    try:
        logger.info("开始执行新闻爬取任务...")
        
        # 爬取新闻数据
        news_list = get_phoenix_finance_news(days=1, skip_content=False, force_crawl=True)
        
        # 数据质量检查
        if not news_list or len(news_list) < 5:
            logger.warning(f"爬取到的新闻数据质量不佳，数量: {len(news_list)}")
            
            # 检查是否有现有缓存
            existing_news = redis_cache.get_cache(NEWS_KEYS['news_latest'])
            if existing_news:
                add_job_log(
                    'skipped', 
                    f'数据质量不佳({len(news_list)}条)，保持现有缓存', 
                    len(news_list)
                )
                return
        
        # 格式化新闻数据
        formatted_news = []
        for news in news_list:
            formatted_news.append({
                'title': news['title'],
                'url': news['url'],
                'datetime': news['datetime'],
                'source': news['source'],
                'summary': news.get('content', '')[:150] + '...' if news.get('content') and len(news.get('content')) > 150 else news.get('content', '')
            })
        
        # 准备缓存数据
        cache_data = {
            'news': formatted_news,
            'count': len(formatted_news),
            'updated_at': start_time.strftime('%Y-%m-%d %H:%M:%S'),
            'data_source': 'phoenix_finance',
            'scheduler': 'apscheduler'
        }
        
        # 原子性更新缓存（旧缓存自动失效）
        redis_cache.set_cache(NEWS_KEYS['news_latest'], cache_data, ttl=14400)  # 4小时过期
        redis_cache.set_cache(NEWS_KEYS['news_last_update'], start_time.isoformat(), ttl=86400)
        
        execution_time = (datetime.now() - start_time).total_seconds()
        
        add_job_log(
            'success',
            f'成功爬取并缓存 {len(formatted_news)} 条新闻',
            len(formatted_news),
            execution_time
        )
        
        logger.info(f"新闻爬取任务完成，耗时: {execution_time:.2f}秒")
        
    except Exception as e:
        execution_time = (datetime.now() - start_time).total_seconds()
        error_message = f"新闻爬取失败: {str(e)}"
        
        add_job_log('failed', error_message, 0, execution_time)
        logger.error(f"{error_message}")

def cleanup_old_logs():
    """清理过期日志"""
    try:
        # 清理Redis中过期的日志（保留最近30天）
        cutoff_date = datetime.now() - timedelta(days=30)
        redis_logs = redis_cache.get_cache(NEWS_KEYS['news_scheduler_log']) or []
        
        filtered_logs = []
        for log in redis_logs:
            try:
                log_time = datetime.strptime(log['timestamp'], '%Y-%m-%d %H:%M:%S')
                if log_time > cutoff_date:
                    filtered_logs.append(log)
            except:
                continue
        
        if len(filtered_logs) != len(redis_logs):
            redis_cache.set_cache(NEWS_KEYS['news_scheduler_log'], filtered_logs, ttl=86400)
            logger.info(f"清理了 {len(redis_logs) - len(filtered_logs)} 条过期日志")
        
    except Exception as e:
        logger.error(f"清理日志失败: {str(e)}")

def start_news_scheduler():
    """启动新闻调度器"""
    global scheduler
    
    if scheduler and scheduler.running:
        logger.warning("调度器已经在运行中")
        return
    
    try:
        # 创建后台调度器
        scheduler = BackgroundScheduler(
            timezone='Asia/Shanghai',
            job_defaults={
                'coalesce': True,  # 合并未执行的任务
                'max_instances': 1,  # 同时只运行一个实例
                'misfire_grace_time': 300  # 5分钟的容错时间
            }
        )
        
        # 添加新闻爬取任务 - 每3小时执行一次
        scheduler.add_job(
            func=crawl_and_cache_news,
            trigger=CronTrigger(minute=0, second=0, hour='0,3,6,9,12,15,18,21'),
            id='crawl_news',
            name='爬取凤凰财经新闻',
            replace_existing=True
        )
        
        # 添加日志清理任务 - 每天凌晨3点执行
        scheduler.add_job(
            func=cleanup_old_logs,
            trigger=CronTrigger(hour=3, minute=0, second=0),
            id='cleanup_logs',
            name='清理过期日志',
            replace_existing=True
        )
        
        # 启动调度器
        scheduler.start()
        
        # 立即执行一次新闻爬取
        logger.info("启动时立即执行首次新闻爬取...")
        threading.Thread(target=crawl_and_cache_news, daemon=True).start()
        
        logger.info("新闻调度器启动成功")
        logger.info("定时任务: 每3小时爬取新闻，每天3点清理日志")
        logger.info("首次爬取: 启动时立即执行")
        
    except Exception as e:
        logger.error(f"启动调度器失败: {str(e)}")

def stop_news_scheduler():
    """停止新闻调度器"""
    global scheduler
    
    if scheduler and scheduler.running:
        scheduler.shutdown(wait=False)
        logger.info("新闻调度器已停止")
    else:
        logger.info("调度器未运行")

def get_scheduler_status() -> Dict[str, Any]:
    """获取调度器状态"""
    global scheduler, job_logs
    
    try:
        if not scheduler:
            return {
                'running': False,
                'error': '调度器未初始化'
            }
        
        # 获取任务信息
        jobs_info = []
        if scheduler.running:
            for job in scheduler.get_jobs():
                next_run = job.next_run_time
                jobs_info.append({
                    'id': job.id,
                    'name': job.name,
                    'next_run': next_run.strftime('%Y-%m-%d %H:%M:%S') if next_run else None,
                    'trigger': str(job.trigger)
                })
        
        # 获取缓存状态
        cached_news = redis_cache.get_cache(NEWS_KEYS['news_latest'])
        last_update = redis_cache.get_cache(NEWS_KEYS['news_last_update'])
        
        return {
            'running': scheduler.running if scheduler else False,
            'jobs': jobs_info,
            'recent_logs': job_logs[:5],  # 最近5次日志
            'cache_status': {
                'exists': cached_news is not None,
                'news_count': cached_news.get('count', 0) if cached_news else 0,
                'last_update': last_update,
                'data_source': cached_news.get('data_source') if cached_news else None
            },
            'scheduler_type': 'APScheduler',
            'description': '轻量级调度器，启动时立即执行，每2小时定时更新'
        }
        
    except Exception as e:
        return {
            'running': False,
            'error': str(e)
        }

def crawl_with_params(force_crawl=True):
    """带参数的爬取函数，用于线程调用"""
    crawl_and_cache_news()

def trigger_immediate_crawl(force_crawl=True) -> Dict[str, Any]:
    """立即触发一次新闻爬取"""
    try:
        logger.info("手动触发新闻爬取...")
        threading.Thread(target=crawl_and_cache_news, daemon=True).start()
        
        return {
            'success': True,
            'message': '新闻爬取任务已触发',
            'triggered_at': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        }
    except Exception as e:
        return {
            'success': False,
            'message': f'触发失败: {str(e)}'
        } 