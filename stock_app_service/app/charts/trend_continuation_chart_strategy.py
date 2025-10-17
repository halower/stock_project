# -*- coding: utf-8 -*-
"""趋势延续图表策略实现"""

import pandas as pd
import json
from typing import Dict, Any

from app.charts.base_chart_strategy import BaseChartStrategy
from app.core.logging import logger

class TrendContinuationChartStrategy(BaseChartStrategy):
    """趋势延续图表策略"""
    
    # 策略元数据
    STRATEGY_CODE = "trend_continuation"
    STRATEGY_NAME = "趋势延续"
    STRATEGY_DESCRIPTION = ""
    
    @classmethod
    def generate_chart_html(cls, stock_data: Dict[str, Any], **kwargs) -> str:
        """
        生成趋势延续图表HTML
        
        Args:
            stock_data: 股票数据字典
            **kwargs: 额外参数
            
        Returns:
            完整的HTML字符串
        """
        try:
            stock = stock_data['stock']
            df = stock_data['data']
            signals = stock_data['signals']
            
            # 准备基础数据
            chart_data = cls._prepare_chart_data(df)
            markers = cls._prepare_markers(df, signals)
            volume_data = cls._prepare_volume_data(chart_data)
            
            # 准备价格线数据
            price_lines = cls._prepare_price_lines(df, signals)
            
            # 生成价格线的JavaScript代码
            additional_series = cls._generate_price_lines_code(price_lines)
            
            # 生成图例代码
            additional_scripts = cls._generate_legend_code()
            
            return cls._generate_base_html_template(
                stock=stock,
                strategy_name=cls.STRATEGY_NAME,
                strategy_desc=cls.STRATEGY_DESCRIPTION,
                chart_data=chart_data,
                markers=markers,
                volume_data=volume_data,
                additional_series=additional_series,
                additional_scripts=additional_scripts
            )
            
        except Exception as e:
            logger.error(f"生成趋势延续图表时出错: {str(e)}")
            return ""
    
    @classmethod
    def _prepare_price_lines(cls, df, signals) -> list:
        """
        准备价格线数据（支撑阻力位、止损止盈线等）
        适配A股做多特性
        
        Args:
            df: 包含数据的DataFrame
            signals: 信号列表
            
        Returns:
            价格线列表
        """
        levels = []
        
        try:
            # 添加最新买入信号的止损止盈线
            if signals:
                # 找到最后一个买入信号
                latest_buy_signal = None
                for signal in reversed(signals):
                    if signal['type'] == 'buy':
                        latest_buy_signal = signal
                        break
                
                if latest_buy_signal:
                    # 添加止损线（买入信号才有止损止盈）
                    if 'stop_loss' in latest_buy_signal and latest_buy_signal['stop_loss'] is not None:
                        levels.append({
                            "price": float(latest_buy_signal['stop_loss']),
                            "color": "#FF5252",  # 红色
                            "lineWidth": 2,
                            "lineStyle": 0,  # 实线
                            "text": "止损位"
                        })
                    
                    # 添加止盈线
                    if 'take_profit' in latest_buy_signal and latest_buy_signal['take_profit'] is not None:
                        levels.append({
                            "price": float(latest_buy_signal['take_profit']),
                            "color": "#4CAF50",  # 绿色
                            "lineWidth": 2,
                            "lineStyle": 0,  # 实线
                            "text": "止盈位"
                        })
                    
                    # 添加入场价格线
                    if 'price' in latest_buy_signal:
                        levels.append({
                            "price": float(latest_buy_signal['price']),
                            "color": "#2196F3",  # 蓝色
                            "lineWidth": 2,
                            "lineStyle": 0,  # 实线
                            "text": "买入入场位"
                        })
            
            # 添加支撑阻力位
            if not df.empty and 'last_high' in df.columns and 'last_low' in df.columns:
                last_high = df['last_high'].iloc[-1]
                last_low = df['last_low'].iloc[-1]
                
                if not pd.isna(last_high):
                    levels.append({
                        "price": float(last_high),
                        "color": "#FF9800",  # 橙色
                        "lineWidth": 1,
                        "lineStyle": 3,  # 点线
                        "text": "阻力位"
                    })
                
                if not pd.isna(last_low):
                    levels.append({
                        "price": float(last_low),
                        "color": "#8BC34A",  # 淡绿色
                        "lineWidth": 1,
                        "lineStyle": 3,  # 点线
                        "text": "支撑位"
                    })
                    
        except Exception as e:
            logger.error(f"准备价格线数据时出错: {str(e)}")
        
        return levels
    
    @classmethod
    def _generate_price_lines_code(cls, price_lines: list) -> str:
        """
        生成价格线的JavaScript代码
        
        Args:
            price_lines: 价格线数据列表
            
        Returns:
            JavaScript代码字符串
        """
        if not price_lines:
            return ""
        
        price_lines_json = json.dumps(price_lines)
        
        return f"""
                // 添加水平价格线（支撑阻力位和止损止盈线）
                const levels = {price_lines_json};
                if (levels.length > 0) {{
                    levels.forEach(level => {{
                        const price = level.price;
                        candleSeries.createPriceLine({{
                            price: price,
                            color: level.color,
                            lineWidth: level.lineWidth,
                            lineStyle: level.lineStyle,
                            axisLabelVisible: true,
                            title: level.text,
                        }});
                    }});
                }}
        """
    
    @classmethod
    def _generate_legend_code(cls) -> str:
        """
        生成图例的JavaScript代码
        适配A股做多特性
        
        Returns:
            JavaScript代码字符串
        """
        return """
                // 添加趋势延续图例（适配A股做多特性）
                const legend = document.createElement('div');
                legend.style = 'position: absolute; left: 12px; top: 12px; z-index: 100; font-size: 12px; background: rgba(21, 25, 36, 0.7); padding: 5px; border-radius: 4px;';
                legend.innerHTML = `
                    <div style="display: flex; align-items: center; margin-bottom: 4px;">
                        <span style="display: inline-block; width: 10px; height: 2px; background: #4CAF50; margin-right: 5px;"></span>
                        <span>买入信号</span>
                    </div>
                    <div style="display: flex; align-items: center; margin-bottom: 4px;">
                        <span style="display: inline-block; width: 10px; height: 2px; background: #F44336; margin-right: 5px;"></span>
                        <span>卖出信号（减仓）</span>
                    </div>
                    <div style="display: flex; align-items: center; margin-bottom: 4px;">
                        <span style="display: inline-block; width: 10px; height: 2px; background: #2196F3; margin-right: 5px;"></span>
                        <span>买入入场位</span>
                    </div>
                    <div style="display: flex; align-items: center; margin-bottom: 4px;">
                        <span style="display: inline-block; width: 10px; height: 2px; background: #4CAF50; margin-right: 5px;"></span>
                        <span>止盈位</span>
                    </div>
                    <div style="display: flex; align-items: center; margin-bottom: 4px;">
                        <span style="display: inline-block; width: 10px; height: 2px; background: #FF5252; margin-right: 5px;"></span>
                        <span>止损位</span>
                    </div>
                    <div style="display: flex; align-items: center; margin-bottom: 4px;">
                        <span style="display: inline-block; width: 10px; height: 2px; background: #FF9800; margin-right: 5px;"></span>
                        <span>阻力位</span>
                    </div>
                    <div style="display: flex; align-items: center;">
                        <span style="display: inline-block; width: 10px; height: 2px; background: #8BC34A; margin-right: 5px;"></span>
                        <span>支撑位</span>
                    </div>
                `;
                chartContainer.appendChild(legend);
        """ 