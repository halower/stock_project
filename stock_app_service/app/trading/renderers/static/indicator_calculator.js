/**
 * 前端指标计算引擎
 * 
 * 将所有指标计算逻辑移到前端，实现TradingView式的按需计算
 * 只需要传输OHLCV原始数据，指标在浏览器中实时计算
 * 
 * 优势：
 * 1. 服务端响应速度快（无需计算指标）
 * 2. 支持任意数量的指标（不影响加载速度）
 * 3. 用户体验与TradingView一致
 */

// ============================================================================
// 工具函数
// ============================================================================

/**
 * 计算EMA（指数移动平均）
 * 与Pandas ewm(span=period, adjust=False)行为完全一致
 * 
 * @param {Array<number>} data - 价格数据
 * @param {number} period - 周期
 * @returns {Array<number>} EMA值数组
 */
function calculateEMA(data, period) {
    const result = new Array(data.length);
    const alpha = 2 / (period + 1);
    
    // ✅ 修复：从第一个值开始计算（与Pandas ewm一致）
    result[0] = data[0];
    
    // ✅ 使用标准EMA公式：EMA[i] = alpha * data[i] + (1 - alpha) * EMA[i-1]
    for (let i = 1; i < data.length; i++) {
        result[i] = alpha * data[i] + (1 - alpha) * result[i - 1];
    }
    
    return result;
}

/**
 * 计算SMA（简单移动平均）
 * @param {Array<number>} data - 价格数据
 * @param {number} period - 周期
 * @returns {Array<number>} SMA值数组
 */
function calculateSMA(data, period) {
    const result = new Array(data.length);
    
    for (let i = 0; i < data.length; i++) {
        if (i < period - 1) {
            result[i] = NaN;
            continue;
        }
        
        let sum = 0;
        for (let j = 0; j < period; j++) {
            sum += data[i - j];
        }
        result[i] = sum / period;
    }
    
    return result;
}

/**
 * 找到Pivot High点
 * @param {Array} candleData - K线数据
 * @param {number} leftBars - 左侧K线数量
 * @param {number} rightBars - 右侧K线数量
 * @returns {Array<{index: number, price: number}>} Pivot High点数组
 */
function findPivotHighs(candleData, leftBars, rightBars) {
    const pivotHighs = [];
    
    for (let i = leftBars; i < candleData.length - rightBars; i++) {
        const centerHigh = candleData[i].high;
        let isPivot = true;
        
        // 检查左侧
        for (let j = i - leftBars; j < i; j++) {
            if (candleData[j].high >= centerHigh) {
                isPivot = false;
                break;
            }
        }
        
        if (!isPivot) continue;
        
        // 检查右侧
        for (let j = i + 1; j <= i + rightBars; j++) {
            if (candleData[j].high >= centerHigh) {
                isPivot = false;
                break;
            }
        }
        
        if (isPivot) {
            pivotHighs.push({ index: i, price: centerHigh });
        }
    }
    
    return pivotHighs;
}

/**
 * 找到Pivot Low点
 * @param {Array} candleData - K线数据
 * @param {number} leftBars - 左侧K线数量
 * @param {number} rightBars - 右侧K线数量
 * @returns {Array<{index: number, price: number}>} Pivot Low点数组
 */
function findPivotLows(candleData, leftBars, rightBars) {
    const pivotLows = [];
    
    for (let i = leftBars; i < candleData.length - rightBars; i++) {
        const centerLow = candleData[i].low;
        let isPivot = true;
        
        // 检查左侧
        for (let j = i - leftBars; j < i; j++) {
            if (candleData[j].low <= centerLow) {
                isPivot = false;
                break;
            }
        }
        
        if (!isPivot) continue;
        
        // 检查右侧
        for (let j = i + 1; j <= i + rightBars; j++) {
            if (candleData[j].low <= centerLow) {
                isPivot = false;
                break;
            }
        }
        
        if (isPivot) {
            pivotLows.push({ index: i, price: centerLow });
        }
    }
    
    return pivotLows;
}

// ============================================================================
// 指标计算函数
// ============================================================================

/**
 * 计算EMA指标（统一接口）
 * @param {Array} candleData - K线数据 [{time, open, high, low, close, volume}]
 * @param {object} params - 参数 {period: number}
 * @returns {Array<{time: string, value: number}>} 指标数据
 */
function calculateIndicatorEMA(candleData, params = {}) {
    const period = params.period || 12;
    const closes = candleData.map(d => d.close);
    const emaValues = calculateEMA(closes, period);
    
    return candleData.map((d, i) => ({
        time: d.time,
        value: emaValues[i]
    })).filter(d => !isNaN(d.value));
}

/**
 * 计算镜像K线
 * @param {Array} candleData - K线数据
 * @param {object} params - 参数（当前无参数）
 * @returns {Array<{time, open, high, low, close}>} 镜像K线数据
 */
function calculateMirrorCandle(candleData, params = {}) {
    if (!candleData || candleData.length === 0) {
        return [];
    }
    
    const startPrice = candleData[0].close;
    const mirrorData = [];
    
    let prevInvertedClose = startPrice;
    
    for (let i = 0; i < candleData.length; i++) {
        const curr = candleData[i];
        
        if (i === 0) {
            // 第一根K线保持不变
            mirrorData.push({
                time: curr.time,
                open: startPrice,
                high: curr.high,
                low: curr.low,
                close: startPrice
            });
            continue;
        }
        
        const prev = candleData[i - 1];
        
        if (prev.close === 0) {
            mirrorData.push({
                time: curr.time,
                open: prevInvertedClose,
                high: prevInvertedClose,
                low: prevInvertedClose,
                close: prevInvertedClose
            });
            continue;
        }
        
        // 计算百分比变化
        const closePct = (curr.close - prev.close) / prev.close;
        const openPct = (curr.open - prev.close) / prev.close;
        const highPct = (curr.high - prev.close) / prev.close;
        const lowPct = (curr.low - prev.close) / prev.close;
        
        // 镜像计算（涨跌反转）
        const invertedClose = prevInvertedClose * (1 - closePct);
        const invertedOpen = prevInvertedClose * (1 - openPct);
        const invertedHigh = prevInvertedClose * (1 - lowPct);  // 高低互换
        const invertedLow = prevInvertedClose * (1 - highPct);   // 高低互换
        
        mirrorData.push({
            time: curr.time,
            open: Math.round(invertedOpen * 100) / 100,
            high: Math.round(invertedHigh * 100) / 100,
            low: Math.round(invertedLow * 100) / 100,
            close: Math.round(invertedClose * 100) / 100
        });
        
        prevInvertedClose = invertedClose;
    }
    
    return mirrorData;
}

/**
 * 计算支撑和阻力区域（Pivot Order Blocks）
 * @param {Array} candleData - K线数据
 * @param {object} params - 参数
 * @returns {Array<{type, price_high, price_low, start_time, end_time, strength}>}
 */
function calculatePivotOrderBlocks(candleData, params = {}) {
    const {
        left = 15,
        right = 8,
        box_count = 2,
        percentage_change = 6.0,
        box_extend_to_end = true
    } = params;
    
    if (!candleData || candleData.length < left + right + 1) {
        return [];
    }
    
    // 找到Pivot High和Pivot Low
    const pivotHighs = findPivotHighs(candleData, left, right);
    const pivotLows = findPivotLows(candleData, left, right);
    
    // 合并并排序
    const allPivots = [
        ...pivotHighs.map(p => ({ ...p, type: 'high' })),
        ...pivotLows.map(p => ({ ...p, type: 'low' }))
    ].sort((a, b) => a.index - b.index);
    
    if (allPivots.length < 2) {
        return [];
    }
    
    const orderBlocks = [];
    
    for (let i = 0; i < allPivots.length - 1; i++) {
        const current = allPivots[i];
        const next = allPivots[i + 1];
        
        // 只在pivot类型变化时生成订单块
        if (current.type === next.type) continue;
        
        // 检查价格变化是否足够大
        const priceChangePct = Math.abs(next.price - current.price) / current.price * 100;
        if (priceChangePct < percentage_change) continue;
        
        // 找到订单块范围
        let blockHigh, blockLow;
        if (current.type === 'high') {
            // 阻力订单块 - 找pivot前最后一根阳线
            [blockHigh, blockLow] = findResistanceBlock(candleData, current.index);
        } else {
            // 支撑订单块 - 找pivot前最后一根阴线
            [blockHigh, blockLow] = findSupportBlock(candleData, current.index);
        }
        
        // 计算强度
        const strength = Math.min(priceChangePct / 10.0, 1.0);
        
        const endIndex = box_extend_to_end ? candleData.length - 1 : next.index;
        
        orderBlocks.push({
            type: current.type === 'high' ? 'resistance' : 'support',
            price_high: blockHigh,
            price_low: blockLow,
            start_time: candleData[current.index].time,
            end_time: candleData[endIndex].time,
            start_index: current.index,
            end_index: endIndex,
            strength: strength
        });
    }
    
    // 按强度排序，只保留最强的
    orderBlocks.sort((a, b) => b.strength - a.strength);
    return orderBlocks.slice(0, box_count);
}

/**
 * 找阻力订单块（pivot high前的最后一根阳线）
 */
function findResistanceBlock(candleData, pivotIdx) {
    for (let i = pivotIdx; i >= Math.max(0, pivotIdx - 10); i--) {
        const candle = candleData[i];
        if (candle.close >= candle.open) {
            // 阳线
            return [
                Math.max(candle.open, candle.close),
                Math.min(candle.open, candle.close)
            ];
        }
    }
    // 没找到，使用pivot点K线
    const candle = candleData[pivotIdx];
    return [candle.high, candle.low];
}

