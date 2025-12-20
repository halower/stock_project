# -*- coding: utf-8 -*-
"""
Pivot Order Blocks 指标
移植自 TradingView Pine Script (tradingview.txt)
原作者: © dgtrd
"""

import pandas as pd
import numpy as np
from typing import List, Dict, Optional, Tuple
from app.core.logging import logger


def calculate_pivot_order_blocks(
    df: pd.DataFrame,
    left: int = 15,
    right: int = 8,
    box_count: int = 2,
    percentage_change: float = 6.0,
    box_extend_to_end: bool = True
) -> Optional[List[Dict]]:
    """
    计算 Pivot Order Blocks
    
    移植自 TradingView 的 Pivot Order Blocks 指标
    原理：识别关键的支撑/阻力区域（订单块）
    
    基于Pivot High/Low点，识别价格反转后形成的订单块区域。
    这些区域通常是机构订单集中的地方，具有支撑/阻力作用。
    
    Args:
        df: K线数据，需包含 high, low, close, open 列
        left: 左侧K线数量（用于pivot点检测）
        right: 右侧K线数量（用于pivot点检测）
        box_count: 最大显示的订单块数量
        percentage_change: 右侧价格变化百分比阈值（用于过滤弱订单块）
        box_extend_to_end: 订单块是否延伸到最新K线
        
    Returns:
        订单块列表，每个订单块包含：
        {
            'type': 'support' | 'resistance',  # 支撑或阻力
            'price_high': float,                # 订单块上界
            'price_low': float,                 # 订单块下界
            'start_index': int,                 # 开始K线索引
            'end_index': int,                   # 结束K线索引
            'pivot_price': float,               # Pivot点价格
            'strength': float                   # 强度（0-1）
        }
        如果计算失败返回 None
    """
    try:
        if df is None or len(df) < left + right + 1:
            logger.warning(f"Pivot Order Blocks: 数据不足，需要至少 {left + right + 1} 根K线")
            return None
        
        # 确保数据有索引
        df = df.reset_index(drop=True)
        
        # 检测Pivot High和Pivot Low
        pivot_highs = _find_pivot_highs(df, left, right)
        pivot_lows = _find_pivot_lows(df, left, right)
        
        # 合并pivot点并按索引排序
        all_pivots = []
        for idx, price in pivot_highs:
            all_pivots.append({
                'index': idx,
                'price': price,
                'type': 'high'
            })
        for idx, price in pivot_lows:
            all_pivots.append({
                'index': idx,
                'price': price,
                'type': 'low'
            })
        
        all_pivots.sort(key=lambda x: x['index'])
        
        if len(all_pivots) < 2:
            logger.info("Pivot Order Blocks: pivot点不足，无法生成订单块")
            return []
        
        # 生成订单块
        order_blocks = []
        
        for i in range(len(all_pivots) - 1):
            current_pivot = all_pivots[i]
            next_pivot = all_pivots[i + 1]
            
            # 只在pivot类型变化时生成订单块
            if current_pivot['type'] == next_pivot['type']:
                continue
            
            pivot_idx = current_pivot['index']
            pivot_price = current_pivot['price']
            pivot_type = current_pivot['type']
            
            # 检查右侧价格变化是否足够大
            if not _check_price_change(df, pivot_idx, next_pivot['index'], percentage_change):
                continue
            
            # 确定订单块的范围
            if pivot_type == 'high':
                # Pivot High -> 阻力订单块
                # 找到pivot点前的最后一根阳线或pivot点K线
                block_high, block_low = _find_resistance_block(df, pivot_idx)
                ob_type = 'resistance'
            else:
                # Pivot Low -> 支撑订单块
                # 找到pivot点前的最后一根阴线或pivot点K线
                block_high, block_low = _find_support_block(df, pivot_idx)
                ob_type = 'support'
            
            # 计算订单块强度（基于价格变化幅度）
            price_change = abs(next_pivot['price'] - pivot_price) / pivot_price * 100
            strength = min(price_change / 10.0, 1.0)  # 10%变化 = 100%强度
            
            # 确定订单块的结束索引
            end_idx = len(df) - 1 if box_extend_to_end else next_pivot['index']
            
            order_blocks.append({
                'type': ob_type,
                'price_high': float(block_high),
                'price_low': float(block_low),
                'start_index': int(pivot_idx),
                'end_index': int(end_idx),
                'pivot_price': float(pivot_price),
                'strength': float(strength)
            })
        
        # 按强度排序，只保留最强的box_count个
        order_blocks.sort(key=lambda x: x['strength'], reverse=True)
        order_blocks = order_blocks[:box_count]
        
        # 按开始索引重新排序
        order_blocks.sort(key=lambda x: x['start_index'])
        
        logger.info(f"Pivot Order Blocks 计算成功: 生成 {len(order_blocks)} 个订单块")
        return order_blocks
        
    except Exception as e:
        logger.error(f"计算 Pivot Order Blocks 失败: {e}")
        import traceback
        logger.error(traceback.format_exc())
        return None


