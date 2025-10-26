# ETF实时行情功能说明

## 📋 功能概述

已为系统添加完整的ETF实时行情更新功能，支持：
- ✅ 多数据源（东方财富、新浪财经）
- ✅ 自动切换和故障转移
- ✅ 定时自动更新（交易时间内）
- ✅ K线数据实时合并
- ✅ 防封策略（限流、随机延迟）
- ✅ 完整的配置管理API

## 🎯 核心特性

### 1. 多数据源支持

| 数据源 | 接口 | 特点 | 返回字段 |
|--------|------|------|----------|
| **东方财富** | `ak.fund_etf_spot_em()` | 数据全面、更新快 | 包含IOPV、折价率、资金流向等 |
| **新浪财经** | `ak.fund_etf_category_sina()` | 稳定性好 | 基础行情数据 |

**代码格式处理**：
- 东方财富：返回标准6位代码（`510050`、`159949`）
- 新浪财经：返回带前缀代码（`sh510050`、`sz159949`），已自动清理

### 2. 自动更新机制

#### 定时任务
```
交易时间内每60分钟自动更新（可配置）
├─ 9:30-11:30  上午交易时段
├─ 13:00-15:00 下午交易时段
└─ 15:00-15:30 收盘后数据窗口
```

#### 更新流程
```
1. 读取ETF列表 (app/etf/ETF列表.csv)
2. 调用实时行情接口获取数据
3. 存储到Redis (etf:realtime)
4. 合并到K线数据 (etf_trend:{ts_code})
5. 记录日志和统计
```

### 3. 数据存储结构

#### Redis键名规则
```python
ETF_KEYS = {
    'etf_codes': 'etf:codes:all',           # ETF代码列表
    'etf_realtime': 'etf:realtime',         # 实时数据
    'etf_kline': 'etf_trend:{}',            # K线数据（需要ts_code）
    'etf_signals': 'etf:buy_signals',       # 策略信号（预留）
    'etf_scheduler_log': 'etf:scheduler:log', # 调度日志
    'etf_last_update': 'etf:last_update'    # 最后更新时间
}
```

#### 实时数据格式
```json
{
  "data": {
    "510050": {
      "code": "510050",
      "name": "上证50ETF",
      "price": 2.856,
      "change": 0.012,
      "change_percent": 0.42,
      "volume": 12345678,
      "amount": 35234567.89,
      "open": 2.850,
      "high": 2.860,
      "low": 2.845,
      "pre_close": 2.844,
      "turnover_rate": 1.23,
      "iopv": 2.857,
      "discount_rate": -0.03,
      "update_time": "2025-10-26 14:30:00"
    }
  },
  "update_time": "2025-10-26 14:30:00",
  "source": "eastmoney",
  "count": 51
}
```

## 🔧 配置参数

### 环境变量（docker-compose.yml）

```yaml
# ETF实时行情配置
- ETF_REALTIME_PROVIDER=eastmoney    # 数据源: eastmoney/sina/auto
- ETF_UPDATE_INTERVAL=60             # 更新间隔（分钟）
- ETF_AUTO_SWITCH=true               # 自动切换数据源
- ETF_RETRY_TIMES=2                  # 重试次数
- ETF_MIN_REQUEST_INTERVAL=3.0       # 最小请求间隔（秒）
```

### 配置说明

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `ETF_REALTIME_PROVIDER` | `eastmoney` | 默认数据源 |
| `ETF_UPDATE_INTERVAL` | `60` | 每60分钟更新一次 |
| `ETF_AUTO_SWITCH` | `true` | 主源失败自动切换到备用源 |
| `ETF_RETRY_TIMES` | `2` | 每个数据源重试2次 |
| `ETF_MIN_REQUEST_INTERVAL` | `3.0` | 请求间隔至少3秒（防封） |

## 📡 API接口

### 1. 获取ETF配置
```bash
GET /api/etf/config
```

**响应示例**：
```json
{
  "success": true,
  "data": {
    "default_provider": "eastmoney",
    "auto_switch": true,
    "retry_times": 2,
    "min_request_interval": 3.0
  }
}
```

### 2. 更新ETF配置
```bash
PUT /api/etf/config
Content-Type: application/json

{
  "default_provider": "sina",
  "auto_switch": true,
  "retry_times": 3
}
```

### 3. 获取统计信息
```bash
GET /api/etf/stats
```

**响应示例**：
```json
{
  "success": true,
  "data": {
    "eastmoney": {
      "success": 15,
      "fail": 0,
      "last_success_time": "2025-10-26 14:30:00"
    },
    "sina": {
      "success": 2,
      "fail": 1,
      "last_success_time": "2025-10-26 13:00:00"
    },
    "total_requests": 17,
    "auto_switches": 1
  }
}
```