/**
 * 找支撑订单块（pivot low前的最后一根阴线）
 */
function findSupportBlock(candleData, pivotIdx) {
    for (let i = pivotIdx; i >= Math.max(0, pivotIdx - 10); i--) {
        const candle = candleData[i];
        if (candle.close < candle.open) {
            // 阴线
            return [
                Math.max(candle.open, candle.close),
                Math.min(candle.open, candle.close)
            ];
        }
    }
    // 没找到，使用pivot点K线
    const candle = candleData[pivotIdx];
    return [candle.high, candle.low];
}

/**
 * 计算成交量分布（Volume Profile Pivot Anchored）
 * @param {Array} candleData - K线数据
 * @param {object} params - 参数
 * @returns {Array} Volume Profile数据
 */
function calculateVolumeProfile(candleData, params = {}) {
    const {
        pivot_length = 20,
        profile_levels = 25,
        value_area_percent = 68.0,
        profile_width = 0.30
    } = params;
    
    if (!candleData || candleData.length < pivot_length * 2 + 1) {
        return [];
    }
    
    // 找到Pivot点
    const pivotHighs = findPivotHighs(candleData, pivot_length, pivot_length);
    const pivotLows = findPivotLows(candleData, pivot_length, pivot_length);
    
    // 合并并排序
    const allPivots = [
        ...pivotHighs.map(p => ({ ...p, type: 'high' })),
        ...pivotLows.map(p => ({ ...p, type: 'low' }))
    ].sort((a, b) => a.index - b.index);
    
    if (allPivots.length < 2) {
        return [];
    }
    
    const volumeProfiles = [];
    
    // 在每两个pivot点之间计算volume profile
    for (let i = 0; i < allPivots.length - 1; i++) {
        const startIdx = allPivots[i].index - pivot_length;
        const endIdx = allPivots[i + 1].index - pivot_length;
        
        if (startIdx < 0 || endIdx >= candleData.length) continue;
        
        const profile = calculateProfileForRange(
            candleData, startIdx, endIdx, profile_levels, value_area_percent, profile_width
        );
        
        if (profile) {
            volumeProfiles.push(profile);
        }
    }
    
    // 最后一个pivot到当前的profile
    if (allPivots.length > 0) {
        const startIdx = allPivots[allPivots.length - 1].index - pivot_length;
        const endIdx = candleData.length - 1;
        
        if (startIdx >= 0 && endIdx - startIdx > 0) {
            const profile = calculateProfileForRange(
                candleData, startIdx, endIdx, profile_levels, value_area_percent, profile_width
            );
            if (profile) {
                profile.is_developing = true;
                volumeProfiles.push(profile);
            }
        }
    }
    
    return volumeProfiles;
}

/**
 * 为指定区间计算Volume Profile
 */
function calculateProfileForRange(candleData, startIdx, endIdx, profileLevels, valueAreaPercent, profileWidth) {
    if (startIdx < 0 || endIdx >= candleData.length || startIdx >= endIdx) {
        return null;
    }
    
    const rangeData = candleData.slice(startIdx, endIdx + 1);
    
    // 获取价格范围
    const priceHigh = Math.max(...rangeData.map(d => d.high));
    const priceLow = Math.min(...rangeData.map(d => d.low));
    const totalVolume = rangeData.reduce((sum, d) => sum + d.volume, 0);
    
    if (priceHigh <= priceLow) return null;
    
    const priceStep = (priceHigh - priceLow) / profileLevels;
    if (priceStep <= 0) return null;
    
    // 初始化成交量数组
    const volumeStorage = new Array(profileLevels + 1).fill(0);
    
    // 分配成交量到各价格级别
    for (const candle of rangeData) {
        const barHigh = candle.high;
        const barLow = candle.low;
        const barVolume = candle.volume;
        
        if (!barVolume || barVolume <= 0) continue;
        
        for (let level = 0; level < profileLevels; level++) {
            const levelLow = priceLow + level * priceStep;
            const levelHigh = priceLow + (level + 1) * priceStep;
            
            // K线与该级别有交集
            if (barHigh >= levelLow && barLow < levelHigh) {
                const volumePortion = barHigh > barLow 
                    ? barVolume * priceStep / (barHigh - barLow)
                    : barVolume;
                volumeStorage[level] += volumePortion;
            }
        }
    }
    
    // 找到POC
    const pocLevel = volumeStorage.indexOf(Math.max(...volumeStorage));
    const pocPrice = priceLow + (pocLevel + 0.5) * priceStep;
    
    // 计算Value Area
    const targetVolume = volumeStorage.reduce((a, b) => a + b, 0) * (valueAreaPercent / 100);
    let valueAreaVolume = volumeStorage[pocLevel];
    let levelAbovePoc = pocLevel;
    let levelBelowPoc = pocLevel;
    
    while (valueAreaVolume < targetVolume && (levelAbovePoc < profileLevels - 1 || levelBelowPoc > 0)) {
        const volumeAbove = levelAbovePoc < profileLevels - 1 ? volumeStorage[levelAbovePoc + 1] : 0;
        const volumeBelow = levelBelowPoc > 0 ? volumeStorage[levelBelowPoc - 1] : 0;
        
        if (volumeAbove === 0 && volumeBelow === 0) break;
        
        if (volumeAbove >= volumeBelow) {
            valueAreaVolume += volumeAbove;
            levelAbovePoc++;
        } else {
            valueAreaVolume += volumeBelow;
            levelBelowPoc--;
        }
    }
    
    const vahPrice = priceLow + (levelAbovePoc + 1.0) * priceStep;
    const valPrice = priceLow + levelBelowPoc * priceStep;
    
    // 构建profile数据
    const maxVolume = Math.max(...volumeStorage);
    const profileData = [];
    
    for (let level = 0; level < profileLevels; level++) {
        const volumePercent = maxVolume > 0 ? volumeStorage[level] / maxVolume : 0;
        
        profileData.push({
            level: level,
            price_low: priceLow + level * priceStep,
            price_high: priceLow + (level + 1) * priceStep,
            price_mid: priceLow + (level + 0.5) * priceStep,
            volume: volumeStorage[level],
            volume_percent: volumePercent,
            in_value_area: levelBelowPoc <= level && level <= levelAbovePoc,
            is_poc: level === pocLevel
        });
    }
    
    return {
        start_time: candleData[startIdx].time,
        end_time: candleData[endIdx].time,
        start_index: startIdx,
        end_index: endIdx,
        price_high: priceHigh,
        price_low: priceLow,
        poc_price: pocPrice,
        vah_price: vahPrice,
        val_price: valPrice,
        total_volume: totalVolume,
        profile_levels: profileLevels,
        profile_width: profileWidth,
        profile_data: profileData,
        is_developing: false
    };
}

// ============================================================================
// 指标注册表（映射指标ID到计算函数）
// ============================================================================

const INDICATOR_CALCULATORS = {
    // EMA系列
    'ema6': (candleData) => calculateIndicatorEMA(candleData, { period: 6 }),
    'ema12': (candleData) => calculateIndicatorEMA(candleData, { period: 12 }),
    'ema18': (candleData) => calculateIndicatorEMA(candleData, { period: 18 }),
    'ema144': (candleData) => calculateIndicatorEMA(candleData, { period: 144 }),
    'ema169': (candleData) => calculateIndicatorEMA(candleData, { period: 169 }),
    
    // 复杂指标
    'mirror_candle': calculateMirrorCandle,
    'pivot_order_blocks': calculatePivotOrderBlocks,
    'volume_profile_pivot': calculateVolumeProfile,
    'divergence_detector': calculateDivergenceDetector,
    'fvg_order_blocks': calculateFVGOrderBlocks  // 公平价值缺口订单块
};

/**
 * 统一的指标计算接口
 * @param {string} indicatorId - 指标ID
 * @param {Array} candleData - K线数据
 * @param {object} params - 参数
 * @returns {Array} 计算结果
 */
function calculateIndicator(indicatorId, candleData, params = {}) {
    const calculator = INDICATOR_CALCULATORS[indicatorId];
    
    if (!calculator) {
        console.warn(`指标 ${indicatorId} 没有对应的计算函数`);
        return null;
    }
    
    try {
        console.time(`计算指标: ${indicatorId}`);
        const result = calculator(candleData, params);
        console.timeEnd(`计算指标: ${indicatorId}`);
        return result;
    } catch (error) {
        console.error(`计算指标 ${indicatorId} 失败:`, error);
        return null;
    }
}

// 导出到全局作用域
window.IndicatorCalculator = {
    calculate: calculateIndicator,
    calculators: INDICATOR_CALCULATORS,
    
    // 导出工具函数（供高级用户使用）
    utils: {
        calculateEMA,
        calculateSMA,
        findPivotHighs,
        findPivotLows
    }
};

console.log('✅ 指标计算引擎已加载');

/**
 * 多指标背离检测器 - JavaScript实现（✅ 修复版，与Python版本完全一致）
 * 
 * 修复内容：
 * 1. ✅ Pivot点检测逻辑与Python一致（从1开始，不包括中心点）
 * 2. ✅ 背离检测从最近往前查找（pivot_lows[-1], pivot_lows[-2]）
 * 3. ✅ 每个方向只取最近的一个背离（break）
 * 4. ✅ 只保留最近20个Pivot点
 * 5. ✅ 直接使用价格pivot点对应的指标值（不单独检测指标pivot）
 */

// ============================================================================
// 技术指标计算函数
// ============================================================================

/**
 * 计算MACD完整指标
 */
