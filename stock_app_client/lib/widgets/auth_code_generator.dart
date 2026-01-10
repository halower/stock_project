import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/device_info_service.dart';
import 'fingerprint_visualizer.dart';

class AuthCodeGenerator extends StatefulWidget {
  const AuthCodeGenerator({super.key});

  @override
  State<AuthCodeGenerator> createState() => _AuthCodeGeneratorState();
}

class _AuthCodeGeneratorState extends State<AuthCodeGenerator> {
  String? _generatedCode;
  bool _isGenerating = false;
  String? _deviceFingerprint;
  bool _isAdvancedMode = false;
  final _fingerprintController = TextEditingController();
  final _customDaysController = TextEditingController();
  bool _deviceVerified = false;
  int _deviceSecurityLevel = 0;
  
  // 授权期限选项：7天、1个月、6个月、1年、自定义
  final List<Map<String, dynamic>> _durationOptions = [
    {'label': '7天', 'days': 7, 'months': 0},
    {'label': '1个月', 'days': 0, 'months': 1},
    {'label': '6个月', 'days': 0, 'months': 6},
    {'label': '1年', 'days': 0, 'months': 12},
    {'label': '自定义天数', 'days': -1, 'months': 0}, // -1 表示自定义
  ];
  
  // 默认选择1个月
  String _selectedDurationLabel = '1个月';
  
  // 是否为自定义天数模式
  bool get _isCustomDays => _selectedDurationLabel == '自定义天数';
  
  // 根据标签获取选项
  Map<String, dynamic> _getDurationByLabel(String label) {
    return _durationOptions.firstWhere((option) => option['label'] == label);
  }
  
  @override
  void initState() {
    super.initState();
    _loadCurrentDeviceFingerprint();
  }
  
  @override
  void dispose() {
    _fingerprintController.dispose();
    _customDaysController.dispose();
    super.dispose();
  }
  
  // 加载当前设备的指纹，用于快速复制测试
  Future<void> _loadCurrentDeviceFingerprint() async {
    final fingerprint = await DeviceInfoService.getDeviceFingerprint();
    setState(() {
      _deviceFingerprint = fingerprint;
    });
  }

