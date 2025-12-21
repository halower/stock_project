# -*- coding: utf-8 -*-
"""
K线镜像翻转指标
将K线走势进行镜像反转，涨跌完全相反，用于观察不同视角的市场结构
"""

import pandas as pd
import numpy as np
from typing import List, Dict
from app.core.logging import logger


def calculate_mirror_candle(df: pd.DataFrame) -> List[Dict]:
    """
    计算K线镜像翻转数据
    
    算法逻辑（来自TradingView）：
    1. 使用第一根K线的收盘价作为起点
    2. 计算每根K线相对于前一根的涨跌幅
    3. 将涨跌幅取反应用到镜像价格
    4. 高低互换：镜像的高点用原始的低点百分比计算，反之亦然
    
    Args:
        df: 包含OHLC数据的DataFrame
        
    Returns:
        镜像K线数据列表 [{'time': timestamp, 'open': float, 'high': float, 'low': float, 'close': float}, ...]
    """
    try:
        if df is None or len(df) == 0:
            logger.warning("镜像翻转: 输入数据为空")
            return []
        
        # 确保有必要的列（日期列可能是date或trade_date或日期）
        required_cols = ['open', 'high', 'low', 'close']
        if not all(col in df.columns for col in required_cols):
            logger.error(f"镜像翻转: 缺少必要的列，当前列: {df.columns.tolist()}, 需要: {required_cols}")
            return []
        
        # 检查日期列
        date_col = None
        if 'date' in df.columns:
            date_col = 'date'
        elif 'trade_date' in df.columns:
            date_col = 'trade_date'
        elif '日期' in df.columns:
            date_col = '日期'
        else:
            logger.error(f"镜像翻转: 未找到日期列，当前列: {df.columns.tolist()}")
            return []
        
        # 创建副本避免修改原数据
        data = df.copy()
        
        # 使用第一根K线的收盘价作为起点
        start_price = float(data.iloc[0]['close'])
        
        # 初始化镜像价格序列
        inverted_prices = np.zeros(len(data))
        inverted_prices[0] = start_price
        
        # 初始化镜像OHLC
        inverted_open = np.zeros(len(data))
        inverted_high = np.zeros(len(data))
        inverted_low = np.zeros(len(data))
        inverted_close = np.zeros(len(data))
        
        # 第一根K线保持原样
        inverted_open[0] = start_price
        inverted_high[0] = float(data.iloc[0]['high'])
        inverted_low[0] = float(data.iloc[0]['low'])
        inverted_close[0] = start_price
        
        # 逐根计算镜像K线
        for i in range(1, len(data)):
            prev_close = float(data.iloc[i-1]['close'])
            curr_open = float(data.iloc[i]['open'])
            curr_high = float(data.iloc[i]['high'])
            curr_low = float(data.iloc[i]['low'])
            curr_close = float(data.iloc[i]['close'])
            
            # 避免除零错误
            if prev_close == 0:
                logger.warning(f"镜像翻转: 第{i-1}根K线收盘价为0，跳过")
                inverted_prices[i] = inverted_prices[i-1]
                inverted_open[i] = inverted_prices[i-1]
                inverted_high[i] = inverted_prices[i-1]
                inverted_low[i] = inverted_prices[i-1]
                inverted_close[i] = inverted_prices[i-1]
                continue
            
            # 计算当前K线相对于前一根的涨跌幅
            pct_change = (curr_close - prev_close) / prev_close
            
            # 翻转后的收盘价：涨跌幅取反
            inverted_prices[i] = inverted_prices[i-1] * (1 - pct_change)
            inverted_close[i] = inverted_prices[i]
            
            # 计算开盘、高、低相对于前一根收盘的百分比变化
            open_pct = (curr_open - prev_close) / prev_close
            high_pct = (curr_high - prev_close) / prev_close
            low_pct = (curr_low - prev_close) / prev_close
            
            # 镜像的开盘价
            inverted_open[i] = inverted_prices[i-1] * (1 - open_pct)
            
            # 高低互换：原K线的高点对应镜像的低点，原K线的低点对应镜像的高点
            inverted_high[i] = inverted_prices[i-1] * (1 - low_pct)  # 高低互换
            inverted_low[i] = inverted_prices[i-1] * (1 - high_pct)   # 高低互换
        
        # 转换为LightweightCharts所需的格式
        mirror_data = []
        for i in range(len(data)):
            # 转换日期格式
            date_value = data.iloc[i][date_col]
            
            # 处理不同的日期格式
            if hasattr(date_value, 'strftime'):
                # datetime对象
                time_str = date_value.strftime('%Y-%m-%d')
            else:
                # 字符串格式
                date_str = str(date_value)
                if len(date_str) == 8:  # YYYYMMDD
                    time_str = f"{date_str[:4]}-{date_str[4:6]}-{date_str[6:8]}"
                else:
                    time_str = date_str
            
            mirror_data.append({
                'time': time_str,
                'open': round(float(inverted_open[i]), 2),
                'high': round(float(inverted_high[i]), 2),
                'low': round(float(inverted_low[i]), 2),
                'close': round(float(inverted_close[i]), 2)
            })
        
        logger.info(f"镜像翻转计算完成: {len(mirror_data)} 根K线")
        return mirror_data
        
    except Exception as e:
        logger.error(f"镜像翻转计算失败: {str(e)}", exc_info=True)
        return []

