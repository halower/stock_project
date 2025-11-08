#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
市场类型管理API
提供动态市场类型列表，支持股票和ETF的市场分类
"""

from fastapi import APIRouter, Depends
from typing import List, Dict, Any
from app.api.dependencies import verify_token
from app.core.logging import logger
from app.core.redis_client import get_redis_client

router = APIRouter(tags=["市场类型"])


def get_market_display_name(market_code: str) -> str:
    """
    将市场代码转换为显示名称
    
    Args:
        market_code: 市场代码（如 SH, SZ, BJ, ETF等）
        
    Returns:
        市场显示名称
    """
    # 预定义市场映射
    market_mapping = {
        'SH': '上证主板',
        'SZ': '深证主板',
        'BJ': '北交所',
        'ETF': 'ETF',
    }
    
    return market_mapping.get(market_code, market_code)


def categorize_market(market_value: str) -> str:
    """
    将原始market字段归类为标准分类
    
    Args:
        market_value: 原始market字段值
        
    Returns:
        标准分类名称
    """
    if not market_value:
        return '其他'
    
    # ETF单独分类
    if market_value == 'ETF':
        return 'ETF'
    
    # 根据market字段内容进行分类
    market_lower = market_value.lower()
    
    # 主板
    if '主板' in market_value or market_value in ['SH', 'SZ']:
        return '主板'
    
    # 创业板
    if '创业板' in market_value or market_lower == 'cyb':
        return '创业板'
    
    # 科创板
    if '科创板' in market_value or market_lower == 'kcb':
        return '科创板'
    
    # 北交所
    if '北交所' in market_value or market_value == 'BJ' or '北京' in market_value:
        return '北交所'
    
    return '其他'


@router.get("/api/market-types", summary="获取所有市场类型", dependencies=[Depends(verify_token)])
@router.get("/market-types", summary="获取所有市场类型（兼容路径）", dependencies=[Depends(verify_token)])
async def get_market_types() -> Dict[str, Any]:
    """
    获取系统中所有可用的市场类型
    
    Returns:
        市场类型列表，包含市场代码和显示名称
        
    响应格式:
    {
        "code": 200,
        "message": "获取市场类型成功",
        "data": {
            "market_types": [
                {"code": "all", "name": "全部"},
                {"code": "main_board", "name": "主板"},
                {"code": "gem", "name": "创业板"},
                {"code": "star", "name": "科创板"},
                {"code": "bse", "name": "北交所"},
                {"code": "etf", "name": "ETF"}
            ],
            "count": 6
        }
    }
    """
    redis_client = None
    try:
        # 每次请求都重新获取Redis客户端，确保在正确的事件循环中
        redis_client = await get_redis_client()
        
        # 从Redis获取所有股票数据
        stock_list_data = await redis_client.hgetall("stock_list")
        
        if not stock_list_data:
            logger.warning("Redis中没有股票数据")
            # 返回默认市场类型
            return {
                "code": 200,
                "message": "获取市场类型成功（使用默认数据）",
                "data": {
                    "market_types": [
                        {"code": "all", "name": "全部"},
                        {"code": "main_board", "name": "主板"},
                        {"code": "gem", "name": "创业板"},
                        {"code": "star", "name": "科创板"},
                        {"code": "bse", "name": "北交所"},
                        {"code": "etf", "name": "ETF"}
                    ],
                    "count": 6
                }
            }
        
        # 统计所有唯一的市场类型
        market_categories = set()
        
        import json
        for ts_code, stock_data_str in stock_list_data.items():
            try:
                stock_data = json.loads(stock_data_str)
                market_value = stock_data.get('market', '')
                
                # 将market归类
                category = categorize_market(market_value)
                market_categories.add(category)
                
            except json.JSONDecodeError:
                continue
            except Exception as e:
                logger.debug(f"处理股票 {ts_code} 时出错: {e}")
                continue
        
        # 构建市场类型列表（确保顺序）
        market_types = [{"code": "all", "name": "全部"}]
        
        # 定义标准市场顺序和映射
        standard_markets = [
            ("main_board", "主板"),
            ("gem", "创业板"),
            ("star", "科创板"),
            ("bse", "北交所"),
            ("etf", "ETF"),
        ]
        
        for code, name in standard_markets:
            if name in market_categories:
                market_types.append({"code": code, "name": name})
        
        # 添加其他未分类的市场
        if "其他" in market_categories:
            market_types.append({"code": "other", "name": "其他"})
        
        logger.info(f"成功获取 {len(market_types)} 个市场类型")
        
        return {
            "code": 200,
            "message": "获取市场类型成功",
            "data": {
                "market_types": market_types,
                "count": len(market_types)
            }
        }
        
    except Exception as e:
        logger.error(f"获取市场类型失败: {str(e)}")
        import traceback
        logger.error(f"详细错误: {traceback.format_exc()}")
        
        # 返回默认市场类型作为降级方案
        return {
            "code": 200,
            "message": f"获取市场类型失败，使用默认数据: {str(e)}",
            "data": {
                "market_types": [
                    {"code": "all", "name": "全部"},
                    {"code": "main_board", "name": "主板"},
                    {"code": "gem", "name": "创业板"},
                    {"code": "star", "name": "科创板"},
                    {"code": "bse", "name": "北交所"},
                    {"code": "etf", "name": "ETF"}
                ],
                "count": 6
            }
        }




