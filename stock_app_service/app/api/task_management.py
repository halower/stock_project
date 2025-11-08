# -*- coding: utf-8 -*-
"""
任务管理API
提供异步任务的管理和状态查询接口
"""
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Dict, Any, List, Optional
from datetime import datetime

from app.tasks.stock_data_tasks import get_task_status, get_all_tasks, clear_completed_tasks

router = APIRouter(prefix="/api/tasks", tags=["任务管理"])

# ===================== 响应模型 =====================

class TaskStatusResponse(BaseModel):
    """任务状态响应"""
    id: str
    type: str
    status: str
    start_time: Optional[str] = None
    end_time: Optional[str] = None
    result: Optional[Dict[str, Any]] = None
    error: Optional[str] = None
    progress: int = 0
    total: int = 0
    progress_percentage: float = 0
    elapsed_seconds: Optional[float] = None

class TaskListResponse(BaseModel):
    """任务列表响应"""
    tasks: List[TaskStatusResponse]
    count: int

# ===================== API接口 =====================


