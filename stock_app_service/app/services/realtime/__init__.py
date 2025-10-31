# -*- coding: utf-8 -*-
"""
实时行情服务V2 - 支持动态代理IP
包含代理管理和数据获取功能
"""

from .proxy_manager import ProxyManager, get_proxy_manager
from .stock_realtime_service import StockRealtimeServiceV2, get_stock_realtime_service_v2
from .etf_realtime_service import ETFRealtimeServiceV2, get_etf_realtime_service_v2

__all__ = [
    'ProxyManager',
    'get_proxy_manager',
    'StockRealtimeServiceV2',
    'get_stock_realtime_service_v2',
    'ETFRealtimeServiceV2',
    'get_etf_realtime_service_v2',
]

