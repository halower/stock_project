# 系统计划任务和API接口清单

## 📅 生成日期
2025-11-11

---

# 一、计划任务清单

## 1. 股票数据调度器（stock_scheduler.py）

### 启动任务（系统启动时执行）
| 任务ID | 任务名称 | 执行条件 | 说明 |
|--------|---------|---------|------|
| startup_1 | 初始化股票代码 | init_mode='full_init' | 获取并缓存所有股票代码 |
| startup_2 | 初始化K线数据 | init_mode='full_init' | 全量更新180天K线数据 |
| startup_3 | 计算策略信号 | calculate_signals=True | 计算所有买入信号 |

### 运行时任务（定时执行）

#### 1.1 实时数据更新
```python
任务ID: realtime_update
触发方式: IntervalTrigger(minutes=1)  # 可配置
执行函数: RuntimeTasks.job_realtime_update()
执行时间: 每1分钟（仅交易时间9:30-15:00）
说明: 
  - 仅更新股票（不更新ETF）
  - 使用Tushare数据源
  - 更新Redis中的K线数据
  - 不自动触发信号计算
```

**配置项**：
- `REALTIME_UPDATE_INTERVAL=1` （分钟）

#### 1.2 策略信号计算
```python
任务ID: signal_calculation
触发方式: CronTrigger(
    day_of_week='mon-fri',
    hour='9-11,13-15',
    minute='0,10,20,30,40,50'
)
执行函数: RuntimeTasks.job_calculate_signals()
执行时间: 
  - 上午：9:30, 9:50, 10:10, 10:30, 10:50, 11:10, 11:30
  - 下午：13:00, 13:20, 13:40, 14:00, 14:20, 14:40, 15:00, 15:20
说明:
  - 仅计算股票信号（不计算ETF）
  - 使用所有已注册的策略
  - 独立任务，不依赖实时更新
```

#### 1.3 新闻爬取
```python
任务ID: crawl_news
触发方式: IntervalTrigger(hours=2)
执行函数: RuntimeTasks.job_crawl_news()
执行时间: 每2小时
说明:
  - 爬取凤凰财经新闻
  - 缓存到Redis
```

**可选删除**：如果不需要新闻功能

#### 1.4 全量更新并计算信号
```python
任务ID: full_update_and_calculate
触发方式: CronTrigger(hour=17, minute=35, day_of_week='mon-fri')
执行函数: RuntimeTasks.job_full_update_and_calculate()
执行时间: 每个交易日17:35
说明:
  - 清空所有K线数据
  - 重新获取180天数据（股票+ETF）
  - 计算所有信号（股票+ETF）
  - 耗时约8-12分钟
```

#### 1.5 图表文件清理
```python
任务ID: cleanup_charts
触发方式: CronTrigger(hour=0, minute=0)
执行函数: RuntimeTasks.job_cleanup_charts()
执行时间: 每天00:00
说明:
  - 清理7天前的图表文件
  - 节省磁盘空间
```

**可选删除**：如果不使用图表功能

---

## 2. 新闻调度器（news_scheduler.py）

### 运行时任务

#### 2.1 新闻爬取
```python
任务ID: crawl_news
触发方式: CronTrigger(minute=0, second=0, hour='0,3,6,9,12,15,18,21')
执行函数: crawl_and_cache_news()
执行时间: 每3小时（0点、3点、6点、9点、12点、15点、18点、21点）
说明:
  - 爬取凤凰财经新闻
  - 缓存到Redis（最多100条）
  - 首次启动时立即执行
```

**可选删除**：与stock_scheduler的新闻爬取功能重复

#### 2.2 日志清理
```python
任务ID: cleanup_logs
触发方式: CronTrigger(hour=3, minute=0, second=0)
执行函数: cleanup_old_logs()
执行时间: 每天凌晨3点
说明:
  - 清理Redis中的过期日志
```

---

# 二、API接口清单

## 1. 股票数据相关

### 1.1 stocks_redis.py（核心数据接口）

| 方法 | 路径 | 说明 | 鉴权 | 推荐保留 |
|------|------|------|------|---------|
| GET | `/api/stocks` | 获取所有股票清单 | ✅ | ✅ **必需** |
| GET | `/api/stocks/history` | 获取股票历史K线数据 | ✅ | ✅ **必需** |
| GET | `/api/stocks/batch-price` | 批量获取股票最新价格 | ✅ | ✅ **必需** |

### 1.2 stock_data_management.py（数据管理接口）

**文件位置**: `app/api/stock_data_management.py`

预计包含的接口（需要查看完整文件）：
- 股票清单管理
- 股票走势数据管理
- 数据状态检查