function calculateMACD(closes) {
    const exp1 = calculateEMA(closes, 12);
    const exp2 = calculateEMA(closes, 26);
    
    const macdLine = [];
    const signalLine = [];
    const histogram = [];
    
    for (let i = 0; i < closes.length; i++) {
        if (exp1[i] && exp2[i]) {
            macdLine[i] = exp1[i] - exp2[i];
        } else {
            macdLine[i] = NaN;
        }
    }
    
    // Signal line is EMA of MACD line
    const validMacd = macdLine.filter(v => !isNaN(v));
    const signalEMA = calculateEMA(validMacd, 9);
    
    // Map back to full length
    let signalIdx = 0;
    for (let i = 0; i < macdLine.length; i++) {
        if (!isNaN(macdLine[i])) {
            signalLine[i] = signalEMA[signalIdx++];
            histogram[i] = macdLine[i] - (signalLine[i] || 0);
        } else {
            signalLine[i] = NaN;
            histogram[i] = NaN;
        }
    }
    
    return { macdLine, signalLine, histogram };
}

/**
 * 计算RSI
 */
function calculateRSI(closes, period = 14) {
    const rsi = new Array(closes.length).fill(NaN);
    
    let gains = 0;
    let losses = 0;
    
    // First RSI value
    for (let i = 1; i <= period; i++) {
        const change = closes[i] - closes[i - 1];
        if (change > 0) {
            gains += change;
        } else {
            losses += Math.abs(change);
        }
    }
    
    let avgGain = gains / period;
    let avgLoss = losses / period;
    
    if (avgLoss === 0) {
        rsi[period] = 100;
    } else {
        const rs = avgGain / avgLoss;
        rsi[period] = 100 - (100 / (1 + rs));
    }
    
    // Subsequent RSI values
    for (let i = period + 1; i < closes.length; i++) {
        const change = closes[i] - closes[i - 1];
        const gain = change > 0 ? change : 0;
        const loss = change < 0 ? Math.abs(change) : 0;
        
        avgGain = (avgGain * (period - 1) + gain) / period;
        avgLoss = (avgLoss * (period - 1) + loss) / period;
        
        if (avgLoss === 0) {
            rsi[i] = 100;
        } else {
            const rs = avgGain / avgLoss;
            rsi[i] = 100 - (100 / (1 + rs));
        }
    }
    
    return rsi;
}

/**
 * 计算Stochastic
 */
function calculateStochastic(candleData, period = 14) {
    const stoch = new Array(candleData.length).fill(NaN);
    
    for (let i = period - 1; i < candleData.length; i++) {
        let lowMin = Infinity;
        let highMax = -Infinity;
        
        for (let j = i - period + 1; j <= i; j++) {
            lowMin = Math.min(lowMin, candleData[j].low);
            highMax = Math.max(highMax, candleData[j].high);
        }
        
        const close = candleData[i].close;
        if (highMax - lowMin !== 0) {
            stoch[i] = 100 * (close - lowMin) / (highMax - lowMin);
        }
    }
    
    // Smooth with 3-period MA
    const smoothed = new Array(candleData.length).fill(NaN);
    for (let i = period + 1; i < candleData.length; i++) {
        if (!isNaN(stoch[i]) && !isNaN(stoch[i-1]) && !isNaN(stoch[i-2])) {
            smoothed[i] = (stoch[i] + stoch[i-1] + stoch[i-2]) / 3;
        }
    }
    
    return smoothed;
}

/**
 * 计算CCI (Commodity Channel Index)
 */
function calculateCCI(candleData, period = 10) {
    const cci = new Array(candleData.length).fill(NaN);
    
    for (let i = period - 1; i < candleData.length; i++) {
        // Calculate typical price
        const tpValues = [];
        for (let j = i - period + 1; j <= i; j++) {
            const tp = (candleData[j].high + candleData[j].low + candleData[j].close) / 3;
            tpValues.push(tp);
        }
        
        const smaTp = tpValues.reduce((a, b) => a + b, 0) / period;
        const currentTp = tpValues[tpValues.length - 1];
        
        // Calculate mean absolute deviation
        const mad = tpValues.reduce((sum, val) => sum + Math.abs(val - smaTp), 0) / period;
        
        if (mad !== 0) {
            cci[i] = (currentTp - smaTp) / (0.015 * mad);
        }
    }
    
    return cci;
}

/**
 * 计算Momentum
 */
function calculateMomentum(closes, period = 10) {
    const momentum = new Array(closes.length).fill(NaN);
    
    for (let i = period; i < closes.length; i++) {
        momentum[i] = closes[i] - closes[i - period];
    }
    
    return momentum;
}

/**
 * 计算OBV (On-Balance Volume)
 */
function calculateOBV(candleData) {
    const obv = new Array(candleData.length);
    obv[0] = candleData[0].volume;
    
    for (let i = 1; i < candleData.length; i++) {
        if (candleData[i].close > candleData[i - 1].close) {
            obv[i] = obv[i - 1] + candleData[i].volume;
        } else if (candleData[i].close < candleData[i - 1].close) {
            obv[i] = obv[i - 1] - candleData[i].volume;
        } else {
            obv[i] = obv[i - 1];
        }
    }
    
    return obv;
}

/**
 * 计算CMF (Chaikin Money Flow)
 */
function calculateCMF(candleData, period = 21) {
    const cmf = new Array(candleData.length).fill(NaN);
    
    for (let i = period - 1; i < candleData.length; i++) {
        let mfVolumeSum = 0;
        let volumeSum = 0;
        
        for (let j = i - period + 1; j <= i; j++) {
            const high = candleData[j].high;
            const low = candleData[j].low;
            const close = candleData[j].close;
            const volume = candleData[j].volume;
            
            if (high - low !== 0) {
                const mfMultiplier = ((close - low) - (high - close)) / (high - low);
                mfVolumeSum += mfMultiplier * volume;
                volumeSum += volume;
            }
        }
        
        if (volumeSum !== 0) {
            cmf[i] = mfVolumeSum / volumeSum;
        }
    }
    
    return cmf;
}

/**
 * 计算MFI (Money Flow Index)
 */
function calculateMFI(candleData, period = 14) {
    const mfi = new Array(candleData.length).fill(NaN);
    const typicalPrice = candleData.map(d => (d.high + d.low + d.close) / 3);
    const moneyFlow = candleData.map((d, i) => typicalPrice[i] * d.volume);
    
    for (let i = period; i < candleData.length; i++) {
        let positiveFlow = 0;
        let negativeFlow = 0;
        
        for (let j = i - period + 1; j <= i; j++) {
            if (typicalPrice[j] > typicalPrice[j - 1]) {
                positiveFlow += moneyFlow[j];
            } else if (typicalPrice[j] < typicalPrice[j - 1]) {
                negativeFlow += moneyFlow[j];
            }
        }
        
        if (negativeFlow === 0) {
            mfi[i] = 100;
        } else {
            const mfRatio = positiveFlow / negativeFlow;
            mfi[i] = 100 - (100 / (1 + mfRatio));
        }
    }
    
    return mfi;
}

/**
 * 计算VWMACD (Volume Weighted MACD)
 */
function calculateVWMACD(candleData) {
    const vwmacd = new Array(candleData.length).fill(NaN);
    
    for (let i = 25; i < candleData.length; i++) {
        // VWMA Fast (12)
        let volumeSumFast = 0;
        let priceVolumeSumFast = 0;
        for (let j = i - 11; j <= i; j++) {
            volumeSumFast += candleData[j].volume;
            priceVolumeSumFast += candleData[j].close * candleData[j].volume;
        }
        const vwmaFast = priceVolumeSumFast / volumeSumFast;
        
        // VWMA Slow (26)
        let volumeSumSlow = 0;
        let priceVolumeSumSlow = 0;
        for (let j = i - 25; j <= i; j++) {
            volumeSumSlow += candleData[j].volume;
            priceVolumeSumSlow += candleData[j].close * candleData[j].volume;
        }
        const vwmaSlow = priceVolumeSumSlow / volumeSumSlow;
        
        vwmacd[i] = vwmaFast - vwmaSlow;
    }
    
    return vwmacd;
}

// ============================================================================
// Pivot点检测（✅ 修复版 - 与Python一致）
// ============================================================================

/**
 * 找到价格Pivot High点（✅ 修复版 - 与Python一致）
 */
function findPricePivotHighs(candleData, period) {
    const pivots = [];
    
    for (let i = period; i < candleData.length - period; i++) {
        const currentHigh = candleData[i].high;
        let isPivot = true;
        
        // ✅ 修复：检查左边（从1开始，不包括中心点）
        for (let j = 1; j <= period; j++) {
            if (candleData[i - j].high >= currentHigh) {
                isPivot = false;
                break;
            }
        }
        
        if (!isPivot) continue;
        
        // ✅ 修复：检查右边（从1开始，不包括中心点）
        for (let j = 1; j <= period; j++) {
            if (candleData[i + j].high >= currentHigh) {
                isPivot = false;
                break;
            }
        }
        
        if (isPivot) {
            pivots.push({ index: i, price: currentHigh });
        }
    }
    
    // ✅ 修复：只保留最近20个
    return pivots.slice(-20);
}

/**
 * 找到价格Pivot Low点（✅ 修复版 - 与Python一致）
 */
function findPricePivotLows(candleData, period) {
    const pivots = [];
    
    for (let i = period; i < candleData.length - period; i++) {
        const currentLow = candleData[i].low;
        let isPivot = true;
        
        // ✅ 修复：检查左边（从1开始，不包括中心点）
        for (let j = 1; j <= period; j++) {
            if (candleData[i - j].low <= currentLow) {
                isPivot = false;
                break;
            }
        }
        
        if (!isPivot) continue;
        
        // ✅ 修复：检查右边（从1开始，不包括中心点）
        for (let j = 1; j <= period; j++) {
            if (candleData[i + j].low <= currentLow) {
                isPivot = false;
                break;
            }
        }
        
        if (isPivot) {
            pivots.push({ index: i, price: currentLow });
        }
    }
    
    // ✅ 修复：只保留最近20个
    return pivots.slice(-20);
}

