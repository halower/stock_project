# -*- coding: utf-8 -*-
"""
价格推送器

职责：
1. 从信号数据中获取价格（信号计算时已包含价格和涨跌幅）
2. 实时更新时添加随机波动模拟真实行情（测试用）
3. 根据订阅关系推送给相应客户端
"""

from typing import List, Dict, Optional
from datetime import datetime

from app.core.logging import logger
from app.models.websocket_models import (
    PriceUpdate,
    PriceUpdateMessage,
    SubscriptionType
)
from app.services.websocket.connection_manager import connection_manager
from app.services.websocket.subscription_manager import subscription_manager


class PricePublisher:
    """
    价格推送器
    
    负责获取价格数据并推送给订阅的客户端
    """
    
    def __init__(self):
        self._last_prices: Dict[str, float] = {}  # 缓存上次价格
    
    async def publish_strategy_prices(self, strategy: str) -> int:
        """
        推送策略相关的所有股票价格
        
        Args:
            strategy: 策略代码（如：volume_wave）
            
        Returns:
            int: 推送的客户端数量
        """
        try:
            # 1. 获取订阅了该策略的客户端
            subscribers = subscription_manager.get_subscribers(
                SubscriptionType.STRATEGY,
                strategy
            )
            
            if not subscribers:
                logger.debug(f"策略 {strategy} 没有订阅者，跳过推送")
                return 0
            
            # 2. 获取该策略的所有信号价格
            price_updates = await self._get_strategy_price_updates(strategy)
            
            if not price_updates:
                logger.debug(f"策略 {strategy} 没有价格更新")
                return 0
            
            # 3. 构造推送消息
            message = PriceUpdateMessage(
                data=price_updates,
                count=len(price_updates)
            )
            
            # 调试：打印前3个价格更新
            if len(price_updates) > 0:
                sample_updates = [p.model_dump() for p in price_updates[:3]]
                logger.info(f"推送消息示例（前3个）: {sample_updates}")
            
            # 4. 推送给所有订阅者
            success_count = 0
            for client_id in subscribers:
                if await connection_manager.send_message(client_id, message.model_dump()):
                    success_count += 1
            
            logger.info(
                f"推送策略 {strategy} 价格更新: "
                f"{len(price_updates)}个股票, {success_count}/{len(subscribers)}个客户端"
            )
            
            return success_count
            
        except Exception as e:
            logger.error(f"推送策略价格失败: {strategy}, 错误: {e}")
            return 0
    
    async def broadcast_all_prices(self) -> int:
        """
        广播所有活跃订阅的价格更新（包括策略订阅和单个股票订阅）
        
        Returns:
            int: 推送的客户端数量
        """
        try:
            total_clients = 0
            
            # 1. 推送策略订阅的价格
            strategies = subscription_manager.get_all_targets(SubscriptionType.STRATEGY)
            for strategy in strategies:
                client_count = await self.publish_strategy_prices(strategy)
                total_clients += client_count
            
            # 2. 推送单个股票订阅的价格
            stocks = subscription_manager.get_all_targets(SubscriptionType.STOCK)
            if stocks:
                client_count = await self.publish_stock_prices(list(stocks))
                total_clients += client_count
            
            if total_clients > 0:
                logger.info(
                    f"广播价格更新完成: {len(strategies)}个策略, "
                    f"{len(stocks)}个股票, {total_clients}次推送"
                )
            
            return total_clients
            
        except Exception as e:
            logger.error(f"广播价格失败: {e}")
            return 0
    
    async def publish_stock_prices(self, stock_codes: List[str]) -> int:
        """
        推送指定股票的价格更新
        
        Args:
            stock_codes: 股票代码列表（如：['600519', '000001']）
            
        Returns:
            int: 推送的客户端数量
        """
        try:
            if not stock_codes:
                return 0
            
            # 获取所有订阅了这些股票的客户端（去重）
            all_subscribers = set()
            for code in stock_codes:
                subscribers = subscription_manager.get_subscribers(
                    SubscriptionType.STOCK, 
                    code
                )
                all_subscribers.update(subscribers)
            
            if not all_subscribers:
                return 0
            
            # 获取这些股票的价格更新
            price_updates = []
            for code in stock_codes:
                price_update = await self._get_stock_price_update(code)
                if price_update:
                    price_updates.append(price_update)
            
            if not price_updates:
                return 0
            
            # 构造推送消息
            message = PriceUpdateMessage(
                data=price_updates,
                count=len(price_updates)
            )
            
            # 推送给所有订阅者
            success_count = 0
            for client_id in all_subscribers:
                if await connection_manager.send_message(client_id, message.model_dump()):
                    success_count += 1
            
            logger.debug(
                f"推送股票价格更新: {len(price_updates)}个股票, "
                f"{success_count}/{len(all_subscribers)}个客户端"
            )
            
            return success_count
            
        except Exception as e:
            logger.error(f"推送股票价格失败: {e}")
            return 0
    
    async def _get_strategy_price_updates(self, strategy: str) -> List[PriceUpdate]:
        """
        获取策略相关的所有股票价格更新
        
        优先从K线缓存读取最新价格（每分钟更新），如果没有则使用信号数据
        
        Args:
            strategy: 策略代码
            
        Returns:
            List[PriceUpdate]: 价格更新列表
        """
        try:
            import json
            from app.db.session import cache  # 使用全局单例，避免重复创建连接
            
            # 使用全局Redis客户端（复用连接，避免每次创建新连接）
            redis_client = cache.get_redis_client()
            
            if redis_client is None:
                logger.warning("Redis客户端未连接，跳过价格更新")
                return []
            
            buy_signals_key = "buy_signals"
            
            # 从Redis获取所有信号（使用同步方式）
            all_signals_data = redis_client.hgetall(buy_signals_key)
            
            if not all_signals_data:
                return []
            
            # 过滤出指定策略的信号
            signals = []
            for key, value in all_signals_data.items():
                # Redis返回的是bytes，需要解码
                key_str = key.decode('utf-8') if isinstance(key, bytes) else key
                value_str = value.decode('utf-8') if isinstance(value, bytes) else value
                signal = json.loads(value_str)
                if signal.get('strategy') == strategy:
                    signals.append(signal)
            
            if not signals:
                return []
            
            price_updates = []
            
            for signal in signals:
                code = signal.get('code')
                ts_code = signal.get('ts_code', '')
                name = signal.get('name', '')
                
                if not code:
                    continue
                
                # 1. 优先从K线缓存读取最新价格（每分钟更新）
                current_price = None
                current_change_percent = None
                volume = None
                
                # 尝试从K线缓存读取（这是每分钟更新的实时数据）
                if ts_code:
                    kline_key = f"stock_trend:{ts_code}"
                    kline_data = cache.get_cache(kline_key)
                    
                    if kline_data:
                        kline_list = kline_data.get('data', []) if isinstance(kline_data, dict) else kline_data
                        if kline_list:
                            # 取最新一条K线
                            last_kline = kline_list[-1]
                            current_price = float(last_kline.get('close', 0))
                            current_change_percent = float(last_kline.get('pct_chg', 0))
                            volume = int(last_kline.get('vol', 0)) if last_kline.get('vol') else None
                
                # 2. 如果K线缓存没有，使用信号中的价格（兜底）
                if current_price is None or current_price <= 0:
                    current_price = float(signal.get('price', 0))
                    current_change_percent = float(signal.get('change_percent', 0))
                    volume = signal.get('volume', 0)
                
                if current_price <= 0:
                    continue
                
                # 3. 检测价格是否有变化（与上次推送比较）
                last_price = self._last_prices.get(code, 0)
                price_change = round(current_price - last_price, 2) if last_price > 0 else 0
                
                # 更新缓存
                self._last_prices[code] = current_price
                
                # 创建价格更新对象
                price_update = PriceUpdate(
                    code=code,
                    name=name,
                    price=round(current_price, 2),
                    change=price_change,
                    change_percent=round(current_change_percent, 2) if current_change_percent else 0,
                    volume=int(volume) if volume else None,
                    timestamp=datetime.now().isoformat()
                )
                
                price_updates.append(price_update)
            
            return price_updates
            
        except Exception as e:
            logger.error(f"获取策略价格更新失败: {strategy}, 错误: {e}")
            import traceback
            logger.error(traceback.format_exc())
            return []
    
    async def _get_stock_price_update(self, code: str) -> Optional[PriceUpdate]:
        """
        获取单个股票的价格更新
        
        优先从K线缓存读取最新价格（每分钟更新）
        
        Args:
            code: 股票代码（如：600519）
            
        Returns:
            Optional[PriceUpdate]: 价格更新对象，如果获取失败则返回None
        """
        try:
            import json
            from app.db.session import cache  # 使用全局单例
            
            # 1. 优先从K线缓存读取（每分钟更新的实时数据）
            ts_codes = [
                f"{code}.SH",
                f"{code}.SZ",
                f"{code}.BJ"
            ]
            
            current_price = None
            current_change_percent = None
            volume = None
            name = code
            
            for ts_code in ts_codes:
                kline_data = cache.get_cache(f"stock_trend:{ts_code}")
                if kline_data:
                    kline_list = kline_data.get('data', []) if isinstance(kline_data, dict) else kline_data
                    if kline_list:
                        last_kline = kline_list[-1]
                        current_price = float(last_kline.get('close', 0))
                        current_change_percent = float(last_kline.get('pct_chg', 0))
                        volume = int(last_kline.get('vol', 0)) if last_kline.get('vol') else None
                        name = last_kline.get('name', code)
                        break
            
            # 2. 如果K线缓存没有，尝试从信号中获取（兜底）
            if current_price is None or current_price <= 0:
                redis_client = cache.get_redis_client()
                if redis_client:
                    buy_signals_key = "buy_signals"
                    signal_data = redis_client.hget(buy_signals_key, code)
                    
                    if signal_data:
                        signal_str = signal_data.decode('utf-8') if isinstance(signal_data, bytes) else signal_data
                        signal = json.loads(signal_str)
                        current_price = float(signal.get('price', 0))
                        current_change_percent = float(signal.get('change_percent', 0))
                        volume = signal.get('volume', 0)
                        name = signal.get('name', code)
            
            if current_price is None or current_price <= 0:
                logger.debug(f"未找到股票 {code} 的数据")
                return None
            
            # 3. 检测价格是否有变化
            last_price = self._last_prices.get(code, 0)
            price_change = round(current_price - last_price, 2) if last_price > 0 else 0
            
            # 更新缓存
            self._last_prices[code] = current_price
            
            # 创建价格更新对象
            return PriceUpdate(
                code=code,
                name=name,
                price=round(current_price, 2),
                change=price_change,
                change_percent=round(current_change_percent, 2) if current_change_percent else 0,
                volume=int(volume) if volume else None,
                timestamp=datetime.now().isoformat()
            )
            
        except Exception as e:
            logger.error(f"获取股票 {code} 价格更新失败: {e}")
            return None


# 全局单例实例
price_publisher = PricePublisher()
