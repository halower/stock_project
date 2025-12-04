# -*- coding: utf-8 -*-
"""
专业指数分析API - TradingView级别的专业图表和分析
仅支持三大核心指数：上证指数、深证成指、创业板指
"""

from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import HTMLResponse, RedirectResponse
from typing import Dict, Any, Optional
from pydantic import BaseModel

from app.core.logging import logger
from app.services.index.index_service import index_service
from app.services.index.index_chart_service import index_chart_service

router = APIRouter(prefix="/api/index", tags=["专业指数分析"])


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
    """专业指数分析响应模型"""
    success: bool
    chart_url: Optional[str] = None
    technical_analysis: Optional[Dict[str, Any]] = None
    market_sentiment: Optional[Dict[str, Any]] = None
    key_metrics: Optional[Dict[str, Any]] = None
    key_levels: Optional[Dict[str, Any]] = None  # 关键点位（散户最关心）
    index_code: Optional[str] = None
    index_name: Optional[str] = None
    index_info: Optional[Dict[str, Any]] = None
    error: Optional[str] = None


class IndexListResponse(BaseModel):
    """指数列表响应模型"""
    success: bool
    data: Optional[list] = None
    count: Optional[int] = None
    error: Optional[str] = None


@router.get("/list", response_model=IndexListResponse, summary="获取三大核心指数列表")
async def get_index_list():
    """
    获取三大核心指数列表
    
    专业版仅支持：
    - 上证指数 (000001.SH)
    - 深证成指 (399001.SZ)
    - 创业板指 (399006.SZ)
    
    Returns:
        三大核心指数列表，包含代码、名称、市场、描述等信息
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
        description="指数代码（仅支持三大核心指数）：000001.SH（上证指数）、399001.SZ（深证成指）、399006.SZ（创业板指）"
    ),
    days: int = Query(
        default=180,
        ge=30,
        le=1000,
        description="获取天数，范围30-1000天，推荐180天"
    )
):
    """
    获取指数日线K线数据
    
    专业版仅支持三大核心指数的原始K线数据。
    
    Args:
        index_code: 指数代码（仅支持三大核心指数）
        days: 获取天数（推荐180天以获得更好的技术分析效果）
        
    Returns:
        指数日线K线数据，包含开高低收、成交量等
    """
    try:
        result = await index_service.get_index_daily(index_code, days)
        return IndexDataResponse(**result)
        
    except Exception as e:
        logger.error(f"获取指数日线数据失败: {e}")
        raise HTTPException(status_code=500, detail=f"获取指数日线数据失败: {str(e)}")


@router.get("/chart", summary="获取专业指数图表")
async def get_index_chart(
    index_code: str = Query(
        default="000001.SH",
        description="指数代码（仅支持：000001.SH、399001.SZ、399006.SZ）"
    ),
    days: int = Query(
        default=180,
        ge=30,
        le=1000,
        description="获取天数，推荐180天"
    ),
    theme: str = Query(
        default="dark",
        description="图表主题: dark（推荐）或 light"
    )
):
    """
    获取TradingView级别的专业指数图表
    
    专业特性：
    - 动量守恒增强版策略
    - 多维度技术指标
    - 专业级可视化
    - 交易信号标注
    
    仅支持三大核心指数：
    - 上证指数 (000001.SH)
    - 深证成指 (399001.SZ)
    - 创业板指 (399006.SZ)
    
    Args:
        index_code: 指数代码（仅支持三大核心指数）
        days: 获取天数（推荐180天）
        theme: 图表主题（推荐dark深色主题）
        
    Returns:
        重定向到专业图表HTML文件
    """
    try:
        result = await index_chart_service.generate_index_chart(index_code, days, theme)
        
        if not result['success']:
            raise HTTPException(status_code=400, detail=result.get('error', '生成专业图表失败'))
        
        # 重定向到专业图表文件
        return RedirectResponse(url=result['chart_url'])
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取专业指数图表失败: {e}")
        raise HTTPException(status_code=500, detail=f"获取专业指数图表失败: {str(e)}")


@router.get("/analysis", response_model=IndexAnalysisResponse, summary="获取专业指数分析")
async def get_index_analysis(
    index_code: str = Query(
        default="000001.SH",
        description="指数代码（仅支持：000001.SH、399001.SZ、399006.SZ）"
    ),
    days: int = Query(
        default=180,
        ge=30,
        le=1000,
        description="获取天数，推荐180天"
    ),
    theme: str = Query(
        default="dark",
        description="图表主题: dark（推荐）或 light"
    )
):
    """
    获取TradingView级别的专业指数完整分析
    
    专业分析包含：
    1. 专业图表URL（动量守恒增强版策略）
    2. 技术分析（MA、MACD、RSI、布林带等）
    3. 市场情绪分析（多空力量、成交量趋势）
    4. 关键指标（波动率、最大回撤、夏普比率等）
    
    仅支持三大核心指数：
    - 上证指数 (000001.SH) - 上海市场综合指数
    - 深证成指 (399001.SZ) - 深圳市场成份指数
    - 创业板指 (399006.SZ) - 创业板综合指数
    
    Args:
        index_code: 指数代码（仅支持三大核心指数）
        days: 获取天数（推荐180天以获得更准确的技术分析）
        theme: 图表主题（推荐dark深色主题）
        
    Returns:
        {
            'success': bool,
            'chart_url': str,  # 专业图表URL
            'technical_analysis': {  # 技术分析
                'trend': str,  # 趋势判断
                'moving_averages': {},  # 移动平均线
                'macd': {},  # MACD指标
                'rsi': {},  # RSI指标
                'bollinger_bands': {}  # 布林带
            },
            'market_sentiment': {  # 市场情绪
                'sentiment': str,  # 情绪描述
                'sentiment_score': float,  # 情绪评分
                'volume_trend': str  # 成交量趋势
            },
            'key_metrics': {  # 关键指标
                'current_price': float,
                'period_return': float,
                'volatility': float,
                'max_drawdown': float,
                'sharpe_ratio': float
            },
            'index_info': {}  # 指数详细信息
        }
    """
    try:
        result = await index_chart_service.get_index_analysis(index_code, days, theme)
        return IndexAnalysisResponse(**result)
        
    except Exception as e:
        logger.error(f"获取专业指数分析失败: {e}")
        raise HTTPException(status_code=500, detail=f"获取专业指数分析失败: {str(e)}")

