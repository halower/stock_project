# 🔧 信号计算逻辑修复

## 🚨 原始问题

### 错误的逻辑：

```python
# _init_etf_only() - 只计算 ETF 信号
await _calculate_signals_async(etf_only=True)  # ❌ 遗漏股票信号！
```

**后果**:
- ❌ ETF 初始化后只有 ETF 信号
- ❌ 股票信号全部丢失
- ❌ 用户看不到股票买入信号

---

## ✅ 修复后的逻辑

### 核心原则：

1. **股票信号优先** - 任何模式都先计算股票信号
2. **ETF 信号追加** - 在股票信号之后追加 ETF 信号
3. **信号不丢失** - 确保股票和 ETF 信号同时存在

### 新增参数：

```python
async def calculate_buy_signals(
    force_recalculate: bool = False,
    etf_only: bool = False,        # 仅计算 ETF
    stock_only: bool = False,      # ← 新增：仅计算股票
    clear_existing: bool = True    # ← 新增：是否清空现有信号
):
```

### 参数组合：

| `stock_only` | `etf_only` | `clear_existing` | 效果 |
|--------------|------------|------------------|------|
| `True` | `False` | `True` | 清空所有信号，只计算股票 |
| `False` | `True` | `False` | 不清空，追加 ETF 信号 |
| `False` | `False` | `True` | 清空所有信号，计算股票+ETF |

---

## 📊 修复后的执行流程

### `etf_only` 模式（ETF 专项初始化）

```python
# 步骤 1: 初始化 ETF 清单
await sdm.initialize_etf_list()

# 步骤 2: 获取 ETF K线数据
for etf in etf_list:
    await sdm.update_stock_trend_data(etf['ts_code'], days=180)

# 步骤 3: 先计算股票信号（优先，清空旧信号）✅
await _calculate_signals_async(stock_only=True, clear_existing=True)

# 步骤 4: 再计算 ETF 信号（追加，不清空）✅
await _calculate_signals_async(etf_only=True, clear_existing=False)
```

**结果**:
- ✅ 清空所有旧信号
- ✅ 先计算并存储所有股票信号
- ✅ 再追加所有 ETF 信号
- ✅ 股票信号在前，ETF 信号在后

---

### `full_init` 模式（完整初始化）

```python
# 一次性计算所有信号
await _calculate_signals_async(etf_only=False, stock_only=False, clear_existing=True)
```

**结果**:
- ✅ 清空所有旧信号
- ✅ 计算股票信号
- ✅ 计算 ETF 信号
- ✅ 股票在前，ETF 在后（由 get_buy_signals 排序）

---

### `tasks_only` 模式（仅任务）

```python
# 不获取 K线，只计算信号
await _calculate_signals_async(etf_only=False, stock_only=False, clear_existing=True)
```

---

### 定时任务（每日 17:30）

```python
# 重新计算所有信号
await _calculate_signals_async(etf_only=False, stock_only=False, clear_existing=True)
```

**说明**: 定时任务每次都重新计算股票和 ETF 信号

---

## 🎯 信号排序逻辑

### 在 `get_buy_signals()` 中：

```python
# 1. 分离股票和 ETF 信号
stock_signals = [s for s in signals if s.get('market') != 'ETF']
etf_signals = [s for s in signals if s.get('market') == 'ETF']

# 2. 分别按置信度排序
stock_signals.sort(key=lambda x: (-x['confidence'], -x['timestamp']))
etf_signals.sort(key=lambda x: (-x['confidence'], -x['timestamp']))

# 3. 股票在前，ETF 在后
return stock_signals + etf_signals
```

**效果**:
```
买入信号列表:
  [1-N]   股票信号（按置信度降序）
  [N+1-M] ETF 信号（按置信度降序）
```

---

## 📋 修改文件清单

### 1. `app/services/signal_manager.py`

**修改 1**: 新增参数
```python
async def calculate_buy_signals(
    force_recalculate: bool = False,
    etf_only: bool = False,
    stock_only: bool = False,      # ← 新增
    clear_existing: bool = True    # ← 新增
):
```

