# -*- coding: utf-8 -*-
"""简化的Redis异步客户端 - 避免复杂的锁机制"""

import asyncio
import redis.asyncio as redis
from app.core.config import settings
from app.core.logging import logger


# 全局Redis客户端实例
_redis_client = None
_client_lock = None


async def get_simple_redis_client():
    """获取简化的Redis客户端，避免复杂的锁机制"""
    global _redis_client, _client_lock
    
    # 延迟初始化锁，确保在正确的事件循环中创建
    if _client_lock is None:
        try:
            _client_lock = asyncio.Lock()
        except RuntimeError:
            # 如果没有运行的事件循环，直接创建客户端
            pass
    
    if _redis_client is None:
        # 如果有锁就使用，没有就直接创建
        if _client_lock:
            async with _client_lock:
                if _redis_client is None:
                    _redis_client = await _create_redis_client()
        else:
            _redis_client = await _create_redis_client()
    
    return _redis_client

async def _create_redis_client():
    """创建Redis客户端的内部函数"""
    try:
        # 创建简单的Redis客户端
        client = redis.Redis(
            host=settings.REDIS_HOST,
            port=settings.REDIS_PORT,
            password=settings.REDIS_PASSWORD,
            db=settings.REDIS_DB,
            decode_responses=True,
            retry_on_timeout=True,
            socket_connect_timeout=5,  # 减少连接超时
            socket_timeout=5,          # 减少操作超时
            max_connections=20,        # 减少连接池大小
            health_check_interval=30
        )
        
        # 测试连接
        await asyncio.wait_for(client.ping(), timeout=3)
        logger.info("简化Redis客户端连接成功")
        
        return client
        
    except Exception as e:
        logger.error(f"简化Redis客户端连接失败: {e}")
        raise


async def close_simple_redis_client():
    """关闭简化Redis客户端"""
    global _redis_client
    
    if _redis_client:
        try:
            await _redis_client.close()
            logger.info("简化Redis客户端已关闭")
        except Exception as e:
            logger.error(f"关闭简化Redis客户端失败: {e}")
        finally:
            _redis_client = None
