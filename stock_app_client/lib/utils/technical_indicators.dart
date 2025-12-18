/// 技术指标计算工具类
/// 用于计算EMA、RSI、MACD、布林带等技术指标
library;

import 'dart:math';

class TechnicalIndicators {
  /// 计算EMA (指数移动平均线)
  /// [prices] 价格列表
  /// [period] 周期
  static List<double?> calculateEMA(List<double> prices, int period) {
    if (prices.isEmpty || period <= 0) return [];
    
    final ema = List<double?>.filled(prices.length, null);
    final multiplier = 2.0 / (period + 1);
    
    // 第一个EMA使用SMA
    double sum = 0;
    for (int i = 0; i < period && i < prices.length; i++) {
      sum += prices[i];
    }
    ema[period - 1] = sum / period;
    
    // 计算后续EMA
    for (int i = period; i < prices.length; i++) {
      ema[i] = (prices[i] - ema[i - 1]!) * multiplier + ema[i - 1]!;
    }
    
    return ema;
  }
  
  /// 计算SMA (简单移动平均线)
  /// [prices] 价格列表
  /// [period] 周期
  static List<double?> calculateSMA(List<double> prices, int period) {
    if (prices.isEmpty || period <= 0) return [];
    
    final sma = List<double?>.filled(prices.length, null);
    
    for (int i = period - 1; i < prices.length; i++) {
      double sum = 0;
      for (int j = 0; j < period; j++) {
        sum += prices[i - j];
      }
      sma[i] = sum / period;
    }
    
    return sma;
  }
  
  /// 计算RSI (相对强弱指标)
  /// [prices] 价格列表
  /// [period] 周期，默认14
  static List<double?> calculateRSI(List<double> prices, {int period = 14}) {
    if (prices.length < period + 1) return [];
    
    final rsi = List<double?>.filled(prices.length, null);
    double avgGain = 0;
    double avgLoss = 0;
    
    // 计算初始平均涨跌幅
    for (int i = 1; i <= period; i++) {
      final change = prices[i] - prices[i - 1];
      if (change > 0) {
        avgGain += change;
      } else {
        avgLoss += change.abs();
      }
    }
    avgGain /= period;
    avgLoss /= period;
    
    // 计算第一个RSI
    if (avgLoss == 0) {
      rsi[period] = 100;
    } else {
      final rs = avgGain / avgLoss;
      rsi[period] = 100 - (100 / (1 + rs));
    }
    
    // 计算后续RSI
    for (int i = period + 1; i < prices.length; i++) {
      final change = prices[i] - prices[i - 1];
      final gain = change > 0 ? change : 0;
      final loss = change < 0 ? change.abs() : 0;
      
      avgGain = (avgGain * (period - 1) + gain) / period;
      avgLoss = (avgLoss * (period - 1) + loss) / period;
      
      if (avgLoss == 0) {
        rsi[i] = 100;
      } else {
        final rs = avgGain / avgLoss;
        rsi[i] = 100 - (100 / (1 + rs));
      }
    }
    
    return rsi;
  }
  
