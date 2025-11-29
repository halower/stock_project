# -*- coding: utf-8 -*-
"""
订阅管理器

职责：
1. 管理客户端的订阅关系
2. 根据订阅类型分发消息
3. 支持多种订阅类型（策略、股票、市场）
4. 提供订阅的增删查功能
"""

from typing import Dict, List, Set, Optional
from collections import defaultdict
import asyncio

from app.core.logging import logger
from app.models.websocket_models import SubscriptionType


class SubscriptionManager:
    """
    订阅管理器
    
    管理客户端与订阅目标的多对多关系
    支持按订阅类型快速查找订阅者
    """
    
    _instance = None
    _lock = asyncio.Lock()
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance
    
    def __init__(self):
        if hasattr(self, '_initialized'):
            return
        
        # 客户端订阅：{client_id: {(subscription_type, target)}}
        self._client_subscriptions: Dict[str, Set[tuple]] = defaultdict(set)
        
        # 反向索引：{(subscription_type, target): {client_id}}
        # 用于快速查找订阅了特定目标的所有客户端
        self._target_subscribers: Dict[tuple, Set[str]] = defaultdict(set)
        
        # 统计信息
        self._total_subscriptions = 0
        
        self._initialized = True
        logger.info("订阅管理器初始化完成")
    
    def subscribe(
        self, 
        client_id: str, 
        subscription_type: SubscriptionType, 
        target: str
    ) -> bool:
        """
        添加订阅
        
        Args:
            client_id: 客户端ID
            subscription_type: 订阅类型
            target: 订阅目标
            
        Returns:
            bool: 是否为新订阅（True）或已存在（False）
        """
        subscription_key = (subscription_type, target)
        
        # 检查是否已订阅
        if subscription_key in self._client_subscriptions[client_id]:
            logger.debug(f"客户端 {client_id} 已订阅 {subscription_type}:{target}")
            return False
        
        # 添加订阅
        self._client_subscriptions[client_id].add(subscription_key)
        self._target_subscribers[subscription_key].add(client_id)
        self._total_subscriptions += 1
        
        logger.info(
            f"添加订阅: 客户端={client_id}, "
            f"类型={subscription_type}, 目标={target}, "
            f"该目标订阅者数={len(self._target_subscribers[subscription_key])}"
        )
        
        return True
    
    def unsubscribe(
        self, 
        client_id: str, 
        subscription_type: SubscriptionType, 
        target: str
    ) -> bool:
        """
        取消订阅
        
        Args:
            client_id: 客户端ID
            subscription_type: 订阅类型
            target: 订阅目标
            
        Returns:
            bool: 是否成功取消
        """
        subscription_key = (subscription_type, target)
        
        # 检查订阅是否存在
        if subscription_key not in self._client_subscriptions[client_id]:
            logger.debug(f"客户端 {client_id} 未订阅 {subscription_type}:{target}")
            return False
        
        # 移除订阅
        self._client_subscriptions[client_id].discard(subscription_key)
        self._target_subscribers[subscription_key].discard(client_id)
        self._total_subscriptions -= 1
        
        # 清理空集合
        if not self._target_subscribers[subscription_key]:
            del self._target_subscribers[subscription_key]
        
        if not self._client_subscriptions[client_id]:
            del self._client_subscriptions[client_id]
        
        logger.info(f"取消订阅: 客户端={client_id}, 类型={subscription_type}, 目标={target}")
        
        return True
    
    def unsubscribe_all(self, client_id: str) -> int:
        """
        取消客户端的所有订阅
        
        Args:
            client_id: 客户端ID
            
        Returns:
            int: 取消的订阅数量
        """
        if client_id not in self._client_subscriptions:
            return 0
        
        # 获取所有订阅
        subscriptions = list(self._client_subscriptions[client_id])
        count = len(subscriptions)
        
        # 逐个取消
        for subscription_type, target in subscriptions:
            self.unsubscribe(client_id, subscription_type, target)
        
        logger.info(f"取消客户端 {client_id} 的所有订阅，共 {count} 个")
        
        return count
    
    def get_subscribers(
        self, 
        subscription_type: SubscriptionType, 
        target: str
    ) -> List[str]:
        """
        获取订阅了指定目标的所有客户端
        
        Args:
            subscription_type: 订阅类型
            target: 订阅目标
            
        Returns:
            List[str]: 客户端ID列表
        """
        subscription_key = (subscription_type, target)
        return list(self._target_subscribers.get(subscription_key, set()))
    
    def get_client_subscriptions(self, client_id: str) -> List[Dict[str, str]]:
        """
        获取客户端的所有订阅
        
        Args:
            client_id: 客户端ID
            
        Returns:
            List[Dict]: 订阅列表，格式：[{"type": "strategy", "target": "volume_wave"}]
        """
        if client_id not in self._client_subscriptions:
            return []
        
        subscriptions = []
        for subscription_type, target in self._client_subscriptions[client_id]:
            subscriptions.append({
                "type": subscription_type,
                "target": target
            })
        
        return subscriptions
    
    def is_subscribed(
        self, 
        client_id: str, 
        subscription_type: SubscriptionType, 
        target: str
    ) -> bool:
        """检查客户端是否订阅了指定目标"""
        subscription_key = (subscription_type, target)
        return subscription_key in self._client_subscriptions.get(client_id, set())
    
    def get_subscription_count(self, client_id: Optional[str] = None) -> int:
        """
        获取订阅数量
        
        Args:
            client_id: 如果指定，返回该客户端的订阅数；否则返回总订阅数
        """
        if client_id:
            return len(self._client_subscriptions.get(client_id, set()))
        return self._total_subscriptions
    
    def get_target_subscriber_count(
        self, 
        subscription_type: SubscriptionType, 
        target: str
    ) -> int:
        """获取订阅了指定目标的客户端数量"""
        subscription_key = (subscription_type, target)
        return len(self._target_subscribers.get(subscription_key, set()))
    
    def get_all_targets(self, subscription_type: Optional[SubscriptionType] = None) -> List[str]:
        """
        获取所有订阅目标
        
        Args:
            subscription_type: 如果指定，只返回该类型的目标
            
        Returns:
            List[str]: 目标列表
        """
        targets = set()
        
        for sub_type, target in self._target_subscribers.keys():
            if subscription_type is None or sub_type == subscription_type:
                targets.add(target)
        
        return list(targets)
    
    def get_stats(self) -> Dict[str, int]:
        """获取订阅统计信息"""
        return {
            "total_subscriptions": self._total_subscriptions,
            "total_clients": len(self._client_subscriptions),
            "total_targets": len(self._target_subscribers),
            "strategy_targets": len([
                k for k in self._target_subscribers.keys() 
                if k[0] == SubscriptionType.STRATEGY
            ]),
            "stock_targets": len([
                k for k in self._target_subscribers.keys() 
                if k[0] == SubscriptionType.STOCK
            ]),
            "market_targets": len([
                k for k in self._target_subscribers.keys() 
                if k[0] == SubscriptionType.MARKET
            ])
        }


# 全局单例实例
subscription_manager = SubscriptionManager()

