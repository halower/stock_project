# -*- coding: utf-8 -*-
"""
实时行情服务（优化版）
统一的股票和ETF实时数据获取
"""

from .config import DataProvider, RealtimeConfig, realtime_config, update_config, get_config
from .proxy_manager import ProxyManager, ProxyInfo, get_proxy_manager
from .realtime_service import (
    RealtimeService,
    get_realtime_service,
    get_stock_realtime_service_v2,  # 兼容旧接口
    get_etf_realtime_service_v2      # 兼容旧接口
)

__all__ = [
    # 配置
    'DataProvider',
    'RealtimeConfig',
    'realtime_config',
    'update_config',
    'get_config',
    
    # 代理管理
    'ProxyManager',
    'ProxyInfo',
    'get_proxy_manager',
    
    # 实时服务
    'RealtimeService',
    'get_realtime_service',
    
    # 兼容旧接口
    'get_stock_realtime_service_v2',
    'get_etf_realtime_service_v2',
]
