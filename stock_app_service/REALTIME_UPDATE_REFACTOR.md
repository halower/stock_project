# 实时数据更新重构说明

## 📋 重构目标

1. ✅ 将股票实时数据获取改回使用 akshare（更稳定）
2. ✅ 保留 ETF 使用当前的东方财富接口
3. ✅ 优化更新流程：股票实时更新 → ETF实时更新 → 只触发一次信号计算
4. ✅ ETF更新逻辑：当天没有K线则新增，有K线则更新
5. ✅ 将实时更新逻辑独立到单独文件，方便维护

## 📁 新增文件

### `app/services/scheduler/realtime_updater.py`

独立的实时数据更新模块，包含以下功能：

#### 核心函数

1. **`get_stock_realtime_data_akshare()`**
   - 使用 akshare 获取所有股票实时数据
   - 数据源：`ak.stock_zh_a_spot_em()`
   - 返回标准格式的股票实时数据列表

2. **`get_etf_realtime_data()`**
   - 使用东方财富接口获取 ETF 实时数据
   - 只获取配置文件中的 121 个精选 ETF
   - 返回实时数据字典和数据源

3. **`merge_stock_realtime_to_kline()`**
   - 将股票实时数据合并到K线
   - 当天没有K线则新增，有K线则更新
   - 统一使用 tushare 格式

4. **`merge_etf_realtime_to_kline()`**
   - 将 ETF 实时数据合并到K线
   - 当天没有K线则新增，有K线则更新
   - 支持创建、更新、追加三种模式

5. **`update_realtime_data()`**
   - 主入口函数，协调整个更新流程
   - 流程：股票 → ETF → 信号计算（一次）
   - 返回详细的更新结果

## 🔄 更新流程

### 旧流程（问题）
```
1. 获取股票实时数据（V2服务，不稳定）
2. 合并股票数据到K线
3. 获取ETF实时数据
4. 合并ETF数据到K线
5. 触发信号计算（可能触发多次）
```

### 新流程（优化后）
```
1. 使用 akshare 获取股票实时数据（更稳定）
   ├─ 数据源：akshare
   └─ 合并到K线（当天没有则新增，有则更新）

2. 使用东方财富获取 ETF 实时数据
   ├─ 数据源：东方财富
   ├─ 只获取 121 个精选 ETF
   └─ 合并到K线（当天没有则新增，有则更新）

3. 统一触发一次信号计算
   └─ 股票 + ETF 一起计算（避免重复）
```

## 📊 数据格式统一

### 股票K线格式（tushare标准）
```python
{
    'ts_code': '000001.SZ',
    'trade_date': '20251106',
    'open': 10.5,
    'high': 10.8,
    'low': 10.3,
    'close': 10.6,
    'pre_close': 10.4,
    'change': 0.2,
    'pct_chg': 1.92,
    'vol': 1000000,  # 手
    'amount': 10500,  # 千元
    'actual_trade_date': '2025-11-06',
    'is_closing_data': False,
    'update_time': '2025-11-06 14:30:00'
}
```

### ETF K线格式
```python
{
    'date': '2025-11-06',
    'trade_date': '20251106',
    'open': 3.5,
    'high': 3.6,
    'low': 3.4,
    'close': 3.55,
    'volume': 5000000,
    'amount': 17500000,
    'turnover_rate': 2.5,
    'change': 0.05,
    'pct_chg': 1.43,
    'is_closing_data': False,
    'update_time': '2025-11-06 14:30:00'
}
```

## 🔧 修改的文件

### 1. `app/services/scheduler/stock_scheduler.py`

**修改内容：**
- 导入新的 `realtime_updater` 模块
- `update_realtime_stock_data()` 改为包装函数，调用独立模块
- 保留向后兼容性

**修改前：**
```python
def update_realtime_stock_data(...):
    # 直接在这里实现所有逻辑（200+ 行代码）
    realtime_service = get_stock_realtime_service_v2(...)
    result = realtime_service.get_all_stocks_realtime()
    # ... 大量实现代码
```

**修改后：**
```python
from app.services.scheduler.realtime_updater import update_realtime_data

def update_realtime_stock_data(...):
    """包装函数，调用独立模块"""
    if not force_update and not is_trading_time():
        return
    
    result = update_realtime_data(
        force_update=force_update,
        is_closing_update=is_closing_update,
        auto_calculate_signals=auto_calculate_signals
    )
    
    # 记录日志
    if result.get('success'):
        add_stock_job_log(...)
```

