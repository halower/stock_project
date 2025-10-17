// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stock.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Stock _$StockFromJson(Map json) => $checkedCreate(
      'Stock',
      json,
      ($checkedConvert) {
        final val = Stock(
          code: $checkedConvert('code', (v) => v as String),
          name: $checkedConvert('name', (v) => v as String),
          costPrice:
              $checkedConvert('cost_price', (v) => (v as num?)?.toDouble()),
          currentPrice:
              $checkedConvert('current_price', (v) => (v as num?)?.toDouble()),
          quantity: $checkedConvert('quantity', (v) => (v as num?)?.toInt()),
          profit: $checkedConvert('profit', (v) => (v as num?)?.toDouble()),
          addTime: $checkedConvert('add_time',
              (v) => v == null ? null : DateTime.parse(v as String)),
          strategy: $checkedConvert('strategy', (v) => v as String?),
          notes: $checkedConvert('notes', (v) => v as String?),
          watchReason: $checkedConvert('watch_reason', (v) => v as String?),
          targetPrice:
              $checkedConvert('target_price', (v) => (v as num?)?.toDouble()),
          market: $checkedConvert('market', (v) => v as String? ?? ''),
          industry: $checkedConvert('industry', (v) => v as String? ?? ''),
        );
        return val;
      },
      fieldKeyMap: const {
        'costPrice': 'cost_price',
        'currentPrice': 'current_price',
        'addTime': 'add_time',
        'watchReason': 'watch_reason',
        'targetPrice': 'target_price'
      },
    );

Map<String, dynamic> _$StockToJson(Stock instance) => <String, dynamic>{
      'code': instance.code,
      'name': instance.name,
      'cost_price': instance.costPrice,
      'current_price': instance.currentPrice,
      'quantity': instance.quantity,
      'profit': instance.profit,
      'add_time': instance.addTime?.toIso8601String(),
      'strategy': instance.strategy,
      'notes': instance.notes,
      'watch_reason': instance.watchReason,
      'target_price': instance.targetPrice,
      'market': instance.market,
      'industry': instance.industry,
    };
