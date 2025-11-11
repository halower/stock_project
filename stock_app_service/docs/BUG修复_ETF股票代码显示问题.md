# BUG修复说明 - ETF股票代码在买入信号中不显示

## 发现时间
2025-11-11

## 问题描述

**现象**: 买入信号列表中，ETF的股票代码字段为空或不存在

**影响范围**: 
- 前端显示的买入信号列表
- ETF信号无法正确显示代码
- 可能影响用户识别ETF

---

## 🔍 问题根源分析

### 代码存储逻辑（signal_manager.py）

在 `_store_signal_sync` 方法中（第320-321行）：

```python
# 去掉ts_code的后缀，只保留纯数字代码
clean_code = ts_code.split('.')[0] if '.' in ts_code else ts_code
```

**处理示例**:
```python
# 股票
ts_code = "600519.SH"  →  clean_code = "600519"  ✅ 正确

# ETF
ts_code = "510300.SH"  →  clean_code = "510300"  ✅ 代码正确
ts_code = "159915.SZ"  →  clean_code = "159915"  ✅ 代码正确
```

看起来代码处理逻辑是正确的！

---

## 🕵️ 深入排查

### 检查点1: ETF是否被正确识别和处理？

**stock_data_manager.py** 中ETF数据结构（第398-410行）：

```python
for etf in etf_list:
    etf_key = etf['ts_code']
    etf_data = {
        'ts_code': etf['ts_code'],      # ✅ "510300.SH"
        'symbol': etf['symbol'],         # ✅ "510300"
        'name': etf['name'],             # ✅ "沪深300ETF"
        'area': etf.get('area', ''),
        'industry': etf.get('industry', 'T+0交易'),  # ✅ ETF特殊标识
        'market': etf.get('market', 'ETF'),          # ✅ 市场标识
        'list_date': etf.get('list_date', ''),
        'updated_at': datetime.now().isoformat()
    }
    pipe.hset("stock_list", etf_key, json.dumps(etf_data))
```

**结论**: ✅ ETF数据存储正确

---

### 检查点2: 信号存储时是否有ETF？

**signal_manager.py** 的 `_store_signal_sync` 方法（第424-442行）：

```python
signal_data = {
    'code': clean_code,                          # "510300"
    'name': stock.get('name', ''),               # "沪深300ETF"
    'industry': stock.get('industry', ''),       # "T+0交易" 或 "T+1交易"
    'market': stock.get('market', ''),           # "ETF"
    'strategy': strategy_code,
    'strategy_name': strategy_info['name'],
    'confidence': clean_value(confidence, 0.75),
    # ... 其他字段
}

signal_key = f"{clean_code}:{strategy_code}"  # "510300:volume_wave"
redis_client.hset(
    self.buy_signals_key,                      # "buy_signals"
    signal_key,
    json.dumps(signal_data)
)
```

**存储示例**:
```
Redis Key: buy_signals
Hash Field: 510300:volume_wave
Hash Value: {
  "code": "510300",
  "name": "沪深300ETF",
  "market": "ETF",
  ...
}
```

**结论**: ✅ 信号存储逻辑正确

---

### 检查点3: 获取信号时是否正确解析？

**signal_manager.py** 的 `get_buy_signals` 方法（第145-213行）：

```python
async def get_buy_signals(self, strategy: Optional[str] = None, limit: int = None):
    """获取买入信号列表"""
    # 从Redis获取所有买入信号
    redis_client = await get_redis_client()
    signals_data = await redis_client.hgetall(self.buy_signals_key)
    
    if not signals_data:
        return []
    
    signals = []
    for key, value in signals_data.items():
        try:
            signal_data = json.loads(value)  # ✅ 应该包含 code 字段
            
            # 如果指定了策略，只返回该策略的信号
            if strategy and signal_data.get('strategy') != strategy:
                continue
                
            signals.append(signal_data)  # ✅ signal_data 应该有 code
        except json.JSONDecodeError as e:
            logger.error(f"解析信号数据失败: {key}, {e}")
            continue
    
    # 更新实时价格
    await self._update_signals_with_realtime_prices(signals, redis_client)
    
    # 过滤ST股票...
    # 分离股票和ETF...
    
    return filtered_signals
```