### 4. 测试数据源
```bash
GET /api/etf/test/eastmoney
GET /api/etf/test/sina
```

**响应示例**：
```json
{
  "success": true,
  "data": {
    "provider": "eastmoney",
    "count": 51,
    "elapsed_time": 2.35,
    "sample_data": [
      {
        "code": "510050",
        "name": "上证50ETF",
        "price": 2.856
      }
    ]
  }
}
```

### 5. 初始化ETF历史数据
```bash
POST /api/etf/init
Authorization: Bearer eXvM4zU8nP9qWt3dRfKgH7jBcA2yE5sZ
```

**功能**：
- 读取`app/etf/ETF列表.csv`
- 逐个获取最近1年的历史K线数据
- 存储到Redis（`etf_trend:{ts_code}`）

**预计耗时**：约5-10分钟（51只ETF）

### 6. 手动更新ETF实时数据
```bash
POST /api/etf/update
Authorization: Bearer eXvM4zU8nP9qWt3dRfKgH7jBcA2yE5sZ
```

**功能**：
- 立即获取所有ETF实时数据
- 更新到Redis
- 合并到K线数据

## 🚀 使用流程

### 首次使用

#### 1. 初始化历史数据
```bash
curl -X POST "http://your-server:8000/api/etf/init" \
  -H "Authorization: Bearer eXvM4zU8nP9qWt3dRfKgH7jBcA2yE5sZ"
```

**日志示例**：
```
🚀 开始初始化ETF历史K线数据...
📋 读取ETF列表: 51 只
[1/51] 获取 上证50ETF(510050) 历史数据...
  ✅ 上证50ETF(510050) 成功: 245 条K线
[2/51] 获取 中证1000ETF(512100) 历史数据...
  ✅ 中证1000ETF(512100) 成功: 189 条K线
...
🎉 ETF历史数据初始化完成: 成功 51 只，失败 0 只，耗时 325.67秒
```

#### 2. 启动定时更新

服务启动后会自动启动定时任务，无需手动操作。

查看调度器状态：
```bash
curl "http://your-server:8000/api/stocks/scheduler/status" \
  -H "Authorization: Bearer eXvM4zU8nP9qWt3dRfKgH7jBcA2yE5sZ"
```

### 日常使用

#### 手动触发更新
```bash
curl -X POST "http://your-server:8000/api/etf/update" \
  -H "Authorization: Bearer eXvM4zU8nP9qWt3dRfKgH7jBcA2yE5sZ"
```

#### 查看更新日志
```bash
tail -f logs/app.log | grep ETF
```

**日志示例**：
```
2025-10-26 14:30:00 - INFO - 🎯 开始更新ETF实时数据...
2025-10-26 14:30:00 - INFO - 📋 读取ETF列表: 51 只
2025-10-26 14:30:03 - INFO - ✅ 成功从 eastmoney 获取 51 只ETF实时数据
2025-10-26 14:30:03 - INFO - 📊 开始合并ETF实时数据到K线，共 51 只ETF
2025-10-26 14:30:04 - INFO - 📊 ETF K线合并完成: 成功更新 51 只，跳过（无K线数据）0 只
2025-10-26 14:30:04 - INFO - 🎉 ETF实时数据更新完成: 51只，K线更新: 51只，耗时 4.12秒
```

## 🛠️ 技术实现

### 核心文件

| 文件 | 说明 |
|------|------|
| `app/services/etf_realtime_service.py` | ETF实时行情服务（核心） |
| `app/services/stock_scheduler.py` | 调度器（新增ETF任务） |
| `app/api/etf_config.py` | ETF配置管理API |
| `app/core/config.py` | 配置参数定义 |
| `app/etf/ETF列表.csv` | ETF列表（51只精选） |
| `docker-compose.yml` | 环境变量配置 |

### 关键类和函数

#### ETFRealtimeService
```python
class ETFRealtimeService:
    """ETF实时行情服务"""
    
    def get_all_etfs_realtime(provider=None) -> Dict
        """获取所有ETF实时数据"""
    
    def get_single_etf_realtime(etf_code, provider=None) -> Dict
        """获取单只ETF实时数据"""
    
    def _fetch_eastmoney_etf() -> Dict
        """从东方财富获取数据"""
    
    def _fetch_sina_etf() -> Dict
        """从新浪财经获取数据"""
```

#### 调度器函数
```python
def update_etf_realtime_data(force_update=False):
    """更新ETF实时数据（主函数）"""

def _merge_etf_realtime_to_kline(realtime_dict) -> int:
    """合并实时数据到K线"""

def init_etf_kline_data():
    """初始化ETF历史K线数据"""
```

## 🔍 数据源对比

### 东方财富 vs 新浪财经

