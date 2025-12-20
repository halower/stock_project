# -*- coding: utf-8 -*-
"""
Volume Profile, Pivot Anchored 指标
移植自 TradingView Pine Script (tradingview.txt)
原作者: © dgtrd

原理：
- 使用 Pivot High/Low 点作为锚点，在两个 Pivot 点之间计算成交量分布
- 识别 POC（Point of Control）- 成交量最大的价格
- 计算 Value Area - 包含指定百分比成交量的价格区间
"""

import pandas as pd
import numpy as np
from typing import Dict, List, Optional, Tuple
from app.core.logging import logger


def calculate_volume_profile_pivot_anchored(
    df: pd.DataFrame,
    pivot_length: int = 20,
    profile_levels: int = 25,
    value_area_percent: float = 68.0,
    profile_width: float = 0.30
) -> Optional[List[Dict]]:
    """
    计算 Volume Profile Pivot Anchored
    
    在每两个相邻的 Pivot 点之间计算成交量分布
    
    Args:
        df: K线数据，需包含 high, low, open, close, volume, date 列
        pivot_length: Pivot 点检测的左右 K 线数量（默认 20）
        profile_levels: 价格区间数量（默认 25）
        value_area_percent: Value Area 占比（默认 68%）
        profile_width: Profile 宽度占比（默认 30%）
        
    Returns:
        Volume Profile 列表，每个包含：
        {
            'start_time': 起始时间,
            'end_time': 结束时间,
            'start_index': 起始索引,
            'end_index': 结束索引,
            'price_high': 价格区间最高价,
            'price_low': 价格区间最低价,
            'poc_price': POC 价格,
            'vah_price': Value Area High 价格,
            'val_price': Value Area Low 价格,
            'total_volume': 总成交量,
            'profile_data': 各价格级别的成交量数据列表
        }
    """
    try:
        if df is None or len(df) < pivot_length * 2 + 1:
            logger.warning(f"Volume Profile Pivot Anchored: 数据不足")
            return []
        
        df = df.reset_index(drop=True)
        
        # 检测 Pivot High 和 Pivot Low
        pivot_highs = _find_pivot_highs(df, pivot_length, pivot_length)
        pivot_lows = _find_pivot_lows(df, pivot_length, pivot_length)
        
        # 合并所有 Pivot 点并按索引排序
        all_pivots = []
        for idx, price in pivot_highs:
            all_pivots.append({'index': idx, 'price': price, 'type': 'high'})
        for idx, price in pivot_lows:
            all_pivots.append({'index': idx, 'price': price, 'type': 'low'})
        
        all_pivots.sort(key=lambda x: x['index'])
        
        if len(all_pivots) < 2:
            logger.info("Volume Profile Pivot Anchored: Pivot 点不足")
            return []
        
        # 在每两个相邻 Pivot 点之间计算 Volume Profile
        volume_profiles = []
        
        for i in range(len(all_pivots) - 1):
            current_pivot = all_pivots[i]
            next_pivot = all_pivots[i + 1]
            
            # 计算区间（考虑 pivot_length 的偏移）
            start_idx = current_pivot['index'] - pivot_length
            end_idx = next_pivot['index'] - pivot_length
            
            if start_idx < 0 or end_idx >= len(df):
                continue
            
            # 计算该区间的 Volume Profile
            profile = _calculate_profile_for_range(
                df, start_idx, end_idx, profile_levels, value_area_percent, profile_width
            )
            
            if profile:
                volume_profiles.append(profile)
        
        # 计算最后一个 Pivot 点到当前的 Volume Profile（实时更新的部分）
        if len(all_pivots) > 0:
            last_pivot = all_pivots[-1]
            start_idx = last_pivot['index'] - pivot_length
            end_idx = len(df) - 1
            
            if start_idx >= 0 and end_idx - start_idx > 0:
                profile = _calculate_profile_for_range(
                    df, start_idx, end_idx, profile_levels, value_area_percent, profile_width
                )
                if profile:
                    profile['is_developing'] = True  # 标记为实时更新的 Profile
                    volume_profiles.append(profile)
        
        logger.info(f"Volume Profile Pivot Anchored: 计算了 {len(volume_profiles)} 个 Profile")
        return volume_profiles
        
    except Exception as e:
        logger.error(f"计算 Volume Profile Pivot Anchored 失败: {e}")
        import traceback
        logger.error(traceback.format_exc())
        return []


def _find_pivot_highs(df: pd.DataFrame, left: int, right: int) -> List[Tuple[int, float]]:
    """检测 Pivot High 点"""
    pivot_highs = []
    
    for i in range(left, len(df) - right):
        center_high = df.loc[i, 'high']
        is_pivot = True
        
        # 检查左侧
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
    """检测 Pivot Low 点"""
    pivot_lows = []
    
    for i in range(left, len(df) - right):
        center_low = df.loc[i, 'low']
        is_pivot = True
        
        # 检查左侧
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


