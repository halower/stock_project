# -*- coding: utf-8 -*-
"""交易策略抽象基类定义"""

from abc import ABC, abstractmethod
from typing import List, Dict, Tuple
import pandas as pd

class BaseStrategy(ABC):
    """
    交易策略抽象基类
    
    所有交易策略都应继承此基类并实现其方法
    """
    
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