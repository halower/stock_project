# -*- coding: utf-8 -*-
"""新闻消息面分析服务模块"""

import os
import json
import requests
from typing import Dict, Any, List, Optional
from datetime import datetime, timedelta
import pandas as pd
import time
import random
import re
from bs4 import BeautifulSoup

from app.core.logging import logger
from app.core.config import (
    AI_MAX_TOKENS, AI_TEMPERATURE
)
from app.db.session import RedisCache

# Redis缓存客户端
redis_cache = RedisCache()

# 新闻数据缓存键定义
NEWS_KEYS = {
    'news_latest': 'news:latest',
    'news_last_update': 'news:last_update',
    'news_scheduler_log': 'news:scheduler:log',
}

# 新闻数据缓存（内存缓存作为备用）
news_cache = {}  # {key: {"data": [...], "timestamp": datetime对象}}
news_analysis_cache = {}  # {key: {"analysis": "...", "timestamp": datetime对象}}

def get_phoenix_finance_news(days: int = 1, skip_content: bool = False, force_crawl: bool = False) -> List[Dict[str, Any]]:
    """从凤凰财经爬取新闻数据
    
    Args:
        days: 获取最近几天的数据
        skip_content: 是否跳过获取新闻详情内容，仅获取标题和链接
        force_crawl: 是否强制爬取，忽略缓存
        
    Returns:
        新闻数据列表
    """
    # 首先检查Redis缓存（优先级最高）
    if not force_crawl and days <= 2:  # 对于1-2天的新闻，优先使用Redis缓存
        redis_news = redis_cache.get_cache(NEWS_KEYS['news_latest'])
        if redis_news and redis_news.get('news'):
            logger.info(f"使用Redis缓存的凤凰财经新闻数据，新闻数量: {len(redis_news['news'])}")
            return redis_news['news']
    
    # 检查内存缓存
    cache_key = f"phoenix_finance_{days}"
    if not force_crawl and cache_key in news_cache:
        cache_data = news_cache[cache_key]
        # 缓存有效期2小时
        if (datetime.now() - cache_data["timestamp"]).total_seconds() < 7200:
            logger.info(f"使用内存缓存的凤凰财经新闻数据: {cache_key}, 新闻数量: {len(cache_data['data'])}")
            return cache_data["data"]
    
    news_list = []
    
    try:
        # 请求头
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8",
            "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8"
        }
        
        # 凤凰财经新闻列表页
        phoenix_urls = [
            "https://finance.ifeng.com/",  # 凤凰财经首页
            "https://finance.ifeng.com/stock/",  # 股票
            "https://finance.ifeng.com/ipo/",  # IPO
            "https://finance.ifeng.com/financial/",  # 金融
        ]
        
        # 设置请求参数，禁用代理
        request_kwargs = {
            "headers": headers, 
            "timeout": 10,
            "verify": False,  # 禁用SSL验证
            "proxies": {"http": None, "https": None}  # 禁用代理
        }
        
        # 禁用SSL警告
        import urllib3
        urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
        
        processed_titles = set()  # 用于去重
        
        for url in phoenix_urls:
            if len(news_list) >= 50:  # 控制新闻总数
                break
                
            try:
                # 防止请求过快
                time.sleep(random.uniform(0.3, 0.5))
                
                # 尝试使用禁用代理的方式请求
                try:
                    response = requests.get(url, **request_kwargs)
                except Exception as e:
                    logger.warning(f"使用无代理模式请求失败: {url}, {str(e)}")
                    # 如果禁用代理失败，尝试使用默认设置
                    response = requests.get(url, headers=headers, timeout=10)
                
                if response.status_code == 200:
                    soup = BeautifulSoup(response.text, 'html.parser')
                    
                    # 获取新闻列表
                    news_items = []
                    
                    # 尝试多种选择器获取新闻列表
                    selectors = [
                        '.news-stream-newsStream-news-item h2 a',  # 主流新闻项
                        '.content-list h3 a',  # 内容列表
                        '.newsList li h3 a',  # 新闻列表
                        '.news-list li a',  # 标准新闻列表
                        '.box-list li a',  # 盒子列表
                        'a.tit',  # 标题链接
                        '.headline-news h2 a',  # 头条新闻
                    ]
                    
                    for selector in selectors:
                        items = soup.select(selector)
                        if items:
                            news_items.extend(items)
                    
                    # 如果没有找到新闻，尝试其他选择器
                    if not news_items:
                        items = soup.select('a[href*="finance.ifeng.com"]')
                        news_items.extend(items)
                    
                    # 处理找到的新闻
                    for item in news_items:
                        if len(news_list) >= 50:  # 控制新闻总数
                            break
                            
                        title = item.get_text().strip()
                        link = item.get('href')
                        
                        # 过滤无效标题和链接
                        if not title or not link or len(title) < 5 or title in processed_titles:
                            continue
                        
                        # 过滤掉"中国深度财经"和"上市公司研究院"这两个非新闻标题
                        if title == "中国深度财经" or title == "上市公司研究院":
                            continue
                            
                        # 确保URL是完整的
                        if not link.startswith('http'):
                            if link.startswith('/'):
                                link = 'https://finance.ifeng.com' + link
                            else:
                                continue
                        
                        # 只处理凤凰财经的链接
                        if not ('ifeng.com' in link and ('finance' in link or 'stock' in link)):
                            continue
                            
                        processed_titles.add(title)
                        
                        # 添加到新闻列表
                        news_list.append({
                            'title': title,
                            'url': link,
                            'source': '凤凰财经',
                            'datetime': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                            'content': ''
                        })
            except Exception as e:
                logger.warning(f"获取凤凰财经新闻列表失败: {url}, {str(e)}")
        
        logger.info(f"从凤凰财经获取到 {len(news_list)} 条新闻")
        
        # 如果获取到的新闻数量太少，但缓存中有数据，则使用缓存
        if len(news_list) < 5 and cache_key in news_cache:
            logger.warning(f"获取到的新闻数量太少({len(news_list)}条)，使用缓存中的新闻数据")
            return news_cache[cache_key]["data"]
        
        # 获取每篇新闻的详情内容，仅当skip_content为False时进行
        if not skip_content:
            logger.info(f"开始获取 {len(news_list)} 条新闻的详情内容")
            content_count = 0
            
            for i, news in enumerate(news_list):
                try:
                    # 防止请求过快
                    time.sleep(random.uniform(0.2, 0.3))  # 减少延迟时间
                    
                    # 尝试使用禁用代理的方式请求
                    try:
                        detail_response = requests.get(news['url'], **request_kwargs)
                    except Exception as e:
                        logger.warning(f"使用无代理模式请求新闻详情失败: {news['url']}, {str(e)}")
                        # 如果禁用代理失败，尝试使用默认设置
                        detail_response = requests.get(news['url'], headers=headers, timeout=10)
                    
                    if detail_response.status_code == 200:
                        detail_soup = BeautifulSoup(detail_response.text, 'html.parser')
                        
                        # 提取发布时间
                        time_str = None
                        time_selectors = [
                            '.time', '.date', '.ss_time', '.p_time', '.artTime', '.article-time',
                            '.article-meta .time', '.detail-title-date', '.date-source'
                        ]
                        for selector in time_selectors:
                            time_element = detail_soup.select_one(selector)
                            if time_element:
                                time_str = time_element.get_text().strip()
                                break
                        
                        # 解析时间
                        if time_str:
                            # 尝试多种格式解析时间
                            time_patterns = [
                                r'(\d{4})年(\d{1,2})月(\d{1,2})日\s*(\d{1,2}):(\d{1,2})',  # 2024年5月27日 19:52
                                r'(\d{4})-(\d{1,2})-(\d{1,2})\s*(\d{1,2}):(\d{1,2})',      # 2024-5-27 19:52
                                r'(\d{4})\/(\d{1,2})\/(\d{1,2})\s*(\d{1,2}):(\d{1,2})',    # 2024/5/27 19:52
                            ]
                            
                            for pattern in time_patterns:
                                match = re.search(pattern, time_str)
                                if match:
                                    if len(match.groups()) == 5:  # 年月日时分
                                        year, month, day, hour, minute = match.groups()
                                        time_str = f"{year}-{month.zfill(2)}-{day.zfill(2)} {hour}:{minute}"
                                        break
                        
                            try:
                                pub_time = datetime.strptime(time_str, '%Y-%m-%d %H:%M')
                                news['datetime'] = pub_time.strftime('%Y-%m-%d %H:%M:%S')
                            except Exception as e:
                                # 如果解析失败，保留当前时间
                                logger.warning(f"解析时间失败: {time_str}, {str(e)}")
                        
                        # 提取内容摘要
                        summary = ""
                        
                        # 先尝试获取摘要
                        summary_selectors = [
                            '.main-content', '.article-content', '.article_content', '.content',
                            '#main_content', '.all-content', '.article'
                        ]
                        
                        for selector in summary_selectors:
                            content_element = detail_soup.select_one(selector)
                            if content_element:
                                # 获取所有段落
                                paragraphs = content_element.select('p')
                                if paragraphs:
                                    # 提取前两段文字作为摘要
                                    text_paras = [p.get_text().strip() for p in paragraphs if p.get_text().strip()]
                                    if text_paras:
                                        summary = ' '.join(text_paras[:2])
                                        if len(summary) > 300:
                                            summary = summary[:297] + '...'
                                        break
                        
                        news['content'] = summary
                        content_count += 1
                        
                        # 每处理5条新闻记录一次日志
                        if content_count % 5 == 0:
                            logger.info(f"已获取 {content_count}/{len(news_list)} 条新闻的详情内容")
                        
                except Exception as e:
                    logger.warning(f"获取新闻详情失败: {news['url']}, {str(e)}")
        else:
            logger.info("跳过获取新闻详情内容")
            # 对于跳过内容的情况，设置空内容
            for news in news_list:
                news['content'] = ''
        
        # 根据发布时间过滤新闻
        filtered_news = []
        for news in news_list:
            try:
                news_time = datetime.strptime(news['datetime'], '%Y-%m-%d %H:%M:%S')
                if (datetime.now() - news_time).days <= days:
                    filtered_news.append(news)
            except Exception:
                # 如果日期解析失败，默认保留
                filtered_news.append(news)
        
        news_list = filtered_news
        
        # 只有当获取到足够的新闻时才更新缓存
        if len(news_list) >= 5:
            news_cache[cache_key] = {
                "data": news_list,
                "timestamp": datetime.now()
            }
            logger.info(f"更新凤凰财经新闻缓存: {cache_key}, 新闻数量: {len(news_list)}")
        else:
            logger.warning(f"获取到的新闻数量太少({len(news_list)}条)，不更新缓存")
        
        return news_list
    except Exception as e:
        logger.error(f"获取凤凰财经新闻失败: {str(e)}")
        # 如果出错且缓存中有数据，则使用缓存
        if cache_key in news_cache:
            logger.info(f"爬虫失败，使用缓存中的新闻数据: {cache_key}")
            return news_cache[cache_key]["data"]
        # 如果没有缓存，返回空列表
        return []

