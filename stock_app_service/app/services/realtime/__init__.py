# -*- coding: utf-8 -*-
"""
实时行情服务（简化版 - 仅Tushare）
统一的股票和ETF实时数据获取
"""

from .config import RealtimeConfig, realtime_config, get_config
from .realtime_service import RealtimeService, get_realtime_service

__all__ = [
    # 配置
    'RealtimeConfig',
    'realtime_config',
    'get_config',
    
    # 实时服务
    'RealtimeService',
    'get_realtime_service',
]
