# -*- coding: utf-8 -*-
"""AI分析相关的数据模式"""

from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime

class AIAnalysisReportBase(BaseModel):
    """AI分析报告基础模式"""
    stock_code: str = Field(..., description="股票代码")
    report_content: str = Field(..., description="分析报告内容")

class AIAnalysisReportCreate(AIAnalysisReportBase):
    """AI分析报告创建模式"""
    prompt_used: Optional[str] = Field(None, description="使用的提示词")
    token_count: Optional[int] = Field(None, description="消耗的token数量")
    model_used: Optional[str] = Field(None, description="使用的模型名称")
    expires_at: datetime = Field(..., description="过期时间")

class AIAnalysisReportResponse(AIAnalysisReportBase):
    """AI分析报告响应模式"""
    id: int
    created_at: datetime
    expires_at: datetime
    token_count: Optional[int]
    model_used: Optional[str]
    
    class Config:
        orm_mode = True

class StockAnalysisResponse(BaseModel):
    """股票分析报告响应模式"""
    stock_code: str = Field(..., description="股票代码")
    stock_name: str = Field(..., description="股票名称")
    report: str = Field(..., description="分析报告内容")
    is_cached: bool = Field(..., description="是否为缓存数据")
    created_at: str = Field(..., description="创建时间")
    expires_at: str = Field(..., description="过期时间")
    token_count: Optional[int] = Field(None, description="消耗的token数量，仅非缓存数据有此字段") 