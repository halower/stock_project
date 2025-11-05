# 股票系统初始化模式说明

## 📋 配置方式

### 1️⃣ 环境变量（推荐，Docker部署使用）

```bash
# 设置环境变量
export STOCK_INIT_MODE="etf_only"

# 或者在Docker Compose中设置
environment:
  - STOCK_INIT_MODE=etf_only
```

### 2️⃣ 配置文件默认值

如果未设置环境变量，将使用 `app/core/config.py` 中的默认值：

```python
STOCK_INIT_MODE = os.environ.get("STOCK_INIT_MODE", "none").lower()
```

---

## 🎯 六种初始化模式详解

### 模式1: `none` （默认）

**操作内容：**
- ❌ 不获取股票列表
- ❌ 不获取ETF列表
- ❌ 不获取历史K线数据
- ❌ 不获取新闻
- ❌ 不计算信号
- ✅ 直接进入计划任务监听

**使用场景：**
- 快速启动服务，完全不做初始化
- Redis中已有完整数据，无需重新获取
- 手动通过API触发数据更新
- 开发调试时节省启动时间

**执行时间：** < 1秒

**示例：**
```bash
export STOCK_INIT_MODE="none"
python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

---

### 模式2: `signals_only`

**操作内容：**
- ❌ 不获取股票列表
- ❌ 不获取ETF列表
- ❌ 不获取历史K线数据
- ❌ 不获取新闻
- ✅ 计算买入信号（股票+ETF）
- ✅ 进入计划任务监听

**使用场景：**
- 数据已存在，只需重新计算信号
- 策略参数调整后重新计算
- 信号计算逻辑更新后刷新
- 快速更新买入信号列表

**执行时间：** 约30秒-2分钟（取决于数据量）

**示例：**
```bash
export STOCK_INIT_MODE="signals_only"
python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

---

### 模式3: `tasks_only`

**操作内容：**
- ✅ 检查现有股票/ETF列表（从Redis读取）
- ❌ 不获取新的历史K线数据
- ✅ 获取最新新闻资讯
- ✅ 基于Redis现有K线数据计算信号
- ✅ 进入计划任务监听

**使用场景：**
- 日常维护，只更新信号和新闻
- Redis中已有K线数据，只需重新计算
- 快速重启服务并更新信号
- 节省Tushare API配额

**执行时间：** 约1-3分钟（取决于信号计算）

**示例：**
```bash
export STOCK_INIT_MODE="tasks_only"
python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

---

### 模式4: `stock_only`

**操作内容：**
- ✅ 获取最新股票列表（Tushare API）
- ❌ 不处理ETF
- ✅ 清空现有股票K线数据
- ✅ 重新获取所有股票历史数据（约5400只）
- ✅ 获取最新新闻
- ✅ 计算股票买入信号（不含ETF）
- ✅ 进入计划任务监听

**使用场景：**
- 首次部署，只需要股票数据
- 股票数据出现问题需要重建
- 定期全量更新股票数据（建议每周）
- 不需要ETF数据的轻量级部署

**执行时间：** 约20-30分钟（取决于网络和Tushare限速）

**数据量：** ~5400只股票 × 180天K线

**示例：**
```bash
export STOCK_INIT_MODE="stock_only"
python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

---

### 模式5: `etf_only`

**操作内容：**
- ❌ 不处理股票
- ✅ 获取最新ETF列表（配置文件121个）
- ✅ 清空现有ETF K线数据
- ✅ 重新获取所有ETF历史数据（121只）
- ✅ 获取最新新闻
- ✅ 计算ETF买入信号（不含股票）
- ✅ 进入计划任务监听

**使用场景：**
- 首次部署，只需要ETF数据
- ETF数据出现问题需要重建
- 快速测试ETF功能
- ETF信号专用服务

**执行时间：** 约1-2分钟

**数据量：** 121只ETF × 180天K线

**示例：**
```bash
export STOCK_INIT_MODE="etf_only"
python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

---

### 模式6: `all` （完整初始化）

**操作内容：**
- ✅ 获取最新股票列表（Tushare API，约5400只）
- ✅ 获取最新ETF列表（配置文件，121只）
- ✅ 清空所有历史K线数据（股票+ETF）
- ✅ 重新获取所有历史数据（5569只标的 × 180天）
- ✅ 获取最新新闻
- ✅ 计算所有买入信号（股票+ETF）
- ✅ 进入计划任务监听

**使用场景：**
- 系统首次部署
- 所有数据损坏需要重建
- 定期全量数据刷新（建议每月）
- 完整数据备份和恢复

**执行时间：** 约30-45分钟

**数据量：** 
- 股票：约5400只 × 180天K线
- ETF：121只 × 180天K线
- 总计：约5569只标的

**示例：**
```bash
export STOCK_INIT_MODE="all"
python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

---

## 🔄 模式对比表

| 模式 | 股票列表 | ETF列表 | K线数据 | 新闻 | 信号计算 | 执行时间 | 适用场景 |
|------|---------|---------|---------|------|---------|---------|---------|
| `none` | ❌ | ❌ | ❌ | ❌ | ❌ | < 1秒 | 快速启动/手动控制 |
| `signals_only` | ❌ | ❌ | ❌ | ❌ | ✅全部 | 30秒-2分钟 | 仅重算信号 |
| `tasks_only` | ✅读取 | ✅读取 | ❌ | ✅ | ✅全部 | 1-3分钟 | 日常维护/信号更新 |
| `stock_only` | ✅获取 | ❌ | ✅股票 | ✅ | ✅股票 | 20-30分钟 | 仅股票服务 |
| `etf_only` | ❌ | ✅获取 | ✅ETF | ✅ | ✅ETF | 1-2分钟 | 仅ETF服务 |
| `all` | ✅获取 | ✅获取 | ✅全部 | ✅ | ✅全部 | 30-45分钟 | 完整初始化 |

