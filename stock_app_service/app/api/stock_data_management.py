# -*- coding: utf-8 -*-
"""
股票数据管理API
提供股票清单和股票走势数据的管理接口
"""
from fastapi import APIRouter, HTTPException, BackgroundTasks
from pydantic import BaseModel
from typing import Dict, Any, List, Optional
import logging
from datetime import datetime

from app.services.stock.stock_data_manager import stock_data_manager
# 导入任务将在需要时进行，避免循环导入问题

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/stock-data", tags=["股票数据管理"])

# ===================== 响应模型 =====================

class StockDataStatusResponse(BaseModel):
    """股票数据状态响应"""
    stock_list_count: int
    stock_list_sufficient: bool
    trend_data_count: int
    trend_data_sufficient: bool
    last_check_time: str

class StockDataOperationResponse(BaseModel):
    """股票数据操作响应"""
    success: bool
    message: str
    data: Optional[Dict[str, Any]] = None

class StockListResponse(BaseModel):
    """股票清单响应"""
    ts_code: str
    symbol: str
    name: str
    area: Optional[str] = ""
    industry: Optional[str] = ""
    market: Optional[str] = ""
    list_date: Optional[str] = ""
    updated_at: str

class StockTrendDataResponse(BaseModel):
    """股票走势数据响应"""
    ts_code: str
    data_count: int
    updated_at: str
    latest_date: Optional[str] = None

# ===================== 股票清单管理接口 =====================

@router.get("/stock-list/status", 
           summary="获取股票清单状态",
           description="获取当前股票清单的数量和状态信息",
           response_model=StockDataOperationResponse)
async def get_stock_list_status():
    """获取股票清单状态"""
    try:
        await stock_data_manager.initialize()
        
        is_sufficient, count = await stock_data_manager.check_stock_list_status()
        
        result = {
            "count": count,
            "sufficient": is_sufficient,
            "threshold": 5000,
            "check_time": datetime.now().isoformat()
        }
        
        await stock_data_manager.close()
        
        return StockDataOperationResponse(
            success=True,
            message=f"股票清单状态: {count}只股票, {'充足' if is_sufficient else '不足'}",
            data=result
        )
        
    except Exception as e:
        logger.error(f"获取股票清单状态失败: {e}")
        raise HTTPException(status_code=500, detail=f"获取股票清单状态失败: {str(e)}")


@router.post("/stock-list/initialize",
            summary="初始化股票清单", 
            description="手动触发股票清单初始化，获取所有A股股票的基本信息",
            response_model=StockDataOperationResponse)
async def initialize_stock_list(background_tasks: BackgroundTasks):
    """初始化股票清单"""
    try:
        # 使用后台任务异步执行
        from app.tasks.stock_data_tasks import stock_list_maintenance
        task_result = stock_list_maintenance.delay()
        
        return StockDataOperationResponse(
            success=True,
            message="股票清单初始化任务已启动",
            data={"task_id": task_result.id}
        )
        
    except Exception as e:
        logger.error(f"启动股票清单初始化失败: {e}")
        raise HTTPException(status_code=500, detail=f"启动股票清单初始化失败: {str(e)}")


@router.get("/stock-list/search",
           summary="搜索股票",
           description="根据股票代码或名称搜索股票信息",
           response_model=StockDataOperationResponse)
async def search_stocks(query: str, limit: int = 10):
    """搜索股票"""
    try:
        await stock_data_manager.initialize()
        
        # 从Redis获取股票列表
        stocks = await stock_data_manager._get_all_stocks()
        
        # 搜索匹配的股票
        matched_stocks = []
        query_lower = query.lower()
        
        for stock in stocks:
            if (query_lower in stock['ts_code'].lower() or 
                query_lower in stock['symbol'].lower() or 
                query_lower in stock['name'].lower()):
                matched_stocks.append(stock)
                
                if len(matched_stocks) >= limit:
                    break
        
        await stock_data_manager.close()
        
        return StockDataOperationResponse(
            success=True,
            message=f"找到 {len(matched_stocks)} 只匹配的股票",
            data={
                "stocks": matched_stocks,
                "total": len(matched_stocks),
                "query": query
            }
        )
        
    except Exception as e:
        logger.error(f"搜索股票失败: {e}")
        raise HTTPException(status_code=500, detail=f"搜索股票失败: {str(e)}")

