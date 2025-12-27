# -*- coding: utf-8 -*-
"""
多指标背离检测器 (Divergence for Many Indicators)
TradingView移植版本 - 简化实现
检测MACD、RSI等指标与价格之间的背离现象
"""

import pandas as pd
import numpy as np
from typing import List, Dict, Any, Tuple
from app.core.logging import logger
from app.trading.indicators.indicator_registry import register_indicator


@register_indicator(
    id='divergence_detector',
    name='背离检测',
    category='oscillator',
    description='',
    render_type='overlay',
    enabled_by_default=False,
    default_params={'pivot_period': 5, 'max_pivot_points': 10, 'max_bars': 100, 
                    'check_macd': True, 'check_rsi': True, 'check_stoch': True, 
                    'check_cci': True, 'check_momentum': True},
    render_config={'render_function': 'renderDivergence'}
)
def calculate_divergence_detector(
    df: pd.DataFrame,
    pivot_period: int = 5,
    max_pivot_points: int = 10,
    max_bars: int = 100,
    check_macd: bool = True,
    check_rsi: bool = True,
    check_stoch: bool = True,
    check_cci: bool = True,
    check_momentum: bool = True
) -> List[Dict[str, Any]]:
    """
    计算多指标背离
    
    Args:
        df: 包含OHLCV数据的DataFrame
        pivot_period: Pivot点周期
        max_pivot_points: 最大检查的pivot点数量
        max_bars: 最大检查的K线数量
        check_macd: 是否检查MACD背离
        check_rsi: 是否检查RSI背离
        check_stoch: 是否检查Stochastic背离
        check_cci: 是否检查CCI背离
        check_momentum: 是否检查Momentum背离
        
    Returns:
        背离数据列表，每个元素包含背离信息
    """
    try:
        if len(df) < pivot_period * 2 + 50:
            logger.warning(f"数据不足，需要至少 {pivot_period * 2 + 50} 条K线")
            return []
        
        # 计算所有需要的指标
        indicators = {}
        
        if check_macd:
            macd_line, signal_line, histogram = _calculate_macd_full(df)
            indicators['MACD'] = macd_line
            indicators['Hist'] = histogram  # MACD Histogram
        
        if check_rsi:
            indicators['RSI'] = _calculate_rsi(df, 14)
        
        if check_stoch:
            indicators['Stoch'] = _calculate_stochastic(df, 14)
        
        if check_cci:
            indicators['CCI'] = _calculate_cci(df, 10)
        
        if check_momentum:
            indicators['MOM'] = _calculate_momentum(df, 10)
        
        # 添加更多指标
        indicators['OBV'] = _calculate_obv(df)
        indicators['VWMACD'] = _calculate_vwmacd(df)
        indicators['CMF'] = _calculate_cmf(df, 21)
        indicators['MFI'] = _calculate_mfi(df, 14)
        
        # 找到pivot highs和lows
        pivot_highs = _find_pivot_highs(df, pivot_period)
        pivot_lows = _find_pivot_lows(df, pivot_period)
        
        # 检测背离
        divergences = []
        
        for indicator_name, indicator_values in indicators.items():
            # 检测正常背离
            regular_divs = _detect_regular_divergences(
                df, indicator_values, pivot_highs, pivot_lows,
                max_pivot_points, max_bars, indicator_name
            )
            divergences.extend(regular_divs)
            
            # 检测隐藏背离
            hidden_divs = _detect_hidden_divergences(
                df, indicator_values, pivot_highs, pivot_lows,
                max_pivot_points, max_bars, indicator_name
            )
            divergences.extend(hidden_divs)
        
        # 按位置分组背离，用于显示标签
        grouped_divergences = _group_divergences_by_position(divergences, df)
        
        logger.info(f"✅ 检测到 {len(grouped_divergences)} 组背离")
        return grouped_divergences
        
    except Exception as e:
        logger.error(f"计算背离失败: {e}")
        return []


def _calculate_macd_full(df: pd.DataFrame) -> Tuple[pd.Series, pd.Series, pd.Series]:
    """计算完整MACD（包括MACD线、信号线、柱状图）"""
    exp1 = df['close'].ewm(span=12, adjust=False).mean()
    exp2 = df['close'].ewm(span=26, adjust=False).mean()
    macd_line = exp1 - exp2
    signal_line = macd_line.ewm(span=9, adjust=False).mean()
    histogram = macd_line - signal_line
    return macd_line, signal_line, histogram