def get_today_news() -> List[Dict[str, Any]]:
    """获取当天的凤凰财经新闻，用于前端展示
    
    Returns:
        当天的新闻列表
    """
    # 获取今天的新闻，需要包含详情内容
    news_list = get_phoenix_finance_news(days=1, skip_content=False)
    
    # 统计获取到的新闻数量
    logger.info(f"获取到 {len(news_list)} 条今日新闻")
    
    # 格式化为前端需要的格式
    formatted_news = []
    for news in news_list:
        formatted_news.append({
            'title': news['title'],
            'url': news['url'],
            'datetime': news['datetime'],
            'source': news['source'],
            'summary': news.get('content', '')[:150] + '...' if news.get('content') and len(news.get('content')) > 150 else news.get('content', '')
        })
    
    return formatted_news

def analyze_news_by_titles(news_list: List[Dict[str, Any]], use_cache: bool = True, ai_model_name: str = None, ai_endpoint: str = None, ai_api_key: str = None) -> str:
    """
    分析新闻标题，生成消息面分析报告
    
    Args:
        news_list: 新闻列表
        use_cache: 是否使用缓存
        ai_model_name: AI模型名称
        ai_endpoint: AI接口地址
        ai_api_key: AI接口密钥
        
    Returns:
        分析文本
    """
    from app.services.analysis.llm_service import get_completion_with_custom_params
    from app.core.config import AI_MAX_TOKENS, AI_TEMPERATURE
    
    # 准备新闻标题数据
    news_titles = [news["title"] for news in news_list[:50]]  
    titles_text = "\n".join([f"{i+1}. {title}" for i, title in enumerate(news_titles)])
    
    # 构造提示词
    prompt = f"""
    作为一位专业的金融市场分析师，请基于以下{len(news_titles)}条最新财经新闻标题进行深度分析：
    
    {titles_text}
    
    请进行全面而深入的分析，包括以下方面：
    
    ## 1. 市场整体情绪分析
    - 分析当前市场情绪是积极、中性还是消极
    - 识别情绪变化的主要驱动因素
    - 评估情绪对市场走势的可能影响
    
    ## 2. 热点行业和投资主题
    - 识别当前受关注的重点行业板块
    - 分析新兴投资主题和概念
    - 评估各板块的投资机会和风险
    
    ## 3. 宏观经济和政策影响
    - 分析相关政策对市场的影响
    - 识别宏观经济数据的市场含义
    - 评估国际因素对国内市场的影响
    
    ## 4. 风险因素识别
    - 识别当前主要的市场风险点
    - 分析潜在的黑天鹅事件
    - 评估系统性风险和个股风险
    
    ## 5. 投资策略建议
    - 基于消息面分析的短期投资策略
    - 中长期投资方向建议
    - 风险控制和仓位管理建议
    
    ## 6. 关键信息总结
    - 总结最重要的3-5个市场信号
    - 提炼核心投资逻辑
    - 给出明确的操作建议
    
    请用专业但通俗易懂的语言进行分析，基于新闻内容进行客观分析，避免过度解读。对于不确定的部分请明确指出，保持分析的客观性和实用性。
    """
    
    # 调用AI进行分析
    analysis_result = get_completion_with_custom_params(
        prompt=prompt,
        model=ai_model_name,
        endpoint=ai_endpoint,
        api_key=ai_api_key,
        max_tokens=AI_MAX_TOKENS,
        temperature=AI_TEMPERATURE
    )
    
    return analysis_result

