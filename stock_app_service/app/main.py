# -*- coding: utf-8 -*-
"""修复版本的FastAPI应用主文件"""

from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from fastapi.staticfiles import StaticFiles
import os
from contextlib import asynccontextmanager

from app.core.config import (
    APP_TITLE, APP_DESCRIPTION, APP_VERSION, 
    CHART_DIR, RESET_TABLES
)
from app.core.logging import logger

# 创建静态文件目录
os.makedirs(CHART_DIR, exist_ok=True)

@asynccontextmanager
async def lifespan(app: FastAPI):
    """应用生命周期管理 - 调度器在主循环启动"""
    logger.info("Stock Intelligence API 服务启动...")
    
    # 在主事件循环中启动调度器
    try:
        from app.services.news_scheduler import start_news_scheduler
        from app.services.stock_scheduler import start_stock_scheduler
        from app.tasks import scheduler
        
        start_news_scheduler()
        start_stock_scheduler() 
        scheduler.start()
        logger.info("调度器启动成功")
    except Exception as e:
        logger.error(f"调度器启动失败: {e}")
    
    # 其他初始化操作在后台执行
    def background_initialization():
        """后台初始化其他服务"""
        import time
        import threading
        
        try:
            # 等待API服务完全启动
            time.sleep(3)
            logger.info("后台初始化开始...")
            
            # Redis连接测试
            try:
                from app.db.redis_storage import redis_storage
                if redis_storage.test_connection():
                    logger.info("Redis连接成功")
                    if RESET_TABLES:
                        redis_storage.redis_client.flushdb()
                        logger.info("Redis数据已清理")
                else:
                    logger.warning("Redis连接失败")
            except Exception as e:
                logger.error(f"Redis初始化异常: {e}")
            
            # 数据初始化
            try:
                from app.core.config import STOCK_INIT_MODE
                if STOCK_INIT_MODE != "none":
                    logger.info(f"数据初始化模式: {STOCK_INIT_MODE}")
                    
                    def init_data():
                        from app.services.stock_scheduler import init_stock_system
                        init_stock_system(STOCK_INIT_MODE)
                    
                    # 数据初始化也在独立线程中执行
                    threading.Thread(target=init_data, daemon=True).start()
                    logger.info("数据初始化已启动")
            except Exception as e:
                logger.error(f"数据初始化异常: {e}")
            
            logger.info("后台初始化完成")
            
        except Exception as e:
            logger.error(f"后台初始化失败: {e}")
    
    # 启动后台初始化
    import threading
    threading.Thread(target=background_initialization, daemon=True).start()
    
    logger.info("API服务已启动 - 文档地址: /docs")
    
    yield
    
    # 关闭时的清理
    logger.info("应用关闭中...")
    try:
        from app.services.news_scheduler import stop_news_scheduler
        from app.services.stock_scheduler import stop_stock_scheduler
        from app.tasks import scheduler
        from app.core.redis_client import close_redis_client
        
        stop_news_scheduler()
        stop_stock_scheduler()
        scheduler.shutdown()
        await close_redis_client()
        logger.info("应用已安全关闭")
    except Exception as e:
        logger.error(f"关闭时异常: {e}")
    
# 创建应用实例
app = FastAPI(
    title=APP_TITLE,
    description=APP_DESCRIPTION,
    version=APP_VERSION,
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/docs-cn"
)

# 挂载静态文件
app.mount("/static", StaticFiles(directory="static"), name="static")

# 模板引擎
templates = Jinja2Templates(directory="templates")

# 导入所有API路由
from app.api import (
    system, public, news_analysis, stocks_redis, strategy, 
    signal_management, task_management, stock_scheduler_api,
    stock_data_management, stock_ai_analysis, chart
)

# 注册路由
app.include_router(system.router)
app.include_router(public.router)
app.include_router(news_analysis.router)
app.include_router(stocks_redis.router)
app.include_router(strategy.router)
app.include_router(signal_management.router)
app.include_router(task_management.router)
app.include_router(stock_scheduler_api.router)
app.include_router(stock_data_management.router)
app.include_router(stock_ai_analysis.router)
app.include_router(chart.router)

# 基础路由
@app.get("/ping")
async def ping():
    """健康检查端点"""
    return {"status": "pong", "message": "API服务运行正常"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
