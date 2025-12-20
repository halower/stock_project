# -*- coding: utf-8 -*-
"""量价波动图表策略实现"""

import pandas as pd
import json
from typing import Dict, Any

from app.charts.base_chart_strategy import BaseChartStrategy
from app.core.logging import logger

class VolumeWaveChartStrategy(BaseChartStrategy):
    """动量守恒图表策略"""
    
    # 策略元数据
    STRATEGY_CODE = "volume_wave"
    STRATEGY_NAME = "动量守恒"
    STRATEGY_DESCRIPTION = ""  # 隐藏策略描述
    
    @classmethod
    def generate_chart_html(cls, stock_data: Dict[str, Any], **kwargs) -> str:
        """
        生成量价波动图表HTML
        
        Args:
            stock_data: 股票数据字典
            **kwargs: 额外参数（包括theme主题参数）
            
        Returns:
            完整的HTML字符串
        """
        try:
            # 获取主题配色
            theme = kwargs.get('theme', 'dark')
            colors = cls.get_theme_colors(theme)
            logger.info(f"生成图表使用主题: {theme}")
            
            stock = stock_data['stock']
            df = stock_data['data']
            signals = stock_data['signals']
            
            # 准备基础数据
            chart_data = cls._prepare_chart_data(df)
            markers = cls._prepare_markers(df, signals, colors)  # 传递主题配色
            volume_data = cls._prepare_volume_data(chart_data)
            
            # 准备EMA数据（包括Vegas隧道）
            ema6_data = cls._prepare_ema_data(df, 'ema6')
            ema12_data = cls._prepare_ema_data(df, 'ema12')
            ema18_data = cls._prepare_ema_data(df, 'ema18')
            ema144_data = cls._prepare_ema_data(df, 'ema144')
            ema169_data = cls._prepare_ema_data(df, 'ema169')
            
            # 计算 Volume Profile Pivot Anchored（新版）
            from app.indicators.tradingview.volume_profile_pivot_anchored import calculate_volume_profile_pivot_anchored
            volume_profile = calculate_volume_profile_pivot_anchored(
                df, 
                pivot_length=20, 
                profile_levels=25, 
                value_area_percent=68.0, 
                profile_width=0.30
            )
            
            # 计算 Pivot Order Blocks
            from app.indicators.tradingview.pivot_order_blocks import calculate_pivot_order_blocks
            pivot_order_blocks = calculate_pivot_order_blocks(
                df, left=15, right=8, box_count=2, percentage_change=6.0, box_extend_to_end=True
            )
            if pivot_order_blocks is None:
                pivot_order_blocks = []
            
            # 转换 Pivot Order Blocks 格式
            pivot_order_blocks_for_pool = []
            for block in pivot_order_blocks:
                pivot_order_blocks_for_pool.append({
                    'type': 'resistance' if block['type'] == 'resistance' else 'support',
                    'price_high': block['price_high'],
                    'price_low': block['price_low'],
                    'start_time': cls._get_time_string(df, block['start_index']),
                    'end_time': cls._get_time_string(df, block['end_index']),
                    'strength': block.get('strength', 0.8)
                })
            
            # 计算背离检测
            from app.indicators.tradingview.divergence_detector import calculate_divergence_detector
            divergence_data = calculate_divergence_detector(
                df,
                pivot_period=5,
                max_pivot_points=10,
                max_bars=100,
                check_macd=True,
                check_rsi=True,
                check_stoch=True,
                check_cci=True,
                check_momentum=True
            )
            
            # 不再自动绘制指标，所有指标通过指标池控制
            # 用户可以在指标池中选择启用/禁用指标
            additional_series = ""
            
            # 生成增强的图例代码（已隐藏）
            additional_scripts = cls._generate_enhanced_legend_code()
            
            # 生成指标池配置和逻辑
            indicator_pool_scripts = cls._generate_indicator_pool_scripts(
                ema6_data, ema12_data, ema18_data, ema144_data, ema169_data, volume_profile, pivot_order_blocks_for_pool, divergence_data
            )
            additional_scripts += indicator_pool_scripts
            
            return cls._generate_base_html_template(
                stock=stock,
                strategy_name=cls.STRATEGY_NAME,
                strategy_desc=cls.STRATEGY_DESCRIPTION,
                chart_data=chart_data,
                markers=markers,
                volume_data=volume_data,
                additional_series=additional_series,
                additional_scripts=additional_scripts,
                colors=colors  # 传递主题配色
            )
            
        except Exception as e:
            logger.error(f"生成量价波动图表时出错: {str(e)}")
            import traceback
            logger.error(f"完整错误堆栈:\n{traceback.format_exc()}")
            return ""
    
    @classmethod
    def _get_time_string(cls, df: pd.DataFrame, idx: int) -> str:
        """获取时间字符串（YYYY-MM-DD 格式）"""
        try:
            if idx < 0 or idx >= len(df):
                return str(idx)
            
            if 'date' in df.columns:
                date_value = df.iloc[idx]['date']
            elif 'trade_date' in df.columns:
                date_value = df.iloc[idx]['trade_date']
            else:
                return str(idx)
            
            if hasattr(date_value, 'strftime'):
                return date_value.strftime('%Y-%m-%d')
            else:
                date_str = str(date_value)
                if len(date_str) == 8:  # 20251128 格式
                    return f"{date_str[:4]}-{date_str[4:6]}-{date_str[6:8]}"
                return date_str
                
        except Exception as e:
            logger.warning(f"获取时间字符串失败: {e}")
            return str(idx)
    
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
                                          ema169_data: list, colors: dict) -> str:
        """
        生成增强的EMA系列和Vegas隧道的JavaScript代码
        
        Args:
            ema6_data: EMA6数据
            ema12_data: EMA12数据
            ema18_data: EMA18数据
            ema144_data: EMA144数据（Vegas隧道下轨）
            ema169_data: EMA169数据（Vegas隧道上轨）
            colors: 主题配色字典
            
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
                
                // 添加EMA144均线（Vegas隧道下轨）- 专业线条粗细
                if (ema144Data.length > 0) {{
                    const ema144Series = chart.addLineSeries({{
                        color: '{colors['ema144']}',  // 隧道下轨
                        lineWidth: 1,              // 细线（专业标准）
                        priceLineVisible: false,
                        lastValueVisible: false,
                        title: ''
                    }});
                    ema144Series.setData(ema144Data);
                }}
                
                // 添加EMA169均线（Vegas隧道上轨）- 专业线条粗细
                if (ema169Data.length > 0) {{
                    const ema169Series = chart.addLineSeries({{
                        color: '{colors['ema169']}',  // 隧道上轨
                        lineWidth: 1,              // 细线（专业标准）
                        priceLineVisible: false,
                        lastValueVisible: false,
                        title: ''
                    }});
                    ema169Series.setData(ema169Data);
                }}
                
                // 添加EMA6均线 - 专业线条粗细
                const ema6Data = {ema6_json};
                if (ema6Data.length > 0) {{
                    const ema6Series = chart.addLineSeries({{
                        color: '{colors['ema6']}',   // 最短期EMA（独立颜色）
                        lineWidth: 1,              // 细线（专业标准）
                        priceLineVisible: false,
                        lastValueVisible: false,
                        title: ''
                    }});
                    ema6Series.setData(ema6Data);
                }}
                
                // 添加EMA12均线 - 重要均线，加粗显示
                const ema12Data = {ema12_json};
                if (ema12Data.length > 0) {{
                    const ema12Series = chart.addLineSeries({{
                        color: '{colors['ema12']}',  // 金黄色（重要）
                        lineWidth: 2,              // 加粗线条（重要均线）⭐
                        priceLineVisible: false,
                        lastValueVisible: false,
                        title: ''
                    }});
                    ema12Series.setData(ema12Data);
                }}
                
                // 添加EMA18均线 - 重要均线，加粗显示
                const ema18Data = {ema18_json};
                if (ema18Data.length > 0) {{
                    const ema18Series = chart.addLineSeries({{
                        color: '{colors['ema18']}',  // 蓝色（重要）
                        lineWidth: 2,              // 加粗线条（重要均线）⭐
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
        生成增强的图例JavaScript代码
        
        显示战场态势和战术标记的统一说明框
        
        Returns:
            JavaScript代码字符串
        """
        # 战术信息将在 volume_profile_overlay 中统一显示
        return ""
    
    @classmethod
    def _generate_volume_profile_overlay(cls, volume_profile: Dict, colors: dict, chart_data: list) -> str:
        """
        生成 Volume Profile 覆盖层的 JavaScript 代码
        
        显示内容:
        - POC 线（Point of Control）: 成交量最大的价格水平线
        - Value Area 上界和下界: 包含70%成交量的价格区间
        
        Args:
            volume_profile: Volume Profile 计算结果
            colors: 主题配色字典
            chart_data: K线数据（用于获取时间范围）
        
        Returns:
            JavaScript代码字符串
        """
        if not volume_profile or not chart_data:
            return ""
        
        try:
            poc_price = volume_profile['poc_price']
            va_high = volume_profile['value_area_high']
            va_low = volume_profile['value_area_low']
            
            # 获取时间范围（使用最后150根K线的时间范围）
            num_bars = min(150, len(chart_data))
            first_time = chart_data[-num_bars]['time'] if len(chart_data) >= num_bars else chart_data[0]['time']
            last_time = chart_data[-1]['time']
            
            return f"""
                // ==================== 战术标记线 ====================
                
                // 主战线（火力集中区）- 原 POC 线
                const mainBattleLineSeries = chart.addLineSeries({{
                    color: '#FF5252',  // 红色
                    lineWidth: 2,
                    lineStyle: 0,  // 实线
                    priceLineVisible: false,
                    lastValueVisible: false,
                    title: '',
                    crosshairMarkerVisible: false
                }});
                
                // 设置主战线数据（水平线，从分析开始到结束）
                mainBattleLineSeries.setData([
                    {{ time: '{first_time}', value: {poc_price} }},
                    {{ time: '{last_time}', value: {poc_price} }}
                ]);
                
                // 高地防线（战区上界）- 原 Value Area 上界，加粗
                const highGroundLineSeries = chart.addLineSeries({{
                    color: '#2196F3',  // 蓝色
                    lineWidth: 2,      // 加粗到2px
                    lineStyle: 2,  // 虚线
                    priceLineVisible: false,
                    lastValueVisible: false,
                    title: '',
                    crosshairMarkerVisible: false
                }});
                
                highGroundLineSeries.setData([
                    {{ time: '{first_time}', value: {va_high} }},
                    {{ time: '{last_time}', value: {va_high} }}
                ]);
                
                // 低地防线（战区下界）- 原 Value Area 下界，加粗
                const lowGroundLineSeries = chart.addLineSeries({{
                    color: '#2196F3',  // 蓝色
                    lineWidth: 2,      // 加粗到2px
                    lineStyle: 2,  // 虚线
                    priceLineVisible: false,
                    lastValueVisible: false,
                    title: '',
                    crosshairMarkerVisible: false
                }});
                
                lowGroundLineSeries.setData([
                    {{ time: '{first_time}', value: {va_low} }},
                    {{ time: '{last_time}', value: {va_low} }}
                ]);
                
                // 添加统一的战术信息框（更窄、更透明）
                const tacticalInfoDiv = document.createElement('div');
                tacticalInfoDiv.style.cssText = `
                    position: absolute;
                    left: 8px;
                    top: 35%;
                    transform: translateY(-50%);
                    z-index: 100;
                    font-size: 10px;
                    background: rgba(21, 25, 36, 0.75);
                    color: #ccc;
                    padding: 6px 8px;
                    border-radius: 3px;
                    font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                    line-height: 1.4;
                    box-shadow: 0 1px 4px rgba(0,0,0,0.2);
                    max-width: 100px;
                `;
                tacticalInfoDiv.innerHTML = `
                    <div style="color: #FF5252; font-weight: bold; margin-bottom: 1px; font-size: 10px;">⚔️ 主战线</div>
                    <div style="color: #fff; margin-bottom: 4px; padding-left: 4px; font-size: 10px;">{poc_price:.2f}</div>
                    
                    <div style="color: #2196F3; font-weight: bold; margin-bottom: 1px; font-size: 10px;">🛡️ 战区</div>
                    <div style="color: #fff; font-size: 9px; margin-bottom: 5px; padding-left: 4px;">{va_low:.2f}-{va_high:.2f}</div>
                    
                    <div style="border-top: 1px solid rgba(255,255,255,0.08); padding-top: 4px; margin-top: 1px;">
                        <div style="color: #ddd; font-weight: bold; margin-bottom: 3px; font-size: 10px;">态势</div>
                        <div style="display: flex; align-items: center; margin-bottom: 2px;">
                            <span style="display: inline-block; width: 12px; height: 8px; background: rgba(76, 175, 80, 0.35); border: 1px solid rgba(76, 175, 80, 0.5); margin-right: 4px;"></span>
                            <span style="color: #ccc; font-size: 9px;">进攻</span>
                    </div>
                    <div style="display: flex; align-items: center;">
                            <span style="display: inline-block; width: 12px; height: 8px; background: rgba(244, 67, 54, 0.35); border: 1px solid rgba(244, 67, 54, 0.5); margin-right: 4px;"></span>
                            <span style="color: #ccc; font-size: 9px;">防守</span>
                        </div>
                    </div>
                `;
                document.getElementById('chart-container').appendChild(tacticalInfoDiv);
                
                console.log('战术标记已添加: 主战线={poc_price:.2f}, 战区=[{va_low:.2f}, {va_high:.2f}]');
        """ 
            
        except Exception as e:
            logger.error(f"生成 Volume Profile 覆盖层失败: {str(e)}")
            return "" 