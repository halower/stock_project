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
    
    # 在主事件循环中启动任务调度器（图表清理等）
    try:
        from app.tasks import scheduler
        scheduler.start()
        logger.info("任务调度器启动成功")
    except Exception as e:
        logger.error(f"任务调度器启动失败: {e}")
    
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
                    # ⚠️ 修复：RESET_TABLES应该只在真正需要重置时使用，而不是每次启动都检查
                    # 而且应该考虑init_mode，skip模式下绝不清空数据
                    if RESET_TABLES:
                        # 从环境变量读取init_mode，默认skip
                        init_mode = os.getenv("SCHEDULER_INIT_MODE", "skip").lower()
                        if init_mode == "skip":
                            logger.warning("⚠️ RESET_TABLES=true但init_mode=skip，为保护现有数据，跳过Redis清理")
                            logger.info("如需清理Redis，请同时设置 SCHEDULER_INIT_MODE=init")
                        else:
                            logger.warning("🔥 警告：即将清空Redis所有数据！")
                            logger.warning("🔥 这将删除所有股票数据、信号、缓存等")
                            redis_storage.redis_client.flushdb()
                            logger.info("Redis数据已清理（RESET_TABLES=true且init_mode!=skip）")
                else:
                    logger.warning("Redis连接失败")
            except Exception as e:
                logger.error(f"Redis初始化异常: {e}")
            
            # 启动新闻调度器
            try:
                from app.services.scheduler import start_news_scheduler
                start_news_scheduler()
                logger.info("新闻调度器启动成功")
            except Exception as e:
                logger.error(f"新闻调度器启动异常: {e}")
            
            # 启动股票调度器（新版本）
            try:
                def start_scheduler():
                    import os
                    from app.services.scheduler.stock_scheduler import start_stock_scheduler
                    
                    # 从环境变量读取配置，默认值：skip模式，不计算信号
                    init_mode = os.getenv("SCHEDULER_INIT_MODE", "skip").lower()
                    calculate_signals = os.getenv("SCHEDULER_CALCULATE_SIGNALS", "false").lower() in ("true", "1", "yes")
                    
                    logger.info(f"股票调度器配置: init_mode={init_mode}, calculate_signals={calculate_signals}")
                    start_stock_scheduler(init_mode=init_mode, calculate_signals=calculate_signals)
                
                # 在独立线程中启动调度器
                threading.Thread(target=start_scheduler, daemon=True).start()
                logger.info("股票调度器启动中...")
            except Exception as e:
                logger.error(f"股票调度器启动异常: {e}")
            
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
        from app.services.scheduler import stop_news_scheduler, stop_stock_scheduler
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

# ✅ 添加gzip压缩中间件（提升网络传输性能）
from fastapi.middleware.gzip import GZipMiddleware
app.add_middleware(GZipMiddleware, minimum_size=1000)  # 大于1KB的响应才压缩
logger.info("✅ GZip压缩中间件已启用（minimum_size=1KB）")

# 挂载静态文件
app.mount("/static", StaticFiles(directory="static"), name="static")

# 模板引擎
templates = Jinja2Templates(directory="templates")

# 导入所有API路由
from app.api import (
    system, public, news_analysis, stocks_redis, strategy, 
    signal_management, task_management,
    stock_data_management, stock_ai_analysis, chart, chart_data, market_types,
    realtime_config, data_validation, websocket, index_analysis,
    limit_board, sector_analysis, valuation
)

# 注册路由
app.include_router(system.router)
app.include_router(public.router)
app.include_router(news_analysis.router)
app.include_router(stocks_redis.router)
app.include_router(strategy.router)
app.include_router(signal_management.router)
app.include_router(task_management.router)
app.include_router(stock_data_management.router)
app.include_router(stock_ai_analysis.router)
app.include_router(chart.router)
app.include_router(chart_data.router)  # 新的数据API（推荐）
app.include_router(market_types.router)
app.include_router(realtime_config.router, prefix="/api", tags=["实时行情配置"])
app.include_router(data_validation.router, tags=["数据验证"])
app.include_router(websocket.router, tags=["WebSocket"])
app.include_router(index_analysis.router, tags=["指数分析"])
app.include_router(limit_board.router, prefix="/api", tags=["打板分析"])
app.include_router(sector_analysis.router, prefix="/api", tags=["板块分析"])
app.include_router(valuation.router, prefix="/api", tags=["估值分析"])

# 基础路由
@app.get("/ping")
async def ping():
    """健康检查端点"""
    return {"status": "pong", "message": "API服务运行正常"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
