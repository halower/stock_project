# -*- coding: utf-8 -*-
"""新闻消息面分析API路由 - 基于简化的APScheduler调度器"""

from fastapi import APIRouter, Depends, HTTPException, status
from typing import Dict, Any, Optional
from datetime import datetime
from pydantic import BaseModel, Field

from app.core.logging import logger
from app.core.config import AI_ENABLED
from app.db.session import RedisCache
from app.services.news_analysis_service import get_news_sentiment_analysis
from app.schemas.news_schema import NewsAnalysisResponse, NewsAnalysisData
from app.api.dependencies import verify_token
from app.services.news_scheduler import get_scheduler_status, trigger_immediate_crawl, NEWS_KEYS

# Redis缓存客户端
redis_cache = RedisCache()

# 定义请求模型
class AnalysisRequest(BaseModel):
    force_refresh: bool = False
    ai_model_name: str
    ai_endpoint: str
    ai_api_key: str

# 定义新闻列表响应模型
class NewsListResponse(BaseModel):
    success: bool = Field(..., description="是否成功")
    message: str = Field(..., description="消息")
    data: Optional[Dict[str, Any]] = Field(None, description="数据")

# 定义任务状态响应模型
class TaskStatusResponse(BaseModel):
    success: bool = Field(..., description="是否成功")
    message: str = Field(..., description="消息")
    data: Optional[Dict[str, Any]] = Field(None, description="任务状态数据")

router = APIRouter(tags=["新闻资讯"])

@router.get(
    "/api/news/latest", 
    dependencies=[Depends(verify_token)], 
    response_model=NewsListResponse,
    summary="获取最新财经新闻",
    description="""
    从Redis缓存中获取最新的财经新闻列表。
    
    ✨ 新特性（简化版）：
    - 使用APScheduler轻量级调度器
    - 启动时立即执行一次爬取
    - 每2小时自动更新，无需手动干预
    - 旧缓存自动失效，无需清理接口
    - 可查看详细执行日志
    
    数据包含：
    - 新闻标题、链接、发布时间
    - 新闻来源和内容摘要
    - 缓存更新时间和数据统计
    """,
    response_description="返回最新财经新闻列表，包含新闻数量和详细信息"
)
async def get_latest_news():
    """
    从Redis缓存获取最新财经新闻
    
    优势：
    1. 轻量级：使用APScheduler替代Celery，减少复杂性
    2. 即时性：启动时立即执行一次爬取
    3. 自动化：每2小时自动更新，旧缓存自动失效
    4. 可观测：提供详细的执行日志和状态监控
    
    Returns:
        NewsListResponse: 包含新闻列表和统计信息的响应对象
    """
    try:
        # 从Redis缓存获取新闻数据
        cached_news = redis_cache.get_cache(NEWS_KEYS['news_latest'])
        
        if not cached_news:
            logger.warning("Redis中没有找到新闻缓存数据")
            
            # 如果没有缓存数据，返回提示信息
            return NewsListResponse(
                success=True,
                message="新闻数据正在更新中，请稍后再试",
                data={
                    "news": [],
                    "count": 0,
                    "status": "no_cache",
                    "message": "调度器正在爬取最新数据，首次启动可能需要等待1-2分钟",
                    "suggestion": "请稍后重新请求，或查看调度器状态"
                }
            )
        
        # 检查数据完整性
        news_list = cached_news.get('news', [])
        if not news_list:
            logger.warning("缓存中的新闻列表为空")
            return NewsListResponse(
                success=True,
                message="暂无新闻数据",
                data={
                    "news": [],
                    "count": 0,
                    "status": "empty_cache",
                    "last_update": cached_news.get('updated_at'),
                    "message": "新闻数据为空，可能正在更新中"
                }
            )
        
        # 返回成功响应
        response_data = {
            "news": news_list,
            "count": len(news_list),
            "status": "success",
            "last_update": cached_news.get('updated_at'),
            "data_source": "redis_cache",
            "scheduler_type": cached_news.get('scheduler', 'apscheduler'),
            "auto_updated": True,
            "cache_info": {
                "data_source": cached_news.get('data_source', 'phoenix_finance'),
                "scheduler": "APScheduler (轻量级)"
            }
        }
        
        logger.info(f"成功从Redis缓存获取 {len(news_list)} 条新闻")
        
        return NewsListResponse(
            success=True,
            message=f"获取最新新闻成功，共 {len(news_list)} 条",
            data=response_data
        )
        
    except Exception as e:
        logger.error(f"获取最新新闻失败：{str(e)}")
        return NewsListResponse(
            success=False,
            message=f"获取最新新闻失败：{str(e)}",
            data={
                "error": str(e),
                "status": "error",
                "suggestion": "请检查Redis连接状态或联系管理员"
            }
        )

