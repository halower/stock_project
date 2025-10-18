import '../../models/trade_record.dart';

/// 结算计算服务
/// 
/// 提供各种结算相关的计算功能
class SettlementCalculationService {
  /// 计算交易金额
  /// 
  /// [price] 价格
  /// [quantity] 数量
  /// 返回: 交易金额 = 价格 × 数量
  static double calculateTotalAmount(double price, int quantity) {
    return price * quantity;
  }

  /// 计算总成本（含佣金和税费）
  /// 
  /// [amount] 交易金额
  /// [commission] 佣金
  /// [tax] 税费
  /// 返回: 总成本 = 交易金额 + 佣金 + 税费
  static double calculateTotalCost(double amount, double commission, double tax) {
    return amount + commission + tax;
  }

  /// 计算净盈亏
  /// 
  /// [actualPrice] 实际成交价
  /// [actualQuantity] 实际成交量
  /// [planPrice] 计划价格
  /// [planQuantity] 计划数量
  /// [commission] 佣金
  /// [tax] 税费
  /// [tradeType] 交易类型（买入/卖出）
  /// 返回: 净盈亏（考虑费用后的实际盈亏）
  static double calculateNetProfit({
    required double actualPrice,
    required int actualQuantity,
    required double planPrice,
    required int planQuantity,
    required double commission,
    required double tax,
    required TradeType tradeType,
  }) {
    final actualAmount = calculateTotalAmount(actualPrice, actualQuantity);
    final planAmount = calculateTotalAmount(planPrice, planQuantity);
    final totalFees = commission + tax;

    if (tradeType == TradeType.buy) {
      // 买入：节省的金额 = 计划金额 - 实际金额 - 费用
      return planAmount - actualAmount - totalFees;
    } else {
      // 卖出：盈利金额 = 实际金额 - 计划金额 - 费用
      return actualAmount - planAmount - totalFees;
    }
  }

  /// 计算盈利率
  /// 
  /// [netProfit] 净盈亏
  /// [planAmount] 计划金额
  /// 返回: 盈利率（百分比）
  static double calculateProfitRate(double netProfit, double planAmount) {
    if (planAmount == 0) return 0.0;
    return (netProfit / planAmount) * 100;
  }

  /// 计算盈亏比
  /// 
  /// [planPrice] 计划价格
  /// [stopLossPrice] 止损价格
  /// [takeProfitPrice] 止盈价格
  /// 返回: 盈亏比 = 盈利空间 / 亏损空间
  static double calculateProfitRiskRatio({
    required double planPrice,
    required double stopLossPrice,
    required double takeProfitPrice,
  }) {
    if (planPrice == 0 || stopLossPrice == 0 || takeProfitPrice == 0) {
      return 0.0;
    }

    final profitSpace = (takeProfitPrice - planPrice).abs();
    final lossSpace = (planPrice - stopLossPrice).abs();

    if (lossSpace == 0) return 0.0;

    return profitSpace / lossSpace;
  }

  /// 计算价格变化百分比
  /// 
  /// [currentPrice] 当前价格
  /// [basePrice] 基准价格
  /// 返回: 变化百分比
  static double calculatePriceChangePercent(double currentPrice, double basePrice) {
    if (basePrice == 0) return 0.0;
    return ((currentPrice - basePrice) / basePrice) * 100;
  }

  /// 计算平均成本
  /// 
  /// [totalCost] 总成本
  /// [quantity] 数量
  /// 返回: 平均成本 = 总成本 / 数量
  static double calculateAverageCost(double totalCost, int quantity) {
    if (quantity == 0) return 0.0;
    return totalCost / quantity;
  }

  /// 计算佣金（按比例）
  /// 
  /// [amount] 交易金额
  /// [rate] 佣金率（例如：0.0003 表示万分之三）
  /// [minCommission] 最低佣金（例如：5元）
  /// 返回: 佣金金额
  static double calculateCommission(double amount, double rate, {double minCommission = 5.0}) {
    final commission = amount * rate;
    return commission < minCommission ? minCommission : commission;
  }

  /// 计算印花税（仅卖出时收取）
  /// 
  /// [amount] 交易金额
  /// [rate] 印花税率（例如：0.001 表示千分之一）
  /// [isSell] 是否为卖出交易
  /// 返回: 印花税金额
  static double calculateStampTax(double amount, double rate, {required bool isSell}) {
    if (!isSell) return 0.0;
    return amount * rate;
  }
}

