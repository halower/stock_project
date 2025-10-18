import '../trade_record.dart';
import '../strategy.dart';

/// 仓位计算方式枚举
enum PositionCalculationMethod {
  percentage, // 按比例计算
  quantity,   // 按数量计算
  riskBased   // 以损定仓
}

/// 交易表单数据模型
/// 
/// 统一管理添加交易计划页面的所有表单数据
class TradeFormData {
  // 股票信息
  String stockCode;
  String stockName;
  
  // 交易信息
  TradeType tradeType;
  DateTime createTime;
  double planPrice;
  int planQuantity;
  
  // 风险控制
  double? stopLossPrice;
  double? takeProfitPrice;
  double? atrValue;
  bool useAtrForStopLoss;
  double atrMultiple;
  
  // 市场阶段
  MarketPhase marketPhase;
  TrendStrength trendStrength;
  EntryDifficulty entryDifficulty;
  PositionBuildingMethod buildingMethod;
  PriceTriggerType triggerType;
  
  // 策略
  Strategy? selectedStrategy;
  
  // 仓位计算
  PositionCalculationMethod positionMethod;
  double positionPercentage;
  double accountBalance;
  double accountTotal;
  double riskPercentage;
  
  // 原因和备注
  String reason;
  String notes;
  
  // 手动输入模式
  bool isManualInput;

  TradeFormData({
    this.stockCode = '',
    this.stockName = '',
    this.tradeType = TradeType.buy,
    DateTime? createTime,
    this.planPrice = 0.0,
    this.planQuantity = 0,
    this.stopLossPrice,
    this.takeProfitPrice,
    this.atrValue,
    this.useAtrForStopLoss = true,
    this.atrMultiple = 2.0,
    this.marketPhase = MarketPhase.rising,
    this.trendStrength = TrendStrength.medium,
    this.entryDifficulty = EntryDifficulty.medium,
    this.buildingMethod = PositionBuildingMethod.oneTime,
    this.triggerType = PriceTriggerType.breakout,
    this.selectedStrategy,
    this.positionMethod = PositionCalculationMethod.percentage,
    this.positionPercentage = 20.0,
    this.accountBalance = 100000.0,
    this.accountTotal = 100000.0,
    this.riskPercentage = 2.0,
    this.reason = '',
    this.notes = '',
    this.isManualInput = false,
  }) : createTime = createTime ?? DateTime.now();

  /// 创建初始数据
  factory TradeFormData.initial() {
    return TradeFormData();
  }

  /// 从TradeRecord创建
  factory TradeFormData.fromTradeRecord(TradeRecord record) {
    return TradeFormData(
      stockCode: record.stockCode,
      stockName: record.stockName,
      tradeType: record.tradeType,
      createTime: record.createTime ?? DateTime.now(),
      planPrice: record.planPrice ?? 0.0,
      planQuantity: record.planQuantity ?? 0,
      stopLossPrice: record.stopLossPrice,
      takeProfitPrice: record.takeProfitPrice,
      atrValue: record.atrValue,
      atrMultiple: record.atrMultiple ?? 2.0,
      marketPhase: record.marketPhase ?? MarketPhase.rising,
      trendStrength: record.trendStrength ?? TrendStrength.medium,
      entryDifficulty: record.entryDifficulty ?? EntryDifficulty.medium,
      buildingMethod: record.positionBuildingMethod ?? PositionBuildingMethod.oneTime,
      triggerType: record.priceTriggerType ?? PriceTriggerType.breakout,
      positionPercentage: record.positionPercentage ?? 20.0,
      riskPercentage: record.riskPercentage ?? 2.0,
      reason: record.reason ?? '',
      notes: record.notes ?? '',
    );
  }

  /// 转换为TradeRecord
  TradeRecord toTradeRecord() {
    return TradeRecord(
      id: null, // 新记录ID由数据库生成
      stockCode: stockCode,
      stockName: stockName,
      tradeType: tradeType,
      status: TradeStatus.pending,
      category: TradeCategory.plan,
      tradeDate: createTime,
      createTime: createTime,
      planPrice: planPrice,
      planQuantity: planQuantity,
      stopLossPrice: stopLossPrice,
      takeProfitPrice: takeProfitPrice,
      marketPhase: marketPhase,
      trendStrength: trendStrength,
      entryDifficulty: entryDifficulty,
      positionBuildingMethod: buildingMethod,
      priceTriggerType: triggerType,
      positionPercentage: positionPercentage,
      atrValue: atrValue,
      atrMultiple: atrMultiple,
      riskPercentage: riskPercentage,
      strategy: selectedStrategy?.name,
      reason: reason.isEmpty ? null : reason,
      notes: notes.isEmpty ? null : notes,
    );
  }

  /// 复制并修改
  TradeFormData copyWith({
    String? stockCode,
    String? stockName,
    TradeType? tradeType,
    DateTime? createTime,
    double? planPrice,
    int? planQuantity,
    double? stopLossPrice,
    double? takeProfitPrice,
    double? atrValue,
    bool? useAtrForStopLoss,
    double? atrMultiple,
    MarketPhase? marketPhase,
    TrendStrength? trendStrength,
    EntryDifficulty? entryDifficulty,
    PositionBuildingMethod? buildingMethod,
    PriceTriggerType? triggerType,
    Strategy? selectedStrategy,
    PositionCalculationMethod? positionMethod,
    double? positionPercentage,
    double? accountBalance,
    double? accountTotal,
    double? riskPercentage,
    String? reason,
    String? notes,
    bool? isManualInput,
  }) {
    return TradeFormData(
      stockCode: stockCode ?? this.stockCode,
      stockName: stockName ?? this.stockName,
      tradeType: tradeType ?? this.tradeType,
      createTime: createTime ?? this.createTime,
      planPrice: planPrice ?? this.planPrice,
      planQuantity: planQuantity ?? this.planQuantity,
      stopLossPrice: stopLossPrice ?? this.stopLossPrice,
      takeProfitPrice: takeProfitPrice ?? this.takeProfitPrice,
      atrValue: atrValue ?? this.atrValue,
      useAtrForStopLoss: useAtrForStopLoss ?? this.useAtrForStopLoss,
      atrMultiple: atrMultiple ?? this.atrMultiple,
      marketPhase: marketPhase ?? this.marketPhase,
      trendStrength: trendStrength ?? this.trendStrength,
      entryDifficulty: entryDifficulty ?? this.entryDifficulty,
      buildingMethod: buildingMethod ?? this.buildingMethod,
      triggerType: triggerType ?? this.triggerType,
      selectedStrategy: selectedStrategy ?? this.selectedStrategy,
      positionMethod: positionMethod ?? this.positionMethod,
      positionPercentage: positionPercentage ?? this.positionPercentage,
      accountBalance: accountBalance ?? this.accountBalance,
      accountTotal: accountTotal ?? this.accountTotal,
      riskPercentage: riskPercentage ?? this.riskPercentage,
      reason: reason ?? this.reason,
      notes: notes ?? this.notes,
      isManualInput: isManualInput ?? this.isManualInput,
    );
  }
}

