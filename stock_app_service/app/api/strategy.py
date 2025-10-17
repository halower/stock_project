# -*- coding: utf-8 -*-
"""策略相关API路由"""

from fastapi import APIRouter, Depends
from typing import List
from pydantic import BaseModel

from app.indicators import get_all_strategies
from app.api.dependencies import verify_token

# 定义响应模型
class StrategyInfo(BaseModel):
    code: str
    name: str
    description: str

class StrategiesResponse(BaseModel):
    strategies: List[StrategyInfo]
    total: int

router = APIRouter(tags=["策略管理"])

@router.get("/api/strategies", response_model=StrategiesResponse, summary="获取所有可用策略", dependencies=[Depends(verify_token)])
async def get_strategies() -> StrategiesResponse:
    """
    获取系统中所有可用的交易策略
    
    Returns:
        所有注册的策略信息列表
    """
    strategies_info = get_all_strategies()
    
    # 将字典转换为列表格式
    strategies_list = [
        StrategyInfo(
            code=info["code"],
            name=info["name"],
            description=info["description"]
        ) for info in strategies_info.values()
    ]
    
    return StrategiesResponse(
        strategies=strategies_list,
        total=len(strategies_list)
    ) 