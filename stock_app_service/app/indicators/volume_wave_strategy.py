# -*- coding: utf-8 -*-
"""神明御用波动交易策略v2指标实现"""

import pandas as pd
import numpy as np
from typing import List, Dict, Any, Tuple

from app.indicators.base_strategy import BaseStrategy
from app.core.logging import logger

class VolumeWaveStrategy(BaseStrategy):
    """神明御用波动交易策略v2指标"""
    
    # 策略元数据
    STRATEGY_CODE = "volume_wave"
    STRATEGY_NAME = "量能波动"
    STRATEGY_DESCRIPTION = "基于量能波动的短线交易策略，通过检测特定波动模式产生买卖信号"
    
    # 策略参数
    DEFAULT_PARAMS = {
        'angel_period': 2,      # angel EMA周期
        'xsl_length': 18,       # 线性回归长度
        'xsl_multiplier': 20,   # 线性回归倍数
        'devil_period': 36,     # devil EMA周期
        'timeframe_multiplier': 1  # 时间框架倍数
    }
    
    @staticmethod
    def get_first_valid(values: List[float], length: int) -> float:
        """获取最近非NaN值的函数（xrf）"""
        if length < 1:
            return np.nan
        
        for i in range(length):
            if i < len(values) and not pd.isna(values[i]):
                return values[i]
                
        return np.nan
    
    @staticmethod
    def boolean_to_number(b: bool) -> int:
        """布尔值转换为数值（bton）"""
        return 1 if b else 0
    
    @staticmethod
    def xsa(src: List[float], length: int, weight: float) -> List[float]:
        """指数加权移动平均计算（xsa）- 严格按照TradingView算法实现"""
        if len(src) == 0 or length <= 0:
            return []
            
        result = [np.nan] * len(src)
        sum_vals = [0.0] * len(src)
        
        for i in range(len(src)):
            # 计算sum = nz(sum[1]) - nz(src[len]) + src
            if i == 0:
                sum_vals[i] = src[i] if not pd.isna(src[i]) else 0.0
            else:
                prev_sum = sum_vals[i-1] if not pd.isna(sum_vals[i-1]) else 0.0
                old_val = src[i-length] if i >= length and not pd.isna(src[i-length]) else 0.0
                current_val = src[i] if not pd.isna(src[i]) else 0.0
                sum_vals[i] = prev_sum - old_val + current_val
            
            # 计算ma = na(src[len]) ? na : sum / len
            if i >= length - 1:  # 有足够的数据点
                # 检查src[len]位置的值（即当前位置往前len个位置）
                check_index = i - length + 1
                if check_index >= 0 and not pd.isna(src[check_index]):
                    ma = sum_vals[i] / length
                else:
                    ma = np.nan
            else:
                ma = np.nan
            
            # 计算out = na(out[1]) ? ma : (src * wei + out[1] * (len - wei)) / len
            if i == 0:
                result[i] = ma
            else:
                if pd.isna(result[i-1]):
                    result[i] = ma
                else:
                    if not pd.isna(src[i]) and not pd.isna(ma):
                        result[i] = (src[i] * weight + result[i-1] * (length - weight)) / length
                    else:
                        result[i] = result[i-1]
        
        return result
    
    @staticmethod
    def xsl(src: List[float], length: int, timeframe_multiplier: float = 1.0) -> List[float]:
        """线性回归斜率计算（xsl）- 严格按照TradingView算法实现"""
        if len(src) == 0 or length <= 0:
            return []
            
        result = [0.0] * len(src)
        
        for i in range(len(src)):
            try:
                # 计算当前的线性回归值 lrc = ta.linreg(src, len, 0)
                if i >= length - 1:
                    # 获取当前窗口数据
                    window = src[i-length+1:i+1]
                    
                    # 检查窗口数据是否有效
                    if any(pd.isna(val) for val in window):
                        result[i] = 0.0
                        continue
                    
                    # 生成x坐标
                    x = np.arange(length)
                    
                    # 计算线性回归的最后一个值（当前值）
                    coeffs = np.polyfit(x, window, 1)
                    lrc = coeffs[0] * (length - 1) + coeffs[1]  # 线性回归在最后一个点的值
                else:
                    result[i] = 0.0
                    continue
                
                # 计算前一个的线性回归值 lrprev = ta.linreg(src[1], len, 0)
                if i >= length:  # 需要有前一个完整的窗口
                    # 获取前一个窗口数据 src[1] 表示整个序列向前偏移1位
                    prev_window = src[i-length:i]
                    
                    # 检查前一个窗口数据是否有效
                    if any(pd.isna(val) for val in prev_window):
                        lrprev = lrc  # 如果前一个窗口有无效数据，使用当前值
                    else:
                        # 计算前一个线性回归的最后一个值
                        prev_coeffs = np.polyfit(x, prev_window, 1)
                        lrprev = prev_coeffs[0] * (length - 1) + prev_coeffs[1]
                else:
                    lrprev = lrc  # 没有足够的历史数据时，使用当前值
                
                # 计算输出：out := (lrc - lrprev) / timeframe.multiplier
                result[i] = (lrc - lrprev) / timeframe_multiplier
                
            except Exception as e:
                # 出错时设置为0
                result[i] = 0.0
                
        return result
    
    @staticmethod
    def calculate_sma(data: List[float], period: int) -> List[float]:
        """计算简单移动平均"""
        if len(data) == 0 or period <= 0:
            return []
            
        result = []
        
        for i in range(len(data)):
            if i < period - 1:
                result.append(np.nan)
                continue
                
            sum_val = 0.0
            for j in range(period):
                sum_val += data[i - j]
            
            result.append(sum_val / period)
            
        return result
    
    @staticmethod
    def calculate_ema(data: List[float], period: int) -> List[float]:
        """计算指数移动平均"""
        if len(data) == 0 or period <= 0:
            return []
            
        result = [0.0] * len(data)
        
        # 初始化
        if len(data) > 0:
            first_value = data[0] if not (pd.isna(data[0]) or np.isnan(data[0]) or np.isinf(data[0])) else 0.0
            result[0] = first_value
            
        # EMA权重
        k = 2.0 / (period + 1)
        
        # 计算EMA
        for i in range(1, len(data)):
            current_value = data[i] if not (pd.isna(data[i]) or np.isnan(data[i]) or np.isinf(data[i])) else result[i-1]
            ema_value = current_value * k + result[i-1] * (1 - k)
            
            # 确保EMA值有效
            if np.isnan(ema_value) or np.isinf(ema_value):
                result[i] = result[i-1]  # 使用前一个有效值
            else:
                result[i] = ema_value
            
        return result
    
    @staticmethod
    def crossover(a: List[float], b: List[float]) -> List[bool]:
        """判断金叉：a从下方穿过b"""
        if len(a) == 0 or len(b) == 0 or len(a) != len(b):
            return []
            
        result = [False] * len(a)
        
        for i in range(1, len(a)):
            if not pd.isna(a[i-1]) and not pd.isna(b[i-1]) and not pd.isna(a[i]) and not pd.isna(b[i]):
                if a[i-1] <= b[i-1] and a[i] > b[i]:
                    result[i] = True
                
        return result
    
    @staticmethod
    def crossunder(a: List[float], b: List[float]) -> List[bool]:
        """判断死叉：a从上方穿过b"""
        if len(a) == 0 or len(b) == 0 or len(a) != len(b):
            return []
            
        result = [False] * len(a)
        
        for i in range(1, len(a)):
            if not pd.isna(a[i-1]) and not pd.isna(b[i-1]) and not pd.isna(a[i]) and not pd.isna(b[i]):
                if a[i-1] >= b[i-1] and a[i] < b[i]:
                    result[i] = True
                
        return result
    
    @classmethod
    def apply_strategy(cls, df: pd.DataFrame, **kwargs) -> Tuple[pd.DataFrame, List[Dict]]:
        """应用波动交易策略 - 严格按照TradingView原始算法实现"""
        try:
            # 获取并验证参数
            params = cls.validate_params(kwargs)
            
            # 获取收盘价
            close = df['close'].tolist()
            
            # 计算趋势信号
            # angel = ta.ema(close, 2)
            df['angel'] = cls.calculate_ema(close, params['angel_period'])
            
            # 计算EMA6和EMA18用于图表显示
            df['ema6'] = cls.calculate_ema(close, 6)
            df['ema18'] = cls.calculate_ema(close, 18)
            
            # 计算线性回归斜率并构建devil信号
            # devil = ta.ema(xsl(close, 21) * 20 + close, 42)
            xsl_values = cls.xsl(close, params['xsl_length'], params['timeframe_multiplier'])
            
            # 构建调整后的价格序列：xsl(close, 21) * 20 + close
            adjusted_close = []
            for i in range(len(close)):
                if i < len(xsl_values):
                    adjusted_value = xsl_values[i] * params['xsl_multiplier'] + close[i]
                    adjusted_close.append(adjusted_value)
                else:
                    adjusted_close.append(close[i])
            
            # 计算devil的EMA
            df['devil'] = cls.calculate_ema(adjusted_close, params['devil_period'])
            
            # 计算买卖信号
            # long = ta.crossover(angel, devil)
            # short = ta.crossunder(angel, devil)
            df['long'] = cls.crossover(df['angel'].tolist(), df['devil'].tolist())
            df['short'] = cls.crossunder(df['angel'].tolist(), df['devil'].tolist())
            
            # 构建买卖信号列表（移除成交量过滤条件）
            signals = []
            
            for i in range(len(df)):
                if df['long'].iloc[i]:
                    signals.append({
                        'type': 'buy',
                        'index': i,
                        'price': df['close'].iloc[i],
                        'strategy': cls.STRATEGY_CODE
                    })
                elif df['short'].iloc[i]:
                    signals.append({
                        'type': 'sell',
                        'index': i,
                        'price': df['close'].iloc[i],
                        'strategy': cls.STRATEGY_CODE
                    })
            
            return df, signals
        except Exception as e:
            logger.error(f"应用策略计算时出错: {str(e)}")
            return df, []
    
    @classmethod
    def get_strategy_params(cls) -> Dict[str, Any]:
        """获取策略参数配置"""
        return {
            'angel_period': {
                'name': 'Angel EMA周期',
                'description': '天使线EMA计算周期',
                'type': 'int',
                'default': 2,
                'min': 1,
                'max': 100
            },
            'xsl_length': {
                'name': '线性回归长度',
                'description': '线性回归斜率计算的窗口长度',
                'type': 'int',
                'default': 21,
                'min': 5,
                'max': 200
            },
            'xsl_multiplier': {
                'name': '线性回归倍数',
                'description': '线性回归斜率的放大倍数',
                'type': 'float',
                'default': 20.0,
                'min': 1.0,
                'max': 100.0
            },
            'devil_period': {
                'name': 'Devil EMA周期',
                'description': '魔鬼线EMA计算周期',
                'type': 'int',
                'default': 42,
                'min': 5,
                'max': 200
            },
            'timeframe_multiplier': {
                'name': '时间框架倍数',
                'description': 'TradingView时间框架倍数',
                'type': 'float',
                'default': 1.0,
                'min': 0.1,
                'max': 10.0
            }
        }
    
    @classmethod
    def validate_params(cls, params: Dict[str, Any]) -> Dict[str, Any]:
        """验证和标准化参数"""
        validated_params = cls.DEFAULT_PARAMS.copy()
        param_config = cls.get_strategy_params()
        
        for key, value in params.items():
            if key in param_config:
                config = param_config[key]
                
                # 类型转换
                if config['type'] == 'int':
                    try:
                        value = int(value)
                    except (ValueError, TypeError):
                        continue
                elif config['type'] == 'float':
                    try:
                        value = float(value)
                    except (ValueError, TypeError):
                        continue
                
                # 范围验证
                if 'min' in config and value < config['min']:
                    value = config['min']
                if 'max' in config and value > config['max']:
                    value = config['max']
                
                validated_params[key] = value
        
        return validated_params