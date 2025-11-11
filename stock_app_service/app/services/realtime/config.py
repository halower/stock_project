# -*- coding: utf-8 -*-
"""实时行情服务配置（简化版 - 仅Tushare）"""

from pydantic import BaseModel, Field


class RealtimeConfig(BaseModel):
    """实时行情配置（仅Tushare）"""
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
    enable_realtime_update: bool = Field(
        default=True,
        description="是否启用实时数据更新"
    )
    
    class Config:
        use_enum_values = True


# 全局配置实例
realtime_config = RealtimeConfig()


def get_config() -> RealtimeConfig:
    """获取当前配置"""
    return realtime_config
