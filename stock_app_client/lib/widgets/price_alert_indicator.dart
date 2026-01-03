import 'package:flutter/material.dart';
import '../models/price_alert.dart';

/// 价格预警指示器组件
class PriceAlertIndicator extends StatelessWidget {
  final List<PriceAlert>? alerts;
  final VoidCallback? onTap;

  const PriceAlertIndicator({
    super.key,
    this.alerts,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (alerts == null || alerts!.isEmpty) {
      return SizedBox.shrink();
    }

    final activeAlerts = alerts!.where((a) => a.isActive).toList();
    
    if (activeAlerts.isEmpty) {
      return SizedBox.shrink();
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange[300]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_active,
              size: 14,
              color: Colors.orange[800],
            ),
            SizedBox(width: 4),
            Text(
              '${activeAlerts.length}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.orange[800],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 价格预警摘要组件（显示具体预警信息）
class PriceAlertSummary extends StatelessWidget {
  final List<PriceAlert> alerts;
  final double? currentPrice;

  const PriceAlertSummary({
    super.key,
    required this.alerts,
    this.currentPrice,
  });

  @override
  Widget build(BuildContext context) {
    final activeAlerts = alerts.where((a) => a.isActive).toList();
    
    if (activeAlerts.isEmpty) {
      return SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: activeAlerts.take(3).map((alert) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Text(alert.alertType.icon, style: TextStyle(fontSize: 12)),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${alert.alertType.displayName}: ¥${alert.targetPrice.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

