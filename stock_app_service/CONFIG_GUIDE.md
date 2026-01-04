# 股票服务配置指南

## 🚀 快速开始

### 推荐配置（生产环境）

```bash
# 默认配置，无需设置环境变量
# 系统会：
# 1. 跳过启动时的全量初始化（skip模式）
# 2. 保留Redis中的现有数据
# 3. 访问图表时自动补偿缺失的数据
# 4. 不自动计算信号（减少启动时间）
```

这是最安全、最高效的配置，适合大多数场景。

---

## 📋 环境变量详解

### 1. 初始化模式 `SCHEDULER_INIT_MODE`

控制系统启动时的数据初始化行为。

#### `skip` 模式（默认，推荐）

```bash
export SCHEDULER_INIT_MODE=skip
# 或不设置，默认就是skip
```

**特点：**
- ✅ 保留Redis中所有现有数据
- ✅ 启动速度快（秒级启动）
- ✅ 按需自动补偿数据（访问时自动获取缺失数据）
- ✅ 节省API调用次数
- ✅ 适合频繁重启场景

**适用场景：**
- 生产环境日常运行
- 开发调试
- Redis数据完整时
- 晚上10点等非交易时间启动

#### `init` 模式（全量初始化）

```bash
export SCHEDULER_INIT_MODE=init
```

**特点：**
- 🔄 启动时获取所有股票数据（约6000只）
- ⏱️ 耗时较长（约30-60分钟）
- 📊 适合首次部署或数据完全丢失时
- 🔌 会调用大量Tushare API

**适用场景：**
- 首次部署系统
- Redis数据完全丢失
- 需要刷新所有股票数据
- 有充足时间等待初始化

---

### 2. 信号计算 `SCHEDULER_CALCULATE_SIGNALS`

控制启动时是否计算买入信号。

```bash
# 不计算（默认，推荐）
export SCHEDULER_CALCULATE_SIGNALS=false

# 计算信号（启动时间会增加5-10分钟）
export SCHEDULER_CALCULATE_SIGNALS=true
```

**建议：**
- 开发环境：false（快速启动）
- 生产环境：通过定时任务或API手动触发计算

---

### 3. Redis清空 `RESET_TABLES`

⚠️ **危险操作**：控制是否清空Redis数据。

```bash
# 不清空（默认，强烈推荐）
export RESET_TABLES=false

# 清空Redis（需谨慎！）
export RESET_TABLES=true
```

**重要说明：**
1. **skip模式保护**：即使设置`RESET_TABLES=true`，如果`SCHEDULER_INIT_MODE=skip`，系统也不会清空Redis
2. **只在init模式下生效**：只有`SCHEDULER_INIT_MODE=init`时才会真正清空
3. **生产环境禁用**：生产环境应该保持`false`

**适用场景：**
- 数据损坏需要重建
- 测试环境需要清空数据
- 从旧版本迁移到新版本

---

## 🎯 常见配置组合

### 场景1：生产环境日常运行（推荐）

```bash
# 不设置任何环境变量，使用默认值
# 或明确设置：
export SCHEDULER_INIT_MODE=skip
export SCHEDULER_CALCULATE_SIGNALS=false
export RESET_TABLES=false
```

✅ **效果**：
- 秒级启动
- 保留所有数据
- 按需补偿缺失数据
- 无数据丢失风险

---

### 场景2：首次部署

```bash
export SCHEDULER_INIT_MODE=init
export SCHEDULER_CALCULATE_SIGNALS=true
export RESET_TABLES=false  # 保持false，Redis是空的不需要清空
```

⏱️ **启动时间**：30-60分钟
📊 **结果**：所有股票数据+买入信号全部就绪

---

### 场景3：Redis数据损坏，需要重建

```bash
export SCHEDULER_INIT_MODE=init
export SCHEDULER_CALCULATE_SIGNALS=true
export RESET_TABLES=true  # 清空损坏的数据
```

🔥 **警告**：这会删除所有Redis数据！
🔄 **启动时间**：30-60分钟

---

### 场景4：开发调试

```bash
export SCHEDULER_INIT_MODE=skip
export SCHEDULER_CALCULATE_SIGNALS=false
export RESET_TABLES=false
```

⚡ **效果**：快速启动，使用现有数据，按需补偿

---

## 🔧 新特性：自动数据补偿

从本版本开始，系统具备**智能数据补偿**能力：

### 工作原理

```
用户访问图表 → Redis没有数据 → 自动从Tushare获取 → 存入Redis → 生成图表
                                     ↓
                              下次访问直接使用
```

### 优势

1. **无需全量初始化**：只获取实际需要的股票数据
2. **节省API调用**：避免获取永远不会访问的股票数据
3. **快速启动**：skip模式秒级启动
4. **自动恢复**：Redis重启后数据按需自动恢复

---

## 📊 启动日志示例

### Skip模式（推荐）

```
2026-01-04 22:00:00 - Stock Intelligence API 服务启动...
2026-01-04 22:00:01 - Redis连接成功
2026-01-04 22:00:01 - 股票调度器配置: init_mode=skip, calculate_signals=false
2026-01-04 22:00:02 - API服务已启动 - 文档地址: /docs
2026-01-04 22:00:02 - 后台初始化完成
```

**启动时间**：2秒

---

### Init模式

```
2026-01-04 22:00:00 - Stock Intelligence API 服务启动...
2026-01-04 22:00:01 - Redis连接成功
2026-01-04 22:00:01 - 股票调度器配置: init_mode=init, calculate_signals=true
2026-01-04 22:00:02 - API服务已启动 - 文档地址: /docs
2026-01-04 22:00:03 - 开始全量初始化所有股票数据...
2026-01-04 22:00:03 - 共需要初始化 6000 只股票的走势数据
...（30分钟后）
2026-01-04 22:30:15 - 股票走势数据初始化完成!
2026-01-04 22:30:15 - 开始计算策略信号...
...（10分钟后）
2026-01-04 22:40:20 - 信号计算完成
```

**启动时间**：40分钟

---

## ⚠️ 常见问题

### Q1: 为什么我的数据丢失了？

**A**: 检查是否设置了`RESET_TABLES=true`。建议保持`false`或不设置。

### Q2: Skip模式下如何保证数据完整？

**A**: 系统会在访问时自动补偿缺失数据，首次访问可能慢1-2秒，后续访问秒开。

### Q3: 什么时候需要用init模式？

**A**: 只在以下场景：
- 首次部署
- Redis完全清空
- 需要刷新所有数据

### Q4: 晚上启动用什么模式？

**A**: 用`skip`模式。非交易时间启动不需要全量数据，需要什么补偿什么。

---

## 🎉 推荐实践

1. **日常运行**：使用skip模式，快速启动
2. **按需补偿**：让系统自动处理缺失数据
3. **定期全量更新**：每周末用定时任务执行一次全量更新
4. **信号计算**：通过API手动触发，不在启动时计算
5. **保护数据**：生产环境永远不设置`RESET_TABLES=true`

---

## 📞 技术支持

如有问题，请查看日志文件或联系技术支持。

