# -*- coding: utf-8 -*-
"""
WebSocket连接管理器

职责：
1. 管理WebSocket连接的生命周期
2. 维护活跃连接列表
3. 提供连接的增删查功能
4. 处理连接断开和清理
"""

from typing import Dict, List, Optional
from fastapi import WebSocket
from fastapi.websockets import WebSocketState
from datetime import datetime
import asyncio

from app.core.logging import logger
from app.models.websocket_models import ClientInfo, ConnectionStats


class ConnectionManager:
    """
    WebSocket连接管理器
    
    单例模式，全局唯一实例
    线程安全，支持并发访问
    """
    
    _instance = None
    _lock = asyncio.Lock()
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance
    
    def __init__(self):
        # 避免重复初始化
        if hasattr(self, '_initialized'):
            return
        
        # 活跃连接：{client_id: websocket}
        self._connections: Dict[str, WebSocket] = {}
        
        # 客户端信息：{client_id: ClientInfo}
        self._client_info: Dict[str, ClientInfo] = {}
        
        # 统计信息
        self._stats = ConnectionStats(
            total_connections=0,
            active_connections=0,
            total_subscriptions=0
        )
        
        self._initialized = True
        logger.info("WebSocket连接管理器初始化完成")
    
    async def connect(self, websocket: WebSocket, client_id: str) -> bool:
        """
        接受新的WebSocket连接
        
        Args:
            websocket: WebSocket连接对象
            client_id: 客户端唯一标识
            
        Returns:
            bool: 连接是否成功
        """
        try:
            # 接受连接
            await websocket.accept()
            
            # 如果客户端已存在，先断开旧连接
            if client_id in self._connections:
                logger.warning(f"客户端 {client_id} 重复连接，断开旧连接")
                await self.disconnect(client_id)
            
            # 保存连接
            self._connections[client_id] = websocket
            
            # 保存客户端信息
            self._client_info[client_id] = ClientInfo(
                client_id=client_id,
                connected_at=datetime.now()
            )
            
            # 更新统计
            self._stats.total_connections += 1
            self._stats.active_connections = len(self._connections)
            
            logger.info(
                f"WebSocket连接成功: {client_id}, "
                f"当前活跃连接数: {self._stats.active_connections}"
            )
            
            return True
            
        except Exception as e:
            logger.error(f"WebSocket连接失败: {client_id}, 错误: {e}")
            return False
    
    async def disconnect(self, client_id: str, reason: str = "正常断开") -> bool:
        """
        断开WebSocket连接
        
        Args:
            client_id: 客户端ID
            reason: 断开原因
            
        Returns:
            bool: 是否成功断开
        """
        try:
            # 关闭连接
            if client_id in self._connections:
                websocket = self._connections[client_id]
                
                # 只有在连接状态下才尝试关闭
                if websocket.client_state == WebSocketState.CONNECTED:
                    try:
                        await websocket.close()
                    except Exception as e:
                        logger.warning(f"关闭WebSocket连接时出错: {e}")
                
                del self._connections[client_id]
            
            # 清理客户端信息
            if client_id in self._client_info:
                del self._client_info[client_id]
            
            # 更新统计
            self._stats.active_connections = len(self._connections)
            
            logger.info(
                f"WebSocket连接断开: {client_id}, 原因: {reason}, "
                f"剩余连接数: {self._stats.active_connections}"
            )
            
            return True
            
        except Exception as e:
            logger.error(f"断开WebSocket连接失败: {client_id}, 错误: {e}")
            return False
    
    async def send_message(self, client_id: str, message: dict) -> bool:
        """
        向指定客户端发送消息
        
        Args:
            client_id: 客户端ID
            message: 消息内容（字典）
            
        Returns:
            bool: 是否发送成功
        """
        if client_id not in self._connections:
            logger.warning(f"客户端 {client_id} 不存在，无法发送消息")
            return False
        
        websocket = self._connections[client_id]
        
        try:
            # 检查连接状态
            if websocket.client_state != WebSocketState.CONNECTED:
                logger.warning(f"客户端 {client_id} 连接已断开")
                await self.disconnect(client_id, "连接已断开")
                return False
            
            # 发送消息
            await websocket.send_json(message)
            
            # 更新统计
            self._stats.messages_sent += 1
            
            return True
            
        except Exception as e:
            logger.error(f"发送消息失败: {client_id}, 错误: {e}")
            await self.disconnect(client_id, f"发送失败: {e}")
            return False
    
    async def broadcast(self, message: dict, exclude: Optional[List[str]] = None) -> int:
        """
        广播消息到所有连接的客户端
        
        Args:
            message: 消息内容
            exclude: 排除的客户端ID列表
            
        Returns:
            int: 成功发送的数量
        """
        exclude = exclude or []
        success_count = 0
        failed_clients = []
        
        # 获取所有客户端ID（避免在迭代时修改字典）
        client_ids = list(self._connections.keys())
        
        for client_id in client_ids:
            if client_id in exclude:
                continue
            
            if await self.send_message(client_id, message):
                success_count += 1
            else:
                failed_clients.append(client_id)
        
        # 清理失败的连接
        for client_id in failed_clients:
            await self.disconnect(client_id, "广播失败")
        
        logger.debug(
            f"广播消息完成: 成功 {success_count}/{len(client_ids)}, "
            f"失败 {len(failed_clients)}"
        )
        
        return success_count
    
    def get_client_info(self, client_id: str) -> Optional[ClientInfo]:
        """获取客户端信息"""
        return self._client_info.get(client_id)
    
    def get_all_clients(self) -> List[ClientInfo]:
        """获取所有客户端信息"""
        return list(self._client_info.values())
    
    def is_connected(self, client_id: str) -> bool:
        """检查客户端是否连接"""
        return client_id in self._connections
    
    def get_connection_count(self) -> int:
        """获取当前连接数"""
        return len(self._connections)
    
    def get_stats(self) -> ConnectionStats:
        """获取连接统计信息"""
        self._stats.active_connections = len(self._connections)
        return self._stats
    
    async def update_last_ping(self, client_id: str):
        """更新客户端最后心跳时间"""
        if client_id in self._client_info:
            self._client_info[client_id].last_ping = datetime.now()
    
    async def cleanup_inactive_connections(self, timeout_seconds: int = 300):
        """
        清理不活跃的连接
        
        Args:
            timeout_seconds: 超时时间（秒），默认5分钟
        """
        now = datetime.now()
        inactive_clients = []
        
        for client_id, info in self._client_info.items():
            # 如果从未收到心跳，使用连接时间
            last_active = info.last_ping or info.connected_at
            inactive_seconds = (now - last_active).total_seconds()
            
            if inactive_seconds > timeout_seconds:
                inactive_clients.append(client_id)
        
        # 断开不活跃的连接
        for client_id in inactive_clients:
            await self.disconnect(client_id, f"超时未活跃（{timeout_seconds}秒）")
        
        if inactive_clients:
            logger.info(f"清理了 {len(inactive_clients)} 个不活跃连接")


# 全局单例实例
connection_manager = ConnectionManager()

