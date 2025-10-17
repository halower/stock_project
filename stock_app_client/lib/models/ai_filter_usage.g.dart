// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_filter_usage.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AIFilterUsage _$AIFilterUsageFromJson(Map json) => $checkedCreate(
      'AIFilterUsage',
      json,
      ($checkedConvert) {
        final val = AIFilterUsage(
          lastUsedDate: $checkedConvert('last_used_date', (v) => v as String),
          usedCount: $checkedConvert('used_count', (v) => (v as num).toInt()),
        );
        return val;
      },
      fieldKeyMap: const {
        'lastUsedDate': 'last_used_date',
        'usedCount': 'used_count'
      },
    );

Map<String, dynamic> _$AIFilterUsageToJson(AIFilterUsage instance) =>
    <String, dynamic>{
      'last_used_date': instance.lastUsedDate,
      'used_count': instance.usedCount,
    };
