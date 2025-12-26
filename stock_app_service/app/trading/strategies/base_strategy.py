# -*- coding: utf-8 -*-
"""交易策略抽象基类定义"""

from abc import ABC, abstractmethod
from typing import List, Dict, Tuple, Optional
import pandas as pd

# 全局自动注册表（用于装饰器注册）
_AUTO_REGISTERED_STRATEGIES: Dict[str, type] = {}


def register_strategy(cls):
    """
    装饰器：自动注册策略类
    
    使用示例：
        @register_strategy
        class MyStrategy(BaseStrategy):
            STRATEGY_CODE = "my_strategy"
            ...
    
    Args:
        cls: 策略类
        
    Returns:
        原始类（不修改）
    """
    if not hasattr(cls, 'STRATEGY_CODE'):
        raise ValueError(f"策略类 {cls.__name__} 必须定义 STRATEGY_CODE 属性")
    
    strategy_code = cls.STRATEGY_CODE
    if strategy_code in _AUTO_REGISTERED_STRATEGIES:
        raise ValueError(f"策略代码 {strategy_code} 已被注册")
    
    _AUTO_REGISTERED_STRATEGIES[strategy_code] = cls
    return cls


class BaseStrategy(ABC):
    """
    交易策略抽象基类
    
    所有交易策略都应继承此基类并实现其方法
    
    可选属性：
        CHART_SERIES: Dict - 声明图表需要的特殊系列配置
            示例: {'my_line': {'type': 'line', 'color': '#FF6B6B', 'data_column': 'my_indicator'}}
    """
    
    # 可选的图表系列配置（子类可选声明）
    CHART_SERIES: Dict = {}
    
    @classmethod
    @abstractmethod
    def apply_strategy(cls, df: pd.DataFrame, **kwargs) -> Tuple[pd.DataFrame, List[Dict]]:
        """
        应用策略算法到数据上
        
        Args:
            df: 包含OHLCV数据的DataFrame
            **kwargs: 策略特定的参数
            
        Returns:
            带有策略指标的DataFrame和信号列表
        """
        pass
    
    @classmethod
    def get_strategy_code(cls) -> str:
        """
        获取策略代码
        
        Returns:
            策略唯一标识代码
        """
        return cls.STRATEGY_CODE
    
    @classmethod
    def get_strategy_name(cls) -> str:
        """
        获取策略中文名称
        
        Returns:
            策略的中文名称
        """
        return cls.STRATEGY_NAME
    
    @classmethod
    def get_strategy_description(cls) -> str:
        """
        获取策略描述
        
        Returns:
            策略的详细描述
        """
        return cls.STRATEGY_DESCRIPTION 