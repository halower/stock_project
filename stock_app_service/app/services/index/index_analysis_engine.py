# -*- coding: utf-8 -*-
"""
指数分析引擎 - 专业的技术分析和预测算法
"""

import pandas as pd
import numpy as np
from typing import Dict, Any, List, Tuple
from app.core.logging import logger


class IndexAnalysisEngine:
    """指数分析引擎 - 提供专业的技术分析"""
    
    @staticmethod
    def calculate_support_resistance(df: pd.DataFrame, periods: int = 20) -> Dict[str, Any]:
        """
        计算支撑位和压力位（基于斐波那契回撤和关键价格）
        
        Args:
            df: 包含OHLC数据的DataFrame
            periods: 计算周期
            
        Returns:
            支撑位和压力位信息
        """
        try:
            recent_df = df.tail(periods)
            current_price = float(df.iloc[-1]['close'])
            
            # 计算周期内的最高价和最低价
            period_high = float(recent_df['high'].max())
            period_low = float(recent_df['low'].min())
            
            # 斐波那契回撤位
            diff = period_high - period_low
            fib_levels = {
                '0.0%': period_high,
                '23.6%': period_high - diff * 0.236,
                '38.2%': period_high - diff * 0.382,
                '50.0%': period_high - diff * 0.500,
                '61.8%': period_high - diff * 0.618,
                '78.6%': period_high - diff * 0.786,
                '100.0%': period_low
            }
            
            # 找出当前价格附近的支撑位和压力位
            support_levels = []
            resistance_levels = []
            
            for level_name, level_price in fib_levels.items():
                if level_price < current_price:
                    support_levels.append({
                        'name': f'斐波那契{level_name}',
                        'price': round(level_price, 2),
                        'distance_pct': round((current_price - level_price) / current_price * 100, 2)
                    })
                elif level_price > current_price:
                    resistance_levels.append({
                        'name': f'斐波那契{level_name}',
                        'price': round(level_price, 2),
                        'distance_pct': round((level_price - current_price) / current_price * 100, 2)
                    })
            
            # 按距离排序，取最近的3个
            support_levels.sort(key=lambda x: x['distance_pct'])
            resistance_levels.sort(key=lambda x: x['distance_pct'])
            
            return {
                'current_price': round(current_price, 2),
                'period_high': round(period_high, 2),
                'period_low': round(period_low, 2),
                'support_levels': support_levels[:3],
                'resistance_levels': resistance_levels[:3]
            }
            
        except Exception as e:
            logger.error(f"计算支撑压力位失败: {e}")
            return {}
    
    @staticmethod
    def calculate_target_price(df: pd.DataFrame) -> Dict[str, Any]:
        """
        计算目标价位（基于ATR和趋势）
        
        Args:
            df: 包含OHLC数据的DataFrame
            
        Returns:
            目标价位信息
        """
        try:
            # 计算ATR（平均真实波幅）
            df = df.copy()
            df['tr1'] = df['high'] - df['low']
            df['tr2'] = abs(df['high'] - df['close'].shift(1))
            df['tr3'] = abs(df['low'] - df['close'].shift(1))
            df['tr'] = df[['tr1', 'tr2', 'tr3']].max(axis=1)
            atr = df['tr'].rolling(window=14).mean().iloc[-1]
            
            current_price = float(df.iloc[-1]['close'])
            
            # 计算EMA趋势
            ema_short = df['close'].ewm(span=12, adjust=False).mean().iloc[-1]
            ema_long = df['close'].ewm(span=26, adjust=False).mean().iloc[-1]
            
            # 判断趋势方向
            is_uptrend = ema_short > ema_long
            
            # 基于ATR计算目标价位
            if is_uptrend:
                # 上升趋势：目标价 = 当前价 + (1.5 * ATR)
                target_price = current_price + (1.5 * atr)
                stop_loss = current_price - atr
                trend = "上升"
            else:
                # 下降趋势：目标价 = 当前价 - (1.5 * ATR)
                target_price = current_price - (1.5 * atr)
                stop_loss = current_price + atr
                trend = "下降"
            
            # 计算涨跌幅
            target_change_pct = (target_price - current_price) / current_price * 100
            stop_loss_pct = (stop_loss - current_price) / current_price * 100
            
            return {
                'current_price': round(current_price, 2),
                'target_price': round(target_price, 2),
                'target_change_pct': round(target_change_pct, 2),
                'stop_loss': round(stop_loss, 2),
                'stop_loss_pct': round(stop_loss_pct, 2),
                'atr': round(atr, 2),
                'trend': trend,
                'confidence': 'high' if abs(ema_short - ema_long) > atr else 'medium'
            }
            
        except Exception as e:
            logger.error(f"计算目标价位失败: {e}")
            return {}
    
    @staticmethod
    def calculate_technical_indicators(df: pd.DataFrame) -> Dict[str, Any]:
        """
        计算技术指标（RSI、MACD、布林带等）
        
        Args:
            df: 包含OHLC数据的DataFrame
            
        Returns:
            技术指标信息
        """
        try:
            df = df.copy()
            
            # 1. RSI（相对强弱指标）
            delta = df['close'].diff()
            gain = (delta.where(delta > 0, 0)).rolling(window=14).mean()
            loss = (-delta.where(delta < 0, 0)).rolling(window=14).mean()
            rs = gain / loss
            rsi = 100 - (100 / (1 + rs))
            current_rsi = float(rsi.iloc[-1])
            
            # RSI判断
            if current_rsi > 70:
                rsi_signal = "超买"
                rsi_color = "red"
            elif current_rsi < 30:
                rsi_signal = "超卖"
                rsi_color = "green"
            else:
                rsi_signal = "中性"
                rsi_color = "gray"
            
            # 2. MACD
            ema_12 = df['close'].ewm(span=12, adjust=False).mean()
            ema_26 = df['close'].ewm(span=26, adjust=False).mean()
            macd = ema_12 - ema_26
            signal = macd.ewm(span=9, adjust=False).mean()
            histogram = macd - signal
            
            current_macd = float(macd.iloc[-1])
            current_signal = float(signal.iloc[-1])
            current_histogram = float(histogram.iloc[-1])
            
            # MACD判断
            if current_macd > current_signal and current_histogram > 0:
                macd_signal = "金叉向上"
                macd_color = "red"
            elif current_macd < current_signal and current_histogram < 0:
                macd_signal = "死叉向下"
                macd_color = "green"
            else:
                macd_signal = "震荡"
                macd_color = "gray"
            
            # 3. 布林带
            sma_20 = df['close'].rolling(window=20).mean()
            std_20 = df['close'].rolling(window=20).std()
            upper_band = sma_20 + (std_20 * 2)
            lower_band = sma_20 - (std_20 * 2)
            
            current_price = float(df.iloc[-1]['close'])
            current_upper = float(upper_band.iloc[-1])
            current_lower = float(lower_band.iloc[-1])
            current_middle = float(sma_20.iloc[-1])
            
            # 布林带判断
            if current_price > current_upper:
                bb_signal = "突破上轨"
                bb_color = "red"
            elif current_price < current_lower:
                bb_signal = "跌破下轨"
                bb_color = "green"
            elif current_price > current_middle:
                bb_signal = "中轨上方"
                bb_color = "orange"
            else:
                bb_signal = "中轨下方"
                bb_color = "blue"
            
            return {
                'rsi': {
                    'value': round(current_rsi, 2),
                    'signal': rsi_signal,
                    'color': rsi_color
                },
                'macd': {
                    'macd': round(current_macd, 2),
                    'signal_line': round(current_signal, 2),
                    'histogram': round(current_histogram, 2),
                    'signal': macd_signal,
                    'color': macd_color
                },
                'bollinger_bands': {
                    'upper': round(current_upper, 2),
                    'middle': round(current_middle, 2),
                    'lower': round(current_lower, 2),
                    'current': round(current_price, 2),
                    'signal': bb_signal,
                    'color': bb_color
                }
            }
            
        except Exception as e:
            logger.error(f"计算技术指标失败: {e}")
            return {}
    
    @staticmethod
    def analyze_volume_price(df: pd.DataFrame) -> Dict[str, Any]:
        """
        量价关系分析
        
        Args:
            df: 包含OHLC和成交量数据的DataFrame
            
        Returns:
            量价关系分析结果
        """
        try:
            df = df.copy()
            
            # 计算成交量均线
            df['vol_ma5'] = df['volume'].rolling(window=5).mean()
            df['vol_ma20'] = df['volume'].rolling(window=20).mean()
            
            # 最近几天的数据
            recent = df.tail(5)
            
            # 价格变化
            price_change = (recent['close'].iloc[-1] - recent['close'].iloc[0]) / recent['close'].iloc[0] * 100
            
            # 成交量变化
            vol_change = (recent['volume'].iloc[-1] - recent['vol_ma20'].iloc[-1]) / recent['vol_ma20'].iloc[-1] * 100
            
            # 量价关系判断
            if price_change > 0 and vol_change > 0:
                signal = "量价齐升"
                description = "价格上涨且成交量放大，上涨动能强劲"
                color = "red"
                strength = "strong"
            elif price_change > 0 and vol_change < 0:
                signal = "价涨量缩"
                description = "价格上涨但成交量萎缩，上涨动能不足"
                color = "orange"
                strength = "weak"
            elif price_change < 0 and vol_change > 0:
                signal = "价跌量增"
                description = "价格下跌且成交量放大，下跌压力较大"
                color = "green"
                strength = "strong"
            elif price_change < 0 and vol_change < 0:
                signal = "价跌量缩"
                description = "价格下跌但成交量萎缩，下跌动能减弱"
                color = "blue"
                strength = "weak"
            else:
                signal = "量价平衡"
                description = "价格和成交量变化不明显"
                color = "gray"
                strength = "neutral"
            
            return {
                'signal': signal,
                'description': description,
                'color': color,
                'strength': strength,
                'price_change_5d': round(price_change, 2),
                'volume_change_pct': round(vol_change, 2),
                'current_volume': int(recent['volume'].iloc[-1]),
                'avg_volume_20d': int(recent['vol_ma20'].iloc[-1])
            }
            
        except Exception as e:
            logger.error(f"量价关系分析失败: {e}")
            return {}
    
    @staticmethod
    def calculate_trend_strength(df: pd.DataFrame) -> Dict[str, Any]:
        """
        计算趋势强度
        
        Args:
            df: 包含OHLC数据的DataFrame
            
        Returns:
            趋势强度分析
        """
        try:
            df = df.copy()
            
            # 计算多个周期的EMA
            ema_5 = df['close'].ewm(span=5, adjust=False).mean()
            ema_10 = df['close'].ewm(span=10, adjust=False).mean()
            ema_20 = df['close'].ewm(span=20, adjust=False).mean()
            ema_60 = df['close'].ewm(span=60, adjust=False).mean()
            
            current_price = float(df.iloc[-1]['close'])
            
            # 短期趋势（5日和10日）
            if ema_5.iloc[-1] > ema_10.iloc[-1] and current_price > ema_5.iloc[-1]:
                short_trend = "强势上涨"
                short_score = 80
            elif ema_5.iloc[-1] > ema_10.iloc[-1]:
                short_trend = "上涨"
                short_score = 60
            elif ema_5.iloc[-1] < ema_10.iloc[-1] and current_price < ema_5.iloc[-1]:
                short_trend = "强势下跌"
                short_score = 20
            elif ema_5.iloc[-1] < ema_10.iloc[-1]:
                short_trend = "下跌"
                short_score = 40
            else:
                short_trend = "震荡"
                short_score = 50
            
            # 中期趋势（20日和60日）
            if ema_20.iloc[-1] > ema_60.iloc[-1] and current_price > ema_20.iloc[-1]:
                medium_trend = "强势上涨"
                medium_score = 80
            elif ema_20.iloc[-1] > ema_60.iloc[-1]:
                medium_trend = "上涨"
                medium_score = 60
            elif ema_20.iloc[-1] < ema_60.iloc[-1] and current_price < ema_20.iloc[-1]:
                medium_trend = "强势下跌"
                medium_score = 20
            elif ema_20.iloc[-1] < ema_60.iloc[-1]:
                medium_trend = "下跌"
                medium_score = 40
            else:
                medium_trend = "震荡"
                medium_score = 50
            
            # 长期趋势（60日均线方向）
            ema_60_slope = (ema_60.iloc[-1] - ema_60.iloc[-10]) / ema_60.iloc[-10] * 100
            
            if ema_60_slope > 2:
                long_trend = "强势上涨"
                long_score = 80
            elif ema_60_slope > 0:
                long_trend = "上涨"
                long_score = 60
            elif ema_60_slope < -2:
                long_trend = "强势下跌"
                long_score = 20
            elif ema_60_slope < 0:
                long_trend = "下跌"
                long_score = 40
            else:
                long_trend = "震荡"
                long_score = 50
            
            # 综合评分
            overall_score = int((short_score * 0.3 + medium_score * 0.4 + long_score * 0.3))
            
            if overall_score >= 70:
                overall_trend = "强势上涨"
                overall_color = "red"
            elif overall_score >= 55:
                overall_trend = "上涨"
                overall_color = "orange"
            elif overall_score >= 45:
                overall_trend = "震荡"
                overall_color = "gray"
            elif overall_score >= 30:
                overall_trend = "下跌"
                overall_color = "blue"
            else:
                overall_trend = "强势下跌"
                overall_color = "green"
            
            return {
                'short_term': {
                    'trend': short_trend,
                    'score': short_score
                },
                'medium_term': {
                    'trend': medium_trend,
                    'score': medium_score
                },
                'long_term': {
                    'trend': long_trend,
                    'score': long_score
                },
                'overall': {
                    'trend': overall_trend,
                    'score': overall_score,
                    'color': overall_color
                }
            }
            
        except Exception as e:
            logger.error(f"计算趋势强度失败: {e}")
            return {}
    
    @classmethod
    def comprehensive_analysis(cls, df: pd.DataFrame) -> Dict[str, Any]:
        """
        综合分析（整合所有分析结果）
        
        Args:
            df: 包含OHLC数据的DataFrame
            
        Returns:
            综合分析结果
        """
        try:
            return {
                'support_resistance': cls.calculate_support_resistance(df),
                'target_price': cls.calculate_target_price(df),
                'technical_indicators': cls.calculate_technical_indicators(df),
                'volume_price': cls.analyze_volume_price(df),
                'trend_strength': cls.calculate_trend_strength(df)
            }
        except Exception as e:
            logger.error(f"综合分析失败: {e}")
            return {}


# 创建全局实例
analysis_engine = IndexAnalysisEngine()

