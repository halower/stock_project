import 'package:json_annotation/json_annotation.dart';

part 'trade_record.g.dart';

@JsonEnum(valueField: 'name')
enum TradeType {
  @JsonValue('buy')
  buy,
  @JsonValue('sell')
  sell
}

@JsonEnum(valueField: 'name')
enum TradeStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('completed')
  completed,
  @JsonValue('cancelled')
  cancelled
}

@JsonEnum(valueField: 'name')
enum TradeCategory {
  @JsonValue('plan')
  plan,
  @JsonValue('settlement')
  settlement
}

@JsonEnum(valueField: 'name')
enum MarketPhase {
  @JsonValue('building_bottom')
  buildingBottom, // 筑底
  @JsonValue('rising')
  rising, // 上升
  @JsonValue('consolidation')
  consolidation, // 盘整
  @JsonValue('topping')
  topping, // 做头
  @JsonValue('falling')
  falling // 下降
}

@JsonEnum(valueField: 'name')
enum TrendStrength {
  @JsonValue('strong')
  strong, // 强
  @JsonValue('medium')
  medium, // 中
  @JsonValue('weak')
  weak // 弱
}

@JsonEnum(valueField: 'name')
enum EntryDifficulty {
  @JsonValue('very_easy')
  veryEasy, // ⭐
  @JsonValue('easy')
  easy, // ⭐⭐
  @JsonValue('medium')
  medium, // ⭐⭐⭐
  @JsonValue('hard')
  hard, // ⭐⭐⭐⭐
  @JsonValue('very_hard')
  veryHard // ⭐⭐⭐⭐⭐
}

@JsonEnum(valueField: 'name')
enum PositionBuildingMethod {
  @JsonValue('one_time')
  oneTime, // 一次性建仓
  @JsonValue('batch')
  batch // 分批建仓
}

@JsonEnum(valueField: 'name')
enum PriceTriggerType {
  @JsonValue('breakout')
  breakout, // 突破
  @JsonValue('pullback')
  pullback // 回调
}

@JsonSerializable(
  explicitToJson: true,
  includeIfNull: false,
  createFactory: true,
  createToJson: true,
)
class TradeRecord {
  @JsonKey(name: 'id')
  final int? id;
  @JsonKey(name: 'stock_code')
  final String stockCode;
  @JsonKey(name: 'stock_name')
  final String stockName;
  @JsonKey(name: 'trade_type')
  final TradeType tradeType;
  @JsonKey(name: 'status')
  final TradeStatus status;
  @JsonKey(name: 'category')
  final TradeCategory category;
  @JsonKey(name: 'trade_date')
  final DateTime tradeDate;
  @JsonKey(name: 'create_time')
  final DateTime? createTime;
  @JsonKey(name: 'update_time')
  final DateTime? updateTime;
  
  // 新增交易计划相关字段
  @JsonKey(name: 'market_phase')
  final MarketPhase? marketPhase;        // 盘趋阶段
  @JsonKey(name: 'trend_strength')
  final TrendStrength? trendStrength;    // 趋势强度
  @JsonKey(name: 'entry_difficulty')
  final EntryDifficulty? entryDifficulty; // 下单难度
  @JsonKey(name: 'position_percentage')
  final double? positionPercentage;      // 计划仓位占比
  @JsonKey(name: 'position_building_method')
  final PositionBuildingMethod? positionBuildingMethod; // 建仓方式
  @JsonKey(name: 'price_trigger_type')
  final PriceTriggerType? priceTriggerType; // 触发价类型
  @JsonKey(name: 'atr_value')
  final double? atrValue;                // ATR值
  @JsonKey(name: 'atr_multiple')
  final double? atrMultiple;            // ATR倍数（用于止损）
  @JsonKey(name: 'risk_percentage')
  final double? riskPercentage;         // 风险熔断百分比
  @JsonKey(name: 'invalidation_condition')
  final String? invalidationCondition;  // 策略失效条件
  
  // 现有交易计划相关字段
  @JsonKey(name: 'plan_price')
  final double? planPrice;        // 计划价格
  @JsonKey(name: 'plan_quantity')
  final int? planQuantity;        // 计划数量
  @JsonKey(name: 'stop_loss_price')
  final double? stopLossPrice;    // 止损价格
  @JsonKey(name: 'take_profit_price')
  final double? takeProfitPrice;  // 止盈价格
  @JsonKey(name: 'strategy')
  final String? strategy;         // 使用的策略
  @JsonKey(name: 'notes')
  final String? notes;            // 交易说明
  @JsonKey(name: 'reason')
  final String? reason;           // 开仓理由
  
  // 实际执行相关字段
  @JsonKey(name: 'actual_price')
  final double? actualPrice;      // 实际成交价格
  @JsonKey(name: 'actual_quantity')
  final int? actualQuantity;      // 实际成交数量
  @JsonKey(name: 'commission')
  final double? commission;       // 手续费
  @JsonKey(name: 'tax')
  final double? tax;             // 税费
  @JsonKey(name: 'total_cost')
  final double? totalCost;       // 总成本
  @JsonKey(name: 'net_profit')
  final double? netProfit;       // 净利润
  @JsonKey(name: 'profit_rate')
  final double? profitRate;      // 收益率
  @JsonKey(name: 'settlement_no')
  final String? settlementNo;    // 交割单号
  @JsonKey(name: 'settlement_date')
  final DateTime? settlementDate; // 交割日期
  @JsonKey(name: 'settlement_status')
  final String? settlementStatus; // 交割状态

