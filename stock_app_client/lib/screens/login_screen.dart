import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'home_screen.dart';
import '../services/auth_service.dart';
import '../services/ai_config_service.dart';
import '../widgets/auth_code_generator.dart';
import '../services/device_info_service.dart';
import '../widgets/fingerprint_visualizer.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _authCodeController = TextEditingController();
  
  bool _isLoading = false;
  bool _agreedToTerms = false;
  int _logoClickCount = 0;
  int _versionClickCount = 0;
  final int _clicksNeededToShowGenerator = 5;
  String? _deviceFingerprint;
  int _deviceSecurityLevel = 0;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  // 为金融特效添加的动画控制器
  late Animation<double> _pulseAnimation;
  late Animation<double> _glowAnimation;
  final List<CandleStick> _candleSticks = [];
  final List<StockLine> _stockLines = [];
  
  // 添加一个随机数生成器，用于K线动态变化
  final random = math.Random();
  
  // K线动态更新计数器
  int _updateCounter = 0;
  
  @override
  void initState() {
    super.initState();
    
    // 初始化动画控制器
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    
    _fadeAnimation = Tween<double>(begin: 1.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeInOut),
      ),
    );
    
    // 添加脉冲动画效果
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    // 添加光晕动画效果
    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    )..addListener(() {
      setState(() {});
    });
    
    // 设置动画为循环
    _animationController.repeat(reverse: true);
    
    // 生成随机K线和曲线数据
    _generateCandleSticks();
    _generateStockLines();
    
    // 添加动画监听器，定期更新K线数据
    _animationController.addListener(_updateCandleSticks);
    
    // 加载设备指纹
    _loadDeviceFingerprint();
    
    // 检查是否已有授权
    _checkExistingAuth();
  }
  
  // 更新K线数据 - 增强动态效果
  void _updateCandleSticks() {
    _updateCounter++;
    // 每10帧更新一次，让变化更明显
    if (_updateCounter % 10 == 0) {
      for (var stick in _candleSticks) {
        // 增大变化幅度，让K线动态更明显
        final variation = (random.nextDouble() - 0.5) * 8;
        stick.update(variation);
      }
    }
  }
  
  // 生成K线图数据
  void _generateCandleSticks() {
    double lastClose = 100 + random.nextDouble() * 50;
    
    for (int i = 0; i < 40; i++) {
      final open = lastClose;
      final close = open * (0.98 + random.nextDouble() * 0.04); // -2% 到 +2% 的变化
      final high = math.max(open, close) + random.nextDouble() * 2;
      final low = math.min(open, close) - random.nextDouble() * 2;
      
      _candleSticks.add(CandleStick(
        open: open,
        close: close,
        high: high,
        low: low,
        x: i * 10.0,
      ));
      
      lastClose = close;
    }
  }
  
  // 生成股票曲线数据
  void _generateStockLines() {
    for (int lineIndex = 0; lineIndex < 3; lineIndex++) {
      final points = <Offset>[];
      double y = 50 + random.nextDouble() * 50;
      
      for (int i = 0; i < 100; i++) {
        // 添加随机波动
        y += (random.nextDouble() * 4 - 2);
        // 确保y在合理范围内
        y = math.max(10, math.min(100, y));
        
        points.add(Offset(i * 5.0, y));
      }
      
      _stockLines.add(StockLine(
        points: points,
        color: [
          const Color(0xFFE53935), // 红色
          const Color(0xFF1976D2), // 深蓝色
          const Color(0xFF43A047), // 绿色
        ][lineIndex],
        strokeWidth: 1.8 - (lineIndex * 0.3),
      ));
    }
  }

  Future<void> _checkExistingAuth() async {
    setState(() => _isLoading = true);
    
    final isAuthorized = await AuthService.isAuthorized();
    
    if (isAuthorized && mounted) {
      // 根据现有授权设置用户身份
      final isAdmin = await AuthService.isAdmin();
      final username = isAdmin ? 'admin' : 'user';
      await AIConfigService.setCurrentUser(username);
      
      // 已有有效授权，直接进入主页
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      // 检查是否同意协议
      if (!_agreedToTerms) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: const Text('请先阅读并同意免责协议'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF1976D2),  // 蓝色
          ),
        );
        return;
      }
      
      // 隐藏键盘
      FocusScope.of(context).unfocus();
      
      setState(() {
        _isLoading = true;
      });
      
      // 验证授权码
      final authCode = _authCodeController.text.trim();
      final isValid = await AuthService.validateAndSaveAuthCode(authCode);
      
      if (isValid && mounted) {
        // 根据授权码类型设置用户身份
        final isAdmin = await AuthService.isAdmin();
        final username = isAdmin ? 'admin' : 'user';
        
        // 保存当前用户信息到AI配置服务
        await AIConfigService.setCurrentUser(username);
        
        // 登录成功后导航到主页
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else if (mounted) {
        // 显示错误提示
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('授权码无效或已过期'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
  
  void _showGeneratorDialog() {
    showDialog(
      context: context,
      builder: (context) => const AuthCodeGenerator(),
    );
  }
  
  // 显示免责协议
  void _showDisclaimerDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('免责协议'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '重要声明',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '1. 本软件仅供学习研究使用',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text(
                  '本应用程序（"交易大陆"）是一个专为教育和研究目的开发的量化交易分析平台。所有功能、数据分析、AI建议和交易策略仅用于学习和研究，不构成任何形式的投资建议。',
                ),
                const SizedBox(height: 12),
                const Text(
                  '2. 投资风险提示',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text(
                  '股票、期货、外汇等金融投资具有高风险性，可能导致本金损失。过往表现不代表未来结果。任何投资决策应基于您自己的研究和判断，或咨询专业的金融顾问。',
                ),
                const SizedBox(height: 12),
                const Text(
                  '3. 免责声明',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text(
                  '• 本软件开发者不对使用本软件产生的任何直接或间接损失承担责任\n'
                  '• 本软件提供的所有信息、数据、分析结果仅供参考，不保证准确性\n'
                  '• 用户应自行承担使用本软件的所有风险和责任\n'
                  '• 本软件不提供实盘交易功能，仅用于模拟和分析',
                ),
                const SizedBox(height: 12),
                const Text(
                  '4. 数据来源说明',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text(
                  '本软件使用的市场数据来源于公开渠道，我们努力确保数据的准确性，但不对数据的完整性、及时性或准确性做出保证。',
                ),
                const SizedBox(height: 12),
                const Text(
                  '5. 法律适用',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text(
                  '本协议受中华人民共和国法律管辖。如有争议，应通过友好协商解决。',
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '请注意：使用本软件即表示您已充分理解并接受上述风险和免责条款。如果您不同意这些条款，请不要使用本软件。',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('我已阅读'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _agreedToTerms = true;
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('感谢您同意免责协议'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: Color(0xFFE53935),  // 红色
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),  // 红色按钮
              foregroundColor: Colors.white,
            ),
            child: const Text('同意并继续'),
          ),
        ],
      ),
    );
  }
  
  void _handleLogoTap() {
    setState(() {
      _logoClickCount++;
    });
    
    if (_logoClickCount >= _clicksNeededToShowGenerator) {
      // 弹出授权码验证对话框
      _showSecretKeyDialog();
      _logoClickCount = 0;
    }
  }
  
  void _handleVersionTap() {
    setState(() {
      _versionClickCount++;
    });
    
    if (_versionClickCount >= _clicksNeededToShowGenerator) {
      // 弹出授权码验证对话框
      _showSecretKeyDialog();
      _versionClickCount = 0;
    }
  }
  
  void _showSecretKeyDialog() {
    final secretKeyController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('验证管理员权限'),
        content: TextField(
          controller: secretKeyController,
          decoration: const InputDecoration(
            labelText: '请输入管理员密钥',
            border: OutlineInputBorder(),
          ),
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final secretKey = secretKeyController.text.trim();
              Navigator.pop(context);
              
              // 验证密钥
              if (secretKey == 'Qwe@1324bnm') {
                _showGeneratorDialog();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('管理员密钥错误'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
  
  // 加载设备指纹
  Future<void> _loadDeviceFingerprint() async {
    final fingerprint = await DeviceInfoService.getDeviceFingerprint();
    final securityLevel = await DeviceInfoService.getSecurityLevel();
    
    if (mounted) {
      setState(() {
        _deviceFingerprint = fingerprint;
        _deviceSecurityLevel = securityLevel;
      });
    }
  }
  
  // 显示指纹详情对话框
  void _showFingerprintDetails() {
    if (_deviceFingerprint == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.security, color: Color(0xFFE53935)),  // 红色
            SizedBox(width: 10),
            Text('设备生物识别指纹'),
          ],
        ),
        backgroundColor: const Color(0xFF1C1C24),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FingerprintVisualizer(
                fingerprint: _deviceFingerprint!,
                size: 120,
                color: const Color(0xFFE53935),
              ),
              const SizedBox(height: 20),
              
              // 安全等级显示
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getSecurityLevelColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _getSecurityLevelColor().withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_getSecurityLevelIcon(), color: _getSecurityLevelColor()),
                        const SizedBox(width: 8),
                        Text(
                          '安全等级：${_getSecurityLevelText()}',
                          style: TextStyle(
                            color: _getSecurityLevelColor(),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) => Icon(
                        index < _deviceSecurityLevel ? Icons.star : Icons.star_border,
                        size: 18,
                        color: Colors.cyan.shade400,
                      )),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getSecurityLevelDescription(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E0E11),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade800),
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
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, color: Colors.white),
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
                '此指纹用于获取授权码，请复制并发送给管理员',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: Colors.red.shade400,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '生成此指纹时使用了先进的设备特征识别技术，确保一机一码',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
              if (_deviceSecurityLevel < 3) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade900.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue.shade400.withOpacity(0.3)),
                  ),
                  child: Text(
                    '注意：当前设备安全等级较低，建议联系技术支持提升安全性',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue.shade300,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭', style: TextStyle(color: Color(0xFFE53935))),
          ),
        ],
      ),
    );
  }
  
  // 获取安全等级颜色
  Color _getSecurityLevelColor() {
    switch (_deviceSecurityLevel) {
      case 1:
      case 2:
        return Colors.red;
      case 3:
        return Colors.cyan.shade400;  // 改为青色，更有科技感
      case 4:
        return Colors.blue.shade400;
      case 5:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
  
  // 获取安全等级图标
  IconData _getSecurityLevelIcon() {
    switch (_deviceSecurityLevel) {
      case 1:
      case 2:
        return Icons.security_outlined;
      case 3:
        return Icons.verified_user_outlined;
      case 4:
        return Icons.verified_user;
      case 5:
        return Icons.verified;
      default:
        return Icons.help_outline;
    }
  }
  
  // 获取安全等级文本
  String _getSecurityLevelText() {
    switch (_deviceSecurityLevel) {
      case 1:
        return '基础';
      case 2:
        return '较低';
      case 3:
        return '中等';
      case 4:
        return '较高';
      case 5:
        return '极高';
      default:
        return '未知';
    }
  }
  
  // 获取安全等级描述
  String _getSecurityLevelDescription() {
    switch (_deviceSecurityLevel) {
      case 1:
      case 2:
        return '设备特征较少，安全性有限';
      case 3:
        return '具备基本设备绑定能力';
      case 4:
        return '设备特征丰富，安全性良好';
      case 5:
        return '设备特征完整，安全性极佳';
      default:
        return '无法确定安全等级';
    }
  }
  
  @override
  void dispose() {
    _authCodeController.dispose();
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    // 设置状态栏为透明
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    
    return Scaffold(
      body: Stack(
        children: [
          // 背景图层
          _buildBackground(),
          
          // 内容层
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildLoginCard(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0A0E27), // 深邃深蓝
            Color(0xFF1A1F3A), // 深蓝紫
            Color(0xFF0F1419), // 深黑蓝
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // 添加K线图装饰 - 增强动态效果
          Positioned(
            top: 50,
            left: 0,
            right: 0,
            height: 300,
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Opacity(
                  opacity: 0.15 + (_glowAnimation.value * 0.1),
              child: CustomPaint(
                painter: CandleStickPainter(candleSticks: _candleSticks),
              ),
                );
              },
            ),
          ),
          
          // 添加曲线图装饰 - 增强动态效果
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            height: 200,
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Opacity(
                  opacity: 0.2 + (_glowAnimation.value * 0.15),
              child: CustomPaint(
                painter: StockLinePainter(stockLines: _stockLines),
              ),
                );
              },
            ),
          ),
          
          // 添加波动粒子效果
          Positioned.fill(
            child: Opacity(
              opacity: 0.08,
              child: CustomPaint(
                painter: ParticlePainter(pulseValue: _pulseAnimation.value),
              ),
            ),
          ),
          
          // 添加网格线图案
          Positioned.fill(
            child: CustomPaint(
              painter: GridPainter(),
            ),
          ),
          
          // 微妙的红色光晕（右上）- 专业简洁
          Positioned(
            top: -100,
            right: -100,
            child: AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, child) {
                return Container(
                  width: 350,
                  height: 350,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFE53935).withOpacity(0.08), // 微妙的红色
                        const Color(0xFFE53935).withOpacity(0.0),
                      ],
                      stops: const [0.0, 1.0],
                    ),
                  ),
                );
              },
            ),
          ),
          
          // 微妙的深色渐变（左下）- 增加层次感
          Positioned(
            bottom: -120,
            left: -120,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF000000).withOpacity(0.15), // 深色
                    const Color(0xFF000000).withOpacity(0.0),
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLoginCard() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 新的现代化Logo设计 - 喜庆红色金融风格
                GestureDetector(
                  onTap: _handleLogoTap,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFFF6B6B), // 浅红色
                          Color(0xFFE53935), // 中国红
                          Color(0xFFC62828), // 深红色
                        ],
                        stops: [0.0, 0.5, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE53935).withOpacity(0.6),
                          blurRadius: 25,
                          spreadRadius: 3,
                        ),
                        BoxShadow(
                          color: const Color(0xFFFF6B6B).withOpacity(0.4),
                          blurRadius: 35,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Transform.scale(
                        scale: _pulseAnimation.value * 0.85,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // 多层图标组合 - 更专业的金融感
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                // 背景圆形
                                Container(
                                  width: 55,
                                  height: 55,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(0.15),
                                  ),
                                ),
                                // 主图标 - 上涨趋势
                            const Icon(
                              Icons.trending_up,
                              color: Colors.white,
                                  size: 45,
                                ),
                                // 辅助图标 - K线
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.candlestick_chart,
                                      color: Color(0xFFE53935),
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // 脉冲光环
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 600),
                              width: 70 * _pulseAnimation.value,
                              height: 70 * _pulseAnimation.value,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.4),
                                  width: 3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '交易大陆',
                  style: GoogleFonts.notoSans(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '专业的量化交易分析平台',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 24),
                
                // 生物指纹显示区域
                if (_deviceFingerprint != null)
                  InkWell(
                    onTap: _showFingerprintDetails,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getSecurityLevelColor().withOpacity(0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          FingerprintVisualizer(
                            fingerprint: _deviceFingerprint!,
                            size: 40,
                            color: _getSecurityLevelColor(),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      '生物识别指纹',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      _getSecurityLevelIcon(),
                                      size: 16,
                                      color: _getSecurityLevelColor(),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      '安全等级：${_getSecurityLevelText()}',
                                      style: TextStyle(
                                        color: _getSecurityLevelColor(),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ...List.generate(3, (index) => Icon(
                                      index < _deviceSecurityLevel ? Icons.star : Icons.star_border,
                                      size: 12,
                                      color: Colors.cyan.shade400,
                                    )),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '点击查看详情并复制设备标识',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                const SizedBox(height: 24),
                
                // 登录表单
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // 授权码输入框
                      TextFormField(
                        controller: _authCodeController,
                        decoration: InputDecoration(
                          labelText: '授权码',
                          prefixIcon: Icon(
                            Icons.vpn_key_outlined,
                            color: Colors.white.withOpacity(0.7),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE53935), // 红色
                              width: 2.0,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          labelStyle: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                          ),
                          hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '请输入授权码';
                          }
                          return null;
                        },
                        cursorColor: const Color(0xFFE53935), // 红色
                      ),
                      const SizedBox(height: 20),
                      
                      // 免责协议同意复选框
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _agreedToTerms 
                                ? const Color(0xFFE53935).withOpacity(0.4)
                                : Colors.white.withOpacity(0.1),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Transform.scale(
                              scale: 1.2,
                              child: Checkbox(
                                value: _agreedToTerms,
                                onChanged: (value) {
                                  if (value == true) {
                                    _showDisclaimerDialog();
                                  } else {
                                    setState(() {
                                      _agreedToTerms = false;
                                    });
                                  }
                                },
                                activeColor: const Color(0xFFE53935),
                                checkColor: Colors.white,
                                side: BorderSide(
                                  color: Colors.white.withOpacity(0.7),
                                  width: 2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                onTap: _showDisclaimerDialog,
                                child: RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white.withOpacity(0.8),
                                    ),
                                    children: const [
                                      TextSpan(text: '我已阅读并同意'),
                                      TextSpan(
                                        text: '《免责协议》',
                                        style: TextStyle(
                                          color: Color(0xFFE53935),
                                          decoration: TextDecoration.underline,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // 登录按钮 - 使用渐变色
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: _isLoading 
                                  ? LinearGradient(
                                      colors: [
                                        const Color(0xFFE53935).withOpacity(0.5),
                                        const Color(0xFFD32F2F).withOpacity(0.5),
                                      ],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    )
                                  : const LinearGradient(
                                      colors: [
                                        Color(0xFFFF5252),  // 鲜艳的红色
                                        Color(0xFFE53935),  // 中国红
                                        Color(0xFFD32F2F),  // 深红色
                                      ],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      stops: [0.0, 0.5, 1.0],
                                    ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFE53935).withOpacity(0.5),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Container(
                              alignment: Alignment.center,
                              child: _isLoading
                                  ? SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.9)),
                                        strokeWidth: 2.0,
                                      ),
                                    )
                                  : const Text(
                                      '登 录',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // 版本信息（双击触发授权码生成）
                      GestureDetector(
                        onTap: _handleVersionTap,
                        child: Text(
                          '版本: 1.2.20+2',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// K线图数据模型
class CandleStick {
  double open;
  double high;
  double low;
  double close;
  final double x;
  
  CandleStick({
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.x,
  });
  
  // 添加更新方法，用于动态变化
  void update(double variation) {
    // 更新收盘价
    close += variation;
    
    // 确保最高价始终是最高的
    if (close > high) {
      high = close;
    }
    
    // 确保最低价始终是最低的
    if (close < low) {
      low = close;
    }
  }
}

// K线图绘制器
class CandleStickPainter extends CustomPainter {
  final List<CandleStick> candleSticks;
  
  CandleStickPainter({required this.candleSticks});
  
  @override
  void paint(Canvas canvas, Size size) {
    if (candleSticks.isEmpty) return;
    
    final double maxValue = candleSticks.map((c) => c.high).reduce(math.max);
    final double minValue = candleSticks.map((c) => c.low).reduce(math.min);
    final double range = maxValue - minValue;
    
    final redPaint = Paint()
      ..color = const Color(0xFFE53935).withOpacity(0.8) // 中国红 - 上涨
      ..strokeWidth = 2.0;
      
    final greenPaint = Paint()
      ..color = const Color(0xFF4CAF50).withOpacity(0.8) // 绿色 - 下跌
      ..strokeWidth = 2.0;
    
    for (final stick in candleSticks) {
      // 计算坐标
      final double x = stick.x;
      final double yOpen = size.height - ((stick.open - minValue) / range * size.height);
      final double yClose = size.height - ((stick.close - minValue) / range * size.height);
      final double yHigh = size.height - ((stick.high - minValue) / range * size.height);
      final double yLow = size.height - ((stick.low - minValue) / range * size.height);
      
      // 选择画笔颜色（中国习惯：红涨绿跌）
      final isRising = stick.close >= stick.open;
      final paint = isRising ? redPaint : greenPaint;
      
      // 绘制影线
      canvas.drawLine(
        Offset(x, yHigh),
        Offset(x, yLow),
        paint,
      );
      
      // 绘制实体
      final double rectTop = isRising ? yClose : yOpen;
      final double rectBottom = isRising ? yOpen : yClose;
      
      canvas.drawRect(
        Rect.fromPoints(
          Offset(x - 3, rectTop),
          Offset(x + 3, rectBottom),
        ),
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant CandleStickPainter oldDelegate) {
    return true; // 始终重绘以显示动态效果
  }
}

// 股票曲线数据模型
class StockLine {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  
  StockLine({
    required this.points,
    required this.color,
    this.strokeWidth = 2.0,
  });
}

// 股票曲线绘制器
class StockLinePainter extends CustomPainter {
  final List<StockLine> stockLines;
  
  StockLinePainter({required this.stockLines});
  
  @override
  void paint(Canvas canvas, Size size) {
    if (stockLines.isEmpty) return;
    
    for (final line in stockLines) {
      final paint = Paint()
        ..color = line.color
        ..strokeWidth = line.strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      
      final path = Path();
      
      if (line.points.isNotEmpty) {
        // 按比例缩放点到画布大小
        final scaledPoints = line.points.map((point) {
          return Offset(
            point.dx / 500 * size.width,
            point.dy / 100 * size.height,
          );
        }).toList();
        
        path.moveTo(scaledPoints.first.dx, scaledPoints.first.dy);
        
        for (int i = 1; i < scaledPoints.length; i++) {
          path.lineTo(scaledPoints[i].dx, scaledPoints[i].dy);
        }
        
        canvas.drawPath(path, paint);
      }
    }
  }
  
  @override
  bool shouldRepaint(covariant StockLinePainter oldDelegate) {
    return true; // 始终重绘以显示动态效果
  }
}

// 粒子绘制器
class ParticlePainter extends CustomPainter {
  final double pulseValue;
  final List<Offset> particles = [];
  
  ParticlePainter({required this.pulseValue}) {
    // 生成随机粒子
    final random = math.Random(42); // 固定种子以保持一致性
    for (int i = 0; i < 100; i++) {
      particles.add(Offset(
        random.nextDouble() * 1000,
        random.nextDouble() * 2000,
      ));
    }
  }
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.fill;
    
    for (final particle in particles) {
      // 根据脉冲值调整粒子大小
      final adjustedSize = 1.0 + (pulseValue - 1.0) * 2;
      
      // 计算粒子在屏幕上的位置
      final x = (particle.dx % size.width);
      final y = (particle.dy % size.height);
      
      canvas.drawCircle(
        Offset(x, y),
        adjustedSize,
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant ParticlePainter oldDelegate) {
    return oldDelegate.pulseValue != pulseValue;
  }
}

// 金融网格图背景绘制器
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 1;
    
    // 横线
    const double spacing = 30;
    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    
    // 纵线
    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false; // 静态绘制，不需要重绘
  }
} 