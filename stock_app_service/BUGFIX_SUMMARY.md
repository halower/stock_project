# 紧急BUG修复总结

## 修复时间
2025-11-11

## 修复的问题

### 🔧 问题1：量能比值计算异常
**现象**: 实时更新时放量缩量比值经常超过100，与全量更新差异大

**原因**: 使用前一根K线成交量计算，而不是平均成交量

**修复**: 改为使用过去20日平均成交量计算

**文件**: `app/services/signal/signal_manager.py` (第324-377行)

---

### 🔧 问题2：实时更新创建孤立K线
**现象**: 实时更新时对没有历史数据的股票仍创建首条K线

**原因**: 缺少历史数据检查，直接创建新K线

**修复**: 实时更新跳过没有历史数据的股票，不创建首条K线

**文件**: `app/services/stock/unified_data_service.py` (第442-507行)

---

### 🔧 问题3：ETF无数据但出现信号
**现象**: ETF没有足够K线数据，但信号计算仍产生信号

**原因**: 数据验证要求太低（只需20根K线）

**修复**: 提高要求到至少50根K线才能计算信号

**文件**: `app/services/signal/signal_manager.py` (第252-259行)

---

## 测试验证

### 快速测试
```bash
# 1. 全量更新
curl -X POST "http://localhost:8000/api/realtime/test/full-update" \
  -H "Authorization: Bearer YOUR_TOKEN"

# 2. 实时更新
curl -X POST "http://localhost:8000/api/realtime/test/update" \
  -H "Authorization: Bearer YOUR_TOKEN"

# 3. 查看信号
curl "http://localhost:8000/api/signals/buy?limit=50" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### 验证要点
1. ✅ 量能比值应在 0.5-3.0 范围内
2. ✅ 实时更新不应创建新股票的首条K线
3. ✅ 只有K线数≥50的股票才有信号

---

## 详细文档
请查看: `docs/BUG修复说明_量能计算和数据验证.md`

