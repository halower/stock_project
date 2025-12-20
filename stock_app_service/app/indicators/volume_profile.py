# -*- coding: utf-8 -*-
"""
Volume Profile 指标计算
基于 TradingView 的 Volume Profile / Fixed Range 实现
"""

import numpy as np
import pandas as pd
from typing import Dict, List, Optional
from app.core.logging import logger


def calculate_volume_profile(
    df: pd.DataFrame,
    num_bars: int = 150,
    row_size: int = 24,
    percent: float = 70.0
) -> Optional[Dict]:
    """
    计算 Volume Profile
    
    原理：
    - 将价格范围分成多个区间（row_size个）
    - 统计每个价格区间的成交量（分上涨/下跌）
    - 找出成交量最大的价格（POC）
    - 计算包含指定百分比成交量的区间（Value Area）
    
    Args:
        df: K线数据（需包含 high, low, open, close, volume 列）
        num_bars: 分析的K线数量（默认150根）
        row_size: 价格区间数量（默认24个）
        percent: Value Area 占比（默认70%）
        
    Returns:
        {
            'poc_price': POC价格（成交量最大的价格）,
            'value_area_high': Value Area 上界,
            'value_area_low': Value Area 下界,
            'profile': 各价格区间的成交量分布列表
        }
        如果计算失败返回 None
    """
    try:
        # 取最近 num_bars 根K线
        data = df.tail(num_bars).copy()
        
        if len(data) == 0:
            logger.warning("Volume Profile: 数据为空")
            return None
        
        # 计算价格范围
        high_max = data['high'].max()
        low_min = data['low'].min()
        
        if pd.isna(high_max) or pd.isna(low_min) or high_max <= low_min:
            logger.warning("Volume Profile: 价格范围无效")
            return None
        
        # 计算每个价格区间的步长
        step = (high_max - low_min) / row_size
        if step <= 0:
            logger.warning("Volume Profile: 价格步长无效")
            return None
        
        # 构建价格区间边界
        levels = [low_min + step * i for i in range(row_size + 1)]
        
        # 初始化成交量数组
        volumes_up = np.zeros(row_size)    # 上涨K线的成交量
        volumes_down = np.zeros(row_size)  # 下跌K线的成交量
        
        # 遍历每根K线，分配成交量到各价格区间
        for idx, row in data.iterrows():
            high = row['high']
            low = row['low']
            open_price = row['open']
            close = row['close']
            volume = row['volume']
            
            # 跳过无效数据
            if pd.isna(high) or pd.isna(low) or pd.isna(volume) or volume <= 0:
                continue
            
            if pd.isna(open_price) or pd.isna(close):
                continue
            
            # 判断是上涨还是下跌K线
            is_green = close >= open_price
            
            # 计算K线实体和影线的成交量分配
            body_top = max(close, open_price)
            body_bot = min(close, open_price)
            
            topwick = high - body_top      # 上影线长度
            bottomwick = body_bot - low    # 下影线长度
            body = body_top - body_bot     # 实体长度
            
            # 总长度（用于按比例分配成交量）
            total_length = 2 * topwick + 2 * bottomwick + body
            
            if total_length <= 0:
                # 如果是一字线，将成交量分配到该价格区间
                total_length = 1
                body = 1
            
            # 计算各部分的成交量
            # 实体成交量权重更大（不乘2），影线成交量权重小（乘2表示分散）
            if body > 0:
                bodyvol = body * volume / total_length
            else:
                bodyvol = 0
            
            if topwick > 0:
                topwickvol = 2 * topwick * volume / total_length
            else:
                topwickvol = 0
            
            if bottomwick > 0:
                bottomwickvol = 2 * bottomwick * volume / total_length
            else:
                bottomwickvol = 0
            
            # 将成交量分配到各价格区间
            for i in range(row_size):
                level_low = levels[i]
                level_high = levels[i + 1]
                
                # 计算实体与价格区间的交集
                if body > 0:
                    body_vol_in_level = _get_volume_intersection(
                        level_low, level_high, body_bot, body_top, body, bodyvol
                    )
                    if is_green:
                        volumes_up[i] += body_vol_in_level
                    else:
                        volumes_down[i] += body_vol_in_level
                
                # 计算上影线与价格区间的交集（上涨下跌都算一半）
                if topwick > 0:
                    topwick_vol_in_level = _get_volume_intersection(
                        level_low, level_high, body_top, high, topwick, topwickvol
                    )
                    volumes_up[i] += topwick_vol_in_level / 2
                    volumes_down[i] += topwick_vol_in_level / 2
                
                # 计算下影线与价格区间的交集（上涨下跌都算一半）
                if bottomwick > 0:
                    bottomwick_vol_in_level = _get_volume_intersection(
                        level_low, level_high, low, body_bot, bottomwick, bottomwickvol
                    )
                    volumes_up[i] += bottomwick_vol_in_level / 2
                    volumes_down[i] += bottomwick_vol_in_level / 2
        
        # 计算总成交量
        total_volumes = volumes_up + volumes_down
        
        # 找到 POC（Point of Control）- 成交量最大的价格区间
        poc_index = np.argmax(total_volumes)
        poc_price = (levels[poc_index] + levels[poc_index + 1]) / 2
        
        # 计算 Value Area（包含指定百分比成交量的区间）
        target_volume = total_volumes.sum() * (percent / 100)
        va_volume = total_volumes[poc_index]
        up_idx = poc_index
        down_idx = poc_index
        
        # 从 POC 向上下扩展，直到累计成交量达到目标
        while va_volume < target_volume and (up_idx < row_size - 1 or down_idx > 0):
            # 获取上方和下方的成交量
            upper_vol = total_volumes[up_idx + 1] if up_idx < row_size - 1 else 0
            lower_vol = total_volumes[down_idx - 1] if down_idx > 0 else 0
            
            if upper_vol == 0 and lower_vol == 0:
                break
            
            # 选择成交量更大的方向扩展
            if upper_vol >= lower_vol:
                up_idx += 1
                va_volume += upper_vol
            else:
                down_idx -= 1
                va_volume += lower_vol
        
        # Value Area 的上下界
        value_area_high = levels[up_idx + 1] if up_idx < row_size else levels[row_size]
        value_area_low = levels[down_idx]
        
        # 构建成交量分布数据（供未来扩展使用）
        profile = []
        max_volume = total_volumes.max() if len(total_volumes) > 0 else 1
        
        for i in range(row_size):
            profile.append({
                'price_low': float(levels[i]),
                'price_high': float(levels[i + 1]),
                'price_mid': float((levels[i] + levels[i + 1]) / 2),
                'volume_up': float(volumes_up[i]),
                'volume_down': float(volumes_down[i]),
                'total_volume': float(total_volumes[i]),
                'volume_percent': float(total_volumes[i] / max_volume * 100) if max_volume > 0 else 0,
                'in_value_area': bool(down_idx <= i <= up_idx)
            })
        
        result = {
            'poc_price': float(poc_price),
            'value_area_high': float(value_area_high),
            'value_area_low': float(value_area_low),
            'profile': profile,
            'num_bars': int(num_bars),
            'row_size': int(row_size)
        }
        
        logger.info(f"Volume Profile 计算成功: POC={poc_price:.2f}, VA=[{value_area_low:.2f}, {value_area_high:.2f}]")
        return result
        
    except Exception as e:
        logger.error(f"计算 Volume Profile 时出错: {str(e)}")
        import traceback
        logger.error(traceback.format_exc())
        return None


def _get_volume_intersection(
    level_low: float,
    level_high: float,
    price_low: float,
    price_high: float,
    price_range: float,
    volume: float
) -> float:
    """
    计算价格区间与K线部分的交集，并按比例分配成交量
    
    Args:
        level_low: 价格区间下界
        level_high: 价格区间上界
        price_low: K线部分（实体/影线）的下界
        price_high: K线部分的上界
        price_range: K线部分的高度
        volume: K线部分的总成交量
        
    Returns:
        交集部分分配的成交量
    """
    if price_range <= 0 or volume <= 0:
        return 0.0
    
    # 计算交集
    intersection_low = max(price_low, level_low)
    intersection_high = min(price_high, level_high)
    
    if intersection_high <= intersection_low:
        return 0.0
    
    # 交集的高度
    intersection_height = intersection_high - intersection_low
    
    # 按比例分配成交量
    ratio = intersection_height / price_range
    return volume * ratio


