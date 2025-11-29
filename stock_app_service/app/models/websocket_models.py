# -*- coding: utf-8 -*-
"""
WebSocket数据模型

定义WebSocket通信的消息格式和数据结构
"""

from typing import Optional, List, Dict, Any
from pydantic import BaseModel, Field
from datetime import datetime
from enum import Enum


class MessageType(str, Enum):
    """消息类型枚举"""
    # 连接相关
    CONNECTED = "connected"
    DISCONNECTED = "disconnected"
    ERROR = "error"
    
    # 订阅相关
    SUBSCRIBE = "subscribe"
    UNSUBSCRIBE = "unsubscribe"
    SUBSCRIBED = "subscribed"
    UNSUBSCRIBED = "unsubscribed"
    
    # 数据推送
    PRICE_UPDATE = "price_update"
    SIGNAL_UPDATE = "signal_update"
    
    # 心跳
    PING = "ping"
    PONG = "pong"


class SubscriptionType(str, Enum):
    """订阅类型枚举"""
    STRATEGY = "strategy"           # 订阅策略信号
    STOCK = "stock"                 # 订阅单个股票
    MARKET = "market"               # 订阅市场板块


# ==================== 客户端消息 ====================

class SubscribeMessage(BaseModel):
    """订阅消息"""
    type: str = Field(default=MessageType.SUBSCRIBE)
    subscription_type: SubscriptionType = Field(default=SubscriptionType.STRATEGY)
    target: str = Field(..., description="订阅目标：策略代码/股票代码/市场代码")
    
    class Config:
        json_schema_extra = {
            "example": {
                "type": "subscribe",
                "subscription_type": "strategy",
                "target": "volume_wave"
            }
        }


class UnsubscribeMessage(BaseModel):
    """取消订阅消息"""
    type: str = Field(default=MessageType.UNSUBSCRIBE)
    subscription_type: SubscriptionType
    target: str
    
    class Config:
        json_schema_extra = {
            "example": {
                "type": "unsubscribe",
                "subscription_type": "strategy",
                "target": "volume_wave"
            }
        }


class PingMessage(BaseModel):
    """心跳消息"""
    type: str = Field(default=MessageType.PING)


# ==================== 服务端消息 ====================

class ConnectedMessage(BaseModel):
    """连接成功消息"""
    type: str = Field(default=MessageType.CONNECTED)
    client_id: str
    message: str = "WebSocket连接成功"
    timestamp: str = Field(default_factory=lambda: datetime.now().isoformat())
    
    class Config:
        json_schema_extra = {
            "example": {
                "type": "connected",
                "client_id": "client_12345",
                "message": "WebSocket连接成功",
                "timestamp": "2025-11-24T10:30:00"
            }
        }


class SubscribedMessage(BaseModel):
    """订阅成功消息"""
    type: str = Field(default=MessageType.SUBSCRIBED)
    subscription_type: SubscriptionType
    target: str
    message: str = "订阅成功"
    timestamp: str = Field(default_factory=lambda: datetime.now().isoformat())


class UnsubscribedMessage(BaseModel):
    """取消订阅成功消息"""
    type: str = Field(default=MessageType.UNSUBSCRIBED)
    subscription_type: SubscriptionType
    target: str
    message: str = "取消订阅成功"
    timestamp: str = Field(default_factory=lambda: datetime.now().isoformat())


class PongMessage(BaseModel):
    """心跳响应消息"""
    type: str = Field(default=MessageType.PONG)
    timestamp: str = Field(default_factory=lambda: datetime.now().isoformat())


class ErrorMessage(BaseModel):
    """错误消息"""
    type: str = Field(default=MessageType.ERROR)
    error: str
    details: Optional[str] = None
    timestamp: str = Field(default_factory=lambda: datetime.now().isoformat())


# ==================== 数据推送消息 ====================

class PriceUpdate(BaseModel):
    """单个股票价格更新"""
    code: str = Field(..., description="股票代码")
    name: Optional[str] = Field(None, description="股票名称")
    price: float = Field(..., description="最新价格")
    change: Optional[float] = Field(None, description="涨跌额")
    change_percent: float = Field(..., description="涨跌幅（%）")
    volume: Optional[int] = Field(None, description="成交量（股）")
    timestamp: Optional[str] = Field(None, description="更新时间")
    
    class Config:
        json_schema_extra = {
            "example": {
                "code": "600519",
                "name": "贵州茅台",
                "price": 1850.5,
                "change": 25.3,
                "change_percent": 2.5,
                "volume": 12345678,
                "timestamp": "2025-11-24T10:30:00"
            }
        }


class PriceUpdateMessage(BaseModel):
    """价格更新消息（批量）"""
    type: str = Field(default=MessageType.PRICE_UPDATE)
    data: List[PriceUpdate] = Field(..., description="价格更新列表")
    count: int = Field(..., description="更新数量")
    timestamp: str = Field(default_factory=lambda: datetime.now().isoformat())
    
    class Config:
        json_schema_extra = {
            "example": {
                "type": "price_update",
                "data": [
                    {
                        "code": "600519",
                        "price": 1850.5,
                        "change_percent": 2.5
                    }
                ],
                "count": 1,
                "timestamp": "2025-11-24T10:30:00"
            }
        }


class SignalUpdate(BaseModel):
    """信号更新"""
    code: str
    name: str
    signal: str = Field(..., description="信号类型：买入/卖出")
    strategy: str = Field(..., description="策略代码")
    price: float
    change_percent: float
    reason: Optional[str] = Field(None, description="信号原因")


class SignalUpdateMessage(BaseModel):
    """信号更新消息（新增/删除信号）"""
    type: str = Field(default=MessageType.SIGNAL_UPDATE)
    action: str = Field(..., description="操作类型：add/remove")
    data: List[SignalUpdate]
    count: int
    timestamp: str = Field(default_factory=lambda: datetime.now().isoformat())


# ==================== 辅助模型 ====================

class ClientInfo(BaseModel):
    """客户端信息"""
    client_id: str
    connected_at: datetime
    last_ping: Optional[datetime] = None
    subscriptions: List[Dict[str, str]] = Field(default_factory=list)
    
    class Config:
        json_schema_extra = {
            "example": {
                "client_id": "client_12345",
                "connected_at": "2025-11-24T10:30:00",
                "subscriptions": [
                    {"type": "strategy", "target": "volume_wave"}
                ]
            }
        }


class ConnectionStats(BaseModel):
    """连接统计信息"""
    total_connections: int = Field(..., description="总连接数")
    active_connections: int = Field(..., description="活跃连接数")
    total_subscriptions: int = Field(..., description="总订阅数")
    messages_sent: int = Field(default=0, description="已发送消息数")
    messages_received: int = Field(default=0, description="已接收消息数")
    
    class Config:
        json_schema_extra = {
            "example": {
                "total_connections": 10,
                "active_connections": 8,
                "total_subscriptions": 15,
                "messages_sent": 1000,
                "messages_received": 500
            }
        }

