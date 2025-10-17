# K线图表主题切换完整实现指南

## 概述

实现K线图表根据App主题自动切换亮色/暗色背景，提供更友好的用户体验。

## 已完成的修改

### 1. 前端修改（✅ 已完成）

#### 文件：`lib/config/api_config.dart`
添加主题参数到URL构建方法：

```dart
// 获取带策略和主题的图表URL
static String getStockChartWithStrategyUrl(String stockCode, String strategy, {bool isDarkMode = false}) {
  final theme = isDarkMode ? 'dark' : 'light';
  return '$stockChartEndpoint$stockCode?strategy=$strategy&theme=$theme';
}
```

#### 文件：`lib/screens/stock_detail_screen.dart`
在两处调用图表URL时传递主题参数：

```dart
// 1. 横屏K线图视图（第307-309行）
final isDarkMode = Theme.of(context).brightness == Brightness.dark;
final String chartUrl = ApiConfig.getStockChartWithStrategyUrl(_currentStockCode, strategyToUse, isDarkMode: isDarkMode);

// 2. 竖屏K线图视图（第540-542行）
final isDarkMode = Theme.of(context).brightness == Brightness.dark;
final String chartUrl = ApiConfig.getStockChartWithStrategyUrl(_currentStockCode ?? widget.stockCode, strategyToUse, isDarkMode: isDarkMode);
```

#### 文件：`lib/screens/stock_chart_screen.dart`
在initState中传递主题参数：

```dart
// 获取当前主题（第45-49行）
final isDarkMode = Theme.of(context).brightness == Brightness.dark;
_chartUrl = ApiConfig.getStockChartWithStrategyUrl(widget.stockCode, strategyParam, isDarkMode: isDarkMode);
```

### 2. 后端API修改（✅ 已完成）

#### 文件：`app/api/chart.py`

**修改1：接收主题参数**
```python
# generate_stock_chart函数（第26-49行）
@router.get("/api/stocks/{stock_code}/chart")
async def generate_stock_chart(
    stock_code: str,
    strategy: str = Query("volume_wave", ...),
    theme: str = Query("dark", description="图表主题: light(亮色) 或 dark(暗色)")
):
    # 检查主题类型
    if theme not in ["light", "dark"]:
        theme = "dark"  # 默认暗色主题
```

**修改2：传递主题到数据字典**
```python
# 准备图表数据（第270-280行）
stock_data = {
    'stock': {...},
    'data': processed_df,
    'signals': signals,
    'strategy': strategy,
    'theme': theme  # ✅ 添加主题参数
}
```

**修改3：在生成HTML时使用主题**
```python
# generate_chart_from_redis_data函数（第367-374行）
theme = stock_data.get('theme', 'dark')
chart_file = f"{stock['code']}_{strategy}_{theme}_{datetime.now()...}.html"
html_content = generate_chart_html(strategy, stock_data, theme=theme)
```

**修改4：view_stock_chart函数**
```python
# 第304-345行
async def view_stock_chart(
    stock_code: str,
    strategy: str = Query(...),
    theme: str = Query("dark", ...)
):
    if theme not in ["light", "dark"]:
        theme = "dark"
    
    chart_result = await generate_stock_chart(stock_code, strategy, theme)
```

## 待完成的后端修改（需要继续实现）

### 3. 图表生成器修改

#### 文件：`app/charts/base_chart_strategy.py`

需要定义主题配色方案：

