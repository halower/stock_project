# -*- coding: utf-8 -*-
"""定时任务调度器"""

import os
import glob
import logging
from datetime import datetime, timedelta
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
from app.core.config import STATIC_DIR

logger = logging.getLogger(__name__)

class TaskScheduler:
    """定时任务调度器"""
    
    def __init__(self):
        self.scheduler = AsyncIOScheduler()
        self._setup_jobs()
    
    def _setup_jobs(self):
        """设置定时任务"""
        # 每天00:00清理图表文件
        self.scheduler.add_job(
            func=self.cleanup_chart_files,
            trigger=CronTrigger(hour=0, minute=0),
            id='cleanup_charts',
            name='清理图表文件',
            replace_existing=True
        )
        
        # 可以添加更多定时任务
        # self.scheduler.add_job(
        #     func=self.other_task,
        #     trigger=CronTrigger(hour=6, minute=0),
        #     id='other_task',
        #     name='其他任务'
        # )
    
    async def cleanup_chart_files(self):
        """清理图表文件"""
        try:
            charts_dir = os.path.join(STATIC_DIR, 'charts')
            if not os.path.exists(charts_dir):
                logger.info("图表目录不存在，跳过清理")
                return
            
            # 获取所有HTML文件
            html_files = glob.glob(os.path.join(charts_dir, '*.html'))
            
            if not html_files:
                logger.info("没有找到需要清理的图表文件")
                return
            
            # 删除所有HTML文件
            deleted_count = 0
            for file_path in html_files:
                try:
                    os.remove(file_path)
                    deleted_count += 1
                    logger.debug(f"已删除图表文件: {os.path.basename(file_path)}")
                except Exception as e:
                    logger.error(f"删除文件失败 {file_path}: {e}")
            
            logger.info(f"图表文件清理完成，共删除 {deleted_count} 个文件")
            
        except Exception as e:
            logger.error(f"清理图表文件时发生错误: {e}")
    
    async def cleanup_old_chart_files(self, days_old: int = 1):
        """清理指定天数之前的图表文件"""
        try:
            charts_dir = os.path.join(STATIC_DIR, 'charts')
            if not os.path.exists(charts_dir):
                return
            
            cutoff_time = datetime.now() - timedelta(days=days_old)
            html_files = glob.glob(os.path.join(charts_dir, '*.html'))
            
            deleted_count = 0
            for file_path in html_files:
                try:
                    file_mtime = datetime.fromtimestamp(os.path.getmtime(file_path))
                    if file_mtime < cutoff_time:
                        os.remove(file_path)
                        deleted_count += 1
                        logger.debug(f"已删除过期图表文件: {os.path.basename(file_path)}")
                except Exception as e:
                    logger.error(f"删除过期文件失败 {file_path}: {e}")
            
            if deleted_count > 0:
                logger.info(f"过期图表文件清理完成，共删除 {deleted_count} 个文件")
            
        except Exception as e:
            logger.error(f"清理过期图表文件时发生错误: {e}")
    
    def start(self):
        """启动调度器"""
        if not self.scheduler.running:
            self.scheduler.start()
            logger.info("定时任务调度器已启动")
            
            # 显示图表清理任务信息
            next_cleanup = self.get_next_cleanup_time()
            if next_cleanup:
                logger.info(f"图表文件自动清理任务已设置，下次执行时间: {next_cleanup}")
            else:
                logger.warning("图表清理任务未正确设置")
    
    def shutdown(self):
        """关闭调度器"""
        if self.scheduler.running:
            self.scheduler.shutdown()
            logger.info("定时任务调度器已关闭")
    
    def get_next_cleanup_time(self):
        """获取下次清理时间"""
        jobs = self.scheduler.get_jobs()
        cleanup_job = next((job for job in jobs if job.id == 'cleanup_charts'), None)
        if cleanup_job and cleanup_job.next_run_time:
            return cleanup_job.next_run_time.isoformat()
        return None

# 全局调度器实例
scheduler = TaskScheduler() 