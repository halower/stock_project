# -*- coding: utf-8 -*-
"""板块分析API接口"""

from fastapi import APIRouter, Depends, HTTPException, Query
from typing import Dict, Any, Optional
from pydantic import BaseModel

from app.api.dependencies import verify_token
from app.core.logging import logger
from app.services.sector.sector_service import SectorService

router = APIRouter(tags=["板块分析"])

# 初始化服务
sector_service = SectorService()


# 响应模型
class SectorListResponse(BaseModel):
    """板块列表响应"""
    success: bool
    data: list
    count: int
    timestamp: str
    from_cache: Optional[bool] = False


class SectorMembersResponse(BaseModel):
    """板块成分股响应"""
    success: bool
    sector_code: str
    data: list
    count: int
    from_cache: Optional[bool] = False


class SectorStrengthResponse(BaseModel):
    """板块强度响应"""
    success: bool
    sector_code: str
    avg_change_pct: Optional[float] = None
    up_count: Optional[int] = None
    down_count: Optional[int] = None
    limit_up_count: Optional[int] = None
    limit_down_count: Optional[int] = None
    avg_turnover_rate: Optional[float] = None
    total_amount: Optional[float] = None
    leading_stock: Optional[dict] = None
    sample_count: Optional[int] = None
    total_count: Optional[int] = None
    timestamp: Optional[str] = None


class SectorRankingResponse(BaseModel):
    """板块排名响应"""
    success: bool
    rank_type: str
    data: list
    count: int
    timestamp: str


class HotConceptsResponse(BaseModel):
    """热门概念响应"""
    success: bool
    data: list
    count: int
    timestamp: str


@router.get("/sector/list", 
           summary="获取板块列表",
           dependencies=[Depends(verify_token)])
async def get_sector_list(
    exchange: str = Query('A', description="交易所代码：A=全部，N=概念，I=行业")
) -> Dict[str, Any]:
    """
    获取板块列表
    
    Args:
        exchange: 交易所代码
            - A: 全部板块
            - N: 概念板块
            - I: 行业板块
    
    Returns:
        板块列表数据
    """
    try:
        logger.info(f"API请求：获取板块列表，类型={exchange}")
        result = await sector_service.get_sector_list(exchange=exchange)
        
        if not result['success']:
            raise HTTPException(status_code=500, detail=result.get('error', '获取板块列表失败'))
        
        return result
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取板块列表API异常: {e}")
        raise HTTPException(status_code=500, detail=f"获取板块列表失败: {str(e)}")


@router.get("/sector/{sector_code}/members",
           summary="获取板块成分股",
           dependencies=[Depends(verify_token)])
async def get_sector_members(
    sector_code: str
) -> Dict[str, Any]:
    """
    获取板块成分股列表
    
    Args:
        sector_code: 板块代码（如：885771.TI）
    
    Returns:
        成分股列表数据
    """
    try:
        logger.info(f"API请求：获取板块成分股，板块代码={sector_code}")
        result = await sector_service.get_sector_members(sector_code=sector_code)
        
        if not result['success']:
            raise HTTPException(status_code=500, detail=result.get('error', '获取成分股失败'))
        
        return result
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取板块成分股API异常: {e}")
        raise HTTPException(status_code=500, detail=f"获取成分股失败: {str(e)}")


@router.get("/sector/{sector_code}/strength",
           summary="获取板块强度",
           dependencies=[Depends(verify_token)])
async def get_sector_strength(
    sector_code: str
) -> Dict[str, Any]:
    """
    获取板块强度指标
    
    计算板块的平均涨跌幅、涨停数、换手率等指标
    
    Args:
        sector_code: 板块代码
    
    Returns:
        板块强度数据
    """
    try:
        logger.info(f"API请求：获取板块强度，板块代码={sector_code}")
        result = await sector_service.calculate_sector_strength(sector_code=sector_code)
        
        if not result['success']:
            raise HTTPException(status_code=500, detail=result.get('error', '计算板块强度失败'))
        
        return result
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取板块强度API异常: {e}")
        raise HTTPException(status_code=500, detail=f"计算板块强度失败: {str(e)}")


@router.get("/sector/ranking",
           summary="获取板块排名",
           dependencies=[Depends(verify_token)])
async def get_sector_ranking(
    rank_type: str = Query('change', description="排名类型：change=涨跌幅，amount=成交额，turnover=换手率"),
    limit: int = Query(50, ge=1, le=100, description="返回数量限制")
) -> Dict[str, Any]:
    """
    获取板块排名
    
    Args:
        rank_type: 排名类型
            - change: 按涨跌幅排名
            - amount: 按成交额排名
            - turnover: 按换手率排名
        limit: 返回数量限制（1-100）
    
    Returns:
        板块排名数据
    """
    try:
        logger.info(f"API请求：获取板块排名，类型={rank_type}，限制={limit}")
        
        if rank_type not in ['change', 'amount', 'turnover']:
            raise HTTPException(status_code=400, detail="无效的排名类型")
        
        result = await sector_service.get_sector_ranking(rank_type=rank_type, limit=limit)
        
        if not result['success']:
            raise HTTPException(status_code=500, detail=result.get('error', '获取板块排名失败'))
        
        return result
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取板块排名API异常: {e}")
        raise HTTPException(status_code=500, detail=f"获取板块排名失败: {str(e)}")


@router.get("/sector/hot-concepts",
           summary="获取热门概念",
           dependencies=[Depends(verify_token)])
async def get_hot_concepts(
    limit: int = Query(20, ge=1, le=50, description="返回数量限制")
) -> Dict[str, Any]:
    """
    获取热门概念板块
    
    基于涨停股数量、平均涨幅等指标筛选热门概念
    
    Args:
        limit: 返回数量限制（1-50）
    
    Returns:
        热门概念列表
    """
    try:
        logger.info(f"API请求：获取热门概念，限制={limit}")
        result = await sector_service.get_hot_concepts(limit=limit)
        
        if not result['success']:
            raise HTTPException(status_code=500, detail=result.get('error', '获取热门概念失败'))
        
        return result
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取热门概念API异常: {e}")
        raise HTTPException(status_code=500, detail=f"获取热门概念失败: {str(e)}")


@router.get("/sector/{sector_code}/detail",
           summary="获取板块详情",
           dependencies=[Depends(verify_token)])
async def get_sector_detail(
    sector_code: str
) -> Dict[str, Any]:
    """
    获取板块详细信息（包含成分股和强度指标）
    
    Args:
        sector_code: 板块代码
    
    Returns:
        板块详细信息
    """
    try:
        logger.info(f"API请求：获取板块详情，板块代码={sector_code}")
        
        # 获取成分股
        members_result = await sector_service.get_sector_members(sector_code=sector_code)
        
        # 获取强度指标
        strength_result = await sector_service.calculate_sector_strength(sector_code=sector_code)
        
        # 组合返回
        return {
            'success': True,
            'sector_code': sector_code,
            'members': members_result.get('data', []),
            'member_count': members_result.get('count', 0),
            'strength': strength_result if strength_result['success'] else None,
            'timestamp': strength_result.get('timestamp', '')
        }
        
    except Exception as e:
        logger.error(f"获取板块详情API异常: {e}")
        raise HTTPException(status_code=500, detail=f"获取板块详情失败: {str(e)}")

