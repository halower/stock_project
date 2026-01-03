import 'package:json_annotation/json_annotation.dart';

part 'price_alert.g.dart';

/// 预警类型枚举
enum AlertType {
  @JsonValue('target_price')
  targetPrice,  // 目标价
  
  @JsonValue('stop_loss')
  stopLoss,     // 止损价
  
  @JsonValue('take_profit')
  takeProfit,   // 止盈价
}

/// 预警类型扩展方法
extension AlertTypeExtension on AlertType {
  String get displayName {
    switch (this) {
      case AlertType.targetPrice:
        return '目标价';
      case AlertType.stopLoss:
        return '止损价';
      case AlertType.takeProfit:
        return '止盈价';
    }
  }
  
  String get icon {
    switch (this) {
      case AlertType.targetPrice:
        return '🎯';
      case AlertType.stopLoss:
        return '🛡️';
      case AlertType.takeProfit:
        return '💰';
    }
  }
}

/// 价格预警模型
@JsonSerializable()
class PriceAlert {
  /// 唯一标识
  final String id;
  
  /// 股票代码
  final String stockCode;
  
  /// 股票名称
  final String stockName;
  
  /// 预警类型
  final AlertType alertType;
  
  /// 目标价格
  final double targetPrice;
  
  /// 是否启用
  final bool isEnabled;
  
  /// 创建时间
  final DateTime createdAt;
  
  /// 触发时间（如果已触发）
  final DateTime? triggeredAt;
  
  /// 触发时的价格
  final double? triggeredPrice;
  
  /// 备注
  final String? note;

  PriceAlert({
    required this.id,
    required this.stockCode,
    required this.stockName,
    required this.alertType,
    required this.targetPrice,
    this.isEnabled = true,
    required this.createdAt,
    this.triggeredAt,
    this.triggeredPrice,
    this.note,
  });

  /// 从JSON创建
  factory PriceAlert.fromJson(Map<String, dynamic> json) => _$PriceAlertFromJson(json);

  /// 转换为JSON
  Map<String, dynamic> toJson() => _$PriceAlertToJson(this);

  /// 复制并修改部分字段
  PriceAlert copyWith({
    String? id,
    String? stockCode,
    String? stockName,
    AlertType? alertType,
    double? targetPrice,
    bool? isEnabled,
    DateTime? createdAt,
    DateTime? triggeredAt,
    double? triggeredPrice,
    String? note,
  }) {
    return PriceAlert(
      id: id ?? this.id,
      stockCode: stockCode ?? this.stockCode,
      stockName: stockName ?? this.stockName,
      alertType: alertType ?? this.alertType,
      targetPrice: targetPrice ?? this.targetPrice,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      triggeredAt: triggeredAt ?? this.triggeredAt,
      triggeredPrice: triggeredPrice ?? this.triggeredPrice,
      note: note ?? this.note,
    );
  }

  /// 检查价格是否触发预警
  bool checkTrigger(double currentPrice) {
    if (!isEnabled || triggeredAt != null) {
      return false;
    }

    switch (alertType) {
      case AlertType.targetPrice:
        // 目标价：价格达到或超过目标价
        return currentPrice >= targetPrice;
      case AlertType.stopLoss:
        // 止损价：价格跌破止损价
        return currentPrice <= targetPrice;
      case AlertType.takeProfit:
        // 止盈价：价格达到或超过止盈价
        return currentPrice >= targetPrice;
    }
  }

  /// 计算价格差距百分比
  double calculatePriceDifferencePercent(double currentPrice) {
    if (currentPrice == 0) return 0;
    return ((targetPrice - currentPrice) / currentPrice) * 100;
  }

  /// 获取触发条件描述
  String getTriggerConditionDescription() {
    switch (alertType) {
      case AlertType.targetPrice:
        return '价格达到 ¥${targetPrice.toStringAsFixed(2)}';
      case AlertType.stopLoss:
        return '价格跌破 ¥${targetPrice.toStringAsFixed(2)}';
      case AlertType.takeProfit:
        return '价格达到 ¥${targetPrice.toStringAsFixed(2)}';
    }
  }

  /// 是否已触发
  bool get isTriggered => triggeredAt != null;

  /// 是否活跃（启用且未触发）
  bool get isActive => isEnabled && !isTriggered;
}

