// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'strategy.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Strategy _$StrategyFromJson(Map json) => $checkedCreate(
      'Strategy',
      json,
      ($checkedConvert) {
        final val = Strategy(
          id: $checkedConvert('id', (v) => (v as num?)?.toInt()),
          name: $checkedConvert('name', (v) => v as String),
          description: $checkedConvert('description', (v) => v as String?),
          entryConditions: $checkedConvert(
              'entry_conditions', (v) => Strategy._listFromJson(v as String)),
          exitConditions: $checkedConvert(
              'exit_conditions', (v) => Strategy._listFromJson(v as String)),
          riskControls: $checkedConvert(
              'risk_controls', (v) => Strategy._listFromJson(v as String)),
          isActive: $checkedConvert('is_active', (v) => v as bool? ?? true),
          createTime: $checkedConvert(
              'create_time', (v) => DateTime.parse(v as String)),
          updateTime: $checkedConvert('update_time',
              (v) => v == null ? null : DateTime.parse(v as String)),
        );
        return val;
      },
      fieldKeyMap: const {
        'entryConditions': 'entry_conditions',
        'exitConditions': 'exit_conditions',
        'riskControls': 'risk_controls',
        'isActive': 'is_active',
        'createTime': 'create_time',
        'updateTime': 'update_time'
      },
    );

Map<String, dynamic> _$StrategyToJson(Strategy instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'entry_conditions': Strategy._listToJson(instance.entryConditions),
      'exit_conditions': Strategy._listToJson(instance.exitConditions),
      'risk_controls': Strategy._listToJson(instance.riskControls),
      'create_time': instance.createTime.toIso8601String(),
      'update_time': instance.updateTime?.toIso8601String(),
      'is_active': instance.isActive,
    };
