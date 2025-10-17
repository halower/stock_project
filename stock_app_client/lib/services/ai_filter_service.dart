import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ai_filter_usage.dart';
import 'auth_service.dart';

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
  static Future<bool> canUseAIFilter() async {
    try {
      final isAdmin = await AuthService.isAdmin();
      final usage = await loadUsage();
      
      return usage.canUseToday(isAdmin);
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
  static Future<int> getRemainingCount() async {
    try {
      final isAdmin = await AuthService.isAdmin();
      final usage = await loadUsage();
      
      return usage.getRemainingCount(isAdmin);
    } catch (e) {
      debugPrint('获取AI筛选剩余次数出错: $e');
      return 0;
    }
  }
  
  // 获取格式化的剩余使用次数文本
  static Future<String> getRemainingCountText() async {
    final count = await getRemainingCount();
    final isAdmin = await AuthService.isAdmin();
    
    if (isAdmin) {
      return '管理员不限次数';
    } else {
      return '今日剩余: $count 次';
    }
  }
} 