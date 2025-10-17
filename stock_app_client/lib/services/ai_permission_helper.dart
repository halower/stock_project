 import 'package:flutter/material.dart';
import 'ai_config_service.dart';
import '../widgets/ai_config_required_dialog.dart';

/// AI权限检查和提示辅助类
class AIPermissionHelper {
  /// 检查AI权限并在需要时显示配置对话框
  /// 
  /// [context] - 用于显示对话框的上下文
  /// [feature] - 功能名称，用于提示对话框
  /// [description] - 功能描述，用于提示对话框
  /// [canCancel] - 是否允许取消，默认为true
  /// 
  /// 返回true表示有权限使用AI功能，false表示需要配置
  static Future<bool> checkPermissionAndPrompt(
    BuildContext context, {
    required String feature,
    String? description,
    bool canCancel = true,
  }) async {
    final aiPermission = await AIConfigService.canUseAI();
    
    if (aiPermission['canUse'] == true) {
      return true;
    }
    
    // 显示专业的配置提示对话框
    final shouldConfigure = await AIConfigRequiredDialog.show(
      context,
      feature: feature,
      description: description ?? '',
      canCancel: canCancel,
    );
    
    return false; // 用户选择配置后仍然返回false，需要重新检查
  }
  
  /// 仅检查AI权限，不显示对话框
  /// 
  /// 返回 {canUse: bool, message: String, ...}
  static Future<Map<String, dynamic>> checkPermission() async {
    return await AIConfigService.canUseAI();
  }
  
  /// 获取AI配置参数，如果没有配置则抛出异常
  /// 
  /// 返回 {url: String, apiKey: String, model: String?}
  static Future<Map<String, String?>> getAIConfigOrThrow() async {
    final url = await AIConfigService.getEffectiveUrl();
    final apiKey = await AIConfigService.getEffectiveApiKey();
    final model = await AIConfigService.getEffectiveModel();
    
    if (url == null || url.isEmpty || apiKey == null || apiKey.isEmpty) {
      throw Exception('AI配置无效，请先配置完整的API服务地址和API密钥');
    }
    
    return {
      'url': url,
      'apiKey': apiKey,
      'model': model,
    };
  }
  
  /// 在界面上显示AI配置缺失的温馨提示
  /// 
  /// [context] - 上下文
  /// [feature] - 功能名称
  /// [onConfigPressed] - 点击配置按钮的回调
  static Widget buildConfigMissingWidget(
    BuildContext context, {
    required String feature,
    VoidCallback? onConfigPressed,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.psychology_outlined,
            size: 48,
            color: Colors.orange.shade600,
          ),
          const SizedBox(height: 16),
          Text(
            '使用 $feature 需要配置AI服务',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '请先在AI模型设置中配置完整的API服务地址和密钥',
            style: TextStyle(
              fontSize: 14,
              color: Colors.orange.shade700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onConfigPressed ?? () async {
              await checkPermissionAndPrompt(
                context,
                feature: feature,
                canCancel: true,
              );
            },
            icon: const Icon(Icons.settings),
            label: const Text('立即配置'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// 构建简洁的配置提示条
  static Widget buildConfigBar(
    BuildContext context, {
    required String feature,
    VoidCallback? onConfigPressed,
  }) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.amber.shade700,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '使用$feature需要配置AI服务',
              style: TextStyle(
                color: Colors.amber.shade800,
                fontSize: 14,
              ),
            ),
          ),
          TextButton(
            onPressed: onConfigPressed ?? () async {
              await checkPermissionAndPrompt(
                context,
                feature: feature,
                canCancel: true,
              );
            },
            child: const Text('配置'),
          ),
        ],
      ),
    );
  }
} 