/// 技术指标计算工具类
/// 提供专业级的技术分析指标计算
import 'dart:math';

/// MA均线计算结果
class MAResult {
  final List<double> values;
  MAResult(this.values);
}

/// MACD计算结果
class MACDResult {
  final List<double> dif;   // 差离值
  final List<double> dea;   // 信号线
  final List<double> macd;  // 柱状图
  
  MACDResult(this.dif, this.dea, this.macd);
}

/// 布林带计算结果
class BOLLResult {
  final List<double> upper;  // 上轨
  final List<double> middle; // 中轨
  final List<double> lower;  // 下轨
  
  BOLLResult(this.upper, this.middle, this.lower);
}

/// KDJ计算结果
class KDJResult {
  final List<double> k;
  final List<double> d;
  final List<double> j;
  
  KDJResult(this.k, this.d, this.j);
}

/// 技术指标计算器
class TechnicalIndicatorCalculator {
  /// 计算MA均线
  /// [prices] 价格序列（通常是收盘价）
  /// [period] 周期（如5、10、20、60）
  static MAResult calculateMA(List<double> prices, int period) {
    List<double> ma = [];
    
    for (int i = 0; i < prices.length; i++) {
      if (i < period - 1) {
        ma.add(double.nan); // 数据不足，填充NaN
      } else {
        double sum = 0;
        for (int j = 0; j < period; j++) {
          sum += prices[i - j];
        }
        ma.add(sum / period);
      }
    }
    
    return MAResult(ma);
  }
  
  /// 计算EMA指数移动平均
  /// [prices] 价格序列
  /// [period] 周期
  static List<double> calculateEMA(List<double> prices, int period) {
    List<double> ema = [];
    if (prices.isEmpty) return ema;
    
    double multiplier = 2.0 / (period + 1);
    
    // 第一个EMA值使用SMA
    double sum = 0;
    int count = min(period, prices.length);
    for (int i = 0; i < count; i++) {
      sum += prices[i];
    }
    double firstEMA = sum / count;
    
    // 填充前面的值
    for (int i = 0; i < count - 1; i++) {
      ema.add(double.nan);
    }
    ema.add(firstEMA);
    
    // 计算后续EMA值
    for (int i = count; i < prices.length; i++) {
      double value = (prices[i] - ema.last) * multiplier + ema.last;
      ema.add(value);
    }
    
    return ema;
  }
  
  /// 计算MACD指标
  /// [prices] 价格序列（收盘价）
  /// [fastPeriod] 快线周期，默认12
  /// [slowPeriod] 慢线周期，默认26
  /// [signalPeriod] 信号线周期，默认9
  static MACDResult calculateMACD(
    List<double> prices, {
    int fastPeriod = 12,
    int slowPeriod = 26,
    int signalPeriod = 9,
  }) {
    // 计算快线和慢线EMA
    final ema12 = calculateEMA(prices, fastPeriod);
    final ema26 = calculateEMA(prices, slowPeriod);
    
    // 计算DIF（差离值）
    List<double> dif = [];
    for (int i = 0; i < prices.length; i++) {
      if (ema12[i].isNaN || ema26[i].isNaN) {
        dif.add(double.nan);
      } else {
        dif.add(ema12[i] - ema26[i]);
      }
    }
    
    // 计算DEA（信号线）- DIF的EMA
    final validDif = dif.where((v) => !v.isNaN).toList();
    final dea = calculateEMA(validDif, signalPeriod);
    
    // 补齐DEA长度，确保与prices长度一致
    List<double> deaFull = [];
    int nanCount = dif.where((v) => v.isNaN).length;
    for (int i = 0; i < nanCount; i++) {
      deaFull.add(double.nan);
    }
    deaFull.addAll(dea);
    
    // 如果deaFull长度不足，补充NaN
    while (deaFull.length < prices.length) {
      deaFull.add(double.nan);
    }
    
    // 如果deaFull长度超过，截断
    if (deaFull.length > prices.length) {
      deaFull = deaFull.sublist(0, prices.length);
    }
    
    // 计算MACD柱状图
    List<double> macd = [];
    for (int i = 0; i < prices.length; i++) {
      if (dif[i].isNaN || deaFull[i].isNaN) {
        macd.add(double.nan);
      } else {
        macd.add((dif[i] - deaFull[i]) * 2);
      }
    }
    
    return MACDResult(dif, deaFull, macd);
  }
  
