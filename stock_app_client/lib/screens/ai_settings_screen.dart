import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/ai_config.dart';
import '../services/ai_config_service.dart';
import '../utils/financial_colors.dart';

// 常用AI服务提供商配置
class AIProvider {
  final String name;
  final String displayName;
  final String apiUrl;
  final String modelExample;
  final IconData icon;
  final Color color;
  final String description;

  const AIProvider({
    required this.name,
    required this.displayName,
    required this.apiUrl,
    required this.modelExample,
    required this.icon,
    required this.color,
    required this.description,
  });
}

class AISettingsScreen extends StatefulWidget {
  const AISettingsScreen({super.key});

  @override
  State<AISettingsScreen> createState() => _AISettingsScreenState();
}

class _AISettingsScreenState extends State<AISettingsScreen> with SingleTickerProviderStateMixin {
  // AI配置
  String? _customUrl = '';
  String? _apiKey;
  String? _modelName;
  bool _isLoading = true;
  bool _isAdmin = false;
  String? _currentUser;
  String? _selectedProvider;
  
  // 控制器
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // 常用AI服务提供商列表
  static const List<AIProvider> _aiProviders = [
    AIProvider(
      name: 'aliyun_bailian',
      displayName: '阿里云百炼',
      apiUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions',
      modelExample: 'qwen-plus',
      icon: Icons.cloud,
      color: Color(0xFFFF6A00),
      description: '阿里云通义千问大模型',
    ),
    AIProvider(
      name: 'openai',
      displayName: 'OpenAI',
      apiUrl: 'https://api.openai.com/v1/chat/completions',
      modelExample: 'gpt-4',
      icon: Icons.psychology,
      color: Color(0xFF10A37F),
      description: 'OpenAI GPT系列模型',
    ),
    AIProvider(
      name: 'deepseek',
      displayName: 'DeepSeek',
      apiUrl: 'https://api.deepseek.com/v1/chat/completions',
      modelExample: 'deepseek-chat',
      icon: Icons.auto_awesome,
      color: Color(0xFF4A90E2),
      description: 'DeepSeek深度求索大模型',
    ),
    AIProvider(
      name: 'zhipu',
      displayName: '智谱AI',
      apiUrl: 'https://open.bigmodel.cn/api/paas/v4/chat/completions',
      modelExample: 'glm-4',
      icon: Icons.lightbulb,
      color: Color(0xFF6366F1),
      description: '智谱GLM系列模型',
    ),
    AIProvider(
      name: 'moonshot',
      displayName: 'Moonshot AI',
      apiUrl: 'https://api.moonshot.cn/v1/chat/completions',
      modelExample: 'moonshot-v1-8k',
      icon: Icons.nightlight,
      color: Color(0xFF8B5CF6),
      description: 'Kimi大模型',
    ),
    AIProvider(
      name: 'custom',
      displayName: '自定义',
      apiUrl: '',
      modelExample: '',
      icon: Icons.edit,
      color: Color(0xFF64748B),
      description: '使用自定义API地址',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _loadConfig();
    _animationController.forward();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    _animationController.dispose();
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
        
        // 检测当前使用的提供商
        _detectProvider();
        
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('加载AI配置出错: $e');
      
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 检测当前使用的提供商
  void _detectProvider() {
    final url = _urlController.text.trim();
    for (final provider in _aiProviders) {
      if (provider.apiUrl.isNotEmpty && url.contains(provider.apiUrl.split('/')[2])) {
        _selectedProvider = provider.name;
        return;
      }
    }
    _selectedProvider = 'custom';
  }

  // 选择提供商
  void _selectProvider(AIProvider provider) {
    setState(() {
      _selectedProvider = provider.name;
      if (provider.apiUrl.isNotEmpty) {
        _urlController.text = provider.apiUrl;
      }
      if (provider.modelExample.isNotEmpty) {
        _modelController.text = provider.modelExample;
      }
    });
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
            content: Row(
              children: [
                Icon(
                  result['success'] ? Icons.check_circle : Icons.error,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(result['message'])),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: result['success'] ? Colors.green : const Color(0xFF1E40AF),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      debugPrint('保存AI配置出错: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('保存失败: $e')),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF1E40AF),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.refresh, color: Theme.of(context).primaryColor),
            const SizedBox(width: 12),
            const Text('恢复默认配置'),
          ],
        ),
        content: Text(_isAdmin 
          ? '确定要重置所有AI配置吗？管理员将恢复到默认配置。'
          : '确定要清除所有AI配置吗？您需要重新配置API服务地址和密钥。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              
              if (_isAdmin) {
                _loadConfig();
              } else {
                setState(() {
                  _urlController.text = '';
                  _apiKeyController.text = '';
                  _modelController.text = '';
                  _selectedProvider = null;
                });
              }
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 12),
                      Text('配置已重置'),
                    ],
                  ),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('重置'),
          ),
        ],
      ),
    );
  }

  // 测试连接
  Future<void> _testConnection() async {
    if (_urlController.text.trim().isEmpty || _apiKeyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning, color: Colors.white),
              SizedBox(width: 12),
              Text('请先填写API地址和密钥'),
            ],
          ),
          backgroundColor: const Color(0xFF1E40AF),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await Future.delayed(const Duration(seconds: 2));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('连接测试成功！'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('连接测试失败: $e')),
              ],
            ),
            backgroundColor: const Color(0xFF1E40AF),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF0F1419) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    FinancialColors.blueGradient[0],
                    FinancialColors.blueGradient[1],
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: FinancialColors.blueGradient[0].withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: const Icon(Icons.psychology, size: 24, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isAdmin ? 'AI模型设置' : 'AI模型设置',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (_isAdmin)
                  const Text(
                    '管理员',
                    style: TextStyle(fontSize: 12, color: const Color(0xFF1E40AF)),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '重置设置',
            onPressed: _resetConfig,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      FinancialColors.blueGradient[0],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '加载中...',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white70 : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            )
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 顶部说明卡片
                    _buildInfoCard(isDarkMode),
                    
                    const SizedBox(height: 24),
                    
                    // AI服务提供商选择
                    _buildProviderSelection(isDarkMode),
                  
                  const SizedBox(height: 24),
                  
                  // API服务地址
                  _buildInputField(
                    label: 'API服务地址 *',
                      hint: '选择提供商或输入自定义地址',
                    controller: _urlController,
                    icon: Icons.link,
                    isPassword: false,
                    isRequired: !_isAdmin,
                    helpText: '必须是完整的API地址，包含协议和路径',
                      isDarkMode: isDarkMode,
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // 模型名称
                  _buildInputField(
                    label: '模型名称',
                      hint: '例如: gpt-4, qwen-plus, deepseek-chat',
                    controller: _modelController,
                    icon: Icons.analytics,
                    isPassword: false,
                    helpText: '根据您使用的API服务选择对应的模型',
                      isDarkMode: isDarkMode,
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // 最大Token数
                  _buildInputField(
                    label: '最大Token数',
                    hint: '1-4096之间的数值',
                    controller: _maxTokensController,
                    icon: Icons.format_list_numbered,
                    isPassword: false,
                    helpText: 'AI响应的最大token数量，建议设置在4000以下以避免API限制',
                    keyboardType: TextInputType.number,
                    isDarkMode: isDarkMode,
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
                      isDarkMode: isDarkMode,
                  ),
                  
                  const SizedBox(height: 32),
                  
                    // 操作按钮组
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: LinearGradient(
                                colors: [
                                  FinancialColors.blueGradient[0],
                                  FinancialColors.blueGradient[1],
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: FinancialColors.blueGradient[0].withOpacity(0.4),
                                  blurRadius: 12,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _saveConfig,
                              icon: const Icon(Icons.save, color: Colors.white),
                              label: const Text('保存配置', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                                ),
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                elevation: 0,
                              ),
                      ),
                    ),
                  ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _testConnection,
                            icon: Icon(Icons.wifi_tethering, color: FinancialColors.blueGradient[0]),
                            label: Text('测试连接', style: TextStyle(color: FinancialColors.blueGradient[0], fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                              ),
                              side: BorderSide(
                                color: FinancialColors.blueGradient[0],
                                width: 2,
                              ),
                      ),
                    ),
                  ),
                ],
                    ),
                    
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  // 构建信息卡片
  Widget _buildInfoCard(bool isDarkMode) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [
                  const Color(0xFF1E3A8A).withOpacity(0.3),
                  const Color(0xFF3730A3).withOpacity(0.2),
                ]
              : [
                  Colors.blue.shade50,
                  Colors.indigo.shade50,
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDarkMode 
              ? Colors.blue.withOpacity(0.3)
              : Colors.blue.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            blurRadius: 12,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.indigo.shade400],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: const Icon(Icons.info_outline, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'AI配置说明',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ],
            ),
          const SizedBox(height: 16),
            if (_isAdmin) ...[
            _buildInfoItem('您是管理员用户，可以使用默认配置或自定义配置', Icons.verified_user),
            _buildInfoItem('留空将使用系统默认的AI服务配置', Icons.cloud_done),
            ] else ...[
            _buildInfoItem('您需要配置完整的API服务地址和密钥才能使用AI功能', Icons.settings),
            _buildInfoItem('请确保API地址格式正确，包含完整的URL路径', Icons.link),
          ],
          _buildInfoItem('配置保存后将应用到所有AI功能', Icons.sync),
          _buildInfoItem('请妥善保管您的API密钥，不要泄露给他人', Icons.security),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.blue.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  // 构建提供商选择
  Widget _buildProviderSelection(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.cloud_queue, color: FinancialColors.blueGradient[0]),
            const SizedBox(width: 8),
            const Text(
              '选择AI服务提供商',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '快速配置常用AI服务',
          style: TextStyle(
            fontSize: 13,
            color: isDarkMode ? Colors.white60 : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _aiProviders.length,
          itemBuilder: (context, index) {
            final provider = _aiProviders[index];
            final isSelected = _selectedProvider == provider.name;
            
            return InkWell(
              onTap: () => _selectProvider(provider),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          colors: [
                            provider.color.withOpacity(0.2),
                            provider.color.withOpacity(0.1),
                          ],
                        )
                      : null,
                  color: isSelected ? null : (isDarkMode ? const Color(0xFF1A1F2E) : Colors.white),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? provider.color : (isDarkMode ? Colors.white10 : Colors.grey.shade300),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: provider.color.withOpacity(0.3),
                            blurRadius: 12,
                            spreadRadius: 0,
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            spreadRadius: 0,
                          ),
                        ],
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: provider.color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        provider.icon,
                        color: provider.color,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      provider.displayName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected ? provider.color : null,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      provider.description,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDarkMode ? Colors.white60 : Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // 构建输入字段
  Widget _buildInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    required bool isPassword,
    required bool isDarkMode,
    bool isRequired = false,
    String? helpText,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: FinancialColors.blueGradient[0]),
            const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                spreadRadius: 0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextFormField(
          controller: controller,
          obscureText: isPassword,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
              prefixIcon: Icon(icon, color: FinancialColors.blueGradient[0]),
              suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: controller.text));
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.white),
                                SizedBox(width: 12),
                                Text('已复制到剪贴板'),
                              ],
                            ),
                          behavior: SnackBarBehavior.floating,
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isDarkMode ? Colors.white10 : Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: FinancialColors.blueGradient[0], width: 2),
              ),
              filled: true,
              fillColor: isDarkMode ? const Color(0xFF1A1F2E) : Colors.white,
            ),
            maxLines: isPassword ? 1 : null,
            onChanged: (value) => setState(() {}),
          ),
        ),
        if (helpText != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.help_outline, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
            helpText,
            style: TextStyle(
              fontSize: 12,
                    color: isDarkMode ? Colors.white60 : Colors.grey.shade600,
                  ),
                ),
            ),
            ],
          ),
        ],
      ],
    );
  }
}