def _calculate_rsi(df: pd.DataFrame, period: int = 14) -> pd.Series:
    """计算RSI"""
    delta = df['close'].diff()
    gain = (delta.where(delta > 0, 0)).rolling(window=period).mean()
    loss = (-delta.where(delta < 0, 0)).rolling(window=period).mean()
    rs = gain / loss
    rsi = 100 - (100 / (1 + rs))
    return rsi


def _calculate_stochastic(df: pd.DataFrame, period: int = 14) -> pd.Series:
    """计算Stochastic"""
    low_min = df['low'].rolling(window=period).min()
    high_max = df['high'].rolling(window=period).max()
    stoch = 100 * (df['close'] - low_min) / (high_max - low_min)
    stoch_smooth = stoch.rolling(window=3).mean()
    return stoch_smooth


def _calculate_cci(df: pd.DataFrame, period: int = 10) -> pd.Series:
    """计算CCI (Commodity Channel Index)"""
    tp = (df['high'] + df['low'] + df['close']) / 3
    sma_tp = tp.rolling(window=period).mean()
    mad = tp.rolling(window=period).apply(lambda x: np.abs(x - x.mean()).mean())
    cci = (tp - sma_tp) / (0.015 * mad)
    return cci


def _calculate_momentum(df: pd.DataFrame, period: int = 10) -> pd.Series:
    """计算Momentum"""
    momentum = df['close'].diff(period)
    return momentum


def _calculate_obv(df: pd.DataFrame) -> pd.Series:
    """计算OBV (On-Balance Volume)"""
    obv = pd.Series(index=df.index, dtype=float)
    obv.iloc[0] = df['volume'].iloc[0]
    
    for i in range(1, len(df)):
        if df['close'].iloc[i] > df['close'].iloc[i-1]:
            obv.iloc[i] = obv.iloc[i-1] + df['volume'].iloc[i]
        elif df['close'].iloc[i] < df['close'].iloc[i-1]:
            obv.iloc[i] = obv.iloc[i-1] - df['volume'].iloc[i]
        else:
            obv.iloc[i] = obv.iloc[i-1]
    
    return obv


def _calculate_vwmacd(df: pd.DataFrame) -> pd.Series:
    """计算Volume Weighted MACD"""
    vwma_fast = (df['close'] * df['volume']).rolling(window=12).sum() / df['volume'].rolling(window=12).sum()
    vwma_slow = (df['close'] * df['volume']).rolling(window=26).sum() / df['volume'].rolling(window=26).sum()
    vwmacd = vwma_fast - vwma_slow
    return vwmacd


def _calculate_cmf(df: pd.DataFrame, period: int = 21) -> pd.Series:
    """计算Chaikin Money Flow"""
    mf_multiplier = ((df['close'] - df['low']) - (df['high'] - df['close'])) / (df['high'] - df['low'])
    mf_multiplier = mf_multiplier.fillna(0)  # 处理除以零的情况
    mf_volume = mf_multiplier * df['volume']
    cmf = mf_volume.rolling(window=period).sum() / df['volume'].rolling(window=period).sum()
    return cmf


def _calculate_mfi(df: pd.DataFrame, period: int = 14) -> pd.Series:
    """计算Money Flow Index"""
    typical_price = (df['high'] + df['low'] + df['close']) / 3
    money_flow = typical_price * df['volume']
    
    positive_flow = pd.Series(0.0, index=df.index)
    negative_flow = pd.Series(0.0, index=df.index)
    
    for i in range(1, len(df)):
        if typical_price.iloc[i] > typical_price.iloc[i-1]:
            positive_flow.iloc[i] = money_flow.iloc[i]
        elif typical_price.iloc[i] < typical_price.iloc[i-1]:
            negative_flow.iloc[i] = money_flow.iloc[i]
    
    positive_mf = positive_flow.rolling(window=period).sum()
    negative_mf = negative_flow.rolling(window=period).sum()
    
    mfi = 100 - (100 / (1 + positive_mf / negative_mf.replace(0, 1)))
    return mfi


def _find_pivot_highs(df: pd.DataFrame, period: int) -> List[Tuple[int, float]]:
    """找到pivot highs（高点）"""
    pivot_highs = []
    
    for i in range(period, len(df) - period):
        is_pivot = True
        current_high = df['high'].iloc[i]
        
        # 检查左边
        for j in range(1, period + 1):
            if df['high'].iloc[i - j] >= current_high:
                is_pivot = False
                break
        
        if not is_pivot:
            continue
        
        # 检查右边
        for j in range(1, period + 1):
            if df['high'].iloc[i + j] >= current_high:
                is_pivot = False
                break
        
        if is_pivot:
            pivot_highs.append((i, current_high))
    
    return pivot_highs[-20:]  # 保留最近20个


