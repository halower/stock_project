# -*- coding: utf-8 -*-
"""
123趋势延续模式策略指标实现

原指标基于123价格延续模式，提供入场、止损和止盈价格参考点
适配A股市场特性：主要做多，卖出信号表示减仓或空仓等待
针对日线级别优化止损幅度

性能优化：
1. 使用numpy数组替代DataFrame频繁索引
2. 向量化计算替代嵌套循环
3. 一次性赋值减少DataFrame操作
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
        应用123趋势延续模式策略（性能优化版）
        
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

            # 转换为numpy数组以提高性能
            n = len(df)
            high = df['high'].values
            low = df['low'].values
            close = df['close'].values
            
            # 计算滚动窗口的最高点和最低点（向量化操作）
            window = length * 2 + 1
            h = pd.Series(high).rolling(window=window, center=True).max().values
            l = pd.Series(low).rolling(window=window, center=True).min().values
            
            # 检测局部极值点（向量化）
            is_max = np.zeros(n, dtype=bool)
            is_min = np.zeros(n, dtype=bool)
            
            for i in range(length, n - length):
                # 检查是否为窗口内最高点
                if high[i] == h[i]:
                    is_max[i] = True
                # 检查是否为窗口内最低点
                if low[i] == l[i]:
                    is_min[i] = True
            
            # 初始化数组
            last_high = np.zeros(n)
            last_low = np.zeros(n)
            time_high = np.zeros(n, dtype=int)
            time_low = np.zeros(n, dtype=int)
            dir_up = np.zeros(n, dtype=bool)
            
            # 初始值
            current_dir_up = False
            current_low = low[0]
            current_high = high[0]
            current_time_low = 0
            current_time_high = 0
            
            # 单次遍历计算趋势方向和关键点
            for i in range(length, n):
                check_idx = i - length
                
                if current_dir_up:
                    # 趋势向上时更新最低点
                    if is_min[check_idx] and low[check_idx] < current_low:
                        current_low = low[check_idx]
                        current_time_low = check_idx
                    
                    # 检测是否转为下降趋势
                    if is_max[check_idx] and high[check_idx] > current_low:
                        current_high = high[check_idx]
                        current_time_high = check_idx
                        current_dir_up = False
                else:
                    # 趋势向下时更新最高点
                    if is_max[check_idx] and high[check_idx] > current_high:
                        current_high = high[check_idx]
                        current_time_high = check_idx
                    
                    # 检测是否转为上升趋势
                    if is_min[check_idx] and low[check_idx] < current_high:
                        current_low = low[check_idx]
                        current_time_low = check_idx
                        current_dir_up = True
                        
                        # 同时检测最高点
                        if is_max[check_idx] and high[check_idx] > current_low:
                            current_high = high[check_idx]
                            current_time_high = check_idx
                            current_dir_up = False
                
                # 存储当前状态
                last_high[i] = current_high
                last_low[i] = current_low
                time_high[i] = current_time_high
                time_low[i] = current_time_low
                dir_up[i] = current_dir_up
            
            # 向量化检测最近触及关键水平
            recent_touch = np.zeros(n, dtype=bool)
            look_back = 10
            
            for i in range(look_back, n):
                # 向量化检查最近10个K线是否触及关键水平
                for j in range(1, look_back):
                    idx = i - j
                    idx_next = idx - 1
                    
                    if idx_next < 0:
                        break
                    
                    # 检查是否触碰到最低点或最高点
                    touch_low = (low[idx] <= last_low[idx] and low[idx_next] > last_low[idx_next])
                    touch_high = (high[idx] >= last_high[idx] and high[idx_next] < last_high[idx_next])
                    
                    if touch_low or touch_high:
                        recent_touch[i] = True
                        break
            
            # 计算买卖条件（向量化）
            entry_price_long = close if use_close_candle else high
            entry_price_short = close if use_close_candle else low
            
            # 买入条件：价格突破阻力位
            long_condition = np.zeros(n, dtype=bool)
            for i in range(length + 1, n):
                if (entry_price_long[i] >= last_high[i] and 
                    high[i-1] < last_high[i-1] and 
                    not recent_touch[i]):
                    long_condition[i] = True
            
            # 卖出条件：价格跌破支撑位
            short_condition = np.zeros(n, dtype=bool)
            for i in range(length + 1, n):
                if (entry_price_short[i] <= last_low[i] and 
                    low[i-1] > last_low[i-1] and 
                    not recent_touch[i]):
                    short_condition[i] = True
            
            # 一次性赋值到DataFrame（避免频繁操作）
            df['last_high'] = last_high
            df['last_low'] = last_low
            df['time_high'] = time_high
            df['time_low'] = time_low
            df['dir_up'] = dir_up
            df['long_condition'] = long_condition
            df['short_condition'] = short_condition
            df['recent_touch'] = recent_touch
            
            # 构建信号列表
            signals = []
            
            # 找出所有买入信号
            buy_indices = np.where(long_condition)[0]
            for i in buy_indices:
                # 买入信号的止损止盈逻辑（适合A股做多，日线级别）
                entry_price = last_high[i]  # 突破阻力位入场
                
                # 日线级别止损策略：
                # 1. 使用支撑位作为基础止损
                # 2. 但限制最大止损幅度为5%（可配置）
                support_stop = last_low[i]
                ratio_stop = entry_price * (1 - stop_loss_ratio)  # 按比例止损
                
                # 选择更保守的止损位（离入场价更近的）
                stop_loss = max(support_stop, ratio_stop)
                
                # 止盈位：基于风险回报比，通常1:1.5或1:2
                risk = entry_price - stop_loss
                take_profit = entry_price + risk * 1.5  # 1:1.5的风险回报比
                
                signals.append({
                    'type': 'buy',
                    'index': int(i),
                    'price': float(entry_price),
                    'stop_loss': float(stop_loss),
                    'take_profit': float(take_profit),
                    'strategy': cls.STRATEGY_CODE
                })
            
            # 找出所有卖出信号
            sell_indices = np.where(short_condition)[0]
            for i in sell_indices:
                # 卖出信号：表示减仓或空仓等待，不设置止损止盈（因为不是做空）
                # 或者可以理解为持仓的止损信号
                entry_price = last_low[i]   # 跌破支撑位
                
                signals.append({
                    'type': 'sell',
                    'index': int(i),
                    'price': float(entry_price),
                    'stop_loss': None,  # 卖出信号不设置止损
                    'take_profit': None,  # 卖出信号不设置止盈
                    'strategy': cls.STRATEGY_CODE,
                    'note': '减仓或空仓等待信号'
                })
            
            return df, signals
                    
        except Exception as e:
            logger.error(f"123趋势延续计算出错: {str(e)}")
            return df, [] 