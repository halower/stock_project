# 策略指标自动注册系统使用指南

## 概述

自动注册系统让您能够通过简单的装饰器和约定式目录结构，快速添加新策略和指标，而无需手动修改注册代码。

**核心优势：**
- ✅ 添加新策略：从4个文件减少到1个文件
- ✅ 添加新指标：从2-3个文件减少到1个文件
- ✅ 零手动注册：使用装饰器自动注册
- ✅ 100%向后兼容：现有代码完全不受影响

---

## 快速开始

### 方式1：添加新策略（推荐）

**步骤：**
1. 在 `app/strategies/` 目录下创建新文件
2. 使用 `@register_strategy` 装饰器
3. 重启服务，自动识别

**示例：创建动量突破策略**

```python
# app/strategies/momentum_breakout.py
from app.strategies.base_strategy import BaseStrategy, register_strategy
import pandas as pd
from typing import Tuple, List, Dict

@register_strategy  # 自动注册！
class MomentumBreakoutStrategy(BaseStrategy):
    """动量突破策略"""
    
    STRATEGY_CODE = "momentum_breakout"
    STRATEGY_NAME = "动量突破"
    STRATEGY_DESCRIPTION = ""  # 建议留空，保护核心逻辑
    
    # 可选：声明图表需要的特殊系列
    CHART_SERIES = {
        'momentum': {
            'type': 'line',
            'color': '#FF6B6B',
            'data_column': 'momentum_line'
        }
    }
    
    @classmethod
    def calculate_signals(cls, df: pd.DataFrame, **kwargs) -> Tuple[pd.DataFrame, List[Dict]]:
        """
        计算动量突破信号
        
        Args:
            df: OHLCV数据
            **kwargs: 可选参数
            
        Returns:
            (处理后的DataFrame, 信号列表)
        """
        # 计算动量指标
        df['momentum_line'] = df['close'].pct_change(20) * 100
        
        # 生成买卖信号
        signals = []
        for i in range(20, len(df)):
            if df.iloc[i]['momentum_line'] > 5 and df.iloc[i-1]['momentum_line'] <= 5:
                signals.append({
                    'date': df.iloc[i]['date'],
                    'type': 'buy',
                    'index': i,
                    'price': df.iloc[i]['close'],
                    'reason': '动量突破买入',
                    'strategy': 'momentum_breakout'
                })
            elif df.iloc[i]['momentum_line'] < -5 and df.iloc[i-1]['momentum_line'] >= -5:
                signals.append({
                    'date': df.iloc[i]['date'],
                    'type': 'sell',
                    'index': i,
                    'price': df.iloc[i]['close'],
                    'reason': '动量跌破卖出',
                    'strategy': 'momentum_breakout'
                })
        
        return df, signals
```

**效果：**
- ✅ 重启服务后自动出现在策略列表
- ✅ 可以用于股票筛选
- ✅ 图表自动渲染（基于CHART_SERIES配置）
- ✅ 分析工具面板自动包含所有标准指标
- ✅ 无需修改任何其他文件

---

### 方式2：添加新指标（推荐）

**步骤：**
1. 在 `app/indicators/tradingview/` 目录下创建新文件
2. 使用 `@register_indicator` 装饰器
3. 重启服务，自动出现在分析工具面板

**示例：创建布林带指标**

```python
# app/indicators/tradingview/bollinger_bands.py
import pandas as pd
from app.indicators.indicator_registry import register_indicator

@register_indicator(
    id="bollinger_bands",
    name="布林带",
    category="trend",
    render_type="overlay",  # 覆盖在K线图上
    description="",
    enabled_by_default=False
)
def calculate_bollinger_bands(df: pd.DataFrame, period: int = 20, std_dev: float = 2.0):
    """
    计算布林带
    
    Args:
        df: OHLCV数据
        period: 周期
        std_dev: 标准差倍数
        
    Returns:
        包含upper, middle, lower三条线的数据
    """
    # 计算中轨（移动平均）
    middle = df['close'].rolling(period).mean()
    
    # 计算标准差
    std = df['close'].rolling(period).std()
    
    # 计算上下轨
    upper = middle + (std * std_dev)
    lower = middle - (std * std_dev)
    
    # 转换为前端格式
    result = {
        'lines': [
            {'name': 'upper', 'color': '#FF6B6B', 'data': []},
            {'name': 'middle', 'color': '#4DABF7', 'data': []},
            {'name': 'lower', 'color': '#51CF66', 'data': []}
        ]
    }
    
    for idx in range(len(df)):
        if pd.notna(upper.iloc[idx]):
            time_str = df.iloc[idx]['date']
            result['lines'][0]['data'].append({'time': time_str, 'value': float(upper.iloc[idx])})
            result['lines'][1]['data'].append({'time': time_str, 'value': float(middle.iloc[idx])})
            result['lines'][2]['data'].append({'time': time_str, 'value': float(lower.iloc[idx])})
    
    return result
```