// ============================================================================
// 背离检测（✅ 修复版 - 与Python完全一致）
// ============================================================================

/**
 * 检测正常背离（✅ 修复版）
 * 
 * 关键修复：
 * 1. ✅ 从最近的pivot往前查找（与Python一致）
 * 2. ✅ 每个方向只取最近的一个背离（break）
 * 3. ✅ 直接使用价格pivot点对应的指标值（不单独检测指标pivot）
 */
function detectRegularDivergences(candleData, indicatorValues, pricePivotHighs, pricePivotLows, 
                                 maxPivotPoints, maxBars, indicatorName) {
    const divergences = [];
    const currentIdx = candleData.length - 1;
    
    // ✅ 检测看涨背离（Bullish）- 从最近往前找
    if (pricePivotLows.length >= 2) {
        for (let i = 0; i < Math.min(maxPivotPoints, pricePivotLows.length - 1); i++) {
            // ✅ 修复：从最近往前取（pivot_lows[-(i+1)]）
            const pivot1 = pricePivotLows[pricePivotLows.length - 1 - i];      // 最近的
            const pivot2 = pricePivotLows[pricePivotLows.length - 1 - i - 1];  // 次近的
            
            if (currentIdx - pivot1.index > maxBars) {
                break;
            }
            
            // ✅ 价格创新低，但指标未创新低
            const ind1 = indicatorValues[pivot1.index];
            const ind2 = indicatorValues[pivot2.index];
            
            if (!isNaN(ind1) && !isNaN(ind2) && pivot1.price < pivot2.price && ind1 > ind2) {
                divergences.push({
                    type: 'bullish',
                    indicator: indicatorName,
                    start_index: pivot2.index,
                    end_index: pivot1.index,
                    start_price: pivot2.price,
                    end_price: pivot1.price,
                    start_ind_value: ind2,
                    end_ind_value: ind1
                });
                break;  // ✅ 修复：每个方向只取最近的一个
            }
        }
    }
    
    // ✅ 检测看跌背离（Bearish）- 从最近往前找
    if (pricePivotHighs.length >= 2) {
        for (let i = 0; i < Math.min(maxPivotPoints, pricePivotHighs.length - 1); i++) {
            // ✅ 修复：从最近往前取（pivot_highs[-(i+1)]）
            const pivot1 = pricePivotHighs[pricePivotHighs.length - 1 - i];      // 最近的
            const pivot2 = pricePivotHighs[pricePivotHighs.length - 1 - i - 1];  // 次近的
            
            if (currentIdx - pivot1.index > maxBars) {
                break;
            }
            
            // ✅ 价格创新高，但指标未创新高
            const ind1 = indicatorValues[pivot1.index];
            const ind2 = indicatorValues[pivot2.index];
            
            if (!isNaN(ind1) && !isNaN(ind2) && pivot1.price > pivot2.price && ind1 < ind2) {
                divergences.push({
                    type: 'bearish',
                    indicator: indicatorName,
                    start_index: pivot2.index,
                    end_index: pivot1.index,
                    start_price: pivot2.price,
                    end_price: pivot1.price,
                    start_ind_value: ind2,
                    end_ind_value: ind1
                });
                break;  // ✅ 修复：每个方向只取最近的一个
            }
        }
    }
    
    return divergences;
}

/**
 * 检测隐藏背离（✅ 修复版）
 */
function detectHiddenDivergences(candleData, indicatorValues, pricePivotHighs, pricePivotLows, 
                                maxPivotPoints, maxBars, indicatorName) {
    const divergences = [];
    const currentIdx = candleData.length - 1;
    
    // 隐藏看涨背离 - 价格未创新低，但指标创新低
    if (pricePivotLows.length >= 2) {
        for (let i = 0; i < Math.min(maxPivotPoints, pricePivotLows.length - 1); i++) {
            const pivot1 = pricePivotLows[pricePivotLows.length - 1 - i];
            const pivot2 = pricePivotLows[pricePivotLows.length - 1 - i - 1];
            
            if (currentIdx - pivot1.index > maxBars) break;
            
            const ind1 = indicatorValues[pivot1.index];
            const ind2 = indicatorValues[pivot2.index];
            
            if (!isNaN(ind1) && !isNaN(ind2) && pivot1.price > pivot2.price && ind1 < ind2) {
                divergences.push({
                    type: 'bullish_hidden',
                    indicator: indicatorName,
                    start_index: pivot2.index,
                    end_index: pivot1.index,
                    start_price: pivot2.price,
                    end_price: pivot1.price
                });
                break;
            }
        }
    }
    
    // 隐藏看跌背离 - 价格未创新高，但指标创新高
    if (pricePivotHighs.length >= 2) {
        for (let i = 0; i < Math.min(maxPivotPoints, pricePivotHighs.length - 1); i++) {
            const pivot1 = pricePivotHighs[pricePivotHighs.length - 1 - i];
            const pivot2 = pricePivotHighs[pricePivotHighs.length - 1 - i - 1];
            
            if (currentIdx - pivot1.index > maxBars) break;
            
            const ind1 = indicatorValues[pivot1.index];
            const ind2 = indicatorValues[pivot2.index];
            
            if (!isNaN(ind1) && !isNaN(ind2) && pivot1.price < pivot2.price && ind1 > ind2) {
                divergences.push({
                    type: 'bearish_hidden',
                    indicator: indicatorName,
                    start_index: pivot2.index,
                    end_index: pivot1.index,
                    start_price: pivot2.price,
                    end_price: pivot1.price
                });
                break;
            }
        }
    }
    
    return divergences;
}

/**
 * 分组背离（按位置）
 */
function groupDivergences(divergences, candleData) {
    if (divergences.length === 0) return [];
    
    // 按end_index和type分组
    const groups = {};
    
    for (const div of divergences) {
        const key = `${div.end_index}_${div.type}`;
        if (!groups[key]) {
            groups[key] = [];
        }
        groups[key].push(div);
    }
    
    // 转换为输出格式
    const result = [];
    
    for (const [key, divs] of Object.entries(groups)) {
        const firstDiv = divs[0];
        const indicators = divs.map(d => d.indicator).join(', ');
        
        // ✅ 修复：支持隐藏背离的标签
        const labelText = `${firstDiv.type === 'bullish' ? '看涨' : 
                          firstDiv.type === 'bearish' ? '看跌' :
                          firstDiv.type === 'bullish_hidden' ? '隐藏看涨' : '隐藏看跌'}背离: ${indicators}`;
        
        // 创建背离线
        const lines = divs.map(d => ({
            start_time: candleData[d.start_index].time,
            end_time: candleData[d.end_index].time,
            start_price: d.start_price,
            end_price: d.end_price
        }));
        
        result.push({
            type: firstDiv.type,
            color: firstDiv.type,
            start_time: candleData[firstDiv.start_index].time,
            end_time: candleData[firstDiv.end_index].time,
            start_price: firstDiv.start_price,
            end_price: firstDiv.end_price,
            label_text: labelText,
            lines: lines
        });
    }
    
    return result;
}

// ============================================================================
// 主函数
// ============================================================================

/**
 * 计算多指标背离
 * @param {Array} candleData - K线数据 [{time, open, high, low, close, volume}]
 * @param {object} params - 参数
 * @returns {Array} 背离数据
 */
function calculateDivergenceDetector(candleData, params = {}) {
    const {
        pivot_period = 5,
        max_pivot_points = 10,
        max_bars = 100,
        check_macd = true,
        check_rsi = true,
        check_stoch = true,
        check_cci = true,
        check_momentum = true
    } = params;
    
    console.log('🔍 [背离检测] 开始计算，K线数量:', candleData.length);
    
    if (!candleData || candleData.length < pivot_period * 2 + 50) {
        console.warn('⚠️ [背离检测] 数据不足');
        return [];
    }
    
    const closes = candleData.map(d => d.close);
    const indicators = {};
    
    // 计算各种指标
    if (check_macd) {
        const macd = calculateMACD(closes);
        indicators['MACD'] = macd.macdLine;
        indicators['Hist'] = macd.histogram;
    }
    
    if (check_rsi) {
        indicators['RSI'] = calculateRSI(closes, 14);
    }
    
    if (check_stoch) {
        indicators['Stoch'] = calculateStochastic(candleData, 14);
    }
    
    if (check_cci) {
        indicators['CCI'] = calculateCCI(candleData, 10);
    }
    
    if (check_momentum) {
        indicators['MOM'] = calculateMomentum(closes, 10);
    }
    
    // 额外指标
    indicators['OBV'] = calculateOBV(candleData);
    indicators['VWMACD'] = calculateVWMACD(candleData);  // ✅ 添加VWMACD
    indicators['CMF'] = calculateCMF(candleData, 21);
    indicators['MFI'] = calculateMFI(candleData, 14);
    
    console.log('✅ [背离检测] 指标计算完成，共', Object.keys(indicators).length, '个');
    
    // ✅ 找pivot点（修复版）
    const pricePivotHighs = findPricePivotHighs(candleData, pivot_period);
    const pricePivotLows = findPricePivotLows(candleData, pivot_period);
    
    console.log('✅ [背离检测] Pivot点检测完成，高点:', pricePivotHighs.length, '低点:', pricePivotLows.length);
    
    // ✅ 检测背离（包括正常背离和隐藏背离）
    const allDivergences = [];
    
    for (const [indicatorName, indicatorValues] of Object.entries(indicators)) {
        // 正常背离
        const regularDivs = detectRegularDivergences(
            candleData, 
            indicatorValues, 
            pricePivotHighs, 
            pricePivotLows,
            max_pivot_points, 
            max_bars, 
            indicatorName
        );
        allDivergences.push(...regularDivs);
        
        // ✅ 隐藏背离
        const hiddenDivs = detectHiddenDivergences(
            candleData, 
            indicatorValues, 
            pricePivotHighs, 
            pricePivotLows,
            max_pivot_points, 
            max_bars, 
            indicatorName
        );
        allDivergences.push(...hiddenDivs);
    }
    
    console.log('✅ [背离检测] 原始背离数量:', allDivergences.length);
    
    // 分组
    const grouped = groupDivergences(allDivergences, candleData);
    
    console.log('✅ [背离检测] 完成，检测到', grouped.length, '组背离');
    
    return grouped;
}

