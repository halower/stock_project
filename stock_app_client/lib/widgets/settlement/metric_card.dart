import 'package:flutter/material.dart';

/// 指标卡片组件
/// 
/// 用于显示单个关键指标，如价格、数量、盈亏比等
/// 采用专业金融配色方案
class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const MetricCard({
    Key? key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        // 专业金融风格渐变背景
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [
                  color.withOpacity(0.15),
                  color.withOpacity(0.05),
                ]
              : [
                  color.withOpacity(0.08),
                  color.withOpacity(0.03),
                ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(isDarkMode ? 0.3 : 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 图标容器
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(isDarkMode ? 0.2 : 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(height: 8),
          
          // 标签
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          
          // 数值
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
              letterSpacing: 0.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// 专业金融配色方案
class FinancialColors {
  // 主色调 - 蓝色系（信任、专业）
  static const primary = Color(0xFF2563EB);
  static const primaryLight = Color(0xFF3B82F6);
  static const primaryDark = Color(0xFF1E40AF);

  // 价格相关 - 蓝色
  static const price = Color(0xFF0EA5E9);
  static const priceLight = Color(0xFF38BDF8);

  // 数量相关 - 紫色
  static const quantity = Color(0xFF8B5CF6);
  static const quantityLight = Color(0xFFA78BFA);

  // 盈利 - 绿色（A股风格）
  static const profit = Color(0xFF10B981);
  static const profitLight = Color(0xFF34D399);

  // 亏损 - 红色（A股风格）
  static const loss = Color(0xFFEF4444);
  static const lossLight = Color(0xFFF87171);

  // 警告 - 橙色
  static const warning = Color(0xFFF59E0B);
  static const warningLight = Color(0xFFFBBF24);

  // 信息 - 青色
  static const info = Color(0xFF06B6D4);
  static const infoLight = Color(0xFF22D3EE);

  // 中性色
  static const neutral = Color(0xFF64748B);
  static const neutralLight = Color(0xFF94A3B8);

  // 背景色（深色模式）
  static const darkBg = Color(0xFF1F2937);
  static const darkBgLight = Color(0xFF374151);

  // 背景色（浅色模式）
  static const lightBg = Color(0xFFF8FAFC);
  static const lightBgDark = Color(0xFFF1F5F9);
}

