# -*- coding: utf-8 -*-
"""股票交易策略模块"""

import importlib
from pathlib import Path
from typing import Dict, Type, Optional, Any

from app.core.logging import logger
from app.trading.strategies.base_strategy import BaseStrategy, _AUTO_REGISTERED_STRATEGIES

# 注册所有可用的策略（由自动扫描接管）
REGISTERED_STRATEGIES: Dict[str, Type[BaseStrategy]] = {}


def _auto_discover_strategies() -> Dict[str, Type[BaseStrategy]]:
    """
    自动发现策略模块
    
    扫描app/strategies/目录，自动加载使用@register_strategy装饰器的策略类
    
    Returns:
        自动发现的策略字典
    """
    discovered = {}
    strategies_dir = Path(__file__).parent
    
    logger.info(f"开始自动扫描策略目录: {strategies_dir}")
    
    for file_path in strategies_dir.glob('*.py'):
        if file_path.stem.startswith('_') or file_path.stem == 'base_strategy':
            continue  # 跳过私有文件和基类
        
        module_name = f"app.trading.strategies.{file_path.stem}"
        try:
            importlib.import_module(module_name)
            logger.debug(f"✅ 已加载策略模块: {module_name}")
        except Exception as e:
            logger.warning(f"⚠️ 无法加载策略模块 {module_name}: {e}")
    
    # 从装饰器注册表获取自动注册的策略
    discovered.update(_AUTO_REGISTERED_STRATEGIES)
    
    if discovered:
        logger.info(f"✅ 自动发现 {len(discovered)} 个策略: {list(discovered.keys())}")
    else:
        logger.debug("未发现自动注册的策略")
    
    return discovered


# 自动发现并合并策略
_auto_strategies = _auto_discover_strategies()
for code, strategy_class in _auto_strategies.items():
    if code not in REGISTERED_STRATEGIES:
        REGISTERED_STRATEGIES[code] = strategy_class
        logger.info(f"📝 已自动注册策略: {code} ({strategy_class.STRATEGY_NAME})")
    else:
        logger.debug(f"策略 {code} 已手动注册，跳过自动注册")


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
    "get_strategy_by_code",
    "get_all_strategies",
    "apply_strategy",
    "REGISTERED_STRATEGIES"
]