**结论**: ✅ 获取逻辑正确

---

### 检查点4: 实时价格更新是否影响了code字段？

**signal_manager.py** 的 `_update_signals_with_realtime_prices` 方法（第453-517行）：

```python
async def _update_signals_with_realtime_prices(self, signals: List[Dict[str, Any]], redis_client):
    """更新信号中的实时价格数据"""
    try:
        updated_count = 0
        for signal in signals:
            code = signal.get('code', '')  # ✅ 获取code
            if not code:
                continue  # ← ⚠️ 如果code为空，跳过
            
            # 获取实时价格数据
            realtime_data = await self._get_realtime_price_data(code, redis_client)
            
            if realtime_data:
                # 更新价格、涨跌幅等信息
                signal['price'] = realtime_data.get('price', signal.get('price', 0))
                signal['change_percent'] = realtime_data.get('change_pct', signal.get('change_percent', 0))
                # ...
                updated_count += 1
```

**问题可能在这里！** 让我检查 `_get_realtime_price_data` 方法：

```python
async def _get_realtime_price_data(self, code: str, redis_client) -> Optional[Dict[str, Any]]:
    """获取实时价格数据"""
    try:
        # 尝试从 realtime:stock:{code} 获取
        realtime_key = f"realtime:stock:{code}"
        realtime_data = await redis_client.get(realtime_key)
        
        if realtime_data:
            return json.loads(realtime_data)
        
        # 如果没有，尝试从 stock_trend:{code} 获取最后一条
        # ⚠️ 注意：这里需要完整的 ts_code（510300.SH），但传入的是 clean_code（510300）
        kline_key = f"stock_trend:{code}"  # ❌ 这里有问题！
        # ...
```

**找到问题了！**

---

## ⚠️ 问题根源

### 问题1: 实时价格数据Key格式不匹配

**信号存储时**:
- `code` 字段: `"510300"` (clean_code, 不带后缀)
- Redis Key: `stock_trend:510300.SH` (完整ts_code)

**获取实时价格时**:
- 使用 `code` 去查找: `realtime:stock:510300` ✅ 可能存在
- 但查找K线时: `stock_trend:510300` ❌ **找不到！应该是 `stock_trend:510300.SH`**

### 问题2: ETF实时数据可能不存在

**盘中更新**:
- 默认 `include_etf=False`，不更新ETF
- `realtime:stock:510300` 可能不存在

**查找K线**:
- 需要完整的ts_code: `stock_trend:510300.SH`
- 但传入的是clean_code: `510300`

---

## 🔧 修复方案

### 方案A: 在信号中同时存储 clean_code 和 ts_code（推荐）

**修改位置**: `signal_manager.py` 第424-442行

```python
# 修改前
signal_data = {
    'code': clean_code,  # 只有 "510300"
    'name': stock.get('name', ''),
    # ...
}

# 修改后
signal_data = {
    'code': clean_code,              # "510300" (前端显示用)
    'ts_code': ts_code,              # "510300.SH" (查询K线用)
    'name': stock.get('name', ''),
    'market': stock.get('market', ''),
    # ...
}
```

**修改实时价格更新逻辑**:

