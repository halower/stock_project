import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/trade_record.dart';
import '../services/providers/trade_provider.dart';

class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          '个人交易概览',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        centerTitle: true,
      ),
      body: Consumer<TradeProvider>(
        builder: (context, tradeProvider, child) {
          if (tradeProvider.isLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '加载交易数据...',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          if (tradeProvider.tradeRecords.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    size: 80,
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂无交易记录',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '添加交易记录后，将在此处显示分析数据',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              
              // 主内容
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSummaryCard(context, tradeProvider),
                      const SizedBox(height: 24),
                      _buildMonthlyAnalysis(context, tradeProvider),
                      const SizedBox(height: 24),
                      _buildWinRateChart(context, tradeProvider),
                      const SizedBox(height: 24),
                      _buildProfitChart(context, tradeProvider),
                      const SizedBox(height: 24),
                      _buildRiskMetrics(context, tradeProvider),
                      const SizedBox(height: 24),
                      _buildTradingFrequency(context, tradeProvider),
                      const SizedBox(height: 24),
                      _buildStrategyStats(context, tradeProvider),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
  
  Widget _buildSummaryCard(BuildContext context, TradeProvider tradeProvider) {
    final totalProfit = tradeProvider.totalProfit;
    final winRate = tradeProvider.winRate;
    final averageProfit = tradeProvider.averageProfit;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            isDarkMode ? const Color(0xFF334155) : const Color(0xFFF8FAFC),
                ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isDarkMode 
                ? Colors.black.withOpacity(0.3)
                : Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题区域
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.blue.shade400,
                        Colors.blue.shade600,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.trending_up,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  '交易概览',
                  style: TextStyle(
                    fontSize: 22,
                        fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                      ),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // 数据卡片区域 - 使用A股红涨绿跌色彩
            Row(
              children: [
                Expanded(
                  child: _buildModernStatCard(
                  context,
                  '总盈亏',
                  NumberFormat.currency(symbol: '¥').format(totalProfit),
                    totalProfit >= 0 
                        ? [const Color(0xFFDC2626), const Color(0xFFB91C1C)] // A股红色：盈利
                        : [const Color(0xFF059669), const Color(0xFF047857)], // A股绿色：亏损
                    Icons.account_balance_wallet,
                    totalProfit >= 0 ? '+' : '',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildModernStatCard(
                  context,
                  '胜率',
                  '${winRate.toStringAsFixed(1)}%',
                    [const Color(0xFF3B82F6), const Color(0xFF2563EB)],
                    Icons.emoji_events,
                    '',
                  ),
                ),
              ],
                ),
            
            const SizedBox(height: 16),
            
            // 平均盈亏单独占一行，使其更突出 - 使用A股色彩
            _buildModernStatCard(
                  context,
                  '平均盈亏',
                  NumberFormat.currency(symbol: '¥').format(averageProfit),
              averageProfit >= 0 
                  ? [const Color(0xFFDC2626), const Color(0xFFB91C1C)] // A股红色：盈利
                  : [const Color(0xFF059669), const Color(0xFF047857)], // A股绿色：亏损
              Icons.trending_flat,
              averageProfit >= 0 ? '+' : '',
              isFullWidth: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernStatCard(
    BuildContext context,
    String title,
    String value,
    List<Color> gradientColors,
    IconData icon,
    String prefix,
    {bool isFullWidth = false}
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
            color: gradientColors.first.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
              ),
            ],
          ),
      child: Column(
        crossAxisAlignment: isFullWidth 
            ? CrossAxisAlignment.center 
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isFullWidth 
                ? MainAxisAlignment.center 
                : MainAxisAlignment.spaceBetween,
            children: [
              if (!isFullWidth) ...[
                Icon(
            icon,
                  color: Colors.white.withOpacity(0.9),
            size: 24,
          ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.arrow_upward,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ] else ...[
                Icon(
                  icon,
                  color: Colors.white.withOpacity(0.9),
                  size: 28,
              ),
              ],
            ],
        ),
          
          const SizedBox(height: 12),
          
        Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: isFullWidth ? 16 : 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          
          const SizedBox(height: 8),
          
          RichText(
            text: TextSpan(
              children: [
                if (prefix.isNotEmpty)
                  TextSpan(
                    text: prefix,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isFullWidth ? 24 : 20,
                fontWeight: FontWeight.bold,
                    ),
                  ),
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isFullWidth ? 24 : 20,
                    fontWeight: FontWeight.bold,
              ),
        ),
      ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyAnalysis(BuildContext context, TradeProvider tradeProvider) {
    final records = tradeProvider.tradeRecords;
    final monthlyData = <String, Map<String, dynamic>>{};
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // 按月份统计数据
    for (var record in records) {
      final month = DateFormat('yyyy-MM').format(record.tradeDate);
      if (!monthlyData.containsKey(month)) {
        monthlyData[month] = {
          'profit': 0.0,
          'count': 0,
          'wins': 0,
        };
      }
      
      final profit = record.netProfit ?? 0;
      monthlyData[month]!['profit'] = monthlyData[month]!['profit']! + profit;
      monthlyData[month]!['count'] = monthlyData[month]!['count']! + 1;
      if (profit > 0) {
        monthlyData[month]!['wins'] = monthlyData[month]!['wins']! + 1;
      }
    }

    // 转换为列表并排序
    final sortedMonths = monthlyData.keys.toList()..sort();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            isDarkMode ? const Color(0xFF334155) : const Color(0xFFF8FAFC),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isDarkMode 
                ? Colors.black.withOpacity(0.3)
                : Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.indigo.shade400,
                        Colors.indigo.shade600,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.indigo.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.calendar_month,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  '月度分析',
                  style: TextStyle(
                    fontSize: 22,
                        fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                      ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // 图表容器
            Container(
              height: 220,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode 
                    ? Colors.grey.shade800.withOpacity(0.3)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: monthlyData.isEmpty
                ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              Icons.bar_chart_outlined,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                      '暂无足够数据生成图表',
                      style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                      ),
                          ),
                        ],
                    ),
                  )
                : BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: monthlyData.values.map((e) => e['profit'] as double).reduce((a, b) => a > b ? a : b) * 1.2,
                    minY: monthlyData.values.map((e) => e['profit'] as double).reduce((a, b) => a < b ? a : b) < 0 
                        ? monthlyData.values.map((e) => e['profit'] as double).reduce((a, b) => a < b ? a : b) * 1.2
                        : 0,
                    barGroups: sortedMonths.asMap().entries.map((entry) {
                      final month = entry.value;
                      final data = monthlyData[month]!;
                        final profit = data['profit'] as double;
                        final isProfit = profit >= 0;
                        
                      return BarChartGroupData(
                        x: entry.key,
                        barRods: [
                          BarChartRodData(
                              toY: profit.abs(),
                              gradient: LinearGradient(
                                colors: isProfit 
                                    ? [const Color(0xFFDC2626), const Color(0xFFB91C1C)] // A股红色：盈利
                                    : [const Color(0xFF059669), const Color(0xFF047857)], // A股绿色：亏损
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                              width: 24,
                              borderRadius: BorderRadius.circular(8),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: monthlyData.values.map((e) => e['profit'] as double).reduce((a, b) => a > b ? a : b).abs() * 1.1,
                              color: isDarkMode
                                    ? Colors.grey.shade700.withOpacity(0.3)
                                    : Colors.grey.shade200.withOpacity(0.8),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        tooltipBgColor: isDarkMode 
                              ? Colors.grey.shade800.withOpacity(0.95) 
                              : Colors.white.withOpacity(0.95),
                          tooltipPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          tooltipMargin: 12,
                          tooltipRoundedRadius: 12,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final month = sortedMonths[group.x.toInt()];
                          final data = monthlyData[month]!;
                          final profit = data['profit'] as double;
                          final count = data['count'] as int;
                          final winRate = (data['wins'] as int) / count * 100;
                          
                          return BarTooltipItem(
                              '${DateFormat('yyyy年MM月').format(DateTime.parse('$month-01'))}\n${profit >= 0 ? '+' : ''}${NumberFormat.currency(symbol: '¥').format(profit)}\n交易次数: $count\n胜率: ${winRate.toStringAsFixed(1)}%',
                            TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black,
                                fontWeight: FontWeight.w600,
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
                                  '${sortedMonths[value.toInt()].substring(5)}月',
                                style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                            reservedSize: 50,
                          getTitlesWidget: (value, meta) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Text(
                                  NumberFormat.compactCurrency(symbol: '¥').format(value),
                                style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            );
                          },
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
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                            color: Colors.grey.shade300.withOpacity(0.6),
                          strokeWidth: 1,
                            dashArray: [4, 4],
                        );
                      },
                    ),
                      borderData: FlBorderData(show: false),
                  ),
                ),
            ),
            
            if (sortedMonths.isNotEmpty) ...[
              const SizedBox(height: 20),
              
              // 月度摘要
              Container(
                padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                  color: isDarkMode 
                      ? Colors.grey.shade800.withOpacity(0.3)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '本月表现',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white70 : Colors.grey.shade700,
                          ),
                        ),
                        Icon(
                          Icons.trending_up_outlined,
                          color: Colors.blue.shade600,
                          size: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMonthSummaryItem(
                            context,
                            '盈亏',
                            NumberFormat.currency(symbol: '¥').format(monthlyData[sortedMonths.last]!['profit']),
                            (monthlyData[sortedMonths.last]!['profit'] as double) >= 0,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildMonthSummaryItem(
                            context,
                            '胜率',
                            '${((monthlyData[sortedMonths.last]!['wins'] as int) / (monthlyData[sortedMonths.last]!['count'] as int) * 100).toStringAsFixed(1)}%',
                            null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildMonthSummaryItem(BuildContext context, String label, String value, bool? isPositive) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    Color? valueColor;
    
    if (isPositive != null) {
      valueColor = isPositive 
          ? Colors.green.shade600 
          : Colors.red.shade600;
    } else {
      valueColor = Colors.blue.shade600;
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
                    style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (isPositive != null) ...[
              Icon(
                isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                color: valueColor,
                size: 16,
              ),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: valueColor,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWinRateChart(BuildContext context, TradeProvider tradeProvider) {
    final records = tradeProvider.tradeRecords.where((record) => record.status == TradeStatus.completed).toList();
    if (records.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // 计算盈利、亏损、持平的交易数量
    int winCount = 0;
    int loseCount = 0;
    int drawCount = 0;
    
    for (var record in records) {
      if (record.netProfit == null) {
        continue;
      }
      
      if (record.netProfit! > 0) {
        winCount++;
      } else if (record.netProfit! < 0) {
        loseCount++;
      } else {
        drawCount++;
      }
    }
    
    return Card(
      color: Theme.of(context).cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.tertiary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.pie_chart,
                    color: Theme.of(context).colorScheme.tertiary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '交易结果分布',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 240,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      value: winCount.toDouble(),
                      title: '盈利\n$winCount笔',
                      titleStyle: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                      color: const Color(0xFFF44336),
                      radius: 90,
                      titlePositionPercentageOffset: 0.6,
                    ),
                    PieChartSectionData(
                      value: loseCount.toDouble(),
                      title: '亏损\n$loseCount笔',
                      titleStyle: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                      color: const Color(0xFF4CAF50),
                      radius: 90,
                      titlePositionPercentageOffset: 0.6,
                    ),
                    if (drawCount > 0)
                      PieChartSectionData(
                        value: drawCount.toDouble(),
                        title: '持平\n$drawCount笔',
                        titleStyle: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                        color: const Color(0xFF9E9E9E),
                        radius: 90,
                        titlePositionPercentageOffset: 0.6,
                      ),
                  ],
                  sectionsSpace: 4,
                  centerSpaceRadius: 45,
                  centerSpaceColor: Theme.of(context).cardColor,
                ),
              ),
            ),
            const SizedBox(height: 32),
            // 图例区域
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]?.withOpacity(0.3)
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildLegendItem('盈利', const Color(0xFFF44336), winCount),
                  _buildLegendItem('亏损', const Color(0xFF4CAF50), loseCount),
                  _buildLegendItem('持平', const Color(0xFF9E9E9E), drawCount),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  

  
  Widget _buildLegendItem(String label, Color color, int count) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: $count',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildProfitChart(BuildContext context, TradeProvider tradeProvider) {
    final records = tradeProvider.tradeRecords;
    
    // 改进：计算累计盈亏而不是单次盈亏
    double cumulativeProfit = 0;
    final cumulativeSpots = <FlSpot>[];
    final dateLabels = <String>[];
    
    // 按日期排序交易记录
    final sortedRecords = List<TradeRecord>.from(records)
      ..sort((a, b) => a.tradeDate.compareTo(b.tradeDate));
    
    // 计算每个点的累计盈亏
    for (int i = 0; i < sortedRecords.length; i++) {
      final record = sortedRecords[i];
      final profit = record.netProfit ?? 0;
      cumulativeProfit += profit;
      cumulativeSpots.add(FlSpot(i.toDouble(), cumulativeProfit));
      dateLabels.add(DateFormat('MM-dd').format(record.tradeDate));
    }
    
    // 计算最大和最小值，确保图表能够正确显示
    double minY = 0;
    double maxY = 0;
    
    if (cumulativeSpots.isNotEmpty) {
      minY = cumulativeSpots.map((spot) => spot.y).reduce((a, b) => a < b ? a : b);
      maxY = cumulativeSpots.map((spot) => spot.y).reduce((a, b) => a > b ? a : b);
      
      // 增加边距，使图表更美观
      if (minY < 0) {
        minY = minY * 1.2; // 留出20%的空间
      } else if (minY > 0) {
        minY = 0; // 如果最小值大于0，从0开始
      }
      
      // 确保maxY有足够空间
      if (maxY > 0) {
        maxY = maxY * 1.2;
      } else if (maxY < 0) {
        maxY = 0; // 如果最大值小于0，最高显示到0
      }
      
      // 确保有最小的显示范围
      if (maxY - minY < 100) {
        maxY = minY + 100;
      }
    }
    
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final gridColor = isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300;
    const lineColor = Color(0xFFF44336);
    
    // 计算零基准线的位置
    final zeroLine = minY < 0 ? 0.0 : null;

    return Card(
      color: Theme.of(context).cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: lineColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.trending_up,
                    color: lineColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '盈亏走势（累计）',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: lineColor,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            cumulativeSpots.isEmpty 
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: Text('暂无足够数据生成图表'),
                    ),
                  )
                : SizedBox(
                    height: 220,
                    child: LineChart(
                      LineChartData(
                        minY: minY,
                        maxY: maxY,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: true,
                          drawHorizontalLine: true,
                          horizontalInterval: null, // 自动计算间隔
                          getDrawingHorizontalLine: (value) {
                            // 对零线特殊处理
                            if (zeroLine != null && value.toDouble() == zeroLine) {
                              return FlLine(
                                color: Colors.grey.shade400,
                                strokeWidth: 1.5,
                                dashArray: [5, 5], // 零线使用虚线
                              );
                            }
                            return FlLine(
                              color: gridColor.withOpacity(0.7),
                              strokeWidth: 0.8,
                            );
                          },
                          getDrawingVerticalLine: (value) {
                            return FlLine(
                              color: gridColor.withOpacity(0.5),
                              strokeWidth: 0.8,
                            );
                          },
                        ),
                        lineTouchData: LineTouchData(
                          enabled: true,
                          touchTooltipData: LineTouchTooltipData(
                            tooltipBgColor: isDarkMode 
                                ? Colors.grey.shade800.withOpacity(0.85) 
                                : Colors.white.withOpacity(0.85),
                            tooltipPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            tooltipMargin: 10,
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((touchedSpot) {
                                final index = touchedSpot.spotIndex;
                                if (index >= 0 && index < sortedRecords.length) {
                                  final record = sortedRecords[index];
                                  final date = DateFormat('yyyy-MM-dd').format(record.tradeDate);
                                  final cumulativeValue = touchedSpot.y;
                                  final formattedValue = cumulativeValue >= 0 
                                      ? '+${NumberFormat.currency(symbol: '¥').format(cumulativeValue)}'
                                      : NumberFormat.currency(symbol: '¥').format(cumulativeValue);
                                  
                                  return LineTooltipItem(
                                    '$date\n累计: $formattedValue',
                                    TextStyle(
                                      color: isDarkMode ? Colors.white : Colors.black,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                }
                                return null;
                              }).toList();
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 60,
                              getTitlesWidget: (value, meta) {
                                // 格式化为简洁的金额
                                String formattedValue;
                                if (value.abs() >= 10000) {
                                  formattedValue = '${(value / 10000).toStringAsFixed(1)}w';
                                } else {
                                  formattedValue = value.toInt().toString();
                                }
                                
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: Text(
                                    formattedValue,
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                );
                              },
                              interval: (maxY - minY) / 5,
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final intValue = value.toInt();
                                if (intValue >= 0 && intValue < dateLabels.length && intValue % 5 == 0) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      dateLabels[intValue],
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                              interval: 1,
                            ),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border.all(
                            color: gridColor.withOpacity(0.7),
                            width: 1,
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: cumulativeSpots,
                            isCurved: true,
                            curveSmoothness: 0.35, // 更平滑的曲线
                            color: lineColor.withOpacity(0.85),
                            barWidth: 3.0,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: false,
                              getDotPainter: (spot, percent, barData, index) {
                                return FlDotCirclePainter(
                                  radius: 4,
                                  color: lineColor,
                                  strokeWidth: 1,
                                  strokeColor: Colors.white,
                                );
                              },
                              checkToShowDot: (spot, barData) {
                                // 只在部分点显示圆点
                                return spot.x.toInt() % 5 == 0;
                              },
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              color: lineColor.withOpacity(0.15),
                              gradient: LinearGradient(
                                colors: [
                                  lineColor.withOpacity(0.3),
                                  lineColor.withOpacity(0.1),
                                  lineColor.withOpacity(0.05),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              // 对于负值区域使用不同颜色
                              spotsLine: BarAreaSpotsLine(
                                show: true,
                                flLineStyle: FlLine(
                                  color: Colors.blue.withOpacity(0.5),
                                  strokeWidth: 1,
                                ),
                              ),
                              cutOffY: zeroLine ?? 0,
                              applyCutOffY: zeroLine != null,
                            ),
                            shadow: const Shadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ),
                        ],
                        // 在Y轴=0处添加基准线
                        extraLinesData: zeroLine != null ? ExtraLinesData(
                          horizontalLines: [
                            HorizontalLine(
                              y: zeroLine,
                              color: Colors.grey.withOpacity(0.8),
                              strokeWidth: 1.5,
                              dashArray: [5, 5],
                            ),
                          ],
                        ) : null,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskMetrics(BuildContext context, TradeProvider tradeProvider) {
    final records = tradeProvider.tradeRecords;
    if (records.isEmpty) return const SizedBox.shrink();

    // 计算风险指标
    double maxDrawdown = 0;
    double currentDrawdown = 0;
    double peakValue = 0;
    double totalProfit = 0;
    double maxProfit = 0;
    double maxLoss = 0;
    double profitFactor = 0;
    double totalProfitSum = 0;
    double totalLossSum = 0;

    for (var record in records) {
      final profit = record.netProfit ?? 0;
      totalProfit += profit;
      
      if (profit > 0) {
        totalProfitSum += profit;
        maxProfit = maxProfit < profit ? profit : maxProfit;
      } else {
        totalLossSum += profit.abs();
        maxLoss = maxLoss > profit ? profit : maxLoss;
      }

      if (totalProfit > peakValue) {
        peakValue = totalProfit;
      }
      
      currentDrawdown = peakValue - totalProfit;
      if (currentDrawdown > maxDrawdown) {
        maxDrawdown = currentDrawdown;
      }
    }

    profitFactor = totalLossSum > 0 ? totalProfitSum / totalLossSum : 0;

    return Card(
      color: Theme.of(context).cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.shield,
                    color: Colors.deepPurple,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '风险指标',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildRiskMetricItem(
                  context,
                  '最大回撤',
                  NumberFormat.currency(symbol: '¥').format(maxDrawdown),
                  const Color(0xFF4CAF50),
                  Icons.trending_down,
                ),
                _buildRiskMetricItem(
                  context,
                  '盈亏比',
                  profitFactor.toStringAsFixed(2),
                  const Color(0xFFF44336),
                  Icons.balance,
                ),
                _buildRiskMetricItem(
                  context,
                  '最大单笔盈利',
                  NumberFormat.currency(symbol: '¥').format(maxProfit),
                  const Color(0xFFF44336),
                  Icons.emoji_events,
                ),
                _buildRiskMetricItem(
                  context,
                  '最大单笔亏损',
                  NumberFormat.currency(symbol: '¥').format(maxLoss.abs()),
                  const Color(0xFF4CAF50),
                  Icons.warning_amber,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskMetricItem(
    BuildContext context,
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 5,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              Icon(
                icon,
                size: 18,
                color: color,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTradingFrequency(BuildContext context, TradeProvider tradeProvider) {
    final records = tradeProvider.validTradeRecords; // 使用有效交易记录
    if (records.isEmpty) return const SizedBox.shrink();

    // 按星期统计交易频率，只包含工作日（周一到周五）
    final weekdayCounts = List<int>.filled(5, 0); // 只统计周一到周五
    for (var record in records) {
      final weekday = record.tradeDate.weekday - 1; // 0-4 代表周一到周五
      if (weekday < 5) { // 确保只统计工作日
        weekdayCounts[weekday]++;
      }
    }

    final weekdays = ['周一', '周二', '周三', '周四', '周五'];
    final maxCount = weekdayCounts.reduce((a, b) => a > b ? a : b);

    return Card(
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '交易频率分析',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxCount * 1.2,
                  barGroups: weekdayCounts.asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.toDouble(),
                          color: Theme.of(context).colorScheme.primary,
                          width: 20,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }).toList(),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      tooltipBgColor: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.grey.shade800.withOpacity(0.8) 
                          : Colors.white.withOpacity(0.8),
                      tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      tooltipMargin: 8,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final weekday = weekdays[group.x.toInt()];
                        final count = weekdayCounts[group.x.toInt()];
                        
                        return BarTooltipItem(
                          '$weekday\n交易次数: $count',
                          TextStyle(
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
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
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                fontSize: 10,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                              fontSize: 10,
                            ),
                          );
                        },
                        interval: 1,
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
                    horizontalInterval: 1,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                        strokeWidth: 1,
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '交易时间分布',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: weekdayCounts.asMap().entries.map((entry) {
                return Chip(
                  label: Text(
                    '${weekdays[entry.key]}: ${entry.value}笔',
                  ),
                  backgroundColor: Theme.of(context).colorScheme.surface,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStrategyStats(BuildContext context, TradeProvider tradeProvider) {
    final stats = tradeProvider.strategyStats;

    return Card(
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '策略统计',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: stats.length,
              itemBuilder: (context, index) {
                final strategy = stats.keys.elementAt(index);
                final data = stats[strategy]!;
                return ListTile(
                  title: Text(strategy),
                  subtitle: Text(
                    '交易次数: ${data['count']} | 胜率: ${data['winRate'].toStringAsFixed(1)}%',
                  ),
                  trailing: Text(
                    NumberFormat.currency(symbol: '¥').format(data['totalProfit']),
                    style: TextStyle(
                      color: (data['totalProfit'] as double) >= 0
                          ? const Color(0xFFDC2626) // A股红色：盈利
                          : const Color(0xFF059669), // A股绿色：亏损
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

}