# -*- coding: utf-8 -*-
"""
全局线程池管理模块
用于控制整个应用的线程使用，避免线程数超出限制
"""
import asyncio
import logging
from app.core.config import settings

logger = logging.getLogger(__name__)

class GlobalThreadPool:
    """数据获取专用线程池，仅用于股票数据获取任务，不影响API服务"""
    
    _instance = None
    
    @classmethod
    def get_instance(cls):
        """获取单例实例"""
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance
    
    def __init__(self):
        """初始化线程池"""
        self.max_threads = settings.GLOBAL_THREAD_POOL_SIZE
        self.active_threads = 0
        self.semaphore = asyncio.Semaphore(self.max_threads)
        self.lock = asyncio.Lock()
        logger.info(f"数据获取专用线程池初始化，最大线程数: {self.max_threads}（不影响API服务）")
    
    async def acquire_thread(self):
        """获取线程资源"""
        await self.semaphore.acquire()
        async with self.lock:
            self.active_threads += 1
            logger.debug(f"获取线程资源，当前活跃线程: {self.active_threads}/{self.max_threads}")
        return self.active_threads
    
    def release_thread(self):
        """释放线程资源"""
        if self.active_threads > 0:
            self.active_threads -= 1
            logger.debug(f"释放线程资源，当前活跃线程: {self.active_threads}/{self.max_threads}")
        self.semaphore.release()
    
    async def get_status(self):
        """获取线程池状态"""
        return {
            "max_threads": self.max_threads,
            "active_threads": self.active_threads,
            "available_threads": self.max_threads - self.active_threads
        }

# 全局线程池实例
global_thread_pool = GlobalThreadPool.get_instance()
