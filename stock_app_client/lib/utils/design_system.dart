import 'package:flutter/material.dart';
import 'dart:ui';

/// 交易大陆设计系统
/// 专业金融科技风格 - 深邃、稳重、科技感
class AppDesignSystem {
  // 私有构造函数
  AppDesignSystem._();

  // ========== 品牌色彩系统 ==========
  
  /// 主色调 - 科技蓝（专业稳重）
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryLight = Color(0xFF60A5FA);
  static const Color primaryDark = Color(0xFF1D4ED8);
  
  /// 强调色 - 金色（财富象征）
  static const Color accent = Color(0xFFFFB800);
  static const Color accentLight = Color(0xFFFFD54F);
  static const Color accentDark = Color(0xFFFF8C00);
  
  /// 上涨色 - A股红色
  static const Color upColor = Color(0xFFEF4444);
  static const Color upColorLight = Color(0xFFFCA5A5);
  static const Color upColorDark = Color(0xFFDC2626);
  
  /// 下跌色 - A股绿色
  static const Color downColor = Color(0xFF10B981);
  static const Color downColorLight = Color(0xFF6EE7B7);
  static const Color downColorDark = Color(0xFF059669);
  
  /// 警告色
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFCD34D);
  
  /// 信息色
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFF93C5FD);

  // ========== 暗色模式色板 (AMOLED 真黑优化) ==========
  
  /// 暗色背景层级 - AMOLED 优化版
  /// 使用纯黑色作为最深背景，节省OLED屏幕电量，视觉更沉浸
  static const Color darkBg1 = Color(0xFF000000);  // 纯黑背景 (AMOLED优化)
  static const Color darkBg2 = Color(0xFF0A0A0A);  // 次级背景 (微妙提升)
  static const Color darkBg3 = Color(0xFF141414);  // 卡片背景 (层次分明)
  static const Color darkBg4 = Color(0xFF1F1F1F);  // 浮层背景 (悬浮元素)
  
  /// 暗色文字层级 - 高对比度优化
  static const Color darkText1 = Color(0xFFFFFFFF);  // 主要文字 (纯白，最高对比)
  static const Color darkText2 = Color(0xFFE5E5E5);  // 次要文字 (柔和白)
  static const Color darkText3 = Color(0xFFA3A3A3);  // 辅助文字 (中灰)
  static const Color darkText4 = Color(0xFF737373);  // 禁用文字 (深灰)
  
  /// 暗色边框 - 微妙层次
  static const Color darkBorder1 = Color(0xFF262626);  // 主边框 (微妙可见)
  static const Color darkBorder2 = Color(0xFF333333);  // 次边框 (稍明显)

  // ========== 亮色模式色板 ==========
  
  /// 亮色背景层级
  static const Color lightBg1 = Color(0xFFF8FAFC);  // 最浅背景
  static const Color lightBg2 = Color(0xFFFFFFFF);  // 卡片背景
  static const Color lightBg3 = Color(0xFFF1F5F9);  // 次级背景
  static const Color lightBg4 = Color(0xFFE2E8F0);  // 浮层背景
  
  /// 亮色文字层级
  static const Color lightText1 = Color(0xFF0F172A);  // 主要文字
  static const Color lightText2 = Color(0xFF334155);  // 次要文字
  static const Color lightText3 = Color(0xFF64748B);  // 辅助文字
  static const Color lightText4 = Color(0xFF94A3B8);  // 禁用文字
  
  /// 亮色边框
  static const Color lightBorder1 = Color(0xFFE2E8F0);
  static const Color lightBorder2 = Color(0xFFCBD5E1);

  // ========== 渐变色系统 ==========
  
  /// 品牌主渐变
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, Color(0xFF7C3AED)],
  );
  
  /// 金色渐变
  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, accentDark],
  );
  
  /// 科技感渐变
  static const LinearGradient techGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0EA5E9), Color(0xFF8B5CF6)],
  );
  
  /// 暗色背景渐变 - AMOLED优化
  static const LinearGradient darkBgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF000000), Color(0xFF050505)],
  );
  
  /// 暗色微光渐变 (用于卡片悬浮效果)
  static const LinearGradient darkGlowGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A1A1A), Color(0xFF0D0D0D)],
  );
  
  /// 上涨渐变
  static const LinearGradient upGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [upColor, upColorDark],
  );
  
  /// 下跌渐变
  static const LinearGradient downGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [downColor, downColorDark],
  );

  // ========== 间距系统 (8px基准) ==========
  
  static const double space2 = 2.0;
  static const double space4 = 4.0;
  static const double space6 = 6.0;
  static const double space8 = 8.0;
  static const double space10 = 10.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space40 = 40.0;
  static const double space48 = 48.0;
  static const double space64 = 64.0;

  // ========== 圆角系统 ==========
  
  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  static const double radiusXxl = 24.0;
  static const double radiusFull = 999.0;

  // ========== 阴影系统 ==========
  
  static List<BoxShadow> shadowSm(bool isDark) => [
    BoxShadow(
      color: (isDark ? Colors.black : Colors.black).withOpacity(isDark ? 0.3 : 0.05),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];
  
  static List<BoxShadow> shadowMd(bool isDark) => [
    BoxShadow(
      color: (isDark ? Colors.black : Colors.black).withOpacity(isDark ? 0.4 : 0.08),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> shadowLg(bool isDark) => [
    BoxShadow(
      color: (isDark ? Colors.black : Colors.black).withOpacity(isDark ? 0.5 : 0.1),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
  
  static List<BoxShadow> shadowGlow(Color color, {double intensity = 0.3}) => [
    BoxShadow(
      color: color.withOpacity(intensity),
      blurRadius: 20,
      spreadRadius: 0,
    ),
  ];

  // ========== 动画时长 ==========
  
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 250);
  static const Duration durationSlow = Duration(milliseconds: 400);
  static const Duration durationPage = Duration(milliseconds: 350);

  // ========== 动画曲线 ==========
  
  static const Curve curveDefault = Curves.easeOutCubic;
  static const Curve curveEmphasized = Curves.easeOutQuart;
  static const Curve curveSpring = Curves.elasticOut;
}

/// 毛玻璃容器装饰器
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double borderRadius;
  final Color? backgroundColor;
  final Border? border;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 10.0,
    this.borderRadius = 16.0,
    this.backgroundColor,
    this.border,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: backgroundColor ?? 
                (isDark 
                  ? Colors.white.withOpacity(0.05) 
                  : Colors.white.withOpacity(0.7)),
              borderRadius: BorderRadius.circular(borderRadius),
              border: border ?? Border.all(
                color: isDark 
                  ? Colors.white.withOpacity(0.1) 
                  : Colors.white.withOpacity(0.5),
                width: 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 渐变文字
class GradientText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Gradient gradient;

  const GradientText({
    super.key,
    required this.text,
    this.style,
    this.gradient = AppDesignSystem.goldGradient,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Text(text, style: style),
    );
  }
}

/// 科技感边框容器
class TechBorderContainer extends StatelessWidget {
  final Widget child;
  final Color? glowColor;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double glowIntensity;

  const TechBorderContainer({
    super.key,
    required this.child,
    this.glowColor,
    this.borderRadius = 16.0,
    this.padding,
    this.margin,
    this.glowIntensity = 0.3,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveGlowColor = glowColor ?? AppDesignSystem.primary;
    
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: effectiveGlowColor.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: effectiveGlowColor.withOpacity(glowIntensity),
            blurRadius: 12,
            spreadRadius: 0,
          ),
          if (isDark)
            BoxShadow(
              color: effectiveGlowColor.withOpacity(glowIntensity * 0.5),
              blurRadius: 24,
              spreadRadius: -4,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      AppDesignSystem.darkBg3.withOpacity(0.9),
                      AppDesignSystem.darkBg2.withOpacity(0.95),
                    ]
                  : [
                      Colors.white.withOpacity(0.95),
                      AppDesignSystem.lightBg1.withOpacity(0.98),
                    ],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 脉冲光点指示器
class PulsingDot extends StatefulWidget {
  final Color color;
  final double size;

  const PulsingDot({
    super.key,
    required this.color,
    this.size = 8.0,
  });

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(_animation.value * 0.6),
                blurRadius: widget.size * 2 * _animation.value,
                spreadRadius: 0,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 图标徽章容器
class IconBadge extends StatelessWidget {
  final IconData icon;
  final Gradient? gradient;
  final Color? backgroundColor;
  final double size;
  final double iconSize;
  final double borderRadius;

  const IconBadge({
    super.key,
    required this.icon,
    this.gradient,
    this.backgroundColor,
    this.size = 40.0,
    this.iconSize = 20.0,
    this.borderRadius = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? backgroundColor : null,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: gradient != null
            ? [
                BoxShadow(
                  color: (gradient as LinearGradient).colors.first.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: iconSize,
      ),
    );
  }
}