**建议**: 查看后决定是否保留

---

## 2. 信号相关

### 2.1 signal_management.py（信号管理）

| 方法 | 路径 | 说明 | 鉴权 | 推荐保留 |
|------|------|------|------|---------|
| GET | `/api/stocks/signal/buy` | 获取买入信号 | ✅ | ✅ **必需** |

支持参数：
- `strategy`: 策略过滤（可选）
- `limit`: 返回数量限制
- `sort`: 排序方式

---

## 3. 任务管理

### 3.1 task_management.py（任务触发）

| 方法 | 路径 | 说明 | 鉴权 | 推荐保留 |
|------|------|------|------|---------|
| POST | `/calculate-signals` | 手动触发信号计算 | ✅ | ✅ 推荐保留 |

参数：
- `stock_only`: 是否仅计算股票（默认true）

---

## 4. 图表相关

### 4.1 chart.py（K线图表）

| 方法 | 路径 | 说明 | 鉴权 | 推荐保留 |
|------|------|------|------|---------|
| GET | `/api/stocks/{stock_code}/chart` | 生成股票K线图表（PNG） | ✅ | ❓ 可选 |
| GET | `/api/chart/{stock_code}` | 查看股票图表页面（HTML） | ❌ | ❓ 可选 |

**说明**：
- 生成静态图表文件
- 占用服务器资源
- 前端可以用echarts替代

**建议**: ❌ **可删除**（前端自己画图更灵活）

---

## 5. AI分析相关

### 5.1 stock_ai_analysis.py（AI技术分析）

| 方法 | 路径 | 说明 | 鉴权 | 推荐保留 |
|------|------|------|------|---------|
| GET | `/api/stocks/ai-analysis/cache` | 查询AI分析缓存 | ✅ | ❓ 可选 |
| POST | `/api/stocks/ai-analysis/simple` | 获取股票AI分析 | ✅ | ❓ 可选 |

**说明**：
- 使用AI模型分析股票
- 需要AI API配置
- 耗费AI tokens

**建议**: 根据需求决定

---

## 6. 新闻相关

### 6.1 news_analysis.py（新闻分析）

| 方法 | 路径 | 说明 | 鉴权 | 推荐保留 |
|------|------|------|------|---------|
| GET | `/api/news/latest` | 获取最新新闻 | ✅ | ❓ 可选 |
| POST | `/api/news/analysis` | 分析新闻（AI） | ✅ | ❓ 可选 |
| GET | `/api/news/analysis/status` | 查询新闻分析状态 | ✅ | ❓ 可选 |

**说明**：
- 新闻爬取和分析
- 需要AI API配置

**建议**: ❌ **可删除**（如果不需要新闻功能）

### 6.2 public.py（公共新闻）

| 方法 | 路径 | 说明 | 鉴权 | 推荐保留 |
|------|------|------|------|---------|
| GET | `/api/public/stock_news` | 获取股票新闻 | ✅ | ❓ 与news_analysis重复 |

**建议**: ❌ **可删除**（功能重复）

---

## 7. 策略相关

### 7.1 strategy.py（策略管理）

| 方法 | 路径 | 说明 | 鉴权 | 推荐保留 |
|------|------|------|------|---------|
| GET | `/api/strategies` | 获取所有可用策略 | ✅ | ✅ 推荐保留 |

**说明**：
- 返回系统中注册的所有交易策略
- 包括策略参数说明

---

## 8. 市场类型

### 8.1 market_types.py（市场分类）

| 方法 | 路径 | 说明 | 鉴权 | 推荐保留 |
|------|------|------|------|---------|
| GET | `/api/market-types` | 获取所有市场类型 | ✅ | ✅ 推荐保留 |
| GET | `/market-types` | 获取所有市场类型（兼容） | ✅ | ⚠️ 二选一 |

**说明**：
- 返回市场分类（主板、创业板、科创板等）
- 用于前端筛选

**建议**: 保留 `/api/market-types`，删除 `/market-types`

---

## 9. 实时配置

### 9.1 realtime_config.py（实时行情配置）

**文件位置**: `app/api/realtime_config.py`

预计包含的接口：
- 获取实时配置
- 更新实时配置
- 获取统计信息

**说明**: 现在只有Tushare，配置接口意义不大

**建议**: ❌ **可删除**（配置已简化）

---

## 10. 数据验证

### 10.1 data_validation.py（数据完整性检查）

预计包含的接口：
- 检查今日数据
- 验证数据完整性

**建议**: ✅ **保留**（用于运维检查）

---

## 11. 系统状态

