# -*- coding: utf-8 -*-
"""
123趋势延续模式策略指标实现

原指标基于123价格延续模式，提供入场、止损和止盈价格参考点
适配A股市场特性：主要做多，卖出信号表示减仓或空仓等待
针对日线级别优化止损幅度
"""

import pandas as pd
import numpy as np
from typing import List, Dict, Any, Tuple

from app.indicators.base_strategy import BaseStrategy
from app.core.logging import logger

class TrendContinuationStrategy(BaseStrategy):
    """123趋势延续模式策略"""
    
    # 策略元数据
    STRATEGY_CODE = "trend_continuation"
    STRATEGY_NAME = "趋势延续"
    STRATEGY_DESCRIPTION = "基于123价格形态的趋势延续，适配A股做多特性，买入信号表示建仓机会，卖出信号表示减仓或空仓等待"
    
    @classmethod
    def apply_strategy(cls, df: pd.DataFrame, 
                       tp_multiplier: float = 0.5, 
                       length: int = 5,
                       trade_type: str = "Long", 
                       use_close_candle: bool = False,
                       stop_loss_ratio: float = 0.05) -> Tuple[pd.DataFrame, List[Dict]]:
        """
        应用123趋势延续模式策略
        
        Args:
            df: 包含OHLCV数据的DataFrame
            tp_multiplier: 止盈乘数(应用于第一点和第二点之间的距离)
            length: 高点/低点检测长度 (类似于之字形指标中的范围)
            trade_type: 显示的交易类型，默认为"Long"适应A股做多特性
            use_close_candle: 是否使用收盘价作为入场价格
            stop_loss_ratio: 止损比例，默认5%，适合日线级别
            
        Returns:
            带有指标和信号的DataFrame及信号列表
        """
        try:
            # 确保数据足够
            if len(df) < length * 2 + 1:
                return df, []

            # 计算周期内的最高点和最低点
            def rolling_highest(series, window):
                return series.rolling(window=window).max()
            
            def rolling_lowest(series, window):
                return series.rolling(window=window).min()
            
            h = rolling_highest(df['high'], length * 2 + 1)
            l = rolling_lowest(df['low'], length * 2 + 1)
            
            # 检测是否为局部最高点或最低点
            def is_max(i, window):
                if i < window:
                    return False
                return df['high'].iloc[i] == h.iloc[i]
                
            def is_min(i, window):
                if i < window:
                    return False
                return df['low'].iloc[i] == l.iloc[i]
            
            # 初始化方向和关键点
            dir_up = False
            last_low = df['low'].iloc[0] if len(df) > 0 else 0
            last_high = df['high'].iloc[0] if len(df) > 0 else 0
            time_low = 0
            time_high = 0
            
            # 存储每个K线的最高点和最低点
            df['last_high'] = np.nan
            df['last_low'] = np.nan
            df['time_high'] = np.nan
            df['time_low'] = np.nan
            df['dir_up'] = False
            
            # 迭代计算趋势方向和关键点
            for i in range(length, len(df)):
                is_min_point = is_min(i-length, length)
                is_max_point = is_max(i-length, length)
                
                if dir_up:
                    if is_min_point and df['low'].iloc[i-length] < last_low:
                        last_low = df['low'].iloc[i-length]
                        time_low = i-length
                    
                    if is_max_point and df['high'].iloc[i-length] > last_low:
                        last_high = df['high'].iloc[i-length]
                        time_high = i-length
                        dir_up = False
                else:
                    if is_max_point and df['high'].iloc[i-length] > last_high:
                        last_high = df['high'].iloc[i-length]
                        time_high = i-length
                    
                    if is_min_point and df['low'].iloc[i-length] < last_high:
                        last_low = df['low'].iloc[i-length]
                        time_low = i-length
                        dir_up = True
                        
                        if is_max_point and df['high'].iloc[i-length] > last_low:
                            last_high = df['high'].iloc[i-length]
                            time_high = i-length
                            dir_up = False
                
                # 记录当前状态
                df.loc[df.index[i], 'last_high'] = last_high
                df.loc[df.index[i], 'last_low'] = last_low
                df.loc[df.index[i], 'time_high'] = time_high
                df.loc[df.index[i], 'time_low'] = time_low
                df.loc[df.index[i], 'dir_up'] = dir_up
            
            # 检测是否最近触及关键水平
            def check_recent_touch(i):
                if i < 10:
                    return False
                    
                for j in range(1, 10):
                    idx = i - j
                    idx_next = i - j - 1
                    if idx < 0 or idx_next < 0:
                        continue
                        
                    # 检查是否触碰到最低点或最高点
                    if ((df['low'].iloc[idx] <= df['last_low'].iloc[idx] and 
                         df['low'].iloc[idx_next] > df['last_low'].iloc[idx_next]) or 
                        (df['high'].iloc[idx] >= df['last_high'].iloc[idx] and 
                         df['high'].iloc[idx_next] < df['last_high'].iloc[idx_next])):
                        return True
                return False
            
            # 计算交易信号
            df['long_condition'] = False
            df['short_condition'] = False
            df['recent_touch'] = False
            
            for i in range(length, len(df)):
                if i <= 0:
                    continue
                
                # 检查是否最近触及关键水平
                df.loc[df.index[i], 'recent_touch'] = check_recent_touch(i)
                
                # 买入信号：价格突破阻力位（last_high）
                entry_price = df['close'].iloc[i] if use_close_candle else df['high'].iloc[i]
                if (entry_price >= df['last_high'].iloc[i] and 
                    df['high'].iloc[i-1] < df['last_high'].iloc[i-1] and 
                    not df['recent_touch'].iloc[i]):
                    df.loc[df.index[i], 'long_condition'] = True
                
                # 卖出信号：价格跌破支撑位（last_low），表示减仓或空仓等待
                entry_price = df['close'].iloc[i] if use_close_candle else df['low'].iloc[i]
                if (entry_price <= df['last_low'].iloc[i] and 
                    df['low'].iloc[i-1] > df['last_low'].iloc[i-1] and 
                    not df['recent_touch'].iloc[i]):
                    df.loc[df.index[i], 'short_condition'] = True
            
            # 构建信号列表
            signals = []
            
            for i in range(length, len(df)):
                if df['long_condition'].iloc[i]:
                    # 买入信号的止损止盈逻辑（适合A股做多，日线级别）
                    entry_price = df['last_high'].iloc[i]  # 突破阻力位入场
                    
                    # 日线级别止损策略：
                    # 1. 使用支撑位作为基础止损
                    # 2. 但限制最大止损幅度为5%（可配置）
                    support_stop = df['last_low'].iloc[i]
                    ratio_stop = entry_price * (1 - stop_loss_ratio)  # 按比例止损
                    
                    # 选择更保守的止损位（离入场价更近的）
                    stop_loss = max(support_stop, ratio_stop)
                    
                    # 止盈位：基于风险回报比，通常1:1.5或1:2
                    risk = entry_price - stop_loss
                    take_profit = entry_price + risk * 1.5  # 1:1.5的风险回报比
                    
                    signals.append({
                        'type': 'buy',
                        'index': i,
                        'price': entry_price,
                        'stop_loss': stop_loss,
                        'take_profit': take_profit,
                        'strategy': cls.STRATEGY_CODE
                    })
                    
                elif df['short_condition'].iloc[i]:
                    # 卖出信号：表示减仓或空仓等待，不设置止损止盈（因为不是做空）
                    # 或者可以理解为持仓的止损信号
                    entry_price = df['last_low'].iloc[i]   # 跌破支撑位
                    
                    signals.append({
                        'type': 'sell',
                        'index': i,
                        'price': entry_price,
                        'stop_loss': None,  # 卖出信号不设置止损
                        'take_profit': None,  # 卖出信号不设置止盈
                        'strategy': cls.STRATEGY_CODE,
                        'note': '减仓或空仓等待信号'
                    })
            
            return df, signals
                    
        except Exception as e:
            logger.error(f"123趋势延续计算出错: {str(e)}")
            return df, [] 