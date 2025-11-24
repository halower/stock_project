# Volume Wave 图表改进方案

## 改进目标

1. **隐藏 EMA 线说明** - 不显示技术指标图例（EMA6/EMA12/EMA18/EMA144/EMA169/趋势隧道），保持图表简洁
2. **添加 Volume Profile** - 整合 TradingView 的 Volume Profile / Fixed Range 指标

---

## 改进1: 隐藏 EMA 线说明

### 当前实现

- 文件: `app/charts/volume_wave_chart_strategy.py`
- 方法: `_generate_enhanced_legend_code()` (第276-311行)
- 当前图例显示:
  - EMA6 (短期均线)
  - EMA12 (中期均线)
  - EMA18 (长期均线)
  - EMA144 (隧道下轨)
  - EMA169 (隧道上轨)
  - 趋势隧道说明

### 修改方案

**方案A: 完全隐藏图例（推荐）**

直接返回空字符串，不生成任何图例：

```python
@classmethod
def _generate_enhanced_legend_code(cls) -> str:
    """生成增强的图例JavaScript代码 - 隐藏所有图例"""
    return ""  # 返回空字符串，不显示任何图例
```

**方案B: 保留简化图例（可选）**

只显示策略名称，不显示EMA明细：

```python
@classmethod
def _generate_enhanced_legend_code(cls) -> str:
    """生成简化的图例JavaScript代码"""
    return """
        // 添加简化的策略图例
        const legend = document.createElement('div');
        legend.style = 'position: absolute; left: 12px; top: 12px; z-index: 100; font-size: 12px; background: rgba(21, 25, 36, 0.90); padding: 8px 12px; border-radius: 4px; font-family: -apple-system, BlinkMacSystemFont, sans-serif;';
        legend.innerHTML = `
            <div style="font-weight: bold; color: #fff;">动量守恒策略</div>
        `;
        document.getElementById('chart-container').appendChild(legend);
    """
```

---

## 改进2: 添加 Volume Profile

### TradingView 指标分析

**原理**:
- Volume Profile 按价格区间统计成交量分布
- POC (Point of Control): 成交量最大的价格区间
- Value Area: 包含 70% 成交量的价格区间
- 上升/下降成交量分别着色

**参数**:
- `Number of Bars`: 分析的K线数量（默认150根）
- `Row Size`: 价格区间数量（默认24个）
- `Value Area Volume %`: Value Area 占比（默认70%）
- `POC Color`: POC线颜色
- `Value Area Up/Down Color`: Value Area 区域颜色
- `UP/Down Volume Color`: 上涨/下跌成交量颜色

### 实现挑战

**LightweightCharts 限制**:
- ❌ 不支持水平柱状图（TradingView的Volume Profile是水平的）
- ❌ 不支持复杂的填充区域（按价格区间填充）
- ✅ 支持线条、标记、简单区域填充

### 可行方案

#### 方案A: 简化的 Volume Profile（推荐）

**显示内容**:
1. **POC 线** - 成交量最大价格的水平线（红色）
2. **Value Area 上下界** - 两条水平虚线（蓝色）
3. **成交量分布提示** - 鼠标悬停显示价格区间的成交量

**实现步骤**:

1. **后端计算 Volume Profile**（Python）