  /// 计算MACD (指数平滑异同移动平均线)
  /// [prices] 价格列表
  /// [fastPeriod] 快线周期，默认12
  /// [slowPeriod] 慢线周期，默认26
  /// [signalPeriod] 信号线周期，默认9
  /// 返回 {macd, signal, histogram}
  static Map<String, List<double?>> calculateMACD(
    List<double> prices, {
    int fastPeriod = 12,
    int slowPeriod = 26,
    int signalPeriod = 9,
  }) {
    final fastEMA = calculateEMA(prices, fastPeriod);
    final slowEMA = calculateEMA(prices, slowPeriod);
    
    // 计算MACD线 (DIF)
    final macdLine = List<double?>.filled(prices.length, null);
    for (int i = 0; i < prices.length; i++) {
      if (fastEMA[i] != null && slowEMA[i] != null) {
        macdLine[i] = fastEMA[i]! - slowEMA[i]!;
      }
    }
    
    // 计算信号线 (DEA) - MACD的EMA
    final macdValues = macdLine.whereType<double>().toList();
    final signalEMA = calculateEMA(macdValues, signalPeriod);
    
    final signalLine = List<double?>.filled(prices.length, null);
    int signalIndex = 0;
    for (int i = 0; i < prices.length; i++) {
      if (macdLine[i] != null) {
        if (signalIndex < signalEMA.length && signalEMA[signalIndex] != null) {
          signalLine[i] = signalEMA[signalIndex];
        }
        signalIndex++;
      }
    }
    
    // 计算柱状图 (MACD - Signal)
    final histogram = List<double?>.filled(prices.length, null);
    for (int i = 0; i < prices.length; i++) {
      if (macdLine[i] != null && signalLine[i] != null) {
        histogram[i] = macdLine[i]! - signalLine[i]!;
      }
    }
    
    return {
      'macd': macdLine,
      'signal': signalLine,
      'histogram': histogram,
    };
  }
  
  /// 计算布林带 (Bollinger Bands)
  /// [prices] 价格列表
  /// [period] 周期，默认20
  /// [stdDev] 标准差倍数，默认2
  /// 返回 {upper, middle, lower}
  static Map<String, List<double?>> calculateBollingerBands(
    List<double> prices, {
    int period = 20,
    double stdDev = 2.0,
  }) {
    final middle = calculateSMA(prices, period);
    final upper = List<double?>.filled(prices.length, null);
    final lower = List<double?>.filled(prices.length, null);
    
    for (int i = period - 1; i < prices.length; i++) {
      // 计算标准差
      double sum = 0;
      for (int j = 0; j < period; j++) {
        sum += pow(prices[i - j] - middle[i]!, 2);
      }
      final std = sqrt(sum / period);
      
      upper[i] = middle[i]! + (stdDev * std);
      lower[i] = middle[i]! - (stdDev * std);
    }
    
    return {
      'upper': upper,
      'middle': middle,
      'lower': lower,
    };
  }
  
  /// 计算ATR (平均真实波幅)
  /// [highs] 最高价列表
  /// [lows] 最低价列表
  /// [closes] 收盘价列表
  /// [period] 周期，默认14
  static List<double?> calculateATR(
    List<double> highs,
    List<double> lows,
    List<double> closes, {
    int period = 14,
  }) {
    if (highs.length != lows.length || highs.length != closes.length) {
      return [];
    }
    
    final tr = <double>[];
    
    // 计算真实波幅
    for (int i = 1; i < closes.length; i++) {
      final high = highs[i];
      final low = lows[i];
      final prevClose = closes[i - 1];
      
      final tr1 = high - low;
      final tr2 = (high - prevClose).abs();
      final tr3 = (low - prevClose).abs();
      
      tr.add(max(tr1, max(tr2, tr3)));
    }
    
    // 计算ATR (使用SMA)
    final atr = List<double?>.filled(closes.length, null);
    
    if (tr.length >= period) {
      double sum = 0;
      for (int i = 0; i < period; i++) {
        sum += tr[i];
      }
      atr[period] = sum / period;
      
      // 使用Wilder's平滑方法
      for (int i = period + 1; i < closes.length; i++) {
        atr[i] = (atr[i - 1]! * (period - 1) + tr[i - 1]) / period;
      }
    }
    
    return atr;
  }
  
