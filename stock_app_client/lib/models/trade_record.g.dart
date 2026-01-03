// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trade_record.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TradeRecord _$TradeRecordFromJson(Map json) => $checkedCreate(
      'TradeRecord',
      json,
      ($checkedConvert) {
        final val = TradeRecord(
          id: $checkedConvert('id', (v) => (v as num?)?.toInt()),
          stockCode: $checkedConvert('stock_code', (v) => v as String),
          stockName: $checkedConvert('stock_name', (v) => v as String),
          tradeType: $checkedConvert(
              'trade_type', (v) => $enumDecode(_$TradeTypeEnumMap, v)),
          status: $checkedConvert(
              'status', (v) => $enumDecode(_$TradeStatusEnumMap, v)),
          category: $checkedConvert(
              'category', (v) => $enumDecode(_$TradeCategoryEnumMap, v)),
          tradeDate:
              $checkedConvert('trade_date', (v) => DateTime.parse(v as String)),
          createTime: $checkedConvert('create_time',
              (v) => v == null ? null : DateTime.parse(v as String)),
          updateTime: $checkedConvert('update_time',
              (v) => v == null ? null : DateTime.parse(v as String)),
          marketPhase: $checkedConvert('market_phase',
              (v) => $enumDecodeNullable(_$MarketPhaseEnumMap, v)),
          trendStrength: $checkedConvert('trend_strength',
              (v) => $enumDecodeNullable(_$TrendStrengthEnumMap, v)),
          entryDifficulty: $checkedConvert('entry_difficulty',
              (v) => $enumDecodeNullable(_$EntryDifficultyEnumMap, v)),
          positionPercentage: $checkedConvert(
              'position_percentage', (v) => (v as num?)?.toDouble()),
          positionBuildingMethod: $checkedConvert('position_building_method',
              (v) => $enumDecodeNullable(_$PositionBuildingMethodEnumMap, v)),
          priceTriggerType: $checkedConvert('price_trigger_type',
              (v) => $enumDecodeNullable(_$PriceTriggerTypeEnumMap, v)),
          atrValue:
              $checkedConvert('atr_value', (v) => (v as num?)?.toDouble()),
          atrMultiple:
              $checkedConvert('atr_multiple', (v) => (v as num?)?.toDouble()),
          riskPercentage: $checkedConvert(
              'risk_percentage', (v) => (v as num?)?.toDouble()),
          invalidationCondition:
              $checkedConvert('invalidation_condition', (v) => v as String?),
          planPrice:
              $checkedConvert('plan_price', (v) => (v as num?)?.toDouble()),
          planQuantity:
              $checkedConvert('plan_quantity', (v) => (v as num?)?.toInt()),
          stopLossPrice: $checkedConvert(
              'stop_loss_price', (v) => (v as num?)?.toDouble()),
          takeProfitPrice: $checkedConvert(
              'take_profit_price', (v) => (v as num?)?.toDouble()),
          strategy: $checkedConvert('strategy', (v) => v as String?),
          notes: $checkedConvert('notes', (v) => v as String?),
          reason: $checkedConvert('reason', (v) => v as String?),
          actualPrice:
              $checkedConvert('actual_price', (v) => (v as num?)?.toDouble()),
          actualQuantity:
              $checkedConvert('actual_quantity', (v) => (v as num?)?.toInt()),
          commission:
              $checkedConvert('commission', (v) => (v as num?)?.toDouble()),
          tax: $checkedConvert('tax', (v) => (v as num?)?.toDouble()),
          totalCost:
              $checkedConvert('total_cost', (v) => (v as num?)?.toDouble()),
          netProfit:
              $checkedConvert('net_profit', (v) => (v as num?)?.toDouble()),
          profitRate:
              $checkedConvert('profit_rate', (v) => (v as num?)?.toDouble()),
          settlementNo: $checkedConvert('settlement_no', (v) => v as String?),
          settlementDate: $checkedConvert('settlement_date',
              (v) => v == null ? null : DateTime.parse(v as String)),
          settlementStatus:
              $checkedConvert('settlement_status', (v) => v as String?),
        );
        return val;
      },
      fieldKeyMap: const {
        'stockCode': 'stock_code',
        'stockName': 'stock_name',
        'tradeType': 'trade_type',
        'tradeDate': 'trade_date',
        'createTime': 'create_time',
        'updateTime': 'update_time',
        'marketPhase': 'market_phase',
        'trendStrength': 'trend_strength',
        'entryDifficulty': 'entry_difficulty',
        'positionPercentage': 'position_percentage',
        'positionBuildingMethod': 'position_building_method',
        'priceTriggerType': 'price_trigger_type',
        'atrValue': 'atr_value',
        'atrMultiple': 'atr_multiple',
        'riskPercentage': 'risk_percentage',
        'invalidationCondition': 'invalidation_condition',
        'planPrice': 'plan_price',
        'planQuantity': 'plan_quantity',
        'stopLossPrice': 'stop_loss_price',
        'takeProfitPrice': 'take_profit_price',
        'actualPrice': 'actual_price',
        'actualQuantity': 'actual_quantity',
        'totalCost': 'total_cost',
        'netProfit': 'net_profit',
        'profitRate': 'profit_rate',
        'settlementNo': 'settlement_no',
        'settlementDate': 'settlement_date',
        'settlementStatus': 'settlement_status'
      },
    );

