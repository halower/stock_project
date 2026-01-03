import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/price_alert.dart';

class PriceAlertService {
  static const String _alertsKey = 'price_alerts_v1';
  static const String _historyKey = 'price_alerts_history_v1';
  
  // 状态变化通知
  static final ValueNotifier<int> alertChangeNotifier = ValueNotifier<int>(0);
  
  /// 通知状态变化
  static void _notifyChange() {
    alertChangeNotifier.value++;
  }

  /// 获取所有预警
  static Future<List<PriceAlert>> getAllAlerts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alertsJson = prefs.getString(_alertsKey);
      
      if (alertsJson == null || alertsJson.isEmpty) {
        return [];
      }
      
      final List<dynamic> alertsData = json.decode(alertsJson);
      return alertsData.map((item) => PriceAlert.fromJson(item)).toList();
    } catch (e) {
      debugPrint('获取预警列表失败: $e');
      return [];
    }
  }

  /// 获取某只股票的所有预警
  static Future<List<PriceAlert>> getAlertsForStock(String stockCode) async {
    final allAlerts = await getAllAlerts();
    return allAlerts.where((alert) => alert.stockCode == stockCode).toList();
  }

  /// 获取所有活跃的预警（启用且未触发）
  static Future<List<PriceAlert>> getActiveAlerts() async {
    final allAlerts = await getAllAlerts();
    return allAlerts.where((alert) => alert.isActive).toList();
  }

  /// 添加预警
  static Future<void> addAlert(PriceAlert alert) async {
    try {
      final alerts = await getAllAlerts();
      alerts.add(alert);
      await _saveAlerts(alerts);
      _notifyChange();
      debugPrint('添加预警成功: ${alert.stockName}(${alert.stockCode}) ${alert.alertType.displayName} ¥${alert.targetPrice}');
    } catch (e) {
      debugPrint('添加预警失败: $e');
      rethrow;
    }
  }

  /// 更新预警
  static Future<void> updateAlert(PriceAlert alert) async {
    try {
      final alerts = await getAllAlerts();
      final index = alerts.indexWhere((a) => a.id == alert.id);
      
      if (index == -1) {
        throw Exception('预警不存在: ${alert.id}');
      }
      
      alerts[index] = alert;
      await _saveAlerts(alerts);
      _notifyChange();
      debugPrint('更新预警成功: ${alert.id}');
    } catch (e) {
      debugPrint('更新预警失败: $e');
      rethrow;
    }
  }

  /// 删除预警
  static Future<void> deleteAlert(String alertId) async {
    try {
      final alerts = await getAllAlerts();
      alerts.removeWhere((alert) => alert.id == alertId);
      await _saveAlerts(alerts);
      _notifyChange();
      debugPrint('删除预警成功: $alertId');
    } catch (e) {
      debugPrint('删除预警失败: $e');
      rethrow;
    }
  }

  /// 删除某只股票的所有预警
  static Future<void> deleteAlertsForStock(String stockCode) async {
    try {
      final alerts = await getAllAlerts();
      alerts.removeWhere((alert) => alert.stockCode == stockCode);
      await _saveAlerts(alerts);
      _notifyChange();
      debugPrint('删除股票预警成功: $stockCode');
    } catch (e) {
      debugPrint('删除股票预警失败: $e');
      rethrow;
    }
  }

  /// 启用/禁用预警
  static Future<void> toggleAlert(String alertId, bool isEnabled) async {
    try {
      final alerts = await getAllAlerts();
      final index = alerts.indexWhere((a) => a.id == alertId);
      
      if (index == -1) {
        throw Exception('预警不存在: $alertId');
      }
      
      alerts[index] = alerts[index].copyWith(isEnabled: isEnabled);
      await _saveAlerts(alerts);
      _notifyChange();
      debugPrint('${isEnabled ? "启用" : "禁用"}预警成功: $alertId');
    } catch (e) {
      debugPrint('切换预警状态失败: $e');
      rethrow;
    }
  }

  /// 触发预警（标记为已触发并禁用）
  static Future<void> triggerAlert(String alertId, double triggeredPrice) async {
    try {
      final alerts = await getAllAlerts();
      final index = alerts.indexWhere((a) => a.id == alertId);
      
      if (index == -1) {
        throw Exception('预警不存在: $alertId');
      }
      
      final triggeredAlert = alerts[index].copyWith(
        isEnabled: false,
        triggeredAt: DateTime.now(),
        triggeredPrice: triggeredPrice,
      );
      
      alerts[index] = triggeredAlert;
      await _saveAlerts(alerts);
      
      // 添加到历史记录
      await _addToHistory(triggeredAlert);
      
      _notifyChange();
      debugPrint('触发预警: ${triggeredAlert.stockName}(${triggeredAlert.stockCode}) '
          '${triggeredAlert.alertType.displayName} ¥${triggeredAlert.targetPrice} -> ¥$triggeredPrice');
    } catch (e) {
      debugPrint('触发预警失败: $e');
      rethrow;
    }
  }

  /// 检查价格并触发预警
  /// 返回被触发的预警列表
  static Future<List<PriceAlert>> checkAndTriggerAlerts(String stockCode, double currentPrice) async {
    try {
      final alerts = await getAlertsForStock(stockCode);
      final triggeredAlerts = <PriceAlert>[];
      
      for (final alert in alerts) {
        if (alert.checkTrigger(currentPrice)) {
          await triggerAlert(alert.id, currentPrice);
          triggeredAlerts.add(alert);
        }
      }
      
      return triggeredAlerts;
    } catch (e) {
      debugPrint('检查预警失败: $e');
      return [];
    }
  }

  /// 批量检查多只股票的预警
  /// 返回 Map<股票代码, 触发的预警列表>
  static Future<Map<String, List<PriceAlert>>> batchCheckAlerts(Map<String, double> stockPrices) async {
    final result = <String, List<PriceAlert>>{};
    
    for (final entry in stockPrices.entries) {
      final triggeredAlerts = await checkAndTriggerAlerts(entry.key, entry.value);
      if (triggeredAlerts.isNotEmpty) {
        result[entry.key] = triggeredAlerts;
      }
    }
    
    return result;
  }

  /// 重新启用已触发的预警
  static Future<void> reEnableAlert(String alertId) async {
    try {
      final alerts = await getAllAlerts();
      final index = alerts.indexWhere((a) => a.id == alertId);
      
      if (index == -1) {
        throw Exception('预警不存在: $alertId');
      }
      
      alerts[index] = alerts[index].copyWith(
        isEnabled: true,
        triggeredAt: null,
        triggeredPrice: null,
      );
      
      await _saveAlerts(alerts);
      _notifyChange();
      debugPrint('重新启用预警成功: $alertId');
    } catch (e) {
      debugPrint('重新启用预警失败: $e');
      rethrow;
    }
  }

  /// 获取预警历史记录
  static Future<List<PriceAlert>> getHistory({int limit = 100}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_historyKey);
      
      if (historyJson == null || historyJson.isEmpty) {
        return [];
      }
      
      final List<dynamic> historyData = json.decode(historyJson);
      final history = historyData.map((item) => PriceAlert.fromJson(item)).toList();
      
      // 按触发时间倒序排序
      history.sort((a, b) {
        if (a.triggeredAt == null && b.triggeredAt == null) return 0;
        if (a.triggeredAt == null) return 1;
        if (b.triggeredAt == null) return -1;
        return b.triggeredAt!.compareTo(a.triggeredAt!);
      });
      
      return history.take(limit).toList();
    } catch (e) {
      debugPrint('获取预警历史失败: $e');
      return [];
    }
  }

  /// 清理过期的历史记录（保留最近30天）
  static Future<void> cleanupHistory({int daysToKeep = 30}) async {
    try {
      final history = await getHistory(limit: 1000);
      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
      
      final recentHistory = history.where((alert) {
        if (alert.triggeredAt == null) return false;
        return alert.triggeredAt!.isAfter(cutoffDate);
      }).toList();
      
      await _saveHistory(recentHistory);
      debugPrint('清理历史记录完成，保留 ${recentHistory.length} 条');
    } catch (e) {
      debugPrint('清理历史记录失败: $e');
    }
  }

  /// 获取统计信息
  static Future<Map<String, dynamic>> getStatistics() async {
    try {
      final allAlerts = await getAllAlerts();
      final history = await getHistory();
      
      final activeCount = allAlerts.where((a) => a.isActive).length;
      final triggeredCount = allAlerts.where((a) => a.isTriggered).length;
      final disabledCount = allAlerts.where((a) => !a.isEnabled && !a.isTriggered).length;
      
      // 按类型统计
      final typeStats = <AlertType, int>{};
      for (final alert in allAlerts) {
        typeStats[alert.alertType] = (typeStats[alert.alertType] ?? 0) + 1;
      }
      
      return {
        'total': allAlerts.length,
        'active': activeCount,
        'triggered': triggeredCount,
        'disabled': disabledCount,
        'history_count': history.length,
        'by_type': {
          'target_price': typeStats[AlertType.targetPrice] ?? 0,
          'stop_loss': typeStats[AlertType.stopLoss] ?? 0,
          'take_profit': typeStats[AlertType.takeProfit] ?? 0,
        },
      };
    } catch (e) {
      debugPrint('获取统计信息失败: $e');
      return {};
    }
  }

  /// 保存预警列表
  static Future<void> _saveAlerts(List<PriceAlert> alerts) async {
    final prefs = await SharedPreferences.getInstance();
    final alertsJson = json.encode(alerts.map((a) => a.toJson()).toList());
    await prefs.setString(_alertsKey, alertsJson);
  }

  /// 添加到历史记录
  static Future<void> _addToHistory(PriceAlert alert) async {
    try {
      final history = await getHistory(limit: 1000);
      history.insert(0, alert);
      
      // 只保留最近500条历史
      final limitedHistory = history.take(500).toList();
      await _saveHistory(limitedHistory);
    } catch (e) {
      debugPrint('添加历史记录失败: $e');
    }
  }

  /// 保存历史记录
  static Future<void> _saveHistory(List<PriceAlert> history) async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = json.encode(history.map((a) => a.toJson()).toList());
    await prefs.setString(_historyKey, historyJson);
  }

  /// 清空所有预警
  static Future<void> clearAllAlerts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_alertsKey);
      _notifyChange();
      debugPrint('清空所有预警成功');
    } catch (e) {
      debugPrint('清空预警失败: $e');
      rethrow;
    }
  }

  /// 清空历史记录
  static Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyKey);
      debugPrint('清空历史记录成功');
    } catch (e) {
      debugPrint('清空历史记录失败: $e');
      rethrow;
    }
  }

  /// 导出预警配置为JSON
  static Future<String> exportAlerts() async {
    final alerts = await getAllAlerts();
    return json.encode(alerts.map((a) => a.toJson()).toList());
  }

  /// 从JSON导入预警配置
  static Future<void> importAlerts(String jsonString) async {
    try {
      final List<dynamic> alertsData = json.decode(jsonString);
      final alerts = alertsData.map((item) => PriceAlert.fromJson(item)).toList();
      await _saveAlerts(alerts);
      _notifyChange();
      debugPrint('导入预警成功: ${alerts.length} 条');
    } catch (e) {
      debugPrint('导入预警失败: $e');
      rethrow;
    }
  }
}

