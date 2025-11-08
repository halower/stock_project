# -*- coding: utf-8 -*-
"""股票数据调度器API路由"""

from fastapi import APIRouter, Depends, HTTPException, Query, status
from typing import Dict, Any, Optional
from datetime import datetime
from pydantic import BaseModel, Field

from app.core.logging import logger
from app.api.dependencies import verify_token
from app.services.scheduler.stock_scheduler import (
    get_stock_scheduler_status, 
    trigger_stock_task,
    STOCK_KEYS
)
from app.db.session import RedisCache

# Redis缓存客户端
redis_cache = RedisCache()

# 定义响应模型
class StockSchedulerResponse(BaseModel):
    success: bool = Field(..., description="是否成功")
    message: str = Field(..., description="消息")
    data: Optional[Dict[str, Any]] = Field(None, description="数据")

# 定义手动触发请求模型
class TriggerTaskRequest(BaseModel):
    task_type: str = Field(..., description="任务类型: init_system, clear_refetch, calc_signals, update_realtime")
    is_closing_update: bool = Field(False, description="是否为收盘数据更新（仅当task_type=update_realtime时有效）")

router = APIRouter(tags=["Stock Scheduler"])













# 股票调度器API说明：
# 
# 主要功能：
# - /api/stocks/scheduler/status - 调度器状态和统计
# - /api/stocks/scheduler/init - 初始化股票系统
# - /api/stocks/scheduler/trigger - 手动触发任务
# - /api/stocks/scheduler/refresh-stocks - 刷新股票列表
# - /api/stocks/codes - 获取股票代码列表
# 
# 🕐 任务调度时间：
# - K线数据获取: 每个工作日17:30
# - 策略信号计算: 交易时间内每30分钟
# - 收盘后信号计算: 每个交易日15:30
# - 实时数据更新: 交易时间内每15分钟
# 
# 💾 数据存储策略：
# - 股票代码: 永久保存
# - K线数据: 30天TTL
# - 策略信号: 1小时TTL
# - 实时数据: 5分钟TTL
# - 执行日志: 7天TTL 