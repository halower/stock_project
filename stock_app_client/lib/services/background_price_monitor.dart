import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'price_alert_service.dart';
import 'notification_service.dart';
import 'api_service.dart';

/// 后台任务回调分发器
/// 注意：这个函数必须是顶层函数，不能是类的静态方法
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    debugPrint('[后台任务] 开始执行: $task');
    
    try {
      // 根据任务类型执行不同的逻辑
      switch (task) {
        case 'priceMonitoring':
          await _executePriceMonitoring();
          break;
        default:
          debugPrint('[后台任务] 未知任务类型: $task');
      }
      
      debugPrint('[后台任务] 执行完成: $task');
      return Future.value(true);
    } catch (e) {
      debugPrint('[后台任务] 执行失败: $e');
      return Future.value(false);
    }
  });
}

/// 执行价格监控任务
Future<void> _executePriceMonitoring() async {
  try {
    debugPrint('[价格监控] 开始检查预警');
    
    // 1. 检查是否在交易时间
    if (!_isTradingTime()) {
      debugPrint('[价格监控] 非交易时间，跳过检查');
      return;
    }
    
    // 2. 获取所有活跃的预警
    final activeAlerts = await PriceAlertService.getActiveAlerts();
    if (activeAlerts.isEmpty) {
      debugPrint('[价格监控] 没有活跃的预警');
      return;
    }
    
    debugPrint('[价格监控] 找到 ${activeAlerts.length} 个活跃预警');
    
    // 3. 获取需要检查的股票代码列表
    final stockCodes = activeAlerts.map((alert) => alert.stockCode).toSet().toList();
    
    // 4. 批量获取股票价格
    final apiService = ApiService();
    final priceDataList = await apiService.getBatchStockPrices(stockCodes);
    
    // 5. 构建价格映射
    final stockPrices = <String, double>{};
    final changePercents = <String, double>{};
    
    for (final priceData in priceDataList) {
      final code = priceData['code']?.toString();
      final price = priceData['price'];
      final changePercent = priceData['change_percent'];
      
      if (code != null && price != null) {
        stockPrices[code] = double.tryParse(price.toString()) ?? 0;
        changePercents[code] = double.tryParse(changePercent?.toString() ?? '0') ?? 0;
      }
    }
    
    debugPrint('[价格监控] 获取到 ${stockPrices.length} 只股票的价格');
    
    // 6. 检查并触发预警
    final triggeredAlerts = await PriceAlertService.batchCheckAlerts(stockPrices);
    
    if (triggeredAlerts.isEmpty) {
      debugPrint('[价格监控] 没有预警被触发');
      return;
    }
    
    debugPrint('[价格监控] ${triggeredAlerts.length} 只股票触发了预警');
    
    // 7. 初始化通知服务并发送通知
    await NotificationService.initialize();
    await NotificationService.sendBatchAlertNotifications(
      triggeredAlerts,
      stockPrices,
      changePercents,
    );
    
    debugPrint('[价格监控] 通知发送完成');
  } catch (e) {
    debugPrint('[价格监控] 执行失败: $e');
  }
}

/// 判断是否在交易时间
bool _isTradingTime() {
  final now = DateTime.now();
  final hour = now.hour;
  final minute = now.minute;
  final weekday = now.weekday;
  
  // 周末不交易
  if (weekday == DateTime.saturday || weekday == DateTime.sunday) {
    return false;
  }
  
  // 交易时间：9:30-11:30, 13:00-15:00
  final morning = (hour == 9 && minute >= 30) || 
                  (hour == 10) || 
                  (hour == 11 && minute <= 30);
  
  final afternoon = (hour == 13) || 
                    (hour == 14) || 
                    (hour == 15 && minute == 0);
  
  return morning || afternoon;
}

/// 后台价格监控服务
class BackgroundPriceMonitor {
  static const String _taskName = 'priceMonitoring';
  static const String _uniqueName = 'priceMonitorTask';
  
