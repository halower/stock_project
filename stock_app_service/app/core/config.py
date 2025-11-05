# -*- coding: utf-8 -*-
"""股票数据服务配置"""

import os
import sys
from pydantic import BaseModel
from typing import Optional

# Redis配置 - 主要数据存储
REDIS_HOST = os.getenv("REDIS_HOST", "localhost")
REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))
REDIS_DB = int(os.getenv("REDIS_DB", "0"))
REDIS_PASSWORD = os.getenv("REDIS_PASSWORD", None)
REDIS_URL = os.getenv("REDIS_URL", f"redis://{':{}'.format(REDIS_PASSWORD) + '@' if REDIS_PASSWORD else ''}{REDIS_HOST}:{REDIS_PORT}/{REDIS_DB}")

# Redis连接池配置
REDIS_MAX_CONNECTIONS = int(os.getenv("REDIS_MAX_CONNECTIONS", "100"))
REDIS_RETRY_ON_TIMEOUT = True
REDIS_SOCKET_CONNECT_TIMEOUT = int(os.getenv("REDIS_SOCKET_CONNECT_TIMEOUT", "10"))
REDIS_SOCKET_TIMEOUT = int(os.getenv("REDIS_SOCKET_TIMEOUT", "10"))

# 应用基础配置
APP_TITLE = "股票数据智能分析API"
APP_DESCRIPTION = """
## 核心特性
- **高性能架构**: Redis缓存存储，响应速度快
- **智能分析**: 基于AI的股票趋势分析和投资建议  
- **实时数据**: 股票价格更新和市场监控
- **可视化图表**: 动态K线图和技术指标图表
- **策略分析**: 多种投资策略的分析
- **消息面分析**: 基于财经新闻的市场情绪分析
"""
APP_VERSION = "1.0.0"

# 静态文件和图表配置
STATIC_DIR = os.path.join(os.getcwd(), "static")
CHART_DIR = os.path.join(STATIC_DIR, "charts")
CHART_MAX_FILES = int(os.getenv("CHART_MAX_FILES", "1000"))  # 图表文件最大数量

# 缓存配置
CACHE_TTL = 3600  # 标准缓存1小时
CACHE_TTL_SHORT = 300  # 短期缓存5分钟
CACHE_TTL_LONG = 86400  # 长期缓存24小时

# 数据库初始化配置
RESET_TABLES = os.environ.get("RESET_TABLES", "false").lower() == "true"

# 股票系统启动初始化模式配置
STOCK_INIT_MODE = os.environ.get("STOCK_INIT_MODE", "skip").lower()
# 可选值:
# - "skip": 跳过初始化，启动时什么都不执行，等待手动触发（推荐默认模式）
# - "tasks_only": 仅执行任务，不获取历史K线数据，只执行信号计算、新闻获取等任务
# - "full_init": 完整初始化，清空所有数据（股票+ETF）重新获取
# - "etf_only": 仅初始化ETF，只获取和更新ETF数据

# 向后兼容旧配置名称
_old_mode_mapping = {
    "none": "skip",
    "only_tasks": "tasks_only", 
    "clear_all": "full_init"
}
if STOCK_INIT_MODE in _old_mode_mapping:
    STOCK_INIT_MODE = _old_mode_mapping[STOCK_INIT_MODE]

# 后台任务配置 - 控制后台任务对API服务的影响（使用asyncio，无需线程池）
BACKGROUND_TASK_PRIORITY = os.environ.get("BACKGROUND_TASK_PRIORITY", "low").lower()  # low, normal, high

# 外部API配置 - 单个Token（实际每分钟250次请求，设置240次留余量）
TUSHARE_TOKEN = os.getenv("TUSHARE_TOKEN", "76777e0e5682492c8d346030b5f6d7547b77dbab8ddab96d51ab8267")

# AI分析配置
AI_ENABLED = os.getenv("AI_ENABLED", "true").lower() in ("true", "1", "yes")
AI_MAX_TOKENS = int(os.getenv("AI_MAX_TOKENS", "8000"))
AI_TEMPERATURE = float(os.getenv("AI_TEMPERATURE", "0.7"))

# AI服务默认配置
DEFAULT_AI_ENDPOINT = os.getenv("DEFAULT_AI_ENDPOINT", "")
DEFAULT_AI_API_KEY = os.getenv("DEFAULT_AI_API_KEY", "")
DEFAULT_AI_MODEL = os.getenv("DEFAULT_AI_MODEL", "gpt-3.5-turbo")

# API安全配置
API_TOKEN = os.getenv("API_TOKEN", "eXvM4zU8nP9qWt3dRfKgH7jBcA2yE5sZ")
API_TOKEN_ENABLED = os.getenv("API_TOKEN_ENABLED", "false").lower() in ("true", "1", "yes")

# 日志配置
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")

# 历史数据记录数量限制（用于数据库模式，Redis模式不需要）
MAX_HISTORY_RECORDS = int(os.getenv("MAX_HISTORY_RECORDS", "1000"))

