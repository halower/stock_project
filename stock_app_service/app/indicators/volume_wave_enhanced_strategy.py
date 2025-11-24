# -*- coding: utf-8 -*-
"""动量守恒增强版策略 - 在原动量守恒策略基础上增加EMA18过滤"""

import pandas as pd
from typing import List, Dict, Any, Tuple

from app.indicators.volume_wave_strategy import VolumeWaveStrategy
from app.core.logging import logger

class VolumeWaveEnhancedStrategy(VolumeWaveStrategy):
    """动量守恒增强版策略 - 买入信号需要价格大于EMA18"""
    
    # 策略元数据
    STRATEGY_CODE = "volume_wave_enhanced"
    STRATEGY_NAME = "动量守恒增强版"
    STRATEGY_DESCRIPTION = "基于动量守恒策略，买入信号需要额外满足价格大于EMA18的条件"
    
    @classmethod
    def apply_strategy(cls, df: pd.DataFrame, **kwargs) -> Tuple[pd.DataFrame, List[Dict]]:
        """应用增强版波动交易策略 - 买入信号增加EMA18过滤"""
        try:
            # 调用父类方法获取基础信号
            df, base_signals = super().apply_strategy(df, **kwargs)
            
            # 过滤买入信号：只保留价格大于EMA18的买入信号
            filtered_signals = []
            
            for signal in base_signals:
                if signal['type'] == 'buy':
                    # 买入信号需要额外检查：价格 > EMA18
                    idx = signal['index']
                    if idx < len(df):
                        close_price = df['close'].iloc[idx]
                        ema18 = df['ema18'].iloc[idx]
                        
                        # 只有当价格大于EMA18时才保留买入信号
                        if not pd.isna(ema18) and close_price > ema18:
                            filtered_signals.append(signal)
                        # else:
                        #     logger.debug(f"过滤掉买入信号: index={idx}, close={close_price:.2f}, ema18={ema18:.2f}")
                else:
                    # 卖出信号保持不变
                    filtered_signals.append(signal)
            
            return df, filtered_signals
            
        except Exception as e:
            logger.error(f"应用增强版策略计算时出错: {str(e)}")
            return df, []