// 导出到全局（如果在浏览器环境）
if (typeof window !== 'undefined') {
    window.DivergenceCalculator = {
        calculate: calculateDivergenceDetector
    };
    console.log('✅ 背离检测计算引擎已加载');
}

// 导出（如果在Node.js环境）
if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
        calculateDivergenceDetector,
        calculateFVGOrderBlocks
    };
}

/**
 * FVG Order Blocks - 公平价值缺口订单块
 * 移植自 TradingView Pine Script by BigBeluga
 * 
 * 功能：
 * - 检测价格缺口（Fair Value Gaps）
 * - 创建订单块区域（Order Blocks）
 * - 使用ATR动态调整区域大小
 */

/**
 * 计算ATR (Average True Range)
 */
function calculateATR(candleData, period = 200) {
    const atr = new Array(candleData.length).fill(0);
    
    // 计算True Range
    const tr = new Array(candleData.length).fill(0);
    tr[0] = candleData[0].high - candleData[0].low;
    
    for (let i = 1; i < candleData.length; i++) {
        const high = candleData[i].high;
        const low = candleData[i].low;
        const prevClose = candleData[i - 1].close;
        
        tr[i] = Math.max(
            high - low,
            Math.abs(high - prevClose),
            Math.abs(low - prevClose)
        );
    }
    
    // 计算ATR（使用RMA/Wilder's smoothing）
    atr[period - 1] = tr.slice(0, period).reduce((a, b) => a + b) / period;
    
    for (let i = period; i < candleData.length; i++) {
        atr[i] = (atr[i - 1] * (period - 1) + tr[i]) / period;
    }
    
    return atr;
}

/**
 * 计算FVG Order Blocks
 * @param {Array} candleData - K线数据
 * @param {object} params - 参数
 * @returns {object} 订单块数据
 */
function calculateFVGOrderBlocks(candleData, params = {}) {
    const {
        lookback = 2000,
        filter = 0.5,
        box_amount = 6,
        show_broken = false,
        show_signal = false,
        atr_period = 200
    } = params;
    
    console.log('📊 [FVG Order Blocks] 开始计算，K线数量:', candleData.length);
    
    if (!candleData || candleData.length < 3) {
        console.warn('⚠️ [FVG Order Blocks] 数据不足');
        return { bullish: [], bearish: [], gaps: [] };
    }
    
    // 计算ATR
    const atr = calculateATR(candleData, atr_period);
    
    // 存储订单块
    const bullishBlocks = [];
    const bearishBlocks = [];
    const gaps = [];  // 缺口标记
    
    // 用于计算最大缺口百分比（用于颜色渐变）
    let maxBullGap = 0;
    let maxBearGap = 0;
    
    // 从第2根K线开始检测（需要3根K线）
    const startIdx = Math.max(2, candleData.length - lookback);
    
    for (let i = startIdx; i < candleData.length; i++) {
        const current = candleData[i];
        const prev1 = candleData[i - 1];
        const prev2 = candleData[i - 2];
        
        // 检测看涨缺口（Bullish Gap）
        // 条件：high[2] < low 且 high[2] < high[1] 且 low[2] < low
        const isBullGap = prev2.high < current.low && 
                         prev2.high < prev1.high && 
                         prev2.low < current.low;
        
        if (isBullGap) {
            // 计算缺口百分比
            const gapPercent = ((current.low - prev2.high) / current.low) * 100;
            
            if (gapPercent > filter) {
                maxBullGap = Math.max(maxBullGap, gapPercent);
                
                // 记录缺口（用于显示）
                gaps.push({
                    type: 'bullish',
                    time: current.time,
                    top: current.low,
                    bottom: prev2.high,
                    percent: gapPercent
                });
                
                // 创建看涨订单块
                // 区域：从prev2.high向下延伸ATR
                const blockTop = prev2.high;
                const blockBottom = prev2.high - atr[i];
                
                bullishBlocks.push({
                    startTime: current.time,
                    startIndex: i,
                    top: blockTop,
                    bottom: blockBottom,
                    percent: gapPercent,
                    broken: false,
                    active: true
                });
            }
        }
        
        // 检测看跌缺口（Bearish Gap）
        // 条件：low[2] > high 且 low[2] > low[1] 且 high[2] > high
        const isBearGap = prev2.low > current.high && 
                         prev2.low > prev1.low && 
                         prev2.high > current.high;
        
        if (isBearGap) {
            // 计算缺口百分比
            const gapPercent = ((prev2.low - current.high) / prev2.low) * 100;
            
            if (gapPercent > filter) {
                maxBearGap = Math.max(maxBearGap, gapPercent);
                
                // 记录缺口
                gaps.push({
                    type: 'bearish',
                    time: current.time,
                    top: prev2.low,
                    bottom: current.high,
                    percent: gapPercent
                });
                
                // 创建看跌订单块
                // 区域：从prev2.low向上延伸ATR
                const blockBottom = prev2.low;
                const blockTop = prev2.low + atr[i];
                
                bearishBlocks.push({
                    startTime: current.time,
                    startIndex: i,
                    top: blockTop,
                    bottom: blockBottom,
                    percent: gapPercent,
                    broken: false,
                    active: true
                });
            }
        }
    }
    
    // 检测订单块突破
    for (let i = 0; i < candleData.length; i++) {
        const candle = candleData[i];
        
        // 检查看涨订单块
        for (const block of bullishBlocks) {
            if (i <= block.startIndex) continue;
            
            // 价格跌破订单块底部 = 订单块失效
            if (candle.high < block.bottom && !block.broken) {
                block.broken = true;
                block.brokenTime = candle.time;
                block.brokenIndex = i;
            }
            
            // 价格突破订单块顶部 = 触发信号
            if (candle.low > block.top && !block.triggered) {
                block.triggered = true;
                block.signalTime = candle.time;
                block.signalIndex = i;
            }
        }
        
        // 检查看跌订单块
        for (const block of bearishBlocks) {
            if (i <= block.startIndex) continue;
            
            // 价格突破订单块顶部 = 订单块失效
            if (candle.low > block.top && !block.broken) {
                block.broken = true;
                block.brokenTime = candle.time;
                block.brokenIndex = i;
            }
            
            // 价格跌破订单块底部 = 触发信号
            if (candle.high < block.bottom && !block.triggered) {
                block.triggered = true;
                block.signalTime = candle.time;
                block.signalIndex = i;
            }
        }
    }
    
    // 过滤：只保留最近的box_amount个订单块
    const activeBullish = bullishBlocks
        .filter(b => show_broken || !b.broken)
        .slice(-box_amount);
    
    const activeBearish = bearishBlocks
        .filter(b => show_broken || !b.broken)
        .slice(-box_amount);
    
    console.log('✅ [FVG Order Blocks] 计算完成');
    console.log(`   - 看涨订单块: ${activeBullish.length}`);
    console.log(`   - 看跌订单块: ${activeBearish.length}`);
    console.log(`   - 缺口标记: ${gaps.length}`);
    
    return {
        bullish: activeBullish,
        bearish: activeBearish,
        gaps: gaps,
        maxBullGap: maxBullGap,
        maxBearGap: maxBearGap,
        renderType: 'fvg_order_blocks'
    };
}

// ============================================================================
// Smart Money Concepts - 聪明钱概念
// ============================================================================

/**
 * 计算Smart Money Concepts指标
 * 
 * 核心算法：
 * 1. Leg检测：判断当前市场腿部（牛市腿/熊市腿）
 * 2. Pivot识别：找到关键摆动高点和低点
 * 3. Structure检测：识别BOS（结构突破）和CHoCH（趋势转变）
 * 4. Order Blocks：记录结构突破时的关键价格区域
 * 5. Equal Highs/Lows：识别价格多次触及的相同水平
 * 
 * @param {Array} candleData - K线数据
 * @param {Object} params - 参数配置
 * @returns {Object} 包含所有SMC元素的对象
 */
