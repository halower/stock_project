import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'dart:math' as math;
import '../utils/design_system.dart';

/// 庆祝类型枚举
enum CelebrationType {
  /// 小额盈利 (0-10%)
  smallProfit,
  /// 中等盈利 (10-30%)
  mediumProfit,
  /// 大额盈利 (30%+)
  bigProfit,
  /// 首次盈利
  firstProfit,
  /// 连续盈利
  streak,
  /// 里程碑达成 (累计盈利达到某个数值)
  milestone,
  /// 完美交易 (止盈止损完美执行)
  perfectTrade,
}

/// 盈利里程碑定义
class ProfitMilestone {
  final double amount;
  final String title;
  final String subtitle;
  final CelebrationType type;
  
  const ProfitMilestone({
    required this.amount,
    required this.title,
    required this.subtitle,
    this.type = CelebrationType.milestone,
  });
  
  /// 预设里程碑
  static const List<ProfitMilestone> presets = [
    ProfitMilestone(amount: 1000, title: '初入江湖', subtitle: '累计盈利突破 ¥1,000'),
    ProfitMilestone(amount: 5000, title: '小有所成', subtitle: '累计盈利突破 ¥5,000'),
    ProfitMilestone(amount: 10000, title: '万元俱乐部', subtitle: '累计盈利突破 ¥10,000'),
    ProfitMilestone(amount: 50000, title: '财富进阶', subtitle: '累计盈利突破 ¥50,000'),
    ProfitMilestone(amount: 100000, title: '十万大关', subtitle: '累计盈利突破 ¥100,000'),
    ProfitMilestone(amount: 500000, title: '半百达成', subtitle: '累计盈利突破 ¥500,000'),
    ProfitMilestone(amount: 1000000, title: '百万传奇', subtitle: '累计盈利突破 ¥1,000,000'),
  ];
  
  /// 获取下一个里程碑
  static ProfitMilestone? getNextMilestone(double currentTotal) {
    for (final milestone in presets) {
      if (currentTotal < milestone.amount) {
        return milestone;
      }
    }
    return null;
  }
  
  /// 检查是否达成里程碑
  static ProfitMilestone? checkMilestoneReached(double previousTotal, double newTotal) {
    for (final milestone in presets) {
      if (previousTotal < milestone.amount && newTotal >= milestone.amount) {
        return milestone;
      }
    }
    return null;
  }
}

/// 庆祝覆盖层组件
/// 用于在达成里程碑或盈利时显示撒花/烟花效果
class CelebrationOverlay extends StatefulWidget {
  final Widget child;
  
  const CelebrationOverlay({
    super.key,
    required this.child,
  });
  
  /// 全局Key用于触发庆祝
  static final GlobalKey<CelebrationOverlayState> globalKey = GlobalKey<CelebrationOverlayState>();
  
  /// 便捷方法：触发庆祝动画
  static void celebrate({
    CelebrationType type = CelebrationType.smallProfit,
    String? customTitle,
    String? customSubtitle,
    double? profitAmount,
    double? profitPercent,
  }) {
    globalKey.currentState?.showCelebration(
      type: type,
      customTitle: customTitle,
      customSubtitle: customSubtitle,
      profitAmount: profitAmount,
      profitPercent: profitPercent,
    );
  }

  @override
  State<CelebrationOverlay> createState() => CelebrationOverlayState();
}

