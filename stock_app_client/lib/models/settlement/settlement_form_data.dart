import '../trade_record.dart';

/// 结算表单数据模型
class SettlementFormData {
  final double? actualPrice;
  final int? actualQuantity;
  final double? commission;
  final double? tax;
  final String? notes;

  const SettlementFormData({
    this.actualPrice,
    this.actualQuantity,
    this.commission,
    this.tax,
    this.notes,
  });

  /// 计算交易金额
  double get totalAmount {
    if (actualPrice == null || actualQuantity == null) return 0.0;
    return actualPrice! * actualQuantity!;
  }

  /// 计算总成本（交易金额 + 佣金 + 税费）
  double get totalCost {
    return totalAmount + (commission ?? 0.0) + (tax ?? 0.0);
  }

  /// 从TradeRecord创建
  factory SettlementFormData.fromTradeRecord(TradeRecord record) {
    return SettlementFormData(
      actualPrice: record.actualPrice,
      actualQuantity: record.actualQuantity,
      commission: record.commission ?? 0.0,
      tax: record.tax ?? 0.0,
      notes: record.notes,
    );
  }

  /// 转换为TradeRecord（用于更新）
  TradeRecord toTradeRecord(TradeRecord original) {
    return TradeRecord(
      id: original.id,
      stockCode: original.stockCode,
      stockName: original.stockName,
      tradeType: original.tradeType,
      category: original.category,
      status: TradeStatus.completed, // 结算后状态变为已完成
      tradeDate: original.tradeDate,
      planPrice: original.planPrice,
      planQuantity: original.planQuantity,
      actualPrice: actualPrice,
      actualQuantity: actualQuantity,
      stopLossPrice: original.stopLossPrice,
      takeProfitPrice: original.takeProfitPrice,
      commission: commission,
      tax: tax,
      netProfit: _calculateNetProfit(original),
      marketPhase: original.marketPhase,
      strategy: original.strategy,
      reason: original.reason,
      notes: notes,
      entryDifficulty: original.entryDifficulty,
      positionBuildingMethod: original.positionBuildingMethod,
      priceTriggerType: original.priceTriggerType,
      createTime: original.createTime,
      updateTime: DateTime.now(),
    );
  }

  /// 计算净盈亏
  double? _calculateNetProfit(TradeRecord original) {
    if (actualPrice == null || actualQuantity == null || original.planPrice == null) {
      return null;
    }

    final actualAmount = actualPrice! * actualQuantity!;
    final planAmount = original.planPrice! * (original.planQuantity ?? actualQuantity!);
    final totalCommission = (commission ?? 0.0) + (tax ?? 0.0);

    if (original.tradeType == TradeType.buy) {
      // 买入：实际金额 - 计划金额 - 费用
      return planAmount - actualAmount - totalCommission;
    } else {
      // 卖出：实际金额 - 计划金额 - 费用
      return actualAmount - planAmount - totalCommission;
    }
  }

  /// 复制方法
  SettlementFormData copyWith({
    double? actualPrice,
    int? actualQuantity,
    double? commission,
    double? tax,
    String? notes,
  }) {
    return SettlementFormData(
      actualPrice: actualPrice ?? this.actualPrice,
      actualQuantity: actualQuantity ?? this.actualQuantity,
      commission: commission ?? this.commission,
      tax: tax ?? this.tax,
      notes: notes ?? this.notes,
    );
  }

  /// 验证表单数据是否完整
  bool get isValid {
    return actualPrice != null &&
        actualPrice! > 0 &&
        actualQuantity != null &&
        actualQuantity! > 0;
  }

  @override
  String toString() {
    return 'SettlementFormData(actualPrice: $actualPrice, actualQuantity: $actualQuantity, '
        'commission: $commission, tax: $tax, totalAmount: $totalAmount, totalCost: $totalCost)';
  }
}

