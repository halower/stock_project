# -*- coding: utf-8 -*-
"""实时行情服务配置"""

from enum import Enum
from typing import Optional
from pydantic import BaseModel, Field


class DataProvider(str, Enum):
    """数据提供商"""
    TUSHARE = "tushare"      # Tushare（优先）
    EASTMONEY = "eastmoney"  # 东方财富
    SINA = "sina"            # 新浪财经
    AUTO = "auto"            # 自动选择


class RealtimeConfig(BaseModel):
    """实时行情配置"""
    default_provider: DataProvider = Field(
        default=DataProvider.AUTO,
        description="默认数据提供商"
    )
    auto_switch: bool = Field(
        default=True,
        description="是否自动切换数据源"
    )
    retry_times: int = Field(
        default=3,
        description="重试次数",
        ge=1,
        le=10
    )
    timeout: int = Field(
        default=10,
        description="请求超时时间（秒）",
        ge=5,
        le=60
    )
    enable_proxy: bool = Field(
        default=False,
        description="是否启用代理"
    )
    enable_realtime_update: bool = Field(
        default=False,
        description="是否启用实时数据更新"
    )
    
    class Config:
        use_enum_values = True


# 从环境变量初始化配置
def _init_config_from_env() -> RealtimeConfig:
    """从环境变量初始化配置"""
    from app.core.config import (
        REALTIME_DATA_PROVIDER,
        REALTIME_AUTO_SWITCH,
        REALTIME_UPDATE_ENABLED
    )
    
    return RealtimeConfig(
        default_provider=DataProvider(REALTIME_DATA_PROVIDER) if REALTIME_DATA_PROVIDER in ['tushare', 'eastmoney', 'sina', 'auto'] else DataProvider.AUTO,
        auto_switch=REALTIME_AUTO_SWITCH,
        enable_realtime_update=REALTIME_UPDATE_ENABLED
    )

# 全局配置实例
realtime_config = _init_config_from_env()


def update_config(
    default_provider: Optional[str] = None,
    auto_switch: Optional[bool] = None,
    retry_times: Optional[int] = None,
    timeout: Optional[int] = None,
    enable_proxy: Optional[bool] = None,
    enable_realtime_update: Optional[bool] = None
):
    """更新配置"""
    global realtime_config
    
    if default_provider is not None:
        realtime_config.default_provider = DataProvider(default_provider)
    if auto_switch is not None:
        realtime_config.auto_switch = auto_switch
    if retry_times is not None:
        realtime_config.retry_times = retry_times
    if timeout is not None:
        realtime_config.timeout = timeout
    if enable_proxy is not None:
        realtime_config.enable_proxy = enable_proxy
    if enable_realtime_update is not None:
        realtime_config.enable_realtime_update = enable_realtime_update


def get_config() -> RealtimeConfig:
    """获取当前配置"""
    return realtime_config

