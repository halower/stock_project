# -*- coding: utf-8 -*-
"""Redis数据存储管理 - 完全基于Redis架构"""

import redis
from app.core.config import (
    REDIS_HOST, REDIS_PORT, REDIS_DB, REDIS_PASSWORD,
    REDIS_MAX_CONNECTIONS, REDIS_SOCKET_CONNECT_TIMEOUT, REDIS_SOCKET_TIMEOUT
)
from app.core.logging import logger
import json
from typing import Optional, Any
import asyncio

# 移除SQLAlchemy相关组件，完全使用Redis
# 原因：用户指出SQLite在Linux环境下有多线程限制，且股票数据每天更新，Redis更适合

logger.info("数据存储架构: 完全基于Redis，无关系数据库依赖")

# Redis缓存客户端
class RedisCache:
    """Redis缓存管理器"""
    
    def __init__(self):
        self.redis_client = None
        # 延迟初始化Redis连接，避免启动时连接失败
        # 连接将在第一次使用时建立
        
    def get_redis_client(self):
        """获取同步Redis客户端"""
        if self.redis_client is None:
            try:
                self.redis_client = redis.Redis(
                    host=REDIS_HOST,
                    port=REDIS_PORT,
                    db=REDIS_DB,
                    password=REDIS_PASSWORD,
                    decode_responses=True,
                    socket_connect_timeout=REDIS_SOCKET_CONNECT_TIMEOUT,
                    socket_timeout=REDIS_SOCKET_TIMEOUT,
                    retry_on_timeout=True,
                    max_connections=REDIS_MAX_CONNECTIONS
                )
                # 测试连接
                self.redis_client.ping()
                logger.info("Redis客户端连接成功")
            except Exception as e:
                logger.warning(f"Redis客户端连接失败: {e}，将在需要时重试")
                self.redis_client = None
        return self.redis_client
    
    async def get_async_redis_client(self):
        """
        获取异步Redis客户端。
        使用redis-py的异步客户端替代aioredis。
        """
        import redis.asyncio as aioredis
        redis_url = f"redis://{REDIS_HOST}:{REDIS_PORT}/{REDIS_DB}"
        if REDIS_PASSWORD:
            redis_url = f"redis://:{REDIS_PASSWORD}@{REDIS_HOST}:{REDIS_PORT}/{REDIS_DB}"
        
        return aioredis.from_url(
            redis_url,
            encoding='utf-8',
            decode_responses=True
        )
    
    def set_cache(self, key: str, value: Any, ttl: int = 3600) -> bool:
        """设置缓存"""
        try:
            client = self.get_redis_client()
            if client is None:
                logger.warning(f"Redis客户端未连接，跳过设置缓存: {key}")
                return False
                
            if isinstance(value, (dict, list)):
                value = json.dumps(value, ensure_ascii=False)
            
            # 如果ttl为None，使用set方法进行永久存储
            if ttl is None:
                return client.set(key, value)
            else:
                return client.setex(key, ttl, value)
        except Exception as e:
            logger.error(f"Redis设置缓存失败: {key}, 错误: {e}")
            return False
    
    def get_cache(self, key: str) -> Optional[Any]:
        """获取缓存"""
        try:
            client = self.get_redis_client()
            if client is None:
                logger.warning(f"Redis客户端未连接，跳过获取缓存: {key}")
                return None
                
            value = client.get(key)
            if value is None:
                return None
            
            # 尝试解析JSON
            try:
                return json.loads(value)
            except (json.JSONDecodeError, TypeError):
                return value
        except Exception as e:
            logger.error(f"Redis获取缓存失败: {key}, 错误: {e}")
            return None
    
    def delete_cache(self, key: str) -> bool:
        """删除缓存"""
        try:
            client = self.get_redis_client()
            if client is None:
                logger.warning(f"Redis客户端未连接，跳过删除缓存: {key}")
                return False
            return bool(client.delete(key))
        except Exception as e:
            logger.error(f"Redis删除缓存失败: {key}, 错误: {e}")
            return False
    
    def delete_pattern(self, pattern: str) -> int:
        """按模式删除缓存"""
        try:
            client = self.get_redis_client()
            if client is None:
                logger.warning(f"Redis客户端未连接，跳过按模式删除: {pattern}")
                return 0
            keys = client.keys(pattern)
            if keys:
                return client.delete(*keys)
            return 0
        except Exception as e:
            logger.error(f"Redis按模式删除缓存失败: {pattern}, 错误: {e}")
            return 0

# 全局缓存实例
cache = RedisCache()

def get_redis_storage():
    """获取Redis存储实例 - 替代传统数据库会话"""
    # 延迟导入避免循环导入
    try:
        from app.db.redis_storage import redis_storage
        return redis_storage
    except ImportError as e:
        logger.error(f"Redis存储模块导入失败: {e}")
        return None

async def init_redis_connection():
    """初始化Redis连接"""
    try:
        # 使用同步客户端测试连接，避免异步客户端问题
        cache.get_redis_client().ping()
        logger.info("Redis连接初始化成功")
    except Exception as e:
        logger.error(f"Redis连接初始化失败: {e}")

def test_redis_connection() -> bool:
    """测试Redis连接"""
    try:
        client = cache.get_redis_client()
        if client is None:
            logger.warning("Redis客户端未连接，连接测试失败")
            return False
        client.ping()
        logger.info("Redis连接测试成功")
        return True
    except Exception as e:
        logger.warning(f"Redis连接测试失败: {e}")
        return False

def get_redis_db():
    """获取Redis存储实例 - 替代get_db依赖（非阻塞版本）"""
    try:
        from app.db.redis_storage import redis_storage
        # 不测试连接，直接返回实例，连接测试在实际使用时进行
        return redis_storage if redis_storage else None
    except Exception as e:
        logger.error(f"获取Redis存储失败: {e}")
        return None

# 兼容性函数 - 返回Redis存储实例
def get_db():
    """兼容性函数 - 返回Redis存储实例"""
    return get_redis_db()