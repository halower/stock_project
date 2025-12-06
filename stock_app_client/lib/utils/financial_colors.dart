import 'package:flutter/material.dart';
import 'design_system.dart';

/// 金融专业配色方案
/// 与AppDesignSystem保持一致的金融专业配色
class FinancialColors {
  // 主色调 - 金融科技风格
  static const primary = AppDesignSystem.accent; // 金色
  static const secondary = AppDesignSystem.primary; // 科技蓝
  static const accent = Color(0xFF7B68EE); // 紫色
  
  // A股涨跌色（红涨绿跌）
  static const profit = AppDesignSystem.upColor; // 红色 - 盈利/上涨
  static const loss = AppDesignSystem.downColor; // 绿色 - 亏损/下跌
  
  // 渐变色组
  static const profitGradient = [Color(0xFFDC2626), Color(0xFFB91C1C)];
  static const lossGradient = [Color(0xFF059669), Color(0xFF047857)];
  static const goldGradient = [Color(0xFFFFB800), Color(0xFFFF8C00)];
  static const blueGradient = [Color(0xFF4A90E2), Color(0xFF2563EB)];
  static const purpleGradient = [Color(0xFF8B5CF6), Color(0xFF7C3AED)];
  static const indigoGradient = [Color(0xFF6366F1), Color(0xFF4F46E5)];
  static const techGradient = [Color(0xFF0EA5E9), Color(0xFF8B5CF6)];
  
  // 图表颜色
  static const chartRed = AppDesignSystem.upColor;
  static const chartGreen = AppDesignSystem.downColor;
  static const chartBlue = AppDesignSystem.primary;
  static const chartOrange = AppDesignSystem.warning;
  static const chartPurple = Color(0xFF8B5CF6);
  static const chartGray = Color(0xFF6B7280);
  static const chartCyan = Color(0xFF06B6D4);
  static const chartPink = Color(0xFFEC4899);
  
  // 背景色
  static Color darkCardBg(double opacity) => AppDesignSystem.darkBg3.withOpacity(opacity);
  static Color lightCardBg(double opacity) => Colors.white.withOpacity(opacity);
  
  // 阴影色
  static BoxShadow cardShadow({
    required bool isDark,
    Color? color,
    double blur = 20,
    double spread = 0,
    Offset offset = const Offset(0, 8),
  }) {
    return BoxShadow(
      color: (color ?? (isDark ? Colors.black : Colors.grey)).withOpacity(isDark ? 0.3 : 0.1),
      blurRadius: blur,
      spreadRadius: spread,
      offset: offset,
    );
  }
  
  // 获取渐变背景
  static LinearGradient cardGradient(bool isDark) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [AppDesignSystem.darkBg3, AppDesignSystem.darkBg2]
          : [Colors.white, AppDesignSystem.lightBg1],
    );
  }
  
  // 获取数据卡片渐变
  static LinearGradient dataCardGradient(List<Color> colors) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: colors,
    );
  }
  
  // 发光阴影效果
  static List<BoxShadow> glowShadow(Color color, {double intensity = 0.3}) {
    return [
      BoxShadow(
        color: color.withOpacity(intensity),
        blurRadius: 20,
        spreadRadius: 0,
      ),
      BoxShadow(
        color: color.withOpacity(intensity * 0.5),
        blurRadius: 40,
        spreadRadius: -5,
      ),
    ];
  }
}

