# -*- coding: utf-8 -*-
"""
实时行情配置API
"""

from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel, Field
from typing import Optional, Literal

from app.core.logging import logger
from app.core.config import settings
from app.services.realtime import get_proxy_manager, get_stock_realtime_service_v2
from app.api.dependencies import verify_token

router = APIRouter()


class RealtimeConfigResponse(BaseModel):
    """实时行情配置响应"""
    default_provider: str = Field(..., description="默认数据提供商")
    auto_switch: bool = Field(..., description="是否启用自动切换")
    update_interval: int = Field(..., description="更新周期（分钟）")
    available_providers: list = Field(..., description="可用的数据提供商")


class RealtimeConfigUpdate(BaseModel):
    """实时行情配置更新"""
    default_provider: Optional[Literal["eastmoney", "sina", "auto"]] = Field(None, description="默认数据提供商")
    auto_switch: Optional[bool] = Field(None, description="是否启用自动切换")


class RealtimeStatsResponse(BaseModel):
    """实时行情统计响应"""
    total_requests: int
    eastmoney: dict
    sina: dict
    last_provider: Optional[str]
    last_update: Optional[str]
    config: dict


@router.get("/realtime/config", response_model=RealtimeConfigResponse, summary="获取实时行情配置")
async def get_realtime_config(token: str = Depends(verify_token)):
    """
    获取当前的实时行情配置
    
    返回：
    - default_provider: 默认数据提供商（eastmoney, sina, auto）
    - auto_switch: 是否启用自动切换
    - update_interval: 更新周期（分钟）
    - available_providers: 可用的数据提供商列表
    """
    try:
        proxy_manager = get_proxy_manager()
        service = get_stock_realtime_service_v2(proxy_manager=proxy_manager)
        
        return RealtimeConfigResponse(
            default_provider=service.default_provider,
            auto_switch=service.auto_switch,
            update_interval=settings.REALTIME_UPDATE_INTERVAL,
            available_providers=["eastmoney", "sina", "auto"]
        )
    except Exception as e:
        logger.error(f"获取实时行情配置失败: {str(e)}")
        raise HTTPException(status_code=500, detail=f"获取配置失败: {str(e)}")


@router.put("/realtime/config", summary="更新实时行情配置")
async def update_realtime_config(
    config: RealtimeConfigUpdate,
    token: str = Depends(verify_token)
):
    """
    更新实时行情配置
    
    参数：
    - default_provider: 默认数据提供商（eastmoney, sina, auto）
    - auto_switch: 是否启用自动切换
    
    注意：此配置仅在当前运行时生效，重启后会恢复为环境变量配置
    """
    try:
        proxy_manager = get_proxy_manager()
        service = get_stock_realtime_service_v2(proxy_manager=proxy_manager)
        
        # 更新配置
        if config.default_provider is not None:
            service.default_provider = config.default_provider
            logger.info(f"实时行情默认提供商已更新为: {config.default_provider}")
        
        if config.auto_switch is not None:
            service.auto_switch = config.auto_switch
            logger.info(f"实时行情自动切换已{'启用' if config.auto_switch else '禁用'}")
        
        return {
            "code": 200,
            "message": "配置更新成功",
            "data": {
                "default_provider": service.default_provider,
                "auto_switch": service.auto_switch,
                "update_interval": settings.REALTIME_UPDATE_INTERVAL
            }
        }
    except Exception as e:
        logger.error(f"更新实时行情配置失败: {str(e)}")
        raise HTTPException(status_code=500, detail=f"更新配置失败: {str(e)}")


@router.get("/realtime/stats", response_model=RealtimeStatsResponse, summary="获取实时行情统计信息")
async def get_realtime_stats(token: str = Depends(verify_token)):
    """
    获取实时行情服务的统计信息
    
    返回：
    - total_requests: 总请求次数
    - eastmoney: 东方财富数据源统计
    - sina: 新浪数据源统计
    - last_provider: 上次使用的数据源
    - last_update: 上次更新时间
    - config: 当前配置
    """
    try:
        proxy_manager = get_proxy_manager()
        service = get_stock_realtime_service_v2(proxy_manager=proxy_manager)
        stats = service.get_stats()
        
        return RealtimeStatsResponse(**stats)
    except Exception as e:
        logger.error(f"获取实时行情统计信息失败: {str(e)}")
        raise HTTPException(status_code=500, detail=f"获取统计信息失败: {str(e)}")


@router.post("/realtime/stats/reset", summary="重置实时行情统计信息")
async def reset_realtime_stats(token: str = Depends(verify_token)):
    """
    重置实时行情服务的统计信息
    """
    try:
        proxy_manager = get_proxy_manager()
        service = get_stock_realtime_service_v2(proxy_manager=proxy_manager)
        service.reset_stats()
        
        return {
            "code": 200,
            "message": "统计信息已重置",
            "data": service.get_stats()
        }
    except Exception as e:
        logger.error(f"重置实时行情统计信息失败: {str(e)}")
        raise HTTPException(status_code=500, detail=f"重置统计信息失败: {str(e)}")


@router.get("/realtime/test/{provider}", summary="测试指定数据源")
async def test_realtime_provider(
    provider: Literal["eastmoney", "sina"],
    token: str = Depends(verify_token)
):
    """
    测试指定的数据源是否可用
    
    参数：
    - provider: 数据提供商（eastmoney 或 sina）
    
    返回测试结果和获取的数据量
    """
    try:
        proxy_manager = get_proxy_manager()
        service = get_stock_realtime_service_v2(proxy_manager=proxy_manager)
        
        logger.info(f"开始测试数据源: {provider}")
        result = service.get_all_stocks_realtime(provider=provider)
        
        if result.get('success'):
            return {
                "code": 200,
                "message": f"数据源 {provider} 测试成功",
                "data": {
                    "provider": provider,
                    "success": True,
                    "count": result.get('count', 0),
                    "source": result.get('source'),
                    "update_time": result.get('update_time')
                }
            }
        else:
            return {
                "code": 500,
                "message": f"数据源 {provider} 测试失败",
                "data": {
                    "provider": provider,
                    "success": False,
                    "error": result.get('error', '未知错误')
                }
            }
    except Exception as e:
        logger.error(f"测试数据源 {provider} 失败: {str(e)}")
        raise HTTPException(status_code=500, detail=f"测试失败: {str(e)}")


