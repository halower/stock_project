# -*- coding: utf-8 -*-
"""
WebSocket消息处理器

职责：
1. 处理客户端发送的各类消息
2. 路由消息到对应的处理函数
3. 验证消息格式
4. 生成响应消息
"""

from typing import Dict, Any, Optional
from fastapi import WebSocket

from app.core.logging import logger
from app.models.websocket_models import (
    MessageType,
    SubscriptionType,
    SubscribeMessage,
    UnsubscribeMessage,
    SubscribedMessage,
    UnsubscribedMessage,
    PongMessage,
    ErrorMessage
)
from app.services.websocket.connection_manager import connection_manager
from app.services.websocket.subscription_manager import subscription_manager


class MessageHandler:
    """
    WebSocket消息处理器
    
    处理客户端发送的各类消息并生成响应
    """
    
    def __init__(self):
        # 消息处理器映射
        self._handlers = {
            MessageType.SUBSCRIBE: self._handle_subscribe,
            MessageType.UNSUBSCRIBE: self._handle_unsubscribe,
            MessageType.PING: self._handle_ping,
        }
    
    async def handle_message(
        self, 
        client_id: str, 
        message: Dict[str, Any]
    ) -> Optional[Dict[str, Any]]:
        """
        处理客户端消息
        
        Args:
            client_id: 客户端ID
            message: 消息内容
            
        Returns:
            Optional[Dict]: 响应消息，如果不需要响应则返回None
        """
        try:
            # 获取消息类型
            message_type = message.get("type")
            
            if not message_type:
                return self._error_response("消息缺少type字段")
            
            # 查找处理器
            handler = self._handlers.get(message_type)
            
            if not handler:
                return self._error_response(f"不支持的消息类型: {message_type}")
            
            # 调用处理器
            return await handler(client_id, message)
            
        except Exception as e:
            logger.error(f"处理消息失败: {client_id}, 错误: {e}")
            return self._error_response(f"处理消息失败: {str(e)}")
    
    async def _handle_subscribe(
        self, 
        client_id: str, 
        message: Dict[str, Any]
    ) -> Dict[str, Any]:
        """
        处理订阅消息
        
        消息格式：
        {
            "type": "subscribe",
            "subscription_type": "strategy",  // strategy/stock/market
            "target": "volume_wave"           // 目标标识
        }
        """
        try:
            # 验证消息格式
            subscribe_msg = SubscribeMessage(**message)
            
            # 添加订阅
            is_new = subscription_manager.subscribe(
                client_id=client_id,
                subscription_type=subscribe_msg.subscription_type,
                target=subscribe_msg.target
            )
            
            # 生成响应
            response = SubscribedMessage(
                subscription_type=subscribe_msg.subscription_type,
                target=subscribe_msg.target,
                message="订阅成功" if is_new else "已订阅"
            )
            
            return response.model_dump()
            
        except Exception as e:
            logger.error(f"处理订阅消息失败: {e}")
            return self._error_response(f"订阅失败: {str(e)}")
    
    async def _handle_unsubscribe(
        self, 
        client_id: str, 
        message: Dict[str, Any]
    ) -> Dict[str, Any]:
        """
        处理取消订阅消息
        
        消息格式：
        {
            "type": "unsubscribe",
            "subscription_type": "strategy",
            "target": "volume_wave"
        }
        """
        try:
            # 验证消息格式
            unsubscribe_msg = UnsubscribeMessage(**message)
            
            # 取消订阅
            success = subscription_manager.unsubscribe(
                client_id=client_id,
                subscription_type=unsubscribe_msg.subscription_type,
                target=unsubscribe_msg.target
            )
            
            # 生成响应
            response = UnsubscribedMessage(
                subscription_type=unsubscribe_msg.subscription_type,
                target=unsubscribe_msg.target,
                message="取消订阅成功" if success else "未订阅"
            )
            
            return response.model_dump()
            
        except Exception as e:
            logger.error(f"处理取消订阅消息失败: {e}")
            return self._error_response(f"取消订阅失败: {str(e)}")
    
    async def _handle_ping(
        self, 
        client_id: str, 
        message: Dict[str, Any]
    ) -> Dict[str, Any]:
        """
        处理心跳消息
        
        消息格式：
        {
            "type": "ping"
        }
        """
        # 更新最后心跳时间
        await connection_manager.update_last_ping(client_id)
        
        # 返回pong
        response = PongMessage()
        return response.model_dump()
    
    def _error_response(self, error: str, details: Optional[str] = None) -> Dict[str, Any]:
        """生成错误响应"""
        response = ErrorMessage(error=error, details=details)
        return response.model_dump()


# 全局单例实例
message_handler = MessageHandler()

