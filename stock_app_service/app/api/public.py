# -*- coding: utf-8 -*-
"""新闻资讯API路由"""

from fastapi import APIRouter, Query, HTTPException, Depends, status
import requests
from typing import Any, Optional
from datetime import datetime, timedelta
import json
import hashlib
from sqlalchemy.orm import Session
import time

from app.core.logging import logger
from app.db.session import get_db
from app.api.dependencies import verify_token

# 简单的内存缓存实现
news_cache = {}
NEWS_CACHE_TTL = 3600  # 新闻缓存1小时

router = APIRouter(tags=["新闻资讯"])

# 尝试导入akshare用于新闻功能（可选依赖）
try:
    import akshare as ak
    import pandas as pd
    AKSHARE_AVAILABLE = True
    logger.info("akshare可用，新闻功能已启用")
except ImportError:
    AKSHARE_AVAILABLE = False
    logger.warning("akshare未安装，新闻功能不可用。如需使用新闻功能，请安装: pip install akshare")

@router.get(
    "/api/public/stock_news", 
    dependencies=[Depends(verify_token)],
    summary="获取个股新闻资讯数据",
    description="获取指定股票代码的相关新闻资讯，数据来源为东方财富，每次请求返回最近100条相关新闻",
    response_description="返回新闻列表，每条新闻包含标题、内容摘要、发布时间、来源和链接等信息"
)
async def get_stock_news(
    symbol: str = Query(..., description="股票代码或其他关键词，如：300059"),
    refresh_cache: bool = Query(False, description="是否强制刷新缓存"),
    db: Session = Depends(get_db)
) -> Any:
    """
    获取指定股票的新闻资讯数据
    
    系统会先检查缓存，如存在有效缓存则直接返回，除非指定refresh_cache=True强制刷新
    
    Args:
        symbol: 股票代码或搜索关键词
        refresh_cache: 是否强制刷新缓存
        db: 数据库会话
        
    Returns:
        包含个股新闻资讯的数据列表，限量为当日最近100条新闻资讯数据
        
    响应字段:
        - 关键词: 搜索的关键词
        - 新闻标题: 新闻的标题
        - 新闻内容: 新闻的简要内容
        - 发布时间: 新闻的发布时间
        - 文章来源: 新闻的来源
        - 新闻链接: 新闻的详细链接
    
    Raises:
        HTTPException: 当外部API调用失败或返回无效数据时抛出
    """
    # 生成缓存键
    cache_key = f"stock_news_{symbol}"
    current_time = time.time()
    
    # 检查缓存
    if not refresh_cache and cache_key in news_cache:
        cache_entry = news_cache[cache_key]
        # 验证缓存是否有效
        if current_time - cache_entry["timestamp"] < NEWS_CACHE_TTL:
            logger.debug(f"使用缓存数据返回股票 {symbol} 的新闻资讯")
            return cache_entry["data"]
    
    try:
        # 检查akshare是否可用
        if not AKSHARE_AVAILABLE:
            logger.warning(f"akshare未安装，无法获取股票 {symbol} 的新闻数据")
            return {
                "error": "新闻功能不可用",
                "message": "akshare库未安装。本系统主要使用Tushare，akshare仅用于新闻功能（可选）。如需使用新闻功能，请安装: pip install akshare",
                "data": []
            }
        
        # 直接使用akshare获取新闻数据，不再依赖外部API
        logger.info(f"使用akshare获取股票 {symbol} 的新闻资讯数据")
        
        try:
            # 使用asyncio在线程池中执行阻塞的akshare调用，并设置超时
            import asyncio
            import concurrent.futures
            
            loop = asyncio.get_event_loop()
            with concurrent.futures.ThreadPoolExecutor() as executor:
                # 在线程池中执行阻塞调用，设置30秒超时避免长时间阻塞
                try:
                    news_df = await asyncio.wait_for(
                        loop.run_in_executor(executor, ak.stock_news_em, symbol),
                        timeout=30.0  # 30秒超时
                    )
                except asyncio.TimeoutError:
                    logger.error(f"获取股票 {symbol} 的新闻数据超时（30秒）")
                    return []
            
            # 转换为字典列表
            news_data = news_df.to_dict('records')
            
            # 缓存结果
            news_cache[cache_key] = {
                "data": news_data,
                "timestamp": current_time
            }
            
            return news_data
            
        except Exception as e:
            logger.error(f"使用akshare获取股票 {symbol} 的新闻数据失败: {str(e)}")
            # 如果akshare获取失败，返回空列表
            return []
    
    except Exception as e:
        logger.error(f"获取股票 {symbol} 的新闻资讯失败: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"获取新闻资讯失败: {str(e)}"
        ) 