def _find_pivot_highs(df: pd.DataFrame, left: int, right: int) -> List[Tuple[int, float]]:
    """
    检测Pivot High点
    
    Pivot High: 中心K线的最高价高于左右各left/right根K线的最高价
    """
    pivot_highs = []
    
    for i in range(left, len(df) - right):
        center_high = df.loc[i, 'high']
        
        # 检查左侧
        is_pivot = True
        for j in range(i - left, i):
            if df.loc[j, 'high'] >= center_high:
                is_pivot = False
                break
        
        if not is_pivot:
            continue
        
        # 检查右侧
        for j in range(i + 1, i + right + 1):
            if df.loc[j, 'high'] >= center_high:
                is_pivot = False
                break
        
        if is_pivot:
            pivot_highs.append((i, center_high))
    
    return pivot_highs


def _find_pivot_lows(df: pd.DataFrame, left: int, right: int) -> List[Tuple[int, float]]:
    """
    检测Pivot Low点
    
    Pivot Low: 中心K线的最低价低于左右各left/right根K线的最低价
    """
    pivot_lows = []
    
    for i in range(left, len(df) - right):
        center_low = df.loc[i, 'low']
        
        # 检查左侧
        is_pivot = True
        for j in range(i - left, i):
            if df.loc[j, 'low'] <= center_low:
                is_pivot = False
                break
        
        if not is_pivot:
            continue
        
        # 检查右侧
        for j in range(i + 1, i + right + 1):
            if df.loc[j, 'low'] <= center_low:
                is_pivot = False
                break
        
        if is_pivot:
            pivot_lows.append((i, center_low))
    
    return pivot_lows


def _check_price_change(df: pd.DataFrame, start_idx: int, end_idx: int, threshold: float) -> bool:
    """
    检查从start_idx到end_idx的价格变化是否超过阈值
    """
    if start_idx >= len(df) or end_idx >= len(df):
        return False
    
    start_price = df.loc[start_idx, 'close']
    end_price = df.loc[end_idx, 'close']
    
    if start_price == 0:
        return False
    
    price_change_pct = abs(end_price - start_price) / start_price * 100
    return price_change_pct >= threshold


def _find_resistance_block(df: pd.DataFrame, pivot_idx: int) -> Tuple[float, float]:
    """
    找到阻力订单块的范围
    
    在Pivot High之前，找到最后一根阳线（或pivot点K线本身）
    订单块 = 该K线的实体范围
    """
    if pivot_idx >= len(df):
        return df.loc[pivot_idx - 1, 'high'], df.loc[pivot_idx - 1, 'low']
    
    # 从pivot点向前查找最后一根阳线
    for i in range(pivot_idx, max(0, pivot_idx - 10), -1):
        if i >= len(df):
            continue
        
        open_price = df.loc[i, 'open']
        close_price = df.loc[i, 'close']
        
        if close_price >= open_price:  # 阳线
            # 订单块 = 实体部分
            block_high = max(open_price, close_price)
            block_low = min(open_price, close_price)
            return block_high, block_low
    
    # 如果没找到阳线，使用pivot点K线
    return df.loc[pivot_idx, 'high'], df.loc[pivot_idx, 'low']


def _find_support_block(df: pd.DataFrame, pivot_idx: int) -> Tuple[float, float]:
    """
    找到支撑订单块的范围
    
    在Pivot Low之前，找到最后一根阴线（或pivot点K线本身）
    订单块 = 该K线的实体范围
    """
    if pivot_idx >= len(df):
        return df.loc[pivot_idx - 1, 'high'], df.loc[pivot_idx - 1, 'low']
    
    # 从pivot点向前查找最后一根阴线
    for i in range(pivot_idx, max(0, pivot_idx - 10), -1):
        if i >= len(df):
            continue
        
        open_price = df.loc[i, 'open']
        close_price = df.loc[i, 'close']
        
        if close_price < open_price:  # 阴线
            # 订单块 = 实体部分
            block_high = max(open_price, close_price)
            block_low = min(open_price, close_price)
            return block_high, block_low
    
    # 如果没找到阴线，使用pivot点K线
    return df.loc[pivot_idx, 'high'], df.loc[pivot_idx, 'low']

