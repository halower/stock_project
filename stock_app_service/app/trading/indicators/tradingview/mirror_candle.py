# -*- coding: utf-8 -*-
"""
K线镜像翻转指标 - 元数据注册

⚡ 性能优化：实际计算在前端完成
- JavaScript实现：indicator_calculator.js
- 前端计算：按需、实时、不占用服务器资源
- 本文件仅用于：注册指标元数据
"""

import pandas as pd
from typing import List, Dict
from app.trading.indicators.indicator_registry import register_indicator


@register_indicator(
    id='mirror_candle',
    name='对手盘视角',
    category='subchart',
    description='将K线走势进行镜像反转，涨跌完全相反，用于观察不同视角的市场结构。前端实时计算。',
    render_type='subchart',
    enabled_by_default=False,
    default_params={},
    render_config={'render_function': 'renderMirrorSubchart'}
)
def calculate_mirror_candle(df: pd.DataFrame, **params) -> List[Dict]:
    """
    K线镜像翻转 - 元数据注册函数
    
    ⚠️ 注意：此函数仅用于注册指标元数据
    实际计算逻辑在前端 JavaScript 中实现（indicator_calculator.js）
    
    算法逻辑（TradingView Pine Script移植）：
    1. 使用第一根K线的收盘价作为起点
    2. 计算每根K线相对于前一根的涨跌幅
    3. 将涨跌幅取反应用到镜像价格
    4. 高低互换：镜像的高点用原始的低点百分比计算，反之亦然
    
    Args:
        df: K线数据（接口兼容，实际不使用）
        **params: 指标参数
    
    Returns:
        空数据，前端会自动计算
    """
    return []
