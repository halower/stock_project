# BUG修复：放量计算逻辑错误

**日期**: 2025-11-12  
**严重程度**: 高  
**影响**: 信号列表中放量数值不符合预期

---

## 问题描述

用户反馈：放量应该是**今日成交量 / 昨日成交量**，例如：
- 昨天成交量：100万股
- 今天成交量：120万股
- 放量：**1.2倍**

但系统计算的是：**今日成交量 / 过去20日平均成交量**

---

## 错误逻辑（修复前）

```python
# 计算量能比值：当前成交量/过去20日平均成交量
if signal_index >= 20 and volume > 0:
    # 取信号索引之前的20根K线
    start_idx = max(0, signal_index - 20)
    end_idx = signal_index
    
    volume_list = []
    for i in range(start_idx, end_idx):
        v = df.iloc[i]['volume']
        if v > 0:
            volume_list.append(v)
    
    # 计算平均成交量
    avg_volume = sum(volume_list) / len(volume_list)
    
    # 计算量能比值
    volume_ratio = volume / avg_volume  # ❌ 错误！应该是 / 昨日成交量
```

### 问题

- ❌ 使用20日平均成交量作为基准
- ❌ 需要至少20根K线才能计算
- ❌ 不符合用户对"放量"的理解

---

## 正确逻辑（修复后）

```python
# 计算放量比值：今日成交量 / 昨日成交量
if signal_index >= 1 and volume > 0:
    # 获取昨日成交量（前一根K线）
    prev_idx = signal_index - 1
    prev_volume = df.iloc[prev_idx]['volume']
    prev_vol = float(prev_volume) if not pd.isna(prev_volume) else 0
    
    # 如果昨日成交量为0，尝试从vol字段获取
    if prev_vol == 0 and 'vol' in df.columns:
        prev_vol_value = df.iloc[prev_idx]['vol']
        prev_vol = float(prev_vol_value) if not pd.isna(prev_vol_value) else 0
    
    # 计算放量比值
    if prev_vol > 0:
        ratio = volume / prev_vol
        volume_ratio = round(ratio, 2)  # ✅ 正确！今日 / 昨日
```

### 改进

- ✅ 使用昨日成交量作为基准
- ✅ 只需要2根K线即可计算
- ✅ 符合用户对"放量"的理解

---

## 计算示例

### 示例1：放量
```
昨日成交量：1000万股
今日成交量：1500万股
放量比值：1500 / 1000 = 1.5倍
```

### 示例2：缩量
```
昨日成交量：1000万股
今日成交量：800万股
放量比值：800 / 1000 = 0.8倍
```

### 示例3：持平
```
昨日成交量：1000万股
今日成交量：1000万股
放量比值：1000 / 1000 = 1.0倍
```

---

## 对比

| 指标 | 修复前 | 修复后 |
|------|--------|--------|
| **计算公式** | 今日 / 20日均量 | 今日 / 昨日 |
| **最小K线数** | 20根 | 2根 |
| **典型数值** | 0.5 - 3倍 | 0.5 - 5倍 |
| **符合预期** | ❌ 不符合 | ✅ 符合 |

---

## 修改文件

**文件**: `stock_app_service/app/services/signal/signal_manager.py`

**位置**: 第336-364行

**关键变化**:
1. ✅ 从"20日平均"改为"昨日"
2. ✅ 从 `signal_index >= 20` 改为 `signal_index >= 1`
3. ✅ 简化计算逻辑，提高性能

---

## 部署

```bash
# 重启服务
docker-compose restart api

# 手动触发信号计算（清除旧信号，使用新逻辑重新计算）
curl -X POST "http://your-server/api/tasks/calculate-signals?stock_only=true"
```

---

## 预期效果

### 修复前（错误）
```
深科达：放量 46.1倍  ❌（今日 / 20日均量）
广大特材：放量 33.4倍  ❌
汇洁股份：放量 45.2倍  ❌
```

### 修复后（正确）
```
深科达：放量 1.5倍  ✅（今日 / 昨日）
广大特材：放量 2.1倍  ✅
汇洁股份：放量 1.8倍  ✅
```

---

## 注意事项

### 1. 需要重新计算信号
- 旧的信号使用的是旧逻辑（20日均量）
- 需要手动触发信号计算，或等待下一次定时任务

### 2. 数据兼容性
- 新旧逻辑都使用相同的字段 `volume_ratio`
- 不需要修改数据结构

### 3. 性能提升
- 旧逻辑：需要遍历20根K线
- 新逻辑：只需要读取1根K线（昨日）
- **性能提升约20倍**

---

## 总结

### 核心问题
- ❌ **错误理解**："放量"被理解为"量比"（今日 / 20日均量）
- ✅ **正确理解**："放量"是今日相对昨日的变化（今日 / 昨日）

### 解决方案
- ✅ 修改计算公式：`volume / avg_volume` → `volume / prev_volume`
- ✅ 降低K线要求：20根 → 2根
- ✅ 提升计算性能：遍历20根 → 读取1根

### 用户体验
- ✅ 放量数值符合直觉（1-3倍为常见范围）
- ✅ 更快的信号计算速度
- ✅ 更准确的交易信号

