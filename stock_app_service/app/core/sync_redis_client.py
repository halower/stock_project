# -*- coding: utf-8 -*-
"""同步Redis客户端 - 用于避免事件循环冲突"""

import redis
from app.core.config import settings
from app.core.logging import logger


# 全局同步Redis客户端实例
_sync_redis_client = None


def get_sync_redis_client():
    """获取同步Redis客户端 - 不依赖asyncio事件循环"""
    global _sync_redis_client
    
    if _sync_redis_client is None:
        try:
            _sync_redis_client = redis.Redis(
                host=settings.REDIS_HOST,
                port=settings.REDIS_PORT,
                password=settings.REDIS_PASSWORD,
                db=settings.REDIS_DB,
                decode_responses=True,
                retry_on_timeout=True,
                socket_connect_timeout=5,
                socket_timeout=5,
                max_connections=100  # 增加连接池大小以支持并发访问
            )
            
            # 测试连接
            _sync_redis_client.ping()
            logger.info("同步Redis客户端连接成功")
            
        except Exception as e:
            logger.error(f"同步Redis客户端连接失败: {e}")
            raise
    
    return _sync_redis_client


def close_sync_redis_client():
    """关闭同步Redis客户端"""
    global _sync_redis_client
    
    if _sync_redis_client:
        try:
            _sync_redis_client.close()
            logger.info("同步Redis客户端已关闭")
        except Exception as e:
            logger.error(f"关闭同步Redis客户端失败: {e}")
        finally:
            _sync_redis_client = None