  void _generateCode() {
    // 验证是否输入了设备指纹（高级模式下）
    if (_isAdvancedMode) {
      if (_fingerprintController.text.isEmpty || _fingerprintController.text.length < 8) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('请输入有效的设备标识（至少8个字符）'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // 检查设备是否已验证
      if (!_deviceVerified) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('请先验证设备指纹的有效性'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      // 检查安全等级
      if (_deviceSecurityLevel < 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('设备安全等级过低（$_deviceSecurityLevel/5），无法生成绑定授权码'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }
    
    // 验证自定义天数（如果选择了自定义模式）
    if (_isCustomDays) {
      final customDaysText = _customDaysController.text.trim();
      if (customDaysText.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('请输入自定义天数'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      final customDays = int.tryParse(customDaysText);
      if (customDays == null || customDays <= 0 || customDays > 3650) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('请输入有效的天数（1-3650天）'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      final String code;
      // 获取选择的选项
      final selectedOption = _getDurationByLabel(_selectedDurationLabel);
      
      // 获取选择的天数和月数
      int days = selectedOption['days'] as int;
      final months = selectedOption['months'] as int;
      
      // 如果是自定义天数，使用输入的值
      if (_isCustomDays) {
        days = int.parse(_customDaysController.text.trim());
      }
      
      if (_isAdvancedMode) {
        // 使用输入的设备指纹生成绑定的授权码
        if (days > 0) {
          // 使用天数生成
          code = AuthService.generateAuthCodeWithDeviceIdAndDays(days, _fingerprintController.text);
        } else {
          // 使用月数生成
          code = AuthService.generateAuthCodeWithDeviceId(months, _fingerprintController.text);
        }
      } else {
        // 使用普通方式生成授权码，不绑定设备
        if (days > 0) {
          // 使用天数生成
          code = AuthService.generateAuthCodeWithDays(days);
        } else {
          // 使用月数生成
          code = AuthService.generateAuthCode(months);
        }
      }
      
      setState(() {
        _generatedCode = code;
        _isGenerating = false;
      });
    } catch (e) {
      setState(() {
        _isGenerating = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('生成授权码失败: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _copyToClipboard() {
    if (_generatedCode != null) {
      Clipboard.setData(ClipboardData(text: _generatedCode!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('授权码已复制到剪贴板'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
  
  void _copyDeviceFingerprint() {
    if (_deviceFingerprint != null) {
      Clipboard.setData(ClipboardData(text: _deviceFingerprint!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('当前设备标识已复制到剪贴板'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
  
  // 验证设备指纹
  Future<void> _verifyDeviceFingerprint() async {
    if (_fingerprintController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先输入设备指纹'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    setState(() {
      _isGenerating = true;
    });
    
    try {
      // 模拟验证过程（实际应用中可能需要网络请求）
      await Future.delayed(const Duration(seconds: 1));
      
      // 验证指纹格式和长度
      final fingerprint = _fingerprintController.text.trim();
      
      if (fingerprint.length < 16 || fingerprint.length > 32) {
        throw Exception('设备指纹长度不符合要求（16-32字符）');
      }
      
      // 检查指纹是否包含有效字符
      if (!RegExp(r'^[a-fA-F0-9]+$').hasMatch(fingerprint)) {
        throw Exception('设备指纹包含无效字符，只允许十六进制字符');
      }
      
      // 检查是否与当前设备指纹相同（防止管理员误用自己的指纹）
      if (_deviceFingerprint != null && fingerprint == _deviceFingerprint) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('警告：不应为管理员设备生成授权码'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.orange,
          ),
        );
      }
      
      // 计算安全等级（模拟）
      _deviceSecurityLevel = _calculateSecurityLevel(fingerprint);
      
      setState(() {
        _deviceVerified = true;
        _isGenerating = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('设备验证成功！安全等级：$_deviceSecurityLevel/5'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _deviceVerified = false;
        _isGenerating = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('设备验证失败: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // 计算设备指纹的安全等级
  int _calculateSecurityLevel(String fingerprint) {
    int level = 1;
    
    // 基于长度
    if (fingerprint.length >= 20) level++;
    
    // 基于字符多样性
    final hasUpperCase = fingerprint.contains(RegExp(r'[A-F]'));
    final hasLowerCase = fingerprint.contains(RegExp(r'[a-f]'));
    final hasNumbers = fingerprint.contains(RegExp(r'[0-9]'));
    
    if (hasUpperCase && hasLowerCase && hasNumbers) level++;
    
    // 基于随机性（简单检查）
    final charCounts = <String, int>{};
    for (final char in fingerprint.split('')) {
      charCounts[char] = (charCounts[char] ?? 0) + 1;
    }
    
    // 如果字符分布相对均匀，加分
    final avgCount = fingerprint.length / charCounts.length;
    final variance = charCounts.values.map((count) => (count - avgCount).abs()).reduce((a, b) => a + b) / charCounts.length;
    
    if (variance < 2.0) level++;
    
    return level > 5 ? 5 : level;
  }

  // 月份选择
  DropdownButtonFormField<String> _buildDurationSelector() {
    return DropdownButtonFormField<String>(
      value: _selectedDurationLabel,
      decoration: const InputDecoration(
        labelText: '授权期限',
        border: OutlineInputBorder(),
      ),
      items: _durationOptions
          .map((option) => DropdownMenuItem<String>(
                value: option['label'] as String,
                child: Text(option['label'] as String),
              ))
          .toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _selectedDurationLabel = value;
            _generatedCode = null; // 清除之前生成的授权码
          });
        }
      },
    );
  }
  
  // 自定义天数输入
  Widget _buildCustomDaysInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _customDaysController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(4), // 最多4位数字
          ],
          decoration: InputDecoration(
            labelText: '自定义天数',
            hintText: '请输入有效期天数',
            helperText: '支持1-3650天（约10年）',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.calendar_today),
            suffixText: '天',
            suffixStyle: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          onChanged: (value) {
            setState(() {
              _generatedCode = null; // 清除之前生成的授权码
            });
          },
        ),
        const SizedBox(height: 8),
        // 快捷选项按钮
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildQuickDayButton(3, '3天'),
            _buildQuickDayButton(15, '15天'),
            _buildQuickDayButton(30, '30天'),
            _buildQuickDayButton(45, '45天'),
            _buildQuickDayButton(60, '60天'),
            _buildQuickDayButton(90, '90天'),
            _buildQuickDayButton(180, '180天'),
            _buildQuickDayButton(365, '1年'),
          ],
        ),
      ],
    );
  }
  
  // 快捷天数按钮
  Widget _buildQuickDayButton(int days, String label) {
    final isSelected = _customDaysController.text == days.toString();
    return ActionChip(
      label: Text(label),
      backgroundColor: isSelected 
          ? Theme.of(context).primaryColor.withOpacity(0.2) 
          : null,
      side: isSelected 
          ? BorderSide(color: Theme.of(context).primaryColor) 
          : null,
      onPressed: () {
        setState(() {
          _customDaysController.text = days.toString();
          _generatedCode = null;
        });
      },
    );
  }
  
  // 生成结果文本
  String _getDurationText() {
    // 如果是自定义天数，使用输入的值
    if (_isCustomDays) {
      final customDays = _customDaysController.text.trim();
      return '$customDays 天';
    }
    
    final selectedOption = _getDurationByLabel(_selectedDurationLabel);
    final days = selectedOption['days'] as int;
    final months = selectedOption['months'] as int;
    
    if (days > 0) {
      return '$days 天';
    } else {
      return '$months 个月';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('生成授权码'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 高级模式开关
            SwitchListTile(
              title: const Text('一机一码模式'),
              subtitle: const Text('绑定特定设备，防止授权码共享'),
              value: _isAdvancedMode,
              onChanged: (value) {
                setState(() {
                  _isAdvancedMode = value;
                  _generatedCode = null; // 清除之前生成的授权码
                });
              },
              dense: true,
            ),
            
            // 使用说明
            if (_isAdvancedMode) 
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '使用说明',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. 让用户在登录界面点击"设备指纹"按钮\n'
                      '2. 用户复制并发送设备指纹给您\n'
                      '3. 将用户的设备指纹粘贴到下方输入框\n'
                      '4. 验证设备指纹后生成绑定授权码',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            
            const Divider(),
            
            const Text('请选择授权期限：'),
            const SizedBox(height: 16),
            
            // 月份选择
            _buildDurationSelector(),
            
            // 自定义天数输入
            if (_isCustomDays) ...[
              const SizedBox(height: 16),
              _buildCustomDaysInput(),
            ],
            
            // 高级模式：设备指纹输入
            if (_isAdvancedMode) ...[
              const SizedBox(height: 16),
              
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _fingerprintController,
                          decoration: InputDecoration(
                            labelText: '用户设备指纹',
                            hintText: '请粘贴用户提供的设备指纹（20位字符）',
                            helperText: '用户在登录界面点击"设备指纹"按钮获取',
                            border: const OutlineInputBorder(),
                            suffixIcon: _deviceVerified
                                ? const Icon(Icons.verified, color: Colors.green)
                                : const Icon(Icons.warning, color: Colors.orange),
                          ),
                          onChanged: (value) {
                            // 重置验证状态
                            setState(() {
                              _deviceVerified = false;
                              _deviceSecurityLevel = 0;
                            });
                            
                            // 让可视化组件随输入实时变化
                            if (value.length >= 8) {
                              setState(() {});
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isGenerating ? null : _verifyDeviceFingerprint,
                        child: _isGenerating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('验证'),
                      ),
                      const SizedBox(width: 8),
                      if (_deviceFingerprint != null)
                        Tooltip(
                          message: '复制管理员设备指纹（仅供测试，不要用于正式授权）',
                          child: IconButton(
                            icon: const Icon(Icons.copy_all, color: Colors.orange),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('警告：这是管理员设备指纹，不应用于用户授权！'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              _copyDeviceFingerprint();
                            },
                          ),
                        ),
                    ],
                  ),
                  
                  // 显示验证状态
                  if (_fingerprintController.text.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _deviceVerified ? Colors.green.shade50 : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _deviceVerified ? Colors.green : Colors.orange,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                _deviceVerified ? Icons.verified : Icons.warning,
                                color: _deviceVerified ? Colors.green : Colors.orange,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _deviceVerified ? '设备已验证' : '设备未验证',
                                style: TextStyle(
                                  color: _deviceVerified ? Colors.green : Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          if (_deviceVerified) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Text('安全等级：'),
                                ...List.generate(5, (index) => Icon(
                                  index < _deviceSecurityLevel ? Icons.star : Icons.star_border,
                                  size: 16,
                                  color: Colors.amber,
                                )),
                                Text(' ($_deviceSecurityLevel/5)'),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  
                  if (_fingerprintController.text.length >= 8) ...[
                    const SizedBox(height: 12),
                    FingerprintVisualizer(
                      fingerprint: _fingerprintController.text,
                      size: 60,
                      color: _deviceVerified ? Colors.green : Theme.of(context).primaryColor,
                    ),
                  ],
                ],
              ),
            ],
            
            const SizedBox(height: 24),
            
            // 生成结果
            if (_generatedCode != null) ...[
              const Text('授权码已生成：'),
              const SizedBox(height: 8),
              
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
                        _generatedCode!,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy),
                      tooltip: '复制授权码',
                      onPressed: _copyToClipboard,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              Text(
                _isAdvancedMode
                    ? '该授权码有效期为 ${_getDurationText()}，仅在指定设备上有效。'
                    : '该授权码有效期为 ${_getDurationText()}。',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
              
              if (_isAdvancedMode)
                const Text(
                  '警告：此码仅能在目标设备上激活，其他设备激活无效！',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
        ElevatedButton(
          onPressed: _isGenerating ? null : _generateCode,
          child: _isGenerating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('生成授权码'),
        ),
      ],
    );
  }
} 