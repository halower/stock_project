# -*- coding: utf-8 -*-
"""
股票数据管理API
提供股票清单和股票走势数据的管理接口
"""
from fastapi import APIRouter, HTTPException, BackgroundTasks
from pydantic import BaseModel
from typing import Dict, Any, List, Optional
import logging
from datetime import datetime

from app.services.stock.stock_data_manager import stock_data_manager
# 导入任务将在需要时进行，避免循环导入问题

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/stock-data", tags=["股票数据管理"])

# ===================== 响应模型 =====================

class StockDataStatusResponse(BaseModel):
    """股票数据状态响应"""
    stock_list_count: int
    stock_list_sufficient: bool
    trend_data_count: int
    trend_data_sufficient: bool
    last_check_time: str

class StockDataOperationResponse(BaseModel):
    """股票数据操作响应"""
    success: bool
    message: str
    data: Optional[Dict[str, Any]] = None

class StockListResponse(BaseModel):
    """股票清单响应"""
    ts_code: str
    symbol: str
    name: str
    area: Optional[str] = ""
    industry: Optional[str] = ""
    market: Optional[str] = ""
    list_date: Optional[str] = ""
    updated_at: str

class StockTrendDataResponse(BaseModel):
    """股票走势数据响应"""
    ts_code: str
    data_count: int
    updated_at: str
    latest_date: Optional[str] = None

# ===================== 股票清单管理接口 =====================

 