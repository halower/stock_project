import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import 'http_client.dart';

class Strategy {
  final String id;
  final String name;
  final String code;
  final String description;
  final Map<String, dynamic> parameters;

  Strategy({
    required this.id,
    required this.name,
    required this.code,
    required this.description,
    required this.parameters,
  });

  factory Strategy.fromJson(Map<String, dynamic> json) {
    return Strategy(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      description: json['description'] ?? '',
      parameters: json['parameters'] ?? {},
    );
  }
}

class StrategyService {
  // 获取策略列表
  Future<List<Map<String, dynamic>>> getStrategies() async {
    try {
      debugPrint('请求策略列表');
      final response = await HttpClient.get(ApiConfig.strategiesEndpoint);
    
    if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        final data = json.decode(responseBody);
        final List<dynamic> strategies = data['strategies'] as List<dynamic>;
        debugPrint('获取到策略列表: ${strategies.length}个');
        
        return List<Map<String, dynamic>>.from(strategies);
    } else {
        debugPrint('获取策略列表失败: ${response.statusCode}, ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('获取策略列表出错: $e');
      return [];
    }
  }
  
  // 获取策略详情
  Future<Map<String, dynamic>> getStrategyDetail(String strategyCode) async {
    try {
      final url = '${ApiConfig.strategyDetailEndpoint}/$strategyCode';
      debugPrint('请求策略详情: $url');
      
      final response = await HttpClient.get(url);
    
    if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        final data = json.decode(responseBody);
        debugPrint('获取到策略详情');
        
        return data;
    } else {
        debugPrint('获取策略详情失败: ${response.statusCode}, ${response.body}');
        return {};
      }
    } catch (e) {
      debugPrint('获取策略详情出错: $e');
      return {};
    }
  }
  
  // 将策略列表转换为下拉选择器使用的格式
  static List<Map<String, String>> convertToDropdownItems(List<Strategy> strategies) {
    return strategies.map((strategy) => {
      'value': strategy.code,
      'label': strategy.name,
    }).toList();
  }
} 