function calculateSmartMoneyConcepts(candleData, params) {
    console.log('🧠 [Smart Money Concepts] 开始计算...');
    
    const {
        swing_length = 50,
        internal_length = 5,
        show_internals = true,
        show_structure = true,
        show_swing_points = false,
        show_internal_ob = true,
        internal_ob_count = 5,
        show_swing_ob = false,
        swing_ob_count = 5,
        ob_filter = 'Atr',
        ob_mitigation = 'High/Low',
        show_equal_hl = true,
        equal_hl_length = 3,
        equal_hl_threshold = 0.1,
        show_fvg = false,           // FVG（公平价值缺口）- 默认关闭
        fvg_extend = 20,            // FVG延伸K线数
        fvg_threshold = 0.5,        // FVG阈值（过滤小缺口）
        style = 'Colored',
        mode = 'Historical'
    } = params;
    
    const n = candleData.length;
    const minRequired = Math.max(swing_length + 10, internal_length + 10);
    if (n < minRequired) {
        console.warn(`⚠️ [SMC] 数据不足: 需要至少 ${minRequired} 根K线，当前只有 ${n} 根`);
        return {
            swingStructures: [],
            internalStructures: [],
            swingOrderBlocks: [],
            internalOrderBlocks: [],
            equalHighsLows: [],
            swingPoints: [],
            renderType: 'smart_money_concepts'
        };
    }
    
    console.log(`✅ [SMC] 数据量检查通过: ${n} 根K线 (最少需要 ${minRequired} 根)`);

    
    // 1. 计算ATR（用于订单块过滤和等高等低检测）
    const atrPeriod = Math.min(200, Math.floor(n / 2));
    const atr = calculateATR(candleData, atrPeriod);
    console.log(`   - ATR周期: ${atrPeriod}`);
    
    // 2. 计算volatility measure（用于订单块过滤）
    const volatilityMeasure = [];
    let cumulativeTR = 0;
    for (let i = 0; i < n; i++) {
        const tr = i === 0 ? candleData[i].high - candleData[i].low :
            Math.max(
                candleData[i].high - candleData[i].low,
                Math.abs(candleData[i].high - candleData[i - 1].close),
                Math.abs(candleData[i].low - candleData[i - 1].close)
            );
        cumulativeTR += tr;
        volatilityMeasure[i] = ob_filter === 'Atr' ? atr[i] : cumulativeTR / (i + 1);
    }
    
    // 3. 解析高低点（过滤高波动K线）
    const parsedHighs = [];
    const parsedLows = [];
    for (let i = 0; i < n; i++) {
        const range = candleData[i].high - candleData[i].low;
        const highVolatility = range >= 2 * volatilityMeasure[i];
        parsedHighs[i] = highVolatility ? candleData[i].low : candleData[i].high;
        parsedLows[i] = highVolatility ? candleData[i].high : candleData[i].low;
    }
    
    // 4. 检测Leg（市场腿部）
    function getLeg(index, size) {
        if (index < size) return null;
        
        let maxHigh = -Infinity;
        let minLow = Infinity;
        
        for (let j = index - size + 1; j <= index; j++) {
            if (candleData[j].high > maxHigh) maxHigh = candleData[j].high;
            if (candleData[j].low < minLow) minLow = candleData[j].low;
        }
        
        const newLegHigh = candleData[index - size].high > maxHigh;
        const newLegLow = candleData[index - size].low < minLow;
        
        if (newLegHigh) return 0; // BEARISH_LEG
        if (newLegLow) return 1;  // BULLISH_LEG
        return null;
    }
    
    // 5. 查找摆动点（Swing Points）和结构（Structures）
    const swingStructures = [];
    const internalStructures = [];
    const swingOrderBlocks = [];
    const internalOrderBlocks = [];
    const swingPoints = [];
    const equalHighsLows = [];
    const fairValueGaps = [];
    
    // 摆动Pivot追踪
    let swingHigh = {level: null, lastLevel: null, crossed: false, barIndex: -1, time: null};
    let swingLow = {level: null, lastLevel: null, crossed: false, barIndex: -1, time: null};
    let swingTrend = 0; // 0=中性, 1=看涨, -1=看跌
    
    // 内部Pivot追踪
    let internalHigh = {level: null, lastLevel: null, crossed: false, barIndex: -1, time: null};
    let internalLow = {level: null, lastLevel: null, crossed: false, barIndex: -1, time: null};
    let internalTrend = 0;
    
    // Equal HL追踪
    let equalHigh = {level: null, barIndex: -1, time: null};
    let equalLow = {level: null, barIndex: -1, time: null};
    
    // 遍历K线数据
    let prevSwingLeg = null;
    let prevInternalLeg = null;
    
    for (let i = Math.max(swing_length, internal_length); i < n; i++) {
        const close = candleData[i].close;
        const high = candleData[i].high;
        const low = candleData[i].low;
        const time = candleData[i].time;
        
        // ========== 摆动结构检测 ==========
        if (show_structure) {
            const swingLeg = getLeg(i, swing_length);
            if (swingLeg !== null && swingLeg !== prevSwingLeg && prevSwingLeg !== null) {
                // 发现新的Leg，记录Pivot
                if (swingLeg === 1) {
                    // 新的看涨Leg -> 前一个低点是Pivot Low
                    const pivotIdx = i - swing_length;
                    const pivotLow = candleData[pivotIdx].low;
                    
                    // 检测Equal Low（在发现新Pivot时）
                    if (show_equal_hl && equalLow.level !== null && Math.abs(equalLow.level - pivotLow) < equal_hl_threshold * atr[i]) {
                        equalHighsLows.push({
                            type: 'low',
                            price: equalLow.level,
                            startTime: equalLow.time,
                            endTime: candleData[pivotIdx].time,
                            startIndex: equalLow.barIndex,
                            endIndex: pivotIdx
                        });
                    }
                    
                    swingLow.lastLevel = swingLow.level;
                    swingLow.level = pivotLow;
                    swingLow.crossed = false;
                    swingLow.barIndex = pivotIdx;
                    swingLow.time = candleData[pivotIdx].time;
                    
                    equalLow.level = pivotLow;
                    equalLow.barIndex = pivotIdx;
                    equalLow.time = candleData[pivotIdx].time;
                    
                    if (show_swing_points && swingLow.lastLevel !== null) {
                        const label = swingLow.level < swingLow.lastLevel ? 'LL' : 'HL';
                        swingPoints.push({
                            time: swingLow.time,
                            price: swingLow.level,
                            label: label,
                            type: 'low'
                        });
                    }
                } else {
                    // 新的看跌Leg -> 前一个高点是Pivot High
                    const pivotIdx = i - swing_length;
                    const pivotHigh = candleData[pivotIdx].high;
                    
                    // 检测Equal High（在发现新Pivot时）
                    if (show_equal_hl && equalHigh.level !== null && Math.abs(equalHigh.level - pivotHigh) < equal_hl_threshold * atr[i]) {
                        equalHighsLows.push({
                            type: 'high',
                            price: equalHigh.level,
                            startTime: equalHigh.time,
                            endTime: candleData[pivotIdx].time,
                            startIndex: equalHigh.barIndex,
                            endIndex: pivotIdx
                        });
                    }
                    
                    swingHigh.lastLevel = swingHigh.level;
                    swingHigh.level = pivotHigh;
                    swingHigh.crossed = false;
                    swingHigh.barIndex = pivotIdx;
                    swingHigh.time = candleData[pivotIdx].time;
                    
                    equalHigh.level = pivotHigh;
                    equalHigh.barIndex = pivotIdx;
                    equalHigh.time = candleData[pivotIdx].time;
                    
                    if (show_swing_points && swingHigh.lastLevel !== null) {
                        const label = swingHigh.level > swingHigh.lastLevel ? 'HH' : 'LH';
                        swingPoints.push({
                            time: swingHigh.time,
                            price: swingHigh.level,
                            label: label,
                            type: 'high'
                        });
                    }
                }
            }
            prevSwingLeg = swingLeg;
            
            // 检测结构突破（Swing High）
            if (swingHigh.level !== null && close > swingHigh.level && !swingHigh.crossed) {
                const tag = swingTrend === -1 ? 'CHoCH' : 'BOS';
                swingStructures.push({
                    time: time,
                    price: swingHigh.level,
                    type: 'bullish',
                    tag: tag,
                    startTime: swingHigh.time,
                    internal: false
                });
                swingHigh.crossed = true;
                swingTrend = 1; // 看涨趋势
                
                // 创建订单块
                if (show_swing_ob) {
                    createOrderBlock(swingHigh, false, 1, candleData, parsedHighs, parsedLows, swingOrderBlocks, i);
                }
            }
            
            // 检测结构突破（Swing Low）
            if (swingLow.level !== null && close < swingLow.level && !swingLow.crossed) {
                const tag = swingTrend === 1 ? 'CHoCH' : 'BOS';
                swingStructures.push({
                    time: time,
                    price: swingLow.level,
                    type: 'bearish',
                    tag: tag,
                    startTime: swingLow.time,
                    internal: false
                });
                swingLow.crossed = true;
                swingTrend = -1; // 看跌趋势
                
                // 创建订单块
                if (show_swing_ob) {
                    createOrderBlock(swingLow, false, -1, candleData, parsedHighs, parsedLows, swingOrderBlocks, i);
                }
            }
        }
        
        // ========== 内部结构检测 ==========
        if (show_internals) {
            const internalLeg = getLeg(i, internal_length);
            if (internalLeg !== null && internalLeg !== prevInternalLeg && prevInternalLeg !== null) {
                if (internalLeg === 1) {
                    const pivotIdx = i - internal_length;
                    internalLow.lastLevel = internalLow.level;
                    internalLow.level = candleData[pivotIdx].low;
                    internalLow.crossed = false;
                    internalLow.barIndex = pivotIdx;
                    internalLow.time = candleData[pivotIdx].time;
                } else {
                    const pivotIdx = i - internal_length;
                    internalHigh.lastLevel = internalHigh.level;
                    internalHigh.level = candleData[pivotIdx].high;
                    internalHigh.crossed = false;
                    internalHigh.barIndex = pivotIdx;
                    internalHigh.time = candleData[pivotIdx].time;
                }
            }
            prevInternalLeg = internalLeg;
            
            // 检测内部结构突破（不能与Swing结构重合）
            if (internalHigh.level !== null && close > internalHigh.level && !internalHigh.crossed &&
                internalHigh.level !== swingHigh.level) {
                const tag = internalTrend === -1 ? 'CHoCH' : 'BOS';
                internalStructures.push({
                    time: time,
                    price: internalHigh.level,
                    type: 'bullish',
                    tag: tag,
                    startTime: internalHigh.time,
                    internal: true
                });
                internalHigh.crossed = true;
                internalTrend = 1;
                
                if (show_internal_ob) {
                    createOrderBlock(internalHigh, true, 1, candleData, parsedHighs, parsedLows, internalOrderBlocks, i);
                }
            }
            
            if (internalLow.level !== null && close < internalLow.level && !internalLow.crossed &&
                internalLow.level !== swingLow.level) {
                const tag = internalTrend === 1 ? 'CHoCH' : 'BOS';
                internalStructures.push({
                    time: time,
                    price: internalLow.level,
                    type: 'bearish',
                    tag: tag,
                    startTime: internalLow.time,
                    internal: true
                });
                internalLow.crossed = true;
                internalTrend = -1;
                
                if (show_internal_ob) {
                    createOrderBlock(internalLow, true, -1, candleData, parsedHighs, parsedLows, internalOrderBlocks, i);
                }
            }
        }
        
        // ========== Fair Value Gaps检测（FVG - 公平价值缺口）==========
        if (show_fvg && i >= 2) {
            const c1 = candleData[i - 2];  // 第1根K线
            const c2 = candleData[i - 1];  // 第2根K线
            const c3 = candleData[i];      // 第3根K线（当前）
            
            // 看涨FVG: c3的低点 > c1的高点（向上跳空）
            const bullishGap = c3.low - c1.high;
            if (bullishGap > 0 && bullishGap > fvg_threshold * atr[i]) {
                fairValueGaps.push({
                    type: 'bullish',
                    top: c3.low,
                    bottom: c1.high,
                    bias: 1,
                    time: c2.time,
                    endTime: candleData[Math.min(i + fvg_extend, n - 1)].time
                });
            }
            // 看跌FVG: c3的高点 < c1的低点（向下跳空）
            const bearishGap = c1.low - c3.high;
            if (bearishGap > 0 && bearishGap > fvg_threshold * atr[i]) {
                fairValueGaps.push({
                    type: 'bearish',
                    top: c1.low,
                    bottom: c3.high,
                    bias: -1,
                    time: c2.time,
                    endTime: candleData[Math.min(i + fvg_extend, n - 1)].time
                });
            }
        }
        
        // ========== 订单块破坏检测（每根K线检查）==========
        const mitigationHigh = ob_mitigation === 'Close' ? close : high;
        const mitigationLow = ob_mitigation === 'Close' ? close : low;
        
        // 检查摆动订单块
        for (let j = swingOrderBlocks.length - 1; j >= 0; j--) {
            const block = swingOrderBlocks[j];
            if ((block.bias === -1 && mitigationHigh > block.top) ||
                (block.bias === 1 && mitigationLow < block.bottom)) {
                swingOrderBlocks.splice(j, 1);  // 立即删除
            }
        }
        
        // 检查内部订单块
        for (let j = internalOrderBlocks.length - 1; j >= 0; j--) {
            const block = internalOrderBlocks[j];
            if ((block.bias === -1 && mitigationHigh > block.top) ||
                (block.bias === 1 && mitigationLow < block.bottom)) {
                internalOrderBlocks.splice(j, 1);  // 立即删除
            }
        }
    }
    
    // 6. 创建订单块的辅助函数
    function createOrderBlock(pivot, isInternal, bias, candleData, parsedHighs, parsedLows, orderBlockArray, currentBarIndex) {
        const startIdx = Math.max(0, pivot.barIndex);
        const endIdx = currentBarIndex;  // 关键修复：从pivot到当前K线
        
        let extremeIdx = startIdx;
        if (bias === -1) {
            // 看跌订单块：找到最高点
            let maxHigh = parsedHighs[startIdx];
            for (let j = startIdx; j <= endIdx; j++) {
                if (parsedHighs[j] > maxHigh) {
                    maxHigh = parsedHighs[j];
                    extremeIdx = j;
                }
            }
        } else {
            // 看涨订单块：找到最低点
            let minLow = parsedLows[startIdx];
            for (let j = startIdx; j <= endIdx; j++) {
                if (parsedLows[j] < minLow) {
                    minLow = parsedLows[j];
                    extremeIdx = j;
                }
            }
        }
        
        const newBlock = {
            top: parsedHighs[extremeIdx],
            bottom: parsedLows[extremeIdx],
            time: candleData[extremeIdx].time,
            barIndex: extremeIdx,  // 记录创建时的索引
            bias: bias,
            internal: isInternal
        };
        orderBlockArray.push(newBlock);
        
        if (orderBlockArray.length <= 5) {  // 只打印前5个
            console.log(`   [创建${isInternal?'内部':'摆动'}OB] pivot=${pivot.barIndex}, current=${currentBarIndex}, extreme=${extremeIdx}, bias=${bias}, top=${newBlock.top.toFixed(2)}, bottom=${newBlock.bottom.toFixed(2)}`);
        }
    }
    
    // 7. 过滤并返回最终结果（只保留最近的N个订单块）
    const activeSwingOB = swingOrderBlocks.slice(-swing_ob_count);
    const activeInternalOB = internalOrderBlocks.slice(-internal_ob_count);
    
    console.log('✅ [Smart Money Concepts] 计算完成');
    console.log(`   - 摆动结构: ${swingStructures.length}`);
    console.log(`   - 内部结构: ${internalStructures.length}`);
    console.log(`   - 摆动订单块: ${activeSwingOB.length} (show_swing_ob: ${show_swing_ob})`);
    console.log(`   - 内部订单块: ${activeInternalOB.length} (show_internal_ob: ${show_internal_ob})`);
    console.log(`   - 等高等低: ${equalHighsLows.length} (show_equal_hl: ${show_equal_hl})`);
    console.log(`   - 公平价值缺口(FVG): ${fairValueGaps.length} (show_fvg: ${show_fvg})`);
    
    // 打印订单块详情
    if (activeInternalOB.length > 0) {
        console.log('   [内部订单块详情]:');
        activeInternalOB.forEach((block, i) => {
            console.log(`     ${i+1}. top=${block.top.toFixed(2)}, bottom=${block.bottom.toFixed(2)}, 高度=${(block.top - block.bottom).toFixed(2)}, bias=${block.bias}`);
        });
    }
    if (activeSwingOB.length > 0) {
        console.log('   [摆动订单块详情]:');
        activeSwingOB.forEach((block, i) => {
            console.log(`     ${i+1}. top=${block.top.toFixed(2)}, bottom=${block.bottom.toFixed(2)}, 高度=${(block.top - block.bottom).toFixed(2)}, bias=${block.bias}`);
        });
    }
    
    return {
        swingStructures: mode === 'Present' ? swingStructures.slice(-1) : swingStructures,
        internalStructures: mode === 'Present' ? internalStructures.slice(-1) : internalStructures,
        swingOrderBlocks: activeSwingOB,
        internalOrderBlocks: activeInternalOB,
        equalHighsLows: equalHighsLows,
        fairValueGaps: fairValueGaps,
        swingPoints: swingPoints,
        renderType: 'smart_money_concepts'
    };
}

