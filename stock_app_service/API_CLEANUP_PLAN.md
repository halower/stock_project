# API 端点清理计划

## 📋 背景

ETF 和股票实时更新已经合并，很多独立的 ETF API 端点变得冗余。

---

## 🗑️ 可以删除的 API

### 1. ETF配置管理 (`etf_config.py`)
**原因：** ETF 和股票使用相同的实时服务，不需要单独配置

**删除的端点：**
- `GET /api/etf/config` - ETF配置查询
- `PUT /api/etf/config` - ETF配置更新
- `GET /api/etf/stats` - ETF统计信息
- `POST /api/etf/stats/reset` - 重置统计
- `GET /api/etf/test/{provider}` - 测试数据源
- `POST /api/etf/init` - 初始化ETF
- `POST /api/etf/update` - 更新ETF

**替代方案：**
```bash
# 初始化ETF
POST /api/stocks/scheduler/trigger?task_type=init_etf

# 更新ETF实时数据（现在自动包含在股票更新中）
POST /api/stocks/scheduler/trigger?task_type=update_realtime

# 仅重算信号（股票+ETF）
启动时: export STOCK_INIT_MODE=signals_only
```

---

### 2. ETF诊断 (`etf_diagnosis.py`)
**原因：** 股票和 ETF 信号已统一计算，不需要单独诊断

**删除的端点：**
- `GET /api/etf/diagnosis` - ETF诊断
- `POST /api/etf/diagnosis/recalculate` - 重算ETF信号
- `GET /api/etf/signals` - 获取ETF信号

**替代方案：**
```bash
# 查看所有信号（包含ETF）
GET /api/stocks/signal/buy

# 重算所有信号（包含ETF）
export STOCK_INIT_MODE=signals_only
# 或使用
POST /api/stocks/scheduler/trigger?task_type=calc_signals

# 过滤ETF信号（前端处理）
GET /api/stocks/signal/buy
# 然后过滤 market == 'ETF'
```

---

## ⚠️ 保留的 API

### 实时行情配置 (`realtime_config.py`)
**原因：** 配置和监控功能仍然有用

**保留的端点：**
- `GET /api/realtime/config` - 查看配置（数据源、切换策略）
- `PUT /api/realtime/config` - 更新配置
- `GET /api/realtime/stats` - 查看统计（成功率、自动切换次数）
- `POST /api/realtime/stats/reset` - 重置统计
- `GET /api/realtime/test/{provider}` - 测试数据源

**用途：**
- 运维监控数据源健康状况
- 调试时测试不同数据源
- 查看自动切换历史

---

## 🔄 统一后的 API 体系

### 核心调度 API
```bash
# 系统初始化（6种模式）
POST /api/stocks/scheduler/init?mode=signals_only

# 手动触发任务
POST /api/stocks/scheduler/trigger
  - task_type=init_system&mode=signals_only  # 仅计算信号
  - task_type=update_realtime                 # 实时更新（股票+ETF）
  - task_type=calc_signals                    # 计算信号（股票+ETF）
  - task_type=clear_refetch                   # 全量刷新K线
```

### 信号查询 API
```bash
# 获取买入信号（包含股票+ETF）
GET /api/stocks/signal/buy

# 前端按market字段过滤：
# - market == 'ETF' → ETF信号
# - market != 'ETF' → 股票信号
```

### 配置监控 API
```bash
# 实时数据源配置
GET /api/realtime/config
PUT /api/realtime/config
GET /api/realtime/stats
```

---

## 📝 清理步骤

### 1. 删除文件
```bash
cd stock_app_service/app/api/

# 删除冗余的API文件
rm etf_config.py
rm etf_diagnosis.py
```

### 2. 更新 main.py
```python
# 删除导入
from app.api import (
    system, public, news_analysis, stocks_redis, strategy, 
    signal_management, task_management, stock_scheduler_api,
    stock_data_management, stock_ai_analysis, chart, market_types,
    realtime_config,  # 保留
    # etf_config, etf_diagnosis  # 删除这两行
)

# 删除路由注册
# app.include_router(etf_config.router, prefix="/api", tags=["ETF配置管理"])
# app.include_router(etf_diagnosis.router)
```

### 3. 检查依赖
```bash
# 搜索是否有其他地方引用了这些模块
grep -r "from app.api import.*etf_config" .
grep -r "from app.api import.*etf_diagnosis" .
```

---

## ✅ 清理后的优势

1. **简化维护**
   - 减少 2 个 API 文件
   - 减少约 500 行代码
   - 统一的端点命名

2. **更清晰的逻辑**
   - 所有调度任务统一到 `/api/stocks/scheduler/`
   - 股票和 ETF 不再分离
   - 降低学习成本

3. **更好的性能**
   - 股票和 ETF 一起更新、一起计算
   - 避免重复的 Redis 连接
   - 减少 API 端点数量

---

## 🔄 迁移指南

### 旧 API → 新 API 映射

| 旧端点 | 新端点 | 说明 |
|--------|--------|------|
| `POST /api/etf/init` | `POST /api/stocks/scheduler/trigger?task_type=init_etf` | 初始化ETF |
| `POST /api/etf/update` | `POST /api/stocks/scheduler/trigger?task_type=update_realtime` | 实时更新（自动包含ETF） |
| `GET /api/etf/signals` | `GET /api/stocks/signal/buy` (过滤 market=='ETF') | 获取信号 |
| `POST /api/etf/diagnosis/recalculate` | `STOCK_INIT_MODE=signals_only` 或 `task_type=calc_signals` | 重算信号 |
| `GET /api/etf/diagnosis` | ❌ 不需要了 | 统一计算，无需诊断 |
| `GET /api/etf/config` | ❌ 不需要了 | 使用统一的实时配置 |

---

## 📊 对比总结

### 清理前
```
API端点总数: 20+
- 股票调度: 5个
- ETF配置: 7个 ❌
- ETF诊断: 3个 ❌
- 实时配置: 5个 ✅
```

### 清理后
```
API端点总数: 10
- 股票调度: 5个 ✅ (包含ETF)
- 实时配置: 5个 ✅
```

**减少 10 个端点，简化 50%！** 🎉

---

## ⚠️ 注意事项

1. **客户端更新**
   - 如果前端使用了 `/api/etf/*` 端点，需要更新
   - 建议先在开发环境测试

2. **文档更新**
   - 更新 Swagger 文档
   - 更新 README
   - 通知相关开发人员

3. **向后兼容**（可选）
   - 如果担心破坏性变更，可以保留旧端点但标记为 deprecated
   - 设置 6 个月的过渡期

---

**建议：立即执行清理，简化系统架构！** ✅

