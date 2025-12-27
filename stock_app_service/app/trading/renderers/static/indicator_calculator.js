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
    
    // 多指标背离检测（前端计算）
    'divergence_detector': calculateDivergenceDetector
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
        calculateDivergenceDetector
    };
}