  /// 判断趋势方向
  /// [ema5] 5日EMA
  /// [ema10] 10日EMA
  /// [ema20] 20日EMA
  /// [ema60] 60日EMA
  /// 返回: 'strong_up', 'up', 'neutral', 'down', 'strong_down'
  static String analyzeTrend(
    double? ema5,
    double? ema10,
    double? ema20,
    double? ema60,
  ) {
    if (ema5 == null || ema10 == null || ema20 == null || ema60 == null) {
      return 'neutral';
    }
    
    // 多头排列：短期均线在上，长期均线在下
    if (ema5 > ema10 && ema10 > ema20 && ema20 > ema60) {
      return 'strong_up';
    }
    
    // 空头排列：短期均线在下，长期均线在上
    if (ema5 < ema10 && ema10 < ema20 && ema20 < ema60) {
      return 'strong_down';
    }
    
    // 部分多头
    if (ema5 > ema10 && ema10 > ema20) {
      return 'up';
    }
    
    // 部分空头
    if (ema5 < ema10 && ema10 < ema20) {
      return 'down';
    }
    
    return 'neutral';
  }
  
  /// 分析RSI状态
  /// [rsi] RSI值
  /// 返回: 'overbought', 'neutral', 'oversold'
  static String analyzeRSI(double? rsi) {
    if (rsi == null) return 'neutral';
    
    if (rsi > 70) return 'overbought'; // 超买
    if (rsi < 30) return 'oversold';   // 超卖
    return 'neutral';
  }
  
  /// 分析MACD状态
  /// [macd] MACD值
  /// [signal] 信号线值
  /// [histogram] 柱状图值
  /// 返回: 'bullish', 'bearish', 'neutral'
  static String analyzeMACDSignal(
    double? macd,
    double? signal,
    double? histogram,
  ) {
    if (macd == null || signal == null || histogram == null) {
      return 'neutral';
    }
    
    // 金叉：MACD上穿信号线
    if (macd > signal && histogram > 0) {
      return 'bullish';
    }
    
    // 死叉：MACD下穿信号线
    if (macd < signal && histogram < 0) {
      return 'bearish';
    }
    
    return 'neutral';
  }
  
