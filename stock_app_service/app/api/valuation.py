# -*- coding: utf-8 -*-
"""估值分析API接口"""

from fastapi import APIRouter, Depends, HTTPException, Query
from typing import Dict, Any, Optional
from pydantic import BaseModel

from app.api.dependencies import verify_token
from app.core.logging import logger
from app.services.valuation.valuation_service import ValuationService

router = APIRouter(tags=["估值分析"])

# 初始化服务
valuation_service = ValuationService()


# 响应模型
class ValuationScreeningResponse(BaseModel):
    """估值分析响应"""
    success: bool
    data: list
    count: int
    filters: Optional[dict] = None
    timestamp: str


class ValuationRankingResponse(BaseModel):
    """估值排名响应"""
    success: bool
    rank_by: str
    order: str
    data: list
    count: int
    timestamp: str


class ValuationDetailResponse(BaseModel):
    """估值详情响应"""
    success: bool
    stock_code: str
    ts_code: Optional[str] = None
    stock_name: Optional[str] = None
    current_valuation: Optional[dict] = None
    timestamp: Optional[str] = None


@router.get("/valuation/screening",
           summary="估值分析",
           dependencies=[Depends(verify_token)])
async def screening_by_valuation(
    pe_min: Optional[float] = Query(None, description="PE最小值"),
    pe_max: Optional[float] = Query(None, description="PE最大值"),
    pb_min: Optional[float] = Query(None, description="PB最小值"),
    pb_max: Optional[float] = Query(None, description="PB最大值"),
    ps_min: Optional[float] = Query(None, description="PS最小值"),
    ps_max: Optional[float] = Query(None, description="PS最大值"),
    dividend_yield_min: Optional[float] = Query(None, description="股息率最小值(%)"),
    market_value_min: Optional[float] = Query(None, description="市值最小值(亿元)"),
    market_value_max: Optional[float] = Query(None, description="市值最大值(亿元)"),
    limit: int = Query(100, ge=1, le=500, description="返回数量限制")
) -> Dict[str, Any]:
    """
    按估值指标筛选股票
    
    Args:
        pe_min: PE最小值
        pe_max: PE最大值
        pb_min: PB最小值
        pb_max: PB最大值
        ps_min: PS最小值
        ps_max: PS最大值
        dividend_yield_min: 股息率最小值(%)
        market_value_min: 市值最小值(亿元)
        market_value_max: 市值最大值(亿元)
        limit: 返回数量限制（1-500）
    
    Returns:
        筛选结果列表
    """
    try:
        logger.info(f"API请求：估值分析，PE=[{pe_min},{pe_max}], PB=[{pb_min},{pb_max}], 限制={limit}")
        
        result = await valuation_service.screening_by_valuation(
            pe_min=pe_min,
            pe_max=pe_max,
            pb_min=pb_min,
            pb_max=pb_max,
            ps_min=ps_min,
            ps_max=ps_max,
            dividend_yield_min=dividend_yield_min,
            market_value_min=market_value_min,
            market_value_max=market_value_max,
            limit=limit
        )
        
        if not result['success']:
            raise HTTPException(status_code=500, detail=result.get('error', '估值分析失败'))
        
        return result
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"估值分析API异常: {e}")
        raise HTTPException(status_code=500, detail=f"估值分析失败: {str(e)}")


@router.get("/valuation/ranking",
           summary="估值排名",
           dependencies=[Depends(verify_token)])
async def get_valuation_ranking(
    rank_by: str = Query('pe', description="排名依据：pe, pb, ps, dividend_yield, market_value"),
    order: str = Query('asc', description="排序方式：asc=升序, desc=降序"),
    limit: int = Query(100, ge=1, le=500, description="返回数量限制")
) -> Dict[str, Any]:
    """
    获取估值排名
    
    Args:
        rank_by: 排名依据
            - pe: 按市盈率排名
            - pb: 按市净率排名
            - ps: 按市销率排名
            - dividend_yield: 按股息率排名
            - market_value: 按市值排名
        order: 排序方式
            - asc: 升序（从小到大）
            - desc: 降序（从大到小）
        limit: 返回数量限制（1-500）
    
    Returns:
        排名列表
    """
    try:
        logger.info(f"API请求：估值排名，排序字段={rank_by}，顺序={order}，限制={limit}")
        
        if rank_by not in ['pe', 'pb', 'ps', 'dividend_yield', 'market_value']:
            raise HTTPException(status_code=400, detail="无效的排名依据")
        
        if order not in ['asc', 'desc']:
            raise HTTPException(status_code=400, detail="无效的排序方式")
        
        result = await valuation_service.get_valuation_ranking(
            rank_by=rank_by,
            order=order,
            limit=limit
        )
        
        if not result['success']:
            raise HTTPException(status_code=500, detail=result.get('error', '获取估值排名失败'))
        
        return result
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"估值排名API异常: {e}")
        raise HTTPException(status_code=500, detail=f"获取估值排名失败: {str(e)}")