@router.get(
    "/api/news/scheduler/status",
    dependencies=[Depends(verify_token)],
    response_model=TaskStatusResponse,
    summary="获取新闻调度器状态",
    description="""
    获取APScheduler新闻调度器的运行状态和统计信息。
    
    包含信息：
    - 调度器运行状态
    - 定时任务配置和下次执行时间
    - 最近执行日志（成功/失败/跳过）
    - 缓存状态和数据统计
    - 执行耗时统计
    """,
    response_description="返回调度器状态和执行历史"
)
async def get_scheduler_status_api():
    """
    获取新闻调度器状态
    
    提供调度器的详细状态信息，包括：
    - 任务运行状态和下次执行时间
    - 执行历史和日志
    - 缓存数据统计
    """
    try:
        status_data = get_scheduler_status()
        
        return TaskStatusResponse(
            success=True,
            message="获取调度器状态成功",
            data=status_data
        )
        
    except Exception as e:
        logger.error(f"获取调度器状态失败：{str(e)}")
        return TaskStatusResponse(
            success=False,
            message=f"获取调度器状态失败：{str(e)}",
            data={"error": str(e)}
        )

@router.post(
    "/api/news/scheduler/trigger",
    dependencies=[Depends(verify_token)],
    response_model=TaskStatusResponse,
    summary="立即触发新闻爬取",
    description="""
    手动触发一次新闻爬取任务，不影响定时调度。
    
    使用场景：
    - 需要立即更新新闻数据
    - 测试调度器功能
    - 首次启动后快速获取数据
    
    执行方式：
    - 异步执行，立即返回
    - 不阻塞其他请求
    - 可通过状态接口查看执行结果
    """,
    response_description="返回触发结果"
)
async def trigger_news_crawl():
    """
    立即触发新闻爬取任务
    
    手动触发一次新闻爬取，用于：
    - 测试功能
    - 快速更新数据
    - 应急更新
    """
    try:
        # 确保使用force_crawl=True参数
        result = trigger_immediate_crawl(force_crawl=True)
        
        return TaskStatusResponse(
            success=result['success'],
            message=result['message'],
            data=result
        )
        
    except Exception as e:
        logger.error(f"触发新闻爬取失败：{str(e)}")
        return TaskStatusResponse(
            success=False,
            message=f"触发新闻爬取失败：{str(e)}",
            data={"error": str(e)}
        )

