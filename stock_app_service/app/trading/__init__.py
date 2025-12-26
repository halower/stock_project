# -*- coding: utf-8 -*-
"""
交易分析统一模块

此模块整合了策略、指标和图表渲染功能，提供统一的交易分析能力。

目录结构：
- strategies/: 交易策略（筛选股票、生成信号）
- indicators/: 技术指标（图表分析工具）
- renderers/: 图表渲染器（可视化展示）
"""

# 导出策略相关API
from app.trading.strategies import (
    BaseStrategy,
    get_strategy_by_code,
    get_all_strategies,
    apply_strategy,
    REGISTERED_STRATEGIES
)

# 导出图表渲染相关API
from app.trading.renderers import (
    BaseChartStrategy,
    REGISTERED_CHART_STRATEGIES,
    get_chart_strategy_by_code,
    generate_chart_html
)

# 导出指标注册相关API
from app.trading.indicators.indicator_registry import IndicatorRegistry

__all__ = [
    # 策略
    "BaseStrategy",
    "get_strategy_by_code",
    "get_all_strategies",
    "apply_strategy",
    "REGISTERED_STRATEGIES",
    # 图表
    "BaseChartStrategy",
    "REGISTERED_CHART_STRATEGIES",
    "get_chart_strategy_by_code",
    "generate_chart_html",
    # 指标
    "IndicatorRegistry",
]