```python
async def _get_realtime_price_data(self, code: str, redis_client) -> Optional[Dict[str, Any]]:
    """获取实时价格数据"""
    try:
        # 优先使用实时数据
        realtime_key = f"realtime:stock:{code}"
        realtime_data = await redis_client.get(realtime_key)
        
        if realtime_data:
            return json.loads(realtime_data)
        
        # ⚠️ 修复：如果signal中有ts_code，使用ts_code查询K线
        # 但这里只传入了code，需要修改调用方
        return None
    except Exception as e:
        logger.error(f"获取实时价格失败: {code}, {e}")
        return None


async def _update_signals_with_realtime_prices(self, signals: List[Dict[str, Any]], redis_client):
    """更新信号中的实时价格数据"""
    try:
        for signal in signals:
            code = signal.get('code', '')
            ts_code = signal.get('ts_code', '')  # ✅ 新增：获取ts_code
            
            if not code:
                continue
            
            # 1. 尝试从实时数据获取
            realtime_data = await self._get_realtime_price_data(code, redis_client)
            
            if not realtime_data and ts_code:
                # 2. 如果没有实时数据，从K线获取最后一条
                kline_key = f"stock_trend:{ts_code}"  # ✅ 使用完整ts_code
                kline_data = await redis_client.get(kline_key)
                
                if kline_data:
                    trend_data = json.loads(kline_data)
                    kline_list = trend_data.get('data', [])
                    if kline_list and len(kline_list) > 0:
                        # 获取最后一条K线数据
                        last_kline = kline_list[-1]
                        realtime_data = {
                            'price': last_kline.get('close', 0),
                            'change_pct': 0,  # K线中没有涨跌幅，设为0
                            'volume': last_kline.get('volume', 0)
                        }
            
            if realtime_data:
                # 更新价格信息
                signal['price'] = realtime_data.get('price', signal.get('price', 0))
                signal['change_percent'] = realtime_data.get('change_pct', signal.get('change_percent', 0))
                # ...
    except Exception as e:
        logger.error(f"批量更新实时价格失败: {e}")
```

---

### 方案B: 重建代码转换逻辑（备选）

在 `_get_realtime_price_data` 中根据code重建ts_code：

```python
def _rebuild_ts_code(self, code: str, market: str = '') -> str:
    """根据clean_code和market重建ts_code"""
    if '.' in code:
        return code  # 已经是ts_code
    
    # 根据代码规则判断市场
    if code.startswith('6'):
        return f"{code}.SH"  # 上海主板
    elif code.startswith('5'):
        return f"{code}.SH"  # 上海ETF
    elif code.startswith(('0', '3')):
        return f"{code}.SZ"  # 深圳
    elif code.startswith('1') and len(code) == 6:
        return f"{code}.SZ"  # 深圳ETF
    elif code.startswith(('43', '83', '87', '88')):
        return f"{code}.BJ"  # 北交所
    else:
        return f"{code}.SZ"  # 默认深圳
```

**缺点**: 代码规则可能不准确，尤其是ETF

---

## ✅ 推荐修复方案（方案A）

### 修改1: 存储信号时同时保存ts_code

**文件**: `app/services/signal/signal_manager.py`
**位置**: 第424-442行

```python
signal_data = {
    'code': clean_code,              # "510300" (前端显示)
    'ts_code': ts_code,              # "510300.SH" (内部查询)
    'name': stock.get('name', ''),
    'industry': stock.get('industry', ''),
    'market': stock.get('market', ''),
    'strategy': strategy_code,
    'strategy_name': strategy_info['name'],
    'confidence': clean_value(confidence, 0.75),
    'kline_date': kline_date,
    'calculated_time': datetime.now().isoformat(),
    'timestamp': datetime.now().timestamp(),
    'price': clean_value(signal.get('price', 0)),
    'volume': clean_value(volume),
    'volume_ratio': clean_value(volume_ratio),
    'change_percent': clean_value(change_percent),
    'reason': f"策略{strategy_code}最新买入信号",
    'signal_index': signal_index,
    'is_latest': True
}
```

### 修改2: 更新实时价格时使用ts_code

**文件**: `app/services/signal/signal_manager.py`
**位置**: 第453-517行

