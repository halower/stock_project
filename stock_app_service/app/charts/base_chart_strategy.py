# -*- coding: utf-8 -*-
"""图表策略抽象基类定义"""

from abc import ABC, abstractmethod
from typing import Dict, Any
import json
import pandas as pd
from app.core.logging import logger
from app.charts.indicator_pool_mixin import IndicatorPoolMixin

class BaseChartStrategy(ABC, IndicatorPoolMixin):
    """
    图表策略抽象基类
    
    所有图表策略都应继承此基类并实现其方法
    """
    
    # 定义主题配色方案 - 参考专业金融终端（TradingView/Bloomberg）标准
    THEME_COLORS = {
        'light': {
            # 基础背景色 - 纯白简洁
            'background': '#FFFFFF',
            'grid': '#E0E3EB',                 # 更柔和的网格线
            'text': '#131722',                 # 接近黑色的深灰文字
            'border': '#D1D4DC',
            
            # K线配色 - A股标准（红涨绿跌），高对比度
            'upColor': '#F92626',              # 标准A股红（涨）
            'downColor': '#00B67A',            # 标准A股绿（跌）
            'volumeUpColor': 'rgba(249, 38, 38, 0.5)',    # 半透明红色成交量
            'volumeDownColor': 'rgba(0, 182, 122, 0.5)',  # 半透明绿色成交量
            
            # 均线配色 - 专业配色（EMA12/EMA18更重要，使用更显眼的颜色）
            'ma5': '#FF6D00',                  # 橙色 MA5（短期）
            'ma10': '#9C27B0',                 # 紫色 MA10（中期）
            'ema6': '#00BCD4',                 # 青色 EMA6（最短期）
            'ema12': '#FFD700',                # 金黄色 EMA12（重要：短期趋势）⭐
            'ema18': '#2962FF',                # 蓝色 EMA18（重要：中期趋势）⭐
            'ema144': '#00897B',               # 青绿色（隧道下轨）
            'ema169': '#D32F2F',               # 深红色（隧道上轨）
            
            # 信号标记
            'buySignal': '#F92626',            # 买入信号（红色）
            'sellSignal': '#00B67A',           # 卖出信号（绿色）
            
            # UI元素
            'tooltipBg': 'rgba(255, 255, 255, 0.96)',
            'tooltipBorder': '#D1D4DC',
            'watermark': 'rgba(149, 152, 161, 0.06)',  # 非常淡的水印
        },
        'dark': {
            # 基础背景色 - 专业深色（参考TradingView暗色主题）
            'background': '#131722',           # 专业深色背景
            'grid': '#2A2E39',                 # 更深的网格线（低对比）
            'text': '#D1D4DC',                 # 柔和的灰白色文字
            'border': '#2A2E39',
            
            # K线配色 - A股标准（红涨绿跌），专业对比度
            'upColor': '#F92626',              # 标准A股红（涨）
            'downColor': '#00B67A',            # 标准A股绿（跌）
            'volumeUpColor': 'rgba(249, 38, 38, 0.5)',    # 半透明红色成交量
            'volumeDownColor': 'rgba(0, 182, 122, 0.5)',  # 半透明绿色成交量
            
            # 均线配色 - 专业暗色配色（EMA12/EMA18更重要，使用更显眼的颜色）
            'ma5': '#FF9800',                  # 亮橙色 MA5（短期）
            'ma10': '#9C27B0',                 # 紫色 MA10（中期）
            'ema6': '#26A69A',                 # 青绿色 EMA6（最短期）
            'ema12': '#FFD700',                # 金黄色 EMA12（重要：短期趋势）⭐
            'ema18': '#2196F3',                # 亮蓝色 EMA18（重要：中期趋势）⭐
            'ema144': '#00BCD4',               # 青色（隧道下轨）
            'ema169': '#E91E63',               # 粉红色（隧道上轨）
            
            # 信号标记
            'buySignal': '#F92626',            # 买入信号（红色）
            'sellSignal': '#00B67A',           # 卖出信号（绿色）
            
            # UI元素
            'tooltipBg': 'rgba(19, 23, 34, 0.96)',
            'tooltipBorder': '#2A2E39',
            'watermark': 'rgba(120, 123, 134, 0.06)',  # 非常淡的水印
        }
    }
    
    @classmethod
    def get_theme_colors(cls, theme: str = 'dark') -> Dict[str, str]:
        """
        获取主题配色方案
        
        Args:
            theme: 主题类型，'light'（亮色）或'dark'（暗色），默认暗色
            
        Returns:
            主题配色字典
        """
        return cls.THEME_COLORS.get(theme, cls.THEME_COLORS['dark'])
    
    @classmethod
    @abstractmethod
    def generate_chart_html(cls, stock_data: Dict[str, Any], **kwargs) -> str:
        """
        生成图表HTML内容
        
        Args:
            stock_data: 股票数据字典，包含以下键：
                - stock: 股票基本信息对象
                - data: 包含OHLCV和指标数据的DataFrame
                - signals: 买卖信号列表
                - strategy: 策略代码
            **kwargs: 策略特定的参数
            
        Returns:
            完整的HTML字符串
        """
        pass
    
    @classmethod
    def get_strategy_code(cls) -> str:
        """
        获取策略代码
        
        Returns:
            策略唯一标识代码
        """
        return cls.STRATEGY_CODE
    
    @classmethod
    def get_strategy_name(cls) -> str:
        """
        获取策略中文名称
        
        Returns:
            策略的中文名称
        """
        return cls.STRATEGY_NAME
    
    @classmethod
    def get_strategy_description(cls) -> str:
        """
        获取策略描述
        
        Returns:
            策略的详细描述
        """
        return cls.STRATEGY_DESCRIPTION
    
    @classmethod
    def _prepare_chart_data(cls, df) -> list:
        """
        准备基础K线数据
        
        Args:
            df: 包含OHLCV数据的DataFrame
            
        Returns:
            格式化的图表数据列表
        """
        chart_data = []
        for _, row in df.iterrows():
            try:
                # 处理日期字段，确保格式正确
                date_value = row['date']
                
                # 检查是否为NaN或None
                if pd.isna(date_value) or date_value is None:
                    logger.warning(f"跳过无效日期行: {row}")
                    continue
                
                # 转换为字符串格式
                if hasattr(date_value, 'strftime'):
                    date_str = date_value.strftime('%Y-%m-%d')
                else:
                    date_str = str(date_value)
                    # 检查转换后的字符串是否有效
                    if date_str == 'nan' or date_str == 'NaT':
                        logger.warning(f"跳过无效日期: {date_str}")
                        continue
                
                # 验证其他数值字段
                if any(pd.isna(row[col]) for col in ['open', 'high', 'low', 'close', 'volume']):
                    logger.warning(f"跳过包含NaN数值的行: {row}")
                    continue
                
                chart_data.append({
                    "time": date_str,
                    "open": float(row['open']),
                    "high": float(row['high']),
                    "low": float(row['low']),
                    "close": float(row['close']),
                    "volume": float(row['volume'])
                })
            except Exception as e:
                logger.warning(f"处理数据行时出错，跳过: {e}")
                continue
                
        return chart_data
    
    @classmethod
    def _prepare_markers(cls, df, signals, colors=None) -> list:
        """
        准备买卖信号标记
        
        Args:
            df: 包含数据的DataFrame
            signals: 信号列表
            colors: 主题配色字典，如果为None则使用默认颜色
            
        Returns:
            格式化的标记列表
        """
        # 如果没有传入colors，使用默认颜色
        if colors is None:
            colors = cls.get_theme_colors('dark')
        
        markers = []
        for signal in signals:
            try:
                idx = signal['index']
                if idx >= len(df):
                    continue
                    
                row = df.iloc[idx]
                
                # 处理日期字段，确保格式正确
                date_value = row['date']
                
                # 检查是否为NaN或None
                if pd.isna(date_value) or date_value is None:
                    logger.warning(f"跳过无效日期的标记: signal={signal}")
                    continue
                
                # 转换为字符串格式
                if hasattr(date_value, 'strftime'):
                    date_str = date_value.strftime('%Y-%m-%d')
                else:
                    date_str = str(date_value)
                    # 检查转换后的字符串是否有效
                    if date_str == 'nan' or date_str == 'NaT':
                        logger.warning(f"跳过无效日期的标记: {date_str}")
                        continue
                
                if signal['type'] == 'buy':
                    markers.append({
                        "time": date_str,
                        "position": "belowBar",
                        "color": colors['buySignal'],  # 使用主题配色
                        "shape": "arrowUp",
                        "text": "买"
                    })
                else:
                    markers.append({
                        "time": date_str,
                        "position": "aboveBar",
                        "color": colors['sellSignal'],  # 使用主题配色
                        "shape": "arrowDown",
                        "text": "卖"
                    })
            except Exception as e:
                logger.error(f"添加买卖标记时出错: {str(e)}")
                continue
        return markers
    
    @classmethod
    def _prepare_volume_data(cls, chart_data) -> list:
        """
        准备成交量数据
        
        Args:
            chart_data: 基础图表数据
            
        Returns:
            格式化的成交量数据列表
        """
        volume_data = []
        for i, item in enumerate(chart_data):
            # 判断涨跌
            color = '#f44336'  # 默认红色（上涨）
            if i > 0 and item['close'] < chart_data[i - 1]['close']:
                color = '#4caf50'  # 绿色（下跌）
            
            volume_data.append({
                "time": item['time'],
                "value": item['volume'],
                "color": color
            })
        return volume_data
    
    @classmethod
    def _generate_base_html_template(cls, stock, strategy_name, strategy_desc, 
                                   chart_data, markers, volume_data, 
                                   additional_series="", additional_scripts="", colors=None) -> str:
        """
        生成基础HTML模板
        
        Args:
            stock: 股票信息对象
            strategy_name: 策略名称
            strategy_desc: 策略描述
            chart_data: 图表数据
            markers: 买卖标记
            volume_data: 成交量数据
            additional_series: 额外的图表系列代码
            additional_scripts: 额外的JavaScript代码
            colors: 主题配色字典，如果为None则使用暗色主题
            
        Returns:
            完整的HTML字符串
        """
        # 如果没有传入colors，使用默认暗色主题
        if colors is None:
            colors = cls.get_theme_colors('dark')
        return f"""
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <title>{stock['name']}({stock['code']}) - 股票图表</title>
            <script src="https://unpkg.com/lightweight-charts@3.8.0/dist/lightweight-charts.standalone.production.js"></script>
            <style>
                body {{
                    margin: 0;
                    padding: 0;
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'PingFang SC', 'Helvetica Neue', Arial, sans-serif;
                    background-color: {colors['background']};
                    color: {colors['text']};
                }}
                #charts-wrapper {{
                    position: absolute;
                    width: 100%;
                    height: 100%;
                    display: flex;
                    flex-direction: column;
                }}
                
                /* 默认状态：主图占满 */
                #chart-container {{
                    position: relative;
                    width: 100%;
                    height: 100%;
                    flex-shrink: 0;
                }}
                
                /* 默认状态：副图隐藏 */
                #subchart-container {{
                    position: relative;
                    width: 100%;
                    height: 0;
                    flex-shrink: 0;
                    overflow: hidden;
                    border-top: 1px solid {colors['border']};
                }}
                
                /* 有副图时：副图占满100%，主图隐藏 */
                #charts-wrapper.has-subchart #chart-container {{
                    height: 0;
                    overflow: hidden;
                }}
                
                #charts-wrapper.has-subchart #subchart-container {{
                    height: 100%;
                    flex: none;
                    overflow: visible;
                }}
                .chart-title {{
                    position: absolute;
                    top: 10px;
                    left: 50%;
                    transform: translateX(-50%);
                    display: flex;
                    align-items: center;
                    gap: 16px;
                    z-index: 100;
                    background-color: {colors['tooltipBg']};
                    padding: 8px 16px;
                    border-radius: 8px;
                    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
                }}
                
                .title-left {{
                    display: flex;
                    align-items: center;
                    gap: 12px;
                }}
                
                .stock-name {{
                    font-size: 16px;
                    font-weight: bold;
                    color: {colors['text']};
                }}
                
                .strategy-tag {{
                    font-size: 12px;
                    color: {colors['text']};
                    opacity: 0.7;
                    padding: 2px 8px;
                    background: rgba(0, 0, 0, 0.05);
                    border-radius: 4px;
                }}
                
                .analysis-btn {{
                    background: rgba(0, 0, 0, 0.65);
                    color: white;
                    border: none;
                    padding: 6px 14px;
                    border-radius: 4px;
                    font-size: 13px;
                    font-weight: 500;
                    cursor: pointer;
                    transition: all 0.2s ease;
                    backdrop-filter: blur(10px);
                    -webkit-backdrop-filter: blur(10px);
                    white-space: nowrap;
                }}
                
                .analysis-btn:hover {{
                    background: rgba(0, 0, 0, 0.75);
                    transform: translateY(-1px);
                    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.2);
                }}
                
                /* 竖屏模式优化 */
                @media (max-width: 768px) and (orientation: portrait) {{
                    .chart-title {{
                        flex-direction: row;
                        align-items: center;
                        justify-content: space-between;
                        gap: 12px;
                        padding: 8px 12px;
                        left: 10px;
                        right: 10px;
                        transform: none;
                        width: auto;
                        max-width: calc(100% - 20px);
                    }}
                    
                    .title-left {{
                        flex: 1;
                        min-width: 0;
                        gap: 8px;
                        flex-wrap: wrap;
                    }}
                    
                    .stock-name {{
                        font-size: 15px;
                    }}
                    
                    .strategy-tag {{
                        font-size: 11px;
                        padding: 2px 6px;
                        white-space: nowrap;
                    }}
                    
                    .analysis-btn {{
                        padding: 6px 12px;
                        font-size: 13px;
                        flex-shrink: 0;
                    }}
                }}
                .strategy-info {{
                    position: absolute;
                    bottom: 10px;
                    right: 10px;
                    color: {colors['text']};
                    z-index: 100;
                    background-color: {colors['tooltipBg']};
                    padding: 5px 10px;
                    border-radius: 4px;
                    font-size: 12px;
                }}
                @media screen and (orientation: portrait) {{
                    body::after {{
                        position: fixed;
                        top: 50%;
                        left: 50%;
                        transform: translate(-50%, -50%);
                        background-color: rgba(0, 0, 0, 0.7);
                        color: white;
                        padding: 15px;
                        border-radius: 5px;
                        font-size: 16px;
                        z-index: 1000;
                    }}
                }}
                @media screen and (orientation: landscape) {{
                    body::after {{
                        display: none;
                    }}
                }}
                
                /* 指标池样式 */
                
                .side-panel {{
                    position: fixed;
                    top: 0;
                    right: -360px;
                    width: 340px;
                    height: 100vh;
                    background: {colors['background']};
                    box-shadow: -3px 0 20px rgba(0, 0, 0, 0.15);
                    transition: right 0.3s cubic-bezier(0.4, 0, 0.2, 1);
                    z-index: 999;
                    display: flex;
                    flex-direction: column;
                    border-left: 1px solid {colors['border']};
                }}
                
                .side-panel.open {{
                    right: 0;
                }}
                
                .panel-overlay {{
                    position: fixed;
                    top: 0;
                    left: 0;
                    width: 100%;
                    height: 100%;
                    background: rgba(0, 0, 0, 0.5);
                    z-index: 998;
                    opacity: 0;
                    visibility: hidden;
                    transition: opacity 0.3s ease, visibility 0.3s ease;
                }}
                
                .panel-overlay.show {{
                    opacity: 1;
                    visibility: visible;
                }}
                
                .panel-header {{
                    display: flex;
                    justify-content: space-between;
                    align-items: center;
                    padding: 16px;
                    border-bottom: 1px solid {colors['border']};
                    background: rgba(0, 0, 0, 0.02);
                }}
                
                .panel-header h3 {{
                    margin: 0;
                    font-size: 17px;
                    font-weight: 600;
                    color: {colors['text']};
                    letter-spacing: -0.3px;
                }}
                
                .close-btn {{
                    background: none;
                    border: none;
                    font-size: 28px;
                    cursor: pointer;
                    opacity: 0.4;
                    transition: opacity 0.2s;
                    color: {colors['text']};
                    padding: 0;
                    width: 32px;
                    height: 32px;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    line-height: 1;
                }}
                
                .close-btn:hover {{
                    opacity: 0.8;
                }}
                
                .panel-body {{
                    flex: 1;
                    overflow-y: auto;
                }}
                
                .quick-actions {{
                    display: flex;
                    gap: 8px;
                    padding: 12px 16px;
                    border-bottom: 1px solid {colors['border']};
                    background: rgba(0, 0, 0, 0.02);
                }}
                
                .quick-actions button {{
                    flex: 1;
                    padding: 7px 12px;
                    background: white;
                    border: 1px solid #ddd;
                    border-radius: 8px;
                    font-size: 12px;
                    cursor: pointer;
                    transition: all 0.2s;
                    color: {colors['text']};
                    white-space: nowrap;
                    font-weight: 500;
                }}
                
                .quick-actions button:hover {{
                    background: #f8f8f8;
                    border-color: #999;
                }}
                
                .indicator-category {{
                    padding: 0;
                    border-bottom: 1px solid {colors['border']};
                }}
                
                .category-header {{
                    padding: 12px 16px 8px;
                    font-weight: 600;
                    font-size: 11px;
                    color: #999;
                    text-transform: uppercase;
                    letter-spacing: 0.8px;
                    background: rgba(0, 0, 0, 0.02);
                }}
                
                .indicator-list {{
                    display: flex;
                    flex-direction: column;
                    padding: 0 16px;
                }}
                
                .indicator-item {{
                    padding: 0;
                    background: transparent;
                    border-radius: 0;
                    transition: all 0.15s;
                    border-bottom: 1px solid {colors['border']};
                }}
                
                .indicator-item:last-child {{
                    border-bottom: none;
                }}
                
                .indicator-checkbox {{
                    display: flex;
                    align-items: center;
                    gap: 12px;
                    padding: 12px 0;
                    cursor: pointer;
                    position: relative;
                    user-select: none;
                }}
                
                .indicator-checkbox input {{
                    position: absolute;
                    opacity: 0;
                    cursor: pointer;
                }}
                
                .checkmark {{
                    position: relative;
                    height: 20px;
                    width: 20px;
                    border: 2px solid #ddd;
                    border-radius: 4px;
                    transition: all 0.2s ease;
                    flex-shrink: 0;
                }}
                
                .indicator-checkbox:hover .checkmark {{
                    border-color: #999;
                }}
                
                .indicator-checkbox input:checked ~ .checkmark {{
                    background-color: #007AFF;
                    border-color: #007AFF;
                }}
                
                .checkmark:after {{
                    content: "";
                    position: absolute;
                    display: none;
                    left: 6px;
                    top: 2px;
                    width: 5px;
                    height: 10px;
                    border: solid white;
                    border-width: 0 2px 2px 0;
                    transform: rotate(45deg);
                }}
                
                .indicator-checkbox input:checked ~ .checkmark:after {{
                    display: block;
                }}
                
                .indicator-name {{
                    flex: 1;
                    font-weight: 400;
                    font-size: 15px;
                    color: {colors['text']};
                    line-height: 1.4;
                }}
                
                .color-badges {{
                    display: flex;
                    gap: 5px;
                    align-items: center;
                    margin-left: auto;
                }}
                
                .color-dot {{
                    width: 10px;
                    height: 10px;
                    border-radius: 50%;
                    border: 1.5px solid white;
                    box-shadow: 0 0 0 0.5px rgba(0,0,0,0.1);
                    flex-shrink: 0;
                }}
                
                .panel-footer {{
                    padding: 12px 16px;
                    text-align: center;
                    opacity: 0.4;
                    font-size: 10px;
                    border-top: 1px solid {colors['border']};
                    color: {colors['text']};
                }}
                
                .panel-body::-webkit-scrollbar {{
                    width: 4px;
                }}
                
                .panel-body::-webkit-scrollbar-track {{
                    background: {colors['background']};
                }}
                
                .panel-body::-webkit-scrollbar-thumb {{
                    background: {colors['border']};
                    border-radius: 2px;
                }}
                
                /* 横屏模式 - 平板和大屏手机 */
                @media (max-width: 1024px) and (orientation: landscape) {{
                    .chart-title {{
                        padding: 6px 12px;
                        gap: 12px;
                    }}
                    
                    .stock-name {{
                        font-size: 14px;
                    }}
                    
                    .strategy-tag {{
                        font-size: 11px;
                    }}
                    
                    .analysis-btn {{
                        padding: 5px 12px;
                        font-size: 12px;
                    }}
                }}
                
                /* 通用移动端 */
                @media (max-width: 768px) {{
                    .side-panel {{
                        width: 100%;
                        right: -100%;
                    }}
                    
                    .panel-header h3 {{
                        font-size: 16px;
                    }}
                    
                    .indicator-checkbox {{
                        padding: 14px 0;
                    }}
                    
                    .indicator-name {{
                        font-size: 16px;
                    }}
                    
                    .quick-actions button {{
                        font-size: 13px;
                        padding: 8px 12px;
                    }}
                }}
            </style>
        </head>
        <body>
            <div class="chart-title">
                <div class="title-left">
                    <span class="stock-name">{stock['name']}({stock['code']})</span>
                    <span class="strategy-tag">{strategy_name}</span>
                </div>
                <button class="analysis-btn" onclick="toggleIndicatorPanel()">分析工具</button>
            </div>
            <div class="strategy-info">
                {strategy_name} - {strategy_desc}
            </div>
            <div id="charts-wrapper">
                <div id="chart-container" class="main-chart"></div>
                <div id="subchart-container" class="sub-chart"></div>
            </div>
            
            <!-- 遮罩层 -->
            <div id="panel-overlay" class="panel-overlay" onclick="toggleIndicatorPanel()"></div>
            
            <!-- 分析工具侧边面板 -->
            <div id="indicator-panel" class="side-panel">
                {cls._generate_indicator_panel_html()}
            </div>
            
            <script>
                // 图表数据
                const chartData = {json.dumps(chart_data)};
                const markers = {json.dumps(markers)};
                const volumeData = {json.dumps(volume_data)};
                
                // 保存到全局变量供指标池使用
                window.candleData = chartData;
                
                // 响应式调整图表大小
                function resizeChart() {{
                    if (chart) {{
                        const mainContainer = document.getElementById('chart-container');
                        if (mainContainer) {{
                            chart.resize(
                                mainContainer.clientWidth,
                                mainContainer.clientHeight
                            );
                            chart.timeScale().fitContent();
                        }}
                    }}
                    
                    // 如果副图存在，同步调整
                    if (typeof mirrorSubchart !== 'undefined' && mirrorSubchart) {{
                        const subContainer = document.getElementById('subchart-container');
                        if (subContainer && subContainer.style.display !== 'none') {{
                            mirrorSubchart.resize(
                                subContainer.clientWidth,
                                subContainer.clientHeight
                            );
                            mirrorSubchart.timeScale().fitContent();
                        }}
                    }}
                }}
                
                // 监听窗口大小变化和设备方向变化
                window.addEventListener('resize', resizeChart);
                window.addEventListener('orientationchange', resizeChart);
                
                // 创建图表
                const chartContainer = document.getElementById('chart-container');
                const {{ createChart }} = LightweightCharts;
                const chart = createChart(chartContainer, {{
                    width: chartContainer.clientWidth,
                    height: chartContainer.clientHeight,
                    layout: {{
                        background: {{
                            color: '{colors['background']}'
                        }},
                        textColor: '{colors['text']}',
                        fontSize: 12,
                        fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "PingFang SC", "Helvetica Neue", Arial, sans-serif'
                    }},
                    grid: {{
                        vertLines: {{
                            color: '{colors['grid']}',
                            style: 4,
                            visible: true,
                        }},
                        horzLines: {{
                            color: '{colors['grid']}',
                            style: 4,
                            visible: true,
                        }},
                    }},
                    crosshair: {{
                        mode: 0,
                        vertLine: {{
                            width: 1,
                            color: '{colors['border']}',
                            style: 0,
                        }},
                        horzLine: {{
                            width: 1,
                            color: '{colors['border']}',
                            style: 0,
                        }},
                    }},
                    timeScale: {{
                        borderColor: '{colors['border']}',
                        timeVisible: true,
                        secondsVisible: false,
                    }},
                    watermark: {{
                        color: '{colors['watermark']}',
                        visible: true,
                        text: '{stock['name']}({stock['code']})',
                        fontSize: 24,
                        horzAlign: 'center',
                        vertAlign: 'center',
                    }},
                    autoSize: true,
                }});
                
                // 创建K线图（使用全局变量，供指标池使用）
                window.candleSeries = chart.addCandlestickSeries({{
                    upColor: '{colors['upColor']}',    // A股红色，涨
                    downColor: '{colors['downColor']}',  // A股绿色，跌
                    borderUpColor: '{colors['upColor']}',
                    borderDownColor: '{colors['downColor']}',
                    wickUpColor: '{colors['upColor']}',
                    wickDownColor: '{colors['downColor']}',
                    priceFormat: {{
                        type: 'price',
                        precision: 2,
                        minMove: 0.01,
                    }},
                }});
                
                // 设置烛线数据
                window.candleSeries.setData(chartData);
                
                // 创建成交量图，放在主图的30%区域
                const volumeSeries = chart.addHistogramSeries({{
                    color: '{colors['volumeUpColor']}',
                    priceFormat: {{
                        type: 'volume',
                    }},
                    priceScaleId: 'volume',
                    scaleMargins: {{
                        top: 0.7, // 主图占用70%
                        bottom: 0,
                    }},
                }});
                
                volumeSeries.setData(volumeData);
                
                {additional_series}
                
                // 保存初始买卖标记到全局变量（供指标池使用）
                window.initialMarkers = markers || [];
                console.log('📍 初始买卖标记数量:', window.initialMarkers.length);
                
                // 添加买卖标记
                if (window.initialMarkers.length > 0) {{
                    window.candleSeries.setMarkers(window.initialMarkers);
                    console.log('✅ 买卖标记已设置到图表');
                }} else {{
                    console.log('⚠️ 没有买卖标记数据');
                }}
                
                // 自动适配显示全部数据
                chart.timeScale().fitContent();
                
                // 添加触摸和鼠标事件处理，显示K线详细信息
                function showKlineInfo(param) {{
                    if (param.point === undefined || !param.time || param.point.x < 0 || param.point.y < 0) {{
                        return;
                    }}
                    
                    // 安全检查 seriesData 和 candleSeries
                    if (!param.seriesData || !window.candleSeries) {{
                        return;
                    }}
                    
                    const data = param.seriesData.get(window.candleSeries);
                    if (data) {{
                        const date = new Date(param.time * 1000);
                        const dateStr = date.getFullYear() + '-' + 
                                       String(date.getMonth() + 1).padStart(2, '0') + '-' + 
                                       String(date.getDate()).padStart(2, '0');
                        
                        // 计算涨幅
                        const change = data.close - data.open;
                        const changePercent = ((change / data.open) * 100).toFixed(2);
                        const changeStr = change >= 0 ? '+' + change.toFixed(2) : change.toFixed(2);
                        const changePercentStr = change >= 0 ? '+' + changePercent + '%' : changePercent + '%';
                        
                        // 更新标题显示K线信息
                        document.title = `${{dateStr}} 开:${{data.open.toFixed(2)}} 高:${{data.high.toFixed(2)}} 低:${{data.low.toFixed(2)}} 收:${{data.close.toFixed(2)}} 涨幅:${{changePercentStr}}`;
                        
                        // 创建或更新信息显示框
                        let infoBox = document.getElementById('kline-info');
                        if (!infoBox) {{
                            infoBox = document.createElement('div');
                            infoBox.id = 'kline-info';
                            infoBox.style.cssText = `
                                position: absolute;
                                top: 50px;
                                right: 10px;
                                background: rgba(0, 0, 0, 0.8);
                                color: white;
                                padding: 8px 12px;
                                border-radius: 4px;
                                font-size: 12px;
                                font-family: monospace;
                                z-index: 1000;
                                pointer-events: none;
                                white-space: nowrap;
                                display: block;
                            `;
                            document.body.appendChild(infoBox);
                        }}
                        
                        const changeColor = change >= 0 ? '#f44336' : '#4caf50';
                        infoBox.innerHTML = `
                            <div>${{dateStr}}</div>
                            <div>开: ${{data.open.toFixed(2)}} 高: ${{data.high.toFixed(2)}}</div>
                            <div>低: ${{data.low.toFixed(2)}} 收: ${{data.close.toFixed(2)}}</div>
                            <div style="color: ${{changeColor}}">涨跌: ${{changeStr}} (${{changePercentStr}})</div>
                        `;
                        infoBox.style.display = 'block';
                    }}
                }}
                
                // 隐藏信息框
                function hideKlineInfo() {{
                    const infoBox = document.getElementById('kline-info');
                    if (infoBox) {{
                        infoBox.style.display = 'none';
                    }}
                }}
                
                // 鼠标悬停事件（桌面端）
                chart.subscribeCrosshairMove(showKlineInfo);
                
                // 触摸事件（移动端）
                let touchTimeout;
                
                // 添加触摸事件支持，但不阻止默认行为以免影响图表
                if (chartContainer) {{
                    chartContainer.addEventListener('touchstart', function(e) {{
                        clearTimeout(touchTimeout);
                    }});
                    
                    chartContainer.addEventListener('touchmove', function(e) {{
                        clearTimeout(touchTimeout);
                    }});
                    
                    chartContainer.addEventListener('touchend', function(e) {{
                        // 延迟隐藏信息框，让用户有时间查看
                        touchTimeout = setTimeout(hideKlineInfo, 3000);
                    }});
                }}
                
                {additional_scripts}
                
                // 横屏提示和自动处理
                function handleOrientation() {{
                    if (window.orientation === 90 || window.orientation === -90) {{
                        // 横屏
                        document.body.classList.remove('portrait');
                        document.body.classList.add('landscape');
                    }} else {{
                        // 竖屏
                        document.body.classList.remove('landscape');
                        document.body.classList.add('portrait');
                    }}
                    resizeChart();
                }}
                
                // 初始检查方向
                handleOrientation();
                window.addEventListener('orientationchange', handleOrientation);
            </script>
        </body>
        </html>
        """ 