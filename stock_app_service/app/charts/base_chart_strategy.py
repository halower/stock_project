# -*- coding: utf-8 -*-
"""图表策略抽象基类定义"""

from abc import ABC, abstractmethod
from typing import Dict, Any
import json
import pandas as pd
from app.core.logging import logger

class BaseChartStrategy(ABC):
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
            
            # 均线配色 - 专业配色（3条短期EMA需要区分）
            'ma5': '#FF6D00',                  # 橙色 MA5（短期）
            'ma10': '#9C27B0',                 # 紫色 MA10（中期）
            'ema6': '#00BCD4',                 # 青色 EMA6（最短期）
            'ema12': '#2962FF',                # 蓝色 EMA12（短期趋势）
            'ema18': '#FF6D00',                # 橙色 EMA18（中期趋势）
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
            
            # 均线配色 - 专业暗色配色（参考TradingView，3条短期EMA需要区分）
            'ma5': '#FF9800',                  # 亮橙色 MA5（短期）
            'ma10': '#9C27B0',                 # 紫色 MA10（中期）
            'ema6': '#26A69A',                 # 青绿色 EMA6（最短期）
            'ema12': '#2196F3',                # 亮蓝色 EMA12（短期趋势）
            'ema18': '#FF9800',                # 亮橙色 EMA18（中期趋势）
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
                #chart-container {{
                    position: absolute;
                    width: 100%;
                    height: 100%;
                }}
                .chart-title {{
                    position: absolute;
                    top: 10px;
                    left: 50%;
                    transform: translateX(-50%);
                    font-size: 16px;
                    font-weight: bold;
                    color: {colors['text']};
                    z-index: 100;
                    background-color: {colors['tooltipBg']};
                    padding: 5px 10px;
                    border-radius: 4px;
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
            </style>
        </head>
        <body>
            <div class="chart-title">{stock['name']}({stock['code']})
                <div style="text-align: center; font-size: 12px; margin-left: 10px; opacity: 0.8;">
                    {strategy_name}
                </div>
            </div>
            <div class="strategy-info">
                {strategy_name} - {strategy_desc}
            </div>
            <div id="chart-container"></div>
            
            <script>
                // 图表数据
                const chartData = {json.dumps(chart_data)};
                const markers = {json.dumps(markers)};
                const volumeData = {json.dumps(volume_data)};
                
                // 响应式调整图表大小
                function resizeChart() {{
                    if (chart) {{
                        chart.resize(
                            chartContainer.clientWidth,
                            chartContainer.clientHeight
                        );
                        chart.timeScale().fitContent();
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
                
                // 创建K线图
                const candleSeries = chart.addCandlestickSeries({{
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
                candleSeries.setData(chartData);
                
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
                
                // 添加买卖标记
                if (markers.length > 0) {{
                    candleSeries.setMarkers(markers);
                }}
                
                // 自动适配显示全部数据
                chart.timeScale().fitContent();
                
                // 添加触摸和鼠标事件处理，显示K线详细信息
                function showKlineInfo(param) {{
                    if (param.point === undefined || !param.time || param.point.x < 0 || param.point.y < 0) {{
                        return;
                    }}
                    
                    const data = param.seriesData.get(candleSeries);
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