def _find_pivot_lows(df: pd.DataFrame, period: int) -> List[Tuple[int, float]]:
    """找到pivot lows（低点）"""
    pivot_lows = []
    
    for i in range(period, len(df) - period):
        is_pivot = True
        current_low = df['low'].iloc[i]
        
        # 检查左边
        for j in range(1, period + 1):
            if df['low'].iloc[i - j] <= current_low:
                is_pivot = False
                break
        
        if not is_pivot:
            continue
        
        # 检查右边
        for j in range(1, period + 1):
            if df['low'].iloc[i + j] <= current_low:
                is_pivot = False
                break
        
        if is_pivot:
            pivot_lows.append((i, current_low))
    
    return pivot_lows[-20:]  # 保留最近20个


def _detect_regular_divergences(
    df: pd.DataFrame,
    indicator: pd.Series,
    pivot_highs: List[Tuple[int, float]],
    pivot_lows: List[Tuple[int, float]],
    max_pivot_points: int,
    max_bars: int,
    indicator_name: str = ''
) -> List[Dict[str, Any]]:
    """
    检测正常背离
    - 正向背离：价格创新低，指标未创新低（看涨信号）
    - 负向背离：价格创新高，指标未创新高（看跌信号）
    """
    divergences = []
    current_idx = len(df) - 1
    
    # 检测正向背离（在pivot lows）
    if len(pivot_lows) >= 2:
        for i in range(min(max_pivot_points, len(pivot_lows) - 1)):
            pivot_idx1, price1 = pivot_lows[-(i + 1)]
            pivot_idx2, price2 = pivot_lows[-(i + 2)]
            
            if current_idx - pivot_idx1 > max_bars:
                break
            
            # 价格创新低，但指标未创新低
            if price1 < price2 and indicator.iloc[pivot_idx1] > indicator.iloc[pivot_idx2]:
                divergences.append({
                    'type': 'bullish',  # 看涨
                    'color': 'bullish',
                    'start_index': pivot_idx2,
                    'end_index': pivot_idx1,
                    'start_time': df['date'].iloc[pivot_idx2].strftime('%Y-%m-%d') if pd.notna(df['date'].iloc[pivot_idx2]) else '',
                    'end_time': df['date'].iloc[pivot_idx1].strftime('%Y-%m-%d') if pd.notna(df['date'].iloc[pivot_idx1]) else '',
                    'start_price': float(price2),
                    'end_price': float(price1),
                    'indicator_name': indicator_name
                })
                break  # 每个方向只取最近的一个
    
    # 检测负向背离（在pivot highs）
    if len(pivot_highs) >= 2:
        for i in range(min(max_pivot_points, len(pivot_highs) - 1)):
            pivot_idx1, price1 = pivot_highs[-(i + 1)]
            pivot_idx2, price2 = pivot_highs[-(i + 2)]
            
            if current_idx - pivot_idx1 > max_bars:
                break
            
            # 价格创新高，但指标未创新高
            if price1 > price2 and indicator.iloc[pivot_idx1] < indicator.iloc[pivot_idx2]:
                divergences.append({
                    'type': 'bearish',  # 看跌
                    'color': 'bearish',
                    'start_index': pivot_idx2,
                    'end_index': pivot_idx1,
                    'start_time': df['date'].iloc[pivot_idx2].strftime('%Y-%m-%d') if pd.notna(df['date'].iloc[pivot_idx2]) else '',
                    'end_time': df['date'].iloc[pivot_idx1].strftime('%Y-%m-%d') if pd.notna(df['date'].iloc[pivot_idx1]) else '',
                    'start_price': float(price2),
                    'end_price': float(price1),
                    'indicator_name': indicator_name
                })
                break  # 每个方向只取最近的一个
    
    return divergences


