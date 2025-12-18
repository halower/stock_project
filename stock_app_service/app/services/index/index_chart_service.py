# -*- coding: utf-8 -*-
"""
专业指数图表服务 - TradingView级别的专业图表分析
只支持三大核心指数：上证指数、深证成指、创业板指
"""

import pandas as pd
import os
import uuid
from typing import Dict, Any, Optional, List
from datetime import datetime
from app.core.logging import logger
from app.core.config import CHART_DIR
from app.charts import generate_chart_html
from app import indicators
from app.services.index.index_service import index_service
from app.services.index.index_analysis_engine import analysis_engine


# 确保图表目录存在
os.makedirs(CHART_DIR, exist_ok=True)

# 三大核心指数配置
CORE_INDICES = {
    '000001.SH': {
        'name': '上证指数',
        'symbol': 'SSE Composite',
        'market': 'Shanghai',
        'color': '#FF6B6B'
    },
    '399001.SZ': {
        'name': '深证成指',
        'symbol': 'SZSE Component',
        'market': 'Shenzhen',
        'color': '#4ECDC4'
    },
    '399006.SZ': {
        'name': '创业板指',
        'symbol': 'ChiNext',
        'market': 'Shenzhen GEM',
        'color': '#95E1D3'
    }
}


class IndexChartService:
    """专业指数图表服务类 - TradingView级别"""
    
    def __init__(self):
        """初始化专业指数图表服务"""
        logger.info("专业指数图表服务初始化成功 - 支持三大核心指数")
    
    def _validate_index_code(self, index_code: str) -> bool:
        """
        验证指数代码是否为支持的三大核心指数
        
        Args:
            index_code: 指数代码
            
        Returns:
            是否为支持的指数
        """
        return index_code in CORE_INDICES
    
    def _get_index_info(self, index_code: str) -> Dict[str, str]:
        """
        获取指数信息
        
        Args:
            index_code: 指数代码
            
        Returns:
            指数信息字典
        """
        return CORE_INDICES.get(index_code, {
            'name': index_code,
            'symbol': index_code,
            'market': 'Unknown',
            'color': '#666666'
        })
    
    async def generate_index_chart(
        self,
        index_code: str = "000001.SH",
        days: int = 180,
        theme: str = "dark"
    ) -> Dict[str, Any]:
        """
        生成专业级指数图表HTML文件（仅支持三大核心指数）
        
        Args:
            index_code: 指数代码（仅支持：000001.SH、399001.SZ、399006.SZ）
            days: 获取天数，默认180天
            theme: 图表主题，light或dark
            
        Returns:
            {
                'success': bool,
                'chart_url': str,  # 图表URL
                'index_code': str,
                'index_name': str,
                'index_info': Dict,  # 指数详细信息
                'error': str  # 错误信息（如果失败）
            }
        """
        try:
            # 验证是否为支持的核心指数
            if not self._validate_index_code(index_code):
                return {
                    'success': False,
                    'error': f'不支持的指数代码。仅支持三大核心指数：上证指数(000001.SH)、深证成指(399001.SZ)、创业板指(399006.SZ)',
                    'index_code': index_code
                }
            
            index_info = self._get_index_info(index_code)
            logger.info(f"开始生成专业图表 - {index_info['name']} ({index_code})，天数: {days}, 主题: {theme}")
            
            # 1. 获取指数日线数据
            index_data = await index_service.get_index_daily(index_code, days)
            
            if not index_data['success'] or not index_data['data']:
                return {
                    'success': False,
                    'error': index_data.get('error', '获取指数数据失败'),
                    'index_code': index_code
                }
            
            # 2. 转换为DataFrame
            df = pd.DataFrame(index_data['data'])
            
            # 确保数据格式正确
            if 'trade_date' in df.columns:
                # 转换trade_date格式 (20250102 -> 2025-01-02)
                def convert_date(date_str):
                    date_str = str(date_str)
                    if len(date_str) == 8 and date_str.isdigit():
                        return f"{date_str[:4]}-{date_str[4:6]}-{date_str[6:8]}"
                    return date_str
                
                df['date'] = pd.to_datetime(df['trade_date'].apply(convert_date))
            else:
                df['date'] = pd.to_datetime(df['date'])
            
            df = df.sort_values('date').reset_index(drop=True)
            
            # 重命名列以匹配图表策略的要求
            if 'vol' in df.columns and 'volume' not in df.columns:
                df['volume'] = df['vol']
            
            # 确保所有必需的列都存在
            required_columns = ['date', 'open', 'high', 'low', 'close', 'volume']
            for col in required_columns:
                if col not in df.columns:
                    logger.error(f"缺少必需列: {col}")
                    return {
                        'success': False,
                        'error': f'数据格式错误，缺少{col}列',
                        'index_code': index_code
                    }
            
            # 3. 应用动量守恒增强版策略
            try:
                processed_df, signals = indicators.apply_strategy('volume_wave_enhanced', df)
                logger.info(f"策略应用成功: 生成 {len(signals)} 个信号")
            except Exception as e:
                logger.error(f"策略应用失败: {e}")
                return {
                    'success': False,
                    'error': f'策略应用失败: {str(e)}',
                    'index_code': index_code
                }
            
            # 4. 准备专业图表数据
            stock_data = {
                'stock': {
                    'code': index_code,
                    'name': index_info['name'],
                    'symbol': index_info['symbol'],
                    'market': index_info['market'],
                    'type': 'index'  # 标记为指数类型
                },
                'data': processed_df,
                'signals': signals,
                'strategy': 'volume_wave_enhanced',
                'theme': theme,
                'professional_mode': True  # 启用专业模式
            }
            
            # 5. 生成专业级图表HTML
            try:
                chart_file = f"pro_index_{index_code.replace('.', '_')}_{theme}_{datetime.now().strftime('%Y%m%d%H%M%S')}_{uuid.uuid4().hex[:8]}.html"
                chart_path = os.path.join(CHART_DIR, chart_file)
                
                # 生成HTML内容
                html_content = generate_chart_html('volume_wave_enhanced', stock_data, theme=theme)
                
                if not html_content:
                    return {
                        'success': False,
                        'error': '生成专业图表HTML失败',
                        'index_code': index_code
                    }
                
                # 写入文件
                with open(chart_path, 'w', encoding='utf-8') as f:
                    f.write(html_content)
                
                chart_url = f"/static/charts/{chart_file}"
                
                logger.info(f"成功生成专业图表 - {index_info['name']}: {chart_url}")
                
                return {
                    'success': True,
                    'chart_url': chart_url,
                    'index_code': index_code,
                    'index_name': index_info['name'],
                    'index_info': index_info
                }
                
            except Exception as e:
                logger.error(f"生成图表文件失败: {e}")
                import traceback
                logger.error(traceback.format_exc())
                return {
                    'success': False,
                    'error': f'生成图表文件失败: {str(e)}',
                    'index_code': index_code
                }
            
        except Exception as e:
            logger.error(f"生成指数图表失败: {e}")
            import traceback
            logger.error(traceback.format_exc())
            return {
                'success': False,
                'error': str(e),
                'index_code': index_code
            }
    
    async def get_index_analysis(
        self,
        index_code: str = "000001.SH",
        days: int = 180,
        theme: str = "dark"
    ) -> Dict[str, Any]:
        """
        获取专业级指数分析数据（TradingView级别）
        包含图表、技术指标、市场情绪等专业分析
        
        Args:
            index_code: 指数代码（仅支持三大核心指数）
            days: 获取天数
            theme: 图表主题
            
        Returns:
            {
                'success': bool,
                'chart_url': str,  # 图表URL
                'technical_analysis': Dict,  # 技术分析（专业级）
                'market_sentiment': Dict,  # 市场情绪分析
                'key_metrics': Dict,  # 关键指标
                'index_code': str,
                'index_name': str,
                'index_info': Dict
            }
        """
        try:
            # 验证指数代码
            if not self._validate_index_code(index_code):
                return {
                    'success': False,
                    'error': f'不支持的指数代码。仅支持三大核心指数：上证指数(000001.SH)、深证成指(399001.SZ)、创业板指(399006.SZ)',
                    'index_code': index_code
                }
            
            index_info = self._get_index_info(index_code)
            
            # 1. 生成专业图表
            chart_result = await self.generate_index_chart(index_code, days, theme)
            
            if not chart_result['success']:
                return chart_result
            
            # 2. 获取原始数据用于专业分析
            index_data = await index_service.get_index_daily(index_code, days)
            
            if not index_data['success']:
                return chart_result  # 至少返回图表数据
            
            # 3. 准备数据
            df = pd.DataFrame(index_data['data'])
            
            # 确保有必要的列
            if 'vol' in df.columns and 'volume' not in df.columns:
                df['volume'] = df['vol']
            
            # 转换日期格式
            if 'trade_date' in df.columns:
                def convert_date(date_str):
                    date_str = str(date_str)
                    if len(date_str) == 8 and date_str.isdigit():
                        return f"{date_str[:4]}-{date_str[4:6]}-{date_str[6:8]}"
                    return date_str
                df['date'] = pd.to_datetime(df['trade_date'].apply(convert_date))
            
            df = df.sort_values('date').reset_index(drop=True)
            
            # 4. 专业技术分析
            technical_analysis = self._perform_technical_analysis(df)
            
            # 5. 市场情绪分析
            market_sentiment = self._analyze_market_sentiment(df)
            
            # 6. 关键指标计算
            key_metrics = self._calculate_key_metrics(df)
            
            # 7. 关键点位预测（散户最关心的）
            key_levels = self._calculate_key_levels(df, technical_analysis)
            
            # 8. 组装返回结果
            chart_result.update({
                'technical_analysis': technical_analysis,
                'market_sentiment': market_sentiment,
                'key_metrics': key_metrics,
                'key_levels': key_levels,
                'index_info': index_info
            })
            
            logger.info(f"成功生成专业分析 - {index_info['name']}")
            
            return chart_result
            
        except Exception as e:
            logger.error(f"获取专业指数分析失败: {e}")
            import traceback
            logger.error(traceback.format_exc())
            return {
                'success': False,
                'error': str(e),
                'index_code': index_code
            }
    
    def _perform_technical_analysis(self, df: pd.DataFrame) -> Dict[str, Any]:
        """
        执行专业技术分析（TradingView级别）
        
        Args:
            df: 数据DataFrame
            
        Returns:
            技术分析结果
        """
        try:
            latest = df.iloc[-1]
            
            # 计算移动平均线
            df['ma5'] = df['close'].rolling(window=5).mean()
            df['ma10'] = df['close'].rolling(window=10).mean()
            df['ma20'] = df['close'].rolling(window=20).mean()
            df['ma60'] = df['close'].rolling(window=60).mean()
            
            # 计算MACD
            exp1 = df['close'].ewm(span=12, adjust=False).mean()
            exp2 = df['close'].ewm(span=26, adjust=False).mean()
            df['macd'] = exp1 - exp2
            df['signal'] = df['macd'].ewm(span=9, adjust=False).mean()
            df['histogram'] = df['macd'] - df['signal']
            
            # 计算RSI
            delta = df['close'].diff()
            gain = (delta.where(delta > 0, 0)).rolling(window=14).mean()
            loss = (-delta.where(delta < 0, 0)).rolling(window=14).mean()
            rs = gain / loss
            df['rsi'] = 100 - (100 / (1 + rs))
            
            # 计算布林带
            df['bb_middle'] = df['close'].rolling(window=20).mean()
            bb_std = df['close'].rolling(window=20).std()
            df['bb_upper'] = df['bb_middle'] + (bb_std * 2)
            df['bb_lower'] = df['bb_middle'] - (bb_std * 2)
            
            latest_with_indicators = df.iloc[-1]
            
            # 趋势判断
            trend = "中性"
            if latest['close'] > latest_with_indicators['ma20']:
                if latest_with_indicators['ma20'] > latest_with_indicators['ma60']:
                    trend = "强势上涨"
                else:
                    trend = "上涨"
            elif latest['close'] < latest_with_indicators['ma20']:
                if latest_with_indicators['ma20'] < latest_with_indicators['ma60']:
                    trend = "强势下跌"
                else:
                    trend = "下跌"
            
            # MACD信号
            macd_signal = "中性"
            if latest_with_indicators['macd'] > latest_with_indicators['signal']:
                macd_signal = "多头" if latest_with_indicators['histogram'] > 0 else "转多"
            else:
                macd_signal = "空头" if latest_with_indicators['histogram'] < 0 else "转空"
            
            # RSI信号
            rsi_value = latest_with_indicators['rsi']
            rsi_signal = "中性"
            if rsi_value > 70:
                rsi_signal = "超买"
            elif rsi_value > 60:
                rsi_signal = "偏强"
            elif rsi_value < 30:
                rsi_signal = "超卖"
            elif rsi_value < 40:
                rsi_signal = "偏弱"
            
            return {
                'trend': trend,
                'moving_averages': {
                    'ma5': float(latest_with_indicators['ma5']),
                    'ma10': float(latest_with_indicators['ma10']),
                    'ma20': float(latest_with_indicators['ma20']),
                    'ma60': float(latest_with_indicators['ma60'])
                },
                'macd': {
                    'value': float(latest_with_indicators['macd']),
                    'signal': float(latest_with_indicators['signal']),
                    'histogram': float(latest_with_indicators['histogram']),
                    'interpretation': macd_signal
                },
                'rsi': {
                    'value': float(rsi_value),
                    'interpretation': rsi_signal
                },
                'bollinger_bands': {
                    'upper': float(latest_with_indicators['bb_upper']),
                    'middle': float(latest_with_indicators['bb_middle']),
                    'lower': float(latest_with_indicators['bb_lower']),
                    'position': 'upper' if latest['close'] > latest_with_indicators['bb_middle'] else 'lower'
                }
            }
            
        except Exception as e:
            logger.error(f"技术分析失败: {e}")
            return {}
    
    def _analyze_market_sentiment(self, df: pd.DataFrame) -> Dict[str, Any]:
        """
        真实市场情绪分析 - 基于多维度量化指标
        
        Args:
            df: 数据DataFrame
            
        Returns:
            市场情绪分析结果
        """
        try:
            recent_20 = df.tail(20)
            recent_5 = df.tail(5)
            
            # 1. 涨跌统计
            up_days = (recent_20['pct_chg'] > 0).sum()
            down_days = (recent_20['pct_chg'] < 0).sum()
            avg_up = recent_20[recent_20['pct_chg'] > 0]['pct_chg'].mean() if up_days > 0 else 0
            avg_down = abs(recent_20[recent_20['pct_chg'] < 0]['pct_chg'].mean()) if down_days > 0 else 0
            
            # 2. 多空力量对比（改进算法：结合涨跌幅、成交量和天数）
            # 计算上涨日的力量：涨幅 × 成交量 × 天数权重
            up_days_data = recent_20[recent_20['pct_chg'] > 0]
            down_days_data = recent_20[recent_20['pct_chg'] < 0]
            
            # 多方力量 = Σ(涨幅 × 成交量) / 总成交量
            if len(up_days_data) > 0:
                bull_power = (up_days_data['pct_chg'] * up_days_data['volume']).sum()
            else:
                bull_power = 0
            
            # 空方力量 = Σ(|跌幅| × 成交量) / 总成交量
            if len(down_days_data) > 0:
                bear_power = (abs(down_days_data['pct_chg']) * down_days_data['volume']).sum()
            else:
                bear_power = 0
            
            # 计算多空比例
            total_power = bull_power + bear_power
            bull_ratio = (bull_power / total_power * 100) if total_power > 0 else 50
            bear_ratio = 100 - bull_ratio
            
            # 3. 成交量能量分析
            recent_vol = recent_5['volume'].mean()
            prev_vol = df.tail(20).head(15)['volume'].mean()
            vol_change = ((recent_vol - prev_vol) / prev_vol * 100) if prev_vol > 0 else 0
            
            # 上涨日成交量 vs 下跌日成交量
            up_vol = recent_20[recent_20['pct_chg'] > 0]['volume'].sum()
            down_vol = recent_20[recent_20['pct_chg'] < 0]['volume'].sum()
            vol_ratio = (up_vol / (up_vol + down_vol) * 100) if (up_vol + down_vol) > 0 else 50
            
            # 4. 价格动能（近5日 vs 近20日）
            momentum_5 = ((recent_5.iloc[-1]['close'] - recent_5.iloc[0]['close']) / recent_5.iloc[0]['close'] * 100)
            momentum_20 = ((recent_20.iloc[-1]['close'] - recent_20.iloc[0]['close']) / recent_20.iloc[0]['close'] * 100)
            
            # 5. 综合情绪评分（0-100）
            # 权重分配：涨跌比30% + 多空力量25% + 成交量比20% + 短期动能15% + 中期动能10%
            sentiment_score = (
                (up_days / 20) * 30 +  # 涨跌天数比
                (bull_ratio / 100) * 25 +  # 多空力量比
                (vol_ratio / 100) * 20 +  # 成交量比
                (max(0, min(100, 50 + momentum_5 * 5)) / 100) * 15 +  # 短期动能
                (max(0, min(100, 50 + momentum_20 * 2)) / 100) * 10  # 中期动能
            )
            
            # 6. 情绪描述
            if sentiment_score >= 75:
                sentiment = "极度乐观"
                sentiment_level = "extreme_bullish"
            elif sentiment_score >= 65:
                sentiment = "乐观"
                sentiment_level = "bullish"
            elif sentiment_score >= 55:
                sentiment = "偏乐观"
                sentiment_level = "slightly_bullish"
            elif sentiment_score >= 45:
                sentiment = "中性"
                sentiment_level = "neutral"
            elif sentiment_score >= 35:
                sentiment = "偏悲观"
                sentiment_level = "slightly_bearish"
            elif sentiment_score >= 25:
                sentiment = "悲观"
                sentiment_level = "bearish"
            else:
                sentiment = "极度悲观"
                sentiment_level = "extreme_bearish"
            
            # 7. 成交量趋势
            if vol_change > 30:
                vol_trend = "显著放量"
            elif vol_change > 15:
                vol_trend = "温和放量"
            elif vol_change > -15:
                vol_trend = "平稳"
            elif vol_change > -30:
                vol_trend = "温和缩量"
            else:
                vol_trend = "显著缩量"
            
            # 8. 市场强度（基于连续涨跌）- 修复逻辑错误
            consecutive_up = 0
            consecutive_down = 0
            
            # 从最新的一天往前数，计算连续上涨或下跌天数
            for i in range(len(recent_5) - 1, -1, -1):
                pct_chg = recent_5.iloc[i]['pct_chg']
                
                if pct_chg > 0:
                    # 如果当前是上涨，但之前已经在计算下跌天数，说明连续下跌中断
                    if consecutive_down > 0:
                        break
                    consecutive_up += 1
                elif pct_chg < 0:
                    # 如果当前是下跌，但之前已经在计算上涨天数，说明连续上涨中断
                    if consecutive_up > 0:
                        break
                    consecutive_down += 1
                else:
                    # 如果是平盘（涨跌幅为0），中断连续计数
                    break
            
            return {
                'sentiment': sentiment,
                'sentiment_level': sentiment_level,
                'sentiment_score': float(sentiment_score),
                'bull_power_ratio': float(bull_ratio),
                'bear_power_ratio': float(bear_ratio),
                'up_days_20': int(up_days),
                'down_days_20': int(down_days),
                'avg_gain': float(avg_up),
                'avg_loss': float(avg_down),
                'volume_trend': vol_trend,
                'volume_change_pct': float(vol_change),
                'volume_ratio': float(vol_ratio),
                'momentum_5d': float(momentum_5),
                'momentum_20d': float(momentum_20),
                'consecutive_up': int(consecutive_up),
                'consecutive_down': int(consecutive_down),
                # 新增：详细的多空力量数据
                'bull_power_detail': {
                    'total_power': float(bull_power),
                    'avg_gain_with_volume': float(bull_power / len(up_days_data)) if len(up_days_data) > 0 else 0,
                    'up_days': int(up_days)
                },
                'bear_power_detail': {
                    'total_power': float(bear_power),
                    'avg_loss_with_volume': float(bear_power / len(down_days_data)) if len(down_days_data) > 0 else 0,
                    'down_days': int(down_days)
                }
            }
            
        except Exception as e:
            logger.error(f"市场情绪分析失败: {e}")
            return {}
    
    def _calculate_key_metrics(self, df: pd.DataFrame) -> Dict[str, Any]:
        """
        计算关键指标
        
        Args:
            df: 数据DataFrame
            
        Returns:
            关键指标
        """
        try:
            latest = df.iloc[-1]
            first = df.iloc[0]
            
            # 波动率（标准差）
            volatility = df['pct_chg'].std()
            
            # 最大回撤
            df['cummax'] = df['close'].cummax()
            df['drawdown'] = (df['close'] - df['cummax']) / df['cummax'] * 100
            max_drawdown = df['drawdown'].min()
            
            # 夏普比率（简化版）
            returns = df['pct_chg'].mean()
            sharpe = (returns / volatility) if volatility > 0 else 0
            
            return {
                'current_price': float(latest['close']),
                'change': float(latest['change']),
                'change_pct': float(latest['pct_chg']),
                'period_high': float(df['high'].max()),
                'period_low': float(df['low'].min()),
                'period_return': float((latest['close'] - first['close']) / first['close'] * 100),
                'volatility': float(volatility),
                'max_drawdown': float(max_drawdown),
                'sharpe_ratio': float(sharpe),
                'avg_volume': float(df['volume'].mean()),
                'total_trading_days': len(df)
            }
            
        except Exception as e:
            logger.error(f"关键指标计算失败: {e}")
            return {}
    
    def _calculate_key_levels(self, df: pd.DataFrame, technical_analysis: Dict[str, Any]) -> Dict[str, Any]:
        """
        计算关键点位 - 散户最关心的支撑位、压力位、目标价
        
        Args:
            df: 数据DataFrame
            technical_analysis: 技术分析结果
            
        Returns:
            关键点位信息
        """
        try:
            latest = df.iloc[-1]
            current_price = float(latest['close'])
            
            # 1. 近期高低点（20日、60日）
            recent_20 = df.tail(20)
            recent_60 = df.tail(60)
            high_20 = float(recent_20['high'].max())
            low_20 = float(recent_20['low'].min())
            high_60 = float(recent_60['high'].max())
            low_60 = float(recent_60['low'].min())
            
            # 2. 移动平均线作为支撑/压力位
            ma_levels = technical_analysis.get('moving_averages', {})
            ma20 = ma_levels.get('ma20', current_price)
            ma60 = ma_levels.get('ma60', current_price)
            
            # 3. 布林带上下轨
            bb = technical_analysis.get('bollinger_bands', {})
            bb_upper = bb.get('upper', current_price * 1.05)
            bb_lower = bb.get('lower', current_price * 0.95)
            
            # 4. 计算支撑位（从低到高排序）
            support_candidates = [
                low_20,  # 20日最低
                ma20 if ma20 < current_price else None,  # MA20（如果在下方）
                bb_lower,  # 布林带下轨
                low_60,  # 60日最低
                ma60 if ma60 < current_price else None,  # MA60（如果在下方）
            ]
            supports = sorted([s for s in support_candidates if s and s < current_price], reverse=True)
            
            # 5. 计算压力位（从低到高排序）
            resistance_candidates = [
                ma20 if ma20 > current_price else None,  # MA20（如果在上方）
                bb_upper,  # 布林带上轨
                high_20,  # 20日最高
                ma60 if ma60 > current_price else None,  # MA60（如果在上方）
                high_60,  # 60日最高
            ]
            resistances = sorted([r for r in resistance_candidates if r and r > current_price])
            
            # 6. 目标价位计算（基于趋势和波动率）
            volatility = df.tail(20)['pct_chg'].std()
            avg_range = (df.tail(20)['high'] - df.tail(20)['low']).mean()
            
            # 根据趋势判断目标价
            trend = technical_analysis.get('trend', '中性')
            if '上涨' in trend:
                # 上涨趋势：目标价 = 当前价 + 平均波动幅度
                target_up = current_price + avg_range
                target_down = supports[0] if supports else current_price * 0.97
                probability_up = 65 if '强势' in trend else 55
            elif '下跌' in trend:
                # 下跌趋势：目标价 = 当前价 - 平均波动幅度
                target_up = resistances[0] if resistances else current_price * 1.03
                target_down = current_price - avg_range
                probability_up = 35 if '强势' in trend else 45
            else:
                # 中性：小幅波动
                target_up = current_price + avg_range * 0.5
                target_down = current_price - avg_range * 0.5
                probability_up = 50
            
            # 7. 关键价位距离当前价的百分比
            def calc_distance(price):
                return ((price - current_price) / current_price * 100)
            
            # 8. 止损止盈建议
            stop_loss = supports[0] if supports else current_price * 0.97
            take_profit = resistances[0] if resistances else current_price * 1.03
            
            return {
                'current_price': current_price,
                'supports': [
                    {
                        'price': float(s),
                        'distance_pct': float(calc_distance(s)),
                        'level': f"支撑{i+1}"
                    }
                    for i, s in enumerate(supports[:3])  # 取前3个支撑位
                ],
                'resistances': [
                    {
                        'price': float(r),
                        'distance_pct': float(calc_distance(r)),
                        'level': f"压力{i+1}"
                    }
                    for i, r in enumerate(resistances[:3])  # 取前3个压力位
                ],
                'target_prices': {
                    'upside_target': float(target_up),
                    'upside_distance': float(calc_distance(target_up)),
                    'downside_target': float(target_down),
                    'downside_distance': float(calc_distance(target_down)),
                    'probability_up': float(probability_up),
                    'probability_down': float(100 - probability_up)
                },
                'trading_advice': {
                    'stop_loss': float(stop_loss),
                    'stop_loss_pct': float(calc_distance(stop_loss)),
                    'take_profit': float(take_profit),
                    'take_profit_pct': float(calc_distance(take_profit)),
                    'risk_reward_ratio': float(abs(calc_distance(take_profit)) / abs(calc_distance(stop_loss))) if calc_distance(stop_loss) != 0 else 1.0
                },
                'key_levels_summary': {
                    'nearest_support': float(supports[0]) if supports else None,
                    'nearest_resistance': float(resistances[0]) if resistances else None,
                    'high_20d': float(high_20),
                    'low_20d': float(low_20),
                    'high_60d': float(high_60),
                    'low_60d': float(low_60)
                }
            }
            
        except Exception as e:
            logger.error(f"关键点位计算失败: {e}")
            return {}


# 创建全局实例
index_chart_service = IndexChartService()