  TradeRecord({
    this.id,
    required this.stockCode,
    required this.stockName,
    required this.tradeType,
    required this.status,
    required this.category,
    required this.tradeDate,
    this.createTime,
    this.updateTime,
    this.marketPhase,
    this.trendStrength,
    this.entryDifficulty,
    this.positionPercentage,
    this.positionBuildingMethod,
    this.priceTriggerType,
    this.atrValue,
    this.atrMultiple,
    this.riskPercentage,
    this.invalidationCondition,
    this.planPrice,
    this.planQuantity,
    this.stopLossPrice,
    this.takeProfitPrice,
    this.strategy,
    this.notes,
    this.reason,
    this.actualPrice,
    this.actualQuantity,
    this.commission,
    this.tax,
    this.totalCost,
    this.netProfit,
    this.profitRate,
    this.settlementNo,
    this.settlementDate,
    this.settlementStatus,
  });

  factory TradeRecord.fromJson(Map<String, dynamic> json) => _$TradeRecordFromJson(json);
  Map<String, dynamic> toJson() => _$TradeRecordToJson(this);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'stock_code': stockCode,
      'stock_name': stockName,
      'trade_type': tradeType.name,
      'status': status.name,
      'category': category.name,
      'trade_date': tradeDate.toIso8601String(),
      'create_time': createTime?.toIso8601String(),
      'update_time': updateTime?.toIso8601String(),
      'market_phase': marketPhase?.name,
      'trend_strength': trendStrength?.name,
      'entry_difficulty': entryDifficulty?.name,
      'position_percentage': positionPercentage,
      'position_building_method': positionBuildingMethod?.name,
      'price_trigger_type': priceTriggerType?.name,
      'atr_value': atrValue,
      'atr_multiple': atrMultiple,
      'risk_percentage': riskPercentage,
      'invalidation_condition': invalidationCondition,
      'plan_price': planPrice,
      'plan_quantity': planQuantity,
      'stop_loss_price': stopLossPrice,
      'take_profit_price': takeProfitPrice,
      'strategy': strategy,
      'notes': notes,
      'reason': reason,
      'actual_price': actualPrice,
      'actual_quantity': actualQuantity,
      'commission': commission,
      'tax': tax,
      'total_cost': totalCost,
      'net_profit': netProfit,
      'profit_rate': profitRate,
      'settlement_no': settlementNo,
      'settlement_date': settlementDate?.toIso8601String(),
      'settlement_status': settlementStatus,
    };
  }

  factory TradeRecord.fromMap(Map<String, dynamic> map) {
    return TradeRecord(
      id: map['id'] as int?,
      stockCode: map['stock_code'] as String,
      stockName: map['stock_name'] as String,
      tradeType: map['trade_type'] != null ? TradeType.values.firstWhere((e) => e.name == map['trade_type'], orElse: () => TradeType.buy) : TradeType.buy,
      status: map['status'] != null ? TradeStatus.values.firstWhere((e) => e.name == map['status'], orElse: () => TradeStatus.pending) : TradeStatus.pending,
      category: map['category'] != null ? TradeCategory.values.firstWhere((e) => e.name == map['category'], orElse: () => TradeCategory.plan) : TradeCategory.plan,
      tradeDate: map['trade_date'] != null ? DateTime.parse(map['trade_date'] as String) : DateTime.now(),
      createTime: map['create_time'] == null ? null : DateTime.parse(map['create_time'] as String),
      updateTime: map['update_time'] == null ? null : DateTime.parse(map['update_time'] as String),
      marketPhase: map['market_phase'] == null ? null : 
        MarketPhase.values.firstWhere((e) => e.name == map['market_phase'], orElse: () => MarketPhase.rising),
      trendStrength: map['trend_strength'] == null ? null : 
        TrendStrength.values.firstWhere((e) => e.name == map['trend_strength'], orElse: () => TrendStrength.medium),
      entryDifficulty: map['entry_difficulty'] == null ? null : 
        EntryDifficulty.values.firstWhere((e) => e.name == map['entry_difficulty'], orElse: () => EntryDifficulty.medium),
      positionPercentage: map['position_percentage'] != null ? (map['position_percentage'] as num).toDouble() : null,
      positionBuildingMethod: map['position_building_method'] == null ? null : 
        PositionBuildingMethod.values.firstWhere((e) => e.name == map['position_building_method'], orElse: () => PositionBuildingMethod.oneTime),
      priceTriggerType: map['price_trigger_type'] == null ? null : 
        PriceTriggerType.values.firstWhere((e) => e.name == map['price_trigger_type'], orElse: () => PriceTriggerType.breakout),
      atrValue: map['atr_value'] != null ? (map['atr_value'] as num).toDouble() : null,
      atrMultiple: map['atr_multiple'] != null ? (map['atr_multiple'] as num).toDouble() : null,
      riskPercentage: map['risk_percentage'] != null ? (map['risk_percentage'] as num).toDouble() : null,
      invalidationCondition: map['invalidation_condition'] as String?,
      planPrice: map['plan_price'] != null ? (map['plan_price'] as num).toDouble() : null,
      planQuantity: map['plan_quantity'] != null ? (map['plan_quantity'] as num).toInt() : null,
      stopLossPrice: map['stop_loss_price'] != null ? (map['stop_loss_price'] as num).toDouble() : null,
      takeProfitPrice: map['take_profit_price'] != null ? (map['take_profit_price'] as num).toDouble() : null,
      strategy: map['strategy'] as String?,
      notes: map['notes'] as String?,
      reason: map['reason'] as String?,
      actualPrice: map['actual_price'] != null ? (map['actual_price'] as num).toDouble() : null,
      actualQuantity: map['actual_quantity'] != null ? (map['actual_quantity'] as num).toInt() : null,
      commission: map['commission'] != null ? (map['commission'] as num).toDouble() : null,
      tax: map['tax'] != null ? (map['tax'] as num).toDouble() : null,
      totalCost: map['total_cost'] != null ? (map['total_cost'] as num).toDouble() : null,
      netProfit: map['net_profit'] != null ? (map['net_profit'] as num).toDouble() : null,
      profitRate: map['profit_rate'] != null ? (map['profit_rate'] as num).toDouble() : null,
      settlementNo: map['settlement_no'] as String?,
      settlementDate: map['settlement_date'] == null ? null : DateTime.parse(map['settlement_date'] as String),
      settlementStatus: map['settlement_status'] as String?,
    );
  }

  TradeRecord copyWith({
    int? id,
    String? stockCode,
    String? stockName,
    TradeType? tradeType,
    TradeStatus? status,
    TradeCategory? category,
    DateTime? tradeDate,
    DateTime? createTime,
    DateTime? updateTime,
    MarketPhase? marketPhase,
    TrendStrength? trendStrength,
    EntryDifficulty? entryDifficulty,
    double? positionPercentage,
    PositionBuildingMethod? positionBuildingMethod,
    PriceTriggerType? priceTriggerType,
    double? atrValue,
    double? atrMultiple,
    double? riskPercentage,
    String? invalidationCondition,
    double? planPrice,
    int? planQuantity,
    double? stopLossPrice,
    double? takeProfitPrice,
    String? strategy,
    String? notes,
    String? reason,
    double? actualPrice,
    int? actualQuantity,
    double? commission,
    double? tax,
    double? totalCost,
    double? netProfit,
    double? profitRate,
    String? settlementNo,
    DateTime? settlementDate,
    String? settlementStatus,
  }) {
    return TradeRecord(
      id: id ?? this.id,
      stockCode: stockCode ?? this.stockCode,
      stockName: stockName ?? this.stockName,
      tradeType: tradeType ?? this.tradeType,
      status: status ?? this.status,
      category: category ?? this.category,
      tradeDate: tradeDate ?? this.tradeDate,
      createTime: createTime ?? this.createTime,
      updateTime: updateTime ?? this.updateTime,
      marketPhase: marketPhase ?? this.marketPhase,
      trendStrength: trendStrength ?? this.trendStrength,
      entryDifficulty: entryDifficulty ?? this.entryDifficulty,
      positionPercentage: positionPercentage ?? this.positionPercentage,
      positionBuildingMethod: positionBuildingMethod ?? this.positionBuildingMethod,
      priceTriggerType: priceTriggerType ?? this.priceTriggerType,
      atrValue: atrValue ?? this.atrValue,
      atrMultiple: atrMultiple ?? this.atrMultiple,
      riskPercentage: riskPercentage ?? this.riskPercentage,
      invalidationCondition: invalidationCondition ?? this.invalidationCondition,
      planPrice: planPrice ?? this.planPrice,
      planQuantity: planQuantity ?? this.planQuantity,
      stopLossPrice: stopLossPrice ?? this.stopLossPrice,
      takeProfitPrice: takeProfitPrice ?? this.takeProfitPrice,
      strategy: strategy ?? this.strategy,
      notes: notes ?? this.notes,
      reason: reason ?? this.reason,
      actualPrice: actualPrice ?? this.actualPrice,
      actualQuantity: actualQuantity ?? this.actualQuantity,
      commission: commission ?? this.commission,
      tax: tax ?? this.tax,
      totalCost: totalCost ?? this.totalCost,
      netProfit: netProfit ?? this.netProfit,
      profitRate: profitRate ?? this.profitRate,
      settlementNo: settlementNo ?? this.settlementNo,
      settlementDate: settlementDate ?? this.settlementDate,
      settlementStatus: settlementStatus ?? this.settlementStatus,
    );
  }

  // 判断交易日期是否为周末
  bool get isWeekendRecord {
    // 周六是6，周日是7
    return tradeDate.weekday >= 6;
  }
}
