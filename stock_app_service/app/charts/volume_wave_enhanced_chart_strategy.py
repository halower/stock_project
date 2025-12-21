# -*- coding: utf-8 -*-
"""动量守恒增强版图表策略实现"""

import json
from typing import Dict, Any, List, Tuple, Optional
import pandas as pd
import numpy as np
from app.charts.volume_wave_chart_strategy import VolumeWaveChartStrategy
from app.core.logging import logger

class VolumeWaveEnhancedChartStrategy(VolumeWaveChartStrategy):
    """动量守恒增强版图表策略 - 继承自动量守恒，隐藏策略描述，增加Pivot Order Block"""
    
    # 策略元数据
    STRATEGY_CODE = "volume_wave_enhanced"
    STRATEGY_NAME = "动量守恒增强版"
    STRATEGY_DESCRIPTION = ""  # 空字符串，隐藏策略描述
    
    # Pivot Order Block 配置
    PIVOT_CONFIG = {
        'left': 15,           # 左侧K线数量
        'right': 8,           # 右侧K线数量
        'box_count': 2,       # 最大显示的订单块数量（改为2个，更简洁）
        'percentage_change': 6,  # 右侧价格变化百分比阈值（提高到6%，只显示最重要的订单块）
        'box_extend_to_end': True,  # 订单块向右延伸到最新K线
    }
    
    @classmethod
    def _calculate_pivot_order_blocks(cls, df: pd.DataFrame) -> List[Dict]:
        """
        计算Pivot Order Blocks（枢轴订单块）
        
        基于TradingView的 'Pivot order block boxes [LM]' 指标
        
        Args:
            df: 包含OHLC数据的DataFrame
            
        Returns:
            订单块列表，每个包含 {type, start_time, end_time, high, low, color}
        """
        order_blocks = []
        
        try:
            left = cls.PIVOT_CONFIG['left']
            right = cls.PIVOT_CONFIG['right']
            percentage = cls.PIVOT_CONFIG['percentage_change']
            max_blocks = cls.PIVOT_CONFIG['box_count']
            
            highs = df['high'].values
            lows = df['low'].values
            opens = df['open'].values
            closes = df['close'].values
            
            # 获取时间索引，统一转换为 YYYY-MM-DD 格式
            if 'date' in df.columns:
                times = []
                for _, row in df.iterrows():
                    date_value = row['date']
                    if hasattr(date_value, 'strftime'):
                        times.append(date_value.strftime('%Y-%m-%d'))
                    else:
                        date_str = str(date_value)
                        if len(date_str) == 8:  # 20251128 格式
                            times.append(f"{date_str[:4]}-{date_str[4:6]}-{date_str[6:8]}")
                        else:
                            times.append(date_str)
            elif 'trade_date' in df.columns:
                times = []
                for _, row in df.iterrows():
                    date_value = row['trade_date']
                    if hasattr(date_value, 'strftime'):
                        times.append(date_value.strftime('%Y-%m-%d'))
                    else:
                        date_str = str(date_value)
                        if len(date_str) == 8:  # 20251128 格式
                            times.append(f"{date_str[:4]}-{date_str[4:6]}-{date_str[6:8]}")
                        else:
                            times.append(date_str)
            else:
                times = list(range(len(df)))
            
            n = len(df)
            
            # 检测Pivot High（局部高点）
            for i in range(left, n - right):
                # 检查是否是pivot high
                is_pivot_high = True
                pivot_value = highs[i]
                
                # 检查左侧
                for j in range(1, left + 1):
                    if highs[i - j] >= pivot_value:
                        is_pivot_high = False
                        break
                
                # 检查右侧
                if is_pivot_high:
                    for j in range(1, right + 1):
                        if highs[i + j] > pivot_value:
                            is_pivot_high = False
                            break
                
                if is_pivot_high:
                    # 检查百分比变化是否足够（检查pivot右侧的价格下跌）
                    percentage_met = False
                    for j in range(right + 2):  # 包括pivot右侧的K线
                        if i + j < n:
                            if (pivot_value - highs[i + j]) / pivot_value >= percentage / 100:
                                percentage_met = True
                                break
                    
                    if percentage_met:
                        # 找到对应的订单块K线（向左找第一根阳线）
                        candle_idx = i
                        for j in range(right, right + left):
                            if i - j + right >= 0:
                                idx = i - j + right
                                if opens[idx] <= closes[idx]:  # 阳线
                                    candle_idx = idx
                                    break
                        
                        # 根据配置决定end_time
                        if cls.PIVOT_CONFIG.get('box_extend_to_end', True):
                            end_idx = n - 1  # 延伸到最新K线
                        else:
                            end_idx = min(n - 1, i + right)
                        
                        order_blocks.append({
                            'type': 'high',
                            'start_time': str(times[candle_idx]),
                            'end_time': str(times[end_idx]),
                            'high': float(highs[candle_idx]),
                            'low': float(lows[candle_idx]),
                            'pivot_index': i
                        })
            
            # 检测Pivot Low（局部低点）
            for i in range(left, n - right):
                # 检查是否是pivot low
                is_pivot_low = True
                pivot_value = lows[i]
                
                # 检查左侧
                for j in range(1, left + 1):
                    if lows[i - j] <= pivot_value:
                        is_pivot_low = False
                        break
                
                # 检查右侧
                if is_pivot_low:
                    for j in range(1, right + 1):
                        if lows[i + j] < pivot_value:
                            is_pivot_low = False
                            break
                
                if is_pivot_low:
                    # 检查百分比变化是否足够（检查pivot右侧的价格上涨）
                    percentage_met = False
                    for j in range(right + 2):  # 包括pivot右侧的K线
                        if i + j < n:
                            if (lows[i + j] - pivot_value) / pivot_value >= percentage / 100:
                                percentage_met = True
                                break
                    
                    if percentage_met:
                        # 找到对应的订单块K线（向左找第一根阴线）
                        candle_idx = i
                        for j in range(right, right + left):
                            if i - j + right >= 0:
                                idx = i - j + right
                                if opens[idx] > closes[idx]:  # 阴线
                                    candle_idx = idx
                                    break
                        
                        # 根据配置决定end_time
                        if cls.PIVOT_CONFIG.get('box_extend_to_end', True):
                            end_idx = n - 1  # 延伸到最新K线
                        else:
                            end_idx = min(n - 1, i + right)
                        
                        order_blocks.append({
                            'type': 'low',
                            'start_time': str(times[candle_idx]),
                            'end_time': str(times[end_idx]),
                            'high': float(highs[candle_idx]),
                            'low': float(lows[candle_idx]),
                            'pivot_index': i
                        })
            
            # 按pivot_index排序，只保留最近的max_blocks个（高点和低点分别保留）
            high_blocks = [b for b in order_blocks if b['type'] == 'high']
            low_blocks = [b for b in order_blocks if b['type'] == 'low']
            
            high_blocks.sort(key=lambda x: x['pivot_index'], reverse=True)
            low_blocks.sort(key=lambda x: x['pivot_index'], reverse=True)
            
            # 各保留max_blocks个
            order_blocks = high_blocks[:max_blocks] + low_blocks[:max_blocks]
            
            logger.info(f"计算出 {len(order_blocks)} 个Pivot Order Blocks")
            return order_blocks
            
        except Exception as e:
            logger.error(f"计算Pivot Order Blocks失败: {e}")
            return []
    
    @classmethod
    def _generate_pivot_order_blocks_code(cls, order_blocks: List[Dict], colors: Dict, chart_data: List) -> str:
        """
        生成Pivot Order Blocks的JavaScript绘制代码（优化版本）
        
        使用少量填充线（12条）+ 边界线实现填充效果，性能比100条提升90%以上
        
        Args:
            order_blocks: 订单块列表
            colors: 主题颜色配置
            chart_data: K线数据（用于获取最后时间）
            
        Returns:
            JavaScript代码字符串
        """
        if not order_blocks or not chart_data:
            return ""
        
        try:
            # 获取最后一根K线的时间
            last_time = chart_data[-1]['time'] if chart_data else None
            if not last_time:
                return ""
            
            js_code = "\n// ==================== Pivot Order Blocks (Optimized) ====================\n"
            
            # 优化参数：只用12条线填充（原来100条，减少88%）
            NUM_FILL_LINES = 15
            FILL_LINE_WIDTH = 5  # 稍微加粗，弥补线条减少
            
            for idx, block in enumerate(order_blocks):
                block_type = block['type']
                start_time = block['start_time']
                high = block['high']
                low = block['low']
                
                # 转换时间格式
                if len(start_time) == 8:  # 20251128 格式
                    start_time = f"{start_time[:4]}-{start_time[4:6]}-{start_time[6:8]}"
                
                # 选择颜色 - 使用适中的配色
                if block_type == 'high':
                    # 蓝色系（阻力位）- 提高透明度弥补线条减少
                    bg_color = 'rgba(100, 140, 210, 0.18)'
                    line_color = 'rgba(100, 140, 210, 0.8)'
                else:
                    # 橙色系（支撑位）
                    bg_color = 'rgba(220, 130, 70, 0.18)'
                    line_color = 'rgba(220, 130, 70, 0.8)'
                
                # 构建订单块的数据
                extend_to_end = cls.PIVOT_CONFIG.get('box_extend_to_end', True)
                
                # 找到起始时间在chart_data中的索引
                start_idx = None
                for i, candle in enumerate(chart_data):
                    if candle['time'] >= start_time:
                        start_idx = i
                        break
                
                if start_idx is None:
                    continue
                
                # 如果延伸到最后，则end_idx为最后一根K线，否则只延伸固定距离
                if extend_to_end:
                    end_idx = len(chart_data) - 1
                else:
                    extend_bars = cls.PIVOT_CONFIG.get('box_extend_bars', 8)
                    end_idx = min(start_idx + extend_bars, len(chart_data) - 1)
                
                # 只用起止两点构建线数据（优化数据量）
                line_data_template = [
                    {'time': chart_data[start_idx]['time']},
                    {'time': chart_data[end_idx]['time']}
                ]
                
                price_range = high - low
                
                js_code += f"""
                // Order Block {idx + 1} - {block_type.upper()}
                """
                
                # 绘制填充线（12条，比原来100条减少88%）
                for line_idx in range(NUM_FILL_LINES):
                    price_level = low + (price_range * (line_idx + 0.5) / NUM_FILL_LINES)
                    fill_data = [
                        {'time': chart_data[start_idx]['time'], 'value': price_level},
                        {'time': chart_data[end_idx]['time'], 'value': price_level}
                    ]
                    js_code += f"""
                const obFill{idx}_{line_idx} = chart.addLineSeries({{
                    color: '{bg_color}',
                    lineWidth: {FILL_LINE_WIDTH},
                    lineStyle: 0,
                    lastValueVisible: false,
                    priceLineVisible: false,
                    crosshairMarkerVisible: false,
                    title: '',
                }});
                obFill{idx}_{line_idx}.setData({json.dumps(fill_data)});
                """
                
                # 绘制上下边界虚线
                high_line_data = [
                    {'time': chart_data[start_idx]['time'], 'value': high},
                    {'time': chart_data[end_idx]['time'], 'value': high}
                ]
                low_line_data = [
                    {'time': chart_data[start_idx]['time'], 'value': low},
                    {'time': chart_data[end_idx]['time'], 'value': low}
                ]
                
                js_code += f"""
                const obHighLine{idx} = chart.addLineSeries({{
                    color: '{line_color}',
                    lineWidth: 2,
                    lineStyle: 2,
                    lastValueVisible: false,
                    priceLineVisible: false,
                    crosshairMarkerVisible: false,
                    title: '',
                }});
                obHighLine{idx}.setData({json.dumps(high_line_data)});
                
                const obLowLine{idx} = chart.addLineSeries({{
                    color: '{line_color}',
                    lineWidth: 2,
                    lineStyle: 2,
                    lastValueVisible: false,
                    priceLineVisible: false,
                    crosshairMarkerVisible: false,
                    title: '',
                }});
                obLowLine{idx}.setData({json.dumps(low_line_data)});
                """
            
            logger.info(f"生成了 {len(order_blocks)} 个Pivot Order Blocks的绘制代码（优化版本，每个{NUM_FILL_LINES}条填充线）")
            return js_code
            
        except Exception as e:
            logger.error(f"生成Pivot Order Blocks代码失败: {e}")
            import traceback
            logger.error(traceback.format_exc())
            return ""
    
    @classmethod
    def generate_chart_html(cls, stock_data: Dict[str, Any], **kwargs) -> str:
        """
        生成动量守恒增强版图表HTML（复用父类的所有逻辑，增加Pivot Order Blocks）
        
        Args:
            stock_data: 股票数据字典
            **kwargs: 额外参数（包括theme主题参数）
            
        Returns:
            完整的HTML字符串
        """
        try:
            # 直接调用父类的生成方法，但使用本类的策略名称和描述
            theme = kwargs.get('theme', 'dark')
            colors = cls.get_theme_colors(theme)
            logger.info(f"生成增强版图表使用主题: {theme}")
            
            stock = stock_data['stock']
            df = stock_data['data']
            signals = stock_data['signals']
            
            # 准备基础数据
            chart_data = cls._prepare_chart_data(df)
            markers = cls._prepare_markers(df, signals, colors)
            volume_data = cls._prepare_volume_data(chart_data)
            
            # 准备EMA数据
            ema6_data = cls._prepare_ema_data(df, 'ema6')
            ema12_data = cls._prepare_ema_data(df, 'ema12')
            ema18_data = cls._prepare_ema_data(df, 'ema18')
            ema144_data = cls._prepare_ema_data(df, 'ema144')
            ema169_data = cls._prepare_ema_data(df, 'ema169')
            
            # 计算 Volume Profile Pivot Anchored（新版）
            from app.indicators.tradingview.volume_profile_pivot_anchored import calculate_volume_profile_pivot_anchored
            volume_profile = calculate_volume_profile_pivot_anchored(
                df, 
                pivot_length=20, 
                profile_levels=25, 
                value_area_percent=68.0, 
                profile_width=0.30
            )
            
            # 计算 Pivot Order Blocks
            order_blocks = cls._calculate_pivot_order_blocks(df)
            
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
            
            # 计算镜像K线
            from app.indicators.tradingview.mirror_candle import calculate_mirror_candle
            mirror_data = calculate_mirror_candle(df)
            logger.info(f"镜像K线数据计算完成: {len(mirror_data) if mirror_data else 0} 根")
            
            # 不再自动绘制指标，所有指标通过指标池控制
            # 用户可以在指标池中选择启用/禁用指标
            additional_series = ""
            
            # 生成增强的图例代码（已隐藏）
            additional_scripts = cls._generate_enhanced_legend_code()
            
            # 转换order_blocks格式为指标池需要的格式
            pivot_order_blocks_for_pool = []
            for block in order_blocks:
                pivot_order_blocks_for_pool.append({
                    'type': 'resistance' if block['type'] == 'high' else 'support',
                    'price_high': block['high'],
                    'price_low': block['low'],
                    'start_time': block['start_time'],
                    'end_time': block['end_time'],
                    'strength': 0.8  # 默认强度
                })
            
            # 生成指标池配置和逻辑
            indicator_pool_scripts = cls._generate_indicator_pool_scripts(
                ema6_data, ema12_data, ema18_data, ema144_data, ema169_data, volume_profile, pivot_order_blocks_for_pool, divergence_data, mirror_data
            )
            additional_scripts += indicator_pool_scripts
            
            return cls._generate_base_html_template(
                stock=stock,
                strategy_name=cls.STRATEGY_NAME,
                strategy_desc=cls.STRATEGY_DESCRIPTION,  # 空字符串
                chart_data=chart_data,
                markers=markers,
                volume_data=volume_data,
                additional_series=additional_series,
                additional_scripts=additional_scripts,
                colors=colors
            )
            
        except Exception as e:
            logger.error(f"生成动量守恒增强版图表时出错: {str(e)}")
            return ""

