# -*- coding: utf-8 -*-
"""
趋势追踪策略 (Trend Following)
基于ATR的动态止损趋势跟踪策略
"""

import pandas as pd
import numpy as np
from typing import List, Dict, Any
from app.core.logging import logger
from app.indicators.base_strategy import BaseStrategy


class VolatilityConservationStrategy(BaseStrategy):
    """
    趋势追踪策略（UT Bot Alerts 移植版）
    
    【核心逻辑 - 内部文档】
    基于ATR（Average True Range）的动态止损趋势追踪策略：
    
    技术原理：
    1. ATR计算：
       - 使用True Range衡量市场波动
       - 周期：默认10根K线
       - 作用：自适应市场波动率
    
    2. 动态止损线（xATRTrailingStop）：
       - nLoss = key_value * ATR
       - 多头止损：max(prev_stop, close - nLoss)
       - 空头止损：min(prev_stop, close + nLoss)
       - 特点：止损线只跟随趋势方向移动，不回撤
    
    3. 信号生成：
       - 买入：价格从下方突破止损线
       - 卖出：价格从上方跌破止损线
       - 使用EMA(close, 1)检测交叉（等同于收盘价）
    
    4. 可选增强：
       - Heikin Ashi蜡烛图：平滑价格噪音
       - 适合波动较大的市场
    
    技术优势：
    - 自适应波动：ATR随市场动态调整
    - 趋势保护：止损线单向跟随，锁定利润
    - 信号清晰：明确的突破买卖点
    - 风险可控：key_value调整止损宽度
    
    参数配置：
    - key_value: 1.0（敏感度，越大止损越宽）
    - atr_period: 10（ATR计算周期）
    - use_heikin_ashi: False（是否使用HA蜡烛图）
    
    适用场景：
    - 趋势明确的市场
    - 中长线持仓
    - 适合追踪大级别趋势
    """
    
    # 策略元数据
    STRATEGY_CODE = "volatility_conservation"
    STRATEGY_NAME = "趋势追踪"
    STRATEGY_DESCRIPTION = ""  # 不向用户展示策略描述
    
    # 策略参数
    DEFAULT_PARAMS = {
        'key_value': 1.0,        # 敏感度参数
        'atr_period': 10,        # ATR周期
        'use_heikin_ashi': False # 是否使用平均K线
    }
    
    @classmethod
    def get_strategy_name(cls) -> str:
        """获取策略名称"""
        return cls.STRATEGY_NAME
    
    @classmethod
    def get_strategy_description(cls) -> str:
        """获取策略描述"""
        return cls.STRATEGY_DESCRIPTION
    
    @classmethod
    def apply_strategy(cls, df: pd.DataFrame, **kwargs) -> tuple:
        """应用策略"""
        params = cls.DEFAULT_PARAMS.copy()
        params.update(kwargs)
        return cls.calculate_signals(df, **params)
    
    @staticmethod
    def calculate_atr(high: np.ndarray, low: np.ndarray, close: np.ndarray, period: int = 10) -> np.ndarray:
        """
        计算ATR (Average True Range)
        
        Args:
            high: 最高价数组
            low: 最低价数组
            close: 收盘价数组
            period: ATR周期
            
        Returns:
            ATR值数组
        """
        # 计算True Range
        tr1 = high - low  # 当日最高价 - 最低价
        tr2 = np.abs(high - np.roll(close, 1))  # 当日最高价 - 昨收盘价
        tr3 = np.abs(low - np.roll(close, 1))   # 当日最低价 - 昨收盘价
        
        # 取三者最大值
        tr = np.maximum(tr1, np.maximum(tr2, tr3))
        tr[0] = tr1[0]  # 第一个值使用当日振幅
        
        # 计算ATR (使用EMA平滑)
        atr = np.zeros_like(tr)
        atr[0] = tr[0]
        
        alpha = 1.0 / period
        for i in range(1, len(tr)):
            atr[i] = alpha * tr[i] + (1 - alpha) * atr[i-1]
        
        return atr
    
    @staticmethod
    def calculate_ema(data: np.ndarray, period: int) -> np.ndarray:
        """
        计算EMA (指数移动平均)
        
        Args:
            data: 数据数组
            period: EMA周期
            
        Returns:
            EMA值数组
        """
        ema = np.zeros_like(data)
        ema[0] = data[0]
        
        alpha = 2.0 / (period + 1)
        for i in range(1, len(data)):
            ema[i] = alpha * data[i] + (1 - alpha) * ema[i-1]
        
        return ema
    
    @staticmethod
    def calculate_signals(
        df: pd.DataFrame,
        key_value: float = 1.0,
        atr_period: int = 10,
        use_heikin_ashi: bool = False
    ) -> tuple:
        """
        计算波动守恒策略信号
        
        Args:
            df: 包含OHLC数据的DataFrame
            key_value: 敏感度参数（默认1.0，越大越不敏感）
            atr_period: ATR周期（默认10）
            use_heikin_ashi: 是否使用平均K线（暂不支持）
            
        Returns:
            (processed_df, signals)
        """
        df = df.copy()
        
        # 提取数据
        high = df['high'].to_numpy()
        low = df['low'].to_numpy()
        close = df['close'].to_numpy()
        
        # 计算ATR
        atr = VolatilityConservationStrategy.calculate_atr(high, low, close, atr_period)
        n_loss = key_value * atr
        
        # 使用收盘价作为源数据
        src = close.copy()
        
        # 计算ATR Trailing Stop
        xATRTrailingStop = np.zeros_like(src)
        xATRTrailingStop[0] = src[0] - n_loss[0]
        
        for i in range(1, len(src)):
            prev_stop = xATRTrailingStop[i-1]
            
            # 上升趋势：止损线上移
            if src[i] > prev_stop and src[i-1] > prev_stop:
                xATRTrailingStop[i] = max(prev_stop, src[i] - n_loss[i])
            # 下降趋势：止损线下移
            elif src[i] < prev_stop and src[i-1] < prev_stop:
                xATRTrailingStop[i] = min(prev_stop, src[i] + n_loss[i])
            # 趋势转换
            elif src[i] > prev_stop:
                xATRTrailingStop[i] = src[i] - n_loss[i]
            else:
                xATRTrailingStop[i] = src[i] + n_loss[i]
        
        # 计算持仓方向
        pos = np.zeros(len(src), dtype=int)
        pos[0] = 0
        
        for i in range(1, len(src)):
            prev_stop = xATRTrailingStop[i-1]
            curr_stop = xATRTrailingStop[i]
            
            # 多头信号：价格从下方突破止损线
            if src[i-1] < prev_stop and src[i] > curr_stop:
                pos[i] = 1
            # 空头信号：价格从上方跌破止损线
            elif src[i-1] > prev_stop and src[i] < curr_stop:
                pos[i] = -1
            else:
                pos[i] = pos[i-1]
        
        # 计算EMA(1) - 实际上就是收盘价本身
        ema = VolatilityConservationStrategy.calculate_ema(src, 1)
        
        # 检测交叉
        above = np.zeros(len(src), dtype=bool)  # EMA上穿止损线
        below = np.zeros(len(src), dtype=bool)  # 止损线上穿EMA
        
        for i in range(1, len(src)):
            above[i] = ema[i-1] <= xATRTrailingStop[i-1] and ema[i] > xATRTrailingStop[i]
            below[i] = ema[i-1] >= xATRTrailingStop[i-1] and ema[i] < xATRTrailingStop[i]
        
        # 生成买卖信号
        buy_signal = (src > xATRTrailingStop) & above
        sell_signal = (src < xATRTrailingStop) & below
        
        # 添加到DataFrame
        df['atr'] = atr
        df['atr_trailing_stop'] = xATRTrailingStop
        df['position'] = pos
        df['buy_signal'] = buy_signal
        df['sell_signal'] = sell_signal
        
        # 计算所有EMA用于图表显示（包括Vegas隧道和移动均线组合）
        df['ema6'] = VolatilityConservationStrategy.calculate_ema(close, 6)
        df['ema12'] = VolatilityConservationStrategy.calculate_ema(close, 12)
        df['ema18'] = VolatilityConservationStrategy.calculate_ema(close, 18)
        df['ema144'] = VolatilityConservationStrategy.calculate_ema(close, 144)
        df['ema169'] = VolatilityConservationStrategy.calculate_ema(close, 169)
        
        # 生成信号列表
        signals = []
        for i in range(len(df)):
            if buy_signal[i]:
                # 获取日期，兼容不同的数据格式
                date_value = df.iloc[i].get('date', df.index[i] if hasattr(df, 'index') else i)
                signals.append({
                    'date': date_value,
                    'type': 'buy',
                    'index': i,  # ✅ 关键：添加index字段用于识别最后一根K线
                    'price': df.iloc[i]['close'],
                    'reason': f'波动守恒买入 (ATR止损: {xATRTrailingStop[i]:.2f})',
                    'strategy': 'volatility_conservation'
                })
            elif sell_signal[i]:
                # 获取日期，兼容不同的数据格式
                date_value = df.iloc[i].get('date', df.index[i] if hasattr(df, 'index') else i)
                signals.append({
                    'date': date_value,
                    'type': 'sell',
                    'index': i,  # ✅ 关键：添加index字段用于识别最后一根K线
                    'price': df.iloc[i]['close'],
                    'reason': f'波动守恒卖出 (ATR止损: {xATRTrailingStop[i]:.2f})',
                    'strategy': 'volatility_conservation'
                })
        
        # 日志级别统一为debug，与其他策略保持一致（不在INFO级别显示详细信号统计）
        logger.debug(f"波动守恒策略: 生成 {len(signals)} 个信号")
        
        return df, signals


def apply_volatility_conservation_strategy(
    df: pd.DataFrame,
    key_value: float = 1.0,
    atr_period: int = 10,
    use_heikin_ashi: bool = False
) -> tuple:
    """
    应用波动守恒策略
    
    Args:
        df: 包含OHLC数据的DataFrame
        key_value: 敏感度参数（默认1.0）
        atr_period: ATR周期（默认10）
        use_heikin_ashi: 是否使用平均K线（暂不支持）
        
    Returns:
        (processed_df, signals)
    """
    return VolatilityConservationStrategy.calculate_signals(
        df, key_value, atr_period, use_heikin_ashi
    )
