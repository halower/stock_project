import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ai_filter_usage.dart';

class AIFilterService {
  static const String _aiFilterUsageKey = 'ai_filter_usage';
  
  // 加载使用统计
  static Future<AIFilterUsage> loadUsage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usageString = prefs.getString(_aiFilterUsageKey);
      
      if (usageString == null || usageString.isEmpty) {
        return AIFilterUsage.defaultUsage();
      }
      
      final map = json.decode(usageString) as Map<String, dynamic>;
      return AIFilterUsage.fromJson(map);
    } catch (e) {
      debugPrint('加载AI筛选使用统计出错: $e');
      return AIFilterUsage.defaultUsage();
    }
  }
  
  // 保存使用统计
  static Future<bool> saveUsage(AIFilterUsage usage) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usageString = json.encode(usage.toJson());
      
      final result = await prefs.setString(_aiFilterUsageKey, usageString);
      return result;
    } catch (e) {
      debugPrint('保存AI筛选使用统计出错: $e');
      return false;
    }
  }
  
  // 检查是否可以使用AI筛选功能
  // 注意：因为用户使用自己的模型配置，所以不再限制次数
  static Future<bool> canUseAIFilter() async {
    try {
      // 所有用户都可以使用（因为使用自己的模型配置）
      return true;
    } catch (e) {
      debugPrint('检查AI筛选使用权限出错: $e');
      return false;
    }
  }
  
  // 记录一次使用并保存
  static Future<bool> recordUsage() async {
    try {
      final usage = await loadUsage();
      usage.recordUsage();
      return await saveUsage(usage);
    } catch (e) {
      debugPrint('记录AI筛选使用统计出错: $e');
      return false;
    }
  }
  
  // 获取剩余使用次数
  // 注意：因为用户使用自己的模型配置，所以不再限制次数
  static Future<int> getRemainingCount() async {
    try {
      // 返回无限次数
      return 999999;
    } catch (e) {
      debugPrint('获取AI筛选剩余次数出错: $e');
      return 999999;
    }
  }
  
  // 获取格式化的剩余使用次数文本
  static Future<String> getRemainingCountText() async {
    // 所有用户都不限次数（使用自己的模型配置）
    return '不限次数（使用您的模型配置）';
  }
} 