  /// 计算RSI相对强弱指标
  /// [prices] 价格序列
  /// [period] 周期，默认14
  static List<double> calculateRSI(List<double> prices, {int period = 14}) {
    List<double> rsi = [];
    
    if (prices.length < period + 1) {
      return List.filled(prices.length, double.nan);
    }
    
    for (int i = 0; i < prices.length; i++) {
      if (i < period) {
        rsi.add(double.nan);
        continue;
      }
      
      double gainSum = 0;
      double lossSum = 0;
      
      for (int j = 1; j <= period; j++) {
        double change = prices[i - j + 1] - prices[i - j];
        if (change > 0) {
          gainSum += change;
        } else {
          lossSum += change.abs();
        }
      }
      
      double avgGain = gainSum / period;
      double avgLoss = lossSum / period;
      
      if (avgLoss == 0) {
        rsi.add(100);
      } else {
        double rs = avgGain / avgLoss;
        rsi.add(100 - (100 / (1 + rs)));
      }
    }
    
    return rsi;
  }
  
  /// 计算布林带
  /// [prices] 价格序列
  /// [period] 周期，默认20
  /// [stdDev] 标准差倍数，默认2
  static BOLLResult calculateBOLL(
    List<double> prices, {
    int period = 20,
    double stdDev = 2.0,
  }) {
    final middle = calculateMA(prices, period).values;
    List<double> upper = [];
    List<double> lower = [];
    
    for (int i = 0; i < prices.length; i++) {
      if (i < period - 1 || middle[i].isNaN) {
        upper.add(double.nan);
        lower.add(double.nan);
      } else {
        // 计算标准差
        double sum = 0;
        for (int j = 0; j < period; j++) {
          sum += pow(prices[i - j] - middle[i], 2);
        }
        double std = sqrt(sum / period);
        
        upper.add(middle[i] + stdDev * std);
        lower.add(middle[i] - stdDev * std);
      }
    }
    
    return BOLLResult(upper, middle, lower);
  }
  
  /// 计算KDJ指标
  /// [closes] 收盘价序列
  /// [highs] 最高价序列
  /// [lows] 最低价序列
  /// [period] 周期，默认9
  /// [kSmooth] K值平滑参数，默认3
  /// [dSmooth] D值平滑参数，默认3
  static KDJResult calculateKDJ(
    List<double> closes,
    List<double> highs,
    List<double> lows, {
    int period = 9,
    int kSmooth = 3,
    int dSmooth = 3,
  }) {
    List<double> k = [];
    List<double> d = [];
    List<double> j = [];
    
    double prevK = 50;
    double prevD = 50;
    
    for (int i = 0; i < closes.length; i++) {
      if (i < period - 1) {
        k.add(double.nan);
        d.add(double.nan);
        j.add(double.nan);
        continue;
      }
      
      // 计算RSV（未成熟随机值）
      double highest = highs[i];
      double lowest = lows[i];
      for (int m = 1; m < period; m++) {
        if (highs[i - m] > highest) highest = highs[i - m];
        if (lows[i - m] < lowest) lowest = lows[i - m];
      }
      
      double rsv = 50; // 默认值
      if (highest != lowest) {
        rsv = (closes[i] - lowest) / (highest - lowest) * 100;
      }
      
      // 计算K值（RSV的移动平均）
      double kValue = (prevK * (kSmooth - 1) + rsv) / kSmooth;
      
      // 计算D值（K值的移动平均）
      double dValue = (prevD * (dSmooth - 1) + kValue) / dSmooth;
      
      // 计算J值
      double jValue = 3 * kValue - 2 * dValue;
      
      k.add(kValue);
      d.add(dValue);
      j.add(jValue);
      
      prevK = kValue;
      prevD = dValue;
    }
    
    return KDJResult(k, d, j);
  }
  
  /// 计算ATR平均真实波幅
  /// [highs] 最高价序列
  /// [lows] 最低价序列
  /// [closes] 收盘价序列
  /// [period] 周期，默认14
  static List<double> calculateATR(
    List<double> highs,
    List<double> lows,
    List<double> closes, {
    int period = 14,
  }) {
    List<double> atr = [];
    List<double> tr = [];
    
    // 计算真实波幅TR
    for (int i = 0; i < closes.length; i++) {
      if (i == 0) {
        tr.add(highs[i] - lows[i]);
      } else {
        double tr1 = highs[i] - lows[i];
        double tr2 = (highs[i] - closes[i - 1]).abs();
        double tr3 = (lows[i] - closes[i - 1]).abs();
        tr.add(max(tr1, max(tr2, tr3)));
      }
    }
    
    // 计算ATR（TR的移动平均）
    for (int i = 0; i < tr.length; i++) {
      if (i < period - 1) {
        atr.add(double.nan);
      } else if (i == period - 1) {
        // 第一个ATR值使用简单平均
        double sum = 0;
        for (int j = 0; j < period; j++) {
          sum += tr[i - j];
        }
        atr.add(sum / period);
      } else {
        // 后续ATR值使用平滑计算
        atr.add((atr.last * (period - 1) + tr[i]) / period);
      }
    }
    
    return atr;
  }
}

