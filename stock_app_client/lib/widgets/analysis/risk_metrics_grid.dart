import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/financial_colors.dart';

/// 风险指标网格组件
class RiskMetricsGrid extends StatelessWidget {
  final double maxDrawdown;
  final double profitFactor;
  final double maxProfit;
  final double maxLoss;

  const RiskMetricsGrid({
    super.key,
    required this.maxDrawdown,
    required this.profitFactor,
    required this.maxProfit,
    required this.maxLoss,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5, // 增加高度比例，避免溢出
      children: [
        _buildMetricCard(
          context,
          '最大回撤',
          NumberFormat.currency(symbol: '¥').format(maxDrawdown),
          FinancialColors.loss,
          Icons.trending_down_rounded,
          'Max Drawdown',
          isDarkMode,
        ),
        _buildMetricCard(
          context,
          '盈亏比',
          profitFactor.toStringAsFixed(2),
          FinancialColors.secondary,
          Icons.balance_rounded,
          'Profit Factor',
          isDarkMode,
        ),
        _buildMetricCard(
          context,
          '最大单笔盈利',
          NumberFormat.currency(symbol: '¥').format(maxProfit),
          FinancialColors.profit,
          Icons.emoji_events_rounded,
          'Max Profit',
          isDarkMode,
        ),
        _buildMetricCard(
          context,
          '最大单笔亏损',
          NumberFormat.currency(symbol: '¥').format(maxLoss.abs()),
          FinancialColors.chartOrange,
          Icons.warning_amber_rounded,
          'Max Loss',
          isDarkMode,
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    BuildContext context,
    String label,
    String value,
    Color color,
    IconData icon,
    String subtitle,
    bool isDarkMode,
  ) {
    return Container(
      padding: const EdgeInsets.all(14), // 减少内边距 18 → 14
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(20), // 减少圆角 22 → 20
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 15,
            spreadRadius: 0,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12, // 减小字体 13 → 12
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white70 : Colors.grey[700],
                        letterSpacing: 0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 9,
                        color: isDarkMode ? Colors.white.withOpacity(0.5) : Colors.grey[500],
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8), // 减少内边距 10 → 8
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12), // 减少圆角 14 → 12
                  border: Border.all(
                    color: color.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 20, // 减小图标 22 → 20
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6), // 减少间距 8 → 6
          Text(
            value,
            style: TextStyle(
              fontSize: 16, // 减小字体 18 → 16
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