/**
 * Support Resistance Channels - 支撑阻力通道计算
 * 基于Pivot点智能识别最强的支撑/阻力通道
 */
function calculateSupportResistanceChannels(candleData, params = {}) {
    console.log('📊 [Support Resistance Channels] 开始计算');
    
    const {
        pivot_period = 10,
        pivot_source = 'High/Low',
        channel_width_percent = 5,
        min_strength = 1,
        max_channels = 6,
        loopback_period = 290
    } = params;
    
    const n = candleData.length;
    if (n < pivot_period * 2 + 10) {
        console.warn('❌ K线数量不足，需要至少', pivot_period * 2 + 10, '根');
        return { channels: [], pivots: [] };
    }
    
    // 1. 检测Pivot High/Low点
    const pivots = [];  // { type: 'high'|'low', price: number, barIndex: number, time: number }
    
    for (let i = pivot_period; i < n - pivot_period; i++) {
        const src1 = pivot_source === 'High/Low' ? candleData[i].high : Math.max(candleData[i].close, candleData[i].open);
        const src2 = pivot_source === 'High/Low' ? candleData[i].low : Math.min(candleData[i].close, candleData[i].open);
        
        // 检测Pivot High
        let isPivotHigh = true;
        for (let j = 1; j <= pivot_period; j++) {
            const leftSrc = pivot_source === 'High/Low' ? candleData[i - j].high : Math.max(candleData[i - j].close, candleData[i - j].open);
            const rightSrc = pivot_source === 'High/Low' ? candleData[i + j].high : Math.max(candleData[i + j].close, candleData[i + j].open);
            if (src1 <= leftSrc || src1 <= rightSrc) {
                isPivotHigh = false;
                break;
            }
        }
        
        if (isPivotHigh) {
            pivots.push({
                type: 'high',
                price: src1,
                barIndex: i,
                time: candleData[i].time
            });
        }
        
        // 检测Pivot Low
        let isPivotLow = true;
        for (let j = 1; j <= pivot_period; j++) {
            const leftSrc = pivot_source === 'High/Low' ? candleData[i - j].low : Math.min(candleData[i - j].close, candleData[i - j].open);
            const rightSrc = pivot_source === 'High/Low' ? candleData[i + j].low : Math.min(candleData[i + j].close, candleData[i + j].open);
            if (src2 >= leftSrc || src2 >= rightSrc) {
                isPivotLow = false;
                break;
            }
        }
        
        if (isPivotLow) {
            pivots.push({
                type: 'low',
                price: src2,
                barIndex: i,
                time: candleData[i].time
            });
        }
    }
    
    // 只保留回溯期内的Pivot点
    const currentBar = n - 1;
    const validPivots = pivots.filter(p => currentBar - p.barIndex <= loopback_period);
    
    if (validPivots.length === 0) {
        console.log('⚠️ 未检测到有效Pivot点');
        return { channels: [], pivots: [] };
    }
    
    // 2. 计算动态通道宽度
    const priceRange300 = [];
    for (let i = Math.max(0, n - 300); i < n; i++) {
        priceRange300.push(candleData[i].high);
        priceRange300.push(candleData[i].low);
    }
    const highest300 = Math.max(...priceRange300);
    const lowest300 = Math.min(...priceRange300);
    const maxChannelWidth = (highest300 - lowest300) * channel_width_percent / 100;
    
    // 3. 为每个Pivot点构建通道
    const channelCandidates = [];
    
    for (let i = 0; i < validPivots.length; i++) {
        let hi = validPivots[i].price;
        let lo = validPivots[i].price;
        let numPivots = 0;
        
        // 尝试将其他Pivot点加入通道
        for (let j = 0; j < validPivots.length; j++) {
            const pivotPrice = validPivots[j].price;
            const width = pivotPrice <= hi ? hi - pivotPrice : pivotPrice - lo;
            
            if (width <= maxChannelWidth) {
                if (pivotPrice <= hi) {
                    lo = Math.min(lo, pivotPrice);
                } else {
                    hi = Math.max(hi, pivotPrice);
                }
                numPivots += 20;  // 每个Pivot点贡献20分
            }
        }
        
        // 4. 计算历史触及次数
        let touchCount = 0;
        for (let k = 0; k < Math.min(loopback_period, n); k++) {
            const bar = candleData[n - 1 - k];
            if ((bar.high <= hi && bar.high >= lo) || (bar.low <= hi && bar.low >= lo)) {
                touchCount++;
            }
        }
        
        const totalStrength = numPivots + touchCount;
        
        channelCandidates.push({
            high: hi,
            low: lo,
            strength: totalStrength,
            pivotIndex: i
        });
    }
    
    // 5. 去重和排序
    const uniqueChannels = [];
    const used = new Set();
    
    // 按强度排序
    channelCandidates.sort((a, b) => b.strength - a.strength);
    
    for (const candidate of channelCandidates) {
        if (candidate.strength < min_strength * 20) continue;
        if (used.has(candidate.pivotIndex)) continue;
        
        // 标记所有包含在此通道内的Pivot点为已使用
        for (let i = 0; i < validPivots.length; i++) {
            const price = validPivots[i].price;
            if (price <= candidate.high && price >= candidate.low) {
                used.add(i);
            }
        }
        
        uniqueChannels.push(candidate);
        
        if (uniqueChannels.length >= max_channels) {
            break;
        }
    }
    
    // 6. 判断通道类型（支撑/阻力/在通道内）
    const currentClose = candleData[n - 1].close;
    const channels = uniqueChannels.map(ch => {
        let type = 'in_channel';
        if (ch.high < currentClose && ch.low < currentClose) {
            type = 'support';  // 支撑
        } else if (ch.high > currentClose && ch.low > currentClose) {
            type = 'resistance';  // 阻力
        }
        
        return {
            high: ch.high,
            low: ch.low,
            strength: ch.strength,
            type: type
        };
    });
    
    console.log('✅ [Support Resistance Channels] 计算完成');
    console.log(`   - 检测到Pivot点: ${pivots.length} (有效: ${validPivots.length})`);
    console.log(`   - 通道候选数: ${channelCandidates.length}`);
    console.log(`   - 最终显示通道: ${channels.length}`);
    console.log(`   - 最大通道宽度: ${maxChannelWidth.toFixed(2)}`);
    
    return {
        channels: channels,
        pivots: validPivots,
        renderType: 'support_resistance_channels'
    };
}

