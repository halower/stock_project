# 后端HTTP接口清单

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
| `/api/stocks` | GET | 获取所有股票清单 | stocks_redis.py |
| `/api/stocks/search` | GET | 股票搜索 | stocks_redis.py |
| `/api/stocks/history` | GET | 获取股票历史数据 | stocks_redis.py |
| `/api/stocks/codes` | GET | 获取股票代码列表 | stock_scheduler_api.py |
| `/api/stocks/batch-price` | GET | 批量获取股票价格信息 | stock_scheduler_api.py |

### 3. 买入信号接口

| 接口路径 | 方法 | 说明 | 文件位置 |
|---------|------|------|---------|
| `/api/stocks/signal/buy` | GET | 获取买入信号 | signal_management.py |
| `/api/signals/calculate` | POST | 手动计算买入信号（后台执行） | signal_management.py |

### 4. 股票图表接口

| 接口路径 | 方法 | 说明 | 文件位置 |
|---------|------|------|---------|
| `/api/stocks/{stock_code}/chart` | GET | 生成股票K线图表 | chart.py |
| `/api/chart/{stock_code}` | GET | 查看股票图表页面 | chart.py |

### 5. 策略管理接口

| 接口路径 | 方法 | 说明 | 文件位置 |
|---------|------|------|---------|
| `/api/strategies` | GET | 获取所有可用策略 | strategy.py |

### 6. 市场类型接口

| 接口路径 | 方法 | 说明 | 文件位置 |
|---------|------|------|---------|
| `/api/market-types` | GET | 获取所有市场类型 | market_types.py |
| `/market-types` | GET | 获取所有市场类型（兼容路径） | market_types.py |
| `/api/market-types/stats` | GET | 获取市场类型统计 | market_types.py |
| `/market-types/stats` | GET | 获取市场类型统计（兼容路径） | market_types.py |

### 7. 新闻资讯接口

| 接口路径 | 方法 | 说明 | 文件位置 |
|---------|------|------|---------|
| `/api/news/latest` | GET | 获取最新财经新闻 | news_analysis.py |
| `/api/news/scheduler/status` | GET | 获取新闻调度器状态 | news_analysis.py |
| `/api/news/scheduler/trigger` | POST | 立即触发新闻爬取 | news_analysis.py |
| `/api/news/analysis` | POST | 获取财经新闻消息面分析 | news_analysis.py |
| `/api/news/analysis/status` | GET | 获取财经新闻消息面分析状态 | news_analysis.py |
| `/api/public/stock_news` | GET | 获取个股新闻资讯数据 | public.py |

### 8. 股票AI分析接口

| 接口路径 | 方法 | 说明 | 文件位置 |
|---------|------|------|---------|
| `/api/stocks/ai-analysis/cache` | GET | 查询股票AI分析缓存 | stock_ai_analysis.py |
| `/api/stocks/ai-analysis/simple` | POST | 获取股票AI分析 | stock_ai_analysis.py |

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
| `/api/stock-data/stock-list/initialize` | POST | 初始化股票清单 | stock_data_management.py |
| `/api/stock-data/stock-list/search` | GET | 搜索股票 | stock_data_management.py |
| `/api/stock-data/trend-data/status` | GET | 获取股票走势数据状态 | stock_data_management.py |
| `/api/stock-data/trend-data/initialize` | POST | 初始化所有股票走势数据 | stock_data_management.py |
| `/api/stock-data/trend-data/smart-update` | POST | 智能更新股票走势数据 | stock_data_management.py |
| `/api/stock-data/trend-data/{ts_code}` | GET | 获取单只股票走势数据 | stock_data_management.py |
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

## 📊 接口统计

- **总接口数量**: 约60个
- **GET接口**: 约42个
- **POST接口**: 约18个
- **PUT接口**: 1个

## 🔐 认证说明

大部分接口需要通过 `verify_token` 进行身份验证，需要在请求头或查询参数中提供有效的token。

## 📝 使用建议

1. **常用接口**：
   - `/api/stocks` - 获取股票列表
   - `/api/stocks/signal/buy` - 获取买入信号
   - `/api/stocks/history` - 获取历史数据
   - `/api/news/latest` - 获取最新新闻

2. **管理接口**：
   - `/api/stocks/scheduler/status` - 查看调度器状态
   - `/api/stocks/scheduler/init` - 初始化系统
   - `/api/signals/calculate` - 手动计算信号

3. **监控接口**：
   - `/api/stocks/status` - 数据状态
   - `/api/data/validation/today` - 数据验证
   - `/realtime/stats` - 实时行情统计

## ⚠️ 注意事项

1. 部分接口执行时间较长，建议使用异步方式调用
2. 批量查询接口有数量限制，注意分批处理
3. 实时数据更新接口建议在交易时间调用
4. 定期检查调度器状态，确保自动任务正常运行