def get_news_sentiment_analysis(force_refresh: bool = False, ai_model_name: str = None, ai_endpoint: str = None, ai_api_key: str = None) -> Dict[str, Any]:
    """获取新闻消息面分析
    
    Args:
        force_refresh: 是否强制刷新分析结果
        ai_model_name: AI模型名称
        ai_endpoint: AI接口地址
        ai_api_key: AI接口密钥
        
    Returns:
        分析结果字典
    """
    logger.info(f"开始获取新闻消息面分析, force_refresh: {force_refresh}, model: {ai_model_name}")
    
    # 检查缓存
    cache_key = "news:analysis_result"
    if not force_refresh:
        # 检查Redis缓存
        cached_result = redis_cache.get_cache(cache_key)
        if cached_result:
            logger.info("使用Redis缓存的消息面分析结果")
            return cached_result
        
        # 检查内存缓存
        if "news_sentiment" in news_analysis_cache:
            cache_data = news_analysis_cache["news_sentiment"]
            # 缓存有效期6小时
            if (datetime.now() - cache_data["timestamp"]).total_seconds() < 21600:
                logger.info("使用内存缓存的消息面分析结果")
                return cache_data["data"]
    
    # 获取最新新闻数据
    news_data = redis_cache.get_cache(NEWS_KEYS['news_latest'])
    if not news_data or not news_data.get('news'):
        return {"error": "没有找到新闻数据，请先获取新闻"}
    
    news_list = news_data.get('news', [])
    logger.info(f"使用Redis缓存的新闻数据进行分析，新闻数量: {len(news_list)}")
    
    # 分析新闻标题
    try:
        start_time = time.time()
        
        # 准备分析数据
        logger.info(f"准备分析 {len(news_list)} 条新闻标题")
        
        # 调用AI模型进行分析
        logger.info(f"调用AI模型: {ai_model_name}")
        analysis_text = analyze_news_by_titles(news_list, use_cache=not force_refresh, ai_model_name=ai_model_name, ai_endpoint=ai_endpoint, ai_api_key=ai_api_key)
        
        # 准备返回数据
        result = {
            "analysis": analysis_text,
            "generated_time": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "model": ai_model_name,
            "news_count": len(news_list)
        }
        
        # 更新缓存
        redis_cache.set_cache(cache_key, result, ttl=21600)  # 6小时
        news_analysis_cache["news_sentiment"] = {
            "data": result,
            "timestamp": datetime.now()
        }
        
        end_time = time.time()
        logger.info(f"AI分析完成，耗时: {end_time - start_time:.2f}秒")
        logger.info("更新共享消息面分析缓存到Redis和内存，有效期6小时")
        
        return result
        
    except Exception as e:
        logger.error(f"分析新闻失败: {str(e)}")
        return {"error": f"分析新闻失败: {str(e)}"} 