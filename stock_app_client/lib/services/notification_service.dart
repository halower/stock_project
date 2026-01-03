import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/price_alert.dart';
import 'notification_settings_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// 通知渠道ID
  static const String _channelId = 'price_alerts_dynamic';
  static const String _channelName = '价格预警🔔📳';
  static const String _channelDescription = '股票价格触发预警时发送通知，包含声音和振动提醒';

  /// 初始化通知服务
  static Future<void> initialize() async {
    if (_initialized) {
      debugPrint('通知服务已初始化');
      return;
    }

    try {
      // Android初始化设置
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      
      // iOS初始化设置
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      
      // 初始化设置
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      // 初始化插件
      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // 创建Android通知渠道
      await _createNotificationChannel();

      _initialized = true;
      debugPrint('通知服务初始化成功');
    } catch (e) {
      debugPrint('通知服务初始化失败: $e');
      rethrow;
    }
  }

  /// 创建或更新Android通知渠道（根据当前设置）
  static Future<void> _createOrUpdateNotificationChannel({
    required bool soundEnabled,
    required bool vibrationEnabled,
  }) async {
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      // 删除所有旧的通知渠道
      final oldChannels = [
        'price_alerts',
        'price_alerts_v2',
        'price_alerts_sv',
        'price_alerts_s',
        'price_alerts_v',
        'price_alerts_',
        _channelId,
      ];
      
      for (final oldChannel in oldChannels) {
        try {
          await androidPlugin.deleteNotificationChannel(oldChannel);
          debugPrint('已删除旧渠道: $oldChannel');
        } catch (e) {
          // 忽略删除失败（渠道可能不存在）
        }
      }
      
      // 创建新的通知渠道，使用当前设置
      final androidChannel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: '$_channelDescription (声音:${soundEnabled ? "开" : "关"} 振动:${vibrationEnabled ? "开" : "关"})',
        importance: Importance.max,
        playSound: soundEnabled,
        enableVibration: vibrationEnabled,
        enableLights: true,
        ledColor: const Color(0xFF00FF00),
      );

      await androidPlugin.createNotificationChannel(androidChannel);
      debugPrint('✅ 通知渠道已创建: $_channelId (声音:$soundEnabled 振动:$vibrationEnabled)');
    }
  }
  
  /// 初始化时创建默认通知渠道
  static Future<void> _createNotificationChannel() async {
    // 使用默认设置创建渠道（都开启）
    await _createOrUpdateNotificationChannel(
      soundEnabled: true,
      vibrationEnabled: true,
    );
  }

  /// 请求通知权限
  static Future<bool> requestPermission() async {
    try {
      // Android 13+ 需要请求通知权限
      final status = await Permission.notification.request();
      
      if (status.isGranted) {
        debugPrint('通知权限已授予');
        return true;
      } else if (status.isDenied) {
        debugPrint('通知权限被拒绝');
        return false;
      } else if (status.isPermanentlyDenied) {
        debugPrint('通知权限被永久拒绝，需要打开设置');
        return false;
      }
      
      return false;
    } catch (e) {
      debugPrint('请求通知权限失败: $e');
      return false;
    }
  }

  /// 检查通知权限状态
  static Future<bool> checkPermission() async {
    try {
      final status = await Permission.notification.status;
      return status.isGranted;
    } catch (e) {
      debugPrint('检查通知权限失败: $e');
      return false;
    }
  }

  /// 打开系统设置页面
  static Future<void> openSettings() async {
    await openAppSettings();
  }

  /// 发送价格预警通知
  static Future<void> sendPriceAlertNotification(
    PriceAlert alert,
    double currentPrice,
    double changePercent,
  ) async {
    if (!_initialized) {
      debugPrint('通知服务未初始化，无法发送通知');
      return;
    }

    try {
      final hasPermission = await checkPermission();
      if (!hasPermission) {
        debugPrint('没有通知权限，无法发送通知');
        return;
      }

      // 获取通知设置
      final soundEnabled = await NotificationSettingsService.isSoundEnabled();
      final vibrationEnabled = await NotificationSettingsService.isVibrationEnabled();

      // 重新创建通知渠道以应用新的设置
      await _createOrUpdateNotificationChannel(
        soundEnabled: soundEnabled,
        vibrationEnabled: vibrationEnabled,
      );

      // 构建通知标题
      final title = '${alert.alertType.icon} 价格预警触发';
      
      // 构建通知内容
      final changeText = changePercent >= 0 
          ? '+${changePercent.toStringAsFixed(2)}%' 
          : '${changePercent.toStringAsFixed(2)}%';
      
      final content = '${alert.stockName}(${alert.stockCode})\n'
          '${alert.alertType.displayName}: ¥${alert.targetPrice.toStringAsFixed(2)}\n'
          '当前价格: ¥${currentPrice.toStringAsFixed(2)} ($changeText)';

      // Android通知详情（使用统一的渠道）
      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: '$_channelDescription (声音:${soundEnabled ? "开" : "关"} 振动:${vibrationEnabled ? "开" : "关"})',
        importance: Importance.max, // 使用最高优先级
        priority: Priority.max,
        playSound: soundEnabled, // 根据设置决定是否播放声音
        enableVibration: vibrationEnabled, // 根据设置决定是否振动
        // 自定义振动模式：更强烈的振动提醒
        vibrationPattern: vibrationEnabled 
            ? Int64List.fromList([0, 1000, 500, 1000, 500, 1000]) 
            : null,
        styleInformation: BigTextStyleInformation(content),
        ticker: '价格预警',
        // 全屏通知（在锁屏时显示）
        fullScreenIntent: true,
        // 通知LED灯
        enableLights: true,
        color: const Color(0xFF2196F3),
        ledColor: const Color(0xFF00FF00),
        ledOnMs: 1000,
        ledOffMs: 500,
      );

      // iOS通知详情
      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: soundEnabled, // 根据设置决定是否播放声音
        sound: soundEnabled ? 'default' : null,
        interruptionLevel: InterruptionLevel.timeSensitive, // 时间敏感通知
      );

      // 通知详情
      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // 发送通知
      await _notifications.show(
        alert.hashCode, // 使用alert的hashCode作为通知ID
        title,
        content,
        notificationDetails,
        payload: 'price_alert:${alert.stockCode}', // 携带股票代码
      );

      debugPrint('发送价格预警通知: ${alert.stockName}(${alert.stockCode}) [声音:$soundEnabled, 振动:$vibrationEnabled]');
    } catch (e) {
      debugPrint('发送通知失败: $e');
    }
  }

  /// 批量发送预警通知
  static Future<void> sendBatchAlertNotifications(
    Map<String, List<PriceAlert>> triggeredAlerts,
    Map<String, double> currentPrices,
    Map<String, double> changePercents,
  ) async {
    for (final entry in triggeredAlerts.entries) {
      final stockCode = entry.key;
      final alerts = entry.value;
      final currentPrice = currentPrices[stockCode] ?? 0;
      final changePercent = changePercents[stockCode] ?? 0;

      for (final alert in alerts) {
        await sendPriceAlertNotification(alert, currentPrice, changePercent);
        // 避免发送过快
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  /// 发送测试通知
  static Future<void> sendTestNotification() async {
    debugPrint('=== 开始发送测试通知 ===');
    
    if (!_initialized) {
      debugPrint('通知服务未初始化，正在初始化...');
      await initialize();
    }

    try {
      // 检查权限
      final hasPermission = await checkPermission();
      debugPrint('通知权限状态: $hasPermission');
      
      if (!hasPermission) {
        debugPrint('没有通知权限，尝试请求权限...');
        final granted = await requestPermission();
        debugPrint('权限请求结果: $granted');
        
        if (!granted) {
          debugPrint('通知权限被拒绝，无法发送通知');
          return;
        }
      }

      // 获取通知设置
      final soundEnabled = await NotificationSettingsService.isSoundEnabled();
      final vibrationEnabled = await NotificationSettingsService.isVibrationEnabled();
      debugPrint('通知设置 - 声音: $soundEnabled, 振动: $vibrationEnabled');

      // 重新创建通知渠道以应用新的设置
      await _createOrUpdateNotificationChannel(
        soundEnabled: soundEnabled,
        vibrationEnabled: vibrationEnabled,
      );

      // 使用统一的渠道配置
      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: '$_channelDescription (声音:${soundEnabled ? "开" : "关"} 振动:${vibrationEnabled ? "开" : "关"})',
        importance: Importance.max,
        priority: Priority.max,
        playSound: soundEnabled,
        enableVibration: vibrationEnabled,
        // 自定义振动模式：振动-停止-振动-停止（更明显）
        vibrationPattern: vibrationEnabled 
            ? Int64List.fromList([0, 1000, 500, 1000, 500, 1000]) 
            : null,
        enableLights: true,
        color: const Color(0xFF2196F3),
        ledColor: const Color(0xFF00FF00),
        ledOnMs: 1000,
        ledOffMs: 500,
        // 显示大文本
        styleInformation: const BigTextStyleInformation(
          '这是一条测试通知，如果您看到这条消息并听到声音/感受到振动，说明通知功能正常工作。',
          htmlFormatBigText: true,
          contentTitle: '🔔 测试通知',
          htmlFormatContentTitle: true,
        ),
      );

      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: soundEnabled,
        sound: soundEnabled ? 'default' : null,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      debugPrint('准备发送通知 (声音:$soundEnabled 振动:$vibrationEnabled)...');
      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch % 100000, // 使用时间戳作为ID
        '🔔 测试通知',
        '这是一条测试通知，如果您看到这条消息，说明通知功能正常工作。\n声音: ${soundEnabled ? "✅开启" : "❌关闭"} | 振动: ${vibrationEnabled ? "✅开启" : "❌关闭"}',
        notificationDetails,
      );

      debugPrint('✅ 测试通知发送成功！(渠道:$_channelId)');
    } catch (e, stackTrace) {
      debugPrint('❌ 发送测试通知失败: $e');
      debugPrint('堆栈跟踪: $stackTrace');
    }
  }

  /// 取消所有通知
  static Future<void> cancelAllNotifications() async {
    try {
      await _notifications.cancelAll();
      debugPrint('取消所有通知成功');
    } catch (e) {
      debugPrint('取消通知失败: $e');
    }
  }

  /// 取消特定通知
  static Future<void> cancelNotification(int id) async {
    try {
      await _notifications.cancel(id);
      debugPrint('取消通知成功: $id');
    } catch (e) {
      debugPrint('取消通知失败: $e');
    }
  }

  /// 通知点击回调
  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint('通知被点击: ${response.payload}');
    
    // 解析payload
    if (response.payload != null && response.payload!.startsWith('price_alert:')) {
      final stockCode = response.payload!.replaceFirst('price_alert:', '');
      debugPrint('跳转到股票详情: $stockCode');
      
      // TODO: 这里可以通过导航服务跳转到备选池或股票详情页
      // 需要在main.dart中设置全局导航key
    }
  }

  /// 获取待处理的通知数量
  static Future<int> getPendingNotificationCount() async {
    try {
      final pendingNotifications = await _notifications.pendingNotificationRequests();
      return pendingNotifications.length;
    } catch (e) {
      debugPrint('获取待处理通知数量失败: $e');
      return 0;
    }
  }

  /// 获取活跃的通知数量
  static Future<int> getActiveNotificationCount() async {
    try {
      final activeNotifications = await _notifications.getActiveNotifications();
      return activeNotifications.length;
    } catch (e) {
      debugPrint('获取活跃通知数量失败: $e');
      return 0;
    }
  }
}

