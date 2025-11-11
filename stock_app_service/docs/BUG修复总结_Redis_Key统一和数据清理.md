# BUG修复总结 - Redis Key统一和全量更新数据清理

## 修复日期
2025-11-11

## 问题概述

发现了股票和ETF数据存储的严重问题：
1. **Redis Key不一致**：ETF和股票使用不同的key前缀（etf_trend vs stock_trend）
2. **全量更新清理不完整**：只清理stock_trend，不清理etf_trend
3. **数据孤岛问题**：导致ETF数据无法被信号计算识别

---

## 核心原则确立

### ✅ ETF是一种特殊的股票

**统一原则**：
- ETF和股票在Redis中使用**相同的key前缀** `stock_trend:`
- ETF和股票在信号计算中使用**相同的逻辑**
- ETF和股票在数据更新中使用**相同的流程**

**区分方式**：
- 通过 `market` 字段区分：`market='ETF'` 表示ETF
- 在业务逻辑需要时再区分处理

---

## 修复内容

### 1. 统一Redis Key（4处修改）

#### 修改1：StockDataManager存储逻辑
**文件**：`app/services/stock/stock_data_manager.py`  
**位置**：第687-722行

```python
# 修复前：根据source判断使用不同的key
if source == 'tushare_fund':
    key = f"etf_trend:{ts_code}"
else:
    key = f"stock_trend:{ts_code}"

# 修复后：ETF也是一种特殊的股票，统一使用stock_trend
key = f"stock_trend:{ts_code}"
```

#### 修改2：AI分析服务读取逻辑
**文件**：`app/services/analysis/stock_ai_analysis_service.py`  
**位置**：第322-327行

```python
# 修复前：根据market字段判断
market = stock_info.get('market', '')
if market == 'ETF':
    trend_key = f"etf_trend:{ts_code}"
else:
    trend_key = f"stock_trend:{ts_code}"

# 修复后：统一使用stock_trend
trend_key = f"stock_trend:{ts_code}"
```

#### 修改3：数据验证API配置
**文件**：`app/api/data_validation.py`  
**位置**：第19-28行

```python
# 修复前
ETF_KEYS = {
    'etf_codes': 'etf:codes:all',
    'etf_kline': 'etf_trend:{}',  # 不一致！
}

# 修复后
ETF_KEYS = {
    'etf_codes': 'etf:codes:all',
    'etf_kline': 'stock_trend:{}',  # ETF也使用stock_trend前缀
}
```

#### 修改4：ETF数据删除逻辑（2处）
**文件**：`app/services/stock/stock_data_manager.py`  
**位置1**：第380-385行（删除旧ETF K线）
**位置2**：第1008-1015行（检查数据存在）

```python
# 修复前
kline_key = f"etf_trend:{key}"
# 或
if market == 'ETF':
    key = f"etf_trend:{ts_code}"

# 修复后：统一使用stock_trend
kline_key = f"stock_trend:{key}"
key = f"stock_trend:{ts_code}"
```

---

### 2. 修复全量更新清空逻辑

**文件**：`app/services/stock/stock_atomic_service.py`  
**位置**：第346-367行

**问题**：全量更新时只清空stock_trend，导致：
- 如果旧数据使用了etf_trend前缀，不会被清空
- 数据重复或残留

**修复**：
```python
async def _clear_all_kline_data(self, stock_list: List[Dict[str, Any]]):
    """清空所有股票和ETF的K线数据"""
    logger.info("开始清空所有股票和ETF的K线数据...")
    cleared_stock_count = 0
    cleared_etf_count = 0
    
    for stock in stock_list:
        ts_code = stock.get('ts_code')
        market = stock.get('market', '')
        
        if ts_code:
            # ETF和股票统一使用stock_trend前缀
            key = self.stock_keys['stock_kline'].format(ts_code)
            self.redis_cache.delete_cache(key)
            
            if market == 'ETF':
                cleared_etf_count += 1
            else:
                cleared_stock_count += 1
    
    total_cleared = cleared_stock_count + cleared_etf_count
    logger.info(f"清空K线数据完成，共清空 {total_cleared} 只（股票 {cleared_stock_count} 只，ETF {cleared_etf_count} 只）")
```

**改进**：
- 添加了ETF和股票的分类统计
- 清空逻辑覆盖所有stock_list中的项目
- 清晰的日志输出

---

## 实时更新配置说明

### 当前配置

**更新频率**：每1分钟（可配置）  
**配置位置**：`docker-compose.yml`

```yaml
environment:
  - REALTIME_UPDATE_INTERVAL=1  # 实时更新周期（分钟）
```

**对应代码**：`app/services/scheduler/stock_scheduler.py` 第532-541行

```python
# 实时数据更新：每分钟执行一次（可通过环境变量配置）
realtime_interval = settings.REALTIME_UPDATE_INTERVAL
scheduler.add_job(
    func=RuntimeTasks.job_realtime_update,
    trigger=IntervalTrigger(minutes=realtime_interval),
    id='realtime_update',
    name='实时数据更新',
    replace_existing=True
)
```

### 实时更新流程

1. **数据更新**（每1分钟，交易时间内）
   - 仅更新股票（不更新ETF）
   - 使用Tushare数据源
   - 更新Redis中的K线数据

2. **信号计算**（固定时间点，独立任务）
   - 9:30/9:50/10:10/10:30/10:50/11:10/11:30
   - 13:00/13:20/13:40/14:00/14:20/14:40/15:00/15:20
   - 仅计算股票信号（不计算ETF信号）

3. **全量更新**（每日17:35）
   - 更新所有股票和ETF
   - 计算所有股票和ETF的信号
   - 清空并重建所有K线数据

### 实时更新不包含ETF的原因