Map<String, dynamic> _$TradeRecordToJson(TradeRecord instance) =>
    <String, dynamic>{
      if (instance.id case final value?) 'id': value,
      'stock_code': instance.stockCode,
      'stock_name': instance.stockName,
      'trade_type': _$TradeTypeEnumMap[instance.tradeType]!,
      'status': _$TradeStatusEnumMap[instance.status]!,
      'category': _$TradeCategoryEnumMap[instance.category]!,
      'trade_date': instance.tradeDate.toIso8601String(),
      if (instance.createTime?.toIso8601String() case final value?)
        'create_time': value,
      if (instance.updateTime?.toIso8601String() case final value?)
        'update_time': value,
      if (_$MarketPhaseEnumMap[instance.marketPhase] case final value?)
        'market_phase': value,
      if (_$TrendStrengthEnumMap[instance.trendStrength] case final value?)
        'trend_strength': value,
      if (_$EntryDifficultyEnumMap[instance.entryDifficulty] case final value?)
        'entry_difficulty': value,
      if (instance.positionPercentage case final value?)
        'position_percentage': value,
      if (_$PositionBuildingMethodEnumMap[instance.positionBuildingMethod]
          case final value?)
        'position_building_method': value,
      if (_$PriceTriggerTypeEnumMap[instance.priceTriggerType]
          case final value?)
        'price_trigger_type': value,
      if (instance.atrValue case final value?) 'atr_value': value,
      if (instance.atrMultiple case final value?) 'atr_multiple': value,
      if (instance.riskPercentage case final value?) 'risk_percentage': value,
      if (instance.invalidationCondition case final value?)
        'invalidation_condition': value,
      if (instance.planPrice case final value?) 'plan_price': value,
      if (instance.planQuantity case final value?) 'plan_quantity': value,
      if (instance.stopLossPrice case final value?) 'stop_loss_price': value,
      if (instance.takeProfitPrice case final value?)
        'take_profit_price': value,
      if (instance.strategy case final value?) 'strategy': value,
      if (instance.notes case final value?) 'notes': value,
      if (instance.reason case final value?) 'reason': value,
      if (instance.actualPrice case final value?) 'actual_price': value,
      if (instance.actualQuantity case final value?) 'actual_quantity': value,
      if (instance.commission case final value?) 'commission': value,
      if (instance.tax case final value?) 'tax': value,
      if (instance.totalCost case final value?) 'total_cost': value,
      if (instance.netProfit case final value?) 'net_profit': value,
      if (instance.profitRate case final value?) 'profit_rate': value,
      if (instance.settlementNo case final value?) 'settlement_no': value,
      if (instance.settlementDate?.toIso8601String() case final value?)
        'settlement_date': value,
      if (instance.settlementStatus case final value?)
        'settlement_status': value,
    };

const _$TradeTypeEnumMap = {
  TradeType.buy: 'buy',
  TradeType.sell: 'sell',
};

const _$TradeStatusEnumMap = {
  TradeStatus.pending: 'pending',
  TradeStatus.completed: 'completed',
  TradeStatus.cancelled: 'cancelled',
};

const _$TradeCategoryEnumMap = {
  TradeCategory.plan: 'plan',
  TradeCategory.settlement: 'settlement',
};

const _$MarketPhaseEnumMap = {
  MarketPhase.buildingBottom: 'building_bottom',
  MarketPhase.rising: 'rising',
  MarketPhase.consolidation: 'consolidation',
  MarketPhase.topping: 'topping',
  MarketPhase.falling: 'falling',
};

const _$TrendStrengthEnumMap = {
  TrendStrength.strong: 'strong',
  TrendStrength.medium: 'medium',
  TrendStrength.weak: 'weak',
};

const _$EntryDifficultyEnumMap = {
  EntryDifficulty.veryEasy: 'very_easy',
  EntryDifficulty.easy: 'easy',
  EntryDifficulty.medium: 'medium',
  EntryDifficulty.hard: 'hard',
  EntryDifficulty.veryHard: 'very_hard',
};

const _$PositionBuildingMethodEnumMap = {
  PositionBuildingMethod.oneTime: 'one_time',
  PositionBuildingMethod.batch: 'batch',
};

const _$PriceTriggerTypeEnumMap = {
  PriceTriggerType.breakout: 'breakout',
  PriceTriggerType.pullback: 'pullback',
};
