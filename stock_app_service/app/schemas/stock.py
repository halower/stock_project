# -*- coding: utf-8 -*-
"""股票相关的Pydantic响应模型"""

from pydantic import BaseModel
from typing import List, Optional
from datetime import date, datetime

class StockInfoResponse(BaseModel):
    """单个股票信息响应模型"""
    code: str
    name: str
    
    class Config:
        from_attributes = True

class StockListResponse(BaseModel):
    """股票列表响应模型,包含总数和数据"""
    total: int
    stocks: List[StockInfoResponse]

class StockHistoryItem(BaseModel):
    """单条股票历史数据响应模型"""
    trade_date: date
    stock_code: str
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
    
    class Config:
        from_attributes = True

class StockHistoryResponse(BaseModel):
    """股票历史数据列表响应模型"""
    code: str
    name: str
    total: int
    history: List[StockHistoryItem]
    last_updated: datetime

class ChartResponse(BaseModel):
    """股票图表响应模型"""
    code: str
    name: str
    chart_url: str
    generated_time: datetime 