**效果：**
- ✅ 重启服务后自动出现在"分析工具"面板
- ✅ 可以开关显示
- ✅ 自动保存用户偏好
- ✅ 无需修改任何其他文件

---

## 现有策略（已全部迁移）

所有策略已迁移到新的装饰器注册方式：

| 策略代码 | 策略名称 | 注册方式 | 位置 |
|---------|---------|---------|------|
| `volume_wave` | 量价突破 | ✅ @register_strategy | app/strategies/ |
| `volume_wave_enhanced` | 量价进阶 | ✅ @register_strategy | app/strategies/ |
| `volatility_conservation` | 趋势追踪 | ✅ @register_strategy | app/strategies/ |

---

## 现有指标（无需迁移）

以下11个指标继续使用手动注册方式，**完全不受影响**：

| 指标ID | 指标名称 | 分类 |
|-------|---------|-----|
| `ma_combo` | 移动均线组合 | 趋势分析 |
| `vegas_tunnel` | Vegas隧道 | 趋势分析 |
| `volume_profile_pivot` | 成交量分布 | 成交量分析 |
| `pivot_order_blocks` | 支撑和阻力区域 | 支撑阻力分析 |
| `divergence_detector` | 背离检测 | 振荡分析 |
| `mirror_candle` | 对手盘视角 | 逆向分析 |
| `ema6` | EMA6 | 趋势分析 |
| `ema12` | EMA12 | 趋势分析 |
| `ema18` | EMA18 | 趋势分析 |
| `ema144` | EMA144 | 趋势分析 |
| `ema169` | EMA169 | 趋势分析 |

---

## 图表配置（CHART_SERIES）

`CHART_SERIES` 允许您声明策略在图表上需要显示的特殊线条或覆盖层。

**支持的系列类型：**

| 类型 | 说明 | 示例 |
|-----|------|-----|
| `line` | 单条线 | 动量线、ATR线 |
| `area` | 区域填充 | 暂不支持 |
| `histogram` | 柱状图 | 暂不支持 |

**配置示例：**

```python
CHART_SERIES = {
    'my_line': {
        'type': 'line',              # 类型
        'color': '#FF6B6B',          # 颜色
        'data_column': 'my_indicator'  # 数据列名（必须在df中存在）
    },
    'another_line': {
        'type': 'line',
        'color': '#51CF66',
        'data_column': 'another_indicator'
    }
}
```

**注意：**
- `data_column` 指定的列必须在 `calculate_signals` 返回的 DataFrame 中存在
- 如果不需要特殊线条，可以省略 `CHART_SERIES`（默认为空字典）

---

## 装饰器参数说明

### @register_strategy

**说明：** 自动注册策略类，无需参数

**要求：**
- 类必须继承 `BaseStrategy`
- 类必须定义 `STRATEGY_CODE`、`STRATEGY_NAME`、`STRATEGY_DESCRIPTION`
- 类必须实现 `calculate_signals` 方法

---

### @register_indicator

**说明：** 自动注册指标计算函数

**参数：**

| 参数 | 类型 | 必填 | 说明 |
|-----|------|-----|------|
| `id` | str | ✅ | 唯一标识 |
| `name` | str | ✅ | 显示名称 |
| `category` | str | ✅ | 分类：trend/volume/support_resistance/oscillator/subchart |
| `render_type` | str | ❌ | 渲染类型：line/overlay/histogram/box/subchart（默认line） |
| `description` | str | ❌ | 描述（默认空） |
| `default_params` | dict | ❌ | 默认参数（默认空字典） |
| `color` | str | ❌ | 默认颜色（默认None） |
| `enabled_by_default` | bool | ❌ | 是否默认启用（默认False） |
| `is_composite` | bool | ❌ | 是否复合指标（默认False） |
| `sub_indicators` | list | ❌ | 子指标ID列表（默认空列表） |

---

## 常见问题

### Q1: 新策略需要重启服务吗？
**A:** 是的，目前需要重启服务。自动扫描只在服务启动时执行一次。

### Q2: 可以同时使用新旧注册方式吗？
**A:** 可以！手动注册的策略/指标优先级更高，自动注册不会覆盖它们。

### Q3: 现有策略需要迁移到新方式吗？
**A:** 不需要。现有3个策略完全正常工作，无需任何修改。

### Q4: 自动注册会影响性能吗？
**A:** 不会。自动扫描只在服务启动时执行一次，运行时性能零影响。

### Q5: 如何调试新策略？
**A:** 
1. 查看服务启动日志，确认策略已注册
2. 使用 `get_all_strategies()` API检查策略列表
3. 使用测试脚本验证策略逻辑

