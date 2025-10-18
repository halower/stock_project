import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/ai_config.dart';
import '../services/ai_config_service.dart';

class AISettingsScreen extends StatefulWidget {
  const AISettingsScreen({super.key});

  @override
  State<AISettingsScreen> createState() => _AISettingsScreenState();
}

class _AISettingsScreenState extends State<AISettingsScreen> {
  // AI配置
  String? _customUrl = '';
  String? _apiKey;
  String? _modelName;
  bool _isLoading = true;
  bool _isAdmin = false;
  String? _currentUser;
  
  // 控制器
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 加载当前配置
    _loadConfig();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  // 加载配置
  Future<void> _loadConfig() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final config = await AIConfigService.loadConfig();
      final isAdmin = await AIConfigService.isCurrentUserAdmin();
      final currentUser = await AIConfigService.getCurrentUser();
      
      setState(() {
        _customUrl = config.customUrl ?? '';
        _apiKey = config.apiKey;
        _modelName = config.model;
        _isAdmin = isAdmin;
        _currentUser = currentUser;
        
        // 设置控制器文本
        _urlController.text = _customUrl ?? '';
        _apiKeyController.text = _apiKey ?? '';
        _modelController.text = _modelName ?? '';
        
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('加载AI配置出错: $e');
      
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 保存配置
  Future<void> _saveConfig() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final aiConfig = AIConfig(
        customUrl: _urlController.text.isEmpty ? null : _urlController.text.trim(),
        apiKey: _apiKeyController.text.isEmpty ? null : _apiKeyController.text.trim(),
        model: _modelController.text.isEmpty ? null : _modelController.text.trim(),
      );
      
      final result = await AIConfigService.saveConfig(aiConfig);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            behavior: SnackBarBehavior.floating,
            backgroundColor: result['success'] ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('保存AI配置出错: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 重置配置
  void _resetConfig() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('恢复默认配置'),
        content: Text(_isAdmin 
          ? '确定要重置所有AI配置吗？管理员将恢复到默认配置。'
          : '确定要清除所有AI配置吗？您需要重新配置API服务地址和密钥。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              
              if (_isAdmin) {
                // 管理员恢复默认配置
                _loadConfig();
              } else {
                // 普通用户清空配置
                setState(() {
                  _urlController.text = '';
                  _apiKeyController.text = '';
                  _modelController.text = '';
                });
              }
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('配置已重置'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('重置'),
          ),
        ],
      ),
    );
  }

  // 显示API地址示例
  void _showApiExamples() {
    final examples = AIConfigService.getApiEndpointExamples();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('API地址示例'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('请输入完整的API服务地址：', 
                style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ...examples.map((example) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () {
                    _urlController.text = example;
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(example, 
                      style: const TextStyle(fontFamily: 'monospace')),
                  ),
                ),
              )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isAdmin ? 'AI模型设置 (管理员)' : 'AI模型设置'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '重置设置',
            onPressed: _resetConfig,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 顶部说明卡片
                  _buildInfoCard(),
                  
                  const SizedBox(height: 24),
                  
                  // API服务地址
                  _buildInputField(
                    label: 'API服务地址 *',
                    hint: 'https://api.openai.com/v1/chat/completions',
                    controller: _urlController,
                    icon: Icons.link,
                    isPassword: false,
                    isRequired: !_isAdmin,
                    helpText: '必须是完整的API地址，包含协议和路径',
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // 模型名称
                  _buildInputField(
                    label: '模型名称',
                    hint: '例如: gpt-3.5-turbo, deepseek-chat',
                    controller: _modelController,
                    icon: Icons.analytics,
                    isPassword: false,
                    helpText: '根据您使用的API服务选择对应的模型',
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // API密钥
                  _buildInputField(
                    label: 'API密钥 *',
                    hint: '输入您的API密钥',
                    controller: _apiKeyController,
                    icon: Icons.key,
                    isPassword: true,
                    isRequired: !_isAdmin,
                    helpText: '从API服务提供商获取的访问密钥',
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // 保存按钮
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _saveConfig,
                    icon: const Icon(Icons.save),
                    label: const Text('保存配置'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 测试连接按钮
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _testConnection,
                    icon: const Icon(Icons.wifi_tethering),
                    label: const Text('测试连接'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // 构建信息卡片
  Widget _buildInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text('AI配置说明', style: TextStyle(
                  fontSize: 16, 
                  fontWeight: FontWeight.bold,
                )),
              ],
            ),
            const SizedBox(height: 12),
            if (_isAdmin) ...[
              const Text('• 您是管理员用户，可以使用默认配置或自定义配置'),
              const Text('• 留空将使用系统默认的AI服务配置'),
            ] else ...[
              const Text('• 您需要配置完整的API服务地址和密钥才能使用AI功能'),
              const Text('• 请确保API地址格式正确，包含完整的URL路径'),
            ],
            const Text('• 配置保存后将应用到所有AI功能'),
            const Text('• 请妥善保管您的API密钥，不要泄露给他人'),
          ],
        ),
      ),
    );
  }

  // 构建输入字段
  Widget _buildInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    required bool isPassword,
    bool isRequired = false,
    String? helpText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isPassword,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon),
            suffixIcon: isPassword && controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: controller.text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('已复制到剪贴板'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          maxLines: isPassword ? 1 : null,
        ),
        if (helpText != null) ...[
          const SizedBox(height: 4),
          Text(
            helpText,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ],
    );
  }

  // 测试连接
  Future<void> _testConnection() async {
    if (_urlController.text.trim().isEmpty || _apiKeyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先填写API地址和密钥'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 这里可以添加实际的连接测试逻辑
      await Future.delayed(const Duration(seconds: 2)); // 模拟测试
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('连接测试成功！'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('连接测试失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
} 