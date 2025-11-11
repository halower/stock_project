# BUG修复清单 - 2025-11-11

## ✅ 已完成的修复

### 1. 量能比值计算修复
- [x] 修改为使用20日平均成交量计算（而非前一根K线）
- [x] 文件：`app/services/signal/signal_manager.py` (324-377行)
- [x] 测试脚本：`scripts/test_volume_ratio_comparison.py`

### 2. 实时更新数据验证
- [x] 没有历史K线数据时跳过更新（不创建首条K线）
- [x] 文件：`app/services/stock/unified_data_service.py` (442-507行)

### 3. 信号计算数据要求
- [x] K线数据要求从20条提高到50条
- [x] 文件：`app/services/signal/signal_manager.py` (252-259行)

### 4. Redis Key统一
- [x] ETF和股票统一使用 `stock_trend:` 前缀
- [x] 修改了4处代码：
  - StockDataManager存储逻辑 (line 687-722)
  - AI分析服务读取逻辑 (line 322-327)
  - 数据验证API配置 (line 19-28)
  - ETF数据删除逻辑 (line 380-385, 1008-1015)

### 5. 全量更新清空逻辑
- [x] 修复清空函数，统一清理股票和ETF
- [x] 文件：`app/services/stock/stock_atomic_service.py` (346-367行)
- [x] 添加了分类统计日志

---

## 📋 需要执行的操作

### 步骤1：清空Redis旧数据

```bash
# 连接到Redis
redis-cli

# 清空旧的ETF数据（如果存在）
EVAL "local keys = redis.call('keys', 'etf_trend:*') for i=1,#keys do redis.call('del', keys[i]) end return #keys" 0

# 或者清空所有K线数据（推荐）
EVAL "local keys = redis.call('keys', 'stock_trend:*') for i=1,#keys do redis.call('del', keys[i]) end return #keys" 0
EVAL "local keys = redis.call('keys', 'etf_trend:*') for i=1,#keys do redis.call('del', keys[i]) end return #keys" 0
```

### 步骤2：重启服务并执行全量更新

```bash
# 重启服务
docker-compose restart stock_app_api

# 等待服务启动完成（约30秒）
sleep 30

# 执行全量更新（约8-12分钟）
curl -X POST "http://localhost:8000/api/realtime/test/full-update" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### 步骤3：验证修复效果

```bash
# 1. 检查量能比值是否正常（应在0.5-3.0范围内）
curl "http://localhost:8000/api/signals/buy?limit=50" \
  -H "Authorization: Bearer YOUR_TOKEN" | jq '.[] | {code, name, volume_ratio}'

# 2. 检查ETF数据（应该存在于stock_trend中）
redis-cli GET "stock_trend:510050.SH"

# 3. 检查旧key（应该不存在）
redis-cli GET "etf_trend:510050.SH"

# 4. 统计K线数据
redis-cli --scan --pattern "stock_trend:*" | wc -l  # 应该约5500条
redis-cli --scan --pattern "etf_trend:*" | wc -l    # 应该为0
```

---

## 📊 当前配置

### 实时更新
- **频率**：每1分钟
- **范围**：仅股票（不包含ETF）
- **数据源**：Tushare
- **配置文件**：`docker-compose.yml`

### 信号计算
- **频率**：固定时间点（约每20分钟）
- **时间点**：9:30/9:50/10:10/10:30/10:50/11:10/11:30/13:00/13:20/13:40/14:00/14:20/14:40/15:00/15:20
- **范围**：仅股票（不包含ETF）

### 全量更新
- **频率**：每日17:35
- **范围**：股票和ETF
- **操作**：清空所有K线数据后重新获取

---

## 🔍 验证检查点

### 数据层检查
- [ ] Redis中没有 `etf_trend:*` 数据
- [ ] 所有股票和ETF都在 `stock_trend:*` 中
- [ ] 全量更新后K线数据约5500条

### 信号检查
- [ ] 量能比值在合理范围内（0.5-3.0）
- [ ] 全量更新后ETF有信号
- [ ] 盘中更新后ETF信号不变（因为不更新ETF）

### 日志检查
- [ ] 全量更新日志显示清空了股票+ETF
- [ ] 实时更新跳过没有历史数据的股票
- [ ] 信号计算跳过K线不足50条的股票

---

## 📝 相关文档

1. `docs/BUG修复说明_量能计算和数据验证.md` - 量能计算修复详情
2. `docs/BUG修复总结_Redis_Key统一和数据清理.md` - Redis key统一详情
3. `scripts/test_volume_ratio_comparison.py` - 量能比值测试脚本

---

## ⚠️ 重要提醒

1. **必须清空Redis旧数据**：否则会有etf_trend和stock_trend并存的问题
2. **必须执行全量更新**：确保数据使用新的key格式
3. **监控日志输出**：确认清空和更新过程正常
4. **验证信号质量**：对比修复前后的信号质量

---

## 🎯 预期效果

1. **量能比值更准确**：不再出现超过100的异常值
2. **数据一致性**：ETF和股票使用统一的存储方式
3. **信号质量提升**：只有数据充足的股票才会产生信号
4. **系统稳定性**：全量更新正确清理所有旧数据

