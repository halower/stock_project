import 'package:json_annotation/json_annotation.dart';

part 'ai_filter_usage.g.dart';

@JsonSerializable()
class AIFilterUsage {
  // 记录上次使用的日期，格式为"YYYY-MM-DD"
  String lastUsedDate;
  
  // 当天已使用的次数
  int usedCount;
  
  AIFilterUsage({
    required this.lastUsedDate,
    required this.usedCount,
  });
  
  // 检查今天是否还可以使用
  bool canUseToday(bool isAdmin) {
    // 管理员不受限制
    if (isAdmin) return true;
    
    // 检查是否是新的一天
    final today = DateTime.now().toString().split(' ')[0]; // 获取YYYY-MM-DD格式的日期
    
    // 如果是新的一天，重置计数器
    if (today != lastUsedDate) {
      return true;
    }
    
    return true;
  }
  
  // 记录一次使用
  void recordUsage() {
    final today = DateTime.now().toString().split(' ')[0];
    
    // 如果是新的一天，重置计数器
    if (today != lastUsedDate) {
      lastUsedDate = today;
      usedCount = 1;
    } else {
      // 增加使用次数
      usedCount++;
    }
  }
  
  // 获取剩余次数
  int getRemainingCount(bool isAdmin) {
    if (isAdmin) return -1; // -1表示无限制
    
    final today = DateTime.now().toString().split(' ')[0];
    
    // 如果是新的一天，重置计数器
    if (today != lastUsedDate) {
      return -1;
    }
    
    return -1;
  }
  
  // 默认值
  factory AIFilterUsage.defaultUsage() {
    final today = DateTime.now().toString().split(' ')[0];
    return AIFilterUsage(
      lastUsedDate: today,
      usedCount: 0,
    );
  }
  
  // JSON序列化相关
  factory AIFilterUsage.fromJson(Map<String, dynamic> json) => _$AIFilterUsageFromJson(json);
  Map<String, dynamic> toJson() => _$AIFilterUsageToJson(this);
} 