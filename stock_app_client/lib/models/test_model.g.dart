// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'test_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TestModel _$TestModelFromJson(Map json) => $checkedCreate(
      'TestModel',
      json,
      ($checkedConvert) {
        final val = TestModel(
          name: $checkedConvert('name', (v) => v as String),
          age: $checkedConvert('age', (v) => (v as num).toInt()),
        );
        return val;
      },
    );

Map<String, dynamic> _$TestModelToJson(TestModel instance) => <String, dynamic>{
      'name': instance.name,
      'age': instance.age,
    };
