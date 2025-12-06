import 'package:flutter/material.dart';
import 'dart:ui';
import '../utils/design_system.dart';

/// 现代卡片基础组件
/// 支持多种风格：标准、玻璃态、渐变边框、发光效果
class ModernCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final ModernCardStyle style;
  final Color? accentColor;
  final VoidCallback? onTap;
  final double borderRadius;
  final bool enableHover;

  const ModernCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.style = ModernCardStyle.standard,
    this.accentColor,
    this.onTap,
    this.borderRadius = AppDesignSystem.radiusMd,
    this.enableHover = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveAccent = accentColor ?? AppDesignSystem.primary;
    
    Widget cardContent = Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(AppDesignSystem.space16),
      decoration: _buildDecoration(isDark, effectiveAccent),
      child: child,
    );
    
    // 玻璃态风格需要额外的模糊效果
    if (style == ModernCardStyle.glass) {
      cardContent = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: cardContent,
        ),
      );
    }
    
    // 如果有点击事件，添加水波纹效果
    if (onTap != null) {
      cardContent = Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          splashColor: effectiveAccent.withOpacity(0.1),
          highlightColor: effectiveAccent.withOpacity(0.05),
          child: cardContent,
        ),
      );
    }
    
    return Container(
      margin: margin,
      child: cardContent,
    );
  }
  
  BoxDecoration _buildDecoration(bool isDark, Color accent) {
    switch (style) {
      case ModernCardStyle.standard:
        return BoxDecoration(
          color: isDark ? AppDesignSystem.darkBg3 : Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: isDark 
                ? AppDesignSystem.darkBorder1.withOpacity(0.5)
                : AppDesignSystem.lightBorder1,
            width: 1,
          ),
          boxShadow: AppDesignSystem.shadowMd(isDark),
        );
        
      case ModernCardStyle.glass:
        return BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    Colors.white.withOpacity(0.05),
                    Colors.white.withOpacity(0.02),
                  ]
                : [
                    Colors.white.withOpacity(0.85),
                    Colors.white.withOpacity(0.7),
                  ],
          ),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: isDark 
                ? Colors.white.withOpacity(0.1)
                : Colors.white.withOpacity(0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        );
        
      case ModernCardStyle.gradient:
        return BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    AppDesignSystem.darkBg3,
                    AppDesignSystem.darkBg2,
                  ]
                : [
                    Colors.white,
                    AppDesignSystem.lightBg1,
                  ],
          ),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: accent.withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(0.1),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
            ...AppDesignSystem.shadowMd(isDark),
          ],
        );
        
      case ModernCardStyle.glow:
        return BoxDecoration(
          color: isDark ? AppDesignSystem.darkBg3 : Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: accent.withOpacity(0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 0,
            ),
            BoxShadow(
              color: accent.withOpacity(0.15),
              blurRadius: 40,
              spreadRadius: -5,
            ),
            ...AppDesignSystem.shadowMd(isDark),
          ],
        );
        
      case ModernCardStyle.elevated:
        return BoxDecoration(
          color: isDark ? AppDesignSystem.darkBg3 : Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: AppDesignSystem.shadowLg(isDark),
        );
    }
  }
}

/// 卡片风格枚举
enum ModernCardStyle {
  standard,  // 标准卡片
  glass,     // 毛玻璃效果
  gradient,  // 渐变背景
  glow,      // 发光边框
  elevated,  // 高阴影
}

/// 带标题的卡片组件
class TitledCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Gradient? iconGradient;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry? contentPadding;
  final EdgeInsetsGeometry? margin;
  final ModernCardStyle style;
  final VoidCallback? onTap;

  const TitledCard({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconGradient,
    required this.child,
    this.trailing,
    this.contentPadding,
    this.margin,
    this.style = ModernCardStyle.standard,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ModernCard(
      style: style,
      margin: margin,
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题区域
          Padding(
            padding: const EdgeInsets.all(AppDesignSystem.space16),
            child: Row(
              children: [
                if (icon != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: iconGradient ?? AppDesignSystem.primaryGradient,
                      borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm),
                      boxShadow: [
                        BoxShadow(
                          color: (iconGradient?.colors.first ?? AppDesignSystem.primary)
                              .withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      icon,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppDesignSystem.space12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppDesignSystem.darkText1 : AppDesignSystem.lightText1,
                          letterSpacing: 0.3,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppDesignSystem.darkText3 : AppDesignSystem.lightText3,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          // 分隔线
          Container(
            height: 1,
            color: isDark 
                ? AppDesignSystem.darkBorder1.withOpacity(0.3)
                : AppDesignSystem.lightBorder1.withOpacity(0.5),
          ),
          // 内容区域
          Padding(
            padding: contentPadding ?? const EdgeInsets.all(AppDesignSystem.space16),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// 数据卡片 - 用于显示统计数据
class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Gradient gradient;
  final String? trend;
  final bool isPositive;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.gradient,
    this.trend,
    this.isPositive = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDesignSystem.space20),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusLg),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              if (trend != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPositive ? Icons.trending_up : Icons.trending_down,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        trend!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppDesignSystem.space16),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppDesignSystem.space6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppDesignSystem.space4),
            Text(
              subtitle!,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 交互卡片 - 带有点击效果
class InteractiveCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? accentColor;

  const InteractiveCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.accentColor,
  });

  @override
  State<InteractiveCard> createState() => _InteractiveCardState();
}

class _InteractiveCardState extends State<InteractiveCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = widget.accentColor ?? AppDesignSystem.primary;
    
    return Container(
      margin: widget.margin,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: widget.onTap,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: widget.padding ?? const EdgeInsets.all(AppDesignSystem.space16),
            decoration: BoxDecoration(
              color: isDark ? AppDesignSystem.darkBg3 : Colors.white,
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
              border: Border.all(
                color: _isPressed 
                    ? accent.withOpacity(0.5)
                    : (isDark 
                        ? AppDesignSystem.darkBorder1.withOpacity(0.5)
                        : AppDesignSystem.lightBorder1),
                width: _isPressed ? 2 : 1,
              ),
              boxShadow: _isPressed
                  ? [
                      BoxShadow(
                        color: accent.withOpacity(0.2),
                        blurRadius: 16,
                        spreadRadius: 0,
                      ),
                    ]
                  : AppDesignSystem.shadowMd(isDark),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// 空状态卡片
class EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final Widget? action;

  const EmptyStateCard({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDesignSystem.space40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppDesignSystem.primary.withOpacity(0.1),
                    AppDesignSystem.primary.withOpacity(0.05),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: AppDesignSystem.primary.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: AppDesignSystem.space24),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark ? AppDesignSystem.darkText1 : AppDesignSystem.lightText1,
              ),
              textAlign: TextAlign.center,
            ),
            if (description != null) ...[
              const SizedBox(height: AppDesignSystem.space8),
              Text(
                description!,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppDesignSystem.darkText3 : AppDesignSystem.lightText3,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppDesignSystem.space24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