def _calculate_profile_for_range(
    df: pd.DataFrame,
    start_idx: int,
    end_idx: int,
    profile_levels: int,
    value_area_percent: float,
    profile_width: float
) -> Optional[Dict]:
    """
    为指定区间计算 Volume Profile
    
    Args:
        df: K线数据
        start_idx: 起始索引
        end_idx: 结束索引
        profile_levels: 价格级别数量
        value_area_percent: Value Area 百分比
        profile_width: Profile 宽度
        
    Returns:
        Volume Profile 数据字典
    """
    try:
        if start_idx < 0 or end_idx >= len(df) or start_idx >= end_idx:
            return None
        
        # 提取区间数据
        range_df = df.iloc[start_idx:end_idx + 1].copy()
        
        if len(range_df) == 0:
            return None
        
        # 获取价格范围
        price_high = range_df['high'].max()
        price_low = range_df['low'].min()
        total_volume = range_df['volume'].sum()
        
        if pd.isna(price_high) or pd.isna(price_low) or price_high <= price_low:
            return None
        
        price_step = (price_high - price_low) / profile_levels
        
        if price_step <= 0:
            return None
        
        # 初始化成交量数组
        volume_storage = np.zeros(profile_levels + 1)
        
        # 分配成交量到各个价格级别
        for idx, row in range_df.iterrows():
            bar_high = row['high']
            bar_low = row['low']
            bar_volume = row['volume']
            
            if pd.isna(bar_high) or pd.isna(bar_low) or pd.isna(bar_volume) or bar_volume <= 0:
                continue
            
            # 根据 K 线与各价格级别的交集分配成交量
            for level in range(profile_levels):
                level_low = price_low + level * price_step
                level_high = price_low + (level + 1) * price_step
                
                # K 线与该级别有交集
                if bar_high >= level_low and bar_low < level_high:
                    # 按比例分配成交量
                    if bar_high > bar_low:
                        volume_portion = bar_volume * price_step / (bar_high - bar_low)
                    else:
                        volume_portion = bar_volume
                    
                    volume_storage[level] += volume_portion
        
        # 找到 POC（Point of Control）
        poc_level = np.argmax(volume_storage)
        poc_price = price_low + (poc_level + 0.5) * price_step
        
        # 计算 Value Area
        target_volume = volume_storage.sum() * (value_area_percent / 100)
        value_area_volume = volume_storage[poc_level]
        level_above_poc = poc_level
        level_below_poc = poc_level
        
        # 从 POC 向上下扩展
        while value_area_volume < target_volume and (level_above_poc < profile_levels - 1 or level_below_poc > 0):
            volume_above = volume_storage[level_above_poc + 1] if level_above_poc < profile_levels - 1 else 0
            volume_below = volume_storage[level_below_poc - 1] if level_below_poc > 0 else 0
            
            if volume_above == 0 and volume_below == 0:
                break
            
            if volume_above >= volume_below:
                value_area_volume += volume_above
                level_above_poc += 1
            else:
                value_area_volume += volume_below
                level_below_poc -= 1
        
        vah_price = price_low + (level_above_poc + 1.0) * price_step
        val_price = price_low + level_below_poc * price_step
        
        # 构建 Profile 数据
        max_volume = volume_storage.max()
        profile_data = []
        
        for level in range(profile_levels):
            if max_volume > 0:
                volume_percent = volume_storage[level] / max_volume
            else:
                volume_percent = 0
            
            profile_data.append({
                'level': int(level),
                'price_low': float(price_low + level * price_step),
                'price_high': float(price_low + (level + 1) * price_step),
                'price_mid': float(price_low + (level + 0.5) * price_step),
                'volume': float(volume_storage[level]),
                'volume_percent': float(volume_percent),
                'in_value_area': bool(level_below_poc <= level <= level_above_poc),
                'is_poc': bool(level == poc_level)
            })
        
        # 获取时间
        start_time = _get_time_string(df, start_idx)
        end_time = _get_time_string(df, end_idx)
        
        return {
            'start_time': start_time,
            'end_time': end_time,
            'start_index': int(start_idx),
            'end_index': int(end_idx),
            'price_high': float(price_high),
            'price_low': float(price_low),
            'poc_price': float(poc_price),
            'vah_price': float(vah_price),
            'val_price': float(val_price),
            'total_volume': float(total_volume),
            'profile_levels': int(profile_levels),
            'profile_width': float(profile_width),
            'profile_data': profile_data,
            'is_developing': False
        }
        
    except Exception as e:
        logger.error(f"计算区间 Volume Profile 失败: {e}")
        return None


def _get_time_string(df: pd.DataFrame, idx: int) -> str:
    """获取时间字符串（YYYY-MM-DD 格式）"""
    try:
        if 'date' in df.columns:
            date_value = df.loc[idx, 'date']
        elif 'trade_date' in df.columns:
            date_value = df.loc[idx, 'trade_date']
        else:
            return str(idx)
        
        if hasattr(date_value, 'strftime'):
            return date_value.strftime('%Y-%m-%d')
        else:
            date_str = str(date_value)
            if len(date_str) == 8:  # 20251128 格式
                return f"{date_str[:4]}-{date_str[4:6]}-{date_str[6:8]}"
            return date_str
            
    except Exception as e:
        logger.warning(f"获取时间字符串失败: {e}")
        return str(idx)

