import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/trade_record.dart';
import '../../utils/financial_colors.dart';

/// 交易频率图表组件
class TradingFrequencyChart extends StatelessWidget {
  final List<TradeRecord> records;

  const TradingFrequencyChart({
    super.key,
    required this.records,
  });

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // 按星期统计交易频率，只包含工作日（周一到周五）
    final weekdayCounts = List<int>.filled(5, 0);
    for (var record in records) {
      final weekday = record.tradeDate.weekday - 1; // 0-4 代表周一到周五
      if (weekday < 5) {
        weekdayCounts[weekday]++;
      }
    }

    final weekdays = ['周一', '周二', '周三', '周四', '周五'];
    final maxCount = weekdayCounts.reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 图表
        Container(
          height: 220,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDarkMode
                  ? [
                      Colors.grey[850]!.withOpacity(0.5),
                      Colors.grey[800]!.withOpacity(0.3),
                    ]
                  : [
                      Colors.grey[50]!,
                      Colors.grey[100]!,
                    ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDarkMode
                  ? Colors.grey[700]!.withOpacity(0.3)
                  : Colors.grey[300]!.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxCount > 0 ? maxCount * 1.2 : 10,
              barGroups: weekdayCounts.asMap().entries.map((entry) {
                return BarChartGroupData(
                  x: entry.key,
                  barRods: [
                    BarChartRodData(
                      toY: entry.value.toDouble(),
                      gradient: LinearGradient(
                        colors: FinancialColors.blueGradient,
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                      width: 32,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(8),
                      ),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: maxCount > 0 ? maxCount * 1.2 : 10,
                        color: isDarkMode
                            ? Colors.grey[700]!.withOpacity(0.3)
                            : Colors.grey[200]!.withOpacity(0.8),
                      ),
                    ),
                  ],
                );
              }).toList(),
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  tooltipBgColor: isDarkMode
                      ? Colors.grey[800]!.withOpacity(0.95)
                      : Colors.white.withOpacity(0.95),
                  tooltipPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  tooltipMargin: 12,
                  tooltipRoundedRadius: 12,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final weekday = weekdays[group.x.toInt()];
                    final count = weekdayCounts[group.x.toInt()];

                    return BarTooltipItem(
                      '$weekday\n交易次数: $count',
                      TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          weekdays[value.toInt()],
                          style: TextStyle(
                            color: isDarkMode
                                ? Colors.white70
                                : Colors.grey[700],
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    getTitlesWidget: (value, meta) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            color: isDarkMode
                                ? Colors.white60
                                : Colors.grey[600],
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      );
                    },
                    interval: maxCount > 5 ? (maxCount / 5).ceilToDouble() : 1,
                  ),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxCount > 5 ? (maxCount / 5).ceilToDouble() : 1,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: isDarkMode
                        ? Colors.grey[700]!.withOpacity(0.3)
                        : Colors.grey[300]!.withOpacity(0.6),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  );
                },
              ),
              borderData: FlBorderData(show: false),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // 统计摘要
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDarkMode
                  ? [
                      FinancialColors.secondary.withOpacity(0.15),
                      FinancialColors.secondary.withOpacity(0.08),
                    ]
                  : [
                      FinancialColors.secondary.withOpacity(0.08),
                      FinancialColors.secondary.withOpacity(0.05),
                    ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: FinancialColors.secondary.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.insights_rounded,
                    color: FinancialColors.secondary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '交易时间分布',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.grey[800],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: weekdayCounts.asMap().entries.map((entry) {
                  final count = entry.value;
                  final total = weekdayCounts.reduce((a, b) => a + b);
                  final percentage = total > 0 ? (count / total * 100).toStringAsFixed(0) : '0';
                  
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.grey[800]!.withOpacity(0.5)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: FinancialColors.secondary.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          weekdays[entry.key],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white70 : Colors.grey[700],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$count笔',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: FinancialColors.secondary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '($percentage%)',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDarkMode ? Colors.white60 : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

