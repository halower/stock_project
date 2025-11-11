# 实时数据更新功能 - 更新日志

## 更新时间：2025-11-11

## 更新内容

### 1. ✅ 添加Tushare实时接口支持

#### 修改文件
- `app/services/realtime/config.py`
  - 添加 `DataProvider.TUSHARE` 枚举值
  - 添加 `enable_realtime_update` 配置项
  - 从环境变量初始化配置

- `app/services/realtime/realtime_service.py`
  - 添加 `_fetch_tushare_spot()` 方法
  - 支持股票实时数据获取（沪深京三市场）
  - 支持ETF实时数据获取（沪深两市）
  - 更新数据源选择逻辑，优先使用Tushare
  - 添加Tushare统计信息

#### 功能特性
- ✅ 支持沪深京股票实时数据（6*.SH, 0*.SZ, 3*.SZ, 9*.BJ）
- ✅ 支持沪深ETF实时数据（5*.SH, 1*.SZ）
- ✅ 数据格式标准化（统一字段名和单位）
- ✅ 自动计算涨跌额和涨跌幅
- ✅ 请求频率控制（0.2秒间隔）
- ✅ 完整的错误处理和重试机制

### 2. ✅ 添加实时更新开关

#### 修改文件
- `app/core/config.py`
  - 添加 `REALTIME_UPDATE_ENABLED` 环境变量
  - 修改 `REALTIME_DATA_PROVIDER` 默认值为 `tushare`
  - 添加到 `Settings` 类

- `docker-compose.yml`
  - 添加实时数据更新配置环境变量
  ```yaml
  - REALTIME_UPDATE_ENABLED=true
  - REALTIME_DATA_PROVIDER=tushare
  - REALTIME_UPDATE_INTERVAL=20
  - REALTIME_AUTO_SWITCH=true
  ```

#### 配置说明
| 环境变量 | 默认值 | 说明 |
|---------|--------|------|
| REALTIME_UPDATE_ENABLED | false | 是否启用实时更新 |
| REALTIME_DATA_PROVIDER | tushare | 数据提供商 |
| REALTIME_UPDATE_INTERVAL | 20 | 更新周期（分钟） |
| REALTIME_AUTO_SWITCH | true | 自动切换数据源 |

### 3. ✅ 数据格式一致性保证

#### Tushare字段映射

| Tushare字段 | 标准字段 | 说明 |
|------------|---------|------|
| ts_code | code | 股票代码（去除后缀） |
| name | name | 股票名称 |
| close | price | 最新价 |
| pre_close | pre_close | 昨收价 |
| open | open | 开盘价 |
| high | high | 最高价 |
| low | low | 最低价 |
| vol | volume | 成交量（股） |
| amount | amount | 成交额（元） |
| - | change | 涨跌额（计算） |
| - | change_pct | 涨跌幅（计算） |

#### 数据验证
- ✅ 字段名统一（volume 而不是 vol）
- ✅ 股票代码统一（去除.SH/.SZ/.BJ后缀）
- ✅ 涨跌额和涨跌幅自动计算
- ✅ 数据类型转换（确保为float）
- ✅ 空值处理（默认为0）

### 4. ✅ 修复图表主题色传递问题

#### 问题描述
在 `chart_service.py` 的 `generate_chart()` 函数中，调用 `generate_chart_html()` 时没有传递 `theme` 参数，导致主题色失效。

#### 修改文件
- `app/services/chart/chart_service.py`
  - 在 `generate_chart()` 函数签名中添加 `theme` 参数（默认 'dark'）
  - 在调用 `generate_chart_html()` 时传递 `theme=theme`
  - 在生成文件名时包含主题信息

#### 修复效果
- ✅ 主题色正确传递到图表生成函数
- ✅ 支持 light 和 dark 两种主题
- ✅ 图表文件名包含主题信息便于识别

### 5. ✅ 测试和文档

#### 新增文件
1. `test_realtime_tushare.py` - 实时数据测试脚本
   - 测试股票实时数据获取
   - 测试ETF实时数据获取
   - 测试股票+ETF混合获取
   - 显示统计信息

2. `REALTIME_UPDATE_README.md` - 功能说明文档
   - 详细的功能介绍
   - 配置说明
   - 使用方法
   - API文档
   - 故障排查

3. `CHANGELOG_实时更新.md` - 更新日志（本文件）

## 技术细节

### 数据源优先级
当 `REALTIME_DATA_PROVIDER=auto` 时：
1. Tushare（优先）- 官方接口，数据准确
2. 东方财富 - 备用数据源
3. 新浪财经 - 备用数据源

### 请求频率控制
```python
time.sleep(0.2)  # 每个请求间隔0.2秒
```

### 错误处理
- 支持重试（默认3次）
- 支持数据源自动切换
- 详细的日志记录
- 友好的错误提示

### 性能优化
- 分批获取数据（按市场分批）
- 请求间隔控制
- 异常捕获不影响其他市场数据获取

## 使用示例

### 1. 启用实时更新

修改 `docker-compose.yml`：
```yaml
environment:
  - REALTIME_UPDATE_ENABLED=true
  - REALTIME_DATA_PROVIDER=tushare
  - TUSHARE_TOKEN=你的token
```

### 2. 重启服务
```bash
docker-compose down
docker-compose up -d
```

### 3. 运行测试
```bash
python test_realtime_tushare.py
```

### 4. 查看日志
```bash
docker-compose logs -f api
```

## 注意事项

### 1. Tushare权限
- 需要单独申请实时数据接口权限
- 登录 https://tushare.pro 申请权限
- 确认 `rt_k` 和 `rt_etf_k` 接口已开通

### 2. 交易时间
- 实时数据仅在交易时间有效
- 非交易时间可能返回空数据或昨日数据

### 3. 请求限制
- 单次最大6000条数据
- 建议分批获取以提高性能
- 已添加请求间隔控制

### 4. 数据延迟
- Tushare实时数据有一定延迟（通常几秒）
- 不是tick级别的实时数据
- 适合分钟级别的更新

## 兼容性

### 向后兼容
- ✅ 保留原有的东方财富和新浪数据源
- ✅ 保留原有的API接口
- ✅ 默认关闭实时更新（需手动开启）
- ✅ 数据格式统一，不影响现有功能

### 升级路径
1. 更新代码
2. 配置环境变量
3. 重启服务
4. 测试验证

## 测试结果

### 测试环境
- Python 3.9+
- Tushare Pro
- Redis 6.0+

### 测试项目
- [x] Tushare股票实时数据获取
- [x] Tushare ETF实时数据获取
- [x] 数据格式转换
- [x] 涨跌额和涨跌幅计算
- [x] 错误处理和重试
- [x] 数据源自动切换
- [x] 图表主题色传递
- [x] 环境变量配置

### 测试结论
✅ 所有功能正常工作

## 后续优化建议

1. **缓存优化**
   - 添加Redis缓存，避免频繁请求
   - 设置合理的缓存过期时间

2. **性能优化**
   - 使用异步请求提高并发性能
   - 批量处理数据减少数据库操作

3. **监控告警**
   - 添加数据源健康检查
   - 监控请求成功率和响应时间
   - 异常情况自动告警

4. **功能扩展**
   - 支持更多数据源
   - 支持自定义更新频率
   - 支持按股票池更新

## 相关文档

- [Tushare实时数据接口文档](实时接口说明)
- [功能说明文档](REALTIME_UPDATE_README.md)
- [测试脚本](test_realtime_tushare.py)

## 联系方式

如有问题，请查看：
1. 日志文件：`logs/app.log`
2. 错误日志：`logs/error.log`
3. 系统日志：`logs/system.log`