# ===================== 股票走势数据管理接口 =====================

@router.get("/trend-data/status",
           summary="获取股票走势数据状态", 
           description="获取当前有走势数据的股票数量和状态信息",
           response_model=StockDataOperationResponse)
async def get_trend_data_status():
    """获取股票走势数据状态"""
    try:
        await stock_data_manager.initialize()
        
        is_sufficient, count = await stock_data_manager.check_stock_trend_data_status()
        
        result = {
            "count": count,
            "sufficient": is_sufficient,
            "threshold": 5000,
            "check_time": datetime.now().isoformat()
        }
        
        await stock_data_manager.close()
        
        return StockDataOperationResponse(
            success=True,
            message=f"股票走势数据状态: {count}只股票有数据, {'充足' if is_sufficient else '不足'}",
            data=result
        )
        
    except Exception as e:
        logger.error(f"获取股票走势数据状态失败: {e}")
        raise HTTPException(status_code=500, detail=f"获取股票走势数据状态失败: {str(e)}")


@router.post("/trend-data/initialize",
            summary="初始化所有股票走势数据",
            description="手动触发所有股票走势数据初始化，获取90个交易日的历史数据",
            response_model=StockDataOperationResponse)
async def initialize_all_trend_data(background_tasks: BackgroundTasks):
    """初始化所有股票走势数据"""
    try:
        # 使用后台任务异步执行
        from app.tasks.stock_data_tasks import weekly_force_stock_trend_update
        task_result = weekly_force_stock_trend_update.delay()
        
        return StockDataOperationResponse(
            success=True,
            message="所有股票走势数据初始化任务已启动",
            data={"task_id": task_result.id}
        )
        
    except Exception as e:
        logger.error(f"启动股票走势数据初始化失败: {e}")
        raise HTTPException(status_code=500, detail=f"启动股票走势数据初始化失败: {str(e)}")


@router.post("/trend-data/smart-update",
            summary="智能更新股票走势数据", 
            description="根据更新时间智能判断哪些股票需要更新走势数据",
            response_model=StockDataOperationResponse)
async def smart_update_trend_data(background_tasks: BackgroundTasks):
    """智能更新股票走势数据"""
    try:
        # 使用后台任务异步执行
        from app.tasks.stock_data_tasks import daily_stock_trend_update
        task_result = daily_stock_trend_update.delay()
        
        return StockDataOperationResponse(
            success=True,
            message="智能更新股票走势数据任务已启动",
            data={"task_id": task_result.id}
        )
        
    except Exception as e:
        logger.error(f"启动智能更新失败: {e}")
        raise HTTPException(status_code=500, detail=f"启动智能更新失败: {str(e)}")


@router.get("/trend-data/{ts_code}",
           summary="获取单只股票走势数据",
           description="获取指定股票的走势数据",
           response_model=StockDataOperationResponse)
