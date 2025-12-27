# -*- coding: utf-8 -*-
"""
股票技术指标模块

此模块仅包含技术指标（用于图表显示面板），不包含策略。
策略相关内容请参考 app.trading.strategies 模块。
"""

# 导入所有TradingView指标模块，以触发@register_indicator装饰器
from app.trading.indicators.tradingview import (
    divergence_detector,
    mirror_candle,
    support_resistance_channels,  # 支撑阻力通道（新）
    volume_profile_pivot_anchored,
    smart_money_concepts,  # 聪明钱概念
)

# 指标相关内容会从indicator_registry导出
# 此文件主要用于模块组织

__all__ = []
