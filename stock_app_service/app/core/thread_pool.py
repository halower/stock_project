# -*- coding: utf-8 -*-
"""
全局线程池管理模块（已废弃 - 保留空实现以兼容旧代码）
现在使用纯异步IO，不再需要线程池
"""
import asyncio
import logging

logger = logging.getLogger(__name__)

class GlobalThreadPool:
    """空实现 - 仅用于向后兼容，实际不使用线程池"""
    
    _instance = None
    
    @classmethod
    def get_instance(cls):
        """获取单例实例"""
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance
    
    def __init__(self):
        """空初始化"""
        logger.info("✅ 纯异步IO模式，无需线程池")
    
    async def acquire_thread(self):
        """空方法 - 向后兼容"""
        pass
    
    def release_thread(self):
        """空方法 - 向后兼容"""
        pass
    
    async def get_status(self):
        """返回状态"""
        return {
            "mode": "pure_async_io",
            "message": "纯异步IO模式，无线程池"
        }

# 全局线程池实例（空实现）
global_thread_pool = GlobalThreadPool.get_instance()
