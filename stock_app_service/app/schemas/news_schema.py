# -*- coding: utf-8 -*-
"""新闻分析相关的数据模式"""

from pydantic import BaseModel, Field
from typing import Optional, Dict, Any, List
from datetime import datetime

class NewsAnalysisData(BaseModel):
    """新闻分析数据"""
    analysis: str = Field(..., description="分析内容")
    updated_at: str = Field(..., description="更新时间")

class NewsAnalysisResponse(BaseModel):
    """新闻分析响应模式"""
    success: bool = Field(..., description="是否成功")
    message: str = Field(..., description="消息")
    data: Optional[NewsAnalysisData] = Field(None, description="分析数据")

class NewsItem(BaseModel):
    """新闻项"""
    title: str = Field(..., description="新闻标题")
    url: str = Field(..., description="新闻链接")
    datetime: str = Field(..., description="发布时间")
    source: str = Field(..., description="新闻来源")
    summary: str = Field(..., description="新闻摘要") 