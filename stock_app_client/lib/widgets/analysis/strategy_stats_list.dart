import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/financial_colors.dart';

/// 策略统计列表组件
class StrategyStatsList extends StatelessWidget {
  final Map<String, Map<String, dynamic>> stats;

  const StrategyStatsList({
    super.key,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            children: [
              Icon(
                Icons.auto_graph_outlined,
                size: 60,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                '暂无策略数据',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: stats.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final strategy = stats.keys.elementAt(index);
        final data = stats[strategy]!;
        final totalProfit = data['totalProfit'] as double;
        final count = data['count'] as int;
        final winRate = data['winRate'] as double;

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDarkMode
                  ? [
                      Colors.grey[850]!.withOpacity(0.6),
                      Colors.grey[800]!.withOpacity(0.4),
                    ]
                  : [
                      Colors.white,
                      Colors.grey[50]!,
                    ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: totalProfit >= 0
                  ? FinancialColors.profit.withOpacity(0.2)
                  : FinancialColors.loss.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (totalProfit >= 0
                        ? FinancialColors.profit
                        : FinancialColors.loss)
                    .withOpacity(0.08),
                blurRadius: 15,
                spreadRadius: 0,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 策略名称 - 独占一行
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: totalProfit >= 0
                            ? FinancialColors.profitGradient
                            : FinancialColors.lossGradient,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: (totalProfit >= 0
                                  ? FinancialColors.profit
                                  : FinancialColors.loss)
                              .withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.auto_graph_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      strategy,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.grey[800],
                        letterSpacing: 0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 14),
              
              // 盈亏金额和状态标签 - 横向排列
              Row(
                children: [
                  Expanded(
                    child: Text(
                      NumberFormat.currency(symbol: '¥').format(totalProfit),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: totalProfit >= 0
                            ? FinancialColors.profit
                            : FinancialColors.loss,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: (totalProfit >= 0
                              ? FinancialColors.profit
                              : FinancialColors.loss)
                          .withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          totalProfit >= 0
                              ? Icons.trending_up
                              : Icons.trending_down,
                          size: 16,
                          color: totalProfit >= 0
                              ? FinancialColors.profit
                              : FinancialColors.loss,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          totalProfit >= 0 ? '盈利' : '亏损',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: totalProfit >= 0
                                ? FinancialColors.profit
                                : FinancialColors.loss,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 分隔线
              Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      isDarkMode
                          ? Colors.grey[700]!.withOpacity(0.5)
                          : Colors.grey[300]!.withOpacity(0.5),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 统计数据
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      '交易次数',
                      '$count笔',
                      Icons.format_list_numbered_rounded,
                      FinancialColors.secondary,
                      isDarkMode,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: isDarkMode
                        ? Colors.grey[700]!.withOpacity(0.5)
                        : Colors.grey[300]!.withOpacity(0.5),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      '胜率',
                      '${winRate.toStringAsFixed(1)}%',
                      Icons.emoji_events_rounded,
                      FinancialColors.primary,
                      isDarkMode,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: isDarkMode
                        ? Colors.grey[700]!.withOpacity(0.5)
                        : Colors.grey[300]!.withOpacity(0.5),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      '平均盈亏',
                      NumberFormat.compactCurrency(symbol: '¥')
                          .format(totalProfit / count),
                      Icons.calculate_rounded,
                      totalProfit >= 0
                          ? FinancialColors.profit
                          : FinancialColors.loss,
                      isDarkMode,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isDarkMode,
  ) {
    return Column(
      children: [
        Icon(
          icon,
          size: 18,
          color: color,
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDarkMode ? Colors.white60 : Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
            letterSpacing: 0.3,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