---

## 🐳 Docker Compose 示例

```yaml
version: '3.8'

services:
  stock_backend:
    build: ./stock_app_service
    environment:
      # 初始化模式（5选1）
      - STOCK_INIT_MODE=tasks_only
      
      # Redis配置
      - REDIS_HOST=redis
      - REDIS_PORT=6379
      
      # Tushare配置
      - TUSHARE_TOKEN=your_tushare_token_here
      
    ports:
      - "8000:8000"
    depends_on:
      - redis
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    restart: unless-stopped

volumes:
  redis_data:
```

---

## 🚀 最佳实践建议

### 生产环境部署流程

#### 首次部署
```bash
# 1. 使用 all 模式完整初始化
export STOCK_INIT_MODE="all"
docker-compose up -d

# 2. 等待初始化完成（30-45分钟）
docker-compose logs -f stock_backend | grep "初始化完成"
```

#### 日常运维
```bash
# 使用 tasks_only 模式快速重启
export STOCK_INIT_MODE="tasks_only"
docker-compose restart stock_backend
```

#### 数据问题修复
```bash
# 仅修复股票数据
export STOCK_INIT_MODE="stock_only"
docker-compose restart stock_backend

# 仅修复ETF数据
export STOCK_INIT_MODE="etf_only"
docker-compose restart stock_backend
```

#### 开发调试
```bash
# 快速启动，手动控制
export STOCK_INIT_MODE="none"
python3 -m uvicorn app.main:app --reload
```

---

## 📊 计划任务说明

**所有模式（除none外）完成初始化后都会进入计划任务监听：**

### 定时任务列表

1. **实时数据更新** - 每20分钟
   - 更新所有股票实时价格
   - 更新ETF实时价格
   - 自动合并到K线数据

2. **信号计算** - 每30分钟
   - 计算量价波动策略信号
   - 计算趋势延续策略信号
   - 更新买入信号列表

3. **新闻爬取** - 每30分钟
   - 获取财经新闻
   - 更新新闻缓存

4. **历史数据全量刷新** - 每天17:30（交易日）
   - 清空所有K线数据
   - 重新获取最新历史数据
   - 重新计算所有信号

---

## ⚙️ 高级配置

### 信号计算优化参数

修改 `app/services/signal/signal_manager.py`：

```python
# 批处理大小（每批处理的股票数）
batch_size = 500  # 默认500只

# 并发数量（同时处理的股票数）
semaphore = asyncio.Semaphore(100)  # 默认100并发
```

### Tushare API限速

修改 `app/core/config.py`：

```python
# 根据Tushare权限等级调整
TUSHARE_TOKEN = "your_token"  # 每分钟请求次数取决于权限
```

---

## 🔍 监控和日志

### 查看初始化进度

```bash
# 实时查看日志
docker-compose logs -f stock_backend

# 查看初始化状态
curl http://localhost:8000/api/stocks/status
```

### 关键日志标识

- `🚀 初始化模式: xxx` - 启动模式
- `📥 步骤1: 初始化股票和ETF清单` - 获取列表
- `📥 步骤2: 清空历史数据` - 清理旧数据
- `📥 步骤3: 获取历史数据` - 下载K线
- `📥 步骤4: 获取新闻资讯` - 新闻更新
- `📥 步骤5: 计算买入信号` - 信号计算
- `✅ 【xxx】模式初始化完成` - 完成标识

---

## ❓ 常见问题

### Q1: 初始化太慢怎么办？
A: 
- 使用 `tasks_only` 模式跳过K线数据获取
- 检查网络连接和Tushare API限速
- 增加并发数（修改 `signal_manager.py`）

### Q2: Docker部署后环境变量不生效？
A: 
- 确认 `docker-compose.yml` 中正确设置了环境变量
- 重新构建镜像：`docker-compose build --no-cache`
- 检查日志中显示的初始化模式是否正确

### Q3: 如何验证数据初始化成功？
A:
```bash
# 检查Redis数据
redis-cli HLEN stock_list  # 应该 > 5000
redis-cli HLEN buy_signals  # 应该 > 0
redis-cli GET "stock_trend:000001.SZ"  # 应有K线数据

# 检查API接口
curl http://localhost:8000/api/stocks/signal/buy
```

### Q4: 信号计算卡住其他请求？
A: 已优化为后台执行，不会阻塞。如仍有问题：
- 检查 `signal_manager.py` 中的并发设置
- 使用 `/api/signals/calculate` 手动触发（后台执行）

---

## 📝 更新日志

### 2025-11-05
- ✅ 统一ETF和股票的Redis Key格式（`stock_trend:*`）
- ✅ 优化信号计算性能（批处理500只，并发100）
- ✅ 修复API计算阻塞问题（改为后台线程执行）
- ✅ 完善初始化模式说明文档

---

**如有问题，请查看日志或联系开发团队！** 🚀

