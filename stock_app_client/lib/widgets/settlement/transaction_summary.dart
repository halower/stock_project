import 'package:flutter/material.dart';
import '../../models/trade_record.dart';
import 'metric_card.dart';

/// 交易摘要组件
/// 
/// 显示交易金额、成本、盈亏等摘要信息
class TransactionSummary extends StatelessWidget {
  final TradeRecord tradePlan;

  const TransactionSummary({
    Key? key,
    required this.tradePlan,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // 计算各项金额
    final actualPrice = tradePlan.actualPrice ?? 0.0;
    final actualQuantity = tradePlan.actualQuantity ?? 0;
    final commission = tradePlan.commission ?? 0.0;
    final tax = tradePlan.tax ?? 0.0;
    final totalAmount = actualPrice * actualQuantity;
    final totalCost = totalAmount + commission + tax;
    final netProfit = tradePlan.netProfit ?? 0.0;
    final isProfit = netProfit >= 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [
                  const Color(0xFF1F2937).withOpacity(0.8),
                  const Color(0xFF111827).withOpacity(0.9),
                ]
              : [
                  const Color(0xFFF8FAFC),
                  const Color(0xFFF1F5F9),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDarkMode
              ? const Color(0xFF374151).withOpacity(0.5)
              : const Color(0xFFE2E8F0).withOpacity(0.8),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.grey.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDarkMode
                        ? [
                            FinancialColors.info.withOpacity(0.3),
                            FinancialColors.info.withOpacity(0.2),
                          ]
                        : [
                            FinancialColors.info.withOpacity(0.2),
                            FinancialColors.info.withOpacity(0.1),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.receipt_long_outlined,
                  color: FinancialColors.info,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '交易摘要',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 交易金额
          _buildSummaryRow(
            '交易金额',
            totalAmount,
            Icons.attach_money_outlined,
            FinancialColors.primary,
            isDarkMode,
          ),
          const SizedBox(height: 14),

          // 佣金
          _buildSummaryRow(
            '佣金',
            commission,
            Icons.account_balance_outlined,
            FinancialColors.neutral,
            isDarkMode,
          ),
          const SizedBox(height: 14),

          // 税费
          _buildSummaryRow(
            '税费',
            tax,
            Icons.receipt_outlined,
            FinancialColors.neutral,
            isDarkMode,
          ),
          const SizedBox(height: 14),

          // 总成本
          _buildSummaryRow(
            '总成本',
            totalCost,
            Icons.calculate_outlined,
            FinancialColors.warning,
            isDarkMode,
            isBold: true,
          ),
          
          // 分隔线
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Divider(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.2),
              thickness: 1,
            ),
          ),

          // 净盈亏（高亮显示）
          _buildProfitRow(
            '净盈亏',
            netProfit,
            isProfit,
            isDarkMode,
          ),
        ],
      ),
    );
  }

  /// 构建摘要行
  Widget _buildSummaryRow(
    String label,
    double amount,
    IconData icon,
    Color color,
    bool isDarkMode, {
    bool isBold = false,
  }) {
    return Row(
      children: [
        // 图标
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(isDarkMode ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: color,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        
        // 标签
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: isBold ? 15 : 14,
              color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
              fontWeight: isBold ? FontWeight.w600 : FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
        ),
        
        // 金额
        Text(
          '¥${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: isBold ? 16 : 15,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  /// 构建盈亏行（特殊样式）
  Widget _buildProfitRow(
    String label,
    double amount,
    bool isProfit,
    bool isDarkMode,
  ) {
    final color = isProfit ? FinancialColors.profit : FinancialColors.loss;
    final icon = isProfit ? Icons.trending_up : Icons.trending_down;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [
                  color.withOpacity(0.15),
                  color.withOpacity(0.08),
                ]
              : [
                  color.withOpacity(0.1),
                  color.withOpacity(0.05),
                ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(isDarkMode ? 0.3 : 0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // 图标
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(isDarkMode ? 0.25 : 0.15),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          
          // 标签
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
          
          // 金额
          Text(
            isProfit
                ? '+¥${amount.toStringAsFixed(2)}'
                : '-¥${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