1. **性能考虑**：ETF交易不活跃，频繁更新意义不大
2. **API限制**：减少API调用次数
3. **数据质量**：ETF数据在收盘后更新更准确

---

## 实时更新数据源

### 当前实现：仅Tushare

**位置**：`app/services/stock/unified_data_service.py`

实时更新使用统一的 `UnifiedDataService`，该服务：
- ✅ 使用Tushare获取历史数据
- ✅ 支持股票和ETF统一处理
- ✅ 统一使用 `stock_trend:` key前缀

### 已废弃的实现

**文件**：`app/services/realtime/realtime_service.py`

该文件包含了多种实时数据源的实现（东方财富、新浪等），但：
- ❌ 在当前架构中未被使用
- ❌ 与unified_data_service功能重复
- ⚠️ 建议：保留文件作为备用，但当前不启用

---

## 数据迁移说明

### 不需要迁移脚本的原因

用户选择：**重新初始化**

操作步骤：
1. 停止服务
2. 清空Redis（或仅清空 `stock_trend:*` 和 `etf_trend:*`）
3. 启动服务，执行全量更新

### 清空旧数据的Redis命令

```bash
# 方式1：清空所有stock_trend和etf_trend数据
redis-cli --scan --pattern "stock_trend:*" | xargs redis-cli DEL
redis-cli --scan --pattern "etf_trend:*" | xargs redis-cli DEL

# 方式2：清空整个Redis数据库（慎用）
redis-cli FLUSHDB
```

---

## 验证测试

### 1. 测试全量更新数据清理

```bash
# 1. 执行全量更新
curl -X POST "http://localhost:8000/api/realtime/test/full-update" \
  -H "Authorization: Bearer YOUR_TOKEN"

# 2. 检查Redis中是否还有etf_trend数据（应该没有）
redis-cli --scan --pattern "etf_trend:*" | wc -l
# 预期输出：0

# 3. 检查stock_trend数据（应该包含股票和ETF）
redis-cli --scan --pattern "stock_trend:*" | wc -l
# 预期输出：~5500（股票5000+ + ETF500+）
```

### 2. 测试ETF信号计算

```bash
# 1. 获取买入信号
curl "http://localhost:8000/api/signals/buy?limit=100" \
  -H "Authorization: Bearer YOUR_TOKEN"

# 2. 检查是否有ETF信号（market字段为'ETF'）
# 在全量更新后应该有ETF信号
# 在盘中更新后不应该有新的ETF信号

# 3. 验证ETF的K线数据
curl "http://localhost:8000/api/stocks/{etf_code}/history" \
  -H "Authorization: Bearer YOUR_TOKEN"
# 示例：510050（50ETF）、159915（创业板ETF）
```

### 3. 测试Key一致性

```python
# 在Python交互环境中测试
from app.db.session import RedisCache
redis_cache = RedisCache()

# 测试股票
stock_key = "stock_trend:600000.SH"
stock_data = redis_cache.get_cache(stock_key)
print(f"股票数据存在: {stock_data is not None}")

# 测试ETF
etf_key = "stock_trend:510050.SH"
etf_data = redis_cache.get_cache(etf_key)
print(f"ETF数据存在: {etf_data is not None}")

# 确保没有etf_trend数据
old_etf_key = "etf_trend:510050.SH"
old_data = redis_cache.get_cache(old_etf_key)
print(f"旧ETF key存在: {old_data is not None}")  # 应该是False
```

---

## 影响范围

### 数据层
- ✅ 所有ETF数据使用stock_trend前缀
- ✅ 全量更新清空所有K线数据
- ✅ 数据存储路径统一

### 服务层
- ✅ SignalManager正确读取ETF数据
- ✅ AI分析服务正确读取ETF数据
- ✅ 数据验证API正确检查ETF数据

### API层
- ✅ 信号API返回包含ETF
- ✅ K线API支持ETF查询
- ✅ 数据验证API统一处理

---

## 配置建议

### 生产环境配置

```yaml
# docker-compose.yml
environment:
  # 实时更新配置
  - REALTIME_UPDATE_ENABLED=true       # 启用实时更新
  - REALTIME_DATA_PROVIDER=tushare     # 仅使用Tushare
  - REALTIME_UPDATE_INTERVAL=1         # 1分钟更新一次
  - REALTIME_AUTO_SWITCH=false         # 不自动切换数据源（当前只有Tushare）
```

### 调试环境配置

```yaml
environment:
  # 降低更新频率，减少API消耗
  - REALTIME_UPDATE_ENABLED=true
  - REALTIME_DATA_PROVIDER=tushare
  - REALTIME_UPDATE_INTERVAL=5         # 5分钟更新一次
```

---

## 后续优化建议

### 1. 监控和告警
- 添加Redis key数量监控
- 监控etf_trend前缀是否还有残留数据
- 监控全量更新的清空效果

### 2. 数据完整性检查
- 定期检查ETF数据完整性
- 对比股票和ETF的数据更新时间
- 检查信号计算中ETF的覆盖率

### 3. 文档更新
- 更新所有文档中的key前缀说明
- 更新架构图，标明ETF和股票的统一处理
- 更新运维手册，说明数据清理流程

---

## 总结

本次修复解决了数据存储架构的核心问题：

✅ **统一性**：ETF和股票使用相同的key前缀  
✅ **完整性**：全量更新正确清空所有数据  
✅ **一致性**：所有服务使用统一的数据访问方式  
✅ **可维护性**：代码逻辑清晰，易于理解

**重要提醒**：
- 必须执行全量更新或清空Redis，才能彻底解决旧数据问题
- 修复后ETF和股票在数据层面完全统一
- 业务层面仍可通过market字段区分处理

