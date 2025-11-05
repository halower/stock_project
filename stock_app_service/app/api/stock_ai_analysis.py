# -*- coding: utf-8 -*-
"""
股票AI分析API路由
提供股票技术分析和AI分析服务
"""
import logging
from fastapi import APIRouter, HTTPException, Depends, Body, Query
from pydantic import BaseModel
from app.services.analysis.stock_ai_analysis_service import StockAIAnalysisService
from app.api.dependencies import verify_token

logger = logging.getLogger(__name__)

router = APIRouter()

from typing import Optional, Dict, Any

class AIAnalysisRequest(BaseModel):
    """AI分析请求参数"""
    stock_code: str
    force_refresh: bool = False
    ai_model_name: str
    ai_endpoint: str
    ai_api_key: str
    indicators: Optional[Dict[str, Any]] = None  # 客户端计算的技术指标

@router.get("/api/stocks/ai-analysis/cache",
           summary="查询股票AI分析缓存",
           description="检查指定股票是否有AI分析缓存，有则返回分析结果，没有则返回空",
           tags=["股票AI分析"],
           dependencies=[Depends(verify_token)])
async def get_stock_ai_analysis_cache(
    code: str = Query(..., description="股票代码")
):
    """
    查询股票AI分析缓存
    
    **查询参数:**
    - **code**: 股票代码（如：000001）
    
    **返回结果:**
    - 如果有缓存：返回分析结果
    - 如果无缓存：返回空结果
    """
    try:
        logger.info(f"查询AI分析缓存: stock_code={code}")
        
        # 验证股票代码
        if not code:
            raise HTTPException(status_code=400, detail="股票代码不能为空")
        
        # 创建服务实例
        service = StockAIAnalysisService()
        
        # 确保服务已初始化
        if not await service.initialize():
            raise HTTPException(status_code=500, detail="AI分析服务初始化失败")
        
        # 检查缓存
        cached_analysis = await service._get_cached_analysis(code)
        
        # 关闭服务连接
        await service.close()
        
        if cached_analysis:
            logger.info(f"找到AI分析缓存: stock_code={code}")
            return {
                "success": True,
                "has_cache": True,
                "stock_code": code,
                "analysis": cached_analysis,
                "from_cache": True
            }
        else:
            logger.info(f"未找到AI分析缓存: stock_code={code}")
            return {
                "success": True,
                "has_cache": False,
                "stock_code": code,
                "analysis": None,
                "message": "该股票暂无AI分析缓存"
            }
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"查询AI分析缓存失败: stock_code={code}, error={e}")
        raise HTTPException(status_code=500, detail=f"查询缓存失败: {str(e)}")

@router.post("/api/stocks/ai-analysis/simple",
            summary="获取股票AI分析",
            description="基于股票历史数据进行AI技术分析，返回完整结果",
            tags=["股票AI分析"],
            dependencies=[Depends(verify_token)])
async def get_stock_ai_analysis_simple(
    request: AIAnalysisRequest = Body(...)
):
    """
    获取股票AI分析
    
    **POST请求体参数:**
    - **stock_code**: 股票代码（如：000001）
    - **force_refresh**: 是否强制刷新缓存（默认false）
    - **ai_model_name**: AI模型名称（必填）
    - **ai_endpoint**: AI服务端点URL（必填）
    - **ai_api_key**: AI API密钥（必填）
    
    **返回结果:**
    返回完整的分析结果，支持自动缓存（当天有效）
    """
    try:
        logger.info(f"收到AI分析请求: stock_code={request.stock_code}, force_refresh={request.force_refresh}")
        
        # 验证必填参数
        if not request.stock_code:
            raise HTTPException(status_code=400, detail="股票代码不能为空")
        if not request.ai_model_name:
            raise HTTPException(status_code=400, detail="AI模型名称不能为空")
        if not request.ai_endpoint:
            raise HTTPException(status_code=400, detail="AI服务端点不能为空")
        if not request.ai_api_key:
            raise HTTPException(status_code=400, detail="AI API密钥不能为空")
        
        # 创建服务实例
        service = StockAIAnalysisService()
        
        # 确保服务已初始化
        if not await service.initialize():
            raise HTTPException(status_code=500, detail="AI分析服务初始化失败")
        
        # 收集所有流式更新
        final_result = None
        async for update in service.get_stock_analysis_stream(
            stock_code=request.stock_code,
            ai_model_name=request.ai_model_name,
            ai_endpoint=request.ai_endpoint,
            ai_api_key=request.ai_api_key,
            force_refresh=request.force_refresh,
            indicators=request.indicators
        ):
            if update.get('status') == 'completed':
                final_result = update
                break
            elif update.get('status') == 'error':
                logger.error(f"AI分析过程中出错: {update.get('message')}")
                raise HTTPException(status_code=400, detail=update.get('message', '分析失败'))
            elif update.get('status') == 'config_required':
                logger.error(f"AI配置问题: {update.get('message')}")
                raise HTTPException(status_code=400, detail=update.get('message', '需要AI配置'))
        
        # 关闭服务连接
        await service.close()
        
        if final_result:
            logger.info(f"AI分析完成: stock_code={request.stock_code}, from_cache={final_result.get('from_cache', False)}")
            return {
                "success": True,
                "stock_code": request.stock_code,
                "analysis": final_result.get('analysis'),
                "from_cache": final_result.get('from_cache', False),
                "timestamp": final_result.get('timestamp')
            }
        else:
            logger.error(f"未能获取分析结果: stock_code={request.stock_code}")
            raise HTTPException(status_code=500, detail="未能获取分析结果")
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"AI分析失败: stock_code={getattr(request, 'stock_code', 'unknown')}, error={e}")
        raise HTTPException(status_code=500, detail=f"AI分析失败: {str(e)}") 