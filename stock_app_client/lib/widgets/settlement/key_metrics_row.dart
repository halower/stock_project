import 'package:flutter/material.dart';
import '../../models/trade_record.dart';
import 'metric_card.dart';

/// 关键指标行组件
/// 
/// 显示进场价格、计划数量、盈亏比等关键指标
class KeyMetricsRow extends StatelessWidget {
  final TradeRecord tradePlan;

  const KeyMetricsRow({
    Key? key,
    required this.tradePlan,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        // 进场价格
        Expanded(
          child: MetricCard(
            label: '进场价格',
            value: '¥${(tradePlan.planPrice ?? 0).toStringAsFixed(2)}',
            icon: Icons.price_check_outlined,
            color: FinancialColors.price,
          ),
        ),
        const SizedBox(width: 12),

        // 计划数量
        Expanded(
          child: MetricCard(
            label: '计划数量',
            value: '${tradePlan.planQuantity ?? 0}股',
            icon: Icons.format_list_numbered_outlined,
            color: FinancialColors.quantity,
          ),
        ),
        const SizedBox(width: 12),

        // 盈亏比或净盈亏
        Expanded(
          child: tradePlan.netProfit != null
              ? _buildNetProfitCard(isDarkMode)
              : _buildProfitRiskRatioCard(),
        ),
      ],
    );
  }

  /// 构建净盈亏卡片
  Widget _buildNetProfitCard(bool isDarkMode) {
    final netProfit = tradePlan.netProfit!;
    final isProfit = netProfit >= 0;

    return MetricCard(
      label: '净盈亏',
      value: isProfit
          ? '+¥${netProfit.toStringAsFixed(2)}'
          : '-¥${netProfit.abs().toStringAsFixed(2)}',
      icon: isProfit ? Icons.trending_up : Icons.trending_down,
      color: isProfit ? FinancialColors.profit : FinancialColors.loss,
    );
  }

  /// 构建盈亏比卡片
  Widget _buildProfitRiskRatioCard() {
    final ratio = _calculateProfitRiskRatio();

    return MetricCard(
      label: '盈亏比',
      value: ratio.toStringAsFixed(2),
      icon: Icons.analytics_outlined,
      color: FinancialColors.warning,
    );
  }

  /// 计算盈亏比
  double _calculateProfitRiskRatio() {
    final planPrice = tradePlan.planPrice ?? 0.0;
    final stopLossPrice = tradePlan.stopLossPrice ?? 0.0;
    final takeProfitPrice = tradePlan.takeProfitPrice ?? 0.0;

    if (planPrice == 0 || stopLossPrice == 0 || takeProfitPrice == 0) {
      return 0.0;
    }

    final profitSpace = (takeProfitPrice - planPrice).abs();
    final lossSpace = (planPrice - stopLossPrice).abs();

    if (lossSpace == 0) return 0.0;

    return profitSpace / lossSpace;
  }
}