**修改 2**: 追加模式支持
```python
if clear_existing:
    # 清空所有旧信号
    sync_redis.delete(self.buy_signals_key)
else:
    # 追加模式：不清空
    logger.info(f"追加模式：不清空现有信号，新增{signal_type}信号")
```

**修改 3**: 股票过滤
```python
elif stock_only:
    # 仅保留股票（market!='ETF'）
    stock_list = [s for s in stock_list if s.get('market') != 'ETF']
```

---

### 2. `app/services/stock_scheduler.py`

**修改 1**: `_calculate_signals_async` 新增参数
```python
async def _calculate_signals_async(
    etf_only: bool = False,
    stock_only: bool = False,     # ← 新增
    clear_existing: bool = True   # ← 新增
):
```

**修改 2**: `_init_etf_only` 执行流程
```python
# 先计算股票信号（优先，清空旧信号）
await _calculate_signals_async(stock_only=True, clear_existing=True)

# 再计算 ETF 信号（追加，不清空）
await _calculate_signals_async(etf_only=True, clear_existing=False)
```

---

## 🚀 测试验证

### 1. 启动 `etf_only` 模式

```bash
# 方式 1: 环境变量
docker-compose up -d  # STOCK_INIT_MODE=etf_only

# 方式 2: API
curl -X POST "http://localhost:8000/api/stocks/scheduler/init?mode=etf_only"
```

**期望日志**:
```
步骤 1: 初始化 ETF 清单...
步骤 2: 获取 1220 个 ETF 的K线数据...
步骤 3: 计算股票买入信号（优先，清空旧信号）...
✅ 股票买入信号重新计算完成: 生成 50 个信号
步骤 4: 计算 ETF 买入信号（追加到股票信号后）...
✅ ETF买入信号追加完成: 生成 10 个信号
```

### 2. 检查信号列表

```bash
curl "http://localhost:8000/api/stocks/signal/buy?strategy=volume_wave"
```

**期望结果**:
```json
[
  {
    "code": "000001.SZ",
    "name": "平安银行",
    "market": "主板",
    "industry": "银行"
  },
  {
    "code": "600036.SH",
    "name": "招商银行",
    "market": "主板",
    "industry": "银行"
  },
  ...
  {
    "code": "510300.SH",
    "name": "沪深300ETF",
    "market": "ETF",
    "industry": "T+0交易"
  }
]
```

**验证点**:
- ✅ 股票信号在前
- ✅ ETF 信号在后
- ✅ 两种信号都存在

---

## 📝 配置说明

### 初始化模式对比

| 模式 | 股票 K线 | ETF K线 | 股票信号 | ETF 信号 | 用途 |
|------|---------|---------|---------|---------|------|
| `skip` | ❌ | ❌ | ❌ | ❌ | 跳过初始化 |
| `tasks_only` | ❌ | ❌ | ✅ | ✅ | 只计算信号 |
| `full_init` | ✅ | ✅ | ✅ | ✅ | 完整初始化 |
| `etf_only` | ❌ | ✅ | ✅ | ✅ | ETF 专项 |

**说明**: 
- `etf_only` 只获取 ETF K线，但**同时计算股票和 ETF 信号**
- 任何模式下，只要计算信号，**都会同时计算股票和 ETF**

---

## ✅ 修复总结

### 修复前 ❌

```
etf_only 模式:
  1. 初始化 ETF
  2. 获取 ETF K线
  3. 只计算 ETF 信号  ← 遗漏股票！
  
结果: 只有 ETF 信号，股票信号全部丢失
```

### 修复后 ✅

```
etf_only 模式:
  1. 初始化 ETF
  2. 获取 ETF K线
  3. 先计算股票信号  ← 优先！
  4. 再追加 ETF 信号  ← 完整！
  
结果: 股票信号在前，ETF 信号在后，两者都存在
```

### 核心原则

1. ✅ **股票优先** - 始终先计算股票信号
2. ✅ **ETF 追加** - 在股票之后追加 ETF 信号
3. ✅ **信号完整** - 确保股票和 ETF 信号都存在
4. ✅ **顺序固定** - 股票在前，ETF 在后

**重启服务后立即生效！** 🎉

