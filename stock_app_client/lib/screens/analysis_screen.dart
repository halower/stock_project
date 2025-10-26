import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/trade_record.dart';
import '../services/providers/trade_provider.dart';
import '../utils/financial_colors.dart';
import '../widgets/analysis/modern_section_card.dart';
import '../widgets/analysis/profit_distribution_pie_chart.dart';
import '../widgets/analysis/risk_metrics_grid.dart';
import '../widgets/analysis/trading_frequency_chart.dart';
import '../widgets/analysis/strategy_stats_list.dart';

class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF0F1419) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: FinancialColors.goldGradient,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: FinancialColors.primary.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.analytics_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
          '个人交易概览',
          style: TextStyle(
            fontWeight: FontWeight.bold,
                fontSize: 20,
          ),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDarkMode
                  ? [const Color(0xFF1A1F3A), const Color(0xFF0F1419)]
                  : [Colors.white, const Color(0xFFF8FAFC)],
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: Consumer<TradeProvider>(
        builder: (context, tradeProvider, child) {
          if (tradeProvider.isLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: FinancialColors.goldGradient,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: FinancialColors.primary.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '加载交易数据中...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white70 : Colors.grey[700],
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
                  Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          FinancialColors.primary.withOpacity(0.1),
                          FinancialColors.secondary.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Icon(
                    Icons.analytics_outlined,
                    size: 80,
                      color: FinancialColors.primary,
                  ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '暂无交易记录',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '添加交易记录后，将在此处显示专业分析数据',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? Colors.white60 : Colors.grey[600],
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
          colors: isDarkMode
              ? [const Color(0xFF1A1F3A), const Color(0xFF2D3748)]
              : [Colors.white, const Color(0xFFF8FAFC)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDarkMode
              ? FinancialColors.primary.withOpacity(0.2)
              : FinancialColors.primary.withOpacity(0.1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode 
                ? Colors.black.withOpacity(0.4)
                : FinancialColors.primary.withOpacity(0.08),
            blurRadius: 30,
            spreadRadius: 0,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: FinancialColors.secondary.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: -5,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题区域 - 更震撼的设计
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: FinancialColors.goldGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: FinancialColors.primary.withOpacity(0.5),
                        blurRadius: 15,
                        spreadRadius: 0,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: FinancialColors.primary.withOpacity(0.2),
                        blurRadius: 25,
                        spreadRadius: -2,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 18),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                  '交易概览',
                  style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Trading Overview',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDarkMode ? Colors.white60 : Colors.grey[600],
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
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
    return Container(
      padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            gradientColors.first,
            gradientColors.last,
          ],
          stops: const [0.0, 1.0],
        ),
        borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
            color: gradientColors.first.withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: gradientColors.last.withOpacity(0.2),
            blurRadius: 30,
            spreadRadius: -5,
            offset: const Offset(0, 15),
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
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
            icon,
                    color: Colors.white,
                    size: 26,
                  ),
          ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.trending_up,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                  icon,
                    color: Colors.white,
                    size: 32,
                  ),
              ),
              ],
            ],
        ),
          
          const SizedBox(height: 16),
          
        Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.95),
              fontSize: isFullWidth ? 15 : 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          
          const SizedBox(height: 10),
          
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: isFullWidth ? Alignment.center : Alignment.centerLeft,
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.visible,
              text: TextSpan(
                children: [
                  if (prefix.isNotEmpty)
                    TextSpan(
                      text: prefix,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isFullWidth ? 28 : 24,
                  fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isFullWidth ? 28 : 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
              ),
        ),
      ],
            ),
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
          colors: isDarkMode
              ? [const Color(0xFF1A1F3A), const Color(0xFF2D3748)]
              : [Colors.white, const Color(0xFFF8FAFC)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDarkMode
              ? FinancialColors.secondary.withOpacity(0.2)
              : FinancialColors.secondary.withOpacity(0.1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode 
                ? Colors.black.withOpacity(0.4)
                : FinancialColors.secondary.withOpacity(0.08),
            blurRadius: 30,
            spreadRadius: 0,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: FinancialColors.secondary.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: -5,
            offset: const Offset(0, 15),
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
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: FinancialColors.blueGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: FinancialColors.secondary.withOpacity(0.5),
                        blurRadius: 15,
                        spreadRadius: 0,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: FinancialColors.secondary.withOpacity(0.2),
                        blurRadius: 25,
                        spreadRadius: -2,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.bar_chart_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 18),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                  '月度分析',
                  style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Monthly Analysis',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDarkMode ? Colors.white60 : Colors.grey[600],
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
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
    final records = tradeProvider.tradeRecords;
    if (records.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return ModernSectionCard(
      title: '交易结果分布',
      subtitle: 'Profit Distribution',
      icon: Icons.pie_chart_rounded,
      iconGradient: FinancialColors.purpleGradient,
      child: ProfitDistributionPieChart(records: records),
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

    return ModernSectionCard(
      title: '盈亏走势',
      subtitle: 'Cumulative P&L',
      icon: Icons.show_chart_rounded,
      iconGradient: FinancialColors.profitGradient,
      child: cumulativeSpots.isEmpty 
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

    return ModernSectionCard(
      title: '风险指标',
      subtitle: 'Risk Metrics',
      icon: Icons.shield_outlined,
      iconGradient: FinancialColors.indigoGradient,
      child: RiskMetricsGrid(
        maxDrawdown: maxDrawdown,
        profitFactor: profitFactor,
        maxProfit: maxProfit,
        maxLoss: maxLoss,
      ),
    );
  }

  Widget _buildTradingFrequency(BuildContext context, TradeProvider tradeProvider) {
    final records = tradeProvider.validTradeRecords;
    if (records.isEmpty) return const SizedBox.shrink();

    return ModernSectionCard(
      title: '交易频率分析',
      subtitle: 'Trading Frequency',
      icon: Icons.calendar_today_rounded,
      iconGradient: FinancialColors.blueGradient,
      child: TradingFrequencyChart(records: records),
    );
  }

  Widget _buildStrategyStats(BuildContext context, TradeProvider tradeProvider) {
    final stats = tradeProvider.strategyStats;

    return ModernSectionCard(
      title: '策略统计',
      subtitle: 'Strategy Statistics',
      icon: Icons.psychology_rounded,
      iconGradient: FinancialColors.purpleGradient,
      child: StrategyStatsList(stats: stats),
    );
  }

}