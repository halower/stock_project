import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../services/providers/theme_provider.dart';
import '../services/auth_service.dart';
import '../services/device_info_service.dart';
import '../services/ai_config_service.dart';
import '../widgets/auth_code_generator.dart';
import '../widgets/fingerprint_visualizer.dart';
import 'ai_settings_screen.dart';
import 'login_screen.dart';
import 'privacy_policy_screen.dart';
import 'feedback_screen.dart';
import '../services/password_lock_service.dart';
import '../widgets/password_lock_dialog.dart';
import '../widgets/password_verify_dialog.dart';
import '../utils/financial_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _darkMode = false;
  String _selectedFont = 'System Default';
  double _fontSize = 1.0; // 字体大小系数，1.0代表默认大小
  int _selectedColor = 0;
  bool _isLoading = true;
  bool _isAdmin = false; // 是否为管理员
  int _remainingDays = 0; // 剩余授权天数
  String? _deviceFingerprint; // 设备指纹
  Timer? _authCheckTimer; // 授权检查定时器
  
  // AI配置状态
  bool _isUsingCustomAI = false;
  String? _aiModel;

  // 可用的主题颜色选项
  final List<Color> _colorOptions = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.purple,
    Colors.orange,
    Colors.teal,
    Colors.indigo,
    Colors.pink,
  ];

  // 可选的字体 - 使用中文名称
  final List<String> _fontOptions = [
    '系统默认',          // System Default
    '思源黑体',          // Noto Sans SC
    '思源宋体',          // Noto Serif SC  
    '苹方字体',          // PingFang SC
    '微软雅黑',          // Microsoft YaHei
    'Roboto',          // Google Roboto字体
    'Open Sans',       // 开源字体
    'Lato',           // 拉丁字体
  ];
  
  // 字体名称映射（中文名称 -> 实际字体名称）
  final Map<String, String> _fontMapping = {
    '系统默认': 'System Default',
    '思源黑体': 'Noto Sans SC',
    '思源宋体': 'Noto Serif SC',
    '苹方字体': 'PingFang SC',
    '微软雅黑': 'Microsoft YaHei',
    'Roboto': 'Roboto',
    'Open Sans': 'Open Sans',
    'Lato': 'Lato',
  };

  bool _isPasswordLockEnabled = false;
  int _passwordLockTimeout = 5;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkAdminStatus();
    _loadDeviceInfo();
    _loadAIConfig();
    _loadPasswordLockSettings();
    _startAuthCheckTimer(); // 添加授权检查
  }

  @override
  void dispose() {
    _authCheckTimer?.cancel(); // 取消定时器
    super.dispose();
  }

  // 启动授权检查定时器
  void _startAuthCheckTimer() {
    // 取消现有的定时器（如果有）
    _authCheckTimer?.cancel();
    
    // 创建新的定时器，每30秒检查一次授权状态
    _authCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkAuthStatus();
    });
  }
  
  // 检查授权状态
  Future<void> _checkAuthStatus() async {
    final isAuthorized = await AuthService.isAuthorized();
    
    if (!isAuthorized && mounted) {
      // 授权已过期，立即退出到登录页面
      _authCheckTimer?.cancel(); // 取消定时器
      
      // 显示提示消息
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('授权已过期，请重新输入授权码'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      
      // 立即导航到登录页面
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false, // 清除所有路由栈
        );
      }
    }
  }

  // 加载设备信息
  Future<void> _loadDeviceInfo() async {
    final fingerprint = await DeviceInfoService.getDeviceFingerprint();
    
    if (mounted) {
      setState(() {
        _deviceFingerprint = fingerprint;
      });
    }
  }
  
  // 加载AI配置
  Future<void> _loadAIConfig() async {
    final config = await AIConfigService.loadConfig();
    
    if (mounted) {
      setState(() {
        _isUsingCustomAI = config.hasValidConfig;
        _aiModel = config.model;
      });
    }
  }

  // 检查管理员状态和授权剩余时间
  Future<void> _checkAdminStatus() async {
    final isAdmin = await AuthService.isAdmin();
    final remainingDays = await AuthService.getAuthRemainingDays();
    
    if (mounted) {
      setState(() {
        _isAdmin = isAdmin;
        _remainingDays = remainingDays;
      });
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    setState(() {
      _darkMode = prefs.getBool('darkMode') ?? false;
      // 从存储中获取实际字体名称，然后转换为中文显示名称
      final storedFont = prefs.getString('fontFamily') ?? 'System Default';
      _selectedFont = _getChineseFontName(storedFont);
      _fontSize = prefs.getDouble('fontSize') ?? 1.0;
      _selectedColor = prefs.getInt('themeColor') ?? 0;
      _isLoading = false;
    });
  }
  
  // 获取字体的中文显示名称
  String _getChineseFontName(String actualFontName) {
    for (final entry in _fontMapping.entries) {
      if (entry.value == actualFontName) {
        return entry.key;
      }
    }
    return '系统默认'; // 默认返回系统默认
  }
  
  // 获取字体的实际名称（用于存储和应用）
  String _getActualFontName(String chineseFontName) {
    return _fontMapping[chineseFontName] ?? 'System Default';
  }

  // 立即应用字体设置
  Future<void> _applyFontSettings() async {
    if (mounted) {
      try {
        final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
        final actualFontName = _getActualFontName(_selectedFont);
        themeProvider.setTheme(_darkMode, actualFontName, _fontSize);
        
        // 保存到本地存储（保存实际字体名称）
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fontFamily', actualFontName);
        await prefs.setDouble('fontSize', _fontSize);
      } catch (e) {
        debugPrint('应用字体设置出错: $e');
      }
    }
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', _darkMode);
    await prefs.setString('fontFamily', _getActualFontName(_selectedFont));
    await prefs.setDouble('fontSize', _fontSize);
    await prefs.setInt('themeColor', _selectedColor);
    
    // 如果使用了ThemeProvider，则更新主题
    if (mounted) {
      try {
        final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
        themeProvider.setTheme(_darkMode, _getActualFontName(_selectedFont), _fontSize);
      } catch (e) {
        debugPrint('ThemeProvider可能尚未实现: $e');
      }
      
      setState(() {
        _isLoading = false;
      });
      
      // 显示保存成功的提示
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('设置已保存'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // 显示授权码生成器
  void _showAuthCodeGenerator() {
    showDialog(
      context: context,
      builder: (context) => const AuthCodeGenerator(),
    );
  }
  
  // 打开AI设置页面
  void _openAISettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const AISettingsScreen()),
    );
    
    // 页面返回后刷新AI配置状态
    _loadAIConfig();
  }

  // 加载密码锁设置
  Future<void> _loadPasswordLockSettings() async {
    final isEnabled = await PasswordLockService.isPasswordLockEnabled();
    final timeout = await PasswordLockService.getLockTimeout();
    
    if (mounted) {
      setState(() {
        _isPasswordLockEnabled = isEnabled;
        _passwordLockTimeout = timeout;
      });
    }
  }
  
  // 显示密码锁设置对话框
  void _showPasswordLockDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => PasswordLockDialog(
        isEnabled: _isPasswordLockEnabled,
        onPasswordSet: () {
          // 密码设置成功后的回调
        },
      ),
    );
    
    // 对话框关闭后，重新加载设置
    if (result != null) {
      _loadPasswordLockSettings();
    }
  }
  
  // 处理密码锁开关状态变更
  void _handlePasswordLockToggle(bool value) async {
    if (value) {
      // 启用密码锁，显示设置对话框
      _showPasswordLockDialog();
    } else {
      // 禁用密码锁，需要验证当前密码
      if (_isPasswordLockEnabled) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => PasswordVerifyDialog(
            onSuccess: () async {
              // 验证成功，禁用密码锁
              await PasswordLockService.clearPassword();
              _loadPasswordLockSettings();
            },
          ),
        );
        
        if (confirmed == true) {
          // 密码验证成功，密码锁已被禁用
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('密码锁已禁用'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  // 格式化密码锁超时时间显示（从分钟转为天）
  String _formatLockTimeout(int minutes) {
    if (minutes == 1440) {
      return '1天';
    } else if (minutes == 21600) {
      return '15天';
    } else if (minutes == 43200) {
      return '30天';
    } else {
      // 转换为天数（向上取整）
      int days = (minutes / 1440).ceil();
      return '$days天';
    }
  }

  // 注销登录
  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('注销确认'),
        content: const Text('确定要注销登录吗？您需要重新输入授权码登录。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // 清除授权信息
              AuthService.clearAuth();
              // 跳转到登录页面
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false, // 清除所有路由栈
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('注销'),
          ),
        ],
      ),
    );
  }

  // 显示安全日志
  void _showSecurityLogs() async {
    final logs = await AuthService.getAuthBindingLogs();
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.security),
            SizedBox(width: 10),
            Text('设备授权安全日志'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: logs.isEmpty
              ? const Center(
                  child: Text('暂无授权记录'),
                )
              : ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    final timestamp = DateTime.fromMillisecondsSinceEpoch(
                      log['timestamp'] as int,
                    );
                    final bindingType = log['bindingType'] as String;
                    final currentDevice = log['currentDevice'] as String;
                    final authDevice = log['authDevice'] as String?;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(
                          bindingType == 'device_bound'
                              ? Icons.link
                              : Icons.link_off,
                          color: bindingType == 'device_bound'
                              ? Colors.green
                              : Colors.orange,
                        ),
                        title: Text(
                          bindingType == 'device_bound'
                              ? '设备绑定授权'
                              : '通用授权',
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '时间：${timestamp.toString().substring(0, 19)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              '当前设备：${currentDevice.substring(0, 8)}...',
                              style: const TextStyle(fontSize: 12),
                            ),
                            if (authDevice != null)
                              Text(
                                '授权设备：${authDevice.substring(0, 8)}...',
                                style: const TextStyle(fontSize: 12),
                              ),
                          ],
                        ),
                        trailing: bindingType == 'device_bound'
                            ? const Icon(Icons.verified, color: Colors.green, size: 16)
                            : const Icon(Icons.warning, color: Colors.orange, size: 16),
                      ),
                    );
                  },
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF0F1419) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        leading: Builder(
          builder: (context) {
            final parentScaffold = context.findAncestorStateOfType<ScaffoldState>();
            if (parentScaffold != null && parentScaffold.hasDrawer) {
              return IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () {
                  parentScaffold.openDrawer();
                },
              );
            }
            return const SizedBox.shrink();
          },
        ),
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
              child: const Icon(Icons.settings, size: 24, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '系统设置',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'System Settings',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showAboutDialog(
                context: context,
                applicationName: '交易大陆',
                applicationVersion: 'v1.2.11+2',
                applicationIcon: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        FinancialColors.blueGradient[0],
                        FinancialColors.blueGradient[1],
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.bar_chart_rounded, color: Colors.white, size: 32),
                ),
                applicationLegalese: '© 2023 交易大陆',
                children: const [
                  SizedBox(height: 16),
                  Text('交易大陆是一个专业的交易管理平台，帮助您更好地管理和分析您的投资组合。'),
                ],
              );
            },
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
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 显示授权信息
                _buildAuthInfoCard(),
                
                const SizedBox(height: 16),
                
                _buildSettingsGroup(
                  title: '外观',
                  children: [
                    // 暗色模式开关
                    _buildSettingItem(
                      title: '暗色模式',
                      subtitle: '切换应用的明暗主题',
                      trailing: Switch(
                        value: _darkMode,
                        onChanged: (value) {
                          final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
                          themeProvider.setDarkMode(value);
                          setState(() {
                            _darkMode = value;
                          });
                        },
                      ),
                    ),
                    
                    // 字体选择
                    _buildSettingItem(
                      title: '字体',
                      subtitle: '选择应用的字体 (当前: $_selectedFont)',
                      trailing: DropdownButton<String>(
                        value: _selectedFont,
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedFont = newValue;
                            });
                            // 立即应用字体设置
                            _applyFontSettings();
                          }
                        },
                        items: _fontOptions
                            .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value,
                              style: TextStyle(
                                fontFamily: _getActualFontName(value) == 'System Default' ? null : _getActualFontName(value),
                                fontSize: 14,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    
                    // 字体大小
                    _buildSettingItem(
                      title: '字体大小',
                      subtitle: '调整应用的字体大小',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${(_fontSize * 100).toInt()}%',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 100,
                            child: Slider(
                              value: _fontSize,
                              min: 0.8,
                              max: 1.4,
                              divisions: 6,
                              onChanged: (value) {
                                setState(() {
                                  _fontSize = value;
                                });
                                // 立即应用字体大小设置
                                _applyFontSettings();
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                
                // 字体预览
                if (_selectedFont != '系统默认')
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '字体预览',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '这是$_selectedFont字体的预览效果 - 股票交易分析系统',
                          style: TextStyle(
                            fontFamily: _getActualFontName(_selectedFont) == 'System Default' ? null : _getActualFontName(_selectedFont),
                            fontSize: 16 * _fontSize,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '1234567890 ABCDEFG abcdefg',
                          style: TextStyle(
                            fontFamily: _getActualFontName(_selectedFont) == 'System Default' ? null : _getActualFontName(_selectedFont),
                            fontSize: 14 * _fontSize,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 16),
                
                // AI模型设置入口
                _buildSettingsGroup(
                  title: 'AI服务',
                  children: [
                    _buildSettingItem(
                      title: 'AI模型设置',
                      subtitle: _isUsingCustomAI 
                          ? '已配置自定义模型: ${_aiModel ?? '未知模型'}'
                          : '使用系统默认配置',
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: _openAISettings,
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                _buildSettingsGroup(
                  title: '安全',
                  children: [
                    // 注销登录选项
                    _buildSettingItem(
                      title: '注销登录',
                      subtitle: '退出当前账号，返回到登录页面',
                      trailing: const Icon(Icons.logout, color: Colors.red),
                      onTap: _logout,
                    ),
                    
                    // 密码锁设置
                    _buildSettingItem(
                      title: '密码锁',
                      subtitle: _isPasswordLockEnabled 
                          ? '已启用 (${_formatLockTimeout(_passwordLockTimeout)})'
                          : '未启用 (开启以保护您的交易记录)',
                      trailing: Switch(
                        value: _isPasswordLockEnabled,
                        onChanged: _handlePasswordLockToggle,
                      ),
                    ),
                    
                    // 如果已启用密码锁，显示修改密码选项
                    if (_isPasswordLockEnabled)
                      _buildSettingItem(
                        title: '修改密码',
                        subtitle: '更改密码锁密码及设置',
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: _showPasswordLockDialog,
                      ),
                    
                    // 显示设备指纹 - 美化版
                    _buildDeviceFingerprint(),
                    
                    // 清除缓存
                    _buildSettingItem(
                      title: '清除缓存',
                      subtitle: '清除应用存储的临时数据',
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('清除缓存'),
                            content: const Text('确定要清除应用缓存吗？这将不会删除您的交易数据。'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('取消'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('缓存已清除'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                                child: const Text('确定'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    
                    // 管理员专属：生成授权码（仅管理员可见）
                    if (_isAdmin)
                      _buildSettingItem(
                        title: '生成授权码',
                        subtitle: '为用户生成有时效的授权码',
                        trailing: const Icon(Icons.vpn_key, color: Colors.orange),
                        onTap: _showAuthCodeGenerator,
                      ),


                  ],
                ),
                
                const SizedBox(height: 16),
                
                _buildSettingsGroup(
                  title: '关于',
                  children: [
                    // 应用版本
                    _buildSettingItem(
                      title: '版本',
                      subtitle: 'v1.2.11+2',
                      trailing: const Icon(Icons.info_outline, color: Colors.grey),
                    ),
                    
                    // 发送反馈
                    _buildSettingItem(
                      title: '发送反馈',
                      subtitle: '帮助我们改进应用',
                      trailing: const Icon(Icons.feedback_outlined, color: Colors.grey),
                      onTap: () {
                        Navigator.push(
                          context, 
                          MaterialPageRoute(builder: (context) => const FeedbackScreen()),
                        );
                      },
                    ),
                    
                    // 隐私政策
                    _buildSettingItem(
                      title: '隐私政策',
                      subtitle: '了解我们如何保护您的数据',
                      trailing: const Icon(Icons.privacy_tip_outlined, color: Colors.grey),
                      onTap: () {
                        Navigator.push(
                          context, 
                          MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()),
                        );
                      },
                    ),
                  ],
                ),
                
                const SizedBox(height: 32),
                
                // 保存按钮
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
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
                    onPressed: _saveSettings,
                    icon: const Icon(Icons.save, color: Colors.white),
                    label: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                        : const Text('保存设置', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // 授权信息卡片
  Widget _buildAuthInfoCard() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    String statusText;
    IconData statusIcon;
    Color statusColor;
    List<Color> gradientColors;
    
    if (_isAdmin) {
      statusText = '管理员账号 (永久授权)';
      statusIcon = Icons.verified_user;
      statusColor = Colors.green;
      gradientColors = [Colors.green.shade400, Colors.green.shade600];
    } else if (_remainingDays > 0) {
      statusText = '授权有效，剩余 $_remainingDays 天';
      statusIcon = Icons.check_circle;
      statusColor = Colors.blue;
      gradientColors = [Colors.blue.shade400, Colors.blue.shade600];
    } else {
      statusText = '授权已过期，请联系管理员';
      statusIcon = Icons.error;
      statusColor = Colors.red;
      gradientColors = [Colors.red.shade400, Colors.red.shade600];
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [
                  statusColor.withOpacity(0.2),
                  statusColor.withOpacity(0.1),
                ]
              : [
                  statusColor.withOpacity(0.1),
                  statusColor.withOpacity(0.05),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.2),
            blurRadius: 12,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradientColors),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withOpacity(0.4),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Icon(
              statusIcon,
                color: Colors.white,
              size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '授权状态',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 14,
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsGroup({required String title, required List<Widget> children}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [
                  const Color(0xFF1A1F2E).withOpacity(0.8),
                  const Color(0xFF0F1419).withOpacity(0.9),
                ]
              : [
                  Colors.white,
                  const Color(0xFFFAFBFC),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDarkMode 
              ? Colors.white.withOpacity(0.1)
              : FinancialColors.blueGradient[0].withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: FinancialColors.blueGradient[0].withOpacity(0.1),
            blurRadius: 12,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.05),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: FinancialColors.blueGradient[0].withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Icon(
                    _getSectionIcon(title),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                title,
                  style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
  
  // 根据标题获取对应图标
  IconData _getSectionIcon(String title) {
    switch (title) {
      case '外观':
        return Icons.palette;
      case 'AI服务':
        return Icons.psychology;
      case '安全':
        return Icons.security;
      case '关于':
        return Icons.info;
      default:
        return Icons.settings;
    }
  }

  Widget _buildSettingItem({
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceFingerprint() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showFingerprintDetails(),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (_deviceFingerprint != null)
                    FingerprintVisualizer(
                      fingerprint: _deviceFingerprint!,
                      size: 50,
                      color: Theme.of(context).primaryColor,
                    ),
                  if (_deviceFingerprint == null)
                    const SizedBox(
                      width: 50,
                      height: 50,
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '生物识别指纹',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '查看您的安全设备标识',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey.shade400),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _showFingerprintDetails() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.security, color: Theme.of(context).primaryColor),
            const SizedBox(width: 10),
            const Text('设备生物识别指纹'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_deviceFingerprint != null) ...[
                FingerprintVisualizer(
                  fingerprint: _deviceFingerprint!,
                  size: 120,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _deviceFingerprint!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy),
                        tooltip: '复制标识码',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _deviceFingerprint!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('设备标识已复制到剪贴板'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '此指纹用于应用授权，请勿与他人共享',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: Colors.red.shade400,
                  ),
                ),
              ] else
                const CircularProgressIndicator(),
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
} 