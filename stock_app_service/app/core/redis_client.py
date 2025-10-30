# -*- coding: utf-8 -*-
"""Redis异步客户端"""

import asyncio
import threading
import redis.asyncio as redis
from app.core.config import settings
from app.core.logging import logger


class RedisClientManager:
    """Redis客户端管理器 - 单例模式"""
    
    def __init__(self):
        self._clients = {}  # 每个事件循环一个客户端
        self._locks = {}    # 每个事件循环一个锁
        self._main_lock = threading.Lock()  # 使用线程锁而不是asyncio锁，避免事件循环绑定问题
        self._connection_pools = {}  # 每个事件循环一个连接池
    
    async def get_client(self):
        """获取Redis客户端实例 - 每个事件循环独立客户端"""
        max_retries = 3
        for attempt in range(max_retries):
            try:
                current_loop = asyncio.get_running_loop()
                loop_id = id(current_loop)
                
                # 使用线程锁保护并发访问
                with self._main_lock:
                    # 检查当前事件循环是否已有客户端
                    if loop_id not in self._clients:
                        # 创建事件循环专用锁（在当前事件循环中创建）
                        if loop_id not in self._locks:
                            self._locks[loop_id] = asyncio.Lock()
                        # 标记需要创建客户端
                        need_create = True
                    else:
                        need_create = False
                
                # 如果需要创建客户端，在锁外执行（避免死锁）
                if need_create:
                    await self._create_client_for_loop(loop_id)
                
                # 获取当前事件循环的客户端
                client = self._clients.get(loop_id)
                if client is None:
                    # 如果客户端不存在，重新创建
                    with self._main_lock:
                        if loop_id not in self._locks:
                            self._locks[loop_id] = asyncio.Lock()
                    await self._create_client_for_loop(loop_id)
                    client = self._clients.get(loop_id)
                
                # 检查连接是否有效（增加超时保护）
                if client:
                    try:
                        await asyncio.wait_for(client.ping(), timeout=5.0)
                        return client
                    except asyncio.TimeoutError:
                        logger.warning(f"Redis连接超时，重新创建: 事件循环 {loop_id}")
                        await self._recreate_client(loop_id)
                        client = self._clients.get(loop_id)
                        if client:
                            return client
                    except Exception as e:
                        logger.warning(f"Redis连接检查失败，重新创建: {e}")
                        await self._recreate_client(loop_id)
                        client = self._clients.get(loop_id)
                        if client:
                            return client
                        
            except Exception as e:
                logger.error(f"获取Redis客户端失败 (尝试 {attempt + 1}/{max_retries}): {e}")
                if attempt < max_retries - 1:
                    # 等待一段时间后重试
                    await asyncio.sleep(0.5 * (attempt + 1))
                    continue
                
                # 最后一次尝试失败，尝试重置连接管理器
                if "event loop" in str(e).lower() or "bound to a different" in str(e).lower():
                    logger.warning(f"检测到事件循环冲突，强制重置连接管理器")
                    await self._force_reset()
                    try:
                        current_loop = asyncio.get_running_loop()
                        loop_id = id(current_loop)
                        with self._main_lock:
                            if loop_id not in self._locks:
                                self._locks[loop_id] = asyncio.Lock()
                        await self._create_client_for_loop(loop_id)
                        return self._clients.get(loop_id)
                    except Exception as retry_error:
                        logger.error(f"重试创建Redis客户端失败: {retry_error}")
                        raise
                else:
                    raise
        
        # 如果所有重试都失败了，抛出异常
        raise Exception("Redis连接失败，已达到最大重试次数")
    
    async def _recreate_client(self, loop_id):
        """重新创建指定事件循环的客户端"""
        with self._main_lock:
            # 清理旧的客户端
            if loop_id in self._clients:
                try:
                    await self._clients[loop_id].close()
                except:
                    pass
                del self._clients[loop_id]
            
            # 确保有锁
            if loop_id not in self._locks:
                self._locks[loop_id] = asyncio.Lock()
        
        # 创建新客户端
        await self._create_client_for_loop(loop_id)
    
    async def _create_client_for_loop(self, loop_id):
        """为特定事件循环创建Redis客户端"""
        try:
            # 使用线程锁保护资源访问
            with self._main_lock:
                # 如果已有客户端，先关闭
                if loop_id in self._clients:
                    try:
                        await self._clients[loop_id].close()
                    except:
                        pass
                
                # 为当前事件循环创建或获取连接池
                if loop_id not in self._connection_pools:
                    self._connection_pools[loop_id] = redis.ConnectionPool(
                        host=settings.REDIS_HOST,
                        port=settings.REDIS_PORT,
                        password=settings.REDIS_PASSWORD,
                        db=settings.REDIS_DB,
                        decode_responses=True,
                        retry_on_timeout=True,
                        socket_connect_timeout=10,
                        socket_timeout=10,
                        max_connections=100,  # 增加连接池大小以支持并发访问
                        health_check_interval=30  # 健康检查间隔
                    )
                
                # 使用特定于循环的连接池创建新客户端
                client = redis.Redis(connection_pool=self._connection_pools[loop_id])
            
            # 测试连接（增加超时保护）
            await asyncio.wait_for(client.ping(), timeout=5.0)
            
            # 存储客户端
            with self._main_lock:
                self._clients[loop_id] = client
            
            logger.info(f"异步Redis连接成功 (事件循环: {loop_id})")
            
        except Exception as e:
            logger.error(f"异步Redis连接失败 (事件循环: {loop_id}): {e}")
            with self._main_lock:
                if loop_id in self._clients:
                    del self._clients[loop_id]
            raise
    
    async def _create_client(self):
        """创建Redis客户端 - 兼容旧方法"""
        current_loop = asyncio.get_running_loop()
        loop_id = id(current_loop)
        await self._create_client_for_loop(loop_id)
    
    async def _force_reset(self):
        """强制重置连接管理器"""
        try:
            # 获取当前状态的副本（避免在迭代时修改）
            clients_copy = {}
            pools_copy = {}
            
            with self._main_lock:
                clients_copy = self._clients.copy()
                pools_copy = self._connection_pools.copy()
                
                # 清空所有状态
                self._clients.clear()
                self._locks.clear()
                self._connection_pools.clear()
            
            # 关闭所有客户端（在锁外执行，避免死锁）
            for loop_id, client in clients_copy.items():
                try:
                    await client.close()
                except:
                    pass
            
            # 关闭所有连接池
            for loop_id, pool in pools_copy.items():
                try:
                    await pool.disconnect()
                except:
                    pass
            
            logger.info("连接管理器已强制重置")
        except Exception as e:
            logger.error(f"强制重置失败: {e}")
            # 即使失败也要清空状态
            with self._main_lock:
                self._clients.clear()
                self._locks.clear()
                self._connection_pools.clear()
    
    async def close(self):
        """关闭Redis连接"""
        try:
            # 获取当前状态的副本
            clients_copy = {}
            pools_copy = {}
            
            with self._main_lock:
                clients_copy = self._clients.copy()
                pools_copy = self._connection_pools.copy()
                
                # 清空所有状态
                self._clients.clear()
                self._locks.clear()
                self._connection_pools.clear()
            
            # 关闭所有客户端
            for loop_id, client in clients_copy.items():
                try:
                    await client.close()
                except:
                    pass
            
            # 关闭所有连接池
            for loop_id, pool in pools_copy.items():
                try:
                    await pool.disconnect()
                except:
                    pass
            
        except Exception as e:
            logger.error(f"关闭Redis连接失败: {e}")
            # 即使失败也要清空状态
            with self._main_lock:
                self._clients.clear()
                self._locks.clear()
                self._connection_pools.clear()


# 全局Redis客户端管理器实例
_redis_manager = RedisClientManager()


async def get_redis_client():
    """获取Redis客户端实例"""
    # 优先使用简化客户端避免事件循环冲突
    try:
        from app.core.simple_redis_client import get_simple_redis_client
        return await get_simple_redis_client()
    except Exception as e:
        logger.warning(f"简化客户端失败，回退到原客户端: {e}")
        # 确保在正确的事件循环中创建客户端
        try:
            current_loop = asyncio.get_running_loop()
            return await _redis_manager.get_client()
        except RuntimeError as loop_error:
            # 如果没有运行的事件循环，创建一个新的
            logger.error(f"事件循环错误: {loop_error}")
            raise Exception("无法获取Redis客户端：事件循环冲突")


async def close_redis_client():
    """关闭Redis客户端"""
    await _redis_manager.close() 