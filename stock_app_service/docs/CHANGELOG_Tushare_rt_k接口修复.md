# Tushare rt_k接口修复 - 使用通配符获取全市场实时数据

**日期**: 2025-11-12  
**版本**: v1.1  
**影响范围**: 实时数据更新

---

## 问题

### 错误日志
```
Exception: 必填参数, ts_code
```

### 原因
`rt_k()` 接口**必须传入 `ts_code` 参数**，不能像 `daily()` 那样不传参数。

---

## 解决方案

### 使用通配符一次性获取全市场

#### 股票
```python
df_stocks = pro.rt_k(ts_code='3*.SZ,6*.SH,0*.SZ,9*.BJ')
```

- `3*.SZ` - 创业板（300xxx, 301xxx）
- `6*.SH` - 沪市主板（600xxx, 601xxx, 603xxx, 688xxx）
- `0*.SZ` - 深市主板（000xxx, 001xxx, 002xxx）
- `9*.BJ` - 北交所（8xxxxx, 43xxxx）

#### ETF
```python
df_etf = pro.rt_etf_k(ts_code='5*.SH,5*.SZ,1*.SH,1*.SZ')
```

- `5*.SH` - 沪市ETF（51xxxx, 56xxxx）
- `5*.SZ` - 深市ETF（15xxxx, 16xxxx）
- `1*.SH` - 沪市ETF（10xxxx）
- `1*.SZ` - 深市ETF（12xxxx）

---

## 代码修改

### 文件: `realtime_service.py`

#### 股票实时数据（第164-222行）

**关键变化**:
1. ✅ 添加 `ts_code` 参数，使用通配符
2. ✅ `rt_k` 接口**直接返回 `pre_close`**，无需反推
3. ✅ 成交量单位是**股**（不是手）
4. ✅ 成交额单位是**元**（不是千元）

```python
# 使用通配符获取全市场
df_stocks = pro.rt_k(ts_code='3*.SZ,6*.SH,0*.SZ,9*.BJ')

# 字段处理
close_price = float(row.get('close', 0))
pre_close_price = float(row.get('pre_close', 0))  # 直接获取，无需计算
change = close_price - pre_close_price
pct_chg = (change / pre_close_price * 100) if pre_close_price > 0 else 0
```

#### ETF实时数据（第224-274行）

```python
# 使用通配符获取全市场ETF
df_etf = pro.rt_etf_k(ts_code='5*.SH,5*.SZ,1*.SH,1*.SZ')

# 字段处理与股票相同
```

---

## 字段说明

### rt_k / rt_etf_k 返回字段

| 字段 | 类型 | 说明 | 单位 |
|------|------|------|------|
| `ts_code` | str | 股票代码（含后缀） | - |
| `name` | str | 股票名称 | - |
| `pre_close` | float | **昨收价**（直接返回） | 元 |
| `open` | float | 开盘价 | 元 |
| `high` | float | 最高价 | 元 |
| `low` | float | 最低价 | 元 |
| `close` | float | 最新价 | 元 |
| `vol` | int | 成交量 | **股** |
| `amount` | int | 成交额 | **元** |
| `num` | int | 成交笔数 | 笔 |
| `trade_time` | str | 交易时间 | - |

**重要**：
- ⚠️ `vol` 单位是**股**（不是手，1手=100股）
- ⚠️ `amount` 单位是**元**（不是千元）
- ✅ `pre_close` 直接返回（不需要反推）

---

## 测试

### 交易时间（9:30-15:00）

**预期日志**:
```
✅ INFO - 使用通配符获取全市场实时数据...
✅ INFO - Tushare rt_k接口返回 5432 条实时数据
✅ INFO - 成功从Tushare获取 5432 只股票实时数据
✅ INFO - 实时更新完成: 成功更新 5432 只
```

### 非交易时间

**预期日志**:
```
✅ INFO - 使用通配符获取全市场实时数据...
✅ WARNING - Tushare rt_k接口返回空数据（可能非交易时间或权限不足）
✅ INFO - 获取到的实时数据为空（可能是非交易时间），跳过更新
```

---

## 部署

```bash
# 重启服务
docker-compose restart api

# 查看日志（等待下一次实时更新）
docker logs -f --tail 100 stock_app_api | grep "rt_k"
```

---

## 注意事项

1. **权限要求**: `rt_k` 和 `rt_etf_k` 需要单独申请权限
2. **单次限制**: 最大6000条，通配符可一次性获取全市场
3. **数据延迟**: 实时数据有1-3分钟延迟
4. **调用频率**: 建议间隔 ≥ 1分钟

---

## 总结

- ✅ 使用通配符 `ts_code='3*.SZ,6*.SH,0*.SZ,9*.BJ'` 获取全市场
- ✅ `rt_k` 直接返回 `pre_close`，无需反推
- ✅ 成交量单位是**股**，成交额单位是**元**
- ✅ 单次调用即可获取全市场实时数据