# 实时行情配置（股票）
REALTIME_DATA_PROVIDER = os.getenv("REALTIME_DATA_PROVIDER", "eastmoney")  # eastmoney, sina, auto
REALTIME_UPDATE_INTERVAL = int(os.getenv("REALTIME_UPDATE_INTERVAL", "20"))  # 股票实时更新周期，单位：分钟
REALTIME_AUTO_SWITCH = os.getenv("REALTIME_AUTO_SWITCH", "true").lower() in ("true", "1", "yes")  # 数据源自动切换

# ETF实时行情配置
ETF_REALTIME_PROVIDER = os.getenv("ETF_REALTIME_PROVIDER", "eastmoney")  # eastmoney, sina, auto
ETF_UPDATE_INTERVAL = int(os.getenv("ETF_UPDATE_INTERVAL", "30"))  # ETF更新周期，单位：分钟（默认30分钟）
ETF_AUTO_SWITCH = os.getenv("ETF_AUTO_SWITCH", "true").lower() in ("true", "1", "yes")  # ETF数据源自动切换
ETF_RETRY_TIMES = int(os.getenv("ETF_RETRY_TIMES", "2"))  # ETF请求重试次数
ETF_MIN_REQUEST_INTERVAL = float(os.getenv("ETF_MIN_REQUEST_INTERVAL", "3.0"))  # ETF最小请求间隔（秒）

# 动态代理IP配置（实时服务V2）
PROXY_ENABLED = os.getenv("PROXY_ENABLED", "false").lower() in ("true", "1", "yes")  # 是否启用代理
PROXY_API_URL = os.getenv("PROXY_API_URL", "https://share.proxy.qg.net/get")  # 代理API地址
PROXY_API_KEY = os.getenv("PROXY_API_KEY", "")  # 代理API密钥
PROXY_AUTH_PASSWORD = os.getenv("PROXY_AUTH_PASSWORD", "")  # 代理认证密码（Authpwd）
PROXY_POOL_SIZE = int(os.getenv("PROXY_POOL_SIZE", "1"))  # 代理池大小（默认1个，按需获取）
PROXY_REFRESH_INTERVAL = int(os.getenv("PROXY_REFRESH_INTERVAL", "300"))  # 代理刷新间隔（秒）
PROXY_MAX_FAIL_COUNT = int(os.getenv("PROXY_MAX_FAIL_COUNT", "3"))  # 代理最大失败次数


class Settings(BaseModel):
    """应用配置类"""
    
    # Redis配置
    REDIS_HOST: str = REDIS_HOST
    REDIS_PORT: int = REDIS_PORT
    REDIS_DB: int = REDIS_DB
    REDIS_PASSWORD: Optional[str] = REDIS_PASSWORD
    REDIS_URL: str = REDIS_URL
    
    # 外部API配置
    TUSHARE_TOKEN: str = TUSHARE_TOKEN
    
    # 应用配置
    APP_TITLE: str = APP_TITLE
    APP_VERSION: str = APP_VERSION
    
    # 缓存配置
    CACHE_TTL: int = CACHE_TTL
    CACHE_TTL_SHORT: int = CACHE_TTL_SHORT
    CACHE_TTL_LONG: int = CACHE_TTL_LONG
    
    # 股票系统启动初始化模式配置
    STOCK_INIT_MODE: str = STOCK_INIT_MODE
    
    # 后台任务配置（纯异步IO模式，无需线程池）
    BACKGROUND_TASK_PRIORITY: str = BACKGROUND_TASK_PRIORITY
    
    # AI服务配置
    DEFAULT_AI_ENDPOINT: str = DEFAULT_AI_ENDPOINT
    DEFAULT_AI_API_KEY: str = DEFAULT_AI_API_KEY
    DEFAULT_AI_MODEL: str = DEFAULT_AI_MODEL
    
    # 实时行情配置（股票）
    REALTIME_DATA_PROVIDER: str = REALTIME_DATA_PROVIDER
    REALTIME_UPDATE_INTERVAL: int = REALTIME_UPDATE_INTERVAL
    REALTIME_AUTO_SWITCH: bool = REALTIME_AUTO_SWITCH
    
    # ETF实时行情配置
    ETF_REALTIME_PROVIDER: str = ETF_REALTIME_PROVIDER
    ETF_UPDATE_INTERVAL: int = ETF_UPDATE_INTERVAL
    ETF_AUTO_SWITCH: bool = ETF_AUTO_SWITCH
    ETF_RETRY_TIMES: int = ETF_RETRY_TIMES
    ETF_MIN_REQUEST_INTERVAL: float = ETF_MIN_REQUEST_INTERVAL
    
    # 动态代理IP配置
    PROXY_ENABLED: bool = PROXY_ENABLED
    PROXY_API_URL: str = PROXY_API_URL
    PROXY_API_KEY: str = PROXY_API_KEY
    PROXY_POOL_SIZE: int = PROXY_POOL_SIZE
    PROXY_REFRESH_INTERVAL: int = PROXY_REFRESH_INTERVAL
    PROXY_MAX_FAIL_COUNT: int = PROXY_MAX_FAIL_COUNT
    
    class Config:
        case_sensitive = True


# 全局设置实例
settings = Settings()
