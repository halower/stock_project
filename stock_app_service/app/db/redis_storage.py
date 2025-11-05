# -*- coding: utf-8 -*-
"""Redis数据存储系统 - 完全替代关系数据库"""

import redis
import json
from datetime import datetime, date, timedelta
from typing import List, Dict, Optional, Any
from dataclasses import dataclass, asdict
from app.core.config import (
    REDIS_HOST, REDIS_PORT, REDIS_DB, REDIS_PASSWORD,
    REDIS_MAX_CONNECTIONS, REDIS_RETRY_ON_TIMEOUT,
    REDIS_SOCKET_CONNECT_TIMEOUT, REDIS_SOCKET_TIMEOUT
)
from app.core.logging import logger

@dataclass
class StockInfo:
    """股票基础信息数据类"""
    code: str
    name: str
    market: str = "A股"
    industry: str = ""
    created_at: str = ""
    updated_at: str = ""
    
    def __post_init__(self):
        if not self.created_at:
            self.created_at = datetime.now().isoformat()
        self.updated_at = datetime.now().isoformat()

@dataclass  
class StockHistory:
    """股票历史行情数据类"""
    stock_code: str
    trade_date: str  # YYYY-MM-DD格式
    open: float
    close: float
    high: float
    low: float
    volume: float = 0.0
    amount: float = 0.0
    amplitude: float = 0.0
    change_percent: float = 0.0
    change_amount: float = 0.0
    turnover_rate: float = 0.0
    updated_at: str = ""
    
    def __post_init__(self):
        if not self.updated_at:
            self.updated_at = datetime.now().isoformat()

class RedisStockStorage:
    """Redis股票数据存储管理器"""
    
    def __init__(self):
        """初始化Redis连接配置（延迟连接）"""
        self.redis_client = None
        # 不在初始化时连接，而是在首次使用时连接
        
        # Redis键名规则
        self.KEYS = {
            'stock_info': 'stock:info:{}',           # stock:info:000001
            'stock_list': 'stock:list:all',          # 所有股票代码列表
            'stock_history': 'stock:history:{}:{}',  # stock:history:000001:2024-01-01
            'stock_history_list': 'stock:history_list:{}',  # 某股票的所有历史日期
            'stock_realtime': 'stock:realtime:{}',   # stock:realtime:000001
            'market_overview': 'market:overview',     # 市场概览
            'hot_stocks': 'market:hot_stocks',       # 热门股票
        }
    
    def _ensure_connection(self):
        """确保Redis连接（懒加载）"""
        if self.redis_client is None:
            self._connect()
    
    def _connect(self):
        """连接Redis"""
        try:
            self.redis_client = redis.Redis(
                host=REDIS_HOST,
                port=REDIS_PORT,
                db=REDIS_DB,
                password=REDIS_PASSWORD,
                decode_responses=True,
                retry_on_timeout=REDIS_RETRY_ON_TIMEOUT,
                socket_connect_timeout=REDIS_SOCKET_CONNECT_TIMEOUT,
                socket_timeout=REDIS_SOCKET_TIMEOUT,
                max_connections=REDIS_MAX_CONNECTIONS
            )
        except Exception as e:
            logger.error(f"Redis连接失败: {e}")
            self.redis_client = None
    
    def test_connection(self) -> bool:
        """测试Redis连接"""
        try:
            self._ensure_connection()
            
            if self.redis_client:
                self.redis_client.ping()
                logger.info("Redis连接测试成功")
                return True
        except Exception as e:
            logger.error(f"Redis连接失败: {e}")
        
        return False
    
    # ==================== 股票基础信息管理 ====================
    
    def add_stock_info(self, stock_info: StockInfo) -> bool:
        """添加股票基础信息"""
        try:
            if not self.redis_client:
                return False
            
            # 存储股票信息
            key = self.KEYS['stock_info'].format(stock_info.code)
            data = asdict(stock_info)
            
            # 使用Hash存储
            self.redis_client.hset(key, mapping=data)
            
            # 添加到股票列表
            self.redis_client.sadd(self.KEYS['stock_list'], stock_info.code)
            
            logger.info(f"添加股票信息: {stock_info.code} - {stock_info.name}")
            return True
            
        except Exception as e:
            logger.error(f"添加股票信息失败 {stock_info.code}: {e}")
            return False
    
    def get_stock_info(self, stock_code: str) -> Optional[StockInfo]:
        """获取单个股票信息"""
        try:
            if not self.redis_client:
                return None
            
            key = self.KEYS['stock_info'].format(stock_code)
            data = self.redis_client.hgetall(key)
            
            if not data:
                return None
                
            return StockInfo(**data)
            
        except Exception as e:
            logger.error(f"获取股票信息失败 {stock_code}: {e}")
            return None
    
    def get_all_stocks(self, offset: int = 0, limit: int = 100) -> List[StockInfo]:
        """获取所有股票信息（分页）"""
        try:
            if not self.redis_client:
                return []
            
            # 获取所有股票代码
            all_codes = list(self.redis_client.smembers(self.KEYS['stock_list']))
            
            # 分页处理
            paginated_codes = all_codes[offset:offset+limit]
            
            stocks = []
            for code in paginated_codes:
                stock_info = self.get_stock_info(code)
                if stock_info:
                    stocks.append(stock_info)
            
            return stocks
            
        except Exception as e:
            logger.error(f"获取股票列表失败: {e}")
            return []
    
    def get_stocks_count(self) -> int:
        """获取股票总数"""
        try:
            if not self.redis_client:
                return 0
            return self.redis_client.scard(self.KEYS['stock_list'])
        except Exception as e:
            logger.error(f"获取股票总数失败: {e}")
            return 0
    
    def query(self, *args, **kwargs):
        """兼容性方法 - 模拟SQLAlchemy的query方法"""
        # 对于简单的查询，返回空结果集
        class MockQuery:
            def all(self):
                return []
            def first(self):
                return None
            def filter(self, *args, **kwargs):
                return self
            def offset(self, *args, **kwargs):
                return self
            def limit(self, *args, **kwargs):
                return self
            def count(self):
                return 0
            def order_by(self, *args, **kwargs):
                return self
        
        return MockQuery()
    
    def get_all_stock_codes(self) -> List[str]:
        """获取所有股票代码"""
        try:
            if not self.redis_client:
                return []
            return list(self.redis_client.smembers(self.KEYS['stock_list']))
        except Exception as e:
            logger.error(f"获取股票代码列表失败: {e}")
            return []
    
    def get_stock_by_code(self, code: str) -> Optional[Dict]:
        """根据代码获取股票信息"""
        try:
            if not self.redis_client:
                return None
            
            key = self.KEYS['stock_info'].format(code)
            data = self.redis_client.hgetall(key)
            
            if not data:
                return None
                
            return data
            
        except Exception as e:
            logger.error(f"获取股票信息失败 {code}: {e}")
            return None
    
    def get_all_stocks_dict(self) -> List[Dict]:
        """获取所有股票信息字典格式"""
        try:
            if not self.redis_client:
                return []
            
            codes = self.get_all_stock_codes()
            stocks = []
            
            for code in codes:
                stock_data = self.get_stock_by_code(code)
                if stock_data:
                    stocks.append(stock_data)
            
            return stocks
            
        except Exception as e:
            logger.error(f"获取股票字典列表失败: {e}")
            return []

# 全局存储实例
redis_storage = RedisStockStorage()