/**
 * ZigZag++ - 之字形指标计算
 * 基于MT4 ZigZag算法，识别价格转折点和市场结构
 */
function calculateZigZag(candleData, params = {}) {
    console.log('📊 [ZigZag++] 开始计算');
    
    const {
        depth = 12,
        deviation = 5,
        backstep = 2,
        repaint = true
    } = params;
    
    const n = candleData.length;
    if (n < depth * 2) {
        console.warn('❌ K线数量不足，需要至少', depth * 2, '根');
        return { pivots: [], lines: [], direction: 0 };
    }
    
    // MT4 ZigZag算法实现
    const pivots = [];  // 转折点 { type: 'high'|'low', price: number, barIndex: number, time: number, label: string }
    
    // 1. 寻找初始高低点
    let extremeType = null;  // 'high' or 'low'
    let extremePrice = 0;
    let extremeIndex = 0;
    
    // 扫描前depth根K线找到初始极值
    for (let i = 0; i < Math.min(depth, n); i++) {
        if (extremeType === null || candleData[i].high > extremePrice) {
            extremeType = 'high';
            extremePrice = candleData[i].high;
            extremeIndex = i;
        }
        if (extremeType === null || candleData[i].low < extremePrice) {
            extremeType = 'low';
            extremePrice = candleData[i].low;
            extremeIndex = i;
        }
    }
    
    // 记录当前极值点
    let currentExtremeType = extremeType;
    let currentExtremePrice = extremePrice;
    let currentExtremeIndex = extremeIndex;
    
    // 2. 主循环：扫描K线寻找转折点
    for (let i = depth; i < n; i++) {
        const bar = candleData[i];
        const deviationAmount = currentExtremePrice * deviation / 100;
        
        // 如果当前极值是高点，寻找低点
        if (currentExtremeType === 'high') {
            // 检查是否有更高的高点（更新当前高点）
            if (bar.high > currentExtremePrice && i - currentExtremeIndex >= backstep) {
                currentExtremePrice = bar.high;
                currentExtremeIndex = i;
            }
            
            // 检查是否出现足够低的低点（形成转折）
            if (currentExtremePrice - bar.low >= deviationAmount && i - currentExtremeIndex >= backstep) {
                // 确认高点
                pivots.push({
                    type: 'high',
                    price: currentExtremePrice,
                    barIndex: currentExtremeIndex,
                    time: candleData[currentExtremeIndex].time
                });
                
                // 切换到寻找高点模式
                currentExtremeType = 'low';
                currentExtremePrice = bar.low;
                currentExtremeIndex = i;
            }
        }
        // 如果当前极值是低点，寻找高点
        else {
            // 检查是否有更低的低点（更新当前低点）
            if (bar.low < currentExtremePrice && i - currentExtremeIndex >= backstep) {
                currentExtremePrice = bar.low;
                currentExtremeIndex = i;
            }
            
            // 检查是否出现足够高的高点（形成转折）
            if (bar.high - currentExtremePrice >= deviationAmount && i - currentExtremeIndex >= backstep) {
                // 确认低点
                pivots.push({
                    type: 'low',
                    price: currentExtremePrice,
                    barIndex: currentExtremeIndex,
                    time: candleData[currentExtremeIndex].time
                });
                
                // 切换到寻找低点模式
                currentExtremeType = 'high';
                currentExtremePrice = bar.high;
                currentExtremeIndex = i;
            }
        }
    }
    
    // 3. 如果启用repaint，添加当前未确认的极值点
    if (repaint && pivots.length > 0) {
        pivots.push({
            type: currentExtremeType,
            price: currentExtremePrice,
            barIndex: currentExtremeIndex,
            time: candleData[currentExtremeIndex].time,
            unconfirmed: true  // 标记为未确认
        });
    }
    
    // 4. 计算市场结构标签（HH/HL/LH/LL）
    if (pivots.length >= 2) {
        let lastPrice = pivots[0].price;
        
        for (let i = 1; i < pivots.length; i++) {
            const pivot = pivots[i];
            
            if (pivot.type === 'high') {
                // 比较当前高点与上一个高点
                if (pivot.price > lastPrice) {
                    pivot.label = 'HH';  // Higher High
                } else {
                    pivot.label = 'LH';  // Lower High
                }
                // 更新lastPrice为上一个高点的价格
                if (i >= 2 && pivots[i - 2].type === 'high') {
                    lastPrice = pivots[i - 2].price;
                } else {
                    lastPrice = pivot.price;
                }
            } else {
                // 比较当前低点与上一个低点
                if (pivot.price < lastPrice) {
                    pivot.label = 'LL';  // Lower Low
                } else {
                    pivot.label = 'HL';  // Higher Low
                }
                // 更新lastPrice为上一个低点的价格
                if (i >= 2 && pivots[i - 2].type === 'low') {
                    lastPrice = pivots[i - 2].price;
                } else {
                    lastPrice = pivot.price;
                }
            }
        }
    }
    
    // 5. 生成连接线数据
    const lines = [];
    for (let i = 0; i < pivots.length - 1; i++) {
        lines.push({
            from: pivots[i],
            to: pivots[i + 1],
            direction: pivots[i + 1].type === 'high' ? 1 : -1  // 1: 上涨, -1: 下跌
        });
    }
    
    const currentDirection = pivots.length > 0 ? (pivots[pivots.length - 1].type === 'high' ? -1 : 1) : 0;
    
    console.log('✅ [ZigZag++] 计算完成');
    console.log(`   - 检测到转折点: ${pivots.length}`);
    console.log(`   - 连接线段: ${lines.length}`);
    console.log(`   - 当前方向: ${currentDirection > 0 ? '上涨' : currentDirection < 0 ? '下跌' : '未知'}`);
    
    return {
        pivots: pivots,
        lines: lines,
        direction: currentDirection,
        renderType: 'zigzag'
    };
}

