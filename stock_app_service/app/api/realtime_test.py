# -*- coding: utf-8 -*-
"""
实时数据测试接口
用于临时测试实时数据获取和更新功能
"""

from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel, Field
from typing import Optional, Literal

from app.core.logging import logger
from app.services.realtime import get_realtime_service
from app.services.stock.stock_atomic_service import stock_atomic_service
from app.api.dependencies import verify_token

router = APIRouter()


class RealtimeTestResponse(BaseModel):
    """实时测试响应"""
    success: bool
    message: str
    data: dict


@router.get("/api/realtime/test/fetch", response_model=RealtimeTestResponse, dependencies=[Depends(verify_token)])
async def test_fetch_realtime(
    provider: Optional[Literal["eastmoney", "sina", "auto"]] = "auto",
    include_etf: bool = False,
    limit: int = 10
):
    """
    测试获取实时数据
    
    Args:
        provider: 数据提供商（eastmoney, sina, auto）
        include_etf: 是否包含ETF
        limit: 返回数据条数限制
    
    Returns:
        实时数据样例
    """
    try:
        logger.info(f"测试获取实时数据: provider={provider}, include_etf={include_etf}")
        
        # 获取实时服务
        service = get_realtime_service()
        
        # 获取实时数据
        result = service.get_all_stocks_realtime(provider=provider, include_etf=include_etf)
        
        if not result.get('success'):
            return RealtimeTestResponse(
                success=False,
                message=f"获取失败: {result.get('error')}",
                data=result
            )
        
        # 限制返回数量
        data = result.get('data', [])
        limited_data = data[:limit] if limit > 0 else data
        
        return RealtimeTestResponse(
            success=True,
            message=f"成功获取 {result.get('count', 0)} 条数据（显示前{len(limited_data)}条）",
            data={
                'total_count': result.get('count', 0),
                'source': result.get('source'),
                'update_time': result.get('update_time'),
                'sample_data': limited_data,
                'stats': service.get_stats()
            }
        )
        
    except Exception as e:
        logger.error(f"测试获取实时数据失败: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/api/realtime/test/update", response_model=RealtimeTestResponse, dependencies=[Depends(verify_token)])
async def test_realtime_update():
    """
    测试实时更新功能
    
    触发一次完整的实时数据更新流程：
    1. 获取所有股票和ETF的实时数据
    2. 更新到Redis历史K线数据
    
    Returns:
        更新结果统计
    """
    try:
        logger.info("测试触发实时更新...")
        
        # 调用原子服务的实时更新方法
        result = await stock_atomic_service.realtime_update_all_stocks()
        
        if result.get('success'):
            return RealtimeTestResponse(
                success=True,
                message=f"实时更新成功: 股票 {result.get('stock_count', 0)} 只, ETF {result.get('etf_count', 0)} 只",
                data=result
            )
        else:
            return RealtimeTestResponse(
                success=False,
                message=f"实时更新失败: {result.get('message')}",
                data=result
            )
        
    except Exception as e:
        logger.error(f"测试实时更新失败: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/api/realtime/test/etf", response_model=RealtimeTestResponse, dependencies=[Depends(verify_token)])
async def test_fetch_etf_realtime(
    provider: Optional[Literal["eastmoney", "sina", "auto"]] = "auto",
    limit: int = 10
):
    """
    测试获取ETF实时数据
    
    Args:
        provider: 数据提供商
        limit: 返回数据条数限制
    
    Returns:
        ETF实时数据样例
    """
    try:
        logger.info(f"测试获取ETF实时数据: provider={provider}")
        
        # 获取实时服务
        service = get_realtime_service()
        
        # 获取ETF实时数据
        result = service.get_all_etfs_realtime(provider=provider)
        
        if not result.get('success'):
            return RealtimeTestResponse(
                success=False,
                message=f"获取失败: {result.get('error')}",
                data=result
            )
        
        # 限制返回数量
        data = result.get('data', [])
        limited_data = data[:limit] if limit > 0 else data
        
        return RealtimeTestResponse(
            success=True,
            message=f"成功获取 {result.get('count', 0)} 只ETF（显示前{len(limited_data)}只）",
            data={
                'total_count': result.get('count', 0),
                'source': result.get('source'),
                'update_time': result.get('update_time'),
                'sample_data': limited_data,
                'stats': service.get_stats()
            }
        )
        
    except Exception as e:
        logger.error(f"测试获取ETF实时数据失败: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/api/realtime/test/service-info")
async def test_service_info():
    """
    获取实时服务信息
    
    Returns:
        服务配置和统计信息
    """
    try:
        service = get_realtime_service()
        
        return {
            'success': True,
            'config': {
                'default_provider': service.config.default_provider.value,
                'auto_switch': service.config.auto_switch,
                'retry_times': service.config.retry_times,
                'timeout': service.config.timeout,
                'mode': 'direct'  # 直连模式
            },
            'service_stats': service.get_stats()
        }
        
    except Exception as e:
        logger.error(f"获取服务信息失败: {e}")
        raise HTTPException(status_code=500, detail=str(e))

