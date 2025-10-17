# K线图主题切换实现说明

## 功能概述
实现了K线图根据App主题自动切换配色的功能：
- **亮色主题**：白色背景，浅色系配色，适合白天使用
- **暗色主题**：深色背景，深色系配色（原有样式），适合夜间使用

## 修改文件

### 前端 (Flutter)

#### 1. `stock_app_client/lib/config/api_config.dart`
- 修改 `getStockChartWithStrategyUrl` 方法，添加 `isDarkMode` 参数
- 根据主题在URL中添加 `theme=light` 或 `theme=dark` 查询参数

```dart
static String getStockChartWithStrategyUrl(String stockCode, String strategy, {bool isDarkMode = false}) {
  final theme = isDarkMode ? 'dark' : 'light';
  return '$stockChartEndpoint$stockCode?strategy=$strategy&theme=$theme';
}
```

#### 2. `stock_app_client/lib/screens/stock_detail_screen.dart`
- 在 `_buildLandscapeKLineView` 和 `build` 方法中获取当前主题
- 调用 `ApiConfig.getStockChartWithStrategyUrl` 时传递 `isDarkMode` 参数

#### 3. `stock_app_client/lib/screens/stock_chart_screen.dart`
- 在 `initState` 中获取当前主题
- 调用 `ApiConfig.getStockChartWithStrategyUrl` 时传递 `isDarkMode` 参数

### 后端 (Python)

#### 1. `stock_app_service/app/api/chart.py`
- `view_stock_chart` 和 `generate_stock_chart` 函数添加 `theme` 查询参数
- 验证 `theme` 参数（只接受 'light' 或 'dark'，默认 'dark'）
- 将 `theme` 参数传递给图表生成函数

#### 2. `stock_app_service/app/charts/__init__.py`
- `generate_chart_html` 函数添加 `**kwargs` 支持
- 将 `theme` 参数传递给具体的图表策略

#### 3. `stock_app_service/app/charts/base_chart_strategy.py`
**新增主题配色方案：**
```python
THEME_COLORS = {
    'light': {
        'background': '#FFFFFF',           # 白色背景
        'grid': '#E5E7EB',                 # 浅灰色网格
        'text': '#1F2937',                 # 深灰色文字
        'upColor': '#EF4444',              # A股红色（涨）
        'downColor': '#10B981',            # A股绿色（跌）
        # ... 更多颜色配置
    },
    'dark': {
        'background': '#151924',           # 深色背景
        'grid': '#2D3748',                 # 深灰色网格
        'text': '#E2E8F0',                 # 浅色文字
        'upColor': '#F56565',              # A股红色（涨）
        'downColor': '#48BB78',            # A股绿色（跌）
        # ... 更多颜色配置
    }
}
```

**修改的方法：**
- 新增 `get_theme_colors(theme)` 方法获取主题配色
- `_generate_base_html_template` 添加 `colors` 参数，应用主题配色到：
  - 页面背景色
  - 图表背景色
  - 网格颜色
  - 文字颜色
  - K线颜色（红涨绿跌）
  - 成交量颜色
  - 十字线和边框颜色
- `_prepare_markers` 添加 `colors` 参数，应用主题配色到买卖标记

#### 4. `stock_app_service/app/charts/volume_wave_chart_strategy.py`
- `generate_chart_html` 获取 `theme` 参数和主题配色
- 传递 `colors` 给 `_prepare_markers`
- 传递 `colors` 给 `_generate_enhanced_ema_series_code`
- 传递 `colors` 给 `_generate_base_html_template`
- `_generate_enhanced_ema_series_code` 应用主题配色到EMA均线和Vegas隧道

#### 5. `stock_app_service/app/charts/trend_continuation_chart_strategy.py`
- `generate_chart_html` 获取 `theme` 参数和主题配色
- 传递 `colors` 给 `_prepare_markers`
- 传递 `colors` 给 `_generate_base_html_template`

## 专业金融配色方案

### 设计理念
参考国际主流金融终端（TradingView、Bloomberg）的专业配色标准：
- **高对比度K线**：确保价格信息清晰可读
- **低对比度网格**：避免视觉干扰，突出价格数据
- **细线均线**：专业标准1px线宽，清晰不杂乱
- **A股配色习惯**：红涨绿跌，符合国内用户习惯

### 亮色主题 (Light)
- **背景**：纯白色 `#FFFFFF`
- **网格**：柔和灰色 `#E0E3EB`（低对比度）
- **文字**：深色 `#131722`（高对比度，易读）
- **K线涨**：标准A股红 `#F92626`（高饱和度）
- **K线跌**：标准A股绿 `#00B67A`（高饱和度）
- **成交量**：半透明红/绿，不抢占视觉焦点
- **EMA均线**：
  - EMA12/EMA18：`#2962FF`（蓝）/ `#FF6D00`（橙）- 1px细线
  - Vegas隧道：`#00897B`（青绿）/ `#D32F2F`（深红）- 1px细线

### 暗色主题 (Dark)
- **背景**：专业深色 `#131722`（TradingView标准）
- **网格**：深灰 `#2A2E39`（极低对比度，不干扰视线）
- **文字**：柔和灰白 `#D1D4DC`
- **K线涨**：标准A股红 `#F92626`（高饱和度）
- **K线跌**：标准A股绿 `#00B67A`（高饱和度）
- **成交量**：半透明红/绿，不抢占视觉焦点
- **EMA均线**：
  - EMA12/EMA18：`#2196F3`（亮蓝）/ `#FF9800`（亮橙）- 1px细线
  - Vegas隧道：`#00BCD4`（青色）/ `#E91E63`（粉红）- 1px细线

### 线条粗细标准
- **K线**：默认宽度（由图表库控制）
- **均线**：1px（专业金融终端标准）
- **隧道线**：1px（与均线保持一致）

## 使用方式

1. **前端自动适配**：
   - Flutter会根据系统或App设置的主题自动传递正确的theme参数
   - 无需用户手动切换

2. **后端接收处理**：
   - 后端接收 `theme` 查询参数
   - 生成对应主题的HTML图表
   - 缓存key包含主题信息，确保不同主题的图表分别缓存

## 测试建议

1. 在App中切换到亮色主题，查看K线图是否为白色背景
2. 切换到暗色主题，查看K线图是否为深色背景
3. 验证所有颜色在两种主题下都清晰可见
4. 测试不同策略（动量守恒、趋势延续）的图表主题切换

## 注意事项

1. **向后兼容**：如果请求中没有theme参数，默认使用暗色主题
2. **缓存策略**：不同主题的图表会分别缓存，避免混淆
3. **一致性**：所有图表策略都使用相同的主题配色方案
4. **A股特色**：保持红涨绿跌的A股配色习惯

---

实现日期：2025-10-17

