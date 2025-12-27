/**
 * 多指标背离检测器 - JavaScript实现
 * 
 * 移植自Python版本的divergence_detector.py
 * 检测MACD、RSI、Stoch、CCI、Momentum等指标与价格之间的背离
 * 
 * 性能优化：前端计算，不占用服务器资源
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

// ============================================================================
// Pivot点检测
// ============================================================================

/**
 * 找到价格Pivot High点
 */
function findPricePivotHighs(candleData, pivotPeriod) {
    const pivots = [];
    
    for (let i = pivotPeriod; i < candleData.length - pivotPeriod; i++) {
        const centerHigh = candleData[i].high;
        let isPivot = true;
        
        // Check left
        for (let j = i - pivotPeriod; j < i; j++) {
            if (candleData[j].high >= centerHigh) {
                isPivot = false;
                break;
            }
        }
        
        if (!isPivot) continue;
        
        // Check right
        for (let j = i + 1; j <= i + pivotPeriod; j++) {
            if (candleData[j].high >= centerHigh) {
                isPivot = false;
                break;
            }
        }
        
        if (isPivot) {
            pivots.push({ index: i, value: centerHigh });
        }
    }
    
    return pivots;
}

/**
 * 找到价格Pivot Low点
 */
function findPricePivotLows(candleData, pivotPeriod) {
    const pivots = [];
    
    for (let i = pivotPeriod; i < candleData.length - pivotPeriod; i++) {
        const centerLow = candleData[i].low;
        let isPivot = true;
        
        // Check left
        for (let j = i - pivotPeriod; j < i; j++) {
            if (candleData[j].low <= centerLow) {
                isPivot = false;
                break;
            }
        }
        
        if (!isPivot) continue;
        
        // Check right
        for (let j = i + 1; j <= i + pivotPeriod; j++) {
            if (candleData[j].low <= centerLow) {
                isPivot = false;
                break;
            }
        }
        
        if (isPivot) {
            pivots.push({ index: i, value: centerLow });
        }
    }
    
    return pivots;
}

/**
 * 找到指标Pivot点
 */
function findIndicatorPivots(values, pivotPeriod, isHigh) {
    const pivots = [];
    
    for (let i = pivotPeriod; i < values.length - pivotPeriod; i++) {
        if (isNaN(values[i])) continue;
        
        const centerValue = values[i];
        let isPivot = true;
        
        // Check left and right
        for (let j = i - pivotPeriod; j < i; j++) {
            if (isNaN(values[j])) continue;
            if (isHigh ? values[j] >= centerValue : values[j] <= centerValue) {
                isPivot = false;
                break;
            }
        }
        
        if (!isPivot) continue;
        
        for (let j = i + 1; j <= i + pivotPeriod; j++) {
            if (isNaN(values[j])) continue;
            if (isHigh ? values[j] >= centerValue : values[j] <= centerValue) {
                isPivot = false;
                break;
            }
        }
        
        if (isPivot) {
            pivots.push({ index: i, value: centerValue });
        }
    }
    
    return pivots;
}

// ============================================================================
// 背离检测
// ============================================================================

/**
 * 检测正常背离（Regular Divergence）
 * 看涨背离：价格创新低，指标未创新低
 * 看跌背离：价格创新高，指标未创新高
 */
function detectRegularDivergences(candleData, indicatorValues, pricePivotHighs, pricePivotLows, 
                                 maxPivotPoints, maxBars, indicatorName) {
    const divergences = [];
    
    // 检测看涨背离（Bullish）- 价格新低，指标未新低
    const indicatorPivotLows = findIndicatorPivots(indicatorValues, 5, false);
    
    for (let i = 0; i < pricePivotLows.length - 1; i++) {
        const pivot1 = pricePivotLows[i];
        
        for (let j = i + 1; j < Math.min(pricePivotLows.length, i + maxPivotPoints); j++) {
            const pivot2 = pricePivotLows[j];
            
            if (pivot2.index - pivot1.index > maxBars) break;
            
            // 价格创新低
            if (pivot2.value < pivot1.value) {
                // 找对应的指标pivot
                const indPivot1 = indicatorPivotLows.find(p => Math.abs(p.index - pivot1.index) <= 3);
                const indPivot2 = indicatorPivotLows.find(p => Math.abs(p.index - pivot2.index) <= 3);
                
                if (indPivot1 && indPivot2 && !isNaN(indPivot1.value) && !isNaN(indPivot2.value)) {
                    // 指标未创新低 = 背离
                    if (indPivot2.value > indPivot1.value) {
                        divergences.push({
                            type: 'bullish',
                            indicator: indicatorName,
                            start_index: pivot1.index,
                            end_index: pivot2.index,
                            start_price: pivot1.value,
                            end_price: pivot2.value,
                            start_ind_value: indPivot1.value,
                            end_ind_value: indPivot2.value
                        });
                    }
                }
            }
        }
    }
    
    // 检测看跌背离（Bearish）- 价格新高，指标未新高
    const indicatorPivotHighs = findIndicatorPivots(indicatorValues, 5, true);
    
    for (let i = 0; i < pricePivotHighs.length - 1; i++) {
        const pivot1 = pricePivotHighs[i];
        
        for (let j = i + 1; j < Math.min(pricePivotHighs.length, i + maxPivotPoints); j++) {
            const pivot2 = pricePivotHighs[j];
            
            if (pivot2.index - pivot1.index > maxBars) break;
            
            // 价格创新高
            if (pivot2.value > pivot1.value) {
                // 找对应的指标pivot
                const indPivot1 = indicatorPivotHighs.find(p => Math.abs(p.index - pivot1.index) <= 3);
                const indPivot2 = indicatorPivotHighs.find(p => Math.abs(p.index - pivot2.index) <= 3);
                
                if (indPivot1 && indPivot2 && !isNaN(indPivot1.value) && !isNaN(indPivot2.value)) {
                    // 指标未创新高 = 背离
                    if (indPivot2.value < indPivot1.value) {
                        divergences.push({
                            type: 'bearish',
                            indicator: indicatorName,
                            start_index: pivot1.index,
                            end_index: pivot2.index,
                            start_price: pivot1.value,
                            end_price: pivot2.value,
                            start_ind_value: indPivot1.value,
                            end_ind_value: indPivot2.value
                        });
                    }
                }
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
    
    // 按end_index分组
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
        const labelText = `${firstDiv.type === 'bullish' ? '看涨' : '看跌'}背离: ${indicators}`;
        
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
    indicators['CMF'] = calculateCMF(candleData, 21);
    indicators['MFI'] = calculateMFI(candleData, 14);
    
    console.log('✅ [背离检测] 指标计算完成，共', Object.keys(indicators).length, '个');
    
    // 找pivot点
    const pricePivotHighs = findPricePivotHighs(candleData, pivot_period);
    const pricePivotLows = findPricePivotLows(candleData, pivot_period);
    
    console.log('✅ [背离检测] Pivot点检测完成，高点:', pricePivotHighs.length, '低点:', pricePivotLows.length);
    
    // 检测背离
    const allDivergences = [];
    
    for (const [indicatorName, indicatorValues] of Object.entries(indicators)) {
        const divs = detectRegularDivergences(
            candleData, 
            indicatorValues, 
            pricePivotHighs, 
            pricePivotLows,
            max_pivot_points, 
            max_bars, 
            indicatorName
        );
        allDivergences.push(...divs);
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

