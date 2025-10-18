import '../../models/trade_record.dart';

/// 交易计算服务
/// 
/// 提供所有交易相关的计算功能
class TradeCalculationService {
  /// 计算盈亏比
  /// 
  /// 盈亏比 = (止盈价 - 计划价) / (计划价 - 止损价)
  static double calculateProfitRiskRatio({
    required double planPrice,
    required double? stopLoss,
    required double? takeProfit,
    required TradeType tradeType,
  }) {
    if (stopLoss == null || takeProfit == null || planPrice <= 0) {
      return 0.0;
    }

    double risk;
    double profit;

    if (tradeType == TradeType.buy) {
      risk = planPrice - stopLoss;
      profit = takeProfit - planPrice;
    } else {
      risk = stopLoss - planPrice;
      profit = planPrice - takeProfit;
    }

    if (risk <= 0) return 0.0;
    return profit / risk;
  }

  /// 计算仓位（按比例）
  /// 
  /// 仓位 = (账户余额 * 仓位比例) / 计划价格
  static int calculatePositionByPercentage({
    required double planPrice,
    required double percentage,
    required double accountBalance,
  }) {
    if (planPrice <= 0 || percentage <= 0 || accountBalance <= 0) {
      return 0;
    }

    final positionValue = accountBalance * (percentage / 100);
    final quantity = (positionValue / planPrice).floor();
    
    // 确保是100的整数倍（A股交易规则）
    return (quantity ~/ 100) * 100;
  }

  /// 计算仓位（以损定仓）
  /// 
  /// 仓位 = (账户余额 * 风险比例) / (计划价 - 止损价)
  static int calculatePositionByRisk({
    required double planPrice,
    required double stopLoss,
    required double riskPercentage,
    required double accountBalance,
    required TradeType tradeType,
  }) {
    if (planPrice <= 0 || stopLoss <= 0 || riskPercentage <= 0 || accountBalance <= 0) {
      return 0;
    }

    final riskAmount = accountBalance * (riskPercentage / 100);
    double priceRisk;

    if (tradeType == TradeType.buy) {
      priceRisk = planPrice - stopLoss;
    } else {
      priceRisk = stopLoss - planPrice;
    }

    if (priceRisk <= 0) return 0;

    final quantity = (riskAmount / priceRisk).floor();
    
    // 确保是100的整数倍（A股交易规则）
    return (quantity ~/ 100) * 100;
  }

  /// 计算ATR止损价
  /// 
  /// 买入: 止损价 = 计划价 - (ATR * 倍数)
  /// 卖出: 止损价 = 计划价 + (ATR * 倍数)
  static double calculateAtrStopLoss({
    required double planPrice,
    required double atrValue,
    required double atrMultiple,
    required TradeType tradeType,
  }) {
    if (planPrice <= 0 || atrValue <= 0 || atrMultiple <= 0) {
      return 0.0;
    }

    final atrDistance = atrValue * atrMultiple;

    if (tradeType == TradeType.buy) {
      return planPrice - atrDistance;
    } else {
      return planPrice + atrDistance;
    }
  }

  /// 计算风险熔断价
  /// 
  /// 买入: 熔断价 = 计划价 * (1 - 风险百分比/100)
  /// 卖出: 熔断价 = 计划价 * (1 + 风险百分比/100)
  static double calculateRiskMeltdownPrice({
    required double planPrice,
    required double riskPercentage,
    required TradeType tradeType,
  }) {
    if (planPrice <= 0 || riskPercentage <= 0) {
      return 0.0;
    }

    final riskFactor = riskPercentage / 100;

    if (tradeType == TradeType.buy) {
      return planPrice * (1 - riskFactor);
    } else {
      return planPrice * (1 + riskFactor);
    }
  }

  /// 计算总投入金额
  static double calculateTotalInvestment({
    required double planPrice,
    required int planQuantity,
  }) {
    return planPrice * planQuantity;
  }

  /// 计算潜在盈利
  static double calculatePotentialProfit({
    required double planPrice,
    required double? takeProfit,
    required int planQuantity,
    required TradeType tradeType,
  }) {
    if (takeProfit == null || planQuantity <= 0) {
      return 0.0;
    }

    if (tradeType == TradeType.buy) {
      return (takeProfit - planPrice) * planQuantity;
    } else {
      return (planPrice - takeProfit) * planQuantity;
    }
  }

  /// 计算潜在亏损
  static double calculatePotentialLoss({
    required double planPrice,
    required double? stopLoss,
    required int planQuantity,
    required TradeType tradeType,
  }) {
    if (stopLoss == null || planQuantity <= 0) {
      return 0.0;
    }

    if (tradeType == TradeType.buy) {
      return (planPrice - stopLoss) * planQuantity;
    } else {
      return (stopLoss - planPrice) * planQuantity;
    }
  }

  /// 计算仓位占比
  static double calculatePositionRatio({
    required double planPrice,
    required int planQuantity,
    required double accountTotal,
  }) {
    if (accountTotal <= 0) return 0.0;
    
    final investment = calculateTotalInvestment(
      planPrice: planPrice,
      planQuantity: planQuantity,
    );
    
    return (investment / accountTotal) * 100;
  }
}