```python
# app/indicators/volume_profile.py
import numpy as np
from typing import Dict, List, Tuple

def calculate_volume_profile(
    df, 
    num_bars: int = 150,
    row_size: int = 24,
    percent: float = 70.0
) -> Dict:
    """
    计算 Volume Profile
    
    Args:
        df: K线数据
        num_bars: 分析的K线数量
        row_size: 价格区间数量
        percent: Value Area 占比
        
    Returns:
        {
            'poc_price': POC价格,
            'value_area_high': Value Area 上界,
            'value_area_low': Value Area 下界,
            'profile': 各价格区间的成交量分布
        }
    """
    # 取最近 num_bars 根K线
    data = df.tail(num_bars).copy()
    
    if len(data) == 0:
        return None
    
    # 计算价格范围
    high_max = data['high'].max()
    low_min = data['low'].min()
    
    # 计算价格区间
    step = (high_max - low_min) / row_size
    levels = [low_min + step * i for i in range(row_size + 1)]
    
    # 初始化成交量数组
    volumes_up = np.zeros(row_size)
    volumes_down = np.zeros(row_size)
    
    # 分配成交量到各价格区间
    for idx, row in data.iterrows():
        high = row['high']
        low = row['low']
        open_price = row['open']
        close = row['close']
        volume = row['volume']
        
        is_green = close >= open_price
        
        # 计算K线在各价格区间的分布
        for i in range(row_size):
            level_low = levels[i]
            level_high = levels[i + 1]
            
            # 计算K线与价格区间的交集
            intersection_low = max(low, level_low)
            intersection_high = min(high, level_high)
            
            if intersection_high > intersection_low:
                # 按比例分配成交量
                ratio = (intersection_high - intersection_low) / (high - low) if high > low else 0
                vol = volume * ratio
                
                if is_green:
                    volumes_up[i] += vol
                else:
                    volumes_down[i] += vol
    
    # 计算总成交量
    total_volumes = volumes_up + volumes_down
    
    # 找到 POC（成交量最大的价格区间）
    poc_index = np.argmax(total_volumes)
    poc_price = (levels[poc_index] + levels[poc_index + 1]) / 2
    
    # 计算 Value Area
    target_volume = total_volumes.sum() * (percent / 100)
    va_volume = total_volumes[poc_index]
    up_idx = poc_index
    down_idx = poc_index
    
    while va_volume < target_volume and (up_idx < row_size - 1 or down_idx > 0):
        # 向上或向下扩展
        upper_vol = total_volumes[up_idx + 1] if up_idx < row_size - 1 else 0
        lower_vol = total_volumes[down_idx - 1] if down_idx > 0 else 0
        
        if upper_vol == 0 and lower_vol == 0:
            break
            
        if upper_vol >= lower_vol:
            up_idx += 1
            va_volume += upper_vol
        else:
            down_idx -= 1
            va_volume += lower_vol
    
    value_area_high = levels[up_idx + 1]
    value_area_low = levels[down_idx]
    
    # 构建成交量分布数据
    profile = []
    for i in range(row_size):
        profile.append({
            'price_low': levels[i],
            'price_high': levels[i + 1],
            'price_mid': (levels[i] + levels[i + 1]) / 2,
            'volume_up': float(volumes_up[i]),
            'volume_down': float(volumes_down[i]),
            'total_volume': float(total_volumes[i]),
            'in_value_area': down_idx <= i <= up_idx
        })
    
    return {
        'poc_price': float(poc_price),
        'value_area_high': float(value_area_high),
        'value_area_low': float(value_area_low),
        'profile': profile
    }
```

2. **前端显示 POC 和 Value Area**（JavaScript）

在 `volume_wave_chart_strategy.py` 的 `_generate_enhanced_ema_series_code()` 方法中添加：

```python
@classmethod
def _generate_volume_profile_overlay(cls, volume_profile: Dict, colors: dict) -> str:
    """生成 Volume Profile 覆盖层的 JavaScript 代码"""
    
    if not volume_profile:
        return ""
    
    poc_price = volume_profile['poc_price']
    va_high = volume_profile['value_area_high']
    va_low = volume_profile['value_area_low']
    
    return f"""
        // 添加 Volume Profile 覆盖层
        
        // POC 线 (Point of Control) - 成交量最大的价格
        const pocSeries = chart.addLineSeries({{
            color: '#FF5252',  // 红色
            lineWidth: 2,
            lineStyle: 0,  // 实线
            priceLineVisible: false,
            lastValueVisible: true,
            title: 'POC',
            priceFormat: {{
                type: 'price',
                precision: 2,
                minMove: 0.01,
            }},
        }});
        
        // 设置 POC 数据（水平线）
        const pocData = [];
        const firstTime = candlestickSeries.dataByIndex(0)?.time;
        const lastTime = candlestickSeries.dataByIndex(candlestickSeries.data().length - 1)?.time;
        
        if (firstTime && lastTime) {{
            pocData.push({{time: firstTime, value: {poc_price}}});
            pocData.push({{time: lastTime, value: {poc_price}}});
        }}
        
        pocSeries.setData(pocData);
        
        // Value Area 上界
        const vaHighSeries = chart.addLineSeries({{
            color: '#2196F3',  // 蓝色
            lineWidth: 1,
            lineStyle: 2,  // 虚线
            priceLineVisible: false,
            lastValueVisible: false,
            title: 'VA High'
        }});
        
        const vaHighData = [];
        if (firstTime && lastTime) {{
            vaHighData.push({{time: firstTime, value: {va_high}}});
            vaHighData.push({{time: lastTime, value: {va_high}}});
        }}
        
        vaHighSeries.setData(vaHighData);
        
        // Value Area 下界
        const vaLowSeries = chart.addLineSeries({{
            color: '#2196F3',  // 蓝色
            lineWidth: 1,
            lineStyle: 2,  // 虚线
            priceLineVisible: false,
            lastValueVisible: false,
            title: 'VA Low'
        }});
        
        const vaLowData = [];
        if (firstTime && lastTime) {{
            vaLowData.push({{time: firstTime, value: {va_low}}});
            vaLowData.push({{time: lastTime, value: {va_low}}});
        }}
        
        vaLowSeries.setData(vaLowData);
        
        // 添加 POC 标签
        const pocLabel = document.createElement('div');
        pocLabel.style = 'position: absolute; right: 12px; top: 50%; transform: translateY(-50%); z-index: 100; font-size: 11px; background: rgba(255, 82, 82, 0.9); color: #fff; padding: 4px 8px; border-radius: 3px; font-family: monospace; font-weight: bold;';
        pocLabel.innerHTML = `POC: {poc_price:.2f}`;
        document.getElementById('chart-container').appendChild(pocLabel);
    """
```

