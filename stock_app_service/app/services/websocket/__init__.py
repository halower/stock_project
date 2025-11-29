# -*- coding: utf-8 -*-
"""
WebSocket服务模块

提供WebSocket实时通信功能，包括：
- 连接管理
- 订阅管理
- 消息处理
- 价格推送

使用示例：
    from app.services.websocket import (
        connection_manager,
        subscription_manager,
        message_handler,
        price_publisher
    )
    
    # 广播价格更新
    await price_publisher.broadcast_all_prices()
"""

from app.services.websocket.connection_manager import connection_manager
from app.services.websocket.subscription_manager import subscription_manager
from app.services.websocket.message_handler import message_handler
from app.services.websocket.price_publisher import price_publisher

__all__ = [
    "connection_manager",
    "subscription_manager",
    "message_handler",
    "price_publisher",
]