### 2. `app/services/scheduler/realtime_updater.py`（新增）

完整的实时数据更新逻辑，独立维护。

## 🎯 优势

### 1. 代码组织更清晰
- 实时更新逻辑独立到单独文件
- `stock_scheduler.py` 从 2000+ 行减少到更易维护的规模
- 职责分离：调度器负责调度，updater负责更新

### 2. 更稳定的数据源
- 股票：akshare（经过验证，更稳定）
- ETF：东方财富（保持原有方式）

### 3. 避免重复计算
- 股票和ETF更新完成后，只触发一次信号计算
- 减少计算资源消耗
- 避免信号数据不一致

### 4. 易于维护和扩展
- 独立文件，修改不影响调度器
- 清晰的函数划分
- 详细的文档注释

### 5. 更好的错误处理
- 每个步骤独立的错误处理
- 详细的日志输出
- 返回结构化的结果

## 📝 使用示例

### 手动触发更新
```python
from app.services.scheduler.realtime_updater import update_realtime_data

# 更新实时数据
result = update_realtime_data(
    force_update=True,
    is_closing_update=False,
    auto_calculate_signals=True
)

print(f"股票成功: {result['stock_success']}")
print(f"ETF成功: {result['etf_success']}")
print(f"总耗时: {result['execution_time']}秒")
```

### 只获取股票实时数据
```python
from app.services.scheduler.realtime_updater import get_stock_realtime_data_akshare

stock_data = get_stock_realtime_data_akshare()
print(f"获取到 {len(stock_data)} 只股票")
```

### 只获取ETF实时数据
```python
from app.services.scheduler.realtime_updater import get_etf_realtime_data

etf_dict, source = get_etf_realtime_data(force_update=True)
print(f"获取到 {len(etf_dict)} 只ETF，数据源: {source}")
```

## 🔍 测试建议

### 1. 单元测试
```bash
# 测试股票数据获取
pytest tests/test_realtime_updater.py::test_get_stock_realtime_data_akshare

# 测试ETF数据获取
pytest tests/test_realtime_updater.py::test_get_etf_realtime_data

# 测试数据合并
pytest tests/test_realtime_updater.py::test_merge_to_kline
```

### 2. 集成测试
```bash
# 手动触发更新
curl -X POST "http://localhost:8000/api/stocks/scheduler/trigger?task_type=update_realtime"

# 查看日志
docker-compose logs -f stock_backend | grep "实时数据更新"
```

### 3. 验证数据
```bash
# 检查Redis中的数据
redis-cli GET "stock:realtime"
redis-cli GET "stock_trend:000001.SZ"
redis-cli GET "etf_trend:510050.SH"
```

## 📈 性能优化

1. **批量处理**：股票数据一次性获取，减少API调用
2. **并发处理**：数据合并时使用合理的并发策略
3. **缓存策略**：实时数据缓存30分钟，K线数据永久存储
4. **错误恢复**：单个股票失败不影响整体流程

## ⚠️ 注意事项

1. **akshare 依赖**：确保已安装 akshare 库
   ```bash
   pip install akshare
   ```

2. **数据源切换**：如果 akshare 不可用，可以快速切换回V2服务
   - 修改 `get_stock_realtime_data_akshare()` 函数
   - 或在 `update_realtime_data()` 中添加降级逻辑

3. **ETF 配置**：ETF 列表来自 `app/core/etf_config.py`
   - 确保配置文件正确
   - 只会获取配置中的 121 个 ETF

4. **信号计算**：默认不自动触发，需要配置
   ```python
   # app/core/config.py
   REALTIME_AUTO_CALCULATE_SIGNALS = True  # 启用自动计算
   ```

## 🚀 后续优化建议

1. **添加数据源降级**：akshare 失败时自动切换到备用源
2. **增加数据验证**：检查获取的数据是否合理
3. **优化合并逻辑**：进一步提升K线合并性能
4. **添加监控指标**：记录成功率、耗时等指标
5. **支持增量更新**：只更新有变化的股票

## 📅 更新日志

### 2025-11-06
- ✅ 创建独立的 `realtime_updater.py` 模块
- ✅ 股票数据源改为 akshare
- ✅ 优化更新流程，避免重复计算信号
- ✅ 实现 ETF 当天K线新增/更新逻辑
- ✅ 完善文档和注释

---

**如有问题，请查看日志或联系开发团队！** 🚀