class CelebrationOverlayState extends State<CelebrationOverlay>
    with TickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  bool _isShowing = false;
  CelebrationType _currentType = CelebrationType.smallProfit;
  String _title = '';
  String _subtitle = '';
  double? _profitAmount;
  double? _profitPercent;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  /// 显示庆祝动画
  void showCelebration({
    CelebrationType type = CelebrationType.smallProfit,
    String? customTitle,
    String? customSubtitle,
    double? profitAmount,
    double? profitPercent,
  }) {
    setState(() {
      _currentType = type;
      _profitAmount = profitAmount;
      _profitPercent = profitPercent;
      _title = customTitle ?? _getDefaultTitle(type);
      _subtitle = customSubtitle ?? _getDefaultSubtitle(type, profitAmount, profitPercent);
      _isShowing = true;
    });
    
    _fadeController.forward();
    _confettiController.play();
    
    // 自动隐藏
    Future.delayed(Duration(seconds: _getDuration(type)), () {
      _hideCelebration();
    });
  }
  
  void _hideCelebration() {
    _fadeController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _isShowing = false;
        });
      }
    });
  }
  
  String _getDefaultTitle(CelebrationType type) {
    switch (type) {
      case CelebrationType.smallProfit:
        return '小赚一笔 🎉';
      case CelebrationType.mediumProfit:
        return '收益可观 🎊';
      case CelebrationType.bigProfit:
        return '大赚特赚 🎆';
      case CelebrationType.firstProfit:
        return '首次盈利 🌟';
      case CelebrationType.streak:
        return '连续盈利 🔥';
      case CelebrationType.milestone:
        return '里程碑达成 🏆';
      case CelebrationType.perfectTrade:
        return '完美交易 ✨';
    }
  }
  
  String _getDefaultSubtitle(CelebrationType type, double? amount, double? percent) {
    if (amount != null && percent != null) {
      final sign = amount >= 0 ? '+' : '';
      return '$sign${amount.toStringAsFixed(2)} 元 ($sign${percent.toStringAsFixed(2)}%)';
    } else if (amount != null) {
      final sign = amount >= 0 ? '+' : '';
      return '$sign${amount.toStringAsFixed(2)} 元';
    } else if (percent != null) {
      final sign = percent >= 0 ? '+' : '';
      return '$sign${percent.toStringAsFixed(2)}%';
    }
    return '继续保持！';
  }
  
  int _getDuration(CelebrationType type) {
    switch (type) {
      case CelebrationType.bigProfit:
      case CelebrationType.milestone:
        return 5;
      case CelebrationType.mediumProfit:
      case CelebrationType.streak:
        return 4;
      default:
        return 3;
    }
  }
  
  /// 获取礼花颜色
  List<Color> _getConfettiColors(CelebrationType type) {
    switch (type) {
      case CelebrationType.bigProfit:
      case CelebrationType.milestone:
        // 金色主题 - 豪华感
        return [
          const Color(0xFFFFD700), // 金色
          const Color(0xFFFFA500), // 橙色
          const Color(0xFFFF6347), // 番茄红
          const Color(0xFFFF4500), // 橙红
          const Color(0xFFFFE4B5), // 杏仁白
          AppDesignSystem.upColor,
        ];
      case CelebrationType.mediumProfit:
        // 红色主题 - 喜庆
        return [
          AppDesignSystem.upColor,
          const Color(0xFFFF6B6B),
          const Color(0xFFFFD93D),
          const Color(0xFFFF8C00),
          Colors.white,
        ];
      case CelebrationType.firstProfit:
        // 彩虹主题 - 欢乐
        return [
          Colors.red,
          Colors.orange,
          Colors.yellow,
          Colors.green,
          Colors.blue,
          Colors.purple,
        ];
      default:
        // 默认红色主题
        return [
          AppDesignSystem.upColor,
          const Color(0xFFFF6B6B),
          const Color(0xFFFFB347),
          Colors.white,
        ];
    }
  }
  
  /// 获取粒子数量
  int _getParticleCount(CelebrationType type) {
    switch (type) {
      case CelebrationType.bigProfit:
      case CelebrationType.milestone:
        return 50;
      case CelebrationType.mediumProfit:
        return 30;
      default:
        return 20;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        
        if (_isShowing) ...[
          // 礼花效果 - 左侧
          Positioned(
            top: 0,
            left: 0,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: -math.pi / 4, // 向右下方向
              maxBlastForce: 60,
              minBlastForce: 30,
              emissionFrequency: 0.05,
              numberOfParticles: _getParticleCount(_currentType),
              gravity: 0.2,
              shouldLoop: false,
              colors: _getConfettiColors(_currentType),
              createParticlePath: (size) => _drawParticle(size),
            ),
          ),
          
          // 礼花效果 - 右侧
          Positioned(
            top: 0,
            right: 0,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: -3 * math.pi / 4, // 向左下方向
              maxBlastForce: 60,
              minBlastForce: 30,
              emissionFrequency: 0.05,
              numberOfParticles: _getParticleCount(_currentType),
              gravity: 0.2,
              shouldLoop: false,
              colors: _getConfettiColors(_currentType),
              createParticlePath: (size) => _drawParticle(size),
            ),
          ),
          
          // 中央礼花效果 (大额盈利/里程碑专属)
          if (_currentType == CelebrationType.bigProfit || 
              _currentType == CelebrationType.milestone)
            Positioned(
              top: MediaQuery.of(context).size.height * 0.3,
              left: MediaQuery.of(context).size.width / 2,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                maxBlastForce: 80,
                minBlastForce: 40,
                emissionFrequency: 0.03,
                numberOfParticles: 30,
                gravity: 0.15,
                shouldLoop: false,
                colors: _getConfettiColors(_currentType),
              ),
            ),
          
          // 庆祝消息卡片
          Positioned.fill(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: GestureDetector(
                onTap: _hideCelebration,
                child: Container(
                  color: Colors.black.withOpacity(0.3),
                  child: Center(
                    child: _buildCelebrationCard(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
  
  Widget _buildCelebrationCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.8, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.elasticOut,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 40),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF1A1A1A), const Color(0xFF0D0D0D)]
                : [Colors.white, const Color(0xFFFAFAFA)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _getAccentColor().withOpacity(0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: _getAccentColor().withOpacity(0.3),
              blurRadius: 30,
              spreadRadius: 5,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 图标
            _buildCelebrationIcon(),
            const SizedBox(height: 16),
            
            // 标题
            Text(
              _title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            
            // 金额/百分比
            if (_profitAmount != null || _profitPercent != null)
              _buildProfitDisplay(),
            
            const SizedBox(height: 8),
            
            // 副标题
            Text(
              _subtitle,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 20),
            
            // 关闭提示
            Text(
              '点击任意处关闭',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCelebrationIcon() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            _getAccentColor(),
            _getAccentColor().withOpacity(0.7),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: _getAccentColor().withOpacity(0.5),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(
        _getIconForType(),
        size: 40,
        color: Colors.white,
      ),
    );
  }
  
  IconData _getIconForType() {
    switch (_currentType) {
      case CelebrationType.smallProfit:
        return Icons.thumb_up;
      case CelebrationType.mediumProfit:
        return Icons.emoji_events;
      case CelebrationType.bigProfit:
        return Icons.rocket_launch;
      case CelebrationType.firstProfit:
        return Icons.star;
      case CelebrationType.streak:
        return Icons.local_fire_department;
      case CelebrationType.milestone:
        return Icons.military_tech;
      case CelebrationType.perfectTrade:
        return Icons.workspace_premium;
    }
  }
  
  Color _getAccentColor() {
    switch (_currentType) {
      case CelebrationType.bigProfit:
      case CelebrationType.milestone:
        return const Color(0xFFFFD700); // 金色
      case CelebrationType.streak:
        return const Color(0xFFFF6B35); // 火焰橙
      default:
        return AppDesignSystem.upColor;
    }
  }
  
  Widget _buildProfitDisplay() {
    final amount = _profitAmount;
    final percent = _profitPercent;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppDesignSystem.upColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppDesignSystem.upColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (amount != null) ...[
            Text(
              '+¥${amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppDesignSystem.upColor,
              ),
            ),
            if (percent != null) const SizedBox(width: 12),
          ],
          if (percent != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppDesignSystem.upColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '+${percent.toStringAsFixed(2)}%',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  /// 绘制自定义粒子形状
  Path _drawParticle(Size size) {
    final random = math.Random();
    final shapeType = random.nextInt(4);
    
    switch (shapeType) {
      case 0:
        // 圆形
        return Path()
          ..addOval(Rect.fromCircle(center: Offset.zero, radius: size.width / 2));
      case 1:
        // 矩形
        return Path()
          ..addRect(Rect.fromCenter(center: Offset.zero, width: size.width, height: size.height * 0.6));
      case 2:
        // 星形
        return _drawStar(size);
      default:
        // 菱形
        return Path()
          ..moveTo(0, -size.height / 2)
          ..lineTo(size.width / 2, 0)
          ..lineTo(0, size.height / 2)
          ..lineTo(-size.width / 2, 0)
          ..close();
    }
  }
  
  Path _drawStar(Size size) {
    final path = Path();
    final double centerX = 0;
    final double centerY = 0;
    final double radius = size.width / 2;
    final double innerRadius = radius * 0.4;
    
    for (int i = 0; i < 5; i++) {
      final double angle = (i * 4 * math.pi / 5) - math.pi / 2;
      final double x = centerX + radius * math.cos(angle);
      final double y = centerY + radius * math.sin(angle);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      
      final double innerAngle = angle + 2 * math.pi / 10;
      final double innerX = centerX + innerRadius * math.cos(innerAngle);
      final double innerY = centerY + innerRadius * math.sin(innerAngle);
      path.lineTo(innerX, innerY);
    }
    
    path.close();
    return path;
  }
}

/// 庆祝服务 - 管理庆祝触发逻辑
class CelebrationService {
  // 注：以下常量预留用于将来的持久化存储实现
  // static const String _lastMilestoneKey = 'last_milestone_amount';
  // static const String _consecutiveWinsKey = 'consecutive_wins';
  // static const String _firstProfitKey = 'first_profit_celebrated';
  
  /// 检查并触发盈利庆祝
  /// 
  /// [profitAmount] 本次盈利金额
  /// [profitPercent] 本次盈利百分比
  /// [totalProfit] 累计总盈利
  /// [isFirstTrade] 是否为首次交易
  static void checkAndCelebrate({
    required double profitAmount,
    double? profitPercent,
    double? totalProfit,
    bool isFirstTrade = false,
  }) {
    // 只有盈利才庆祝
    if (profitAmount <= 0) return;
    
    // 确定庆祝类型
    CelebrationType type;
    String? customTitle;
    String? customSubtitle;
    
    // 检查是否达成里程碑
    if (totalProfit != null) {
      // 这里可以接入 SharedPreferences 来检查里程碑
      // 简化处理，直接根据总盈利判断
      final milestone = ProfitMilestone.presets.firstWhere(
        (m) => totalProfit >= m.amount && totalProfit < m.amount * 1.1, // 刚刚达成
        orElse: () => ProfitMilestone(amount: 0, title: '', subtitle: ''),
      );
      
      if (milestone.amount > 0) {
        type = CelebrationType.milestone;
        customTitle = milestone.title;
        customSubtitle = milestone.subtitle;
      } else if ((profitPercent ?? 0) >= 30) {
        type = CelebrationType.bigProfit;
      } else if ((profitPercent ?? 0) >= 10) {
        type = CelebrationType.mediumProfit;
      } else {
        type = CelebrationType.smallProfit;
      }
    } else if ((profitPercent ?? 0) >= 30) {
      type = CelebrationType.bigProfit;
    } else if ((profitPercent ?? 0) >= 10) {
      type = CelebrationType.mediumProfit;
    } else {
      type = CelebrationType.smallProfit;
    }
    
    // 触发庆祝
    CelebrationOverlay.celebrate(
      type: type,
      customTitle: customTitle,
      customSubtitle: customSubtitle,
      profitAmount: profitAmount,
      profitPercent: profitPercent,
    );
  }
  
  /// 触发里程碑庆祝
  static void celebrateMilestone(ProfitMilestone milestone) {
    CelebrationOverlay.celebrate(
      type: CelebrationType.milestone,
      customTitle: milestone.title,
      customSubtitle: milestone.subtitle,
    );
  }
  
  /// 触发首次盈利庆祝
  static void celebrateFirstProfit({
    required double profitAmount,
    double? profitPercent,
  }) {
    CelebrationOverlay.celebrate(
      type: CelebrationType.firstProfit,
      customTitle: '恭喜首次盈利！🎉',
      customSubtitle: '这是一个美好的开始',
      profitAmount: profitAmount,
      profitPercent: profitPercent,
    );
  }
  
  /// 触发连续盈利庆祝
  static void celebrateStreak(int streakCount) {
    CelebrationOverlay.celebrate(
      type: CelebrationType.streak,
      customTitle: '连续 $streakCount 次盈利！🔥',
      customSubtitle: '保持这个势头',
    );
  }
}

