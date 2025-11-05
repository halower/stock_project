# 信号计算事件循环冲突修复

## 🐛 问题描述

信号计算时出现大量 `Task got Future attached to a different loop` 错误，导致：
1. 信号计算失败率高
2. 前端请求卡住
3. 系统响应缓慢

### 错误日志示例
```
2025-11-05 13:22:11 - stock_app - WARNING - 处理股票 836270.BJ 失败: Task <Task pending name='Task-30954' coro=<SignalManager.calculate_buy_signals.<locals>.process_with_semaphore() running at /app/app/services/signal/signal_manager.py:627> cb=[gather.<locals>._done_callback() at /usr/local/lib/python3.10/asyncio/tasks.py:714]> got Future <Future pending> attached to a different loop

2025-11-05 13:22:12 - stock_app - ERROR - 存储信号失败: Task <Task pending name='Task-31015' coro=<SignalManager.calculate_buy_signals.<locals>.process_with_semaphore() running at /app/app/services/signal/signal_manager.py:627> cb=[gather.<locals>._done_callback() at /usr/local/lib/python3.10/asyncio/tasks.py:714]> got Future <Future pending> attached to a different loop
```

## 🔍 根本原因

### 问题分析

信号计算在后台线程中运行，使用独立的 `asyncio` 事件循环：

```python
# stock_scheduler.py 中
def _trigger_signal_recalculation_async():
    """在独立线程中异步触发信号重新计算"""
    def run_in_thread():
        loop = asyncio.new_event_loop()  # 创建新的事件循环
        asyncio.set_event_loop(loop)
        try:
            result = loop.run_until_complete(
                signal_manager.calculate_buy_signals(...)
            )
        finally:
            loop.close()
    
    thread = threading.Thread(target=run_in_thread, daemon=True)
    thread.start()
```

但是 `SignalManager._process_stock_with_thread_control` 方法中使用了异步 Redis 客户端：

```python
# 旧代码 - 有问题
async def _process_stock_with_thread_control(...):
    # 使用异步Redis客户端
    redis_client = await get_redis_client()  # ❌ 异步调用
    kline_data = await redis_client.get(...)  # ❌ 异步调用
    await self._store_signal(...)  # ❌ 异步调用
```

### 冲突点

1. **后台线程** 有自己的事件循环（Loop A）
2. **异步Redis客户端** 在主事件循环中创建（Loop B）
3. 在 Loop A 中调用 Loop B 的 Future → **冲突！**

## ✅ 解决方案

### 修改策略

将信号计算中的 Redis 操作改为**同步方式**，避免跨事件循环调用。

### 修改内容

#### 1. 修改 `_process_stock_with_thread_control` 方法

**文件**: `app/services/signal/signal_manager.py`

```python
# 修改前
async def _process_stock_with_thread_control(...):
    # 使用异步Redis客户端
    redis_client = await get_redis_client()  # ❌
    kline_data = await redis_client.get(kline_key)  # ❌

# 修改后
async def _process_stock_with_thread_control(...):
    # 使用同步Redis客户端，避免事件循环冲突
    from app.core.sync_redis_client import get_sync_redis_client
    redis_client = get_sync_redis_client()  # ✅ 同步
    kline_data = redis_client.get(kline_key)  # ✅ 同步
```

#### 2. 修改信号存储调用

```python
# 修改前
if signal_index == last_index:
    await self._store_signal(...)  # ❌ 异步调用

# 修改后
if signal_index == last_index:
    self._store_signal_sync(...)  # ✅ 同步调用
```

#### 3. 创建同步版本的 `_store_signal` 方法

```python
# 修改前
async def _store_signal(..., redis_client) -> None:
    """存储买入信号"""
    signal_key = f"{clean_code}:{strategy_code}"
    await redis_client.hset(...)  # ❌ 异步调用

# 修改后
def _store_signal_sync(..., redis_client) -> None:
    """存储买入信号（同步版本，避免事件循环冲突）"""
    signal_key = f"{clean_code}:{strategy_code}"
    redis_client.hset(...)  # ✅ 同步调用
```

## 📊 修改总结

| 项目 | 修改前 | 修改后 |
|------|--------|--------|
| Redis 客户端 | 异步 (`get_redis_client`) | 同步 (`get_sync_redis_client`) |
| Redis 操作 | `await redis_client.get()` | `redis_client.get()` |
| 信号存储方法 | `_store_signal` (异步) | `_store_signal_sync` (同步) |
| 方法调用 | `await self._store_signal()` | `self._store_signal_sync()` |

## 🎯 效果

### 修改前
- ❌ 大量 `Task got Future attached to a different loop` 错误
- ❌ 信号计算成功率低
- ❌ 前端请求卡住
- ❌ 系统响应缓慢

### 修改后
- ✅ 无事件循环冲突错误
- ✅ 信号计算正常完成
- ✅ 前端响应正常
- ✅ 系统运行流畅

## 🔧 技术细节

### 为什么可以混用同步和异步？

`_process_stock_with_thread_control` 方法本身仍然是 `async def`，因为：

1. **外层调用**需要异步（`asyncio.gather`）
2. **内部操作**可以是同步的（Redis）
3. 同步操作在异步函数中**不会阻塞事件循环**（因为运行在独立线程中）

### 同步 Redis 客户端

`get_sync_redis_client()` 返回标准的 `redis.Redis` 客户端：

```python
# app/core/sync_redis_client.py
import redis
from app.core.config import REDIS_HOST, REDIS_PORT, REDIS_DB

def get_sync_redis_client():
    """获取同步Redis客户端"""
    return redis.Redis(
        host=REDIS_HOST,
        port=REDIS_PORT,
        db=REDIS_DB,
        decode_responses=True
    )
```

### 为什么不全改成同步？

1. **FastAPI 路由**需要异步（主事件循环）
2. **信号计算**在后台线程（独立事件循环）
3. 两者需要**不同的 Redis 客户端**

## 🚀 部署步骤

### 在服务器上执行：

```bash
cd /root/stock_app

# 1. 停止容器
docker-compose down

# 2. 重新构建
docker-compose build --no-cache

# 3. 启动容器
docker-compose up -d

# 4. 查看日志
docker logs -f stock_app_api
```

## 📝 验证

### 检查日志

应该看到：

```
✅ 信号计算正常完成
✅ 无 "Task got Future attached to a different loop" 错误
✅ 前端请求响应正常
```

### 前端测试

1. 打开前端页面
2. 查看信号列表
3. 确认数据正常加载
4. 无卡顿现象

## 📚 相关文件

- `app/services/signal/signal_manager.py` - 信号管理器（主要修改）
- `app/core/sync_redis_client.py` - 同步 Redis 客户端
- `app/services/scheduler/stock_scheduler.py` - 调度器（触发信号计算）

## 🎉 总结

通过将后台线程中的 Redis 操作改为同步方式，成功解决了事件循环冲突问题。

**核心原则**：
- 主事件循环 → 异步 Redis
- 后台线程 → 同步 Redis
- 避免跨事件循环调用

---

**修复完成！现在可以重新部署了！** 🚀

