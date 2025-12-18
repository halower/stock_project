import 'package:flutter/material.dart';
import '../../models/trade_record.dart';

/// 交易复盘分析卡片
/// 
/// 显示完整的交易分析，包括：
/// - 预期盈亏分析
/// - 实际盈亏对比
/// - 执行质量评估
/// - 备注和总结
class TradeAnalysisCard extends StatelessWidget {
  final TradeRecord tradePlan;

  const TradeAnalysisCard({
    Key? key,
    required this.tradePlan,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [
                  const Color(0xFF2C2C2E),
                  const Color(0xFF1C1C1E),
                ]
              : [
                  Colors.white,
                  const Color(0xFFFAFAFA),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.grey.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            _buildSectionTitle('📊 交易复盘分析', isDarkMode),
            const SizedBox(height: 20),
            
            // 预期盈亏分析
            _buildExpectedProfitLoss(isDarkMode),
            const SizedBox(height: 20),
            
            // 实际盈亏（如果已结算）
            if (tradePlan.actualPrice != null && tradePlan.actualQuantity != null) ...[
              _buildActualProfitLoss(isDarkMode),
              const SizedBox(height: 20),
              
              // 执行质量评估
              _buildExecutionQuality(isDarkMode),
              const SizedBox(height: 20),
            ],
            
            // 开仓理由
            if (tradePlan.reason != null && tradePlan.reason!.isNotEmpty) ...[
              _buildReasonSection(isDarkMode),
              const SizedBox(height: 20),
            ],
            
            // 策略失效条件
            if (tradePlan.invalidationCondition != null && 
                tradePlan.invalidationCondition!.isNotEmpty) ...[
              _buildInvalidationSection(isDarkMode),
              const SizedBox(height: 20),
            ],
            
            // 交易备注
            if (tradePlan.notes != null && tradePlan.notes!.isNotEmpty) ...[
              _buildNotesSection(isDarkMode),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建章节标题
  Widget _buildSectionTitle(String title, bool isDarkMode) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3B82F6).withOpacity(0.3),
                blurRadius: 8,
                spreadRadius: 0,
              ),
            ],
          ),
          child: const Icon(
            Icons.analytics_outlined,
            color: Colors.white,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  /// 构建预期盈亏分析
  Widget _buildExpectedProfitLoss(bool isDarkMode) {
    final planPrice = tradePlan.planPrice ?? 0.0;
    final planQuantity = tradePlan.planQuantity ?? 0;
    final stopLossPrice = tradePlan.stopLossPrice ?? 0.0;
    final takeProfitPrice = tradePlan.takeProfitPrice ?? 0.0;
    
    if (planPrice == 0 || planQuantity == 0) {
      return const SizedBox.shrink();
    }
    
    // 计算预期盈亏
    final expectedProfit = (takeProfitPrice - planPrice) * planQuantity;
    final expectedLoss = (planPrice - stopLossPrice) * planQuantity;
    final profitLossRatio = expectedLoss > 0 ? expectedProfit / expectedLoss : 0.0;
    
    // 计算盈亏百分比
    final profitPercent = planPrice > 0 ? (expectedProfit / (planPrice * planQuantity)) * 100 : 0.0;
    final lossPercent = planPrice > 0 ? (expectedLoss / (planPrice * planQuantity)) * 100 : 0.0;
    
    final redColor = isDarkMode ? const Color(0xFFEF4444) : const Color(0xFFDC2626);
    final greenColor = isDarkMode ? const Color(0xFF10B981) : const Color(0xFF059669);
    final blueColor = isDarkMode ? Colors.blue[300]! : Colors.blue[700]!;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withOpacity(0.05)
            : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withOpacity(0.1)
              : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.trending_up,
                size: 18,
                color: blueColor,
              ),
              const SizedBox(width: 8),
              Text(
                '预期盈亏分析',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.blue[300] : Colors.blue[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 预期盈利
          _buildAnalysisRow(
            '预期盈利',
            '+¥${expectedProfit.toStringAsFixed(2)}',
            '+${profitPercent.toStringAsFixed(2)}%',
            redColor,
            isDarkMode,
            icon: Icons.arrow_upward,
          ),
          const SizedBox(height: 12),
          
          // 预期亏损
          _buildAnalysisRow(
            '预期亏损',
            '-¥${expectedLoss.toStringAsFixed(2)}',
            '-${lossPercent.toStringAsFixed(2)}%',
            greenColor,
            isDarkMode,
            icon: Icons.arrow_downward,
          ),
          const SizedBox(height: 12),
          
          // 盈亏比
          _buildAnalysisRow(
            '盈亏比',
            '${profitLossRatio.toStringAsFixed(2)} : 1',
            _getRiskRatioComment(profitLossRatio),
            _getRiskRatioColor(profitLossRatio, isDarkMode),
            isDarkMode,
            icon: Icons.balance,
          ),
        ],
      ),
    );
  }

  /// 构建实际盈亏
  Widget _buildActualProfitLoss(bool isDarkMode) {
    final netProfit = tradePlan.netProfit;
    final profitRate = tradePlan.profitRate;
    
    if (netProfit == null) {
      return const SizedBox.shrink();
    }
    
    final isProfit = netProfit >= 0;
    final redColor = isDarkMode ? const Color(0xFFEF4444) : const Color(0xFFDC2626);
    final greenColor = isDarkMode ? const Color(0xFF10B981) : const Color(0xFF059669);
    final color = isProfit ? redColor : greenColor;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isProfit
              ? [
                  redColor.withOpacity(0.15),
                  redColor.withOpacity(0.05),
                ]
              : [
                  greenColor.withOpacity(0.15),
                  greenColor.withOpacity(0.05),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isProfit ? Icons.celebration : Icons.warning_amber,
                size: 20,
                color: color,
              ),
              const SizedBox(width: 8),
              Text(
                '实际交易结果',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '净盈亏',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isProfit
                          ? '+¥${netProfit.toStringAsFixed(2)}'
                          : '-¥${netProfit.abs().toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              if (profitRate != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isProfit
                        ? '+${profitRate.toStringAsFixed(2)}%'
                        : '-${profitRate.abs().toStringAsFixed(2)}%',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建执行质量评估
  Widget _buildExecutionQuality(bool isDarkMode) {
    final planPrice = tradePlan.planPrice ?? 0.0;
    final actualPrice = tradePlan.actualPrice ?? 0.0;
    final stopLossPrice = tradePlan.stopLossPrice ?? 0.0;
    final takeProfitPrice = tradePlan.takeProfitPrice ?? 0.0;
    
    if (planPrice == 0 || actualPrice == 0) {
      return const SizedBox.shrink();
    }
    
    // 计算价格偏差
    final priceDeviation = actualPrice - planPrice;
    final deviationPercent = (priceDeviation / planPrice) * 100;
    
    // 计算预期盈亏
    final expectedProfit = (takeProfitPrice - planPrice) * (tradePlan.planQuantity ?? 0);
    final expectedLoss = (planPrice - stopLossPrice) * (tradePlan.planQuantity ?? 0);
    
    // 计算实际盈亏与预期的对比
    final actualProfit = tradePlan.netProfit ?? 0.0;
    final expectedTarget = actualProfit >= 0 ? expectedProfit : -expectedLoss;
    final executionDeviation = expectedTarget != 0 
        ? ((actualProfit - expectedTarget) / expectedTarget.abs() * 100)
        : 0.0;
    
    // 执行质量评级
    final quality = _getExecutionQuality(deviationPercent.abs(), executionDeviation);
    
    final blueColor = isDarkMode ? Colors.blue[300]! : Colors.blue[700]!;
    final redColor = isDarkMode ? const Color(0xFFEF4444) : const Color(0xFFDC2626);
    final greenColor = isDarkMode ? const Color(0xFF10B981) : const Color(0xFF059669);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withOpacity(0.05)
            : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withOpacity(0.1)
              : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.assessment_outlined,
                size: 18,
                color: blueColor,
              ),
              const SizedBox(width: 8),
              Text(
                '执行质量评估',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: blueColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 价格偏差
          _buildAnalysisRow(
            '成交价偏差',
            '${priceDeviation >= 0 ? '+' : ''}${priceDeviation.toStringAsFixed(2)}',
            '${deviationPercent >= 0 ? '+' : ''}${deviationPercent.toStringAsFixed(2)}%',
            deviationPercent.abs() <= 2 ? blueColor : (deviationPercent > 0 ? greenColor : redColor),
            isDarkMode,
            icon: Icons.compare_arrows,
          ),
          const SizedBox(height: 12),
          
          // 执行偏差
          _buildAnalysisRow(
            '执行偏差',
            '${executionDeviation >= 0 ? '+' : ''}${executionDeviation.toStringAsFixed(1)}%',
            quality.comment,
            quality.color(isDarkMode),
            isDarkMode,
            icon: Icons.speed,
          ),
          const SizedBox(height: 16),
          
          // 综合评级
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  quality.color(isDarkMode).withOpacity(0.2),
                  quality.color(isDarkMode).withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: quality.color(isDarkMode).withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: quality.color(isDarkMode).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    quality.icon,
                    color: quality.color(isDarkMode),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '执行评级',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        quality.grade,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: quality.color(isDarkMode),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: quality.color(isDarkMode).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: quality.color(isDarkMode).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    quality.comment,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: quality.color(isDarkMode),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建开仓理由
  Widget _buildReasonSection(bool isDarkMode) {
    return _buildTextSection(
      '开仓理由',
      tradePlan.reason!,
      Icons.lightbulb_outline,
      isDarkMode ? Colors.amber[300]! : Colors.amber[700]!,
      isDarkMode,
    );
  }

  /// 构建策略失效条件
  Widget _buildInvalidationSection(bool isDarkMode) {
    return _buildTextSection(
      '策略失效条件',
      tradePlan.invalidationCondition!,
      Icons.warning_amber_outlined,
      isDarkMode ? Colors.orange[300]! : Colors.orange[700]!,
      isDarkMode,
    );
  }

  /// 构建备注
  Widget _buildNotesSection(bool isDarkMode) {
    return _buildTextSection(
      '交易备注',
      tradePlan.notes!,
      Icons.note_outlined,
      isDarkMode ? Colors.purple[300]! : Colors.purple[700]!,
      isDarkMode,
    );
  }

  /// 构建文本章节
  Widget _buildTextSection(
    String title,
    String content,
    IconData icon,
    Color color,
    bool isDarkMode,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withOpacity(0.05)
            : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: color,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建分析行
  Widget _buildAnalysisRow(
    String label,
    String value,
    String subtitle,
    Color color,
    bool isDarkMode, {
    IconData? icon,
  }) {
    return Row(
      children: [
        if (icon != null) ...[
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 16,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  /// 获取盈亏比评价
  String _getRiskRatioComment(double ratio) {
    if (ratio >= 3) return '优秀';
    if (ratio >= 2) return '良好';
    if (ratio >= 1) return '合格';
    return '偏低';
  }

  /// 获取盈亏比颜色
  Color _getRiskRatioColor(double ratio, bool isDarkMode) {
    if (ratio >= 3) {
      return isDarkMode ? const Color(0xFFEF4444) : const Color(0xFFDC2626);
    }
    if (ratio >= 2) {
      return isDarkMode ? Colors.orange[300]! : Colors.orange[700]!;
    }
    return isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;
  }

  /// 获取执行质量
  ExecutionQuality _getExecutionQuality(double priceDeviation, double executionDeviation) {
    // 综合价格偏差和执行偏差评估
    if (priceDeviation <= 1 && executionDeviation.abs() <= 5) {
      return ExecutionQuality.excellent;
    }
    if (priceDeviation <= 2 && executionDeviation.abs() <= 10) {
      return ExecutionQuality.good;
    }
    if (priceDeviation <= 3 && executionDeviation.abs() <= 20) {
      return ExecutionQuality.fair;
    }
    return ExecutionQuality.poor;
  }
}

/// 执行质量评级
enum ExecutionQuality {
  excellent,
  good,
  fair,
  poor;

  String get grade {
    switch (this) {
      case ExecutionQuality.excellent:
        return 'A+ 优秀';
      case ExecutionQuality.good:
        return 'A 良好';
      case ExecutionQuality.fair:
        return 'B 合格';
      case ExecutionQuality.poor:
        return 'C 待改进';
    }
  }

  String get comment {
    switch (this) {
      case ExecutionQuality.excellent:
        return '执行精准 👌';
      case ExecutionQuality.good:
        return '执行良好 👍';
      case ExecutionQuality.fair:
        return '基本达标 ✓';
      case ExecutionQuality.poor:
        return '需要改进 ⚠️';
    }
  }

  IconData get icon {
    switch (this) {
      case ExecutionQuality.excellent:
        return Icons.star;
      case ExecutionQuality.good:
        return Icons.thumb_up;
      case ExecutionQuality.fair:
        return Icons.check_circle;
      case ExecutionQuality.poor:
        return Icons.info;
    }
  }

  Color Function(bool) get color {
    switch (this) {
      case ExecutionQuality.excellent:
        return (isDark) => isDark ? const Color(0xFFEF4444) : const Color(0xFFDC2626);
      case ExecutionQuality.good:
        return (isDark) => isDark ? Colors.blue[300]! : Colors.blue[700]!;
      case ExecutionQuality.fair:
        return (isDark) => isDark ? Colors.orange[300]! : Colors.orange[700]!;
      case ExecutionQuality.poor:
        return (isDark) => isDark ? Colors.grey[400]! : Colors.grey[600]!;
    }
  }
}

