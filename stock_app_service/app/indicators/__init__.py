# -*- coding: utf-8 -*-
"""股票技术指标模块"""

from typing import Dict, Type, Optional, List, Any

from app.indicators.base_strategy import BaseStrategy
from app.indicators.volume_wave_strategy import VolumeWaveStrategy
from app.indicators.volume_wave_enhanced_strategy import VolumeWaveEnhancedStrategy

# 注册所有可用的策略
REGISTERED_STRATEGIES: Dict[str, Type[BaseStrategy]] = {
    VolumeWaveStrategy.STRATEGY_CODE: VolumeWaveStrategy,
    VolumeWaveEnhancedStrategy.STRATEGY_CODE: VolumeWaveEnhancedStrategy
}

def get_strategy_by_code(strategy_code: str) -> Optional[Type[BaseStrategy]]:
    """
    根据策略代码获取策略类
    
    Args:
        strategy_code: 策略唯一标识代码
        
    Returns:
        对应的策略类，如果不存在则返回None
    """
    return REGISTERED_STRATEGIES.get(strategy_code)

def get_all_strategies() -> Dict[str, Dict[str, str]]:
    """
    获取所有注册的策略信息
    
    Returns:
        包含所有策略信息的字典，键为策略代码，值为包含名称和描述的字典
    """
    return {
        code: {
            "code": code,
            "name": strat.get_strategy_name(),
            "description": strat.get_strategy_description()
        }
        for code, strat in REGISTERED_STRATEGIES.items()
    }

def apply_strategy(strategy_code: str, df: Any, **kwargs) -> Any:
    """
    应用指定策略到数据上
    
    Args:
        strategy_code: 策略代码
        df: 包含OHLCV数据的DataFrame
        **kwargs: 策略特定的参数
        
    Returns:
        策略计算的结果，通常是(DataFrame, signals)元组
        如果策略不存在则返回原始数据和空列表
    """
    strategy_class = get_strategy_by_code(strategy_code)
    
    if strategy_class:
        return strategy_class.apply_strategy(df, **kwargs)
    
    # 策略不存在，返回原始数据和空列表
    return df, []

# 导出的API
__all__ = [
    "BaseStrategy",
    "VolumeWaveStrategy",
    "VolumeWaveEnhancedStrategy",
    "get_strategy_by_code",
    "get_all_strategies",
    "apply_strategy",
    "REGISTERED_STRATEGIES"
]