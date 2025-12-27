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
    render_config: Optional[Dict[str, Any]] = None  # 渲染配置（自描述渲染）


def register_indicator(
    id: str,
    name: str,
    category: str,
    render_type: str = 'line',
    description: str = '',
    default_params: Optional[Dict[str, Any]] = None,
    color: Optional[str] = None,
    enabled_by_default: bool = False,
    is_composite: bool = False,
    sub_indicators: Optional[List[str]] = None,
    render_config: Optional[Dict[str, Any]] = None
):
    """
    装饰器：自动注册指标计算函数
    
    使用示例：
        @register_indicator(
            id="my_indicator",
            name="我的指标",
            category="trend",
            render_type="line",
            color="#FF6B6B"
        )
        def calculate_my_indicator(df, period=20):
            return df['close'].rolling(period).mean()
    
    Args:
        id: 指标唯一标识
        name: 显示名称
        category: 分类 (trend/volume/support_resistance/oscillator/subchart)
        render_type: 渲染类型 (line/overlay/histogram/box/subchart)
        description: 描述
        default_params: 默认参数字典
        color: 默认颜色
        enabled_by_default: 是否默认启用
        is_composite: 是否复合指标
        sub_indicators: 子指标ID列表
        render_config: 渲染配置（自描述渲染，包含series定义、渲染逻辑等）
        
    Returns:
        装饰后的函数（不修改原函数）
    """
    def decorator(func: Callable):
        indicator_def = IndicatorDefinition(
            id=id,
            name=name,
            category=category,
            description=description,
            calculate_func=func,
            default_params=default_params or {},
            render_type=render_type,
            color=color,
            enabled_by_default=enabled_by_default,
            is_composite=is_composite,
            sub_indicators=sub_indicators or [],
            render_config=render_config
        )
        # 直接注册到IndicatorRegistry
        IndicatorRegistry._indicators[id] = indicator_def
        logger.info(f"✅ 装饰器自动注册指标: {name} ({id})")
        return func
    
    return decorator


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

from app.trading.indicators.tradingview.pivot_order_blocks import calculate_pivot_order_blocks
from app.trading.indicators.tradingview.volume_profile_pivot_anchored import calculate_volume_profile_pivot_anchored
from app.trading.indicators.tradingview.divergence_detector import calculate_divergence_detector
from app.trading.indicators.tradingview.mirror_candle import calculate_mirror_candle

# Volume Profile Pivot Anchored（TradingView移植 - 完整版）
IndicatorRegistry.register(IndicatorDefinition(
    id='volume_profile_pivot',
    name='成交量分布',
    category='volume',
    description='',
    calculate_func=calculate_volume_profile_pivot_anchored,
    default_params={'pivot_length': 20, 'profile_levels': 25, 'value_area_percent': 68.0, 'profile_width': 0.30},
    render_type='overlay',
    enabled_by_default=False,
    render_config={'render_function': 'renderVolumeProfilePivot'}
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
    enabled_by_default=False,
    render_config={'render_function': 'renderPivotOrderBlocks'}
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
    enabled_by_default=False,
    render_config={'render_function': 'renderDivergence'}
))

# Mirror Candle（TradingView移植 - K线镜像翻转）
IndicatorRegistry.register(IndicatorDefinition(
    id='mirror_candle',
    name='对手盘视角',
    category='subchart',
    description='',
    calculate_func=calculate_mirror_candle,
    default_params={},
    render_type='subchart',
    enabled_by_default=False,
    render_config={'render_function': 'renderMirrorSubchart'}
))

logger.info(f"指标注册表初始化完成，共注册 {len(IndicatorRegistry.get_all())} 个指标")