```python
class BaseChartStrategy:
    """图表策略基类"""
    
    # 定义主题配色
    THEME_COLORS = {
        'light': {
            'background': '#FFFFFF',           # 白色背景
            'grid': '#E5E7EB',                 # 浅灰色网格
            'text': '#1F2937',                 # 深灰色文字
            'border': '#D1D5DB',               # 浅灰色边框
            'upColor': '#EF4444',              # A股红色（涨）
            'downColor': '#10B981',            # A股绿色（跌）
            'volumeUpColor': '#FCA5A5',        # 浅红色（成交量-涨）
            'volumeDownColor': '#6EE7B7',      # 浅绿色（成交量-跌）
            'ma5': '#F59E0B',                  # 橙色（MA5）
            'ma10': '#8B5CF6',                 # 紫色（MA10）
            'ema12': '#06B6D4',                # 青色（EMA12）
            'ema18': '#F97316',                # 橙红色（EMA18）
            'ema144': '#10B981',               # 绿色（隧道下轨）
            'ema169': '#EF4444',               # 红色（隧道上轨）
            'buySignal': '#EF4444',            # 买入信号（红色）
            'sellSignal': '#10B981',           # 卖出信号（绿色）
        },
        'dark': {
            'background': '#151924',           # 深色背景（现有）
            'grid': '#2D3748',                 # 深灰色网格
            'text': '#E2E8F0',                 # 浅色文字
            'border': '#4A5568',               # 深灰色边框
            'upColor': '#F56565',              # A股红色（涨）
            'downColor': '#48BB78',            # A股绿色（跌）
            'volumeUpColor': '#FC8181',        # 浅红色（成交量-涨）
            'volumeDownColor': '#68D391',      # 浅绿色（成交量-跌）
            'ma5': '#F6AD55',                  # 橙色（MA5）
            'ma10': '#9F7AEA',                 # 紫色（MA10）
            'ema12': '#4FD1C5',                # 青色（EMA12）
            'ema18': '#FC8181',                # 橙红色（EMA18）
            'ema144': '#48BB78',               # 绿色（隧道下轨）
            'ema169': '#F56565',               # 红色（隧道上轨）
            'buySignal': '#F56565',            # 买入信号（红色）
            'sellSignal': '#48BB78',           # 卖出信号（绿色）
        }
    }
    
    @classmethod
    def get_theme_colors(cls, theme: str = 'dark') -> Dict[str, str]:
        """获取主题配色方案"""
        return cls.THEME_COLORS.get(theme, cls.THEME_COLORS['dark'])
    
    @classmethod
    def generate_chart_html(cls, stock_data: Dict[str, Any], **kwargs) -> str:
        """生成图表HTML - 子类需实现"""
        pass
```

#### 文件：`app/charts/volume_wave_chart_strategy.py`

需要修改HTML模板使用主题配色：

```python
@classmethod
def generate_chart_html(cls, stock_data: Dict[str, Any], **kwargs) -> str:
    # 获取主题
    theme = kwargs.get('theme', 'dark')
    colors = cls.get_theme_colors(theme)
    
    # 在HTML模板中使用colors字典
    html_template = f'''
    <!DOCTYPE html>
    <html>
    <head>
        <style>
            body {{
                margin: 0;
                padding: 0;
                background-color: {colors['background']};  /* 使用主题背景色 */
                color: {colors['text']};                    /* 使用主题文字色 */
            }}
            .chart-container {{
                background-color: {colors['background']};
            }}
        </style>
    </head>
    <body>
        <div id="chart"></div>
        <script>
            var option = {{
                backgroundColor: '{colors['background']}',
                grid: {{
                    borderColor: '{colors['border']}',
                }},
                xAxis: {{
                    axisLine: {{ lineStyle: {{ color: '{colors['grid']}' }} }},
                    axisLabel: {{ color: '{colors['text']}' }}
                }},
                yAxis: {{
                    axisLine: {{ lineStyle: {{ color: '{colors['grid']}' }} }},
                    axisLabel: {{ color: '{colors['text']}' }},
                    splitLine: {{ lineStyle: {{ color: '{colors['grid']}' }} }}
                }},
                series: [
                    {{
                        // K线系列
                        itemStyle: {{
                            color: '{colors['upColor']}',      // 涨-红色
                            color0: '{colors['downColor']}',   // 跌-绿色
                            borderColor: '{colors['upColor']}',
                            borderColor0: '{colors['downColor']}'
                        }}
                    }},
                    {{
                        // 成交量系列
                        itemStyle: {{
                            color: function(params) {{
                                return params.data[1] > params.data[2] 
                                    ? '{colors['volumeUpColor']}' 
                                    : '{colors['volumeDownColor']}';
                            }}
                        }}
                    }},
                    {{
                        // EMA12线
                        lineStyle: {{ color: '{colors['ema12']}' }}
                    }},
                    {{
                        // EMA18线
                        lineStyle: {{ color: '{colors['ema18']}' }}
                    }},
                    // ... 其他指标线
                ]
            }};
        </script>
    </body>
    </html>
    '''
    return html_template
```

#### 文件：`app/charts/trend_continuation_chart_strategy.py`

同样需要修改以支持主题：

