# -*- coding: utf-8 -*-
"""股票相关的数据模型 - 基于Redis存储架构"""

from datetime import datetime, date
from typing import Optional
from dataclasses import dataclass, asdict
import json

@dataclass
class StockInfo:
    """股票信息数据类"""
    code: str
    name: str
    id: Optional[int] = None
    
    def to_dict(self) -> dict:
        """转换为字典"""
        return asdict(self)
    
    def to_json(self) -> str:
        """转换为JSON字符串"""
        return json.dumps(self.to_dict(), ensure_ascii=False)
    
    @classmethod
    def from_dict(cls, data: dict) -> 'StockInfo':
        """从字典创建实例"""
        return cls(**data)
    
    @classmethod
    def from_json(cls, json_str: str) -> 'StockInfo':
        """从JSON字符串创建实例"""
        return cls.from_dict(json.loads(json_str))
    
    def __repr__(self):
        return f"<StockInfo(code='{self.code}', name='{self.name}')>"

@dataclass
class StockHistory:
    """股票历史行情数据类"""
    stock_code: str
    trade_date: date
    open: float
    close: float
    high: float
    low: float
    volume: Optional[float] = None
    amount: Optional[float] = None
    amplitude: Optional[float] = None
    change_percent: Optional[float] = None
    change_amount: Optional[float] = None
    turnover_rate: Optional[float] = None
    updated_at: Optional[datetime] = None
    
    def __post_init__(self):
        """初始化后处理"""
        if self.updated_at is None:
            self.updated_at = datetime.now()
        
        # 确保trade_date是date对象
        if isinstance(self.trade_date, str):
            self.trade_date = datetime.strptime(self.trade_date, '%Y-%m-%d').date()
    
    def to_dict(self) -> dict:
        """转换为字典"""
        data = asdict(self)
        # 处理日期序列化
        if isinstance(data['trade_date'], date):
            data['trade_date'] = data['trade_date'].isoformat()
        if isinstance(data['updated_at'], datetime):
            data['updated_at'] = data['updated_at'].isoformat()
        return data
    
    def to_json(self) -> str:
        """转换为JSON字符串"""
        return json.dumps(self.to_dict(), ensure_ascii=False)
    
    @classmethod
    def from_dict(cls, data: dict) -> 'StockHistory':
        """从字典创建实例"""
        # 处理日期反序列化
        if isinstance(data.get('trade_date'), str):
            data['trade_date'] = datetime.strptime(data['trade_date'], '%Y-%m-%d').date()
        if isinstance(data.get('updated_at'), str):
            data['updated_at'] = datetime.fromisoformat(data['updated_at'])
        return cls(**data)
    
    @classmethod
    def from_json(cls, json_str: str) -> 'StockHistory':
        """从JSON字符串创建实例"""
        return cls.from_dict(json.loads(json_str))
    
    def __repr__(self):
        return f"<StockHistory(stock_code='{self.stock_code}', trade_date='{self.trade_date}', close='{self.close}')>"

@dataclass
class StockSignal:
    """股票信号数据类"""
    code: str
    name: str
    strategy: str
    signal_type: str
    board: Optional[str] = None
    latest_price: Optional[float] = None
    signal_date: Optional[str] = None
    change_percent: Optional[float] = None
    volume: Optional[float] = None
    chart_url: Optional[str] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    id: Optional[int] = None
    
    def __post_init__(self):
        """初始化后处理"""
        if self.created_at is None:
            self.created_at = datetime.now()
        if self.updated_at is None:
            self.updated_at = datetime.now()
    
    def to_dict(self) -> dict:
        """转换为字典"""
        data = asdict(self)
        # 处理日期序列化
        if isinstance(data['created_at'], datetime):
            data['created_at'] = data['created_at'].isoformat()
        if isinstance(data['updated_at'], datetime):
            data['updated_at'] = data['updated_at'].isoformat()
        return data
    
    def to_json(self) -> str:
        """转换为JSON字符串"""
        return json.dumps(self.to_dict(), ensure_ascii=False)
    
    @classmethod
    def from_dict(cls, data: dict) -> 'StockSignal':
        """从字典创建实例"""
        # 处理日期反序列化
        if isinstance(data.get('created_at'), str):
            data['created_at'] = datetime.fromisoformat(data['created_at'])
        if isinstance(data.get('updated_at'), str):
            data['updated_at'] = datetime.fromisoformat(data['updated_at'])
        return cls(**data)
    
    @classmethod
    def from_json(cls, json_str: str) -> 'StockSignal':
        """从JSON字符串创建实例"""
        return cls.from_dict(json.loads(json_str)) 