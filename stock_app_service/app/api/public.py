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
        # 使用东方财富API获取新闻数据
        logger.info(f"使用东方财富API获取股票 {symbol} 的新闻资讯数据")
        
        try:
            # 东方财富个股新闻API
            url = "https://search-api-web.eastmoney.com/search/jsonp"
            params = {
                "cb": "jQuery",
                "param": json.dumps({
                    "uid": "",
                    "keyword": symbol,
                    "type": ["cmsArticleWebOld"],
                    "client": "web",
                    "clientType": "web",
                    "clientVersion": "curr",
                    "param": {
                        "cmsArticleWebOld": {
                            "searchScope": "default",
                            "sort": "default",
                            "pageIndex": 1,
                            "pageSize": 100,
                            "preTag": "<em>",
                            "postTag": "</em>"
                        }
                    }
                }),
                "_": str(int(time.time() * 1000))
            }
            
            headers = {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
                'Referer': 'https://so.eastmoney.com/'
            }
            
            response = requests.get(url, params=params, headers=headers, timeout=30)
            response.raise_for_status()
            
            # 解析JSONP响应
            text = response.text
            # 移除JSONP包装
            if text.startswith('jQuery'):
                text = text[text.index('(') + 1:text.rindex(')')]
            
            data = json.loads(text)
            
            # 提取新闻列表
            news_list = []
            if data.get('result') and data['result'].get('cmsArticleWebOld'):
                articles = data['result']['cmsArticleWebOld']
                for article in articles:
                    news_item = {
                        '关键词': symbol,
                        '新闻标题': article.get('title', ''),
                        '新闻内容': article.get('content', ''),
                        '发布时间': article.get('date', ''),
                        '文章来源': article.get('mediaName', ''),
                        '新闻链接': article.get('url', '')
                    }
                    news_list.append(news_item)
            
            # 缓存结果
            news_cache[cache_key] = {
                "data": news_list,
                "timestamp": current_time
            }
            
            logger.info(f"成功获取股票 {symbol} 的 {len(news_list)} 条新闻")
            return news_list
            
        except requests.Timeout:
            logger.error(f"获取股票 {symbol} 的新闻数据超时（30秒）")
            return []
        except Exception as e:
            logger.error(f"使用东方财富API获取股票 {symbol} 的新闻数据失败: {str(e)}")
            return []
    
    except Exception as e:
        logger.error(f"获取股票 {symbol} 的新闻资讯失败: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"获取新闻资讯失败: {str(e)}"
        ) 