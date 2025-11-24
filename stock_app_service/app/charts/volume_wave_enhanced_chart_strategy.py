# -*- coding: utf-8 -*-
"""动量守恒增强版图表策略实现"""

from typing import Dict, Any
from app.charts.volume_wave_chart_strategy import VolumeWaveChartStrategy
from app.core.logging import logger

class VolumeWaveEnhancedChartStrategy(VolumeWaveChartStrategy):
    """动量守恒增强版图表策略 - 继承自动量守恒，隐藏策略描述"""
    
    # 策略元数据
    STRATEGY_CODE = "volume_wave_enhanced"
    STRATEGY_NAME = "动量守恒增强版"
    STRATEGY_DESCRIPTION = ""  # 空字符串，隐藏策略描述
    
    @classmethod
    def generate_chart_html(cls, stock_data: Dict[str, Any], **kwargs) -> str:
        """
        生成动量守恒增强版图表HTML（复用父类的所有逻辑）
        
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
            
            # 生成EMA系列和Vegas隧道的JavaScript代码
            ema_series_code = cls._generate_enhanced_ema_series_code(
                ema6_data, ema12_data, ema18_data, ema144_data, ema169_data, colors
            )
            
            # 生成 Volume Profile 覆盖层代码
            volume_profile_code = cls._generate_volume_profile_overlay(volume_profile, colors, chart_data)
            
            # 合并所有附加系列代码
            additional_series = ema_series_code + volume_profile_code
            
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