@router.get("/valuation/{stock_code}/detail",
           summary="个股估值详情",
           dependencies=[Depends(verify_token)])
async def get_stock_valuation_detail(
    stock_code: str
) -> Dict[str, Any]:
    """
    获取个股估值详情
    
    Args:
        stock_code: 股票代码（如：000001）
    
    Returns:
        估值详情数据
    """
    try:
        logger.info(f"API请求：获取股票估值详情，代码={stock_code}")
        
        result = await valuation_service.get_stock_valuation_detail(stock_code=stock_code)
        
        if not result['success']:
            raise HTTPException(status_code=500, detail=result.get('error', '获取估值详情失败'))
        
        return result
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取估值详情API异常: {e}")
        raise HTTPException(status_code=500, detail=f"获取估值详情失败: {str(e)}")


@router.get("/valuation/preset/low-value-blue-chip",
           summary="低估值蓝筹筛选",
           dependencies=[Depends(verify_token)])
async def get_low_value_blue_chip(
    limit: int = Query(50, ge=1, le=200, description="返回数量限制")
) -> Dict[str, Any]:
    """
    低估值蓝筹股筛选
    
    筛选条件：PE < 15, PB < 2, 市值 > 100亿
    
    Args:
        limit: 返回数量限制
    
    Returns:
        筛选结果
    """
    try:
        logger.info("API请求：低估值蓝筹筛选")
        
        result = await valuation_service.screening_by_valuation(
            pe_min=0,
            pe_max=15,
            pb_min=0,
            pb_max=2,
            market_value_min=100,
            limit=limit
        )
        
        if not result['success']:
            raise HTTPException(status_code=500, detail=result.get('error', '筛选失败'))
        
        return result
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"低估值蓝筹筛选API异常: {e}")
        raise HTTPException(status_code=500, detail=f"筛选失败: {str(e)}")


@router.get("/valuation/preset/high-dividend",
           summary="高股息股票筛选",
           dependencies=[Depends(verify_token)])
async def get_high_dividend_stocks(
    limit: int = Query(50, ge=1, le=200, description="返回数量限制")
) -> Dict[str, Any]:
    """
    高股息股票筛选
    
    筛选条件：股息率 > 3%
    
    Args:
        limit: 返回数量限制
    
    Returns:
        筛选结果
    """
    try:
        logger.info("API请求：高股息股票筛选")
        
        result = await valuation_service.screening_by_valuation(
            dividend_yield_min=3.0,
            limit=limit
        )
        
        if not result['success']:
            raise HTTPException(status_code=500, detail=result.get('error', '筛选失败'))
        
        return result
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"高股息股票筛选API异常: {e}")
        raise HTTPException(status_code=500, detail=f"筛选失败: {str(e)}")


@router.get("/valuation/preset/growth-value",
           summary="成长价值股筛选",
           dependencies=[Depends(verify_token)])
async def get_growth_value_stocks(
    limit: int = Query(50, ge=1, le=200, description="返回数量限制")
) -> Dict[str, Any]:
    """
    成长价值股筛选
    
    筛选条件：PE < 30, PB < 5
    
    Args:
        limit: 返回数量限制
    
    Returns:
        筛选结果
    """
    try:
        logger.info("API请求：成长价值股筛选")
        
        result = await valuation_service.screening_by_valuation(
            pe_min=0,
            pe_max=30,
            pb_min=0,
            pb_max=5,
            limit=limit
        )
        
        if not result['success']:
            raise HTTPException(status_code=500, detail=result.get('error', '筛选失败'))
        
        return result
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"成长价值股筛选API异常: {e}")
        raise HTTPException(status_code=500, detail=f"筛选失败: {str(e)}")

