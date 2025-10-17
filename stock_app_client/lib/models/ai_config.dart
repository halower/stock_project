import 'package:json_annotation/json_annotation.dart';

part 'ai_config.g.dart';

@JsonSerializable()
class AIConfig {
  // AI模型配置
  String? customUrl;
  String? apiKey;
  String? model;
  
  // 管理员专用的默认配置（普通用户无法使用）
  static const String _adminDefaultApiKey = 'sk-vkicbsufdotlqbxpgehvrcwuguhpyelezcgfvnmirvrzynnt';
  static const String _adminDefaultApiEndpoint = 'https://api.siliconflow.cn/v1/chat/completions';
  static const String _adminDefaultModel = 'deepseek-ai/DeepSeek-R1-Distill-Qwen-7B';
  
  // 管理员账号列表（可以使用默认配置的用户）
  static const List<String> adminUsers = [
    'admin',
    'administrator', 
    'root',
    // 可以在这里添加更多管理员账号
  ];
  
  // AI配置参数
  static const bool enableThinking = true; // 启用AI思考过程
  static const int thinkingBudget = 4096; // 思考过程token预算
  
  // API参数配置
  static const int maxTokens = 4096;
  static const double temperature = 0.7;
  static const double topP = 0.7;
  static const int topK = 50;
  static const double minP = 0.05;
  static const double frequencyPenalty = 0.5;
  
  AIConfig({
    this.customUrl,
    this.apiKey,
    this.model,
  });
  
  // 判断是否有API密钥
  bool get hasApiKey => apiKey?.isNotEmpty == true;
  
  // 判断是否有完整配置（URL和API密钥都必须有）
  bool get hasValidConfig => hasApiKey && customUrl?.isNotEmpty == true;
  
  // 检查是否为管理员用户
  static bool isAdminUser(String? username) {
    if (username == null || username.isEmpty) return false;
    return adminUsers.contains(username.toLowerCase());
  }
  
  // 获取默认API密钥（仅管理员可用）
  static String? getDefaultApiKey(String? username) {
    return isAdminUser(username) ? _adminDefaultApiKey : null;
  }
  
  // 获取默认API地址（仅管理员可用）
  static String? getDefaultApiEndpoint(String? username) {
    return isAdminUser(username) ? _adminDefaultApiEndpoint : null;
  }
  
  // 获取默认模型（仅管理员可用）
  static String? getDefaultModel(String? username) {
    return isAdminUser(username) ? _adminDefaultModel : null;
  }
  
  // 验证API地址格式是否正确（必须是完整的URL）
  static bool isValidApiEndpoint(String? endpoint) {
    if (endpoint == null || endpoint.isEmpty) return false;
    
    // 必须是完整的HTTP/HTTPS URL
    final uri = Uri.tryParse(endpoint);
    if (uri == null) return false;
    
    // 必须包含协议
    if (!uri.hasScheme || (!uri.scheme.startsWith('http'))) return false;
    
    // 必须包含主机名
    if (!uri.hasAuthority || uri.host.isEmpty) return false;
    
    // 建议包含chat/completions路径
    return true;
  }
  
  // 获取API地址示例
  static List<String> getApiEndpointExamples() {
    return [
      'https://api.openai.com/v1/chat/completions',
      'https://api.deepseek.com/v1/chat/completions', 
      'https://api.siliconflow.cn/v1/chat/completions',
      'https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation',
    ];
  }
  
  // 从JSON创建
  factory AIConfig.fromJson(Map<String, dynamic> json) => _$AIConfigFromJson(json);
  
  // 转换为JSON
  Map<String, dynamic> toJson() => _$AIConfigToJson(this);
} 