import 'package:json_annotation/json_annotation.dart';
import 'dart:convert';

part 'strategy.g.dart';

@JsonSerializable()
class Strategy {
  @JsonKey(name: 'id')
  final int? id;
  @JsonKey(name: 'name')
  final String name;
  @JsonKey(name: 'description')
  final String? description;
  @JsonKey(name: 'entry_conditions', fromJson: _listFromJson, toJson: _listToJson)
  final List<String> entryConditions;
  @JsonKey(name: 'exit_conditions', fromJson: _listFromJson, toJson: _listToJson)
  final List<String> exitConditions;
  @JsonKey(name: 'risk_controls', fromJson: _listFromJson, toJson: _listToJson)
  final List<String> riskControls;
  @JsonKey(name: 'create_time')
  final DateTime createTime;
  @JsonKey(name: 'update_time')
  final DateTime? updateTime;
  @JsonKey(name: 'is_active')
  final bool isActive;

  Strategy({
    this.id,
    required this.name,
    this.description,
    required this.entryConditions,
    required this.exitConditions,
    required this.riskControls,
    this.isActive = true,
    required this.createTime,
    this.updateTime,
  });

  static List<String> _listFromJson(String json) => 
      List<String>.from(jsonDecode(json));
  
  static String _listToJson(List<String> list) => 
      jsonEncode(list);

  factory Strategy.fromJson(Map<String, dynamic> json) => 
      _$StrategyFromJson(json);

  Map<String, dynamic> toJson() => _$StrategyToJson(this);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'entry_conditions': entryConditions.join(','),
      'exit_conditions': exitConditions.join(','),
      'risk_controls': riskControls.join(','),
      'is_active': isActive ? 1 : 0,
      'create_time': createTime.toIso8601String(),
      'update_time': updateTime?.toIso8601String(),
    };
  }

  factory Strategy.fromMap(Map<String, dynamic> map) {
    return Strategy(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String?,
      entryConditions: (map['entry_conditions'] as String).split(','),
      exitConditions: (map['exit_conditions'] as String).split(','),
      riskControls: (map['risk_controls'] as String).split(','),
      isActive: map['is_active'] == 1,
      createTime: DateTime.parse(map['create_time'] as String),
      updateTime: map['update_time'] == null ? null : DateTime.parse(map['update_time'] as String),
    );
  }

  Strategy copyWith({
    int? id,
    String? name,
    String? description,
    List<String>? entryConditions,
    List<String>? exitConditions,
    List<String>? riskControls,
    bool? isActive,
    DateTime? createTime,
    DateTime? updateTime,
  }) {
    return Strategy(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      entryConditions: entryConditions ?? this.entryConditions,
      exitConditions: exitConditions ?? this.exitConditions,
      riskControls: riskControls ?? this.riskControls,
      isActive: isActive ?? this.isActive,
      createTime: createTime ?? this.createTime,
      updateTime: updateTime ?? this.updateTime,
    );
  }
} 