| 对比项 | 东方财富 | 新浪财经 |
|--------|----------|----------|
| **数据全面性** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| **更新速度** | 快 | 中等 |
| **稳定性** | 中等 | 好 |
| **特色字段** | IOPV、折价率、资金流向 | 无 |
| **代码格式** | 标准6位 | 带前缀（已处理） |
| **推荐场景** | 日常使用 | 备用/故障转移 |

### 接口返回字段对比

| 字段 | 东方财富 | 新浪财经 | 说明 |
|------|----------|----------|------|
| 基础价格 | ✅ | ✅ | 最新价、涨跌额、涨跌幅 |
| 成交数据 | ✅ | ✅ | 成交量、成交额 |
| 换手率 | ✅ | ❌ | 东财独有 |
| IOPV | ✅ | ❌ | 实时估值 |
| 折价率 | ✅ | ❌ | 溢价/折价 |
| 资金流向 | ✅ | ❌ | 主力/大单/中单/小单 |

## 📊 监控和诊断

### 查看ETF数据
```bash
# 查看ETF代码列表
redis-cli GET etf:codes:all

# 查看实时数据
redis-cli GET etf:realtime

# 查看某只ETF的K线数据
redis-cli GET etf_trend:510050.SH
```

### 常见问题诊断

#### 1. K线更新为0
**症状**：
```
ETF实时数据更新完成: 51只，K线更新: 0只
```

**原因**：
- 没有初始化历史K线数据

**解决**：
```bash
curl -X POST "http://your-server:8000/api/etf/init" \
  -H "Authorization: Bearer eXvM4zU8nP9qWt3dRfKgH7jBcA2yE5sZ"
```

#### 2. 数据源失败
**症状**：
```
ETF实时数据更新失败: 所有数据源均失败
```

**原因**：
- 网络问题
- IP被封
- 接口变更

**解决**：
1. 测试各数据源：
```bash
curl "http://your-server:8000/api/etf/test/eastmoney"
curl "http://your-server:8000/api/etf/test/sina"
```

2. 切换数据源：
```bash
curl -X PUT "http://your-server:8000/api/etf/config" \
  -H "Content-Type: application/json" \
  -d '{"default_provider": "sina"}'
```

3. 调整请求间隔：
```bash
curl -X PUT "http://your-server:8000/api/etf/config" \
  -H "Content-Type: application/json" \
  -d '{"min_request_interval": 5.0}'
```

## 🎯 最佳实践

### 1. 数据源选择
```
推荐配置: auto（自动选择）
├─ 优先使用东方财富（数据全面）
└─ 失败时自动切换到新浪（稳定性好）
```

### 2. 更新频率
```
交易时间内: 60分钟（默认）
├─ 频繁更新意义不大（ETF波动相对平缓）
├─ 避免过度请求被封IP
└─ 节省服务器资源
```

### 3. 防封策略
```
已内置防封机制:
├─ 请求限流（最小间隔3秒）
├─ 随机延迟（0-0.5秒扰动）
├─ 重试机制（失败重试2次）
└─ 自动切换（主源失败切换备用）
```

### 4. 监控建议
```
定期检查:
├─ 查看统计信息（成功率、失败次数）
├─ 监控日志（是否频繁切换数据源）
├─ 验证数据完整性（K线是否正常更新）
└─ 关注更新耗时（是否异常增加）
```

## 📝 更新日志

### v1.0.0 (2025-10-26)
- ✅ 实现ETF实时行情服务
- ✅ 支持东方财富和新浪财经双数据源
- ✅ 自动切换和故障转移
- ✅ 定时自动更新（60分钟间隔）
- ✅ K线数据实时合并
- ✅ 完整的配置管理API
- ✅ 防封策略（限流、随机延迟）
- ✅ 精选51只核心ETF

## 🔮 未来扩展

### 计划功能
1. **ETF信号计算**
   - 类似股票的买卖信号
   - 基于技术指标的策略

2. **ETF组合分析**
   - 板块轮动分析
   - 相关性分析

3. **更多数据源**
   - 支持更多数据提供商
   - 动态IP池（防封）

4. **实时推送**
   - WebSocket实时推送
   - 价格异动提醒

## 📞 技术支持

### 相关文档
- `防封策略说明.md` - 防封策略详解
- `实时行情服务使用说明.md` - 股票实时行情说明
- `ETF精选说明.md` - ETF筛选标准

### 问题反馈
如遇到问题，请提供：
1. 错误日志（`logs/app.log`）
2. 配置信息（`/api/etf/config`）
3. 统计信息（`/api/etf/stats`）
4. 复现步骤

---

**版本**: v1.0.0  
**更新时间**: 2025-10-26  
**作者**: AI Assistant

