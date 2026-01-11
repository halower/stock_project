# -*- coding: utf-8 -*-
"""
ZigZag++ - 之字形指标
移植自 TradingView Pine Script by Dev Lucem

核心功能：
1. 识别价格的重要转折点（高点和低点）
2. 绘制连接转折点的之字形线条
3. 标注市场结构：HH（更高高点）、HL（更高低点）、LH（更低高点）、LL（更低低点）
4. 背景颜色显示当前趋势方向

算法原理（基于MT4 ZigZag）：
- Depth：检测转折点时查看的最小K线数量
- Deviation：识别为有效转折的最小价格变动百分比
- Backstep：回溯步数，防止过近的转折点重叠

应用场景：
- 趋势识别：通过HH/HL判断上涨趋势，LL/LH判断下跌趋势
- 支撑阻力：转折点往往是重要的支撑阻力位
- 波段交易：识别波段的起点和终点

⚡ 性能优化：实际计算在前端完成
- JavaScript实现：indicator_calculator.js
- 本文件仅用于：注册指标元数据
"""

import pandas as pd
from typing import Dict, Any
from app.trading.indicators.indicator_registry import register_indicator


@register_indicator(
    id='zigzag',
    name='价格轨迹',
    category='trend',
    description='智能识别价格转折点并自动画线连接。通过彩色圆点标注转折位置，帮助判断趋势方向。基于MT4经典算法。前端实时计算。',
    render_type='overlay',
    enabled_by_default=False,
    default_params={
        # 核心参数（MT4 ZigZag算法）
        'depth': 12,            # 深度：检测转折点的最小K线数
        'deviation': 5,         # 偏差：最小价格变动百分比
        'backstep': 2,          # 回溯：防止过近转折点的回溯步数
        
        # 显示参数
        'line_thickness': 2,    # 线条粗细
        'show_labels': True,    # 显示转折点标记（彩色圆点）
        'label_size': 'normal', # 标记大小：tiny/small/normal/large/huge
        'extend_line': False,   # 延伸最后一条线到右侧
        'repaint': True,        # 重绘模式（实时更新 vs 确认后显示）
        'show_background': False, # 显示背景颜色（趋势方向）- 默认关闭
        
        # 颜色参数（A股习惯：红涨绿跌）
        'bull_color': 'rgba(239, 83, 80, 0.9)',      # 上涨：红色
        'bear_color': 'rgba(38, 166, 154, 0.9)',     # 下跌：绿色
        'line_transparency': 0,                       # 线条透明度（0-100）
        'label_transparency': 0,                      # 标签透明度（0-100）
        'background_transparency': 85                 # 背景透明度（0-100）
    },
    color='#FF5252',
    render_config={'render_function': 'renderZigZag'}
)
def calculate_zigzag(df: pd.DataFrame, **params) -> Dict[str, Any]:
    """
    ZigZag++ - 元数据注册函数
    
    ⚠️ 实际计算在 indicator_calculator.js 中完成
    
    算法流程：
    1. 从第一根K线开始，寻找初始趋势方向
    2. 根据depth参数检测潜在的高低点
    3. 使用deviation参数验证是否为有效转折
    4. 使用backstep参数避免转折点过密
    5. 计算每个转折点的市场结构标签（HH/HL/LH/LL）
    6. 绘制连接转折点的线条和标签
    
    Args:
        df: K线数据（接口兼容，实际不使用）
        **params: 指标参数
        
    Returns:
        空数据，前端会自动计算
    """
    return {}