```python
async def _update_signals_with_realtime_prices(self, signals: List[Dict[str, Any]], redis_client):
    """更新信号中的实时价格数据"""
    try:
        updated_count = 0
        for signal in signals:
            code = signal.get('code', '')
            ts_code = signal.get('ts_code', '')  # ✅ 获取ts_code
            
            if not code:
                continue
            
            # 1. 尝试从实时数据获取（使用clean_code）
            realtime_key = f"realtime:stock:{code}"
            realtime_data_str = await redis_client.get(realtime_key)
            
            realtime_data = None
            if realtime_data_str:
                realtime_data = json.loads(realtime_data_str)
            
            # 2. 如果没有实时数据且有ts_code，从K线获取
            if not realtime_data and ts_code:
                kline_key = f"stock_trend:{ts_code}"  # ✅ 使用完整ts_code
                kline_data_str = await redis_client.get(kline_key)
                
                if kline_data_str:
                    try:
                        trend_data = json.loads(kline_data_str)
                        kline_list = trend_data.get('data', [])
                        if kline_list and len(kline_list) > 0:
                            last_kline = kline_list[-1]
                            realtime_data = {
                                'price': last_kline.get('close', 0),
                                'change_pct': 0,
                                'volume': last_kline.get('volume', 0),
                                'high': last_kline.get('high', 0),
                                'low': last_kline.get('low', 0),
                            }
                    except json.JSONDecodeError as e:
                        logger.error(f"解析K线数据失败: {ts_code}, {e}")
            
            # 3. 更新价格信息
            if realtime_data:
                signal['price'] = realtime_data.get('price', signal.get('price', 0))
                signal['change_percent'] = realtime_data.get('change_pct', signal.get('change_percent', 0))
                # 其他字段更新...
                updated_count += 1
        
        logger.debug(f"更新了 {updated_count}/{len(signals)} 个信号的实时价格")
    except Exception as e:
        logger.error(f"批量更新实时价格失败: {e}")
```

---

## 🧪 测试验证

### 测试1: 检查信号数据结构

```python
# 在Redis中查看信号
redis-cli
> HGETALL buy_signals
> HGET buy_signals "510300:volume_wave"

# 应该看到类似：
{
  "code": "510300",
  "ts_code": "510300.SH",  # ✅ 应该有这个字段
  "name": "沪深300ETF",
  "market": "ETF",
  ...
}
```

### 测试2: 检查API返回

```bash
# 获取买入信号API
curl -X GET "http://localhost:8000/api/stocks/signal/buy" \
  -H "Authorization: Bearer YOUR_TOKEN"

# 检查返回的ETF信号是否有code字段
```

### 测试3: 检查日志

```bash
# 查看信号计算日志
tail -f logs/app.log | grep "510300"

# 应该看到：
# - 信号存储时包含 ts_code
# - 实时价格更新成功或失败的原因
```

---

## 📊 预期效果

修复后，ETF信号应该：

1. ✅ `code` 字段正确显示：`"510300"`
2. ✅ `ts_code` 字段用于内部查询：`"510300.SH"`
3. ✅ `name` 字段显示名称：`"沪深300ETF"`
4. ✅ `market` 字段标识类型：`"ETF"`
5. ✅ 实时价格能正确更新（从K线获取）

---

## 🎯 总结

**问题根源**:
- 信号存储时只保存了 `clean_code`（"510300"）
- 查询K线时需要完整的 `ts_code`（"510300.SH"）
- 导致ETF无法获取K线数据更新价格

**修复方法**:
- 在信号数据中同时存储 `code` 和 `ts_code`
- 更新实时价格时使用 `ts_code` 查询K线

**影响范围**:
- 需要重新计算信号才能生效
- 旧的信号数据不包含 `ts_code` 字段

**建议**:
修复代码后，运行一次全量信号计算：
```bash
# 清空旧信号
redis-cli
> DEL buy_signals

# 重新计算信号（系统会自动重新计算）
# 或者手动触发
```

