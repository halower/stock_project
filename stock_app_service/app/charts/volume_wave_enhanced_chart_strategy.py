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
        'box_extend_bars': 8,  # 订单块向右延伸的K线数量（改为8根，短小精悍）
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
            
            # 获取时间索引
            if 'trade_date' in df.columns:
                times = df['trade_date'].values
            elif 'date' in df.columns:
                times = df['date'].values
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
                        
                        order_blocks.append({
                            'type': 'high',
                            'start_time': str(times[candle_idx]),
                            'end_time': str(times[min(n - 1, i + right)]),
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
                        
                        order_blocks.append({
                            'type': 'low',
                            'start_time': str(times[candle_idx]),
                            'end_time': str(times[min(n - 1, i + right)]),
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
        生成Pivot Order Blocks的JavaScript绘制代码
        
        使用AreaSeries绘制填充的矩形区域（类似TradingView的box效果）
        
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
            
            js_code = "\n// ==================== Pivot Order Blocks ====================\n"
            
            for idx, block in enumerate(order_blocks):
                block_type = block['type']
                start_time = block['start_time']
                high = block['high']
                low = block['low']
                
                # 转换时间格式
                if len(start_time) == 8:  # 20251128 格式
                    start_time = f"{start_time[:4]}-{start_time[4:6]}-{start_time[6:8]}"
                
                # 选择颜色 - 使用适中的配色（稍微加深）
                if block_type == 'high':
                    # 蓝色系（阻力位）- 适中清晰
                    top_color = 'rgba(100, 140, 210, 0.18)'
                    bottom_color = 'rgba(100, 140, 210, 0.10)'
                    line_color = 'rgba(100, 140, 210, 0.68)'  # 稍微加深
                else:
                    # 橙色系（支撑位）- 适中清晰
                    top_color = 'rgba(220, 130, 70, 0.18)'
                    bottom_color = 'rgba(220, 130, 70, 0.10)'
                    line_color = 'rgba(220, 130, 70, 0.68)'  # 稍微加深
                
                # 构建订单块的区域数据（只延伸固定距离，不延伸到最右侧）
                block_area_data = []
                extend_bars = cls.PIVOT_CONFIG.get('box_extend_bars', 30)
                
                # 找到起始时间在chart_data中的索引
                start_idx = None
                for i, candle in enumerate(chart_data):
                    if candle['time'] >= start_time:
                        start_idx = i
                        break
                
                if start_idx is not None:
                    # 只延伸extend_bars根K线
                    end_idx = min(start_idx + extend_bars, len(chart_data))
                    for i in range(start_idx, end_idx):
                        block_area_data.append({
                            'time': chart_data[i]['time'],
                            'value': high  # 区域的顶部
                        })
                
                if not block_area_data:
                    continue
                
                # 生成订单块区域（使用AreaSeries模拟矩形）
                block_label = "支撑位" if block_type == 'low' else "阻力位"
                js_code += f"""
                // Order Block {idx + 1} - {block_type.upper()} ({block_label})
                const obArea{idx} = chart.addAreaSeries({{
                    topColor: '{top_color}',
                    bottomColor: '{bottom_color}',
                    lineColor: '{line_color}',
                    lineWidth: 2,  // 加粗线条
                    lineStyle: 2,  // 虚线
                    lastValueVisible: false,
                    priceLineVisible: false,
                    crosshairMarkerVisible: false,
                    title: '',
                }});
                
                // 设置区域数据（顶部为high）
                obArea{idx}.setData({json.dumps(block_area_data)});
                
                // 添加底部价格线（low）来形成矩形效果
                obArea{idx}.createPriceLine({{
                    price: {low},
                    color: '{line_color}',
                    lineWidth: 2,  // 加粗线条
                    lineStyle: 2,  // 虚线
                    axisLabelVisible: false,
                    title: '',
                }});
                """
            
            logger.info(f"生成了 {len(order_blocks)} 个Pivot Order Blocks的绘制代码（矩形区域）")
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
            
            # 计算 Volume Profile
            from app.indicators.volume_profile import calculate_volume_profile
            volume_profile = calculate_volume_profile(df, num_bars=150, row_size=24, percent=70.0)
            
            # 计算 Pivot Order Blocks
            order_blocks = cls._calculate_pivot_order_blocks(df)
            
            # 生成EMA系列和Vegas隧道的JavaScript代码
            ema_series_code = cls._generate_enhanced_ema_series_code(
                ema6_data, ema12_data, ema18_data, ema144_data, ema169_data, colors
            )
            
            # 生成 Volume Profile 覆盖层代码
            volume_profile_code = cls._generate_volume_profile_overlay(volume_profile, colors, chart_data)
            
            # 生成 Pivot Order Blocks 代码
            pivot_ob_code = cls._generate_pivot_order_blocks_code(order_blocks, colors, chart_data)
            
            # 合并所有附加系列代码
            additional_series = ema_series_code + volume_profile_code + pivot_ob_code
            
            # 生成增强的图例代码（已隐藏）
            additional_scripts = cls._generate_enhanced_legend_code()
            
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

