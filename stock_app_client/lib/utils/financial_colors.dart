import 'package:flutter/material.dart';

/// 金融专业配色方案
class FinancialColors {
  // 主色调 - 金融科技风格
  static const primary = Color(0xFFFFB800); // 金色
  static const secondary = Color(0xFF4A90E2); // 科技蓝
  static const accent = Color(0xFF7B68EE); // 紫色
  
  // A股涨跌色（红涨绿跌）
  static const profit = Color(0xFFDC2626); // 红色 - 盈利/上涨
  static const loss = Color(0xFF059669); // 绿色 - 亏损/下跌
  
  // 渐变色组
  static const profitGradient = [Color(0xFFDC2626), Color(0xFFB91C1C)];
  static const lossGradient = [Color(0xFF059669), Color(0xFF047857)];
  static const goldGradient = [Color(0xFFFFB800), Color(0xFFFF8C00)];
  static const blueGradient = [Color(0xFF4A90E2), Color(0xFF2563EB)];
  static const purpleGradient = [Color(0xFF7B68EE), Color(0xFF6A5ACD)];
  static const indigoGradient = [Color(0xFF6366F1), Color(0xFF4F46E5)];
  
  // 图表颜色
  static const chartRed = Color(0xFFFF3B30); // 鲜红色
  static const chartGreen = Color(0xFF34C759); // 鲜绿色
  static const chartBlue = Color(0xFF007AFF); // 蓝色
  static const chartOrange = Color(0xFFFF9500); // 橙色
  static const chartPurple = Color(0xFFAF52DE); // 紫色
  static const chartGray = Color(0xFF8E8E93); // 灰色
  
  // 背景色
  static Color darkCardBg(double opacity) => Color(0xFF1E293B).withOpacity(opacity);
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
          ? [const Color(0xFF1E293B), const Color(0xFF334155)]
          : [Colors.white, const Color(0xFFF8FAFC)],
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
}

