# -*- coding: utf-8 -*-
"""
指标池混入类 - 为图表策略添加指标池功能
"""
import json
from typing import Any


class IndicatorPoolMixin:
    """指标池混入类，提供指标池相关的HTML和JavaScript生成方法"""
    
    @classmethod
    def _generate_indicator_pool_scripts(cls, ema6_data, ema12_data, ema18_data, 
                                        ema144_data, ema169_data, volume_profile_data, 
                                        pivot_order_blocks_data=None) -> str:
        """生成指标池完整的JavaScript代码（包括配置和逻辑）"""
        indicator_config = cls._generate_indicator_config_js(
            ema6_data, ema12_data, ema18_data, ema144_data, ema169_data, 
            volume_profile_data, pivot_order_blocks_data
        )
        indicator_logic = cls._generate_indicator_pool_logic_js()
        return f"\n{indicator_config}\n{indicator_logic}\n"
    
    @classmethod
    def _generate_indicator_config_js(cls, ema6_data, ema12_data, ema18_data, 
                                      ema144_data, ema169_data, volume_profile_data, 
                                      pivot_order_blocks_data=None) -> str:
        """生成指标配置JavaScript"""
        from app.indicators.indicator_registry import IndicatorRegistry
        
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
            'pivot_order_blocks': pivot_order_blocks_data if pivot_order_blocks_data is not None else []
        }
        
        for ind_id, ind_def in all_indicators.items():
            data = data_map.get(ind_id)
            
            # 为特殊指标添加渲染函数代码
            render_function = None
            if ind_id == 'pivot_order_blocks' and data:
                render_function = 'renderPivotOrderBlocks'
            elif ind_id == 'volume_profile_pivot' and data:
                render_function = 'renderVolumeProfilePivot'
            
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
        
        // 指标系列管理
        const indicatorSeries = new Map();
        let userPreferences = {};
        
        // 初始化指标池
        function initIndicatorPool() {
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
        
        // 开启指标
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
            
            if (config.isComposite) {
                console.log('启用复合指标:', config.name);
                config.subIndicators.forEach(subId => enableIndicator(subId, false));
            } else if (config.renderType === 'overlay' && config.renderFunction) {
                // overlay类型指标需要自定义渲染
                console.log('渲染覆盖层指标:', config.name);
                if (config.renderFunction === 'renderPivotOrderBlocks') {
                    const elements = renderPivotOrderBlocks(config.data, chart);
                    indicatorSeries.set(id, elements);
                    console.log('✅ 覆盖层指标已渲染:', config.name);
                } else if (config.renderFunction === 'renderVolumeProfilePivot') {
                    const elements = renderVolumeProfilePivot(config.data, chart);
                    indicatorSeries.set(id, elements);
                    console.log('✅ 覆盖层指标已渲染:', config.name);
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
                indicatorSeries.delete(id);
                console.log('✅ 覆盖层指标已移除:', config.name);
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
        
        // 快速操作
        function enableAllIndicators() {
            Object.keys(INDICATOR_POOL).forEach(id => {
                enableIndicator(id, false);
                const checkbox = document.querySelector('[data-id="' + id + '"] input[type="checkbox"]');
                if (checkbox) checkbox.checked = true;
            });
            saveUserPreferences();
            updateIndicatorCount();
        }
        
        function disableAllIndicators() {
            Object.keys(INDICATOR_POOL).forEach(id => {
                disableIndicator(id, false);
                const checkbox = document.querySelector('[data-id="' + id + '"] input[type="checkbox"]');
                if (checkbox) checkbox.checked = false;
            });
            saveUserPreferences();
            updateIndicatorCount();
        }
        
        function resetToDefault() {
            Object.keys(INDICATOR_POOL).forEach(id => {
                const config = INDICATOR_POOL[id];
                const enabled = config.enabled;
                
                if (enabled) {
                    enableIndicator(id, false);
                } else {
                    disableIndicator(id, false);
                }
                
                const checkbox = document.querySelector('[data-id="' + id + '"] input[type="checkbox"]');
                if (checkbox) checkbox.checked = enabled;
            });
            saveUserPreferences();
            updateIndicatorCount();
        }
        
        // 更新指标计数（不再显示，保留函数避免报错）
        function updateIndicatorCount() {
            // 数量统计已隐藏
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
        
        // 初始化指标池（在INDICATOR_POOL定义之后立即执行）
        initIndicatorPool();
        """
    
    @classmethod
    def _generate_indicator_panel_html(cls) -> str:
        """生成指标池面板HTML"""
        from app.indicators.indicator_registry import IndicatorRegistry
        
        all_indicators = IndicatorRegistry.get_all()
        
        # 定义哪些指标应该显示给用户（隐藏内部使用的指标）
        visible_indicators = [
            'ma_combo',           # 移动均线组合
            'vegas_tunnel',       # Vegas隧道
            'volume_profile_pivot',  # Volume Profile
            'pivot_order_blocks'  # Pivot Order Blocks
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
            <div class="quick-actions">
                <button onclick="enableAllIndicators()">全部开启</button>
                <button onclick="disableAllIndicators()">全部关闭</button>
                <button onclick="resetToDefault()">恢复默认</button>
            </div>
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
            html += '<div class="category-header">支撑阻力</div>'
            html += '<div class="indicator-list">'
            for ind in by_category['support_resistance']:
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
            from app.indicators.indicator_registry import IndicatorRegistry
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

