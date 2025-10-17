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

@router.get("/status/{task_id}", 
           summary="获取任务状态",
           description="根据任务ID获取异步任务的执行状态",
           response_model=TaskStatusResponse)
async def get_task_status_api(task_id: str):
    """获取任务状态"""
    task = get_task_status(task_id)
    if not task:
        raise HTTPException(status_code=404, detail=f"任务 {task_id} 不存在")
    return task

@router.get("/list", 
           summary="获取所有任务",
           description="获取所有异步任务的状态列表",
           response_model=TaskListResponse)
async def list_tasks():
    """获取所有任务"""
    tasks = get_all_tasks()
    return {
        "tasks": tasks,
        "count": len(tasks)
    }

@router.post("/clear", 
           summary="清理已完成任务",
           description="清理已完成或失败的任务记录")
async def clear_tasks():
    """清理已完成任务"""
    clear_completed_tasks()
    return {"message": "已清理完成的任务"}
