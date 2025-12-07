# -*- coding: utf-8 -*-
"""
打板分析API路由
提供涨跌停、龙虎榜、连板统计等接口
"""

from typing import Optional
from fastapi import APIRouter, Query, HTTPException
from datetime import datetime

from app.core.logging import logger
from app.services.limit_board import limit_board_service

router = APIRouter(prefix="/limit-board", tags=["打板分析"])


@router.get("/limit-list")
async def get_limit_list(
    trade_date: Optional[str] = Query(None, description="交易日期，格式YYYYMMDD，默认最近交易日"),
    limit_type: str = Query('U', description="涨跌停类型: U-涨停, D-跌停"),
    use_cache: bool = Query(True, description="是否使用缓存")
):
    """
    获取每日涨跌停列表
    
    - **trade_date**: 交易日期，格式YYYYMMDD，不传则使用最近交易日
    - **limit_type**: 涨跌停类型，U表示涨停，D表示跌停
    - **use_cache**: 是否使用缓存，默认True
    """
    try:
        result = await limit_board_service.async_get_limit_list(
            trade_date=trade_date,
            limit_type=limit_type,
            use_cache=use_cache
        )
        return result
    except Exception as e:
        logger.error(f"获取涨跌停数据失败: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/top-list")
async def get_top_list(
    trade_date: Optional[str] = Query(None, description="交易日期，格式YYYYMMDD"),
    use_cache: bool = Query(True, description="是否使用缓存")
):
    """
    获取龙虎榜数据
    
    - **trade_date**: 交易日期，格式YYYYMMDD，不传则使用最近交易日
    - **use_cache**: 是否使用缓存，默认True
    """
    try:
        result = await limit_board_service.async_get_top_list(
            trade_date=trade_date,
            use_cache=use_cache
        )
        return result
    except Exception as e:
        logger.error(f"获取龙虎榜数据失败: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/continuous-stats")
async def get_continuous_stats(
    trade_date: Optional[str] = Query(None, description="交易日期，格式YYYYMMDD"),
    use_cache: bool = Query(True, description="是否使用缓存")
):
    """
    获取连板统计数据
    
    - **trade_date**: 交易日期，格式YYYYMMDD，不传则使用最近交易日
    - **use_cache**: 是否使用缓存，默认True
    
    返回各连板数的股票数量统计，以及3连板以上的高连板股票列表
    """
    try:
        result = limit_board_service.get_continuous_limit_stats(
            trade_date=trade_date,
            use_cache=use_cache
        )
        return result
    except Exception as e:
        logger.error(f"获取连板统计失败: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/summary")
async def get_limit_board_summary(
    trade_date: Optional[str] = Query(None, description="交易日期，格式YYYYMMDD"),
    use_cache: bool = Query(True, description="是否使用缓存")
):
    """
    获取打板综合数据
    
    - **trade_date**: 交易日期，格式YYYYMMDD，不传则使用最近交易日
    - **use_cache**: 是否使用缓存，默认True
    
    返回涨停、跌停、龙虎榜、连板统计等综合数据
    """
    try:
        result = await limit_board_service.async_get_limit_board_summary(
            trade_date=trade_date,
            use_cache=use_cache
        )
        return result
    except Exception as e:
        logger.error(f"获取打板综合数据失败: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/up-limit")
async def get_up_limit_list(
    trade_date: Optional[str] = Query(None, description="交易日期，格式YYYYMMDD"),
    use_cache: bool = Query(True, description="是否使用缓存")
):
    """
    获取涨停板列表（快捷接口）
    """
    return await get_limit_list(trade_date, 'U', use_cache)


@router.get("/down-limit")
async def get_down_limit_list(
    trade_date: Optional[str] = Query(None, description="交易日期，格式YYYYMMDD"),
    use_cache: bool = Query(True, description="是否使用缓存")
):
    """
    获取跌停板列表（快捷接口）
    """
    return await get_limit_list(trade_date, 'D', use_cache)


@router.get("/hot-money-detail")
async def get_hot_money_detail(
    trade_date: Optional[str] = Query(None, description="交易日期，格式YYYYMMDD"),
    ts_code: Optional[str] = Query(None, description="股票代码，可选"),
    use_cache: bool = Query(True, description="是否使用缓存")
):
    """
    获取每日游资交易明细
    
    - **trade_date**: 交易日期，格式YYYYMMDD，不传则使用最近交易日
    - **ts_code**: 股票代码（可选），用于查询特定股票的游资明细
    - **use_cache**: 是否使用缓存，默认True
    
    返回游资交易明细列表，包含游资名称、股票代码、买入卖出金额等信息
    """
    try:
        result = await limit_board_service.async_get_hot_money_detail(
            trade_date=trade_date,
            ts_code=ts_code,
            use_cache=use_cache
        )
        return result
    except Exception as e:
        logger.error(f"获取游资明细失败: {e}")
        raise HTTPException(status_code=500, detail=str(e))