3. **修改 `generate_chart_html()` 方法**

```python
@classmethod
def generate_chart_html(cls, stock_data: Dict[str, Any], **kwargs) -> str:
    """生成量价波动图表HTML"""
    try:
        theme = kwargs.get('theme', 'dark')
        colors = cls.get_theme_colors(theme)
        
        stock = stock_data['stock']
        df = stock_data['data']
        signals = stock_data['signals']
        
        # 计算 Volume Profile
        from app.indicators.volume_profile import calculate_volume_profile
        volume_profile = calculate_volume_profile(df, num_bars=150, row_size=24)
        
        # ... 现有代码 ...
        
        # 生成 Volume Profile 覆盖层
        volume_profile_overlay = cls._generate_volume_profile_overlay(volume_profile, colors)
        
        # 合并到 additional_series
        additional_series = cls._generate_enhanced_ema_series_code(
            ema6_data, ema12_data, ema18_data, ema144_data, ema169_data, colors
        ) + volume_profile_overlay
        
        # 隐藏图例（改进1）
        additional_scripts = ""  # 不生成图例
        
        return cls._generate_base_html_template(
            stock=stock,
            strategy_name=cls.STRATEGY_NAME,
            strategy_desc=cls.STRATEGY_DESCRIPTION,
            chart_data=chart_data,
            markers=markers,
            volume_data=volume_data,
            additional_series=additional_series,
            additional_scripts=additional_scripts,
            colors=colors
        )
    except Exception as e:
        logger.error(f"生成量价波动图表时出错: {str(e)}")
        return ""
```

#### 方案B: 完整的 Volume Profile（复杂）

使用自定义的 Canvas 绘制水平柱状图，覆盖在 LightweightCharts 上方。

**优点**: 完全还原 TradingView 的 Volume Profile
**缺点**: 实现复杂，需要大量自定义代码

---

## 最终建议

### 短期方案（立即可用）

1. **隐藏 EMA 图例** - 使用方案A，直接返回空字符串
2. **添加简化的 Volume Profile** - 只显示 POC 线和 Value Area 边界

### 长期方案（未来优化）

1. **完整的 Volume Profile** - 使用自定义 Canvas 绘制水平柱状图
2. **可配置的图表选项** - 允许用户选择显示/隐藏哪些指标

---

## 实施步骤

1. **隐藏图例**（5分钟）
   - 修改 `_generate_enhanced_legend_code()` 返回空字符串

2. **创建 Volume Profile 计算模块**（30分钟）
   - 新建 `app/indicators/volume_profile.py`
   - 实现 `calculate_volume_profile()` 函数

3. **添加 Volume Profile 显示**（30分钟）
   - 在 `volume_wave_chart_strategy.py` 中添加 `_generate_volume_profile_overlay()`
   - 修改 `generate_chart_html()` 集成 Volume Profile

4. **测试和调试**（30分钟）
   - 测试不同股票的 Volume Profile 显示
   - 调整颜色和样式

**总耗时**: 约1.5小时

---

## 效果预览

### 改进前
- 左上角显示完整的 EMA 图例（占用空间）
- 只有 K线、成交量、EMA线

### 改进后
- 图表简洁，无图例干扰
- 增加 POC 红线（成交量最集中的价格）
- 增加 Value Area 蓝色虚线（70%成交量区间）
- 右侧显示 POC 价格标签

---

## 需要我立即实施吗？

我可以现在就开始修改代码，实现这两个改进。你确认吗？


