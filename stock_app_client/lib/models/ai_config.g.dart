// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AIConfig _$AIConfigFromJson(Map json) => $checkedCreate(
      'AIConfig',
      json,
      ($checkedConvert) {
        final val = AIConfig(
          customUrl: $checkedConvert('custom_url', (v) => v as String?),
          apiKey: $checkedConvert('api_key', (v) => v as String?),
          model: $checkedConvert('model', (v) => v as String?),
        );
        return val;
      },
      fieldKeyMap: const {'customUrl': 'custom_url', 'apiKey': 'api_key'},
    );

Map<String, dynamic> _$AIConfigToJson(AIConfig instance) => <String, dynamic>{
      'custom_url': instance.customUrl,
      'api_key': instance.apiKey,
      'model': instance.model,
    };
