# -*- coding: utf-8 -*-
"""
指数分析API - 提供大盘指数数据和图表
"""

from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import HTMLResponse, RedirectResponse
from typing import Dict, Any, Optional
from pydantic import BaseModel

from app.core.logging import logger
from app.services.index.index_service import index_service
from app.services.index.index_chart_service import index_chart_service

router = APIRouter(prefix="/api/index", tags=["指数分析"])


class IndexDataResponse(BaseModel):
    """指数数据响应模型"""
    success: bool
    data: Optional[list] = None
    count: Optional[int] = None
    index_code: Optional[str] = None
    index_name: Optional[str] = None
    error: Optional[str] = None


class IndexChartResponse(BaseModel):
    """指数图表响应模型"""
    success: bool
    chart_data: Optional[Dict[str, Any]] = None
    index_code: Optional[str] = None
    index_name: Optional[str] = None
    error: Optional[str] = None


class IndexAnalysisResponse(BaseModel):
    """指数分析响应模型"""
    success: bool
    chart_data: Optional[Dict[str, Any]] = None
    statistics: Optional[Dict[str, Any]] = None
    index_code: Optional[str] = None
    index_name: Optional[str] = None
    error: Optional[str] = None


class IndexListResponse(BaseModel):
    """指数列表响应模型"""
    success: bool
    data: Optional[list] = None
    count: Optional[int] = None
    error: Optional[str] = None


@router.get("/list", response_model=IndexListResponse, summary="获取指数列表")
async def get_index_list():
    """
    获取常用指数列表
    
    Returns:
        指数列表，包含代码、名称、市场等信息
    """
    try:
        result = await index_service.get_index_list()
        return IndexListResponse(**result)
        
    except Exception as e:
        logger.error(f"获取指数列表失败: {e}")
        raise HTTPException(status_code=500, detail=f"获取指数列表失败: {str(e)}")


@router.get("/daily", response_model=IndexDataResponse, summary="获取指数日线数据")
async def get_index_daily(
    index_code: str = Query(
        default="000001.SH",
        description="指数代码，如：000001.SH（上证指数）、399001.SZ（深证成指）、399006.SZ（创业板指）"
    ),
    days: int = Query(
        default=180,
        ge=30,
        le=1000,
        description="获取天数，范围30-1000天"
    )
):
    """
    获取指数日线数据
    
    Args:
        index_code: 指数代码
        days: 获取天数
        
    Returns:
        指数日线K线数据
    """
    try:
        result = await index_service.get_index_daily(index_code, days)
        return IndexDataResponse(**result)
        
    except Exception as e:
        logger.error(f"获取指数日线数据失败: {e}")
        raise HTTPException(status_code=500, detail=f"获取指数日线数据失败: {str(e)}")


@router.get("/chart", summary="获取指数图表")
async def get_index_chart(
    index_code: str = Query(
        default="000001.SH",
        description="指数代码"
    ),
    days: int = Query(
        default=180,
        ge=30,
        le=1000,
        description="获取天数"
    ),
    theme: str = Query(
        default="dark",
        description="图表主题: light 或 dark"
    )
):
    """
    获取指数图表（直接返回HTML或重定向到图表文件）
    
    Args:
        index_code: 指数代码
        days: 获取天数
        theme: 图表主题
        
    Returns:
        重定向到图表HTML文件
    """
    try:
        result = await index_chart_service.generate_index_chart(index_code, days, theme)
        
        if not result['success']:
            raise HTTPException(status_code=500, detail=result.get('error', '生成图表失败'))
        
        # 重定向到图表文件
        return RedirectResponse(url=result['chart_url'])
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取指数图表失败: {e}")
        raise HTTPException(status_code=500, detail=f"获取指数图表失败: {str(e)}")


@router.get("/analysis", response_model=IndexAnalysisResponse, summary="获取指数分析")
async def get_index_analysis(
    index_code: str = Query(
        default="000001.SH",
        description="指数代码"
    ),
    days: int = Query(
        default=180,
        ge=30,
        le=1000,
        description="获取天数"
    ),
    theme: str = Query(
        default="dark",
        description="图表主题: light 或 dark"
    )
):
    """
    获取指数完整分析数据（图表URL+统计信息）
    
    Args:
        index_code: 指数代码
        days: 获取天数
        theme: 图表主题
        
    Returns:
        图表URL和统计信息
    """
    try:
        result = await index_chart_service.get_index_analysis(index_code, days, theme)
        return IndexAnalysisResponse(**result)
        
    except Exception as e:
        logger.error(f"获取指数分析失败: {e}")
        raise HTTPException(status_code=500, detail=f"获取指数分析失败: {str(e)}")

