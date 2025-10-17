import 'package:flutter/material.dart';
import '../services/password_lock_service.dart';

class PasswordLockDialog extends StatefulWidget {
  final bool isEnabled;
  final VoidCallback? onPasswordSet;
  
  const PasswordLockDialog({
    super.key, 
    this.isEnabled = false,
    this.onPasswordSet,
  });

  @override
  State<PasswordLockDialog> createState() => _PasswordLockDialogState();
}

class _PasswordLockDialogState extends State<PasswordLockDialog> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  
  bool _showPassword = false;
  bool _isUpdating = false;
  int _selectedTimeout = 1440; // 默认1天（1440分钟）
  String _errorMessage = '';
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _loadTimeout();
  }
  
  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    _currentPasswordController.dispose();
    super.dispose();
  }
  
  // 加载超时时间设置
  Future<void> _loadTimeout() async {
    final timeout = await PasswordLockService.getLockTimeout();
    setState(() {
      _selectedTimeout = timeout;
      _isUpdating = widget.isEnabled;
    });
  }
  
  // 保存密码
  Future<void> _savePassword() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      // 如果是更新，需要验证当前密码
      if (_isUpdating) {
        final isValid = await PasswordLockService.verifyPassword(
          _currentPasswordController.text
        );
        
        if (!isValid) {
          setState(() {
            _errorMessage = '当前密码不正确';
            _isLoading = false;
          });
          return;
        }
      }
      
      // 检查密码是否为空
      if (_passwordController.text.isEmpty) {
        setState(() {
          _errorMessage = '密码不能为空';
          _isLoading = false;
        });
        return;
      }
      
      // 检查密码长度
      if (_passwordController.text.length < 4) {
        setState(() {
          _errorMessage = '密码长度必须至少为4位';
          _isLoading = false;
        });
        return;
      }
      
      // 检查两次输入是否一致
      if (_passwordController.text != _confirmController.text) {
        setState(() {
          _errorMessage = '两次输入的密码不一致';
          _isLoading = false;
        });
        return;
      }
      
      // 设置密码
      final isSuccess = await PasswordLockService.setPassword(_passwordController.text);
      if (!isSuccess) {
        setState(() {
          _errorMessage = '设置密码失败，请重试';
          _isLoading = false;
        });
        return;
      }
      
      // 启用密码锁
      await PasswordLockService.setPasswordLockEnabled(true);
      
      // 设置超时时间
      await PasswordLockService.setLockTimeout(_selectedTimeout);
      
      // 通知回调
      widget.onPasswordSet?.call();
      
      // 关闭对话框
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = '出现错误: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // 清除密码
  Future<void> _clearPassword() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      // 验证当前密码
      final isValid = await PasswordLockService.verifyPassword(
        _currentPasswordController.text
      );
      
      if (!isValid) {
        setState(() {
          _errorMessage = '当前密码不正确';
          _isLoading = false;
        });
        return;
      }
      
      // 清除密码
      await PasswordLockService.clearPassword();
      
      // 通知回调
      widget.onPasswordSet?.call();
      
      // 关闭对话框
      if (mounted) {
        Navigator.of(context).pop(false);
      }
    } catch (e) {
      setState(() {
        _errorMessage = '出现错误: $e';
      });
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
    return AlertDialog(
      title: Text(_isUpdating ? '更新密码锁' : '设置密码锁'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '密码锁可以保护您的应用数据安全，防止他人未经授权访问。',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            
            // 如果是更新，先输入当前密码
            if (_isUpdating) ...[
              TextField(
                controller: _currentPasswordController,
                decoration: InputDecoration(
                  labelText: '当前密码',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () {
                      setState(() {
                        _showPassword = !_showPassword;
                      });
                    },
                  ),
                  border: const OutlineInputBorder(),
                ),
                obscureText: !_showPassword,
              ),
              const SizedBox(height: 16),
            ],
            
            // 新密码
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: '新密码',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () {
                    setState(() {
                      _showPassword = !_showPassword;
                    });
                  },
                ),
                border: const OutlineInputBorder(),
              ),
              obscureText: !_showPassword,
            ),
            const SizedBox(height: 16),
            
            // 确认密码
            TextField(
              controller: _confirmController,
              decoration: const InputDecoration(
                labelText: '确认密码',
                prefixIcon: Icon(Icons.lock),
                border: OutlineInputBorder(),
              ),
              obscureText: !_showPassword,
            ),
            const SizedBox(height: 16),
            
            // 超时设置
            const Text(
              '锁定时间:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _buildTimeoutChip(1440, '1天'),
                _buildTimeoutChip(21600, '15天'),
                _buildTimeoutChip(43200, '30天'),
              ],
            ),
            
            // 错误信息
            if (_errorMessage.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (_isUpdating)
          TextButton(
            onPressed: _isLoading ? null : _clearPassword,
            child: const Text('禁用密码锁', style: TextStyle(color: Colors.red)),
          ),
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _savePassword,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isUpdating ? '更新' : '启用'),
        ),
      ],
    );
  }
  
  Widget _buildTimeoutChip(int minutes, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _selectedTimeout == minutes,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedTimeout = minutes;
          });
        }
      },
    );
  }
} 