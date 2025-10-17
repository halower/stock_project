# -*- coding: utf-8 -*-
"""量价波动图表策略实现"""

import pandas as pd
import json
from typing import Dict, Any

from app.charts.base_chart_strategy import BaseChartStrategy
from app.core.logging import logger

class VolumeWaveChartStrategy(BaseChartStrategy):
    """量能波动图表策略"""
    
    # 策略元数据
    STRATEGY_CODE = "volume_wave"
    STRATEGY_NAME = "量能波动"
    STRATEGY_DESCRIPTION = "基于量能波动的短线交易策略"
    
    @classmethod
    def generate_chart_html(cls, stock_data: Dict[str, Any], **kwargs) -> str:
        """
        生成量价波动图表HTML
        
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
            
            # 准备EMA数据（包括Vegas隧道）
            ema6_data = cls._prepare_ema_data(df, 'ema6')
            ema12_data = cls._prepare_ema_data(df, 'ema12')
            ema18_data = cls._prepare_ema_data(df, 'ema18')
            ema144_data = cls._prepare_ema_data(df, 'ema144')
            ema169_data = cls._prepare_ema_data(df, 'ema169')
            
            # 生成EMA系列和Vegas隧道的JavaScript代码
            additional_series = cls._generate_enhanced_ema_series_code(
                ema6_data, ema12_data, ema18_data, ema144_data, ema169_data
            )
            
            # 生成增强的图例代码
            additional_scripts = cls._generate_enhanced_legend_code()
            
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
            logger.error(f"生成量价波动图表时出错: {str(e)}")
            return ""
    
    @classmethod
    def _prepare_ema_data(cls, df, ema_column: str) -> list:
        """
        准备EMA数据
        
        Args:
            df: 包含数据的DataFrame
            ema_column: EMA列名
            
        Returns:
            格式化的EMA数据列表
        """
        ema_data = []
        if ema_column in df.columns:
            for _, row in df.iterrows():
                try:
                    # 处理日期字段，确保格式正确
                    date_value = row['date']
                    
                    # 检查是否为NaN或None
                    if pd.isna(date_value) or date_value is None:
                        continue
                    
                    # 转换为字符串格式
                    if hasattr(date_value, 'strftime'):
                        date_str = date_value.strftime('%Y-%m-%d')
                    else:
                        date_str = str(date_value)
                        # 检查转换后的字符串是否有效
                        if date_str == 'nan' or date_str == 'NaT':
                            continue
                    
                    # 检查EMA值是否有效
                    if not pd.isna(row[ema_column]):
                        ema_data.append({
                            "time": date_str,
                            "value": float(row[ema_column])
                        })
                except Exception as e:
                    logger.warning(f"处理EMA数据行时出错，跳过: {e}")
                    continue
                    
        return ema_data
    
    @classmethod
    def _generate_enhanced_ema_series_code(cls, ema6_data: list, ema12_data: list, 
                                          ema18_data: list, ema144_data: list, 
                                          ema169_data: list) -> str:
        """
        生成增强的EMA系列和Vegas隧道的JavaScript代码
        
        Args:
            ema6_data: EMA6数据
            ema12_data: EMA12数据
            ema18_data: EMA18数据
            ema144_data: EMA144数据（Vegas隧道下轨）
            ema169_data: EMA169数据（Vegas隧道上轨）
            
        Returns:
            JavaScript代码字符串
        """
        ema6_json = json.dumps(ema6_data)
        ema12_json = json.dumps(ema12_data)
        ema18_json = json.dumps(ema18_data)
        ema144_json = json.dumps(ema144_data)
        ema169_json = json.dumps(ema169_data)
        
        return f"""
                // Vegas隧道数据准备
                const ema144Data = {ema144_json};
                const ema169Data = {ema169_json};
                
                // 先添加Vegas隧道填充区域（作为背景）
                if (ema144Data.length > 0 && ema169Data.length > 0) {{
                    // 创建填充区域数据
                    const vegasFillData = [];
                    const minLength = Math.min(ema144Data.length, ema169Data.length);
                    
                    for (let i = 0; i < minLength; i++) {{
                        if (ema144Data[i].time === ema169Data[i].time) {{
                            const ema144Value = ema144Data[i].value;
                            const ema169Value = ema169Data[i].value;
                            
                            // 判断趋势：EMA144 > EMA169 为上升趋势（绿色），否则为下降趋势（红色）
                            const isUptrend = ema144Value > ema169Value;
                            
                            vegasFillData.push({{
                                time: ema144Data[i].time,
                                value: ema144Value,
                                topValue: ema169Value,
                                isUptrend: isUptrend
                            }});
                        }}
                    }}
                    
                    // 使用Area系列创建填充效果
                    // 上升趋势填充（绿色，半透明）
                    const uptrendData = vegasFillData.filter(d => d.isUptrend).map(d => ({{
                        time: d.time,
                        value: d.value  // 使用EMA144作为基准
                    }}));
                    
                    if (uptrendData.length > 0) {{
                        const vegasUptrendSeries = chart.addAreaSeries({{
                            topColor: 'rgba(76, 175, 80, 0.3)',
                            bottomColor: 'rgba(76, 175, 80, 0.05)',
                            lineColor: 'rgba(76, 175, 80, 0)',
                            lineWidth: 0,
                            priceLineVisible: false,
                            lastValueVisible: false
                        }});
                        vegasUptrendSeries.setData(uptrendData);
                    }}
                    
                    // 下降趋势填充（红色，半透明）
                    const downtrendData = vegasFillData.filter(d => !d.isUptrend).map(d => ({{
                        time: d.time,
                        value: d.topValue  // 使用EMA169作为基准
                    }}));
                    
                    if (downtrendData.length > 0) {{
                        const vegasDowntrendSeries = chart.addAreaSeries({{
                            topColor: 'rgba(244, 67, 54, 0.3)',
                            bottomColor: 'rgba(244, 67, 54, 0.05)',
                            lineColor: 'rgba(244, 67, 54, 0)',
                            lineWidth: 0,
                            priceLineVisible: false,
                            lastValueVisible: false
                        }});
                        vegasDowntrendSeries.setData(downtrendData);
                    }}
                }}
                
                // 添加EMA144均线（Vegas隧道下轨）
                if (ema144Data.length > 0) {{
                    const ema144Series = chart.addLineSeries({{
                        color: 'rgba(156, 39, 176, 0.8)',  // 紫色
                        lineWidth: 1.5,
                        priceLineVisible: false,
                        lastValueVisible: false,
                        title: ''
                    }});
                    ema144Series.setData(ema144Data);
                }}
                
                // 添加EMA169均线（Vegas隧道上轨）
                if (ema169Data.length > 0) {{
                    const ema169Series = chart.addLineSeries({{
                        color: 'rgba(103, 58, 183, 0.8)',  // 深紫色
                        lineWidth: 1.5,
                        priceLineVisible: false,
                        lastValueVisible: false,
                        title: ''
                    }});
                    ema169Series.setData(ema169Data);
                }}
                
                // 添加EMA6均线
                const ema6Data = {ema6_json};
                if (ema6Data.length > 0) {{
                    const ema6Series = chart.addLineSeries({{
                        color: 'rgba(33, 150, 243, 1)',  // 蓝色
                        lineWidth: 2,
                        priceLineVisible: false,
                        lastValueVisible: false,
                        title: ''
                    }});
                    ema6Series.setData(ema6Data);
                }}
                
                // 添加EMA12均线
                const ema12Data = {ema12_json};
                if (ema12Data.length > 0) {{
                    const ema12Series = chart.addLineSeries({{
                        color: 'rgba(0, 188, 212, 1)',  // 青色
                        lineWidth: 2,
                        priceLineVisible: false,
                        lastValueVisible: false,
                        title: ''
                    }});
                    ema12Series.setData(ema12Data);
                }}
                
                // 添加EMA18均线
                const ema18Data = {ema18_json};
                if (ema18Data.length > 0) {{
                    const ema18Series = chart.addLineSeries({{
                        color: 'rgba(255, 152, 0, 1)',  // 橙色
                        lineWidth: 2,
                        priceLineVisible: false,
                        lastValueVisible: false,
                        title: ''
                    }});
                    ema18Series.setData(ema18Data);
                }}
        """
    
    @classmethod
    def _generate_enhanced_legend_code(cls) -> str:
        """
        生成增强的图例JavaScript代码（包含Vegas隧道）
        
        Returns:
            JavaScript代码字符串
        """
        return """
                // 添加增强的EMA图例
                const legend = document.createElement('div');
                legend.style = 'position: absolute; left: 12px; top: 12px; z-index: 100; font-size: 11px; background: rgba(21, 25, 36, 0.85); padding: 8px; border-radius: 4px; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;';
                legend.innerHTML = `
                    <div style="margin-bottom: 6px; font-weight: bold; color: #fff; font-size: 12px;">技术指标</div>
                    <div style="display: flex; align-items: center; margin-bottom: 3px;">
                        <span style="display: inline-block; width: 12px; height: 2px; background: #2196F3; margin-right: 6px;"></span>
                        <span style="color: #ccc;">EMA6</span>
                    </div>
                    <div style="display: flex; align-items: center; margin-bottom: 3px;">
                        <span style="display: inline-block; width: 12px; height: 2px; background: #00BCD4; margin-right: 6px;"></span>
                        <span style="color: #ccc;">EMA12</span>
                    </div>
                    <div style="display: flex; align-items: center; margin-bottom: 3px;">
                        <span style="display: inline-block; width: 12px; height: 2px; background: #FF9800; margin-right: 6px;"></span>
                        <span style="color: #ccc;">EMA18</span>
                    </div>
                    <div style="height: 1px; background: rgba(255,255,255,0.1); margin: 6px 0;"></div>
                    <div style="margin-bottom: 3px; color: #aaa; font-size: 10px;">趋势隧道</div>
                    <div style="display: flex; align-items: center; margin-bottom: 3px;">
                        <span style="display: inline-block; width: 12px; height: 2px; background: #9C27B0; margin-right: 6px;"></span>
                        <span style="color: #ccc;">EMA144</span>
                    </div>
                    <div style="display: flex; align-items: center; margin-bottom: 3px;">
                        <span style="display: inline-block; width: 12px; height: 2px; background: #673AB7; margin-right: 6px;"></span>
                        <span style="color: #ccc;">EMA169</span>
                    </div>
                    <div style="display: flex; align-items: center; margin-bottom: 3px;">
                        <span style="display: inline-block; width: 12px; height: 8px; background: rgba(76, 175, 80, 0.3); border: 1px solid rgba(76, 175, 80, 0.5); margin-right: 6px;"></span>
                        <span style="color: #ccc; font-size: 10px;">上升趋势</span>
                    </div>
                    <div style="display: flex; align-items: center; margin-bottom: 6px;">
                        <span style="display: inline-block; width: 12px; height: 8px; background: rgba(244, 67, 54, 0.3); border: 1px solid rgba(244, 67, 54, 0.5); margin-right: 6px;"></span>
                        <span style="color: #ccc; font-size: 10px;">下降趋势</span>
                    </div>
                    <div style="height: 1px; background: rgba(255,255,255,0.1); margin: 6px 0;"></div>
                    <div style="display: flex; align-items: center; margin-bottom: 3px;">
                        <span style="display: inline-block; width: 12px; height: 2px; background: #4CAF50; margin-right: 6px;"></span>
                        <span style="color: #ccc;">买入信号</span>
                    </div>
                    <div style="display: flex; align-items: center;">
                        <span style="display: inline-block; width: 12px; height: 2px; background: #FF5252; margin-right: 6px;"></span>
                        <span style="color: #ccc;">卖出信号</span>
                    </div>
                `;
                chartContainer.appendChild(legend);
        """ 