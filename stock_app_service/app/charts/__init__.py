# -*- coding: utf-8 -*-
"""图表绘制模块"""

from typing import Dict, Type, Optional, List, Any

from app.charts.base_chart_strategy import BaseChartStrategy
from app.charts.volume_wave_chart_strategy import VolumeWaveChartStrategy
from app.charts.volume_wave_enhanced_chart_strategy import VolumeWaveEnhancedChartStrategy

# 注册所有可用的图表策略
REGISTERED_CHART_STRATEGIES: Dict[str, Type[BaseChartStrategy]] = {
    VolumeWaveChartStrategy.STRATEGY_CODE: VolumeWaveChartStrategy,
    VolumeWaveEnhancedChartStrategy.STRATEGY_CODE: VolumeWaveEnhancedChartStrategy
}

def get_chart_strategy_by_code(strategy_code: str) -> Optional[Type[BaseChartStrategy]]:
    """
    根据策略代码获取图表策略类
    
    Args:
        strategy_code: 策略唯一标识代码
        
    Returns:
        对应的图表策略类，如果不存在则返回None
    """
    return REGISTERED_CHART_STRATEGIES.get(strategy_code)

def get_all_chart_strategies() -> Dict[str, Dict[str, str]]:
    """
    获取所有注册的图表策略信息
    
    Returns:
        包含所有图表策略信息的字典，键为策略代码，值为包含名称和描述的字典
    """
    return {
        code: {
            "code": code,
            "name": strat.get_strategy_name(),
            "description": strat.get_strategy_description()
        }
        for code, strat in REGISTERED_CHART_STRATEGIES.items()
    }

def generate_chart_html(strategy_code: str, stock_data: Dict[str, Any], **kwargs) -> str:
    """
    使用指定策略生成图表HTML
    
    Args:
        strategy_code: 策略代码
        stock_data: 股票数据字典，包含stock、data、signals等信息
        **kwargs: 策略特定的参数
        
    Returns:
        生成的HTML字符串，如果策略不存在则返回空字符串
    """
    strategy_class = get_chart_strategy_by_code(strategy_code)
    
    if strategy_class:
        return strategy_class.generate_chart_html(stock_data, **kwargs)
    
    # 策略不存在，返回空字符串
    return "" 