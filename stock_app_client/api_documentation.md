# 股票API接口文档

## 目录
- [基本信息](#基本信息)
- [股票筛选接口](#股票筛选接口)
  - [获取买入信号股票列表](#获取买入信号股票列表)
  - [获取卖出信号股票列表](#获取卖出信号股票列表)
- [数据更新管理接口](#数据更新管理接口)
  - [覆盖最近N天历史数据](#覆盖最近n天历史数据)
  - [初始化股票历史数据](#初始化股票历史数据)
  - [开始实时数据更新](#开始实时数据更新)
  - [清理历史数据](#清理历史数据)

## 基本信息

本文档描述了股票应用的REST API接口规范，包括请求方法、参数和返回值。所有接口返回JSON格式数据。

- 基础URL：`http://$apiBaseUrl:8000`
- 认证方式：无需认证

## 股票筛选接口

### 获取买入信号股票列表

获取具有买入信号的股票列表，支持不同交易策略。

- **URL**: `/api/stocks/signal/buy`
- **方法**: `GET`
- **参数**:

| 参数名 | 类型 | 必填 | 默认值 | 描述 |
|--------|------|------|--------|------|
| limit | integer | 否 | 100 | 返回记录数限制 |
| force_refresh | boolean | 否 | false | 是否强制刷新缓存 |
| strategy | string | 否 | "volume_wave" | 策略类型，可选值:<br> - `volume_wave`: 波动策略<br> - `trend_continuation`: 123趋势形态 |

- **响应示例**:

```json
{
  "total": 25,
  "returned": 25,
  "updating": false,
  "last_update": "2023-08-20T15:30:00",
  "strategy": "volume_wave",
  "stocks": [
    {
      "code": "000001",
      "name": "平安银行",
      "board": "银行",
      "chart_url": "/chart/000001?strategy=volume_wave",
      "latest_price": 10.56,
      "signal_date": "2023-08-20",
      "kline_date": "2025-06-20",
      "calculated_time": "2025-06-21T03:47:33.198295",
      "change_percent": 2.5,
      "volume": 12345678,
      "strategy": "volume_wave",
      "strategy_name": "量价波动"
    },
    // ...更多股票
  ]
}
```

### 获取卖出信号股票列表

获取具有卖出信号的股票列表，支持不同交易策略。

- **URL**: `/api/stocks/signal/sell`
- **方法**: `GET`
- **参数**:

| 参数名 | 类型 | 必填 | 默认值 | 描述 |
|--------|------|------|--------|------|
| limit | integer | 否 | 100 | 返回记录数限制 |
| force_refresh | boolean | 否 | false | 是否强制刷新缓存 |
| strategy | string | 否 | "volume_wave" | 策略类型，可选值:<br> - `volume_wave`: 波动策略<br> - `trend_continuation`: 123趋势形态 |

- **响应示例**:

```json
{
  "total": 18,
  "returned": 18,
  "updating": false,
  "last_update": "2023-08-20T15:30:00",
  "strategy": "trend_continuation",
  "stocks": [
    {
      "code": "600000",
      "name": "浦发银行",
      "board": "银行",
      "chart_url": "/chart/600000?strategy=trend_continuation",
      "latest_price": 8.75,
      "signal_date": "2023-08-20",
      "change_percent": -1.2,
      "volume": 9876543,
      "strategy": "trend_continuation"
    },
    // ...更多股票
  ]
}
```

## 数据更新管理接口

### 覆盖最近N天历史数据

使用多线程覆盖所有股票最近N天的历史数据，确保数据准确性。

- **URL**: `/api/stocks/history/cover-latest`
- **方法**: `POST`
- **参数**:

| 参数名 | 类型 | 必填 | 默认值 | 描述 |
|--------|------|------|--------|------|
| days | integer | 否 | 10 | 覆盖最近多少天的数据 |
| max_workers | integer | 否 | 5 | 最大线程数，用于并发处理 |

- **响应示例**:

```json
{
  "message": "已覆盖2345只股票最近10天历史数据",
  "total": 3000,
  "updated": 2345,
  "failed": 655
}
```

### 初始化股票历史数据

初始化指定天数的历史数据，可选择单只股票或所有股票。

- **URL**: `/api/stocks/history/init`
- **方法**: `POST`
- **参数**:

| 参数名 | 类型 | 必填 | 默认值 | 描述 |
|--------|------|------|--------|------|
| stock_code | string | 否 | null | 股票代码，不填则处理所有股票 |
| days | integer | 否 | 120 | 获取历史数据的天数（交易日） |
| max_workers | integer | 否 | 5 | 最大线程数，用于并发处理 |

- **响应示例**:

```json
{
  "message": "历史数据初始化任务已启动",
  "status": "started",
  "stock_count": 3000,
  "max_workers": 5
}
```

### 开始实时数据更新

开始实时数据更新任务，定期获取最新行情。

- **URL**: `/api/stocks/realtime/update`
- **方法**: `POST`
- **参数**:

| 参数名 | 类型 | 必填 | 默认值 | 描述 |
|--------|------|------|--------|------|
| interval | integer | 否 | 120 | 更新间隔(秒) |
| max_workers | integer | 否 | 5 | 最大线程数，用于并发处理 |

- **响应示例**:

```json
{
  "message": "实时数据更新任务已启动",
  "status": "started",
  "interval": 120,
  "max_workers": 5
}
```

### 清理历史数据

清理所有股票的历史数据，确保每只股票最多只保留最新的N条记录。

- **URL**: `/api/stocks/cleanup`
- **方法**: `POST`
- **参数**: 无

- **响应示例**:

```json
{
  "message": "清理完成,共清理 3000 只股票的 150000 条记录",
  "result": {
    "cleaned_stocks": 3000,
    "total_removed": 150000
  }
}
```

## 前端集成指南

### 交易策略支持

系统目前支持两种交易策略:

1. **波动策略 (volume_wave)**
   - 基于波动率和成交量变化来识别交易机会
   - 适用于短期波段操作

2. **123趋势形态 (trend_continuation)**
   - 基于123趋势延续模式，提供入场、止损和止盈价格参考点
   - 更适合中期趋势跟踪

### 前端实现建议

1. **策略选择器**
   - 在股票筛选页面加入策略切换下拉菜单
   - 选项包括: "波动策略" 和 "123趋势形态"

2. **URL参数兼容**
   - 确保URL中包含strategy参数，便于分享和保存特定策略的筛选结果
   - 例如: `/stocks/signals?type=buy&strategy=trend_continuation`

3. **图表显示**
   - 根据不同策略，需要显示不同的技术指标线
   - 波动策略: 显示EMA6, EMA17线
   - 趋势形态: 显示趋势线和关键点位

4. **信号详情**
   - 为不同策略的信号提供不同的详情展示
   - 趋势形态策略额外提供止损和目标价格

### 示例调用代码

```javascript
// 获取波动策略买入信号
async function getVolumeWaveBuySignals() {
  const response = await fetch('/api/stocks/signal/buy?strategy=volume_wave&limit=50');
  return await response.json();
}

// 获取趋势形态卖出信号
async function getTrendContinuationSellSignals() {
  const response = await fetch('/api/stocks/signal/sell?strategy=trend_continuation&limit=50');
  return await response.json();
}

// 强制刷新信号缓存
async function forceRefreshSignals() {
  const response = await fetch('/api/stocks/signal/buy?force_refresh=true&limit=1');
  return await response.json();
}
``` 