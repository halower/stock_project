# 需要删除的API清单

> 最后更新时间：2025-11-08

## 📋 接口分类

### 1. 系统状态接口

| 接口路径 | 方法 | 说明 | 文件位置 |
|---------|------|------|---------|
| `/` | GET | 系统状态 | system.py |
| `/api/stocks/status` | GET | 数据状态统计 | system.py |

### 2. 股票数据接口

| 接口路径 | 方法 | 说明 | 文件位置 |
|---------|------|------|---------|
| `/api/stocks/search` | GET | 股票搜索 | stocks_redis.py |

>  股票搜索好像是前端完成的？

### 3. 买入信号接口

| 接口路径 | 方法 | 说明 | 文件位置 |
|---------|------|------|---------|
| `/api/signals/calculate` | POST | 手动计算买入信号（后台执行） | signal_management.py |

### 4. 股票图表接口

| 接口路径 | 方法 | 说明 | 文件位置 |
|---------|------|------|---------|
| `/api/stocks/{stock_code}/chart` | GET | 生成股票K线图表 | chart.py |

> 一般都是查看，这个就不需要了吧，查看的时候自动生成了
### 5. 策略管理接口

| 接口路径 | 方法 | 说明 | 文件位置 |
|---------|------|------|---------|
| `/api/strategies` | GET | 获取所有可用策略 | strategy.py |

### 6. 市场类型接口

| 接口路径 | 方法 | 说明 | 文件位置 |
|---------|------|------|---------|
| `/api/market-types/stats` | GET | 获取市场类型统计 | market_types.py |
| `/market-types/stats` | GET | 获取市场类型统计（兼容路径） | market_types.py |

### 7. 新闻资讯接口

| 接口路径 | 方法 | 说明 | 文件位置 |
|---------|------|------|---------|
| `/api/news/scheduler/status` | GET | 获取新闻调度器状态 | news_analysis.py |
| `/api/news/scheduler/trigger` | POST | 立即触发新闻爬取 | news_analysis.py |
| `/api/news/analysis/status` | GET | 获取财经新闻消息面分析状态 | news_analysis.py |
| `/api/public/stock_news` | GET | 获取个股新闻资讯数据 | public.py |

### 8. 股票AI分析接口

| 接口路径 | 方法 | 说明 | 文件位置 |
|---------|------|------|---------|


### 9. 股票调度器接口

| 接口路径 | 方法 | 说明 | 文件位置 |
|---------|------|------|---------|
| `/api/stocks/scheduler/status` | GET | 获取股票调度器状态 | stock_scheduler_api.py |
| `/api/stocks/scheduler/init` | POST | 初始化股票/ETF系统 | stock_scheduler_api.py |
| `/api/stocks/scheduler/trigger` | POST | 手动触发股票任务 | stock_scheduler_api.py |
| `/api/stocks/scheduler/refresh-stocks` | POST | 刷新股票列表 | stock_scheduler_api.py |
| `/api/scheduler/restart` | POST | 重启所有调度器 | signal_management.py |

### 10. 实时行情配置接口

| 接口路径 | 方法 | 说明 | 文件位置 |
|---------|------|------|---------|
| `/realtime/config` | GET | 获取实时行情配置 | realtime_config.py |
| `/realtime/config` | PUT | 更新实时行情配置 | realtime_config.py |
| `/realtime/stats` | GET | 获取实时行情统计信息 | realtime_config.py |
| `/realtime/stats/reset` | POST | 重置实时行情统计信息 | realtime_config.py |
| `/realtime/test/{provider}` | GET | 测试指定数据源 | realtime_config.py |

### 11. 数据验证接口

| 接口路径 | 方法 | 说明 | 文件位置 |
|---------|------|------|---------|
| `/api/data/validation/today` | GET | 验证当天数据 | data_validation.py |
| `/api/data/validation/stock/{ts_code}` | GET | 验证单个股票数据 | data_validation.py |
| `/api/data/validation/etf/{ts_code}` | GET | 验证单个ETF数据 | data_validation.py |

### 12. 股票数据管理接口

| 接口路径 | 方法 | 说明 | 文件位置 |
|---------|------|------|---------|
| `/api/stock-data/stock-list/status` | GET | 获取股票清单状态 | stock_data_management.py |
| `/api/stock-data/stock-list/search` | GET | 搜索股票 | stock_data_management.py |
| `/api/stock-data/trend-data/status` | GET | 获取股票走势数据状态 | stock_data_management.py |
| `/api/stock-data/trend-data/initialize` | POST | 初始化所有股票走势数据 | stock_data_management.py |
| `/api/stock-data/trend-data/smart-update` | POST | 智能更新股票走势数据 | stock_data_management.py |
| `/api/stock-data/trend-data/{ts_code}/update` | POST | 更新单只股票走势数据 | stock_data_management.py |
| `/api/stock-data/system/status` | GET | 获取系统整体状态 | stock_data_management.py |
| `/api/stock-data/system/startup-check` | POST | 执行启动检查 | stock_data_management.py |
| `/api/stock-data/system/health` | GET | 健康检查 | stock_data_management.py |

### 13. 任务管理接口

| 接口路径 | 方法 | 说明 | 文件位置 |
|---------|------|------|---------|
| `/api/tasks/status/{task_id}` | GET | 获取任务状态 | task_management.py |
| `/api/tasks/list` | GET | 获取所有任务 | task_management.py |
| `/api/tasks/clear` | POST | 清理已完成任务 | task_management.py |
