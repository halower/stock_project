# -*- coding: utf-8 -*-
"""
实时行情配置API
"""

from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel, Field
from typing import Optional, Literal

from app.core.logging import logger
from app.core.config import settings
from app.services.realtime import get_stock_realtime_service_v2
from app.api.dependencies import verify_token

router = APIRouter()


class RealtimeConfigResponse(BaseModel):
    """实时行情配置响应"""
    default_provider: str = Field(..., description="默认数据提供商")
    auto_switch: bool = Field(..., description="是否启用自动切换")
    update_interval: int = Field(..., description="更新周期（分钟）")
    available_providers: list = Field(..., description="可用的数据提供商")


class RealtimeConfigUpdate(BaseModel):
    """实时行情配置更新"""
    default_provider: Optional[Literal["eastmoney", "sina", "auto"]] = Field(None, description="默认数据提供商")
    auto_switch: Optional[bool] = Field(None, description="是否启用自动切换")


class RealtimeStatsResponse(BaseModel):
    """实时行情统计响应"""
    total_requests: int
    eastmoney: dict
    sina: dict
    last_provider: Optional[str]
    last_update: Optional[str]
    config: dict





