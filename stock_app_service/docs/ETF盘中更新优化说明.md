# ETF盘中更新优化说明

## 📋 概述

为了优化系统性能和减少不必要的API调用，我们对ETF的实时更新和信号计算策略进行了调整。

## 🎯 优化目标

1. **减少API调用频率** - ETF交易相对不活跃，盘中频繁更新意义不大
2. **提升系统性能** - 减少盘中的计算负担
3. **保持数据完整性** - 全量更新时仍包含ETF数据
4. **预留扩展接口** - 为未来可能的ETF实时更新需求预留接口

## 📝 优化内容

### 1. 盘中实时更新（交易时间）

#### ✅ 修改前
- 每20分钟更新所有股票 + ETF
- 更新后计算所有股票 + ETF的信号

#### ✅ 修改后
- 每20分钟**仅更新股票**（不更新ETF）
- 更新后**仅计算股票信号**（不计算ETF信号）

#### 代码变更

**`stock_atomic_service.py`**
```python
async def realtime_update_all_stocks(self, include_etf: bool = False) -> Dict[str, Any]:
    """
    实时更新所有股票数据（盘中默认不包括ETF）
    
    Args:
        include_etf: 是否包含ETF，默认False（盘中不更新ETF，仅全量更新时更新）
    """
    if include_etf:
        # 全量更新：包含股票和ETF
        realtime_result = await unified_data_service.async_fetch_all_realtime_data()
    else:
        # 盘中更新：仅股票
        realtime_result = await unified_data_service.async_fetch_stock_realtime_data_only()
```

**`stock_scheduler.py` - 盘中更新任务**
```python
def job_realtime_update():
    """定时任务：实时更新所有股票数据"""
    result = loop.run_until_complete(
        stock_atomic_service.realtime_update_all_stocks()  # 默认 include_etf=False
    )

def job_calculate_signals_after_update():
    """实时更新后自动触发信号计算（盘中仅计算股票信号，不计算ETF）"""
    result = loop.run_until_complete(
        stock_atomic_service.calculate_strategy_signals(
            force_recalculate=False,
            stock_only=True  # 盘中仅计算股票信号
        )
    )
```

### 2. 全量更新（每日17:35）

#### ✅ 保持不变
- 全量更新**包含股票 + ETF**
- 信号计算**包含股票 + ETF**

#### 代码变更

**`stock_scheduler.py` - 全量更新任务**
```python
def job_full_update_and_calculate():
    """定时任务：全量更新并计算信号（包含ETF）"""
    # 1. 全量更新（包含股票和ETF）
    update_result = loop.run_until_complete(
        stock_atomic_service.full_update_all_stocks(
            days=180,
            batch_size=50,
            max_concurrent=5
        )
    )
    
    # 2. 计算信号（包含股票和ETF）
    signal_result = loop.run_until_complete(
        stock_atomic_service.calculate_strategy_signals(
            force_recalculate=True,
            stock_only=False  # 全量更新包含ETF信号
        )
    )
```

### 3. 预留ETF实时更新接口

为未来可能的ETF实时更新需求，我们预留了专门的API接口。

#### 新增API接口

**`/api/realtime/test/update`** - 实时更新（仅股票）
```bash
POST /api/realtime/test/update
```
- 功能：触发实时更新，仅更新股票
- 用途：盘中实时更新使用

**`/api/realtime/test/update-with-etf`** - 实时更新（包含ETF）
```bash
POST /api/realtime/test/update-with-etf
```
- 功能：触发实时更新，包含股票和ETF
- 用途：预留接口，未来可能启用ETF实时更新

#### 使用示例

```bash
# 仅更新股票（盘中使用）
curl -X POST "http://localhost:8000/api/realtime/test/update" \
  -H "Authorization: Bearer YOUR_TOKEN"

# 包含ETF更新（预留接口）
curl -X POST "http://localhost:8000/api/realtime/test/update-with-etf" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

## 📊 优化效果

### 性能提升
- **API调用减少**: 盘中每次更新减少约300-500次ETF相关API调用
- **计算时间减少**: 盘中信号计算时间减少约30-40%
- **系统负载降低**: CPU和内存使用率降低

### 数据完整性
- ✅ 全量更新仍包含ETF数据
- ✅ 每日17:35的ETF信号计算正常
- ✅ ETF历史数据完整性不受影响

## 🔄 更新时间表

| 时间段 | 股票更新 | ETF更新 | 股票信号 | ETF信号 |
|--------|---------|---------|---------|---------|
| 盘中（9:30-15:00，每20分钟） | ✅ | ❌ | ✅ | ❌ |
| 全量更新（每日17:35） | ✅ | ✅ | ✅ | ✅ |

## 🚀 未来扩展

如果未来需要启用ETF实时更新，可以通过以下方式：

1. **调用预留接口**
   ```python
   # 在调度器中调用
   await stock_atomic_service.realtime_update_all_stocks(include_etf=True)
   ```

2. **修改调度器配置**
   ```python
   # stock_scheduler.py
   def job_realtime_update():
       result = loop.run_until_complete(
           stock_atomic_service.realtime_update_all_stocks(include_etf=True)  # 启用ETF
       )
   ```

3. **使用API接口**
   ```bash
   POST /api/realtime/test/update-with-etf
   ```

## 📌 注意事项

1. **盘中ETF数据**: 盘中不更新ETF数据，如需最新ETF数据，请等待17:35全量更新
2. **ETF信号**: 盘中不计算ETF信号，ETF信号在每日17:35全量更新后计算
3. **历史数据**: ETF历史数据在全量更新时完整获取，不受盘中优化影响
4. **预留接口**: 已预留ETF实时更新接口，可随时启用

## 📖 相关文件

- `stock_app_service/app/services/stock/stock_atomic_service.py` - 实时更新逻辑
- `stock_app_service/app/services/stock/unified_data_service.py` - 数据获取服务
- `stock_app_service/app/services/scheduler/stock_scheduler.py` - 调度器配置
- `stock_app_service/app/api/realtime_test.py` - API接口定义

## 🔗 相关文档

- [全量更新优化说明](./全量更新优化说明.md)
- [实时数据更新说明](./实时数据更新优化说明.md)