### 11.1 system.py（系统信息）

**文件位置**: `app/api/system.py`

预计包含的接口：
- 系统健康检查
- 服务状态查询

**建议**: ✅ **保留**（基础接口）

---

# 三、删除建议汇总

## 🔴 建议删除的定时任务

### 1. 新闻调度器（整个文件）
**文件**: `app/services/scheduler/news_scheduler.py`

**原因**：
- 与stock_scheduler的新闻爬取功能重复
- 独立运行的调度器增加复杂度

**影响**：
- 新闻功能仍可通过stock_scheduler的任务使用
- 或者完全删除新闻功能

### 2. 图表清理任务
**任务ID**: `cleanup_charts`  
**文件**: `stock_scheduler.py` 第587-594行

**原因**：
- 如果删除图表生成功能，清理任务也不需要

---

## 🔴 建议删除的API接口

### 1. 图表相关（chart.py）
**删除整个文件**: `app/api/chart.py`

**原因**：
- 后端生成图表占用资源
- 前端使用echarts更灵活
- 图表文件需要存储和管理

**影响**：
- 需要删除图表清理任务
- 需要删除chart目录

### 2. 新闻相关
**删除文件**：
- `app/api/news_analysis.py`
- `app/api/public.py`

**原因**：
- 新闻功能使用率低
- 需要额外的爬虫维护
- AI分析消耗tokens

**影响**：
- 删除新闻爬取任务
- 删除新闻调度器

### 3. 实时配置API
**删除文件**: `app/api/realtime_config.py`

**原因**：
- 现在只使用Tushare
- 配置已经简化
- 不需要动态配置

### 4. 重复路径
**删除**: `market_types.py` 中的 `/market-types`

**保留**: `/api/market-types`

**原因**: 路径统一，避免混乱

---

## ⚠️ 可选删除（根据需求）

### 1. AI分析接口
**文件**: `app/api/stock_ai_analysis.py`

**考虑因素**：
- 需要AI API配置
- 消耗tokens
- 使用频率

**建议**: 如果不使用AI功能就删除

### 2. 新闻爬取任务
**任务ID**: `crawl_news` (stock_scheduler.py)

**考虑因素**：
- 新闻功能的必要性
- 维护成本

**建议**: 如果删除新闻API，一并删除

---

## ✅ 必须保留的核心功能

### 定时任务
1. ✅ 实时数据更新（realtime_update）
2. ✅ 策略信号计算（signal_calculation）
3. ✅ 全量更新（full_update_and_calculate）

### API接口
1. ✅ `/api/stocks` - 股票清单
2. ✅ `/api/stocks/history` - 历史数据
3. ✅ `/api/stocks/signal/buy` - 买入信号
4. ✅ `/api/strategies` - 策略列表
5. ✅ `/api/market-types` - 市场类型
6. ✅ `/calculate-signals` - 手动触发计算

---

# 四、删除操作清单

## 步骤1：删除文件
```bash
# 删除图表相关
rm -f app/api/chart.py

# 删除新闻相关
rm -f app/api/news_analysis.py
rm -f app/api/public.py

# 删除实时配置
rm -f app/api/realtime_config.py

# 删除新闻调度器
rm -f app/services/scheduler/news_scheduler.py

# 删除AI分析（可选）
# rm -f app/api/stock_ai_analysis.py
```

## 步骤2：修改调度器
**文件**: `app/services/scheduler/stock_scheduler.py`

删除以下任务：
```python
# 删除新闻爬取任务（第569-576行）
scheduler.add_job(
    func=RuntimeTasks.job_crawl_news,
    ...
)

# 删除图表清理任务（第587-594行）
scheduler.add_job(
    func=RuntimeTasks.job_cleanup_charts,
    ...
)
```

## 步骤3：删除路由注册
**文件**: `app/api/__init__.py`

删除对应的router导入和注册

## 步骤4：清理依赖
检查并删除不再使用的依赖包（如akshare用于新闻爬取）

---

# 五、最终精简架构

## 保留的定时任务（3个）
1. 实时数据更新（每1分钟）
2. 策略信号计算（每20分钟左右）
3. 全量更新（每日17:35）

## 保留的核心API（8-10个）
1. 股票清单
2. 历史数据
3. 买入信号
4. 策略列表
5. 市场类型
6. 批量价格
7. 手动触发计算
8. 数据验证
9. 系统状态
10. （可选）AI分析

## 预期效果
- **代码减少**: ~30%
- **维护成本**: 降低
- **系统复杂度**: 降低
- **核心功能**: 不受影响

---

**最后更新**: 2025-11-11

