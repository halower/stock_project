# -*- coding: utf-8 -*-
"""波动守恒图表策略"""

from typing import Dict, Any
import pandas as pd
from app.charts.base_chart_strategy import BaseChartStrategy
from app.indicators.volatility_conservation_strategy import VolatilityConservationStrategy
from app.core.logging import logger


class VolatilityConservationChartStrategy(BaseChartStrategy):
    """
    趋势追踪图表策略
    
    【核心逻辑 - 内部文档】
    基于ATR（Average True Range）动态止损的趋势跟踪策略：
    1. 计算ATR作为波动率指标
    2. 使用 nLoss = key_value * ATR 作为止损距离
    3. 根据价格方向动态调整止损线（xATRTrailingStop）
    4. 价格突破止损线产生买卖信号
    5. 可选择使用Heikin Ashi蜡烛图平滑噪音
    
    技术特点：
    - ATR动态调整：根据市场波动自适应
    - 趋势保护：止损线跟随价格移动
    - 信号清晰：明确的突破买卖点
    
    参数说明：
    - key_value: 敏感度（默认1.0，越大止损越宽）
    - atr_period: ATR计算周期（默认10）
    - use_heikin_ashi: 是否使用HA蜡烛图（默认False）
    """
    
    STRATEGY_CODE = "volatility_conservation"
    STRATEGY_NAME = "趋势追踪"
    STRATEGY_DESCRIPTION = ""  # 不向用户展示策略描述
    
    @classmethod
    def get_strategy_name(cls) -> str:
        return cls.STRATEGY_NAME
    
    @classmethod
    def get_strategy_description(cls) -> str:
        return cls.STRATEGY_DESCRIPTION
    
    @classmethod
    def generate_chart_html(cls, stock_data: Dict[str, Any], **kwargs) -> str:
        """
        生成波动守恒图表HTML
        
        Args:
            stock_data: 包含股票信息、数据和信号的字典
            theme: 图表主题 ('light' 或 'dark')
            
        Returns:
            完整的HTML字符串
        """
        try:
            stock = stock_data['stock']
            df = stock_data['data']
            signals = stock_data.get('signals', [])
            theme = kwargs.get('theme', 'dark')  # 从kwargs获取theme参数
            
            logger.info(f"生成波动守恒图表: {stock['name']}({stock['code']})")
            
            # 准备图表数据
            chart_data = cls._prepare_chart_data(df)
            volume_data = cls._prepare_volume_data(chart_data)  # 传入chart_data而不是df
            markers = cls._prepare_markers(df, signals)
            
            # 准备颜色配置
            colors = cls.get_theme_colors(theme)
            
            # 准备ATR止损线数据
            atr_stop_data = []
            if 'atr_trailing_stop' in df.columns:
                for idx, row in df.iterrows():
                    if pd.notna(row.get('atr_trailing_stop')):
                        atr_stop_data.append({
                            'time': row['date'].strftime('%Y-%m-%d'),
                            'value': float(row['atr_trailing_stop'])
                        })
            
            # 准备指标池数据（与其他策略保持一致）
            ema6_data = cls._prepare_ema_data(df, 'ema6')
            ema12_data = cls._prepare_ema_data(df, 'ema12')
            ema18_data = cls._prepare_ema_data(df, 'ema18')
            ema144_data = cls._prepare_ema_data(df, 'ema144')
            ema169_data = cls._prepare_ema_data(df, 'ema169')
            
            # 计算 Volume Profile Pivot Anchored
            from app.indicators.tradingview.volume_profile_pivot_anchored import calculate_volume_profile_pivot_anchored
            volume_profile = calculate_volume_profile_pivot_anchored(
                df, 
                pivot_length=20, 
                profile_levels=25, 
                value_area_percent=68.0, 
                profile_width=0.30
            )
            
            # 计算 Pivot Order Blocks
            from app.indicators.tradingview.pivot_order_blocks import calculate_pivot_order_blocks
            pivot_order_blocks = calculate_pivot_order_blocks(
                df, left=15, right=8, box_count=2, percentage_change=6.0, box_extend_to_end=True
            )
            if pivot_order_blocks is None:
                pivot_order_blocks = []
            
            # 转换 Pivot Order Blocks 格式
            pivot_order_blocks_for_pool = []
            for block in pivot_order_blocks:
                pivot_order_blocks_for_pool.append({
                    'type': 'resistance' if block['type'] == 'resistance' else 'support',
                    'price_high': block['price_high'],
                    'price_low': block['price_low'],
                    'start_time': cls._get_time_string(df, block['start_index']),
                    'end_time': cls._get_time_string(df, block['end_index']),
                    'strength': block.get('strength', 0.8)
                })
            
            # 计算背离检测
            from app.indicators.tradingview.divergence_detector import calculate_divergence_detector
            divergence_data = calculate_divergence_detector(
                df,
                pivot_period=5,
                max_pivot_points=10,
                max_bars=100,
                check_macd=True,
                check_rsi=True,
                check_stoch=True,
                check_cci=True,
                check_momentum=True
            )
            
            # 镜像K线懒加载
            mirror_data = None
            
            # ATR止损线已隐藏（用户要求不显示）
            # ATR止损线数据仍然计算并保存在DataFrame中（df['atr_trailing_stop']）
            # 但不在图表上绘制，保持界面简洁
            atr_line_script = ""
            # if atr_stop_data:
            #     import json
            #     atr_line_script = f"""
            #     // 添加ATR止损线
            #     const atrStopSeries = chart.addLineSeries({{
            #         color: '#ff9800',
            #         lineWidth: 2,
            #         title: '',
            #         priceLineVisible: false,
            #         lastValueVisible: false,
            #     }});
            #     atrStopSeries.setData({json.dumps(atr_stop_data)});
            #     """
            
            # 生成指标池（传入所有指标数据）
            indicator_pool_scripts = cls._generate_indicator_pool_scripts(
                ema6_data, ema12_data, ema18_data, ema144_data, ema169_data, 
                volume_profile, pivot_order_blocks_for_pool, divergence_data, mirror_data
            )
            
            additional_scripts = indicator_pool_scripts  # 不再包含ATR止损线
            
            # 调用基类方法生成HTML
            return cls._generate_base_html_template(
                stock=stock,
                strategy_name=cls.STRATEGY_NAME,
                strategy_desc=cls.STRATEGY_DESCRIPTION,
                chart_data=chart_data,
                markers=markers,
                volume_data=volume_data,
                additional_series="",
                additional_scripts=additional_scripts,
                colors=colors
            )
            
        except Exception as e:
            logger.error(f"生成波动守恒图表失败: {str(e)}")
            import traceback
            logger.error(f"完整错误堆栈:\n{traceback.format_exc()}")
            raise
    
    @classmethod
    def _get_time_string(cls, df: pd.DataFrame, idx: int) -> str:
        """获取时间字符串（YYYY-MM-DD 格式）"""
        try:
            if idx < 0 or idx >= len(df):
                return str(idx)
            
            if 'date' in df.columns:
                date_value = df.iloc[idx]['date']
            elif 'trade_date' in df.columns:
                date_value = df.iloc[idx]['trade_date']
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
    
    @classmethod
    def _prepare_ema_data(cls, df, ema_column: str) -> list:
        """
        准备EMA数据
        
        Args:
            df: 包含数据的DataFrame
            ema_column: EMA列名
            
        Returns:
            格式化的EMA数据列表
        """
        ema_data = []
        if ema_column in df.columns:
            for _, row in df.iterrows():
                try:
                    # 处理日期字段，确保格式正确
                    date_value = row['date']
                    
                    # 检查是否为NaN或None
                    if pd.isna(date_value) or date_value is None:
                        continue
                    
                    # 转换为字符串格式
                    if hasattr(date_value, 'strftime'):
                        date_str = date_value.strftime('%Y-%m-%d')
                    else:
                        date_str = str(date_value)
                        # 检查转换后的字符串是否有效
                        if date_str == 'nan' or date_str == 'NaT':
                            continue
                    
                    # 检查EMA值是否有效
                    if not pd.isna(row[ema_column]):
                        ema_data.append({
                            "time": date_str,
                            "value": float(row[ema_column])
                        })
                except Exception as e:
                    logger.warning(f"处理EMA数据行时出错，跳过: {e}")
                    continue
                    
        return ema_data
    
    @classmethod
    def _prepare_markers(cls, df: pd.DataFrame, signals: list) -> list:
        """准备买卖信号标记"""
        markers = []
        
        for signal in signals:
            signal_type = signal.get('type', '')
            
            marker = {
                'time': signal['date'].strftime('%Y-%m-%d') if hasattr(signal['date'], 'strftime') else str(signal['date']).split(' ')[0],
                'position': 'belowBar' if signal_type == 'buy' else 'aboveBar',
                'color': '#f44336' if signal_type == 'buy' else '#4caf50',
                'shape': 'arrowUp' if signal_type == 'buy' else 'arrowDown',
                'text': '买' if signal_type == 'buy' else '卖',
            }
            markers.append(marker)
        
        return markers

