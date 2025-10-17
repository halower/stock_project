// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stock_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StockInfo _$StockInfoFromJson(Map json) => $checkedCreate(
      'StockInfo',
      json,
      ($checkedConvert) {
        final val = StockInfo(
          code: $checkedConvert('证券代码', (v) => v as String? ?? ''),
          name: $checkedConvert('证券简称', (v) => v as String? ?? ''),
          market: $checkedConvert('market', (v) => v as String? ?? ''),
          industry: $checkedConvert('所属行业', (v) => v as String? ?? ''),
          board: $checkedConvert('板块', (v) => v as String? ?? ''),
          listingDate: $checkedConvert('上市日期', (v) => v as String? ?? ''),
          totalShares: $checkedConvert('总股本', (v) => v as String? ?? ''),
          circulatingShares: $checkedConvert('流通股本', (v) => v as String? ?? ''),
        );
        return val;
      },
      fieldKeyMap: const {
        'code': '证券代码',
        'name': '证券简称',
        'industry': '所属行业',
        'board': '板块',
        'listingDate': '上市日期',
        'totalShares': '总股本',
        'circulatingShares': '流通股本'
      },
    );

Map<String, dynamic> _$StockInfoToJson(StockInfo instance) => <String, dynamic>{
      '证券代码': instance.code,
      '证券简称': instance.name,
      'market': instance.market,
      '所属行业': instance.industry,
      '板块': instance.board,
      '上市日期': instance.listingDate,
      '总股本': instance.totalShares,
      '流通股本': instance.circulatingShares,
    };
