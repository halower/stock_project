# -*- coding: utf-8 -*-
"""
股票数据任务
实现股票数据相关的异步任务
"""
import asyncio
import threading
import logging
from datetime import datetime
from typing import Dict, Any, Optional, List

from app.services.stock.stock_data_manager import stock_data_manager, create_stock_data_manager
from app.services.signal.signal_manager import signal_manager
from app.db.session import RedisCache

logger = logging.getLogger(__name__)

# 任务状态存储
_tasks = {}
redis_cache = RedisCache()

class TaskResult:
    """任务结果"""
    def __init__(self, task_id: str, task_type: str):
        self.id = task_id
        self.type = task_type
        self.status = "pending"  # pending, running, completed, failed
        self.start_time = None
        self.end_time = None
        self.result = None
        self.error = None
        self.progress = 0
        self.total = 0
        
    def to_dict(self) -> Dict[str, Any]:
        """转换为字典"""
        return {
            "id": self.id,
            "type": self.type,
            "status": self.status,
            "start_time": self.start_time.isoformat() if self.start_time else None,
            "end_time": self.end_time.isoformat() if self.end_time else None,
            "result": self.result,
            "error": self.error,
            "progress": self.progress,
            "total": self.total,
            "progress_percentage": round(self.progress / self.total * 100, 2) if self.total > 0 else 0,
            "elapsed_seconds": (self.end_time - self.start_time).total_seconds() if self.end_time and self.start_time else None
        }

class Task:
    """异步任务基类"""
    def __init__(self, task_id: str, task_type: str):
        self.id = task_id
        self.type = task_type
        self.result = TaskResult(task_id, task_type)
        
    def delay(self) -> TaskResult:
        """异步执行任务"""
        self.result.status = "pending"
        self.result.start_time = datetime.now()
        
        # 存储任务
        _tasks[self.id] = self.result
        
        # 在新线程中执行
        thread = threading.Thread(target=self._run_in_thread, daemon=True)
        thread.start()
        
        return self.result
    
    def _run_in_thread(self):
        """在后台线程中运行异步任务，避免阻塞主应用"""
        try:
            self.result.status = "running"
            
            # 在后台线程中创建独立的事件循环
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            
            try:
                # 执行异步任务
                loop.run_until_complete(self._execute())
                self.result.status = "completed"
                self.result.end_time = datetime.now()
                logger.info(f"后台任务 {self.id} 执行成功")
            finally:
                loop.close()
                
        except Exception as e:
            logger.error(f"后台任务 {self.id} 执行失败: {e}")
            self.result.status = "failed"
            self.result.error = str(e)
            self.result.end_time = datetime.now()
    
    async def _execute(self):
        """执行任务（子类实现）"""
        raise NotImplementedError("子类必须实现此方法")

class StockDataStartupCheckTask(Task):
    """股票数据启动检查任务"""
    def __init__(self):
        super().__init__(f"startup_check_{datetime.now().strftime('%Y%m%d%H%M%S')}", "startup_check")
        
    async def _execute(self):
        """执行任务"""
        # 创建独立的实例，避免共享状态
        sdm = create_stock_data_manager()
        await sdm.initialize()
        
        try:
            # 执行启动检查
            self.result.result = await sdm.startup_check()
        finally:
            # 关闭连接
            await sdm.close()

class StockListMaintenanceTask(Task):
    """股票清单维护任务"""
    def __init__(self):
        super().__init__(f"stock_list_{datetime.now().strftime('%Y%m%d%H%M%S')}", "stock_list")
        
    async def _execute(self):
        """执行任务"""
        # 创建独立的实例，避免共享状态
        sdm = create_stock_data_manager()
        await sdm.initialize()
        
        try:
            # 初始化股票清单
            success = await sdm.initialize_stock_list()
            self.result.result = {
                "success": success,
                "count": await sdm.get_stock_list_count() if success else 0
            }
        finally:
            # 关闭连接
            await sdm.close()

class DailyStockTrendUpdateTask(Task):
    """每日股票走势数据更新任务"""
    def __init__(self):
        super().__init__(f"daily_update_{datetime.now().strftime('%Y%m%d%H%M%S')}", "daily_update")
        
    async def _execute(self):
        """执行任务"""
        # 创建独立的实例，避免共享状态
        sdm = create_stock_data_manager()
        await sdm.initialize()
        
        try:
            # 智能更新股票走势数据
            success_count, failed_count = await sdm.smart_update_trend_data()
            self.result.result = {
                "success_count": success_count,
                "failed_count": failed_count,
                "total_count": success_count + failed_count
            }
        finally:
            # 关闭连接
            await sdm.close()

class WeeklyForceStockTrendUpdateTask(Task):
    """每周强制更新所有股票走势数据任务"""
    def __init__(self):
        super().__init__(f"weekly_update_{datetime.now().strftime('%Y%m%d%H%M%S')}", "weekly_update")
        
    async def _execute(self):
        """执行任务"""
        # 创建独立的实例，避免共享状态
        sdm = create_stock_data_manager()
        await sdm.initialize()
        
        try:
            # 初始化所有股票走势数据
            success = await sdm.initialize_all_stock_trend_data()
            self.result.result = {
                "success": success,
                "count": await sdm.get_stock_trend_data_count() if success else 0
            }
        finally:
            # 关闭连接
            await sdm.close()

class CalculateSignalsTask(Task):
    """计算买入信号任务"""
    def __init__(self, force_recalculate: bool = True):
        super().__init__(f"signals_{datetime.now().strftime('%Y%m%d%H%M%S')}", "signals")
        self.force_recalculate = force_recalculate
        
    async def _execute(self):
        """执行任务"""
        # 初始化信号管理器
        await signal_manager.initialize()
        
        try:
            # 计算买入信号
            result = await signal_manager.calculate_buy_signals(force_recalculate=self.force_recalculate)
            self.result.result = result
        finally:
            # 关闭连接
            await signal_manager.close()

# 创建任务实例
stock_data_startup_check = StockDataStartupCheckTask()
stock_list_maintenance = StockListMaintenanceTask()
daily_stock_trend_update = DailyStockTrendUpdateTask()
weekly_force_stock_trend_update = WeeklyForceStockTrendUpdateTask()
calculate_signals = CalculateSignalsTask()

def get_task_status(task_id: str) -> Optional[Dict[str, Any]]:
    """获取任务状态"""
    if task_id in _tasks:
        return _tasks[task_id].to_dict()
    return None

def get_all_tasks() -> List[Dict[str, Any]]:
    """获取所有任务"""
    return [task.to_dict() for task in _tasks.values()]

def clear_completed_tasks():
    """清理已完成的任务"""
    global _tasks
    _tasks = {k: v for k, v in _tasks.items() if v.status not in ["completed", "failed"]}