@router.post(
    "/api/news/analysis", 
    response_model=NewsAnalysisResponse,
    dependencies=[Depends(verify_token)],
    summary="获取财经新闻消息面分析",
    description="基于Redis缓存中的最新财经新闻，使用人工智能分析当前市场的消息面情况，包括热点、风险、机会等方面。"
)
async def get_market_news_analysis(request: AnalysisRequest):
    """
    获取市场消息面分析
    
    基于调度器自动缓存的最新新闻数据进行AI分析
    """
    try:
        # 检查是否有新闻数据
        cached_news = redis_cache.get_cache(NEWS_KEYS['news_latest'])
        if not cached_news or not cached_news.get('news'):
            return NewsAnalysisResponse(
                success=False,
                message="暂无新闻数据进行分析，请等待调度器更新数据",
                data=None
            )
        
        # 检查是否有缓存的分析结果
        cached_analysis = redis_cache.get_cache('news:analysis_result')
        if not request.force_refresh and cached_analysis:
            logger.info("使用缓存的消息面分析结果")
            
            # 创建符合NewsAnalysisData模型的数据
            analysis_data = NewsAnalysisData(
                analysis=cached_analysis["analysis"],
                updated_at=cached_analysis.get("generated_time", datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
            )
                
            return NewsAnalysisResponse(
                success=True,
                message="获取消息面分析成功（来自缓存）",
                data=analysis_data
            )
        
        # 如果需要强制刷新或没有缓存，执行AI分析
        # 使用线程池异步执行，避免阻塞事件循环
        import asyncio
        import concurrent.futures
        
        loop = asyncio.get_event_loop()
        with concurrent.futures.ThreadPoolExecutor() as executor:
            analysis_result = await loop.run_in_executor(
                executor,
                get_news_sentiment_analysis,
                request.force_refresh,
                request.ai_model_name,
                request.ai_endpoint,
                request.ai_api_key
            )
        
        if "error" in analysis_result:
            return NewsAnalysisResponse(
                success=False,
                message=analysis_result["error"],
                data=None
            )
        
        # 创建符合NewsAnalysisData模型的数据
        analysis_data = NewsAnalysisData(
            analysis=analysis_result["analysis"],
            updated_at=analysis_result.get("generated_time", datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
        )
            
        return NewsAnalysisResponse(
            success=True,
            message="获取消息面分析成功",
            data=analysis_data
        )
        
    except Exception as e:
        logger.error(f"获取消息面分析失败：{str(e)}")
        return NewsAnalysisResponse(
            success=False,
            message=f"获取消息面分析失败：{str(e)}",
            data=None
        )

@router.get(
    "/api/news/analysis/status", 
    response_model=NewsAnalysisResponse,
    dependencies=[Depends(verify_token)],
    summary="获取财经新闻消息面分析状态",
    description="检查是否有缓存的消息面分析结果，不会触发新的分析任务。"
)
async def get_analysis_status():
    """
    获取消息面分析状态
    
    检查是否有缓存的分析结果，不会触发新的分析
    """
    try:
        # 检查是否有缓存的分析结果
        cached_analysis = redis_cache.get_cache('news:analysis_result')
        
        if cached_analysis:
            # 创建符合NewsAnalysisData模型的数据
            analysis_data = NewsAnalysisData(
                analysis=cached_analysis["analysis"],
                updated_at=cached_analysis.get("generated_time", datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
            )
                
            return NewsAnalysisResponse(
                success=True,
                message="获取消息面分析成功",
                data=analysis_data
            )
        else:
            return NewsAnalysisResponse(
                success=False,
                message="暂无消息面分析结果，请先触发分析",
                data=None
            )
        
    except Exception as e:
        logger.error(f"获取消息面分析状态失败：{str(e)}")
        return NewsAnalysisResponse(
            success=False,
            message=f"获取消息面分析状态失败：{str(e)}",
            data=None
        )

# API简化说明：
# 
# 保留的功能：
# - /api/news/latest - 获取最新新闻（从调度器缓存读取）
# - /api/news/scheduler/status - 查看调度器状态和日志
# - /api/news/scheduler/trigger - 手动触发爬取（可选）
# - /api/news/analysis - AI消息面分析
# 
# 移除的复杂功能：
# - Celery相关的所有组件
# - /api/news/crawl - 手动爬取接口（由调度器自动处理）
# - /api/news/cache/clear - 手动清理接口（自动失效）
# - Flower监控系统（改用简单的状态接口）
# 
# 优势：
# 1. 复杂度降低：无需Celery、Beat、Flower等组件
# 2. 启动简单：一个命令启动所有功能
# 3. 即时执行：启动时立即爬取一次
# 4. 自动管理：缓存自动失效，日志自动清理
# 5. 易于调试：直接查看Python日志输出
