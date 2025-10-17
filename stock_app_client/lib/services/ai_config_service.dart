import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ai_config.dart';

class AIConfigService {
  static const String _aiConfigKey = 'ai_config';
  static const String _currentUserKey = 'current_user';
  
  // 获取当前登录用户
  static Future<String?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_currentUserKey);
    } catch (e) {
      debugPrint('获取当前用户出错: $e');
      return null;
    }
  }
  
  // 设置当前登录用户
  static Future<bool> setCurrentUser(String username) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final result = await prefs.setString(_currentUserKey, username);
      
      // 如果是管理员且没有AI配置，自动初始化默认配置
      if (result && AIConfig.isAdminUser(username)) {
        await _initializeAdminConfig();
      }
      
      return result;
    } catch (e) {
      debugPrint('设置当前用户出错: $e');
      return false;
    }
  }
  
  // 为管理员初始化默认配置
  static Future<void> _initializeAdminConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configString = prefs.getString(_aiConfigKey);
      
      // 如果没有配置或配置为空，自动创建默认配置
      if (configString == null || configString.isEmpty) {
        final defaultConfig = AIConfig(
          customUrl: AIConfig.getDefaultApiEndpoint('admin'),
          apiKey: AIConfig.getDefaultApiKey('admin'),
          model: AIConfig.getDefaultModel('admin'),
        );
        
        // 直接保存到SharedPreferences，不通过saveConfig方法避免验证
        final configJson = json.encode(defaultConfig.toJson());
        await prefs.setString(_aiConfigKey, configJson);
        
        debugPrint('已为管理员自动初始化默认AI配置');
      }
    } catch (e) {
      debugPrint('初始化管理员AI配置出错: $e');
    }
  }
  
  // 加载AI配置（考虑用户权限）
  static Future<AIConfig> loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configString = prefs.getString(_aiConfigKey);
      final currentUser = await getCurrentUser();
      
      if (configString == null || configString.isEmpty) {
        return _createDefaultConfig(currentUser);
      }
      
      final map = json.decode(configString) as Map<String, dynamic>;
      final userConfig = AIConfig.fromJson(map);
      
      return userConfig;
    } catch (e) {
      debugPrint('加载AI配置出错: $e');
      final currentUser = await getCurrentUser();
      return _createDefaultConfig(currentUser);
    }
  }
  
  // 创建默认配置（根据用户权限）
  static AIConfig _createDefaultConfig(String? username) {
    // 所有用户都返回空配置，优先使用自定义配置
    // 管理员在没有自定义配置时才使用系统默认配置
      return AIConfig();
  }
  
  // 保存AI配置（验证权限和格式）
  static Future<Map<String, dynamic>> saveConfig(AIConfig aiConfig) async {
    try {
      final currentUser = await getCurrentUser();
      
      // 验证API地址格式
      if (aiConfig.customUrl != null && aiConfig.customUrl!.isNotEmpty) {
        if (!AIConfig.isValidApiEndpoint(aiConfig.customUrl)) {
          return {
            'success': false,
            'message': 'API地址格式不正确，请输入完整的URL地址',
          };
        }
      }
      
      // 检查是否有有效配置
      if (!aiConfig.hasApiKey || 
          (aiConfig.customUrl == null || aiConfig.customUrl!.isEmpty)) {
        if (!AIConfig.isAdminUser(currentUser)) {
          return {
            'success': false,
            'message': '普通用户必须配置完整的API服务地址和密钥',
          };
        }
      }
      
      final prefs = await SharedPreferences.getInstance();
      final configString = json.encode(aiConfig.toJson());
      
      final result = await prefs.setString(_aiConfigKey, configString);
      
      if (result) {
        return {
          'success': true,
          'message': 'AI配置保存成功',
        };
      } else {
        return {
          'success': false,
          'message': '保存配置失败',
        };
      }
    } catch (e) {
      debugPrint('保存AI配置出错: $e');
      return {
        'success': false,
        'message': '保存失败: $e',
      };
    }
  }
  
  // 清除AI配置
  static Future<bool> clearConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final result = await prefs.remove(_aiConfigKey);
      return result;
    } catch (e) {
      debugPrint('清除AI配置出错: $e');
      return false;
    }
  }
  
  // 获取有效的API地址（必须已配置）
  static Future<String?> getEffectiveUrl() async {
    final config = await loadConfig();
    return config.customUrl;
  }
  
  // 获取有效的模型（必须已配置）
  static Future<String?> getEffectiveModel() async {
    final config = await loadConfig();
    return config.model;
  }
  
  // 获取有效的API密钥（必须已配置）
  static Future<String?> getEffectiveApiKey() async {
    final config = await loadConfig();
    return config.apiKey;
  }
  
  // 检查是否有有效的AI配置
  static Future<bool> hasValidConfig() async {
    final config = await loadConfig();
    final url = config.customUrl;
    final apiKey = config.apiKey;
    
    return url != null && url.isNotEmpty && 
           apiKey != null && apiKey.isNotEmpty &&
           AIConfig.isValidApiEndpoint(url);
  }
  
  // 检查当前用户是否可以使用AI功能
  static Future<Map<String, dynamic>> canUseAI() async {
    final currentUser = await getCurrentUser();
    final isAdmin = AIConfig.isAdminUser(currentUser);
    
    // 所有用户都需要检查是否有有效配置
    final config = await loadConfig();
    final hasApiKey = config.apiKey != null && config.apiKey!.isNotEmpty;
    final hasUrl = config.customUrl != null && config.customUrl!.isNotEmpty;
    
    if (hasApiKey && hasUrl && AIConfig.isValidApiEndpoint(config.customUrl)) {
      return {
        'canUse': true,
        'message': isAdmin ? '管理员权限，已配置AI服务' : '已配置AI服务，可以使用',
        'isAdmin': isAdmin,
      };
    } else if (isAdmin && (!hasApiKey || !hasUrl)) {
      // 管理员没有配置时自动初始化
      await _initializeAdminConfig();
      return {
        'canUse': true,
        'message': '管理员权限，已自动配置默认AI服务',
        'isAdmin': true,
      };
    } else {
      return {
        'canUse': false,
        'message': '请先在AI模型设置中配置完整的API服务地址和API密钥',
        'isAdmin': isAdmin,
        'hasApiKey': hasApiKey,
        'hasUrl': hasUrl,
      };
    }
  }
  
  // 检查当前用户是否为管理员
  static Future<bool> isCurrentUserAdmin() async {
    final currentUser = await getCurrentUser();
    return AIConfig.isAdminUser(currentUser);
  }
  
  // 获取API地址示例
  static List<String> getApiEndpointExamples() {
    return AIConfig.getApiEndpointExamples();
  }
} 