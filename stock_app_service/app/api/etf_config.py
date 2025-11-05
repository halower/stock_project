# -*- coding: utf-8 -*-
"""
ETF配置管理API
"""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional, Dict, Any

from app.core.logging import logger
from app.services.realtime import get_proxy_manager, get_etf_realtime_service_v2
from app.services.scheduler.stock_scheduler import trigger_stock_task

router = APIRouter()


class ETFConfigUpdate(BaseModel):
    """ETF配置更新模型"""
    default_provider: Optional[str] = None  # eastmoney, sina, auto
    auto_switch: Optional[bool] = None
    retry_times: Optional[int] = None
    min_request_interval: Optional[float] = None


@router.get("/etf/config")
async def get_etf_config():
    """
    获取ETF实时行情配置
    
    Returns:
        当前ETF配置信息
    """
    try:
        proxy_manager = get_proxy_manager()
        service = get_etf_realtime_service_v2(proxy_manager=proxy_manager)
        config = service.get_config()
        
        return {
            'success': True,
            'data': config,
            'message': '获取ETF配置成功'
        }
    except Exception as e:
        logger.error(f"获取ETF配置失败: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.put("/etf/config")
async def update_etf_config(config_update: ETFConfigUpdate):
    """
    更新ETF实时行情配置
    
    Args:
        config_update: 配置更新参数
        
    Returns:
        更新后的配置信息
    """
    try:
        proxy_manager = get_proxy_manager()
        service = get_etf_realtime_service_v2(proxy_manager=proxy_manager)
        
        # 更新配置
        updated_config = service.update_config(
            default_provider=config_update.default_provider,
            auto_switch=config_update.auto_switch,
            retry_times=config_update.retry_times,
            min_request_interval=config_update.min_request_interval
        )
        
        return {
            'success': True,
            'data': updated_config,
            'message': 'ETF配置更新成功'
        }
    except Exception as e:
        logger.error(f"更新ETF配置失败: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/etf/stats")
async def get_etf_stats():
    """
    获取ETF实时行情服务统计信息
    
    Returns:
        统计信息（成功次数、失败次数、自动切换次数等）
    """
    try:
        proxy_manager = get_proxy_manager()
        service = get_etf_realtime_service_v2(proxy_manager=proxy_manager)
        stats = service.get_stats()
        
        return {
            'success': True,
            'data': stats,
            'message': '获取ETF统计信息成功'
        }
    except Exception as e:
        logger.error(f"获取ETF统计信息失败: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/etf/stats/reset")
async def reset_etf_stats():
    """
    重置ETF实时行情服务统计信息
    
    Returns:
        重置结果
    """
    try:
        proxy_manager = get_proxy_manager()
        service = get_etf_realtime_service_v2(proxy_manager=proxy_manager)
        service.reset_stats()
        
        return {
            'success': True,
            'message': 'ETF统计信息已重置'
        }
    except Exception as e:
        logger.error(f"重置ETF统计信息失败: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/etf/test/{provider}")
async def test_etf_provider(provider: str):
    """
    测试指定的ETF数据源
    
    Args:
        provider: 数据源名称 (eastmoney/sina)
        
    Returns:
        测试结果（包含获取到的ETF数量、耗时等）
    """
    import time
    
    try:
        if provider not in ['eastmoney', 'sina']:
            raise HTTPException(status_code=400, detail=f"不支持的数据源: {provider}")
        
        proxy_manager = get_proxy_manager()
        service = get_etf_realtime_service_v2(proxy_manager=proxy_manager)
        
        start_time = time.time()
        result = service.get_all_etfs_realtime(provider=provider)
        elapsed_time = time.time() - start_time
        
        if result.get('success'):
            return {
                'success': True,
                'data': {
                    'provider': provider,
                    'count': result.get('count', 0),
                    'elapsed_time': round(elapsed_time, 2),
                    'sample_data': result.get('data', [])[:3] if result.get('data') else []  # 返回前3条作为示例
                },
                'message': f'测试 {provider} 数据源成功'
            }
        else:
            return {
                'success': False,
                'error': result.get('error'),
                'message': f'测试 {provider} 数据源失败'
            }
            
    except Exception as e:
        logger.error(f"测试ETF数据源失败: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/etf/init")
async def init_etf_data():
    """
    初始化ETF历史K线数据
    
    Returns:
        任务触发结果
    """
    try:
        result = trigger_stock_task('init_etf')
        return result
    except Exception as e:
        logger.error(f"触发ETF初始化任务失败: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/etf/update")
async def update_etf_realtime():
    """
    手动触发ETF实时数据更新
    
    Returns:
        任务触发结果
    """
    try:
        result = trigger_stock_task('update_etf')
        return result
    except Exception as e:
        logger.error(f"触发ETF更新任务失败: {e}")
        raise HTTPException(status_code=500, detail=str(e))