  /// 启动后台监控
  static Future<void> startMonitoring() async {
    try {
      debugPrint('[后台监控] 初始化WorkManager');
      
      // 初始化WorkManager
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: kDebugMode,
      );
      
      debugPrint('[后台监控] 注册周期性任务');
      
      // 注册周期性任务
      // Android系统限制：最短15分钟
      await Workmanager().registerPeriodicTask(
        _uniqueName,
        _taskName,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(
          networkType: NetworkType.connected, // 需要网络连接
        ),
      );
      
      debugPrint('[后台监控] 后台监控服务已启动');
    } catch (e) {
      debugPrint('[后台监控] 启动失败: $e');
      rethrow;
    }
  }
  
  /// 停止后台监控
  static Future<void> stopMonitoring() async {
    try {
      await Workmanager().cancelByUniqueName(_uniqueName);
      debugPrint('[后台监控] 后台监控服务已停止');
    } catch (e) {
      debugPrint('[后台监控] 停止失败: $e');
    }
  }
  
  /// 立即执行一次监控（用于测试）
  static Future<void> runOnce() async {
    try {
      debugPrint('[后台监控] 注册一次性任务');
      
      await Workmanager().registerOneOffTask(
        'priceMonitorOnce',
        _taskName,
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
      );
      
      debugPrint('[后台监控] 一次性任务已注册');
    } catch (e) {
      debugPrint('[后台监控] 注册一次性任务失败: $e');
    }
  }
  
  /// 取消所有后台任务
  static Future<void> cancelAll() async {
    try {
      await Workmanager().cancelAll();
      debugPrint('[后台监控] 所有后台任务已取消');
    } catch (e) {
      debugPrint('[后台监控] 取消任务失败: $e');
    }
  }
  
  /// 检查监控状态
  static Future<bool> isMonitoring() async {
    try {
      // WorkManager没有直接的API检查任务是否在运行
      // 我们可以通过SharedPreferences存储状态
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('background_monitoring_enabled') ?? false;
    } catch (e) {
      debugPrint('[后台监控] 检查状态失败: $e');
      return false;
    }
  }
  
  /// 设置监控状态
  static Future<void> setMonitoringStatus(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('background_monitoring_enabled', enabled);
    } catch (e) {
      debugPrint('[后台监控] 设置状态失败: $e');
    }
  }
  
  /// 手动触发价格检查（前台）
  static Future<void> checkPricesNow() async {
    try {
      debugPrint('[手动检查] 开始检查价格');
      
      // 1. 获取所有活跃的预警
      final activeAlerts = await PriceAlertService.getActiveAlerts();
      if (activeAlerts.isEmpty) {
        debugPrint('[手动检查] 没有活跃的预警');
        return;
      }
      
      // 2. 获取需要检查的股票代码列表
      final stockCodes = activeAlerts.map((alert) => alert.stockCode).toSet().toList();
      
      // 3. 批量获取股票价格
      final apiService = ApiService();
      final priceDataList = await apiService.getBatchStockPrices(stockCodes);
      
      // 4. 构建价格映射
      final stockPrices = <String, double>{};
      final changePercents = <String, double>{};
      
      for (final priceData in priceDataList) {
        final code = priceData['code']?.toString();
        final price = priceData['price'];
        final changePercent = priceData['change_percent'];
        
        if (code != null && price != null) {
          stockPrices[code] = double.tryParse(price.toString()) ?? 0;
          changePercents[code] = double.tryParse(changePercent?.toString() ?? '0') ?? 0;
        }
      }
      
      // 5. 检查并触发预警
      final triggeredAlerts = await PriceAlertService.batchCheckAlerts(stockPrices);
      
      if (triggeredAlerts.isEmpty) {
        debugPrint('[手动检查] 没有预警被触发');
        return;
      }
      
      debugPrint('[手动检查] ${triggeredAlerts.length} 只股票触发了预警');
      
      // 6. 发送通知
      await NotificationService.sendBatchAlertNotifications(
        triggeredAlerts,
        stockPrices,
        changePercents,
      );
      
      debugPrint('[手动检查] 检查完成');
    } catch (e) {
      debugPrint('[手动检查] 执行失败: $e');
      rethrow;
    }
  }
  
  /// 获取上次检查时间
  static Future<DateTime?> getLastCheckTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt('last_price_check_time');
      if (timestamp != null) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
      return null;
    } catch (e) {
      debugPrint('[后台监控] 获取上次检查时间失败: $e');
      return null;
    }
  }
  
  /// 更新上次检查时间
  static Future<void> updateLastCheckTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_price_check_time', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('[后台监控] 更新检查时间失败: $e');
    }
  }
}

