# 实时数据更新功能说明

## 更新内容

### 1. Tushare实时接口支持

已添加Tushare实时数据接口支持，使用以下接口：
- `rt_k`: 获取沪深京股票实时日线数据
- `rt_etf_k`: 获取ETF实时日线数据

#### 支持的市场
- 上海主板: 6*.SH
- 深圳主板: 0*.SZ
- 创业板: 3*.SZ
- 北交所: 9*.BJ
- 深市ETF: 1*.SZ
- 沪市ETF: 5*.SH

#### 数据格式
Tushare返回的实时数据字段：
```python
{
    'ts_code': '600000.SH',  # 股票代码（带后缀）
    'name': '浦发银行',       # 股票名称
    'pre_close': 10.50,      # 昨收价
    'open': 10.55,           # 开盘价
    'high': 10.80,           # 最高价
    'low': 10.45,            # 最低价
    'close': 10.75,          # 收盘价（最新价）
    'vol': 12345678,         # 成交量（股）
    'amount': 123456789,     # 成交额（元）
    'num': 10000             # 成交笔数
}
```

转换后的标准格式：
```python
{
    'code': '600000',        # 股票代码（无后缀）
    'name': '浦发银行',
    'price': 10.75,          # 最新价
    'change': 0.25,          # 涨跌额
    'change_pct': 2.38,      # 涨跌幅(%)
    'volume': 12345678,      # 成交量
    'amount': 123456789,     # 成交额
    'open': 10.55,
    'high': 10.80,
    'low': 10.45,
    'pre_close': 10.50
}
```

### 2. 实时更新开关

添加了环境变量控制实时更新功能的开关：

#### 环境变量配置

在 `docker-compose.yml` 中添加以下配置：

```yaml
environment:
  # 实时数据更新配置
  - REALTIME_UPDATE_ENABLED=true       # 是否启用实时数据更新（true/false）
  - REALTIME_DATA_PROVIDER=tushare     # 实时数据提供商（tushare/eastmoney/sina/auto）
  - REALTIME_UPDATE_INTERVAL=20        # 实时更新周期（分钟）
  - REALTIME_AUTO_SWITCH=true          # 数据源自动切换（true/false）
```

#### 配置说明

| 环境变量 | 说明 | 可选值 | 默认值 |
|---------|------|--------|--------|
| REALTIME_UPDATE_ENABLED | 是否启用实时更新 | true/false | false |
| REALTIME_DATA_PROVIDER | 数据提供商 | tushare/eastmoney/sina/auto | tushare |
| REALTIME_UPDATE_INTERVAL | 更新周期（分钟） | 整数 | 20 |
| REALTIME_AUTO_SWITCH | 自动切换数据源 | true/false | true |

### 3. 数据源优先级

当 `REALTIME_DATA_PROVIDER=auto` 时，系统会根据成功率自动选择数据源：

1. **Tushare**（优先）- 官方接口，数据准确
2. **东方财富** - 备用数据源
3. **新浪财经** - 备用数据源

如果主数据源失败且 `REALTIME_AUTO_SWITCH=true`，会自动切换到备用数据源。

### 4. 图表主题色修复

修复了图表生成时主题色传递的问题：

- 在 `chart_service.py` 的 `generate_chart()` 函数中添加了 `theme` 参数
- 确保主题参数正确传递到图表生成函数
- 支持 `light`（亮色）和 `dark`（暗色）两种主题

#### 使用示例

```python
# 生成暗色主题图表
chart_url = generate_chart(db, stock_code='000001', strategy='volume_wave', theme='dark')

# 生成亮色主题图表
chart_url = generate_chart(db, stock_code='000001', strategy='volume_wave', theme='light')
```

## 使用方法

### 1. 启用实时更新

修改 `docker-compose.yml`：

```yaml
environment:
  - REALTIME_UPDATE_ENABLED=true
  - REALTIME_DATA_PROVIDER=tushare
```

### 2. 配置Tushare Token

确保在 `docker-compose.yml` 中配置了有效的Tushare Token：

```yaml
environment:
  - TUSHARE_TOKEN=你的token
```

### 3. 重启服务

```bash
cd stock_app_service
docker-compose down
docker-compose up -d
```

### 4. 测试实时数据

运行测试脚本：

```bash
cd stock_app_service
python test_realtime_tushare.py
```

## API使用

### 获取股票实时数据

```python
from app.services.realtime import get_realtime_service

service = get_realtime_service()

# 获取股票实时数据（不包含ETF）
result = service.get_all_stocks_realtime(provider='tushare', include_etf=False)

if result['success']:
    print(f"获取到 {result['count']} 只股票数据")
    for stock in result['data']:
        print(f"{stock['code']} {stock['name']}: {stock['price']}")
```

### 获取ETF实时数据

```python
# 获取ETF实时数据
result = service.get_all_etfs_realtime(provider='tushare')

if result['success']:
    print(f"获取到 {result['count']} 只ETF数据")
```

### 获取统计信息

```python
stats = service.get_stats()
print(f"总请求数: {stats['total_requests']}")
print(f"Tushare成功: {stats['tushare']['success']}")
print(f"最后更新: {stats['last_update']}")
```

## 注意事项

### 1. Tushare权限

- 需要单独申请Tushare实时数据权限
- 接口限制：单次最大6000条数据
- 建议分批获取以提高性能

### 2. 请求频率

代码中已添加请求间隔控制（0.2秒），避免请求过快：

```python
time.sleep(0.2)  # 避免请求过快
```

### 3. 数据格式一致性

所有数据源返回的数据都会转换为统一格式，确保：
- 股票代码统一为不带后缀的格式（如 `000001`）
- 涨跌额和涨跌幅自动计算
- 字段名统一（`volume` 而不是 `vol`）

### 4. 错误处理

- 支持自动重试（默认3次）
- 支持数据源自动切换
- 详细的错误日志记录

## 性能优化建议

1. **分批获取**: 不建议一次性获取全市场数据，可以分批获取
2. **缓存策略**: 实时数据可以缓存一定时间（如1分钟）
3. **异步处理**: 大量数据获取时使用异步处理
4. **监控告警**: 监控数据源成功率，及时切换

## 故障排查

### 问题1: Tushare Token未配置

**错误信息**: `Tushare Token未配置`

**解决方法**: 在环境变量中配置 `TUSHARE_TOKEN`

### 问题2: 权限不足

**错误信息**: `权限不足` 或 `接口未开通`

**解决方法**: 
1. 登录Tushare官网
2. 申请实时数据接口权限
3. 确认权限已开通

### 问题3: 数据为空

**错误信息**: `返回空数据`

**可能原因**:
1. 非交易时间
2. 市场休市
3. 网络问题

**解决方法**: 检查交易时间和网络连接

### 问题4: 请求过快

**错误信息**: `请求过于频繁`

**解决方法**: 增加请求间隔或减少请求频率

## 更新日志

### 2025-11-11
- ✅ 添加Tushare实时接口支持（股票+ETF）
- ✅ 添加实时更新开关环境变量
- ✅ 修复数据格式一致性问题
- ✅ 修复图表主题色传递问题
- ✅ 添加测试脚本和文档

## 相关文件

- `app/services/realtime/realtime_service.py` - 实时服务主文件
- `app/services/realtime/config.py` - 配置文件
- `app/core/config.py` - 全局配置
- `docker-compose.yml` - Docker配置
- `test_realtime_tushare.py` - 测试脚本

