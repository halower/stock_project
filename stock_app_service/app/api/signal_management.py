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
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from app.api.dependencies import verify_token
from app.core.logging import logger
from app.services.signal.signal_manager import signal_manager

router = APIRouter()


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


@router.get("/api/stocks/signal/buy", summary="获取买入信号", tags=["买入信号"], dependencies=[Depends(verify_token)])
async def get_buy_signals(
    strategy: Optional[str] = Query(None, description="策略名称（可选）：volume_wave(动量守恒), volume_wave_enhanced(动量守恒增强版)")
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
