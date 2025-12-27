# -*- coding: utf-8 -*-
"""
指标池混入类 - 为图表策略添加指标池功能
"""
import json
import pandas as pd
from typing import Any, Optional, Dict
from app.core.logging import logger


class IndicatorPoolMixin:
    """指标池混入类，提供指标池相关的HTML和JavaScript生成方法"""
    
    @classmethod
    def _generate_indicator_pool_scripts_auto(cls, df: pd.DataFrame, lazy_load: bool = False) -> str:
        """
        使用自动渲染器生成指标池JavaScript代码（新方法）
        
        ⚡ 前端按需计算版本：
        - 只传输指标定义（不包含data）
        - 前端在用户启用指标时实时计算
        - 类似TradingView的架构
        
        Args:
            df: 股票数据DataFrame（仅用于获取指标注册信息，不计算数据）
            lazy_load: 是否懒加载（此参数在前端按需计算模式下无效，保留仅为兼容）
            
        Returns:
            完整的JavaScript代码（配置 + 逻辑 + 计算引擎）
        """
        from app.trading.indicators.indicator_registry import IndicatorRegistry
        
        try:
            # ⚡ 混合策略：轻量级指标前端计算，重量级指标服务端预计算
            indicator_pool = cls._generate_indicator_metadata_only(df)
            
            # 生成配置JavaScript（不包含data字段）
            indicator_config_js = f"const INDICATOR_POOL = {json.dumps(indicator_pool, ensure_ascii=False)};"
            
            # 获取渲染逻辑JavaScript（保持不变）
            indicator_logic_js = cls._generate_indicator_pool_logic_js()
            
            # 读取前端指标计算引擎JavaScript文件
            calculator_js = cls._load_indicator_calculator_js()
            
            logger.info(f"✅ 生成指标池脚本（前端按需计算模式），共 {len(indicator_pool)} 个指标")
            
            return f"\n{calculator_js}\n{indicator_config_js}\n{indicator_logic_js}\n"
            
        except Exception as e:
            logger.error(f"生成指标池脚本失败: {e}")
            # 降级：返回空配置（保证不崩溃）
            return "\nconst INDICATOR_POOL = {};\n"
    
    @classmethod
    def _generate_indicator_metadata_only(cls, df: pd.DataFrame = None) -> Dict[str, Any]:
        """
        生成指标池元数据配置（智能混合策略）
        
        策略：
        - 轻量级指标（EMA等）：data=None，前端计算
        - 重量级指标（背离检测等）：data=预计算，服务端计算
        
        Args:
            df: 股票数据DataFrame（可选，用于服务端预计算重量级指标）
        
        Returns:
            指标池配置字典
        """
        from app.trading.indicators.indicator_registry import IndicatorRegistry
        from app.trading.renderers.indicator_auto_renderer import IndicatorAutoRenderer
        
        indicator_pool = {}
        all_indicators = IndicatorRegistry.get_all()
        
        # ✅ 所有指标均已实现JavaScript版本，全部前端计算！
        # 优势：
        # 1. 服务器响应速度极快（不计算指标）
        # 2. 支持任意数量指标（不影响加载速度）
        # 3. 用户体验与TradingView一致
        lightweight_indicators = {
            'ema6', 'ema12', 'ema18', 'ema144', 'ema169',
            'mirror_candle',  # 镜像K线：前端计算
            'divergence_detector',  # 多指标背离：✅ 已实现JS版本，前端计算
            'volume_profile_pivot',  # 成交量分布：✅ 已实现JS版本，前端计算
            'support_resistance_channels',  # 支撑阻力通道：前端计算
            'smart_money_concepts',  # 聪明钱概念：前端计算
            'zigzag',  # ZigZag++：前端计算
        }
        
        # 🗑️ 重量级指标列表已废弃（所有指标都已前端化）
        # Python版本保留用于：
        # - 服务端数据分析和回测
        # - 作为JavaScript实现的验证基准
        # - 批量计算和离线分析
        heavyweight_indicators = set()  # 空集合，不再使用后端预计算
        
        for indicator_id, indicator_def in all_indicators.items():
            # 构建基础配置
            config = {
                'name': indicator_def.name,
                'category': indicator_def.category,
                'renderType': indicator_def.render_type,
                'enabled': indicator_def.enabled_by_default,
                'color': indicator_def.color,
                'params': indicator_def.default_params
            }
            
            # 智能选择计算方式
            if indicator_id in lightweight_indicators:
                # 轻量级：前端计算
                config['data'] = None
                logger.debug(f"📱 {indicator_def.name}: 前端计算")
            elif indicator_id in heavyweight_indicators and df is not None:
                # 重量级：服务端预计算
                try:
                    logger.debug(f"🖥️  开始计算 {indicator_def.name}...")
                    calculated_data = IndicatorRegistry.calculate(indicator_id, df)
                    
                    # 转换为JS格式
                    js_data = IndicatorAutoRenderer.prepare_indicator_data_for_js(
                        indicator_id, calculated_data, df
                    )
                    config['data'] = js_data
                    
                    data_info = f"{len(js_data)} 项" if isinstance(js_data, list) else "对象"
                    logger.info(f"✅ {indicator_def.name}: 服务端预计算完成，数据: {data_info}")
                except Exception as e:
                    logger.warning(f"⚠️  服务端计算 {indicator_def.name} 失败: {e}")
                    config['data'] = None
            else:
                # 默认：尝试前端计算
                config['data'] = None
                logger.debug(f"⚡ {indicator_def.name}: 尝试前端计算")
            
            # 如果是复合指标
            if indicator_def.is_composite:
                config['isComposite'] = True
                config['subIndicators'] = indicator_def.sub_indicators
            
            # 如果有render_config
            if indicator_def.render_config:
                config['renderConfig'] = indicator_def.render_config
                if 'render_function' in indicator_def.render_config:
                    config['renderFunction'] = indicator_def.render_config['render_function']
            
            indicator_pool[indicator_id] = config
        
        # 统计
        lightweight_count = sum(1 for id in indicator_pool.keys() if id in lightweight_indicators)
        heavyweight_count = sum(1 for id in indicator_pool.keys() if id in heavyweight_indicators)
        
        logger.info(f"✅ 生成指标配置（混合策略）: 总计 {len(indicator_pool)} 个")
        logger.info(f"   - 轻量级（前端计算）: {lightweight_count} 个")
        logger.info(f"   - 重量级（服务端计算）: {heavyweight_count} 个")
        
        return indicator_pool
    
    @classmethod
    def _load_indicator_calculator_js(cls) -> str:
        """
        加载前端指标计算引擎JavaScript文件
        
        Returns:
            JavaScript代码字符串
        """
        import os
        from pathlib import Path
        
        # 获取静态文件路径
        static_dir = Path(__file__).parent / 'static'
        calculator_file = static_dir / 'indicator_calculator.js'
        
        if not calculator_file.exists():
            logger.warning(f"指标计算引擎文件不存在: {calculator_file}")
            return "// 指标计算引擎未找到\n"
        
        try:
            with open(calculator_file, 'r', encoding='utf-8') as f:
                content = f.read()
            logger.debug(f"✅ 已加载指标计算引擎: {len(content)} 字符")
            return content
        except Exception as e:
            logger.error(f"读取指标计算引擎失败: {e}")
            return "// 指标计算引擎加载失败\n"
    
    @classmethod
    def _generate_indicator_pool_scripts(cls, ema6_data, ema12_data, ema18_data, 
                                        ema144_data, ema169_data, volume_profile_data, 
                                        pivot_order_blocks_data=None, divergence_data=None, mirror_data=None) -> str:
        """生成指标池完整的JavaScript代码（包括配置和逻辑）"""
        indicator_config = cls._generate_indicator_config_js(
            ema6_data, ema12_data, ema18_data, ema144_data, ema169_data, 
            volume_profile_data, pivot_order_blocks_data, divergence_data, mirror_data
        )
        indicator_logic = cls._generate_indicator_pool_logic_js()
        return f"\n{indicator_config}\n{indicator_logic}\n"
    
    @classmethod
    def _generate_indicator_config_js(cls, ema6_data, ema12_data, ema18_data, 
                                      ema144_data, ema169_data, volume_profile_data, 
                                      pivot_order_blocks_data=None, divergence_data=None, mirror_data=None) -> str:
        """生成指标配置JavaScript"""
        from app.trading.indicators.indicator_registry import IndicatorRegistry
        
        all_indicators = IndicatorRegistry.get_all()
        config = {}
        
        # 数据映射
        data_map = {
            'ema6': ema6_data,
            'ema12': ema12_data,
            'ema18': ema18_data,
            'ema144': ema144_data,
            'ema169': ema169_data,
            'volume_profile_pivot': volume_profile_data,
            'pivot_order_blocks': pivot_order_blocks_data if pivot_order_blocks_data is not None else [],
            'divergence_detector': divergence_data if divergence_data is not None else [],
            'mirror_candle': mirror_data if mirror_data is not None else []
        }
        
        for ind_id, ind_def in all_indicators.items():
            data = data_map.get(ind_id)
            
            # 为特殊指标添加渲染函数代码
            render_function = None
            if ind_id == 'support_resistance_channels':
                render_function = 'renderSupportResistanceChannels' if data else None
            elif ind_id == 'zigzag':
                render_function = 'renderZigZag' if data else None
            elif ind_id == 'volume_profile_pivot':
                render_function = 'renderVolumeProfilePivot' if data else None
            elif ind_id == 'divergence_detector':
                render_function = 'renderDivergence' if data else None
            elif ind_id == 'smart_money_concepts':
                render_function = 'renderSmartMoneyConcepts' if data else None
            elif ind_id == 'mirror_candle':
                # 镜像翻转应该始终有渲染函数，即使数据为空也要设置
                render_function = 'renderMirrorSubchart'
                if not data or len(data) == 0:
                    logger.warning(f"镜像翻转数据为空！ind_id={ind_id}, data={data}")
            
            config[ind_id] = {
                'name': str(ind_def.name),
                'category': str(ind_def.category),
                'description': str(ind_def.description),
                'color': str(ind_def.color) if ind_def.color else None,
                'enabled': bool(ind_def.enabled_by_default),
                'data': data if data else [],
                'renderType': str(ind_def.render_type),
                'isComposite': bool(ind_def.is_composite),
                'subIndicators': list(ind_def.sub_indicators) if ind_def.sub_indicators else [],
                'renderFunction': render_function
            }
        
        return f"const INDICATOR_POOL = {json.dumps(config, ensure_ascii=False)};"
    
    @classmethod
    def _generate_volume_profile_render_function(cls, volume_profile_data) -> str:
        """生成 Volume Profile 的渲染函数代码（作为字符串）"""
        if not volume_profile_data or not isinstance(volume_profile_data, dict):
            return None
        
        # 提取关键数据
        profile = volume_profile_data.get('profile', [])
        if not profile:
            return None
        
        # 生成渲染逻辑（返回函数代码字符串，将在前端eval执行）
        return "renderVolumeProfile"  # 函数名，实际函数在indicator_pool_logic_js中定义
    
    @classmethod
    def _generate_indicator_pool_logic_js(cls) -> str:
        """生成指标池JavaScript逻辑 - 使用普通字符串，不需要转义大括号"""
        # 注意：这里返回的是普通字符串，所以JavaScript中的 { 和 } 不需要转义
        return """
        // Volume Profile Pivot Anchored 渲染函数
        function renderVolumeProfilePivot(vpData, chart) {
            if (!vpData || !Array.isArray(vpData) || vpData.length === 0) {
                console.warn('Volume Profile Pivot 数据无效');
                return [];
            }
            
            const seriesList = [];
            
            // 获取所有时间点，用于计算相对位置
            const allTimes = chart.data ? chart.data.map(d => d.time) : [];
            
            // 为每个 Volume Profile 区间绘制
            vpData.forEach((profile, profileIdx) => {
                const profileData = profile.profile_data;
                const startTime = profile.start_time;
                const endTime = profile.end_time;
                const pocPrice = profile.poc_price;
                const vahPrice = profile.vah_price;
                const valPrice = profile.val_price;
                const profileWidth = profile.profile_width || 0.30;
                const isDeveloping = profile.is_developing || false;
                
                // 找到 startTime 和 endTime 在数据中的索引
                const startIdx = profile.start_index;
                const endIdx = profile.end_index;
                const profileLength = endIdx - startIdx;
                
                // 绘制成交量柱（使用横向线条模拟，长度根据成交量百分比）
                profileData.forEach((level, levelIdx) => {
                    if (level.volume <= 0) return;
                    
                    const volumePercent = level.volume_percent;
                    const priceMid = level.price_mid;
                    
                    // 计算柱的长度（基于成交量百分比和 profileWidth）
                    // volumePercent 已经是相对于最大成交量的比例（0-1）
                    const barLengthFloat = profileLength * profileWidth * volumePercent;
                    
                    // 如果柱长度小于0.3个K线，不绘制（避免视觉混乱）
                    if (barLengthFloat < 0.3) return;
                    
                    const barLength = Math.max(1, Math.round(barLengthFloat));
                    
                    // 计算柱的起止时间索引（从左侧向右延伸）
                    const barStartIdx = startIdx;
                    const barEndIdx = startIdx + barLength;
                    
                    // 获取对应的时间
                    let barStartTime = startTime;
                    let barEndTime = endTime;
                    
                    try {
                        // 尝试从原始数据中获取准确的时间
                        if (typeof chartData !== 'undefined' && chartData.length > 0) {
                            if (barStartIdx >= 0 && barStartIdx < chartData.length) {
                                barStartTime = chartData[barStartIdx].time;
                            }
                            if (barEndIdx >= 0 && barEndIdx < chartData.length) {
                                barEndTime = chartData[barEndIdx].time;
                            }
                        }
                    } catch (e) {
                        // 如果获取失败，使用默认值
                        console.warn('无法获取图表数据时间:', e);
                    }
                    
                    // 颜色：Value Area 内用灰色，外面用黄色
                    const barColor = level.in_value_area 
                        ? 'rgba(67, 70, 81, 0.6)' 
                        : 'rgba(251, 192, 45, 0.6)';
                    
                    // 绘制成交量柱（横向线条）- POC 位置用粗一点的线
                    const lineWidth = level.is_poc ? 5 : 4;
                    
                    const barSeries = chart.addLineSeries({
                        color: barColor,
                        lineWidth: lineWidth,
                        lineStyle: 0,
                        lastValueVisible: false,
                        priceLineVisible: false,
                        crosshairMarkerVisible: false,
                        title: '',
                    });
                    
                    barSeries.setData([
                        { time: barStartTime, value: priceMid },
                        { time: barEndTime, value: priceMid }
                    ]);
                    
                    seriesList.push(barSeries);
                });
                
                // 绘制 POC 线（红色实线）
                const pocSeries = chart.addLineSeries({
                    color: 'rgba(255, 0, 0, 0.9)',
                    lineWidth: 3,
                    lineStyle: 0,
                    lastValueVisible: false,
                    priceLineVisible: false,
                    crosshairMarkerVisible: false,
                    title: '',
                });
                pocSeries.setData([
                    { time: startTime, value: pocPrice },
                    { time: endTime, value: pocPrice }
                ]);
                seriesList.push(pocSeries);
                
                // 绘制 VAH 线（蓝色实线）
                const vahSeries = chart.addLineSeries({
                    color: 'rgba(41, 98, 255, 0.9)',
                    lineWidth: 2,
                    lineStyle: 0,
                    lastValueVisible: false,
                    priceLineVisible: false,
                    crosshairMarkerVisible: false,
                    title: '',
                });
                vahSeries.setData([
                    { time: startTime, value: vahPrice },
                    { time: endTime, value: vahPrice }
                ]);
                seriesList.push(vahSeries);
                
                // 绘制 VAL 线（蓝色实线）
                const valSeries = chart.addLineSeries({
                    color: 'rgba(41, 98, 255, 0.9)',
                    lineWidth: 2,
                    lineStyle: 0,
                    lastValueVisible: false,
                    priceLineVisible: false,
                    crosshairMarkerVisible: false,
                    title: '',
                });
                valSeries.setData([
                    { time: startTime, value: valPrice },
                    { time: endTime, value: valPrice }
                ]);
                seriesList.push(valSeries);
                
                // 绘制背景区域填充（使用多条半透明线模拟）
                const fillLines = 15;
                for (let i = 0; i < fillLines; i++) {
                    const fillPrice = profile.price_low + (profile.price_high - profile.price_low) * (i / fillLines);
                    const fillSeries = chart.addLineSeries({
                        color: 'rgba(41, 98, 255, 0.03)',
                        lineWidth: 3,
                        lineStyle: 0,
                        lastValueVisible: false,
                        priceLineVisible: false,
                        crosshairMarkerVisible: false,
                        title: '',
                    });
                    fillSeries.setData([
                        { time: startTime, value: fillPrice },
                        { time: endTime, value: fillPrice }
                    ]);
                    seriesList.push(fillSeries);
                }
            });
            
            console.log('✅ Volume Profile Pivot 已渲染:', vpData.length, '个Profile，共', seriesList.length, '条系列');
            return seriesList;
        }
        
        // Pivot Order Blocks 渲染函数 - 使用图表系列绘制
        function renderPivotOrderBlocks(pobData, chart) {
            if (!pobData || !Array.isArray(pobData) || pobData.length === 0) {
                console.warn('Pivot Order Blocks 数据无效');
                return [];
            }
            
            const seriesList = [];
            
            // 为每个订单块创建系列
            pobData.forEach((block, blockIdx) => {
                const isResistance = block.type === 'resistance';
                const priceHigh = block.price_high;
                const priceLow = block.price_low;
                const priceRange = priceHigh - priceLow;
                const startTime = block.start_time;
                const endTime = block.end_time;
                
                // 设置颜色
                const bgColor = isResistance ? 'rgba(100, 140, 210, 0.18)' : 'rgba(220, 130, 70, 0.18)';
                const lineColor = isResistance ? 'rgba(100, 140, 210, 0.8)' : 'rgba(220, 130, 70, 0.8)';
                
                // 创建15条填充线
                const NUM_FILL_LINES = 15;
                for (let i = 0; i < NUM_FILL_LINES; i++) {
                    const priceLevel = priceLow + (priceRange * (i + 0.5) / NUM_FILL_LINES);
                    
                    const fillSeries = chart.addLineSeries({
                        color: bgColor,
                        lineWidth: 5,
                        lineStyle: 0,
                        lastValueVisible: false,
                        priceLineVisible: false,
                        crosshairMarkerVisible: false,
                        title: '',
                    });
                    
                    fillSeries.setData([
                        { time: startTime, value: priceLevel },
                        { time: endTime, value: priceLevel }
                    ]);
                    
                    seriesList.push(fillSeries);
                }
                
                // 创建上下边界虚线
                const topBorderSeries = chart.addLineSeries({
                    color: lineColor,
                    lineWidth: 2,
                    lineStyle: 2,
                    lastValueVisible: false,
                    priceLineVisible: false,
                    crosshairMarkerVisible: false,
                    title: '',
                });
                topBorderSeries.setData([
                    { time: startTime, value: priceHigh },
                    { time: endTime, value: priceHigh }
                ]);
                seriesList.push(topBorderSeries);
                
                const bottomBorderSeries = chart.addLineSeries({
                    color: lineColor,
                    lineWidth: 2,
                    lineStyle: 2,
                    lastValueVisible: false,
                    priceLineVisible: false,
                    crosshairMarkerVisible: false,
                    title: '',
                });
                bottomBorderSeries.setData([
                    { time: startTime, value: priceLow },
                    { time: endTime, value: priceLow }
                ]);
                seriesList.push(bottomBorderSeries);
            });
            
            console.log('✅ Pivot Order Blocks 已渲染:', pobData.length, '个订单块，共', seriesList.length, '条系列');
            return seriesList;
        }
        
        // Divergence 渲染函数
        function renderDivergence(divData, chart) {
            console.log('🔍 [Divergence] 开始渲染，数据长度:', divData ? divData.length : 0);
            
            if (!divData || !Array.isArray(divData) || divData.length === 0) {
                console.warn('⚠️ [Divergence] 无数据');
                return [];
            }
            
            const seriesList = [];
            const markers = [];
            
            // 颜色映射
            const colorMap = {
                'bullish': 'rgba(255, 215, 0, 0.9)',           // 金色 - 正背离（看涨）
                'bearish': 'rgba(0, 51, 153, 0.9)',            // 深蓝 - 负背离（看跌）
                'bullish_hidden': 'rgba(0, 255, 0, 0.9)',      // 绿色 - 隐藏正背离
                'bearish_hidden': 'rgba(255, 0, 0, 0.9)'       // 红色 - 隐藏负背离
            };
            
            const labelColorMap = {
                'bullish': '#FFD700',           // 金色
                'bearish': '#003399',           // 深蓝
                'bullish_hidden': '#00FF00',    // 绿色
                'bearish_hidden': '#FF0000'     // 红色
            };
            
            // 为每个背离组绘制连线和标签
            divData.forEach((divGroup, idx) => {
                console.log('渲染背离组 #' + (idx + 1) + ':', divGroup);
                
                const color = colorMap[divGroup.color] || 'rgba(128, 128, 128, 0.8)';
                const labelColor = labelColorMap[divGroup.color] || '#888888';
                
                try {
                    // 绘制所有背离线（如果有多个指标检测到）
                    if (divGroup.lines && Array.isArray(divGroup.lines)) {
                        divGroup.lines.forEach((line) => {
                            const divLine = chart.addLineSeries({
                                color: color,
                                lineWidth: 2,
                                lineStyle: divGroup.type.includes('hidden') ? 2 : 0,
                                lastValueVisible: false,
                                priceLineVisible: false,
                                crosshairMarkerVisible: false,
                                title: '',
                            });
                            
                            divLine.setData([
                                { time: line.start_time, value: line.start_price },
                                { time: line.end_time, value: line.end_price }
                            ]);
                            
                            seriesList.push(divLine);
                        });
                    } else {
                        // 兼容旧格式
                        const divLine = chart.addLineSeries({
                            color: color,
                            lineWidth: 2,
                            lineStyle: divGroup.type.includes('hidden') ? 2 : 0,
                            lastValueVisible: false,
                            priceLineVisible: false,
                            crosshairMarkerVisible: false,
                            title: '',
                        });
                        
                        divLine.setData([
                            { time: divGroup.start_time, value: divGroup.start_price },
                            { time: divGroup.end_time, value: divGroup.end_price }
                        ]);
                        
                        seriesList.push(divLine);
                    }
                    
                    // 添加标签标记（使用与买卖信号相同的箭头样式）
                    if (divGroup.label_text) {
                        const isBullish = divGroup.type.includes('bullish');
                        // LightweightCharts不支持多行文本，将换行符替换为逗号+空格，更紧凑易读
                        const singleLineText = divGroup.label_text.replace(/\\n/g, ', ');
                        markers.push({
                            time: divGroup.end_time,
                            position: isBullish ? 'belowBar' : 'aboveBar',
                            color: labelColor,
                            shape: isBullish ? 'arrowUp' : 'arrowDown',
                            text: singleLineText
                        });
                        console.log('📝 [Divergence] 标签:', singleLineText, '@', divGroup.end_time);
                    }
                    
                    console.log('✅ 背离组 #' + (idx + 1) + ' 已添加');
                } catch (e) {
                    console.error('渲染背离失败:', e);
                }
            });
            
            // 将markers应用到K线图上（不覆盖原有的买卖标签）
            if (markers.length > 0 && window.candleSeries) {
                try {
                    // 使用全局保存的初始买卖标记
                    const buySellMarkers = window.initialMarkers || [];
                    console.log('📊 [Divergence] 买卖信号:', buySellMarkers.length, '个');
                    
                    // 合并买卖标签和新的背离标签
                    const allMarkers = [...buySellMarkers, ...markers];
                    
                    // 按时间排序
                    allMarkers.sort((a, b) => {
                        if (a.time < b.time) return -1;
                        if (a.time > b.time) return 1;
                        return 0;
                    });
                    
                    window.candleSeries.setMarkers(allMarkers);
                    console.log('✅ [Divergence] 完成: 买卖信号', buySellMarkers.length, '个 + 背离标签', markers.length, '个 = 总计', allMarkers.length, '个');
                } catch (e) {
                    console.error('❌ [Divergence] 设置markers失败:', e);
                }
            } else {
                console.log('⚠️ [Divergence] 没有标签需要添加');
            }
            
            console.log('✅ [Divergence] 渲染完成:', seriesList.length, '条线，', markers.length, '个标签');
            return seriesList;
        }
        
        // Smart Money Concepts渲染函数
        function renderSmartMoneyConcepts(smcData, chart) {
            console.log('🧠 [Smart Money Concepts] 开始渲染');
            
            // 检查是否需要前端计算
            const needsCalculation = !smcData || 
                (Array.isArray(smcData.swingStructures) && smcData.swingStructures.length === 0 &&
                 Array.isArray(smcData.internalStructures) && smcData.internalStructures.length === 0 &&
                 Array.isArray(smcData.swingOrderBlocks) && smcData.swingOrderBlocks.length === 0 &&
                 Array.isArray(smcData.internalOrderBlocks) && smcData.internalOrderBlocks.length === 0);
            
            if (needsCalculation) {
                console.log('⚙️ [SMC] 数据为空，开始前端计算...');
                console.log(`   - K线数据: ${chartData ? chartData.length : 0} 根`);
                
                const config = INDICATOR_POOL['smart_money_concepts'] || {};
                const params = config.params || {
                    swing_length: 50,
                    internal_length: 5,
                    show_internals: true,
                    show_structure: true,
                    show_internal_ob: true,
                    internal_ob_count: 5,
                    show_swing_ob: false,
                    swing_ob_count: 5
                };
                
                console.log('   - 参数配置:', params);
                
                smcData = calculateSmartMoneyConcepts(chartData, params);
                
                if (!smcData) {
                    console.error('❌ [SMC] 计算函数返回null');
                    return [];
                }
                
                console.log('✅ [SMC] 前端计算完成');
                console.log(`   - 摆动结构: ${smcData.swingStructures?.length || 0}`);
                console.log(`   - 内部结构: ${smcData.internalStructures?.length || 0}`);
                console.log(`   - 摆动OB: ${smcData.swingOrderBlocks?.length || 0}`);
                console.log(`   - 内部OB: ${smcData.internalOrderBlocks?.length || 0}`);
                console.log(`   - 等高等低: ${smcData.equalHighsLows?.length || 0}`);
            }
            
            const seriesList = [];
            const endTime = chartData[chartData.length - 1].time;
            
            // 颜色配置（A股习惯：红涨绿跌）
            const bullishColor = '#F23645';  // 红色（涨）
            const bearishColor = '#089981';  // 绿色（跌）
            const internalBullColor = '#F23645';
            const internalBearColor = '#089981';
            
            // 1. 渲染摆动结构线（BOS/CHoCH）- 使用markers显示中文标签
            if (smcData.swingStructures && smcData.swingStructures.length > 0) {
                const structureMarkers = [];
                
                smcData.swingStructures.forEach((structure, index) => {
                    const color = structure.type === 'bullish' ? bullishColor : bearishColor;
                    const lineStyle = 0; // 实线
                    
                    // 使用标准SMC术语
                    const tag = structure.tag; // BOS 或 CHoCH
                    
                    // 创建结构线（加粗）
                    const structureLine = chart.addLineSeries({
                        color: color,
                        lineWidth: 3,  // 加粗到3
                        lineStyle: lineStyle,
                        lastValueVisible: false,
                        priceLineVisible: false
                    });
                    
                    structureLine.setData([
                        { time: structure.startTime, value: structure.price },
                        { time: structure.time, value: structure.price }
                    ]);
                    
                    // 在线上添加标签（使用PriceLine）
                    try {
                        structureLine.createPriceLine({
                            price: structure.price,
                            color: color,
                            lineWidth: 0,
                            lineStyle: 2,
                            axisLabelVisible: true,
                            title: tag
                        });
                    } catch (e) {
                        console.warn('   - 无法在线上添加标签，使用备用方案');
                        // 备用方案：添加到K线上
                        structureMarkers.push({
                            time: structure.time,
                            position: structure.type === 'bullish' ? 'belowBar' : 'aboveBar',
                            color: color,
                            shape: structure.type === 'bullish' ? 'arrowUp' : 'arrowDown',
                            text: tag,
                            size: 1
                        });
                    }
                    
                    seriesList.push(structureLine);
                });
                
                // 添加标签到主K线图上
                if (typeof window.candleSeries !== 'undefined' && window.candleSeries && structureMarkers.length > 0) {
                    try {
                        // 保存摆动结构的markers到全局，供后续合并使用
                        if (!window.smcMarkers) {
                            window.smcMarkers = {
                                structure: [],
                                internal: [],
                                equal: []
                            };
                        }
                        window.smcMarkers.structure = structureMarkers;
                        console.log(`   - 摆动结构: ${smcData.swingStructures.length} (收集了${structureMarkers.length}个标签)`);
                    } catch (e) {
                        console.error('   - 收集摆动结构标签失败:', e);
                    }
                } else {
                    console.warn('   - window.candleSeries 不可用');
                }
            }
            
            // 2. 渲染内部结构线 - 使用markers显示中文标签
            if (smcData.internalStructures && smcData.internalStructures.length > 0) {
                const internalMarkers = [];
                
                smcData.internalStructures.forEach((structure, index) => {
                    const color = structure.type === 'bullish' ? internalBullColor : internalBearColor;
                    const lineStyle = 1; // 虚线
                    
                    // 内部结构也使用相同标签（不加前缀）
                    const tag = structure.tag; // BOS 或 CHoCH
                    
                    // 创建结构线（虚线稍细）
                    const structureLine = chart.addLineSeries({
                        color: color,
                        lineWidth: 2,  // 虚线用2
                        lineStyle: lineStyle,
                        lastValueVisible: false,
                        priceLineVisible: false
                    });
                    
                    structureLine.setData([
                        { time: structure.startTime, value: structure.price },
                        { time: structure.time, value: structure.price }
                    ]);
                    
                    // 在线上添加标签
                    try {
                        structureLine.createPriceLine({
                            price: structure.price,
                            color: color,
                            lineWidth: 0,
                            lineStyle: 2,
                            axisLabelVisible: true,
                            title: tag
                        });
                    } catch (e) {
                        console.warn('   - 无法在线上添加内部结构标签');
                        internalMarkers.push({
                            time: structure.time,
                            position: structure.type === 'bullish' ? 'belowBar' : 'aboveBar',
                            color: color,
                            shape: 'circle',
                            text: tag,
                            size: 0.8
                        });
                    }
                    
                    seriesList.push(structureLine);
                });
                
                // 收集内部结构标签
                if (typeof window.candleSeries !== 'undefined' && window.candleSeries && internalMarkers.length > 0) {
                    try {
                        if (!window.smcMarkers) {
                            window.smcMarkers = {
                                structure: [],
                                internal: [],
                                equal: []
                            };
                        }
                        window.smcMarkers.internal = internalMarkers;
                        console.log(`   - 内部结构: ${smcData.internalStructures.length} (收集了${internalMarkers.length}个标签)`);
                    } catch (e) {
                        console.error('   - 收集内部结构标签失败:', e);
                    }
                }
            }
            
            // 3. 渲染摆动订单块（使用LineSeries画矩形边框，更深颜色）
            if (smcData.swingOrderBlocks && smcData.swingOrderBlocks.length > 0) {
                console.log(`   [渲染摆动订单块] 数量: ${smcData.swingOrderBlocks.length}`);
                smcData.swingOrderBlocks.forEach((block, idx) => {
                    console.log(`     ${idx+1}. top=${block.top}, bottom=${block.bottom}, height=${block.top - block.bottom}, bias=${block.bias}`);
                    
                    const borderColor = block.bias === 1 ? 
                        'rgba(242, 54, 69, 0.8)' :  // 看涨：红色（A股习惯）
                        'rgba(8, 153, 129, 0.8)';   // 看跌：绿色（A股习惯）
                    
                    // 上边框（加粗）
                    const topLine = chart.addLineSeries({
                        color: borderColor,
                        lineWidth: 2,
                        lastValueVisible: false,
                        priceLineVisible: false
                    });
                    topLine.setData([
                        { time: block.time, value: block.top },
                        { time: endTime, value: block.top }
                    ]);
                    seriesList.push(topLine);
                    
                    // 下边框（加粗）
                    const bottomLine = chart.addLineSeries({
                        color: borderColor,
                        lineWidth: 2,
                        lastValueVisible: false,
                        priceLineVisible: false
                    });
                    bottomLine.setData([
                        { time: block.time, value: block.bottom },
                        { time: endTime, value: block.bottom }
                    ]);
                    seriesList.push(bottomLine);
                    
                    // 中间填充线
                    const fillColor = block.bias === 1 ? 
                        'rgba(242, 54, 69, 0.2)' :  // 看涨：红色
                        'rgba(8, 153, 129, 0.2)';   // 看跌：绿色
                    const step = (block.top - block.bottom) / 10;
                    for (let i = 1; i < 10; i++) {
                        const price = block.bottom + step * i;
                        const fillLine = chart.addLineSeries({
                            color: fillColor,
                            lineWidth: 1,
                            lastValueVisible: false,
                            priceLineVisible: false
                        });
                        fillLine.setData([
                            { time: block.time, value: price },
                            { time: endTime, value: price }
                        ]);
                        seriesList.push(fillLine);
                    }
                    
                    console.log(`     ✅ 摆动订单块渲染完成`);
                });
            }
            
            // 4. 渲染内部订单块（使用LineSeries画矩形边框）
            if (smcData.internalOrderBlocks && smcData.internalOrderBlocks.length > 0) {
                console.log(`   [渲染内部订单块] 数量: ${smcData.internalOrderBlocks.length}`);
                smcData.internalOrderBlocks.forEach((block, idx) => {
                    console.log(`     ${idx+1}. top=${block.top}, bottom=${block.bottom}, height=${block.top - block.bottom}, bias=${block.bias}`);
                    
                    const borderColor = block.bias === 1 ? 
                        'rgba(247, 124, 128, 0.6)' :  // 看涨：亮红色（A股习惯）
                        'rgba(49, 121, 245, 0.6)';    // 看跌：亮绿蓝色（A股习惯）
                    
                    // 上边框
                    const topLine = chart.addLineSeries({
                        color: borderColor,
                        lineWidth: 1,
                        lastValueVisible: false,
                        priceLineVisible: false
                    });
                    topLine.setData([
                        { time: block.time, value: block.top },
                        { time: endTime, value: block.top }
                    ]);
                    seriesList.push(topLine);
                    
                    // 下边框
                    const bottomLine = chart.addLineSeries({
                        color: borderColor,
                        lineWidth: 1,
                        lastValueVisible: false,
                        priceLineVisible: false
                    });
                    bottomLine.setData([
                        { time: block.time, value: block.bottom },
                        { time: endTime, value: block.bottom }
                    ]);
                    seriesList.push(bottomLine);
                    
                    // 中间填充线（多条半透明线模拟填充）
                    const fillColor = block.bias === 1 ? 
                        'rgba(247, 124, 128, 0.15)' :  // 看涨：亮红色
                        'rgba(49, 121, 245, 0.15)';    // 看跌：亮绿蓝色
                    const step = (block.top - block.bottom) / 10;  // 画10条线填充
                    for (let i = 1; i < 10; i++) {
                        const price = block.bottom + step * i;
                        const fillLine = chart.addLineSeries({
                            color: fillColor,
                            lineWidth: 1,
                            lastValueVisible: false,
                            priceLineVisible: false
                        });
                        fillLine.setData([
                            { time: block.time, value: price },
                            { time: endTime, value: price }
                        ]);
                        seriesList.push(fillLine);
                    }
                    
                    console.log(`     ✅ 内部订单块渲染完成`);
                });
            }
            
            // 5. 渲染等高等低线 - 使用markers显示中文标签
            if (smcData.equalHighsLows && smcData.equalHighsLows.length > 0) {
                const eqhlMarkers = [];
                
                smcData.equalHighsLows.forEach((ehl, index) => {
                    // EQH在高点（看跌阻力）用绿色，EQL在低点（看涨支撑）用红色
                    const color = ehl.type === 'high' ? bearishColor : bullishColor;
                    const label = ehl.type === 'high' ? 'EQH' : 'EQL';
                    
                    const line = chart.addLineSeries({
                        color: color,
                        lineWidth: 2,  // 加粗到2
                        lineStyle: 2, // 点线
                        lastValueVisible: false,
                        priceLineVisible: false
                    });
                    
                    line.setData([
                        { time: ehl.startTime, value: ehl.price },
                        { time: ehl.endTime, value: ehl.price }
                    ]);
                    
                    // 在线上添加标签
                    try {
                        line.createPriceLine({
                            price: ehl.price,
                            color: color,
                            lineWidth: 0,
                            lineStyle: 2,
                            axisLabelVisible: true,
                            title: label
                        });
                    } catch (e) {
                        console.warn('   - 无法在线上添加等高等低标签');
                        eqhlMarkers.push({
                            time: ehl.endTime,
                            position: ehl.type === 'high' ? 'aboveBar' : 'belowBar',
                            color: color,
                            shape: 'circle',
                            text: label,
                            size: 0.7
                        });
                    }
                    
                    seriesList.push(line);
                });
                
                // 收集等高等低标签
                if (typeof window.candleSeries !== 'undefined' && window.candleSeries && eqhlMarkers.length > 0) {
                    try {
                        if (!window.smcMarkers) {
                            window.smcMarkers = {
                                structure: [],
                                internal: [],
                                equal: []
                            };
                        }
                        window.smcMarkers.equal = eqhlMarkers;
                        console.log(`   - 等高等低: ${smcData.equalHighsLows.length} (收集了${eqhlMarkers.length}个标签)`);
                    } catch (e) {
                        console.error('   - 收集等高等低标签失败:', e);
                    }
                }
            }
            
            // 6. 渲染Fair Value Gaps（FVG - 公平价值缺口）
            if (smcData.fairValueGaps && smcData.fairValueGaps.length > 0) {
                console.log(`   [渲染FVG] 数量: ${smcData.fairValueGaps.length}`);
                smcData.fairValueGaps.forEach((fvg, idx) => {
                    const isBullish = fvg.type === 'bullish';
                    const borderColor = isBullish ? 
                        'rgba(255, 0, 8, 0.6)' :     // 看涨：红色（A股习惯）
                        'rgba(0, 255, 104, 0.6)';    // 看跌：绿色（A股习惯）
                    const fillColor = isBullish ?
                        'rgba(255, 0, 8, 0.1)' :     // 看涨：红色
                        'rgba(0, 255, 104, 0.1)';    // 看跌：绿色
                    
                    // 上边框
                    const topLine = chart.addLineSeries({
                        color: borderColor,
                        lineWidth: 1,
                        lastValueVisible: false,
                        priceLineVisible: false
                    });
                    topLine.setData([
                        { time: fvg.time, value: fvg.top },
                        { time: fvg.endTime, value: fvg.top }
                    ]);
                    seriesList.push(topLine);
                    
                    // 下边框
                    const bottomLine = chart.addLineSeries({
                        color: borderColor,
                        lineWidth: 1,
                        lastValueVisible: false,
                        priceLineVisible: false
                    });
                    bottomLine.setData([
                        { time: fvg.time, value: fvg.bottom },
                        { time: fvg.endTime, value: fvg.bottom }
                    ]);
                    seriesList.push(bottomLine);
                    
                    // 中间填充线
                    const step = (fvg.top - fvg.bottom) / 5;  // 画5条线填充
                    for (let i = 1; i < 5; i++) {
                        const price = fvg.bottom + step * i;
                        const fillLine = chart.addLineSeries({
                            color: fillColor,
                            lineWidth: 1,
                            lastValueVisible: false,
                            priceLineVisible: false
                        });
                        fillLine.setData([
                            { time: fvg.time, value: price },
                            { time: fvg.endTime, value: price }
                        ]);
                        seriesList.push(fillLine);
                    }
                    
                    // 添加FVG标签在价格轴上
                    const midPrice = (fvg.top + fvg.bottom) / 2;
                    const labelLine = chart.addLineSeries({
                        color: 'rgba(0,0,0,0)',
                        lineWidth: 0,
                        lastValueVisible: false,
                        priceLineVisible: false
                    });
                    labelLine.setData([
                        { time: fvg.time, value: midPrice }
                    ]);
                    
                    try {
                        labelLine.createPriceLine({
                            price: midPrice,
                            color: borderColor,
                            lineWidth: 0,
                            lineStyle: 2,
                            axisLabelVisible: true,
                            title: 'FVG'
                        });
                    } catch (e) {
                        console.warn('   - 无法添加FVG标签');
                    }
                    
                    seriesList.push(labelLine);
                });
                console.log(`   ✅ FVG渲染完成: ${smcData.fairValueGaps.length} 个`);
            }
            
            // 7. 渲染摆动点标签（可选功能，默认不启用）
            // 注意：摆动点标签会显示在K线上，可能与其他指标标签冲突
            if (smcData.swingPoints && smcData.swingPoints.length > 0 && false) {
                // 暂时禁用摆动点标签，避免图表过于拥挤
                // 用户可以通过参数 show_swing_points 来启用
                console.log(`   - 摆动点: ${smcData.swingPoints.length} (已禁用显示)`);
            }
            
            // 8. 统一添加所有标签到K线图上（追加模式，不覆盖原有标签）
            if (typeof window.candleSeries !== 'undefined' && window.candleSeries && window.smcMarkers) {
                try {
                    const smcMarkersArray = [
                        ...(window.smcMarkers.structure || []),
                        ...(window.smcMarkers.internal || []),
                        ...(window.smcMarkers.equal || [])
                    ];
                    
                    if (smcMarkersArray.length > 0) {
                        // 获取现有的策略标签（买卖点）
                        const existingMarkers = window.initialMarkers || [];
                        
                        // 合并：策略标签 + SMC标签
                        const allMarkers = [...existingMarkers, ...smcMarkersArray];
                        window.candleSeries.setMarkers(allMarkers);
                        
                        console.log(`✅ [SMC标签] 已添加 ${smcMarkersArray.length} 个SMC标签`);
                        console.log(`   - 摆动结构: ${window.smcMarkers.structure?.length || 0}`);
                        console.log(`   - 内部结构: ${window.smcMarkers.internal?.length || 0}`);
                        console.log(`   - 等高等低: ${window.smcMarkers.equal?.length || 0}`);
                        console.log(`   - 策略买卖点: ${existingMarkers.length}`);
                        console.log(`   - 总计: ${allMarkers.length}`);
                    }
                } catch (e) {
                    console.error('❌ [SMC标签] 添加标签失败:', e);
                }
            } else {
                console.warn('⚠️ [SMC标签] window.candleSeries 或 window.smcMarkers 不可用');
            }
            
            console.log(`✅ [Smart Money Concepts] 渲染完成: ${seriesList.length} 个线条元素`);
            return seriesList;
        }
        
        // Support Resistance Channels 渲染函数
        function renderSupportResistanceChannels(srData, chart) {
            console.log('📊 [Support Resistance Channels] 开始渲染');
            
            // 检查是否需要前端计算
            if (!srData || !srData.channels || srData.channels.length === 0) {
                console.log('⚙️ [SR Channels] 数据为空，开始前端计算...');
                const config = INDICATOR_POOL['support_resistance_channels'] || {};
                const params = config.params || {};
                srData = calculateSupportResistanceChannels(chartData, params);
                
                if (!srData || !srData.channels || srData.channels.length === 0) {
                    console.error('❌ [SR Channels] 计算失败或无通道');
                    return [];
                }
                console.log('✅ [SR Channels] 前端计算完成');
            }
            
            const seriesList = [];
            const currentBarTime = chartData[chartData.length - 1].time;
            
            // 获取颜色配置（优雅配色 - A股习惯）
            const config = INDICATOR_POOL['support_resistance_channels'] || {};
            const params = config.params || {};
            const resistanceColor = params.resistance_color || 'rgba(38, 166, 154, 0.7)';   // 阻力：优雅青绿
            const supportColor = params.support_color || 'rgba(239, 83, 80, 0.7)';          // 支撑：柔和红色
            const inChannelColor = params.in_channel_color || 'rgba(158, 158, 158, 0.6)';   // 在通道内：中性灰
            
            // 渲染通道
            srData.channels.forEach((channel, idx) => {
                // 根据类型选择颜色
                let color = inChannelColor;
                if (channel.type === 'support') {
                    color = supportColor;
                } else if (channel.type === 'resistance') {
                    color = resistanceColor;
                }
                
                console.log(`   通道${idx + 1}: ${channel.type}, 强度=${channel.strength}, [${channel.low.toFixed(2)}, ${channel.high.toFixed(2)}]`);
                
                // 边框颜色（更明显）
                const borderColor = color;
                // 填充颜色（更柔和）
                const fillColor = color.replace(/[\d\.]+\)$/, '0.12)');
                
                // 上边框
                const topLine = chart.addLineSeries({
                    color: borderColor,
                    lineWidth: 1,
                    lastValueVisible: false,
                    priceLineVisible: false
                });
                
                topLine.setData([
                    { time: chartData[0].time, value: channel.high },
                    { time: currentBarTime, value: channel.high }
                ]);
                seriesList.push(topLine);
                
                // 下边框
                const bottomLine = chart.addLineSeries({
                    color: borderColor,
                    lineWidth: 1,
                    lastValueVisible: false,
                    priceLineVisible: false
                });
                
                bottomLine.setData([
                    { time: chartData[0].time, value: channel.low },
                    { time: currentBarTime, value: channel.low }
                ]);
                seriesList.push(bottomLine);
                
                // 填充通道（用更密集但更透明的线，创造渐变效果）
                const fillLines = 12;  // 增加填充线数量
                const step = (channel.high - channel.low) / (fillLines + 1);
                for (let i = 1; i <= fillLines; i++) {
                    const price = channel.low + step * i;
                    const fillLine = chart.addLineSeries({
                        color: fillColor,
                        lineWidth: 1,
                        lastValueVisible: false,
                        priceLineVisible: false
                    });
                    
                    fillLine.setData([
                        { time: chartData[0].time, value: price },
                        { time: currentBarTime, value: price }
                    ]);
                    seriesList.push(fillLine);
                }
                
                // 在价格轴上添加标签
                const midPrice = (channel.high + channel.low) / 2;
                const labelLine = chart.addLineSeries({
                    color: 'rgba(0,0,0,0)',
                    lineWidth: 0,
                    lastValueVisible: false,
                    priceLineVisible: false
                });
                
                labelLine.setData([{ time: currentBarTime, value: midPrice }]);
                
                try {
                    const label = channel.type === 'support' ? 'S' : channel.type === 'resistance' ? 'R' : '—';
                    labelLine.createPriceLine({
                        price: midPrice,
                        color: color,
                        lineWidth: 0,
                        lineStyle: 2,
                        axisLabelVisible: true,
                        title: label
                    });
                } catch (e) {
                    console.warn('   - 无法添加通道标签');
                }
                
                seriesList.push(labelLine);
            });
            
            // 渲染Pivot点（如果启用）
            if (params.show_pivots && srData.pivots && srData.pivots.length > 0) {
                const pivotMarkers = [];
                srData.pivots.forEach(pivot => {
                    pivotMarkers.push({
                        time: pivot.time,
                        position: pivot.type === 'high' ? 'aboveBar' : 'belowBar',
                        color: pivot.type === 'high' ? resistanceColor : supportColor,
                        shape: pivot.type === 'high' ? 'arrowDown' : 'arrowUp',
                        text: pivot.type === 'high' ? 'H' : 'L',
                        size: 0.5
                    });
                });
                
                if (window.candleSeries && pivotMarkers.length > 0) {
                    try {
                        const existingMarkers = window.initialMarkers || [];
                        window.candleSeries.setMarkers([...existingMarkers, ...pivotMarkers]);
                        console.log(`   - 已添加 ${pivotMarkers.length} 个Pivot点标记`);
                    } catch (e) {
                        console.error('   - 添加Pivot标记失败:', e);
                    }
                }
            }
            
            console.log(`✅ [Support Resistance Channels] 渲染完成: ${srData.channels.length} 个通道, ${seriesList.length} 个图形元素`);
            return seriesList;
        }
        
        // ZigZag++ 渲染函数
        function renderZigZag(zzData, chart) {
            console.log('📊 [ZigZag++] 开始渲染');
            
            // 检查是否需要前端计算
            if (!zzData || !zzData.pivots || zzData.pivots.length === 0) {
                console.log('⚙️ [ZigZag++] 数据为空，开始前端计算...');
                const config = INDICATOR_POOL['zigzag'] || {};
                const params = config.params || {};
                zzData = calculateZigZag(chartData, params);
                
                if (!zzData || !zzData.pivots || zzData.pivots.length === 0) {
                    console.error('❌ [ZigZag++] 计算失败或无转折点');
                    return [];
                }
                console.log('✅ [ZigZag++] 前端计算完成');
            }
            
            const seriesList = [];
            const config = INDICATOR_POOL['zigzag'] || {};
            const params = config.params || {};
            
            // 获取颜色配置（A股习惯：红涨绿跌）
            const bullColor = params.bull_color || 'rgba(239, 83, 80, 0.9)';
            const bearColor = params.bear_color || 'rgba(38, 166, 154, 0.9)';
            const lineThickness = params.line_thickness || 2;
            const showLabels = params.show_labels !== false;
            const extendLine = params.extend_line || false;
            const showBackground = params.show_background !== false;
            
            // 1. 渲染ZigZag线条
            if (zzData.lines && zzData.lines.length > 0) {
                zzData.lines.forEach((line, idx) => {
                    const color = line.direction > 0 ? bullColor : bearColor;
                    const isLastLine = idx === zzData.lines.length - 1;
                    
                    const lineSeries = chart.addLineSeries({
                        color: color,
                        lineWidth: lineThickness,
                        lastValueVisible: false,
                        priceLineVisible: false
                    });
                    
                    // 如果是最后一条线且启用延伸，延伸到当前时间
                    const endTime = (isLastLine && extendLine) ? 
                        chartData[chartData.length - 1].time : line.to.time;
                    
                    lineSeries.setData([
                        { time: line.from.time, value: line.from.price },
                        { time: endTime, value: line.to.price }
                    ]);
                    
                    seriesList.push(lineSeries);
                });
                
                console.log(`   - 已绘制 ${zzData.lines.length} 条ZigZag线段`);
            }
            
            // 2. 渲染标签（HH/HL/LH/LL）
            if (showLabels && zzData.pivots && zzData.pivots.length > 0) {
                const labelMarkers = [];
                
                zzData.pivots.forEach(pivot => {
                    if (pivot.label) {
                        const isHigh = pivot.type === 'high';
                        const color = isHigh ? bearColor : bullColor;
                        
                        labelMarkers.push({
                            time: pivot.time,
                            position: isHigh ? 'aboveBar' : 'belowBar',
                            color: color,
                            shape: isHigh ? 'arrowDown' : 'arrowUp',
                            text: pivot.label,
                            size: 1
                        });
                    }
                });
                
                if (window.candleSeries && labelMarkers.length > 0) {
                    try {
                        const existingMarkers = window.initialMarkers || [];
                        const allMarkers = [...existingMarkers, ...labelMarkers];
                        window.candleSeries.setMarkers(allMarkers);
                        
                        // 保存ZigZag标签，以便关闭时清理
                        if (!window.zzMarkers) window.zzMarkers = [];
                        window.zzMarkers = labelMarkers;
                        
                        console.log(`   - 已添加 ${labelMarkers.length} 个结构标签`);
                    } catch (e) {
                        console.error('   - 添加标签失败:', e);
                    }
                }
            }
            
            // 3. 渲染背景颜色（显示当前趋势方向）
            if (showBackground && zzData.direction !== 0) {
                try {
                    const bgTransparency = params.background_transparency || 85;
                    const bgColor = zzData.direction > 0 ? 
                        bullColor.replace(/[\\d\\.]+\\)$/, (bgTransparency / 100) + ')') :
                        bearColor.replace(/[\\d\\.]+\\)$/, (bgTransparency / 100) + ')');
                    
                    // 使用Histogram series创建背景色
                    const bgSeries = chart.addHistogramSeries({
                        color: bgColor,
                        priceFormat: { type: 'price', precision: 2, minMove: 0.01 },
                        priceScaleId: '',
                        lastValueVisible: false,
                        priceLineVisible: false
                    });
                    
                    // 找到最后一个转折点之后的所有K线
                    if (zzData.pivots.length > 0) {
                        const lastPivotIndex = zzData.pivots[zzData.pivots.length - 1].barIndex;
                        const bgData = [];
                        
                        for (let i = lastPivotIndex; i < chartData.length; i++) {
                            const bar = chartData[i];
                            const height = (bar.high - bar.low) * 10;  // 放大高度使背景更明显
                            bgData.push({
                                time: bar.time,
                                value: height,
                                color: bgColor
                            });
                        }
                        
                        if (bgData.length > 0) {
                            bgSeries.setData(bgData);
                            seriesList.push(bgSeries);
                            console.log('   - 已添加趋势背景色');
                        }
                    }
                } catch (e) {
                    console.warn('   - 背景色渲染失败:', e);
                }
            }
            
            console.log(`✅ [ZigZag++] 渲染完成: ${zzData.pivots.length} 个转折点, ${seriesList.length} 个图形元素`);
            return seriesList;
        }
        
        // 全局副图变量
        let mirrorSubchart = null;
        let mirrorCandleSeries = null;
        
        // 前端镜像K线计算函数（JavaScript版本）
        function calculateMirrorData(sourceData) {
            if (!sourceData || sourceData.length === 0) {
                return [];
            }
            
            const mirrorData = [];
            let invertedPrice = sourceData[0].close;
            
            for (let i = 0; i < sourceData.length; i++) {
                const curr = sourceData[i];
                
                if (i === 0) {
                    // 第一根K线保持原样
                    mirrorData.push({
                        time: curr.time,
                        open: invertedPrice,
                        high: curr.high,
                        low: curr.low,
                        close: invertedPrice
                    });
                } else {
                    const prev = sourceData[i - 1];
                    
                    // 计算涨跌幅
                    const pctChange = (curr.close - prev.close) / prev.close;
                    
                    // 翻转后的收盘价
                    invertedPrice = invertedPrice * (1 - pctChange);
                    
                    // 计算开盘、高、低的百分比变化
                    const openPct = (curr.open - prev.close) / prev.close;
                    const highPct = (curr.high - prev.close) / prev.close;
                    const lowPct = (curr.low - prev.close) / prev.close;
                    
                    // 计算镜像OHLC（高低互换）
                    const prevInvertedPrice = mirrorData[i - 1].close;
                    const invertedOpen = prevInvertedPrice * (1 - openPct);
                    const invertedHigh = prevInvertedPrice * (1 - lowPct);  // 高低互换
                    const invertedLow = prevInvertedPrice * (1 - highPct);   // 高低互换
                    
                    mirrorData.push({
                        time: curr.time,
                        open: Math.round(invertedOpen * 100) / 100,
                        high: Math.round(invertedHigh * 100) / 100,
                        low: Math.round(invertedLow * 100) / 100,
                        close: Math.round(invertedPrice * 100) / 100
                    });
                }
            }
            
            return mirrorData;
        }
        
        // 镜像副图渲染函数（支持懒加载）
        function renderMirrorSubchart(mirrorData) {
            console.log('🎯 [镜像副图] 开始渲染');
            
            // 如果数据为空，从主图数据动态计算镜像数据
            if (!mirrorData || !Array.isArray(mirrorData) || mirrorData.length === 0) {
                console.log('⚙️ [镜像副图] 数据为空，开始动态计算...');
                mirrorData = calculateMirrorData(chartData);
                if (!mirrorData || mirrorData.length === 0) {
                    console.error('❌ [镜像副图] 动态计算失败');
                    return [];
                }
                console.log('✅ [镜像副图] 动态计算完成:', mirrorData.length, '根K线');
            }
            
            const subchartContainer = document.getElementById('subchart-container');
            const chartsWrapper = document.getElementById('charts-wrapper');
            
            if (!subchartContainer || !chartsWrapper) {
                console.error('❌ [镜像副图] 容器元素不存在');
                return [];
            }
            
            // 显示副图
            chartsWrapper.classList.add('has-subchart');
            
            // 获取主图配置以保持一致
            const mainChartOptions = {
                width: subchartContainer.clientWidth,
                height: subchartContainer.clientHeight,
                layout: chart.options().layout,
                grid: chart.options().grid,
                crosshair: chart.options().crosshair,
                timeScale: chart.options().timeScale,
                watermark: {
                    visible: true,
                    text: '镜像翻转',
                    fontSize: 14,
                    color: 'rgba(128, 128, 128, 0.15)',
                    horzAlign: 'right',
                    vertAlign: 'bottom'
                },
                autoSize: false
            };
            
            // 创建副图
            const { createChart } = LightweightCharts;
            mirrorSubchart = createChart(subchartContainer, mainChartOptions);
            
            // 添加镜像K线系列（继承主图配色）
            const mainCandleOptions = window.candleSeries.options();
            mirrorCandleSeries = mirrorSubchart.addCandlestickSeries({
                upColor: mainCandleOptions.upColor,
                downColor: mainCandleOptions.downColor,
                borderUpColor: mainCandleOptions.borderUpColor,
                borderDownColor: mainCandleOptions.borderDownColor,
                wickUpColor: mainCandleOptions.wickUpColor,
                wickDownColor: mainCandleOptions.wickDownColor
            });
            
            mirrorCandleSeries.setData(mirrorData);
            
            // 时间轴同步
            syncTimeScales(chart, mirrorSubchart);
            
            // 初始化视图
            mirrorSubchart.timeScale().fitContent();
            
            console.log('✅ [镜像副图] 创建完成');
            return [mirrorSubchart];
        }
        
        // 时间轴同步函数
        function syncTimeScales(mainChart, subChart) {
            console.log('🔗 [同步] 建立时间轴同步');
            
            // 防止循环触发
            let isSyncing = false;
            
            // 主图滚动/缩放 -> 副图同步
            mainChart.timeScale().subscribeVisibleLogicalRangeChange(range => {
                if (isSyncing || !range) return;
                isSyncing = true;
                try {
                    subChart.timeScale().setVisibleLogicalRange(range);
                } catch (e) {
                    console.warn('同步主图到副图失败:', e);
                } finally {
                    setTimeout(() => { isSyncing = false; }, 0);
                }
            });
            
            // 副图滚动/缩放 -> 主图同步
            subChart.timeScale().subscribeVisibleLogicalRangeChange(range => {
                if (isSyncing || !range) return;
                isSyncing = true;
                try {
                    mainChart.timeScale().setVisibleLogicalRange(range);
                } catch (e) {
                    console.warn('同步副图到主图失败:', e);
                } finally {
                    setTimeout(() => { isSyncing = false; }, 0);
                }
            });
            
            console.log('✅ [同步] 时间轴同步已建立');
        }
        
        // 指标系列管理
        const indicatorSeries = new Map();
        let userPreferences = {};
        
        // 初始化指标池
        function initIndicatorPool() {
            console.log('🎬 [初始化] 指标池');
            
            // 检查背离检测数据
            if (INDICATOR_POOL['divergence_detector']) {
                const divConfig = INDICATOR_POOL['divergence_detector'];
                console.log('📊 [初始化] 背离检测数据:', divConfig.data ? divConfig.data.length : 0, '组');
            }
            
            loadUserPreferences();
            
            Object.keys(INDICATOR_POOL).forEach(id => {
                const config = INDICATOR_POOL[id];
                const enabled = userPreferences[id] !== undefined 
                    ? userPreferences[id] 
                    : config.enabled;
                
                if (enabled) {
                    enableIndicator(id, false);
                }
                
                const checkbox = document.querySelector('[data-id="' + id + '"] input[type="checkbox"]');
                if (checkbox) checkbox.checked = enabled;
            });
            
            updateIndicatorCount();
        }
        
        // 切换指标面板
        function toggleIndicatorPanel() {
            const panel = document.getElementById('indicator-panel');
            const overlay = document.getElementById('panel-overlay');
            const isOpen = panel.classList.contains('open');
            
            if (isOpen) {
                panel.classList.remove('open');
                overlay.classList.remove('show');
            } else {
                panel.classList.add('open');
                overlay.classList.add('show');
            }
        }
        
        // 快捷切换镜像视角（点击股票名称）
        function toggleMirrorView() {
            const mirrorId = 'mirror_candle';
            const checkbox = document.querySelector('[data-id="' + mirrorId + '"] input[type="checkbox"]');
            const stockName = document.getElementById('stockName');
            
            if (!checkbox) {
                console.warn('镜像翻转开关未找到');
                return;
            }
            
            // 切换状态
            const newState = !checkbox.checked;
            checkbox.checked = newState;
            
            // 更新股票名称样式
            if (newState) {
                stockName.classList.add('mirror-active');
                console.log('🔄 切换到镜像视角');
            } else {
                stockName.classList.remove('mirror-active');
                console.log('📊 切换到正常视角');
            }
            
            // 触发指标切换
            toggleIndicator(mirrorId, newState);
        }
        
        // 开启指标（⚡ 支持前端动态计算）
        function enableIndicator(id, savePreference = true) {
            const config = INDICATOR_POOL[id];
            if (!config) {
                console.error('指标不存在:', id);
                return;
            }
            
            if (typeof chart === 'undefined') {
                console.warn('图表尚未创建，无法添加指标:', id);
                return;
            }
            
            if (indicatorSeries.has(id)) {
                console.log('指标已存在，跳过:', config.name);
                return;
            }
            
            // ⚡ 如果data为null，则前端动态计算
            if (!config.data && window.IndicatorCalculator) {
                console.log('⚡ [动态计算] 指标:', config.name, '参数:', config.params);
                try {
                    const calculatedData = window.IndicatorCalculator.calculate(id, window.candleData, config.params || {});
                    if (calculatedData) {
                        config.data = calculatedData;
                        console.log('✅ [动态计算] 完成:', config.name, '- 数据点:', 
                            Array.isArray(calculatedData) ? calculatedData.length : '对象');
                    } else {
                        console.warn('⚠️ [动态计算] 失败:', config.name, '- 计算结果为空');
                    }
                } catch (error) {
                    console.error('❌ [动态计算] 出错:', config.name, error);
                }
            }
            
            if (config.isComposite) {
                console.log('启用复合指标:', config.name);
                config.subIndicators.forEach(subId => enableIndicator(subId, false));
            } else if (config.renderType === 'overlay' && config.renderFunction) {
                // overlay类型指标需要自定义渲染
                console.log('渲染覆盖层指标:', config.name);
                if (config.renderFunction === 'renderPivotOrderBlocks') {
                    if (!config.data || config.data.length === 0) {
                        console.warn('⚠️ 支撑和阻力区域：当前股票数据未生成订单块（可能走势较平缓，缺少明显的高低点转折）');
                        indicatorSeries.set(id, []);
                    } else {
                        const elements = renderPivotOrderBlocks(config.data, chart);
                        indicatorSeries.set(id, elements);
                        console.log('✅ 覆盖层指标已渲染:', config.name, '- 生成', config.data.length, '个区域');
                    }
                } else if (config.renderFunction === 'renderVolumeProfilePivot') {
                    if (!config.data || (config.data.profiles && config.data.profiles.length === 0)) {
                        console.warn('⚠️ 成交量分布：数据不足，需要更多K线数据才能计算');
                        indicatorSeries.set(id, []);
                    } else {
                        const elements = renderVolumeProfilePivot(config.data, chart);
                        indicatorSeries.set(id, elements);
                        console.log('✅ 覆盖层指标已渲染:', config.name);
                    }
                } else if (config.renderFunction === 'renderDivergence') {
                    console.log('🎯 [启用指标] 背离检测 - 数据:', config.data ? config.data.length : 0, '组');
                    const elements = renderDivergence(config.data, chart);
                    indicatorSeries.set(id, elements);
                    console.log('✅ [启用指标] 背离检测渲染完成');
                } else if (config.renderFunction === 'renderSmartMoneyConcepts') {
                    console.log('🎯 [启用指标] 聪明钱概念');
                    const elements = renderSmartMoneyConcepts(config.data, chart);
                    indicatorSeries.set(id, elements);
                    console.log('✅ [启用指标] 聪明钱概念渲染完成');
                } else if (config.renderFunction === 'renderSupportResistanceChannels') {
                    console.log('🎯 [启用指标] 支撑阻力通道');
                    const elements = renderSupportResistanceChannels(config.data, chart);
                    indicatorSeries.set(id, elements);
                    console.log('✅ [启用指标] 支撑阻力通道渲染完成');
                } else if (config.renderFunction === 'renderZigZag') {
                    console.log('🎯 [启用指标] ZigZag++');
                    const elements = renderZigZag(config.data, chart);
                    indicatorSeries.set(id, elements);
                    console.log('✅ [启用指标] ZigZag++渲染完成');
                }
            } else if (config.renderType === 'subchart' && config.renderFunction) {
                // subchart类型指标需要自定义渲染
                console.log('渲染副图指标:', config.name);
                if (config.renderFunction === 'renderMirrorSubchart') {
                    console.log('🎯 [启用指标] 镜像翻转 - 数据:', config.data ? config.data.length : 0, '根K线');
                    const elements = renderMirrorSubchart(config.data);
                    indicatorSeries.set(id, elements);
                    console.log('✅ [启用指标] 镜像翻转渲染完成');
                }
            } else if (config.renderType === 'overlay') {
                // overlay类型指标没有渲染函数，仅标记为已启用
                console.log('⚠️ 覆盖层指标无渲染函数:', config.name);
                indicatorSeries.set(id, 'overlay');
            } else if (config.data && (Array.isArray(config.data) ? config.data.length > 0 : true)) {
                if (config.renderType === 'line') {
                    console.log('添加线条指标:', config.name, '颜色:', config.color, '数据点:', config.data.length);
                    const series = chart.addLineSeries({
                        color: config.color || '#888888',
                        lineWidth: 2,
                        title: '',
                        priceLineVisible: false,
                        lastValueVisible: false,
                    });
                    series.setData(config.data);
                    indicatorSeries.set(id, series);
                    console.log('✅ 指标已添加到图表:', config.name);
                }
            } else {
                console.warn('指标无数据或渲染类型不支持:', config.name, 'renderType:', config.renderType);
            }
            
            if (savePreference) {
                userPreferences[id] = true;
                saveUserPreferences();
                updateIndicatorCount();
            }
        }
        
        // 关闭指标
        function disableIndicator(id, savePreference = true) {
            const config = INDICATOR_POOL[id];
            if (!config) {
                console.error('指标不存在:', id);
                return;
            }
            
            if (config.isComposite) {
                console.log('禁用复合指标:', config.name);
                config.subIndicators.forEach(subId => disableIndicator(subId, false));
            } else if (config.renderType === 'overlay') {
                // overlay类型指标需要移除DOM元素或系列
                const elements = indicatorSeries.get(id);
                if (elements && Array.isArray(elements)) {
                    console.log('移除覆盖层指标:', config.name, '元素/系列数量:', elements.length);
                    elements.forEach(elem => {
                        if (elem && elem.parentNode) {
                            // DOM元素
                            elem.parentNode.removeChild(elem);
                        } else if (elem && typeof elem === 'object' && 'setData' in elem) {
                            // 图表系列
                            chart.removeSeries(elem);
                        }
                    });
                }
                
                // 如果是背离检测，只清除背离标签（保留买卖标签）
                if (id === 'divergence_detector' && window.candleSeries) {
                    try {
                        // 恢复初始买卖标记
                        const buySellMarkers = window.initialMarkers || [];
                        window.candleSeries.setMarkers(buySellMarkers);
                        console.log('✅ [禁用指标] 背离检测 - 恢复买卖信号', buySellMarkers.length, '个');
                    } catch (e) {
                        console.error('❌ [禁用指标] 清除markers失败:', e);
                    }
                }
                
                // 如果是聪明钱概念，清除SMC标签（保留买卖标签）
                if (id === 'smart_money_concepts' && window.candleSeries) {
                    try {
                        // 清除SMC标签数据
                        if (window.smcMarkers) {
                            window.smcMarkers = {
                                structure: [],
                                internal: [],
                                equal: []
                            };
                        }
                        // 恢复初始买卖标记（策略的买卖点）
                        const buySellMarkers = window.initialMarkers || [];
                        window.candleSeries.setMarkers(buySellMarkers);
                        console.log('✅ [禁用指标] 聪明钱概念 - 已清除SMC标签，恢复买卖信号', buySellMarkers.length, '个');
                    } catch (e) {
                        console.error('❌ [禁用指标] 清除SMC标签失败:', e);
                    }
                }
                
                // 如果是ZigZag++，清除ZZ标签（保留买卖标签）
                if (id === 'zigzag' && window.candleSeries) {
                    try {
                        // 清除ZigZag标签数据
                        if (window.zzMarkers) {
                            window.zzMarkers = [];
                        }
                        // 恢复初始买卖标记（策略的买卖点）
                        const buySellMarkers = window.initialMarkers || [];
                        window.candleSeries.setMarkers(buySellMarkers);
                        console.log('✅ [禁用指标] ZigZag++ - 已清除ZZ标签，恢复买卖信号', buySellMarkers.length, '个');
                    } catch (e) {
                        console.error('❌ [禁用指标] 清除ZZ标签失败:', e);
                    }
                }
                
                indicatorSeries.delete(id);
                console.log('✅ 覆盖层指标已移除:', config.name);
            } else if (config.renderType === 'subchart') {
                // subchart类型指标需要移除副图
                console.log('移除副图指标:', config.name);
                if (mirrorSubchart) {
                    try {
                        mirrorSubchart.remove();
                        mirrorSubchart = null;
                        mirrorCandleSeries = null;
                        
                        // 隐藏副图容器
                        const chartsWrapper = document.getElementById('charts-wrapper');
                        if (chartsWrapper) {
                            chartsWrapper.classList.remove('has-subchart');
                        }
                        
                        console.log('✅ 副图已移除:', config.name);
                    } catch (e) {
                        console.error('❌ 移除副图失败:', e);
                    }
                }
                indicatorSeries.delete(id);
            } else {
                const series = indicatorSeries.get(id);
                if (series) {
                    console.log('移除指标:', config.name);
                    chart.removeSeries(series);
                    indicatorSeries.delete(id);
                    console.log('✅ 指标已从图表移除:', config.name);
                } else {
                    console.warn('指标未找到，无法移除:', config.name);
                }
            }
            
            if (savePreference) {
                userPreferences[id] = false;
                saveUserPreferences();
                updateIndicatorCount();
            }
        }
        
        // 切换指标
        function toggleIndicator(id, enabled) {
            if (enabled) {
                enableIndicator(id);
            } else {
                disableIndicator(id);
            }
        }
        
        // 指标计数功能（保留函数以保持兼容性）
        function updateIndicatorCount() {
            // 已弃用，不再显示数量统计
        }
        
        // 保存/加载用户偏好
        function saveUserPreferences() {
            try {
                localStorage.setItem('indicator_preferences', JSON.stringify(userPreferences));
            } catch (e) {
                console.error('保存指标偏好失败:', e);
            }
        }
        
        function loadUserPreferences() {
            try {
                const saved = localStorage.getItem('indicator_preferences');
                if (saved) {
                    userPreferences = JSON.parse(saved);
                }
            } catch (e) {
                console.error('加载指标偏好失败:', e);
                userPreferences = {};
            }
        }
        
        // 延迟初始化指标池，确保 candleSeries 和 initialMarkers 已完全创建
        setTimeout(function() {
            if (window.candleSeries && window.initialMarkers !== undefined) {
                console.log('✅ [初始化] candleSeries 和 initialMarkers 已就绪');
        initIndicatorPool();
            } else {
                console.warn('⚠️ [初始化] 等待 candleSeries 就绪...');
                setTimeout(initIndicatorPool, 500);
            }
        }, 100);
        """
    
    @classmethod
    def _generate_indicator_panel_html(cls) -> str:
        """生成指标池面板HTML"""
        from app.trading.indicators.indicator_registry import IndicatorRegistry
        
        all_indicators = IndicatorRegistry.get_all()
        
        # 定义哪些指标应该显示给用户（隐藏内部使用的指标）
        visible_indicators = [
            'ma_combo',                       # 移动均线组合
            'vegas_tunnel',                   # Vegas隧道
            'zigzag',                         # ZigZag++（新）
            'volume_profile_pivot',           # Volume Profile
            'support_resistance_channels',    # 支撑阻力通道
            'divergence_detector',            # 背离检测
            'mirror_candle',                  # 镜像翻转
            'smart_money_concepts',           # 聪明钱概念
        ]
        
        # 按分类分组（只包含可见指标）
        by_category = {}
        for ind_id in visible_indicators:
            ind = all_indicators.get(ind_id)
            if ind:
                if ind.category not in by_category:
                    by_category[ind.category] = []
                by_category[ind.category].append(ind)
        
        html = """
        <div class="panel-header">
            <h3>分析工具</h3>
            <button class="close-btn" onclick="toggleIndicatorPanel()">×</button>
        </div>
        <div class="panel-body">
        """
        
        # 趋势分析
        if 'trend' in by_category:
            html += '<div class="indicator-category">'
            html += '<div class="category-header">趋势分析</div>'
            html += '<div class="indicator-list">'
            for ind in by_category['trend']:
                html += cls._generate_indicator_item_html(ind)
            html += '</div></div>'
        
        # 成交量分析
        if 'volume' in by_category:
            html += '<div class="indicator-category">'
            html += '<div class="category-header">成交量分析</div>'
            html += '<div class="indicator-list">'
            for ind in by_category['volume']:
                html += cls._generate_indicator_item_html(ind)
            html += '</div></div>'
        
        # 支撑阻力
        if 'support_resistance' in by_category:
            html += '<div class="indicator-category">'
            html += '<div class="category-header">支撑阻力分析</div>'
            html += '<div class="indicator-list">'
            for ind in by_category['support_resistance']:
                html += cls._generate_indicator_item_html(ind)
            html += '</div></div>'
        
        # 振荡分析
        if 'oscillator' in by_category:
            html += '<div class="indicator-category">'
            html += '<div class="category-header">振荡分析</div>'
            html += '<div class="indicator-list">'
            for ind in by_category['oscillator']:
                html += cls._generate_indicator_item_html(ind)
            html += '</div></div>'
        
        # 副图
        if 'subchart' in by_category:
            html += '<div class="indicator-category">'
            html += '<div class="category-header">逆向分析</div>'
            html += '<div class="indicator-list">'
            for ind in by_category['subchart']:
                html += cls._generate_indicator_item_html(ind)
            html += '</div></div>'
        
        html += '</div>'  # panel-body
        html += '<div class="panel-footer">偏好设置已自动保存</div>'
        return html
    
    @classmethod
    def _generate_indicator_item_html(cls, indicator) -> str:
        """生成单个指标项HTML（移动端风格复选框）"""
        checked = 'checked' if indicator.enabled_by_default else ''
        
        # 处理复合指标的颜色显示
        color_badges_html = ''
        if indicator.is_composite and indicator.sub_indicators:
            from app.trading.indicators.indicator_registry import IndicatorRegistry
            color_badges_html = '<div class="color-badges">'
            for sub_id in indicator.sub_indicators:
                sub_ind = IndicatorRegistry.get(sub_id)
                if sub_ind and sub_ind.color:
                    color_badges_html += f'<span class="color-dot" style="background: {sub_ind.color};"></span>'
            color_badges_html += '</div>'
        elif indicator.color:
            color_badges_html = f'<div class="color-badges"><span class="color-dot" style="background: {indicator.color};"></span></div>'
        
        return f"""
        <div class="indicator-item" data-id="{indicator.id}">
            <label class="indicator-checkbox">
                <input type="checkbox" {checked} onchange="toggleIndicator('{indicator.id}', this.checked)">
                <span class="checkmark"></span>
                <span class="indicator-name">{indicator.name}</span>
                {color_badges_html}
            </label>
        </div>
        """

