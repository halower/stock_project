# -*- coding: utf-8 -*-
"""量价进阶策略 - 在量价突破策略基础上增加趋势过滤"""

import pandas as pd
from typing import List, Dict, Any, Tuple

from app.trading.strategies.volume_wave_strategy import VolumeWaveStrategy
from app.trading.strategies.base_strategy import register_strategy
from app.core.logging import logger

@register_strategy
class VolumeWaveEnhancedStrategy(VolumeWaveStrategy):
    """
    量价进阶策略
    
    【核心逻辑 - 内部文档】
    在量价突破策略基础上增加趋势过滤机制：
    
    继承父类：VolumeWaveStrategy
    - 保留所有Angel/Devil双线交叉逻辑
    - 保留所有技术指标计算
    
    增强过滤：
    1. 买入信号增强：
       - 原始条件：Angel上穿Devil
       - 新增条件：价格 > EMA18（中期趋势确认）
       - 逻辑：只在上升趋势中买入，避免逆势操作
    
    2. 卖出信号增强：
       - 原始条件：Angel下穿Devil
       - 新增条件：必须有持仓记录
       - 逻辑：实现完整的买卖闭环，避免空头信号
    
    技术优势：
    - 降低假突破：EMA18过滤震荡市
    - 提高胜率：只在趋势确认后入场
    - 风险控制：持仓管理，避免过度交易
    
    适用场景：
    - 趋势明确的市场
    - 降低交易频率，提升质量
    - 适合稳健型投资者
    """
    
    # 策略元数据
    STRATEGY_CODE = "volume_wave_enhanced"
    STRATEGY_NAME = "量价进阶"
    STRATEGY_DESCRIPTION = ""  # 不向用户展示策略描述
    
    @classmethod
    def apply_strategy(cls, df: pd.DataFrame, **kwargs) -> Tuple[pd.DataFrame, List[Dict]]:
        """应用增强版波动交易策略 - 买入信号增加EMA18过滤，卖出信号需要有持仓"""
        try:
            # 调用父类方法获取基础信号
            df, base_signals = super().apply_strategy(df, **kwargs)
            
            # 过滤信号：买入需要价格>EMA18，卖出需要有持仓
            filtered_signals = []
            has_position = False  # 持仓状态
            
            for signal in base_signals:
                if signal['type'] == 'buy':
                    # 买入信号需要额外检查：价格 > EMA18 且 当前无持仓
                    if not has_position:
                        idx = signal['index']
                        if idx < len(df):
                            close_price = df['close'].iloc[idx]
                            ema18 = df['ema18'].iloc[idx]
                            
                            # 只有当价格大于EMA18时才保留买入信号
                            if not pd.isna(ema18) and close_price > ema18:
                                filtered_signals.append(signal)
                                has_position = True  # 买入后标记为持仓
                elif signal['type'] == 'sell':
                    # 卖出信号只有在持仓状态下才有效
                    if has_position:
                        filtered_signals.append(signal)
                        has_position = False  # 卖出后清除持仓状态
            
            return df, filtered_signals
            
        except Exception as e:
            logger.error(f"应用增强版策略计算时出错: {str(e)}")
            return df, []

