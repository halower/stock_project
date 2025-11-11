# -*- coding: utf-8 -*-
"""
任务管理API
提供异步任务的管理和状态查询接口
"""
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import Dict, Any, List, Optional
from datetime import datetime

from app.tasks.stock_data_tasks import get_task_status, get_all_tasks, clear_completed_tasks
from app.services.stock.stock_atomic_service import stock_atomic_service
from app.api.dependencies import verify_token
from app.core.logging import logger

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

class SignalCalculationResponse(BaseModel):
    """信号计算响应"""
    success: bool
    message: str
    data: Optional[Dict[str, Any]] = None

# ===================== API接口 =====================

@router.post("/calculate-signals", response_model=SignalCalculationResponse, summary="触发策略信号计算", dependencies=[Depends(verify_token)])
async def trigger_signal_calculation(
    stock_only: bool = True
):
    """
    手动触发策略信号计算
    
    Args:
        stock_only: 是否仅计算股票信号（默认True，盘中建议仅计算股票）
    
    Returns:
        信号计算结果统计
    """
    try:
        logger.info(f"手动触发信号计算，stock_only={stock_only}")
        
        # 调用原子服务的信号计算方法
        result = await stock_atomic_service.calculate_strategy_signals(
            force_recalculate=False,
            stock_only=stock_only
        )
        
        if result.get('success'):
            return SignalCalculationResponse(
                success=True,
                message=f"信号计算成功: {result.get('message', '')}",
                data=result
            )
        else:
            return SignalCalculationResponse(
                success=False,
                message=f"信号计算失败: {result.get('message', '未知错误')}",
                data=result
            )
        
    except Exception as e:
        logger.error(f"触发信号计算失败: {e}")
        import traceback
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"触发信号计算失败: {str(e)}")


