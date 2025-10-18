import 'package:flutter/material.dart';
import '../../models/trade_record.dart';
import 'key_metrics_row.dart';
import 'metric_card.dart';

/// 股票信息卡片组件
/// 
/// 显示股票基本信息和关键指标
/// 采用专业金融配色，去掉买入标签（A股交易默认都是买入）
class StockInfoCard extends StatelessWidget {
  final TradeRecord tradePlan;

  const StockInfoCard({
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
                  const Color(0xFF1E3A8A).withOpacity(0.3),
                  const Color(0xFF1E40AF).withOpacity(0.2),
                  const Color(0xFF1D4ED8).withOpacity(0.1),
                ]
              : [
                  const Color(0xFFF0F9FF),
                  const Color(0xFFE0F2FE),
                  const Color(0xFFBAE6FD).withOpacity(0.3),
                ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.blue.withOpacity(0.1)
                : Colors.blue.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.2)
                : Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 股票头部信息
            _buildStockHeader(context, isDarkMode),
            const SizedBox(height: 20),

            // 关键指标行
            KeyMetricsRow(tradePlan: tradePlan),
            const SizedBox(height: 20),

            // 详细信息卡片组
            _buildInfoCards(context, isDarkMode),
          ],
        ),
      ),
    );
  }

  /// 构建股票头部信息
  Widget _buildStockHeader(BuildContext context, bool isDarkMode) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 股票名称和代码
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDarkMode
                        ? [
                            const Color(0xFF1E40AF).withOpacity(0.3),
                            const Color(0xFF3B82F6).withOpacity(0.2),
                          ]
                        : [
                            const Color(0xFFDBEAFE),
                            const Color(0xFFBFDBFE),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDarkMode
                        ? const Color(0xFF3B82F6).withOpacity(0.5)
                        : const Color(0xFF60A5FA).withOpacity(0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isDarkMode ? Colors.blue : Colors.blue.shade300)
                          .withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // 股票图标
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? const Color(0xFF3B82F6).withOpacity(0.2)
                            : const Color(0xFF60A5FA).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.candlestick_chart,
                        color: isDarkMode
                            ? const Color(0xFF60A5FA)
                            : const Color(0xFF2563EB),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // 股票名称和代码
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tradePlan.stockName,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode
                                  ? Colors.white
                                  : const Color(0xFF1E40AF),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tradePlan.stockCode,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isDarkMode
                                  ? Colors.grey[400]
                                  : const Color(0xFF64748B),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建信息卡片组
  Widget _buildInfoCards(BuildContext context, bool isDarkMode) {
    return Column(
      children: [
        // 基础信息卡片
        _buildCompactInfoCard(context, isDarkMode),
        const SizedBox(height: 12),
        
        // 风险信息卡片
        _buildRiskInfoCard(context, isDarkMode),
      ],
    );
  }

  /// 构建紧凑信息卡片
  Widget _buildCompactInfoCard(BuildContext context, bool isDarkMode) {
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
              : Colors.white.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          _buildInfoRow('市场阶段', _getMarketPhaseDisplay(tradePlan.marketPhase), isDarkMode),
          const SizedBox(height: 12),
          _buildInfoRow('策略', _getStrategyDisplay(tradePlan.strategy), isDarkMode),
        ],
      ),
    );
  }

  /// 构建风险信息卡片
  Widget _buildRiskInfoCard(BuildContext context, bool isDarkMode) {
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
              : Colors.white.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          if (tradePlan.stopLossPrice != null)
            _buildPriceRow(
              '止损价',
              tradePlan.stopLossPrice!,
              FinancialColors.loss,
              isDarkMode,
            ),
          if (tradePlan.stopLossPrice != null && tradePlan.takeProfitPrice != null)
            const SizedBox(height: 12),
          if (tradePlan.takeProfitPrice != null)
            _buildPriceRow(
              '止盈价',
              tradePlan.takeProfitPrice!,
              FinancialColors.profit,
              isDarkMode,
            ),
        ],
      ),
    );
  }

  /// 构建信息行
  Widget _buildInfoRow(String label, String value, bool isDarkMode) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  /// 获取市场阶段显示文本
  String _getMarketPhaseDisplay(MarketPhase? phase) {
    if (phase == null) return '-';
    switch (phase) {
      case MarketPhase.buildingBottom:
        return '筑底';
      case MarketPhase.rising:
        return '上升';
      case MarketPhase.consolidation:
        return '盘整';
      case MarketPhase.topping:
        return '做头';
      case MarketPhase.falling:
        return '下降';
    }
  }

  /// 获取策略显示文本
  String _getStrategyDisplay(String? strategy) {
    if (strategy == null || strategy.isEmpty) return '-';
    return strategy;
  }

  /// 构建价格行
  Widget _buildPriceRow(String label, double price, Color color, bool isDarkMode) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Text(
          '¥${price.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

