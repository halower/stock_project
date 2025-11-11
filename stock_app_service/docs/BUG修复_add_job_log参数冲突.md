# BUG修复说明 - add_job_log 参数冲突

## 修复时间
2025-11-11

## 问题描述

### 错误信息
```
stock_app - ERROR - >>> 任务失败: 计算信号失败: add_job_log() got multiple values for argument 'status'
```

### 问题原因

`stock_scheduler.py` 中有两处调用 `add_job_log` 时出现参数冲突：

1. **启动任务中**（第247-254行）
2. **运行时任务中**（第353-361行）

#### 函数签名
```python
def add_job_log(job_type: str, status: str, message: str, **kwargs):
```

#### 错误调用方式
```python
result = await stock_atomic_service.calculate_strategy_signals()

# result 中包含 'status' 字段
# 使用 **result 解包时，status 被传递两次
add_job_log(
    'calculate_signals',
    'success',  # 第一次传递 status
    f"计算信号完成",
    **result  # result 中包含 'status'，第二次传递
)
```

#### result 返回结构
来自 `signal_manager.py` 的 `calculate_buy_signals` 方法：

```python
return {
    "status": "success",  # ← 包含 status 字段
    "message": f"买入信号计算完成",
    "total_signals": total_signals,
    "strategy_counts": strategy_counts,
    "processed_stocks": processed_stocks,
    "valid_data_stocks": valid_data_stocks,
    "elapsed_seconds": total_elapsed
}
```

## 修复方案

### 方案：过滤掉 result 中的 status 字段

在调用 `add_job_log` 前，从 `result` 中排除 `status` 字段：

```python
# 从result中排除status字段，避免参数冲突
result_data = {k: v for k, v in result.items() if k != 'status'}
add_job_log(
    'calculate_signals',
    'success' if result.get('success') or result.get('status') == 'success' else 'error',
    f"计算信号完成",
    **result_data  # 使用过滤后的数据
)
```

## 修复位置

### 1. 启动任务 - task_calculate_signals
**文件**: `app/services/scheduler/stock_scheduler.py`  
**行号**: 247-254

**修复前**:
```python
add_job_log(
    'calculate_signals',
    'success' if result.get('success') else 'error',
    f"计算信号完成",
    **result
)
```

**修复后**:
```python
# 从result中排除status字段，避免参数冲突
result_data = {k: v for k, v in result.items() if k != 'status'}
add_job_log(
    'calculate_signals',
    'success' if result.get('success') or result.get('status') == 'success' else 'error',
    f"计算信号完成",
    **result_data
)
```

### 2. 运行时任务 - job_calculate_signals
**文件**: `app/services/scheduler/stock_scheduler.py`  
**行号**: 353-361

**修复前**:
```python
add_job_log(
    'signal_calculation',
    'success',
    f'信号计算完成',
    elapsed_seconds=round(elapsed, 2),
    **result
)
```

**修复后**:
```python
# 从result中排除status字段，避免参数冲突
result_data = {k: v for k, v in result.items() if k != 'status'}
add_job_log(
    'signal_calculation',
    'success' if result.get('success') or result.get('status') == 'success' else 'warning',
    f'信号计算完成',
    elapsed_seconds=round(elapsed, 2),
    **result_data
)
```

## 关于实时更新任务的说明

### 用户疑问
> "实时更新是在盘中每分钟才对吧？"

### 答案：是的，配置正确 ✅

#### 任务注册（第535-545行）
```python
# 实时数据更新：每分钟执行一次
realtime_interval = settings.REALTIME_UPDATE_INTERVAL  # 默认1分钟
scheduler.add_job(
    func=RuntimeTasks.job_realtime_update,
    trigger=IntervalTrigger(minutes=realtime_interval),
    id='realtime_update',
    name='实时数据更新',
    replace_existing=True
)
```

