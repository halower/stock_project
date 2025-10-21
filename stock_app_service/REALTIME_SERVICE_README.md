# 实时行情服务使用说明

## 概述

新的实时行情服务提供了一个统一的接口来获取A股实时行情数据，支持多个数据源（东方财富、新浪财经）的自动切换，提高了系统的稳定性和可靠性。

## 核心特性

### 1. 多数据源支持
- **东方财富（Eastmoney）**: 使用 `ak.stock_zh_a_spot_em()` 接口
- **新浪财经（Sina）**: 使用 `ak.stock_zh_a_spot()` 接口
- **自动模式（Auto）**: 根据历史成功率自动选择最优数据源

### 2. 自动故障切换
- 当主数据源失败时，自动切换到备用数据源
- 支持自定义重试次数
- 记录每个数据源的成功率，优化后续请求

### 3. 统一数据格式
所有数据源返回统一的标准化格式：
```python
{
    'code': str,           # 股票代码
    'name': str,           # 股票名称
    'price': float,        # 最新价
    'change': float,       # 涨跌额
    'change_percent': float, # 涨跌幅
    'volume': float,       # 成交量
    'amount': float,       # 成交额
    'high': float,         # 最高价
    'low': float,          # 最低价
    'open': float,         # 开盘价
    'pre_close': float,    # 昨收价
    'buy': float,          # 买入价
    'sell': float,         # 卖出价
    'turnover_rate': float,# 换手率
    'timestamp': str,      # 时间戳
    'update_time': str     # 更新时间
}
```

### 4. 性能统计
- 实时记录每个数据源的成功/失败次数
- 计算成功率
- 记录最后使用的数据源和更新时间

## 配置说明

### 环境变量配置

在 `.env` 文件或系统环境变量中配置：

```bash
# 默认数据提供商: eastmoney, sina, auto
REALTIME_DATA_PROVIDER=eastmoney

# 实时更新周期（分钟）
REALTIME_UPDATE_INTERVAL=20

# 是否启用数据源自动切换: true, false
REALTIME_AUTO_SWITCH=true
```

### 配置文件

配置定义在 `app/core/config.py` 中：

```python
# 实时行情配置
REALTIME_DATA_PROVIDER = os.getenv("REALTIME_DATA_PROVIDER", "eastmoney")
REALTIME_UPDATE_INTERVAL = int(os.getenv("REALTIME_UPDATE_INTERVAL", "20"))
REALTIME_AUTO_SWITCH = os.getenv("REALTIME_AUTO_SWITCH", "true").lower() in ("true", "1", "yes")
```

## 使用方法

### 1. Python代码中使用

#### 获取所有股票实时数据

```python
from app.services.realtime_service import get_all_stocks_realtime

# 使用默认配置
result = get_all_stocks_realtime()

# 指定数据源
result = get_all_stocks_realtime(provider='eastmoney')
result = get_all_stocks_realtime(provider='sina')
result = get_all_stocks_realtime(provider='auto')

# 返回格式
{
    'success': True,
    'data': [...],  # 股票数据列表
    'count': 5000,  # 股票数量
    'source': 'eastmoney',  # 实际使用的数据源
    'update_time': '2025-10-21 14:30:00'
}
```

#### 获取单只股票实时数据

```python
from app.services.realtime_service import get_single_stock_realtime

# 获取单只股票
result = get_single_stock_realtime('600000')

# 返回格式
{
    'success': True,
    'data': {...},  # 股票数据
    'source': 'eastmoney',
    'update_time': '2025-10-21 14:30:00'
}
```

#### 获取服务统计信息

```python
from app.services.realtime_service import get_realtime_stats

stats = get_realtime_stats()

# 返回格式
{
    'total_requests': 100,
    'eastmoney': {
        'success': 95,
        'fail': 5,
        'success_rate': 95.0
    },
    'sina': {
        'success': 0,
        'fail': 0,
        'success_rate': 0.0
    },
    'last_provider': 'eastmoney',
    'last_update': '2025-10-21T14:30:00',
    'config': {
        'default_provider': 'eastmoney',
        'auto_switch': True,
        'retry_times': 2
    }
}
```

#### 使用服务类

```python
from app.services.realtime_service import RealtimeStockService

# 创建服务实例（自定义配置）
service = RealtimeStockService(
    default_provider='auto',
    auto_switch=True,
    retry_times=3
)

# 获取数据
result = service.get_all_stocks_realtime()

# 获取统计
stats = service.get_stats()

# 重置统计
service.reset_stats()
```

### 2. API接口使用

#### 获取实时行情配置

```bash
GET /api/realtime/config
Authorization: Bearer {token}

# 响应
{
    "default_provider": "eastmoney",
    "auto_switch": true,
    "update_interval": 20,
    "available_providers": ["eastmoney", "sina", "auto"]
}
```

#### 更新实时行情配置

```bash
PUT /api/realtime/config
Authorization: Bearer {token}
Content-Type: application/json

{
    "default_provider": "sina",
    "auto_switch": true
}

# 响应
{
    "code": 200,
    "message": "配置更新成功",
    "data": {
        "default_provider": "sina",
        "auto_switch": true,
        "update_interval": 20
    }
}
```

#### 获取统计信息

