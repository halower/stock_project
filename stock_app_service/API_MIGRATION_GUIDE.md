# API 迁移指南

## 🎯 简介

ETF 和股票实时处理已合并，删除了冗余的 API 端点。

---

## 🗑️ 已删除的 API

### 1. ETF 配置管理 (7个端点)
- ❌ `GET /api/etf/config`
- ❌ `PUT /api/etf/config`
- ❌ `GET /api/etf/stats`
- ❌ `POST /api/etf/stats/reset`
- ❌ `GET /api/etf/test/{provider}`
- ❌ `POST /api/etf/init`
- ❌ `POST /api/etf/update`

### 2. ETF 诊断 (3个端点)
- ❌ `GET /api/etf/diagnosis`
- ❌ `POST /api/etf/diagnosis/recalculate`
- ❌ `GET /api/etf/signals`

---

## 🔄 新的替代方案

### 初始化和更新

```bash
# 旧: POST /api/etf/init
# 新: 使用统一的调度器
POST /api/stocks/scheduler/trigger?task_type=init_etf

# 旧: POST /api/etf/update
# 新: 实时更新自动包含 ETF
POST /api/stocks/scheduler/trigger?task_type=update_realtime

# 或使用初始化模式
export STOCK_INIT_MODE=etf_only  # 仅初始化ETF
docker-compose restart stock_backend
```

### 信号计算

```bash
# 旧: POST /api/etf/diagnosis/recalculate
# 新: 计算所有信号（包含股票+ETF）
POST /api/stocks/scheduler/trigger?task_type=calc_signals

# 或使用新的 signals_only 模式
export STOCK_INIT_MODE=signals_only
docker-compose restart stock_backend
```

### 查询信号

```bash
# 旧: GET /api/etf/signals
# 新: 使用统一端点，前端过滤
GET /api/stocks/signal/buy

# 前端过滤示例（JavaScript）
const allSignals = await fetch('/api/stocks/signal/buy').then(r => r.json());
const etfSignals = allSignals.data.filter(s => s.market === 'ETF');
const stockSignals = allSignals.data.filter(s => s.market !== 'ETF');
```

---

## ✅ 保留的 API

### 实时行情配置（运维监控用）

```bash
# 查看配置
GET /api/realtime/config

# 更新配置
PUT /api/realtime/config
{
  "default_provider": "eastmoney",
  "auto_switch": true
}

# 查看统计
GET /api/realtime/stats

# 重置统计
POST /api/realtime/stats/reset

# 测试数据源
GET /api/realtime/test/eastmoney
GET /api/realtime/test/sina
```

---

## 📊 完整的 API 体系

### 1. 系统初始化
```bash
POST /api/stocks/scheduler/init?mode={mode}

模式选项:
- none          # 什么都不做
- signals_only  # 仅计算信号（新增）
- tasks_only    # 不获取K线，执行任务
- stock_only    # 仅股票
- etf_only      # 仅ETF
- all           # 全部
```

### 2. 手动触发任务
```bash
POST /api/stocks/scheduler/trigger?task_type={task}

任务类型:
- init_system        # 系统初始化
- clear_refetch      # 全量刷新K线
- calc_signals       # 计算信号（股票+ETF）
- update_realtime    # 实时更新（股票+ETF）
- init_etf           # 初始化ETF
- update_etf         # 更新ETF
```

### 3. 查询信号
```bash
# 所有买入信号（包含股票+ETF）
GET /api/stocks/signal/buy

# 按策略过滤
GET /api/stocks/signal/buy?strategy=volume_wave

# 前端按 market 字段过滤
# market == 'ETF' → ETF信号
# market != 'ETF' → 股票信号
```

### 4. 实时配置监控
```bash
GET /api/realtime/config    # 查看配置
PUT /api/realtime/config    # 更新配置
GET /api/realtime/stats     # 查看统计
```

---

## 🚀 优势

### 简化后的系统
- ✅ **减少 10 个端点**（50% 减少）
- ✅ **统一的逻辑**（股票+ETF 一起处理）
- ✅ **更好的性能**（避免重复计算）
- ✅ **降低维护成本**

### 更清晰的架构
```
旧架构:
/api/stocks/*     → 股票相关
/api/etf/*        → ETF相关（独立）
/api/realtime/*   → 配置相关

新架构:
/api/stocks/*     → 股票+ETF（统一）
/api/realtime/*   → 配置监控
```

---

## 📝 迁移检查清单

### 后端
- [x] 删除 `etf_config.py`
- [x] 删除 `etf_diagnosis.py`
- [x] 更新 `main.py` 路由注册
- [x] 测试所有端点

### 前端（如果需要）
- [ ] 更新 API 调用路径
- [ ] 添加信号过滤逻辑
- [ ] 测试 ETF 功能

### 文档
- [x] 创建迁移指南
- [x] 更新 API 文档
- [ ] 通知相关人员

---

## 💡 示例代码

### Python 客户端
```python
import requests

# 初始化 ETF
response = requests.post(
    'http://localhost:8000/api/stocks/scheduler/trigger',
    params={'task_type': 'init_etf'}
)

# 获取所有信号
all_signals = requests.get(
    'http://localhost:8000/api/stocks/signal/buy'
).json()

# 过滤 ETF 信号
etf_signals = [
    s for s in all_signals['data'] 
    if s.get('market') == 'ETF'
]

print(f"ETF 信号数量: {len(etf_signals)}")
```

### JavaScript 前端
```javascript
// 获取 ETF 信号
async function getETFSignals() {
  const response = await fetch('/api/stocks/signal/buy');
  const data = await response.json();
  
  // 过滤出 ETF
  const etfSignals = data.data.filter(s => s.market === 'ETF');
  
  return etfSignals;
}

// 重新计算信号
async function recalculateSignals() {
  const response = await fetch(
    '/api/stocks/scheduler/trigger?task_type=calc_signals',
    { method: 'POST' }
  );
  
  return response.json();
}
```

---

## ❓ FAQ

### Q1: 如何只更新 ETF 而不影响股票？
A: 使用 `etf_only` 模式
```bash
export STOCK_INIT_MODE=etf_only
docker-compose restart stock_backend
```

### Q2: 如何快速重新计算信号？
A: 使用新的 `signals_only` 模式
```bash
export STOCK_INIT_MODE=signals_only
docker-compose restart stock_backend
```

### Q3: 如何区分 ETF 和股票信号？
A: 通过 `market` 字段
- `market == 'ETF'` → ETF
- `market != 'ETF'` → 股票

### Q4: 旧的 API 还能用吗？
A: 不能，已完全删除。请使用新的统一 API。

---

**迁移完成！系统更加简洁高效！** ✅

