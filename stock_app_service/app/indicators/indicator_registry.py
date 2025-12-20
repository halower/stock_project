# -*- coding: utf-8 -*-
"""指标注册表 - 统一管理所有技术指标"""

from typing import Dict, List, Callable, Any, Optional
from dataclasses import dataclass, field
import pandas as pd
from app.core.logging import logger


@dataclass
class IndicatorDefinition:
    """指标定义"""
    id: str                          # 唯一标识
    name: str                        # 显示名称
    category: str                    # 分类：trend/volume/support_resistance/oscillator
    description: str                 # 描述
    calculate_func: Callable         # 计算函数
    default_params: Dict[str, Any]   # 默认参数
    render_type: str                 # 渲染类型：line/overlay/histogram/box
    color: Optional[str] = None      # 默认颜色
    enabled_by_default: bool = False # 是否默认启用
    is_composite: bool = False       # 是否复合指标（如Vegas隧道）
    sub_indicators: List[str] = field(default_factory=list) # 子指标ID列表（复合指标用）


class IndicatorRegistry:
    """指标注册表"""
    
    _indicators: Dict[str, IndicatorDefinition] = {}
    
    @classmethod
    def register(cls, indicator: IndicatorDefinition):
        """注册指标"""
        if indicator.id in cls._indicators:
            logger.warning(f"指标 {indicator.id} 已存在，将被覆盖")
        cls._indicators[indicator.id] = indicator
        logger.info(f"注册指标: {indicator.name} ({indicator.id})")
    
    @classmethod
    def get(cls, indicator_id: str) -> Optional[IndicatorDefinition]:
        """获取指标定义"""
        return cls._indicators.get(indicator_id)
    
    @classmethod
    def get_all(cls) -> Dict[str, IndicatorDefinition]:
        """获取所有指标"""
        return cls._indicators.copy()
    
    @classmethod
    def get_by_category(cls, category: str) -> List[IndicatorDefinition]:
        """按分类获取指标"""
        return [ind for ind in cls._indicators.values() if ind.category == category]
    
    @classmethod
    def calculate(cls, indicator_id: str, df: pd.DataFrame, **params) -> Any:
        """计算指标"""
        indicator = cls.get(indicator_id)
        if not indicator:
            raise ValueError(f"指标 {indicator_id} 不存在")
        
        # 合并默认参数和用户参数
        final_params = {**indicator.default_params, **params}
        
        try:
            return indicator.calculate_func(df, **final_params)
        except Exception as e:
            logger.error(f"计算指标 {indicator_id} 失败: {e}")
            raise


# ============================================================================
# 注册内置指标
# ============================================================================

from app.indicators.tradingview.pivot_order_blocks import calculate_pivot_order_blocks
from app.indicators.tradingview.volume_profile_pivot_anchored import calculate_volume_profile_pivot_anchored
from app.indicators.tradingview.divergence_detector import calculate_divergence_detector

# Volume Profile Pivot Anchored（TradingView移植 - 完整版）
IndicatorRegistry.register(IndicatorDefinition(
    id='volume_profile_pivot',
    name='成交量分布',
    category='volume',
    description='',
    calculate_func=calculate_volume_profile_pivot_anchored,
    default_params={'pivot_length': 20, 'profile_levels': 25, 'value_area_percent': 68.0, 'profile_width': 0.30},
    render_type='overlay',
    enabled_by_default=False
))

# EMA6
IndicatorRegistry.register(IndicatorDefinition(
    id='ema6',
    name='EMA6',
    category='trend',
    description='超短期趋势线',
    calculate_func=lambda df, period=6: df['close'].ewm(span=period, adjust=False).mean(),
    default_params={'period': 6},
    render_type='line',
    color='#00BCD4',
    enabled_by_default=False
))

# EMA12
IndicatorRegistry.register(IndicatorDefinition(
    id='ema12',
    name='EMA12',
    category='trend',
    description='短期趋势线（重要）',
    calculate_func=lambda df, period=12: df['close'].ewm(span=period, adjust=False).mean(),
    default_params={'period': 12},
    render_type='line',
    color='#FFD700',
    enabled_by_default=False  # 默认不显示，用户可选择启用
))

# EMA18
IndicatorRegistry.register(IndicatorDefinition(
    id='ema18',
    name='EMA18',
    category='trend',
    description='中期趋势线（重要）',
    calculate_func=lambda df, period=18: df['close'].ewm(span=period, adjust=False).mean(),
    default_params={'period': 18},
    render_type='line',
    color='#2962FF',
    enabled_by_default=False  # 默认不显示，用户可选择启用
))

# EMA144
IndicatorRegistry.register(IndicatorDefinition(
    id='ema144',
    name='EMA144',
    category='trend',
    description='Vegas隧道下轨',
    calculate_func=lambda df, period=144: df['close'].ewm(span=period, adjust=False).mean(),
    default_params={'period': 144},
    render_type='line',
    color='#00897B',
    enabled_by_default=False
))

# EMA169
IndicatorRegistry.register(IndicatorDefinition(
    id='ema169',
    name='EMA169',
    category='trend',
    description='Vegas隧道上轨',
    calculate_func=lambda df, period=169: df['close'].ewm(span=period, adjust=False).mean(),
    default_params={'period': 169},
    render_type='line',
    color='#D32F2F',
    enabled_by_default=False
))

# 移动均线组合（复合指标）
IndicatorRegistry.register(IndicatorDefinition(
    id='ma_combo',
    name='移动均线组合',
    category='trend',
    description='',
    calculate_func=lambda df: None,  # 复合指标不需要计算函数
    default_params={},
    render_type='line',
    enabled_by_default=True,  # 默认启用
    is_composite=True,
    sub_indicators=['ema6', 'ema18']
))

# Vegas隧道（复合指标）
IndicatorRegistry.register(IndicatorDefinition(
    id='vegas_tunnel',
    name='Vegas隧道',
    category='trend',
    description='',
    calculate_func=lambda df: None,  # 复合指标不需要计算函数
    default_params={},
    render_type='line',
    enabled_by_default=False,
    is_composite=True,
    sub_indicators=['ema12', 'ema144', 'ema169']
))

# Pivot Order Blocks（TradingView移植）
IndicatorRegistry.register(IndicatorDefinition(
    id='pivot_order_blocks',
    name='支撑和阻力区域',
    category='support_resistance',
    description='',
    calculate_func=calculate_pivot_order_blocks,
    default_params={'left': 15, 'right': 8, 'box_count': 2, 'percentage_change': 6.0, 'box_extend_to_end': True},
    render_type='overlay',
    enabled_by_default=False
))

# Divergence Detector（TradingView移植 - 多指标背离检测）
IndicatorRegistry.register(IndicatorDefinition(
    id='divergence_detector',
    name='背离检测',
    category='oscillator',
    description='',
    calculate_func=calculate_divergence_detector,
    default_params={'pivot_period': 5, 'max_pivot_points': 10, 'max_bars': 100, 
                    'check_macd': True, 'check_rsi': True, 'check_stoch': True, 
                    'check_cci': True, 'check_momentum': True},
    render_type='overlay',
    enabled_by_default=False
))

logger.info(f"指标注册表初始化完成，共注册 {len(IndicatorRegistry.get_all())} 个指标")