### Q6: 新策略的图表如何自定义？
**A:** 
- **简单需求**：使用 `CHART_SERIES` 配置
- **复杂需求**：创建专用图表策略类（参考现有策略）

### Q7: 指标数据格式有什么要求？
**A:** 
- **line类型**：返回 `[{'time': '2024-01-01', 'value': 10.5}, ...]`
- **overlay类型**：返回自定义格式，需要配合自定义渲染函数

---

## 架构说明

### 注册流程

```
1. 服务启动
   ↓
2. 导入 app.strategies
   ↓
3. 扫描 app/strategies/ 目录
   ↓
4. 导入所有 .py 文件（跳过 _*.py 和 base_strategy.py）
   ↓
5. @register_strategy 装饰器自动注册到 _AUTO_REGISTERED_STRATEGIES
   ↓
6. 合并到 REGISTERED_STRATEGIES
   ↓
7. 导入 app.charts
   ↓
8. 为没有专用图表类的策略自动生成通用图表策略
   ↓
9. 完成！策略可用
```

### 目录结构

```
app/
├── strategies/                        # 🎯 策略模块（筛选股票）
│   ├── __init__.py                    # 策略注册入口（自动扫描）
│   ├── base_strategy.py               # 基类（装饰器定义）
│   ├── volume_wave_strategy.py        # 量价突破策略
│   ├── volume_wave_enhanced_strategy.py  # 量价进阶策略
│   ├── volatility_conservation_strategy.py  # 趋势追踪策略
│   └── my_strategy.py                 # 新策略示例
│
├── indicators/                        # 📊 指标模块（图表分析）
│   ├── __init__.py                    # 向后兼容层（重新导出strategies API）
│   ├── indicator_registry.py          # 指标注册表（装饰器）
│   └── tradingview/
│       ├── volume_profile_pivot_anchored.py  # 现有指标
│       ├── divergence_detector.py     # 现有指标
│       └── my_indicator.py            # 新指标示例
│
├── charts/                            # 📈 图表渲染模块
│   ├── __init__.py                    # 图表注册入口（自动生成）
│   ├── base_chart_strategy.py         # 基类
│   ├── volume_wave_chart_strategy.py  # 图表策略1
│   ├── volume_wave_enhanced_chart_strategy.py  # 图表策略2
│   └── volatility_conservation_chart_strategy.py  # 图表策略3
└── ...
```

---

## 向后兼容性保证

✅ **所有现有功能100%正常工作：**
- 现有3个策略完全不受影响
- 现有11个指标完全不受影响
- API接口保持一致
- 信号生成保持一致
- 图表渲染保持一致

✅ **测试验证：**
- 7/7 测试全部通过
- 包含策略注册、计算、图表生成、API一致性等全方位测试
- 运行 `python tests/test_backward_compatibility.py` 验证

---

## 最佳实践

### 1. 策略开发

**DO ✅:**
- 使用 `@register_strategy` 装饰器
- 将策略文件放在 `app/strategies/` 目录
- 保持 `STRATEGY_DESCRIPTION` 为空，保护核心逻辑
- 在 docstring 中详细说明技术细节（给开发者看）
- 使用 `CHART_SERIES` 声明需要的图表元素

**DON'T ❌:**
- 不要在 `strategies/` 目录外使用装饰器（不会被扫描）
- 不要暴露策略描述给用户（保护核心逻辑）
- 不要忘记添加 `@register_strategy` 装饰器

### 2. 指标开发

**DO ✅:**
- 使用 `@register_indicator` 装饰器
- 指标文件可以放在任何地方（推荐 `tradingview/` 目录）
- 返回标准格式的数据
- 提供合理的默认参数

**DON'T ❌:**
- 不要在现有指标中添加装饰器（保持向后兼容）
- 不要返回不符合约定的数据格式

---

## 总结

| 指标 | 改进前 | 改进后 |
|------|-------|-------|
| 添加新策略文件数 | 4个 | 1个 ✨ |
| 添加新指标文件数 | 2-3个 | 1个 ✨ |
| 手动注册次数 | 2-4次 | 0次 ✨ |
| 现有功能影响 | - | 0% ✨ |
| 向后兼容性 | - | 100% ✨ |

**核心价值：**
- 🚀 大幅简化开发流程
- 🔒 100%向后兼容
- 🎯 新旧机制并存
- 📦 可选择性迁移

---

## 获取帮助

如有问题，请：
1. 查看本文档
2. 运行向后兼容性测试：`python tests/test_backward_compatibility.py`
3. 查看服务启动日志，确认策略/指标是否已注册
4. 参考示例代码：`app/indicators/strategies/` 目录