  /// 计算支撑位和阻力位
  /// [highs] 最高价列表
  /// [lows] 最低价列表
  /// [period] 回溯周期，默认20
  /// 返回 {support, resistance}
  /// 计算支撑阻力位（专业版 - 优化算法）
  /// 基于多种方法综合判断，返回多个关键价位
  /// [highs] 最高价列表
  /// [lows] 最低价列表
  /// [closes] 收盘价列表
  /// [period] 计算周期（日线建议60天以上）
  /// 返回: {support1, support2, support3, resistance1, resistance2, resistance3}
  static Map<String, double> calculateSupportResistance(
    List<double> highs,
    List<double> lows, {
    List<double>? closes,
    int period = 60, // 改为60天，更适合日线分析
  }) {
    if (highs.isEmpty || lows.isEmpty || highs.length < 30) {
      return {
        'support': 0,
        'resistance': 0,
        'support1': 0,
        'support2': 0,
        'support3': 0,
        'resistance1': 0,
        'resistance2': 0,
        'resistance3': 0,
      };
    }
    
    final currentPrice = closes != null && closes.isNotEmpty ? closes.last : (highs.last + lows.last) / 2;
    
    // 使用更长的历史数据来寻找关键价位
    final lookbackPeriod = min(period, highs.length);
    final start = max(0, highs.length - lookbackPeriod);
    
    // 方法1：寻找重要的波峰波谷（使用更大的lookback）
    final pivotHighs = _findPivotPoints(highs.sublist(start), 8, true); // 使用8天判断波峰
    final pivotLows = _findPivotPoints(lows.sublist(start), 8, false); // 使用8天判断波谷
    
    // 方法2：基于最近的高低点
    final recentHighs = highs.sublist(start);
    final recentLows = lows.sublist(start);
    
    // 收集所有可能的阻力位（高于当前价）
    final resistanceCandidates = <double>[];
    resistanceCandidates.addAll(pivotHighs.where((h) => h > currentPrice * 1.005)); // 至少高于当前价0.5%
    resistanceCandidates.add(recentHighs.reduce(max)); // 最近最高价
    
    // 收集所有可能的支撑位（低于当前价）
    final supportCandidates = <double>[];
    supportCandidates.addAll(pivotLows.where((l) => l < currentPrice * 0.995)); // 至少低于当前价0.5%
    supportCandidates.add(recentLows.reduce(min)); // 最近最低价
    
    // 方法3：加入均线作为动态支撑阻力（重要！）
    if (closes != null && closes.length >= 20) {
      final ma20 = calculateSMA(closes, 20);
      final ma60 = calculateSMA(closes, 60);
      final ma120 = closes.length >= 120 ? calculateSMA(closes, 120) : null;
      
      if (ma20.last != null) {
        final ma20Value = ma20.last!;
        if (ma20Value > currentPrice * 1.005) {
          resistanceCandidates.add(ma20Value);
        } else if (ma20Value < currentPrice * 0.995) {
          supportCandidates.add(ma20Value);
        }
      }
      
      if (ma60.last != null) {
        final ma60Value = ma60.last!;
        if (ma60Value > currentPrice * 1.005) {
          resistanceCandidates.add(ma60Value);
        } else if (ma60Value < currentPrice * 0.995) {
          supportCandidates.add(ma60Value);
        }
      }
      
      if (ma120 != null && ma120.last != null) {
        final ma120Value = ma120.last!;
        if (ma120Value > currentPrice * 1.005) {
          resistanceCandidates.add(ma120Value);
        } else if (ma120Value < currentPrice * 0.995) {
          supportCandidates.add(ma120Value);
        }
      }
    }
    
    // 方法4：识别整数关口（心理价位）
    final nearestRoundNumbers = _findNearbyRoundNumbers(currentPrice);
    for (final price in nearestRoundNumbers) {
      if (price > currentPrice * 1.005) {
        resistanceCandidates.add(price);
      } else if (price < currentPrice * 0.995) {
        supportCandidates.add(price);
      }
    }
    
    // 去重并按距离当前价排序
    final uniqueResistances = resistanceCandidates.toSet().toList()
      ..sort((a, b) => a.compareTo(b)); // 升序：最近的阻力位在前
    
    final uniqueSupports = supportCandidates.toSet().toList()
      ..sort((a, b) => b.compareTo(a)); // 降序：最近的支撑位在前
    
    // 选择最合理的支撑阻力位（优先选择距离当前价3-8%的位置）
    double? findBestLevel(List<double> candidates, bool isResistance) {
      if (candidates.isEmpty) return null;
      
      // 优先选择距离合理的价位（3-8%）
      for (final candidate in candidates) {
        final diff = ((candidate - currentPrice).abs() / currentPrice * 100);
        if (diff >= 3 && diff <= 8) {
          return candidate;
        }
      }
      
      // 如果没有3-8%范围的，选择最近的
      return candidates.first;
    }
    
    double resistance1, resistance2, resistance3;
    double support1, support2, support3;
    
    // 阻力位：至少要高于当前价2%以上才有意义
    if (uniqueResistances.isNotEmpty) {
      resistance1 = findBestLevel(uniqueResistances, true) ?? uniqueResistances.first;
      final remaining = uniqueResistances.where((r) => r > resistance1 * 1.01).toList();
      resistance2 = remaining.isNotEmpty ? remaining.first : currentPrice * 1.10;
      final remaining2 = remaining.where((r) => r > resistance2 * 1.01).toList();
      resistance3 = remaining2.isNotEmpty ? remaining2.first : currentPrice * 1.15;
    } else {
      // 如果找不到合适的阻力位，使用合理的默认值
      resistance1 = currentPrice * 1.05; // 5%
      resistance2 = currentPrice * 1.10; // 10%
      resistance3 = currentPrice * 1.15; // 15%
    }
    
    // 支撑位：至少要低于当前价2%以上才有意义
    if (uniqueSupports.isNotEmpty) {
      support1 = findBestLevel(uniqueSupports, false) ?? uniqueSupports.first;
      final remaining = uniqueSupports.where((s) => s < support1 * 0.99).toList();
      support2 = remaining.isNotEmpty ? remaining.first : currentPrice * 0.93;
      final remaining2 = remaining.where((s) => s < support2 * 0.99).toList();
      support3 = remaining2.isNotEmpty ? remaining2.first : currentPrice * 0.88;
    } else {
      // 如果找不到合适的支撑位，使用合理的默认值
      support1 = currentPrice * 0.95; // -5%
      support2 = currentPrice * 0.92; // -8%
      support3 = currentPrice * 0.88; // -12%
    }
    
    // 🚨 关键修复：确保止损位不会离当前价太远
    // 如果第1支撑位距离当前价超过8%，调整为当前价-5%
    if ((currentPrice - support1) / currentPrice > 0.08) {
      support1 = currentPrice * 0.95; // 强制设为-5%
      print('⚠️ 支撑位调整：原值距离过远，调整为-5%');
    }
    
    // 如果第2支撑位距离当前价超过10%，调整
    if ((currentPrice - support2) / currentPrice > 0.10) {
      support2 = currentPrice * 0.92; // 强制设为-8%
    }
    
    return {
      'support': support1, // 最近支撑位（兼容旧版）
      'resistance': resistance1, // 最近阻力位（兼容旧版）
      'support1': support1,
      'support2': support2,
      'support3': support3,
      'resistance1': resistance1,
      'resistance2': resistance2,
      'resistance3': resistance3,
      // 附加信息：距离百分比
      'support1_pct': ((support1 - currentPrice) / currentPrice * 100),
      'resistance1_pct': ((resistance1 - currentPrice) / currentPrice * 100),
    };
  }
  