```bash
GET /api/realtime/stats
Authorization: Bearer {token}

# 响应
{
    "total_requests": 100,
    "eastmoney": {
        "success": 95,
        "fail": 5,
        "success_rate": 95.0
    },
    "sina": {
        "success": 0,
        "fail": 0,
        "success_rate": 0.0
    },
    "last_provider": "eastmoney",
    "last_update": "2025-10-21T14:30:00",
    "config": {
        "default_provider": "eastmoney",
        "auto_switch": true,
        "retry_times": 2
    }
}
```

#### 重置统计信息

```bash
POST /api/realtime/stats/reset
Authorization: Bearer {token}

# 响应
{
    "code": 200,
    "message": "统计信息已重置",
    "data": {...}
}
```

#### 测试指定数据源

```bash
GET /api/realtime/test/eastmoney
GET /api/realtime/test/sina
Authorization: Bearer {token}

# 响应
{
    "code": 200,
    "message": "数据源 eastmoney 测试成功",
    "data": {
        "provider": "eastmoney",
        "success": true,
        "count": 5000,
        "source": "eastmoney",
        "update_time": "2025-10-21 14:30:00"
    }
}
```

## 与现有系统集成

### 1. 调度器自动更新

`stock_scheduler.py` 中的 `update_realtime_stock_data()` 函数已更新为使用新服务：

```python
def update_realtime_stock_data(force_update=False, is_closing_update=False):
    """更新实时股票数据"""
    # 使用新的统一实时行情服务
    realtime_service = get_realtime_service()
    result = realtime_service.get_all_stocks_realtime()
    
    if not result.get('success'):
        raise Exception(f"获取实时数据失败: {result.get('error')}")
    
    realtime_data = result.get('data', [])
    data_source = result.get('source', 'unknown')
    
    # 存储到Redis
    redis_cache.set_cache(STOCK_KEYS['realtime_data'], {
        'data': realtime_data,
        'count': len(realtime_data),
        'update_time': datetime.now().isoformat(),
        'data_source': data_source,  # 记录实际使用的数据源
        'is_closing_data': is_closing_update
    }, ttl=1800)
```

### 2. Redis股票服务

`redis_stock_service.py` 中的函数已更新：

```python
def get_realtime_stock_data(stock_code: str, provider: str = None) -> Dict[str, Any]:
    """获取股票实时数据，使用统一的实时行情服务"""
    service = get_realtime_service()
    result = service.get_single_stock_realtime(stock_code, provider)
    # 返回标准化数据
    ...
```

## 最佳实践

### 1. 选择合适的数据源

- **生产环境推荐**: `provider='auto'` - 让系统自动选择最优数据源
- **开发/测试**: 可指定特定数据源进行测试
- **高可用性要求**: 启用 `auto_switch=True`

### 2. 监控数据源状态

定期检查统计信息，了解数据源的健康状况：

```python
stats = get_realtime_stats()
if stats['eastmoney']['success_rate'] < 80:
    logger.warning("东方财富数据源成功率低于80%")
```

### 3. 错误处理

```python
result = get_all_stocks_realtime()
if not result.get('success'):
    error = result.get('error', '未知错误')
    logger.error(f"获取实时数据失败: {error}")
    # 执行降级逻辑
```

### 4. 性能优化

- 对于批量查询，优先使用 `get_all_stocks_realtime()` 然后从结果中筛选
- 避免短时间内频繁调用（建议间隔至少1分钟）
- 利用Redis缓存减少API调用

## 故障排查

### 1. 所有数据源都失败

**现象**: 返回 `success: False`，错误信息显示"所有数据源均获取失败"

**可能原因**:
- 网络连接问题
- akshare库版本不兼容
- 数据源API变更
- IP被临时封禁

**解决方法**:
```bash
# 1. 检查网络连接
ping vip.stock.finance.sina.com.cn
ping quote.eastmoney.com

# 2. 更新akshare
pip install --upgrade akshare

# 3. 等待一段时间后重试（避免频繁请求导致封IP）

# 4. 测试单个数据源
curl http://your-api/api/realtime/test/eastmoney
curl http://your-api/api/realtime/test/sina
```

### 2. 数据格式异常

**现象**: 某些字段缺失或格式错误

**原因**: 不同数据源的字段名称可能有细微差异

**解决方法**: 服务已做了字段映射和安全处理，如仍有问题，检查 `realtime_service.py` 中的字段映射逻辑

### 3. 性能问题

**现象**: 获取数据耗时过长

**优化建议**:
- 启用Redis缓存
- 减少调用频率
- 使用 `auto` 模式让系统选择最快的数据源

## 更新日志

### v1.0.0 (2025-10-21)
- ✅ 实现统一的实时行情服务类
- ✅ 支持东方财富和新浪两个数据源
- ✅ 实现自动故障切换机制
- ✅ 添加性能统计功能
- ✅ 提供完整的REST API接口
- ✅ 集成到现有调度器系统
- ✅ 添加配置管理功能

## 技术支持

如有问题或建议，请查看以下文件：
- 服务实现: `app/services/realtime_service.py`
- API接口: `app/api/realtime_config.py`
- 配置文件: `app/core/config.py`
- 调度器集成: `app/services/stock_scheduler.py`