async def get_stock_trend_data(ts_code: str):
    """获取单只股票走势数据"""
    try:
        await stock_data_manager.initialize()
        
        key = f"stock_trend:{ts_code}"
        data = await stock_data_manager.redis_client.get(key)
        
        await stock_data_manager.close()
        
        if not data:
            raise HTTPException(status_code=404, detail=f"股票 {ts_code} 的走势数据不存在")
        
        import json
        trend_data = json.loads(data)
        
        return StockDataOperationResponse(
            success=True,
            message=f"成功获取股票 {ts_code} 的走势数据",
            data=trend_data
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取股票走势数据失败: {e}")
        raise HTTPException(status_code=500, detail=f"获取股票走势数据失败: {str(e)}")


@router.post("/trend-data/{ts_code}/update",
            summary="更新单只股票走势数据",
            description="手动更新指定股票的走势数据",
            response_model=StockDataOperationResponse)
async def update_single_stock_trend_data(ts_code: str, days: int = 180):
    """更新单只股票走势数据"""
    try:
        await stock_data_manager.initialize()
        
        success = await stock_data_manager.update_stock_trend_data(ts_code, days)
        
        await stock_data_manager.close()
        
        if success:
            return StockDataOperationResponse(
                success=True,
                message=f"成功更新股票 {ts_code} 的走势数据",
                data={
                    "ts_code": ts_code,
                    "days": days,
                    "updated_at": datetime.now().isoformat()
                }
            )
        else:
            raise HTTPException(status_code=500, detail=f"更新股票 {ts_code} 走势数据失败")
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"更新股票走势数据失败: {e}")
        raise HTTPException(status_code=500, detail=f"更新股票走势数据失败: {str(e)}")

# ===================== 系统管理接口 =====================

@router.get("/system/status",
           summary="获取系统整体状态",
           description="获取股票数据管理系统的整体状态信息",
           response_model=StockDataOperationResponse)
async def get_system_status():
    """获取系统整体状态"""
    try:
        await stock_data_manager.initialize()
        
        # 获取股票清单状态
        list_sufficient, list_count = await stock_data_manager.check_stock_list_status()
        
        # 获取走势数据状态
        trend_sufficient, trend_count = await stock_data_manager.check_stock_trend_data_status()
        
        # 检查是否为强制更新日
        is_force_update_day = await stock_data_manager.is_force_update_day()
        
        result = {
            "stock_list": {
                "count": list_count,
                "sufficient": list_sufficient,
                "threshold": 5000
            },
            "trend_data": {
                "count": trend_count,
                "sufficient": trend_sufficient,
                "threshold": 5000
            },
            "system": {
                "is_force_update_day": is_force_update_day,
                "current_time": datetime.now().isoformat(),
                "status": "healthy" if (list_sufficient and trend_sufficient) else "needs_attention"
            }
        }
        
        await stock_data_manager.close()
        
        return StockDataOperationResponse(
            success=True,
            message="系统状态获取成功",
            data=result
        )
        
    except Exception as e:
        logger.error(f"获取系统状态失败: {e}")
        raise HTTPException(status_code=500, detail=f"获取系统状态失败: {str(e)}")


@router.post("/system/startup-check",
            summary="执行启动检查",
            description="手动触发系统启动检查，检查股票清单和走势数据状态",
            response_model=StockDataOperationResponse)
async def manual_startup_check(background_tasks: BackgroundTasks):
    """手动执行启动检查"""
    try:
        # 使用后台任务异步执行
        from app.tasks.stock_data_tasks import stock_data_startup_check
        task_result = stock_data_startup_check.delay()
        
        return StockDataOperationResponse(
            success=True,
            message="启动检查任务已启动",
            data={"task_id": task_result.id}
        )
        
    except Exception as e:
        logger.error(f"启动检查失败: {e}")
        raise HTTPException(status_code=500, detail=f"启动检查失败: {str(e)}")


@router.get("/system/health",
           summary="健康检查",
           description="简单的健康检查接口",
           response_model=StockDataOperationResponse)
async def health_check():
    """健康检查"""
    try:
        await stock_data_manager.initialize()
        
        # 简单的Redis连接测试
        await stock_data_manager.redis_client.ping()
        
        await stock_data_manager.close()
        
        return StockDataOperationResponse(
            success=True,
            message="系统运行正常",
            data={
                "status": "healthy",
                "timestamp": datetime.now().isoformat()
            }
        )
        
    except Exception as e:
        logger.error(f"健康检查失败: {e}")
        raise HTTPException(status_code=503, detail=f"系统不健康: {str(e)}") 