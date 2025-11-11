# ETF盘中更新优化 - 快速参考

## 📌 核心变更

### 盘中更新（9:30-15:00，每20分钟）
```
✅ 股票：实时更新 + 信号计算
❌ ETF：不更新 + 不计算信号
```

### 全量更新（每日17:35）
```
✅ 股票：全量更新 + 信号计算
✅ ETF：全量更新 + 信号计算
```

## 🔧 代码调用

### 盘中实时更新（默认不含ETF）
```python
# 仅更新股票
await stock_atomic_service.realtime_update_all_stocks()
# 等价于
await stock_atomic_service.realtime_update_all_stocks(include_etf=False)

# 仅计算股票信号
await stock_atomic_service.calculate_strategy_signals(stock_only=True)
```

### 全量更新（包含ETF）
```python
# 更新股票 + ETF
await stock_atomic_service.full_update_all_stocks(days=180)

# 计算股票 + ETF信号
await stock_atomic_service.calculate_strategy_signals(
    force_recalculate=True,
    stock_only=False
)
```

### 预留接口（手动触发ETF更新）
```python
# 包含ETF的实时更新
await stock_atomic_service.realtime_update_all_stocks(include_etf=True)
```

## 🌐 API接口

### 实时更新（仅股票）
```bash
POST /api/realtime/test/update
```

### 实时更新（包含ETF，预留）
```bash
POST /api/realtime/test/update-with-etf
```

## 📊 对比表

| 项目 | 盘中更新 | 全量更新 |
|------|---------|---------|
| **频率** | 每20分钟 | 每日17:35 |
| **股票数据** | ✅ 更新 | ✅ 更新 |
| **ETF数据** | ❌ 不更新 | ✅ 更新 |
| **股票信号** | ✅ 计算 | ✅ 计算 |
| **ETF信号** | ❌ 不计算 | ✅ 计算 |
| **API调用** | ~3000次 | ~5500次 |
| **耗时** | ~2-3分钟 | ~8-12分钟 |

## ⚡ 性能提升

- **API调用减少**: 盘中每次减少 ~500次（ETF相关）
- **计算时间减少**: 盘中每次减少 ~30-40%
- **系统负载降低**: CPU和内存使用率明显降低

## 🔄 启用ETF实时更新

如需启用ETF实时更新，修改 `stock_scheduler.py`:

```python
def job_realtime_update():
    result = loop.run_until_complete(
        stock_atomic_service.realtime_update_all_stocks(include_etf=True)  # 改为True
    )

def job_calculate_signals_after_update():
    result = loop.run_until_complete(
        stock_atomic_service.calculate_strategy_signals(
            force_recalculate=False,
            stock_only=False  # 改为False
        )
    )
```

## 📝 相关文件

- `app/services/stock/stock_atomic_service.py`
- `app/services/stock/unified_data_service.py`
- `app/services/scheduler/stock_scheduler.py`
- `app/api/realtime_test.py`

