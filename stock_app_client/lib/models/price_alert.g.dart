// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'price_alert.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PriceAlert _$PriceAlertFromJson(Map json) => $checkedCreate(
      'PriceAlert',
      json,
      ($checkedConvert) {
        final val = PriceAlert(
          id: $checkedConvert('id', (v) => v as String),
          stockCode: $checkedConvert('stock_code', (v) => v as String),
          stockName: $checkedConvert('stock_name', (v) => v as String),
          alertType: $checkedConvert(
              'alert_type', (v) => $enumDecode(_$AlertTypeEnumMap, v)),
          targetPrice:
              $checkedConvert('target_price', (v) => (v as num).toDouble()),
          isEnabled: $checkedConvert('is_enabled', (v) => v as bool? ?? true),
          createdAt:
              $checkedConvert('created_at', (v) => DateTime.parse(v as String)),
          triggeredAt: $checkedConvert('triggered_at',
              (v) => v == null ? null : DateTime.parse(v as String)),
          triggeredPrice: $checkedConvert(
              'triggered_price', (v) => (v as num?)?.toDouble()),
          note: $checkedConvert('note', (v) => v as String?),
        );
        return val;
      },
      fieldKeyMap: const {
        'stockCode': 'stock_code',
        'stockName': 'stock_name',
        'alertType': 'alert_type',
        'targetPrice': 'target_price',
        'isEnabled': 'is_enabled',
        'createdAt': 'created_at',
        'triggeredAt': 'triggered_at',
        'triggeredPrice': 'triggered_price'
      },
    );

Map<String, dynamic> _$PriceAlertToJson(PriceAlert instance) =>
    <String, dynamic>{
      'id': instance.id,
      'stock_code': instance.stockCode,
      'stock_name': instance.stockName,
      'alert_type': _$AlertTypeEnumMap[instance.alertType]!,
      'target_price': instance.targetPrice,
      'is_enabled': instance.isEnabled,
      'created_at': instance.createdAt.toIso8601String(),
      'triggered_at': instance.triggeredAt?.toIso8601String(),
      'triggered_price': instance.triggeredPrice,
      'note': instance.note,
    };

const _$AlertTypeEnumMap = {
  AlertType.targetPrice: 'target_price',
  AlertType.stopLoss: 'stop_loss',
  AlertType.takeProfit: 'take_profit',
};
