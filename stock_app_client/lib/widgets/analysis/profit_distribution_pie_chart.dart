import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/trade_record.dart';
import '../../utils/financial_colors.dart';

/// 盈亏分布饼图组件
class ProfitDistributionPieChart extends StatelessWidget {
  final List<TradeRecord> records;

  const ProfitDistributionPieChart({
    super.key,
    required this.records,
  });

  @override
  Widget build(BuildContext context) {
    final completedRecords = records.where((record) => record.status == TradeStatus.completed).toList();
    
    if (completedRecords.isEmpty) {
      return const SizedBox.shrink();
    }

    // 计算盈利、亏损、持平的交易数量
    int winCount = 0;
    int loseCount = 0;
    int drawCount = 0;

    for (var record in completedRecords) {
      if (record.netProfit == null) continue;

      if (record.netProfit! > 0) {
        winCount++;
      } else if (record.netProfit! < 0) {
        loseCount++;
      } else {
        drawCount++;
      }
    }

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // 饼图
        SizedBox(
          height: 260,
          child: PieChart(
            PieChartData(
              sections: [
                PieChartSectionData(
                  value: winCount.toDouble(),
                  title: '$winCount笔',
                  titleStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    shadows: [
                      Shadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  color: FinancialColors.profit,
                  radius: 100,
                  titlePositionPercentageOffset: 0.55,
                  badgeWidget: _buildBadge(Icons.trending_up, FinancialColors.profit),
                  badgePositionPercentageOffset: 1.3,
                ),
                PieChartSectionData(
                  value: loseCount.toDouble(),
                  title: '$loseCount笔',
                  titleStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    shadows: [
                      Shadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  color: FinancialColors.loss,
                  radius: 100,
                  titlePositionPercentageOffset: 0.55,
                  badgeWidget: _buildBadge(Icons.trending_down, FinancialColors.loss),
                  badgePositionPercentageOffset: 1.3,
                ),
                if (drawCount > 0)
                  PieChartSectionData(
                    value: drawCount.toDouble(),
                    title: '$drawCount笔',
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    color: FinancialColors.chartGray,
                    radius: 100,
                    titlePositionPercentageOffset: 0.55,
                    badgeWidget: _buildBadge(Icons.horizontal_rule, FinancialColors.chartGray),
                    badgePositionPercentageOffset: 1.3,
                  ),
              ],
              sectionsSpace: 3,
              centerSpaceRadius: 50,
              centerSpaceColor: isDarkMode ? const Color(0xFF1A1F3A) : Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 32),
        // 图例区域 - 更专业的设计
        Container(
          padding: const EdgeInsets.all(20),
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildLegendItem(
                '盈利',
                FinancialColors.profit,
                winCount,
                Icons.trending_up,
                isDarkMode,
              ),
              Container(
                width: 1,
                height: 40,
                color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
              ),
              _buildLegendItem(
                '亏损',
                FinancialColors.loss,
                loseCount,
                Icons.trending_down,
                isDarkMode,
              ),
              if (drawCount > 0) ...[
                Container(
                  width: 1,
                  height: 40,
                  color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                ),
                _buildLegendItem(
                  '持平',
                  FinancialColors.chartGray,
                  drawCount,
                  Icons.horizontal_rule,
                  isDarkMode,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBadge(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        icon,
        color: color,
        size: 16,
      ),
    );
  }

  Widget _buildLegendItem(
    String label,
    Color color,
    int count,
    IconData icon,
    bool isDarkMode,
  ) {
    final total = records.where((r) => r.status == TradeStatus.completed && r.netProfit != null).length;
    final percentage = total > 0 ? (count / total * 100).toStringAsFixed(1) : '0.0';

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white70 : Colors.grey[700],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$count笔',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          '$percentage%',
          style: TextStyle(
            fontSize: 11,
            color: isDarkMode ? Colors.white60 : Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

