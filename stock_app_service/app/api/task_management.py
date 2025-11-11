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
    手动触发策略信号计算（在后台线程中执行，不阻塞API）
    
    Args:
        stock_only: 是否仅计算股票信号（默认True，盘中建议仅计算股票）
    
    Returns:
        信号计算结果统计
    """
    try:
        logger.info(f"手动触发信号计算，stock_only={stock_only}")
        
        # 在线程池中执行，避免阻塞主事件循环
        import asyncio
        import concurrent.futures
        
        def _run_signal_calculation():
            """在独立线程中运行信号计算"""
            # 创建新的事件循环
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            try:
                result = loop.run_until_complete(
                    stock_atomic_service.calculate_strategy_signals(
                        force_recalculate=False,
                        stock_only=stock_only
                    )
                )
                return result
            finally:
                loop.close()
        
        # 在线程池中执行
        loop = asyncio.get_event_loop()
        with concurrent.futures.ThreadPoolExecutor() as executor:
            result = await loop.run_in_executor(executor, _run_signal_calculation)
        
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


