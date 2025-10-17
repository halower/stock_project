# -*- coding: utf-8 -*-
"""系统状态和基本功能API"""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import Dict, Any

from app.db.session import get_db
from app.models.stock import StockInfo, StockHistory
from app.core.logging import logger
from app.api.dependencies import verify_token

router = APIRouter(tags=["系统"])

@router.get("/", summary="系统状态")
async def read_root() -> Dict[str, str]:
    """返回系统状态信息"""
    return {"message": "股票信息API服务已启动", "status": "running"}

@router.get("/api/stocks/status", dependencies=[Depends(verify_token)], summary="数据状态统计")
async def get_data_status(db: Session = Depends(get_db)) -> Dict[str, Any]:
    """
    获取数据状态统计信息
    
    返回系统中的数据统计信息,包括股票总数、有历史数据的股票数、
    最近更新时间、今日更新的股票数等。
    """
    try:
        # 获取股票总数
        total_stocks = db.query(StockInfo).count()
        
        # 计算有历史数据的股票数
        stocks_with_history = db.query(StockHistory.stock_code).distinct().count()
        
        # 获取最近更新时间
        latest_update = db.query(StockHistory.updated_at).order_by(StockHistory.updated_at.desc()).first()
        latest_update_time = latest_update[0] if latest_update else None
        
        # 获取今日更新的股票数
        from datetime import datetime
        today = datetime.now().date()
        today_updated = db.query(StockHistory.stock_code).filter(
            StockHistory.trade_date == today
        ).distinct().count()
        
        # 获取任务状态（简化版本）
        def get_history_init_status():
            return {"status": "idle"}
        
        def get_background_task_status():
            return {"running": False}
        
        def get_daily_sync_status():
            return {"running": False, "last_sync": None}
        
        return {
            "total_stocks": total_stocks,
            "stocks_with_history": stocks_with_history,
            "latest_update_time": latest_update_time,
            "today_updated_stocks": today_updated,
            "history_init_running": get_history_init_status()["status"] == "running",
            "realtime_update_running": get_background_task_status()["running"],
            "daily_sync_running": get_daily_sync_status()["running"],
            "daily_sync_last_time": get_daily_sync_status().get("last_sync")
        }
    except Exception as e:
        logger.error(f"获取数据状态失败: {str(e)}")
        raise HTTPException(status_code=500, detail=f"获取数据状态失败: {str(e)}")