def _detect_hidden_divergences(
    df: pd.DataFrame,
    indicator: pd.Series,
    pivot_highs: List[Tuple[int, float]],
    pivot_lows: List[Tuple[int, float]],
    max_pivot_points: int,
    max_bars: int,
    indicator_name: str = ''
) -> List[Dict[str, Any]]:
    """
    检测隐藏背离
    - 正向隐藏背离：价格未创新低，指标创新低（趋势延续）
    - 负向隐藏背离：价格未创新高，指标创新高（趋势延续）
    """
    divergences = []
    current_idx = len(df) - 1
    
    # 检测正向隐藏背离
    if len(pivot_lows) >= 2:
        for i in range(min(max_pivot_points, len(pivot_lows) - 1)):
            pivot_idx1, price1 = pivot_lows[-(i + 1)]
            pivot_idx2, price2 = pivot_lows[-(i + 2)]
            
            if current_idx - pivot_idx1 > max_bars:
                break
            
            # 价格未创新低，但指标创新低
            if price1 > price2 and indicator.iloc[pivot_idx1] < indicator.iloc[pivot_idx2]:
                divergences.append({
                    'type': 'bullish_hidden',
                    'color': 'bullish_hidden',
                    'start_index': pivot_idx2,
                    'end_index': pivot_idx1,
                    'start_time': df['date'].iloc[pivot_idx2].strftime('%Y-%m-%d') if pd.notna(df['date'].iloc[pivot_idx2]) else '',
                    'end_time': df['date'].iloc[pivot_idx1].strftime('%Y-%m-%d') if pd.notna(df['date'].iloc[pivot_idx1]) else '',
                    'start_price': float(price2),
                    'end_price': float(price1),
                    'indicator_name': indicator_name
                })
                break
    
    # 检测负向隐藏背离
    if len(pivot_highs) >= 2:
        for i in range(min(max_pivot_points, len(pivot_highs) - 1)):
            pivot_idx1, price1 = pivot_highs[-(i + 1)]
            pivot_idx2, price2 = pivot_highs[-(i + 2)]
            
            if current_idx - pivot_idx1 > max_bars:
                break
            
            # 价格未创新高，但指标创新高
            if price1 < price2 and indicator.iloc[pivot_idx1] > indicator.iloc[pivot_idx2]:
                divergences.append({
                    'type': 'bearish_hidden',
                    'color': 'bearish_hidden',
                    'start_index': pivot_idx2,
                    'end_index': pivot_idx1,
                    'start_time': df['date'].iloc[pivot_idx2].strftime('%Y-%m-%d') if pd.notna(df['date'].iloc[pivot_idx2]) else '',
                    'end_time': df['date'].iloc[pivot_idx1].strftime('%Y-%m-%d') if pd.notna(df['date'].iloc[pivot_idx1]) else '',
                    'start_price': float(price2),
                    'end_price': float(price1),
                    'indicator_name': indicator_name
                })
                break
    
    return divergences


def _group_divergences_by_position(divergences: List[Dict[str, Any]], df: pd.DataFrame) -> List[Dict[str, Any]]:
    """
    按位置分组背离，合并同一位置的多个背离并生成标签
    """
    if not divergences:
        return []
    
    # 按结束位置分组
    grouped = {}
    for div in divergences:
        key = f"{div['end_index']}_{div['type']}"
        if key not in grouped:
            grouped[key] = {
                'divergences': [],
                'end_index': div['end_index'],
                'end_time': div['end_time'],
                'end_price': div['end_price'],
                'type': div['type'],
                'color': div['color']
            }
        grouped[key]['divergences'].append(div)
    
    # 生成最终数据
    result = []
    for group in grouped.values():
        divs = group['divergences']
        
        # 收集指标名称并转换为简称
        indicator_names = [d['indicator_name'] for d in divs]
        
        # 指标简称映射（与TradingView一致）
        short_names_map = {
            'MACD': 'M',
            'Hist': 'H',
            'RSI': 'R',
            'Stoch': 'S',
            'CCI': 'C',
            'MOM': 'M',
            'OBV': 'O',
            'VWMACD': 'V',
            'CMF': 'C',
            'MFI': 'MFI'
        }
        
        # 转换为简称
        short_names = [short_names_map.get(name, name[0]) for name in indicator_names]
        
        # 生成标签文本（多行显示，每个指标一行）
        label_text = '\n'.join(short_names)
        if len(divs) > 1:
            label_text += f"\n{len(divs)}"  # 最后一行显示数量
        
        result.append({
            'type': group['type'],
            'color': group['color'],
            'start_index': divs[0]['start_index'],
            'end_index': group['end_index'],
            'start_time': divs[0]['start_time'],
            'end_time': group['end_time'],
            'start_price': divs[0]['start_price'],
            'end_price': group['end_price'],
            'indicator_count': len(divs),
            'indicator_names': indicator_names,
            'label_text': label_text,
            'lines': divs  # 保留所有背离线信息
        })
    
    # 日志输出
    if len(result) > 0:
        logger.info(f"✅ 检测到 {len(result)} 组背离")
    
    return result

