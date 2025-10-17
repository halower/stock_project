import 'package:flutter/material.dart';
import 'dart:async';
import '../services/password_lock_service.dart';
import 'password_verify_dialog.dart';

class PasswordLockWrapper extends StatefulWidget {
  final Widget child;
  
  const PasswordLockWrapper({
    super.key,
    required this.child,
  });

  @override
  State<PasswordLockWrapper> createState() => _PasswordLockWrapperState();
}

class _PasswordLockWrapperState extends State<PasswordLockWrapper> with WidgetsBindingObserver {
  bool _isLocked = false;
  DateTime? _lastActiveTime;
  bool _isInitialized = false;
  Timer? _lockCheckTimer;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLockStatus();
    _startLockTimer();
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lockCheckTimer?.cancel();
    super.dispose();
  }
  
  // 应用生命周期变化监听
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.paused) {
      // 应用进入后台，记录时间
      _lastActiveTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      // 应用从后台恢复，检查是否需要锁定
      _checkLockTimeout();
    }
  }
  
  // 检查是否应该锁定应用
  Future<void> _checkLockTimeout() async {
    // 如果没有设置密码锁或者没有记录上次活跃时间，则不需要检查
    if (_lastActiveTime == null) return;
    
    final isEnabled = await PasswordLockService.isPasswordLockEnabled();
    if (!isEnabled) return;
    
    // 获取锁定超时时间
    final lockTimeoutMinutes = await PasswordLockService.getLockTimeout();
    final lockTimeoutDuration = Duration(minutes: lockTimeoutMinutes);
    
    // 计算应用在后台的时间
    final now = DateTime.now();
    final backgroundDuration = now.difference(_lastActiveTime!);
    
    // 如果超过锁定时间，则锁定应用
    if (backgroundDuration >= lockTimeoutDuration) {
      setState(() {
        _isLocked = true;
      });
      
      // 显示解锁对话框
      _showUnlockDialog();
    }
    
    // 清除记录的时间
    _lastActiveTime = null;
  }
  
  // 启动定时检查锁定状态
  void _startLockTimer() {
    _lockCheckTimer?.cancel();
    
    // 每分钟检查一次是否需要锁定（用于应用在前台时的超时锁定）
    _lockCheckTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkPeriodicLock();
    });
  }
  
  // 定期检查是否需要锁定
  Future<void> _checkPeriodicLock() async {
    final isEnabled = await PasswordLockService.isPasswordLockEnabled();
    if (!isEnabled) return;
    
    // 如果当前已锁定，不需要再次检查
    if (_isLocked) return;
    
    // 最后活跃时间是否超时
    final now = DateTime.now();
    final lastActive = _lastActiveTime ?? now;
    final timeoutMinutes = await PasswordLockService.getLockTimeout();
    final timeoutDuration = Duration(minutes: timeoutMinutes);
    
    if (now.difference(lastActive) >= timeoutDuration) {
      setState(() {
        _isLocked = true;
      });
      
      // 显示解锁对话框
      _showUnlockDialog();
    }
  }
  
  // 初始检查锁定状态
  Future<void> _checkLockStatus() async {
    final isEnabled = await PasswordLockService.isPasswordLockEnabled();
    
    if (isEnabled) {
      setState(() {
        _isLocked = true;
      });
      
      // 应用启动时显示解锁对话框
      _showUnlockDialog();
    }
    
    setState(() {
      _isInitialized = true;
    });
  }
  
  // 显示解锁对话框
  Future<void> _showUnlockDialog() async {
    if (!mounted) return;
    
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PasswordVerifyDialog(
        onSuccess: () {
          setState(() {
            _isLocked = false;
            _lastActiveTime = DateTime.now();
          });
        },
      ),
    );
  }
  
  // 手动解锁应用
  void _unlockApp() {
    setState(() {
      _isLocked = false;
      _lastActiveTime = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    // 如果没有完成初始化，显示加载指示器
    if (!_isInitialized) {
      return const Material(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    // 如果锁定，显示锁屏页面
    if (_isLocked) {
      return Material(
        child: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.lock,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                const Text(
                  '应用已锁定',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '请输入密码以解锁',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  icon: const Icon(Icons.lock_open),
                  label: const Text('解锁'),
                  onPressed: () => _showUnlockDialog(),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    // 更新最后活跃时间
    _lastActiveTime = DateTime.now();
    
    // 正常显示应用内容
    return GestureDetector(
      onTap: () {
        // 更新最后活跃时间
        _lastActiveTime = DateTime.now();
      },
      child: widget.child,
    );
  }
} 