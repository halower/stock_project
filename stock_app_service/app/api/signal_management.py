#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
买入信号管理API
提供买入信号的查询功能

优化说明：
1. 信号数据在计算时已包含价格和涨跌幅，无需再次查询
2. 实时价格更新通过WebSocket推送，不在API中处理
3. 极致性能：直接从Redis读取已计算好的信号数据
"""

import math
from typing import List, Optional, Dict, Any
from fastapi import APIRouter, Depends, HTTPException, Query, Body
from pydantic import BaseModel, Field
from app.api.dependencies import verify_token
from app.core.logging import logger
from app.services.signal.signal_manager import signal_manager

router = APIRouter()


# ==================== 请求/响应模型 ====================

class BatchSignalCheckRequest(BaseModel):
    """批量信号查询请求"""
    stocks: List[Dict[str, str]] = Field(
        ..., 
        description="股票列表，每个元素包含 code(股票代码) 和 strategy(策略代码)",
        example=[
            {"code": "600519", "strategy": "volume_wave"},
            {"code": "000001", "strategy": "volume_wave_enhanced"}
        ]
    )


class StockSignalResult(BaseModel):
    """单个股票的信号结果"""
    code: str = Field(..., description="股票代码")
    name: Optional[str] = Field(None, description="股票名称")
    strategy: str = Field(..., description="策略代码")
    signal: Optional[str] = Field(None, description="信号类型: buy/sell/null")
    signal_reason: Optional[str] = Field(None, description="信号原因")
    confidence: Optional[float] = Field(None, description="信号置信度")
    price: Optional[float] = Field(None, description="当前价格")
    change_percent: Optional[float] = Field(None, description="涨跌幅")


# ==================== 工具函数 ====================

def clean_numeric_value(value, default=0):
    """清理数值，确保JSON序列化兼容"""
    if value is None:
        return default
    if isinstance(value, (int, float)):
        if math.isnan(value) or math.isinf(value):
            return default
        return value
    try:
        num_value = float(value)
        if math.isnan(num_value) or math.isinf(num_value):
            return default
        return num_value
    except (ValueError, TypeError):
        return default

def format_volume_humanized(volume):
    """格式化成交量为人性化显示（A股习惯：股数单位）"""
    volume = clean_numeric_value(volume, 0)
    if volume <= 0:
        return "无数据"
    elif volume < 10000:
        return f"{volume:,.0f}股"
    elif volume < 100000000:
        wan = volume / 10000
        if wan >= 1000:
            return f"{wan/100:.1f}千万股"
        else:
            return f"{wan:.1f}万股"
    else:
        yi = volume / 100000000
        return f"{yi:.2f}亿股"


# ==================== API端点 ====================

@router.get("/api/stocks/signal/buy", summary="获取买入信号", tags=["买入信号"], dependencies=[Depends(verify_token)])
async def get_buy_signals(
    strategy: Optional[str] = Query(None, description="策略名称（可选）：volume_wave(量价突破), volume_wave_enhanced(量价进阶), volatility_conservation(趋势追踪)")
):
    """
    获取买入信号
    
    性能优化：
    - 直接从Redis读取已计算好的信号数据
    - 信号包含计算时的价格和涨跌幅
    - 实时价格更新通过WebSocket推送
    """
    try:
        # 确保signal_manager已初始化
        init_success = await signal_manager.initialize()
        if not init_success:
            raise HTTPException(status_code=500, detail="SignalManager初始化失败")
        
        # 直接获取信号（已包含价格和涨跌幅）
        signals = await signal_manager.get_buy_signals(strategy=strategy)
        
        # 清理信号数据中的无效数值
        for signal in signals:
            # 清理所有数值字段
            for key in ['price', 'volume', 'volume_ratio', 'change_percent', 'confidence']:
                if key in signal:
                    signal[key] = clean_numeric_value(signal[key], 0)
                
                # 添加人性化成交量显示
                volume = signal.get('volume', 0)
                signal['volume_display'] = format_volume_humanized(volume)
            
        logger.info(f"获取到 {len(signals)} 个信号")
        
        return {
            "code": 200,
            "message": "获取买入信号成功",
            "data": {
                "strategy": strategy,
                "signals": signals,
                "count": len(signals)
            }
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取买入信号失败: {str(e)}")
        import traceback
        logger.error(f"详细错误: {traceback.format_exc()}")
        return {
            "code": 500,
            "message": f"获取买入信号失败: {str(e)}",
            "data": {
                "strategy": strategy,
                "signals": [],
                "count": 0
            }
        }


@router.post("/api/stocks/signal/batch-check", summary="批量查询股票信号", tags=["买入信号"], dependencies=[Depends(verify_token)])
async def batch_check_signals(
    request: BatchSignalCheckRequest = Body(..., description="批量查询请求")
):
    """
    批量查询股票的买入/卖出信号
    
    用于备选池等场景，一次性查询多只股票的最新信号状态。
    支持每只股票使用不同的策略进行查询。
    
    信号类型：
    - buy: 买入信号
    - sell: 卖出信号  
    - null: 无信号
    """
    try:
        # 确保signal_manager已初始化
        init_success = await signal_manager.initialize()
        if not init_success:
            raise HTTPException(status_code=500, detail="SignalManager初始化失败")
        
        results = []
        
        # 按策略分组查询，提高效率
        strategy_stocks: Dict[str, List[str]] = {}
        stock_strategy_map: Dict[str, str] = {}  # code -> strategy
        
        for item in request.stocks:
            code = item.get('code', '')
            strategy = item.get('strategy', 'volume_wave')
            
            if not code:
                continue
                
            if strategy not in strategy_stocks:
                strategy_stocks[strategy] = []
            strategy_stocks[strategy].append(code)
            stock_strategy_map[code] = strategy
        
        # 批量计算每个策略的信号
        for strategy, codes in strategy_stocks.items():
            try:
                # 调用signal_manager的批量信号检查方法
                signals = await signal_manager.batch_check_signals(codes, strategy)
                
                for code in codes:
                    signal_info = signals.get(code, {})
                    results.append({
                        "code": code,
                        "name": signal_info.get('name'),
                        "strategy": strategy,
                        "signal": signal_info.get('signal'),  # buy/sell/null
                        "signal_reason": signal_info.get('reason'),
                        "confidence": clean_numeric_value(signal_info.get('confidence')),
                        "price": clean_numeric_value(signal_info.get('price')),
                        "change_percent": clean_numeric_value(signal_info.get('change_percent'))
                    })
                    
            except Exception as e:
                logger.error(f"策略 {strategy} 批量查询失败: {e}")
                # 对于失败的股票，返回空信号
                for code in codes:
                    results.append({
                        "code": code,
                        "name": None,
                        "strategy": strategy,
                        "signal": None,
                        "signal_reason": None,
                        "confidence": None,
                        "price": None,
                        "change_percent": None
                    })
        
        logger.info(f"批量查询信号完成: {len(results)} 只股票")
        
        return {
            "code": 200,
            "message": "批量查询信号成功",
            "data": {
                "results": results,
                "count": len(results)
            }
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"批量查询信号失败: {str(e)}")
        import traceback
        logger.error(f"详细错误: {traceback.format_exc()}")
        return {
            "code": 500,
            "message": f"批量查询信号失败: {str(e)}",
            "data": {
                "results": [],
                "count": 0
            }
        }

 