```python
@classmethod
def generate_chart_html(cls, stock_data: Dict[str, Any], **kwargs) -> str:
    theme = kwargs.get('theme', 'dark')
    colors = cls.get_theme_colors(theme)
    
    # 在HTML模板中应用colors配色
    # （类似volume_wave_chart_strategy.py的修改）
```

## 实现步骤

### 第1步：修改基类（base_chart_strategy.py）

1. 添加`THEME_COLORS`类属性
2. 添加`get_theme_colors()`方法
3. 更新`generate_chart_html()`文档说明theme参数

### 第2步：修改具体策略类

1. **volume_wave_chart_strategy.py**:
   - 在`generate_chart_html`开头获取theme和colors
   - 替换所有硬编码的颜色值为`colors['xxx']`
   - 特别注意：
     * 背景色：`background-color: {colors['background']}`
     * 网格线：`splitLine: {{ lineStyle: {{ color: '{colors['grid']}' }}`
     * 文字：`axisLabel: {{ color: '{colors['text']}' }}`
     * K线颜色：`color: '{colors['upColor']}'`, `color0: '{colors['downColor']}'`

2. **trend_continuation_chart_strategy.py**:
   - 同样的修改方式

### 第3步：测试

1. 启动后端服务
2. 在App中切换到亮色主题
3. 打开股票详情查看K线图，应该是白色背景
4. 切换到暗色主题
5. 刷新或重新打开K线图，应该是深色背景

## 配色方案说明

### 亮色主题（light）
- 背景：白色 (#FFFFFF)
- 适合白天使用
- 高对比度，清晰易读
- 符合传统股票软件的亮色模式

### 暗色主题（dark）
- 背景：深蓝灰 (#151924)
- 适合夜间使用
- 减少眼睛疲劳
- 符合现代App的暗色设计

### A股配色规则
- ✅ 红色表示涨
- ✅ 绿色表示跌
- 两种主题都遵循这个规则

## 文件修改清单

### 前端（✅ 已完成）
- [x] `lib/config/api_config.dart`
- [x] `lib/screens/stock_detail_screen.dart`
- [x] `lib/screens/stock_chart_screen.dart`

### 后端API层（✅ 已完成）
- [x] `app/api/chart.py`

### 后端图表生成层（⚠️ 待实现）
- [ ] `app/charts/base_chart_strategy.py` - 添加主题配色定义
- [ ] `app/charts/volume_wave_chart_strategy.py` - 应用主题到HTML模板
- [ ] `app/charts/trend_continuation_chart_strategy.py` - 应用主题到HTML模板

## 快速实现脚本

为了快速完成剩余修改，可以：

1. 在`base_chart_strategy.py`文件开头（class定义后）添加`THEME_COLORS`字典
2. 在两个具体策略类中：
   ```python
   # 在generate_chart_html方法开头添加
   theme = kwargs.get('theme', 'dark')
   colors = cls.get_theme_colors(theme)
   
   # 然后在HTML模板中全局替换颜色
   # 例如：将 '#151924' 替换为 {colors['background']}
   ```

## 验证方法

```bash
# 测试亮色主题
curl "http://101.200.47.169:8000/api/chart/603119?strategy=volume_wave&theme=light"

# 测试暗色主题
curl "http://101.200.47.169:8000/api/chart/603119?strategy=volume_wave&theme=dark"
```

## 注意事项

1. **缓存问题**：WebView可能缓存旧版本的HTML，切换主题后需要强制刷新
2. **性能**：每次主题切换都会重新生成HTML文件
3. **兼容性**：默认使用暗色主题，确保向后兼容
4. **测试覆盖**：需要测试两种策略×两种主题=4种组合

## 后续优化建议

1. **缓存优化**：同一股票的不同主题图表可以复用数据
2. **动态切换**：通过JavaScript动态切换主题，无需重新加载
3. **更多主题**：可以扩展支持更多配色方案（如护眼模式、高对比度模式）
4. **用户自定义**：允许用户自定义图表配色

## 总结

前端和后端API层的修改已全部完成✅，主题参数已经能够正确传递。

剩余工作是在图表生成器层（chart strategies）应用主题配色，这是纯展示层的修改，不影响数据处理逻辑，实现起来比较直接。

完成后，用户切换App主题时，K线图表会自动使用对应的亮色或暗色背景，大大提升用户体验！