  /// 寻找附近的整数关口（心理价位）
  static List<double> _findNearbyRoundNumbers(double price) {
    final results = <double>[];
    
    // 找出价格所在的数量级
    if (price >= 100) {
      // 100元以上：找10元的整数倍
      final base = (price / 10).floor() * 10;
      for (int i = -2; i <= 2; i++) {
        final roundPrice = base + (i * 10);
        if (roundPrice > 0 && (roundPrice - price).abs() / price < 0.15) {
          results.add(roundPrice.toDouble());
        }
      }
    } else if (price >= 10) {
      // 10-100元：找5元的整数倍
      final base = (price / 5).floor() * 5;
      for (int i = -2; i <= 2; i++) {
        final roundPrice = base + (i * 5);
        if (roundPrice > 0 && (roundPrice - price).abs() / price < 0.15) {
          results.add(roundPrice.toDouble());
        }
      }
    } else {
      // 10元以下：找1元的整数倍
      final base = price.floor();
      for (int i = -2; i <= 2; i++) {
        final roundPrice = base + i;
        if (roundPrice > 0 && (roundPrice - price).abs() / price < 0.15) {
          results.add(roundPrice.toDouble());
        }
      }
    }
    
    return results;
  }
  
  /// 寻找局部高低点（波峰波谷）
  /// [prices] 价格列表
  /// [period] 左右查看的周期
  /// [findHighs] true=寻找波峰，false=寻找波谷
  static List<double> _findPivotPoints(List<double> prices, int period, bool findHighs) {
    final pivots = <double>[];
    final lookback = min(5, period ~/ 4); // 左右各看5根K线
    
    for (int i = lookback; i < prices.length - lookback; i++) {
      bool isPivot = true;
      
      // 检查左右是否形成波峰或波谷
      for (int j = 1; j <= lookback; j++) {
        if (findHighs) {
          // 寻找波峰：当前价格应该高于左右的价格
          if (prices[i] <= prices[i - j] || prices[i] <= prices[i + j]) {
            isPivot = false;
            break;
          }
        } else {
          // 寻找波谷：当前价格应该低于左右的价格
          if (prices[i] >= prices[i - j] || prices[i] >= prices[i + j]) {
            isPivot = false;
            break;
          }
        }
      }
      
      if (isPivot) {
        pivots.add(prices[i]);
      }
    }
    
    return pivots;
  }
}