#### 交易时间检查（第268-273行）
```python
@staticmethod
def job_realtime_update():
    """定时任务：实时更新所有股票数据"""
    # 检查是否为交易时间
    if not is_trading_time():
        logger.debug("非交易时间，跳过实时数据更新")
        return  # ← 非交易时间直接返回，不执行更新
    
    # ... 执行更新逻辑
```

#### is_trading_time() 函数（第59-89行）
```python
def is_trading_time() -> bool:
    """
    检查当前是否为A股交易时间
    
    交易时间：
    - 周一至周五
    - 上午：09:15-11:30 (集合竞价: 09:15-09:25)
    - 下午：13:00-15:00
    """
    now = datetime.now()
    current_time = now.time()
    weekday = now.weekday()
    
    # 周末不交易
    if weekday >= 5:
        return False
    
    # 上午交易时间：09:15-11:30
    morning_start = time(9, 15)
    morning_end = time(11, 30)
    
    # 下午交易时间：13:00-15:00
    afternoon_start = time(13, 0)
    afternoon_end = time(15, 0)
    
    return (morning_start <= current_time <= morning_end or
            afternoon_start <= current_time <= afternoon_end)
```

### 结论

实时更新任务的配置完全正确：

1. ✅ **每分钟触发一次** - 确保不错过任何数据
2. ✅ **但只在交易时间执行** - 非交易时间自动跳过
3. ✅ **覆盖完整交易时段** - 09:15-11:30 和 13:00-15:00

这样的设计既保证了数据的及时性，又避免了在非交易时间的无效轮询。

## 其他类似问题排查

检查了其他调用 `add_job_log` 的地方，都没有这个问题：

### ✅ realtime_update（第297-301行）
```python
add_job_log(
    'realtime_update',
    'success',
    result.get('message', '实时数据更新完成'),
    **{k: v for k, v in result.items() if k != 'message'}  # 已经过滤了
)
```

### ✅ crawl_news（第221-226行）
```python
add_job_log(
    'crawl_news',
    'success' if result.get('success') else 'warning',
    f"爬取新闻完成，共 {result.get('news_count', 0)} 条",
    **result  # result 中没有 status 字段，安全
)
```

### ✅ full_update（第419-424行）
```python
add_job_log(
    'full_update',
    'success',
    f"全量更新并计算信号完成",
    elapsed_seconds=round(elapsed, 2),
    **result  # result 中没有 status 字段，安全
)
```

## 测试验证

修复后，应该验证：

1. ✅ 启动时的信号计算不再报错
2. ✅ 盘中定时任务的信号计算正常
3. ✅ 日志正确记录任务状态
4. ✅ 实时更新只在交易时间执行

## 预防措施

### 建议1：统一返回结构规范

在 `signal_manager.py` 中，避免返回 `status` 字段，或者使用不同的字段名：

```python
# 方案A：使用 success 代替 status
return {
    "success": True,  # 而不是 "status": "success"
    "message": "...",
    ...
}

# 方案B：使用不同的字段名
return {
    "result_status": "success",  # 避免与参数名冲突
    "message": "...",
    ...
}
```

### 建议2：在 add_job_log 中检查冲突

```python
def add_job_log(job_type: str, status: str, message: str, **kwargs):
    """添加任务执行日志"""
    # 自动过滤掉可能冲突的字段
    kwargs = {k: v for k, v in kwargs.items() if k not in ['job_type', 'status', 'message']}
    
    log_entry = {
        'timestamp': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
        'job_type': job_type,
        'status': status,
        'message': message,
        **kwargs
    }
    # ...
```

## 总结

这是一个典型的 **参数解包冲突** 问题：

- **根本原因**: 返回的字典中包含与函数参数同名的字段
- **触发条件**: 使用 `**dict` 解包时，字段名与显式参数冲突
- **修复方法**: 在解包前过滤掉冲突的字段
- **预防措施**: 规范返回结构，或在函数内部做防御性处理

修复后系统应该能正常计算信号了！

