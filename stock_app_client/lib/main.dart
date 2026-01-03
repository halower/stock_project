import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io' show Platform;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/login_screen.dart';
import 'screens/ai_settings_screen.dart';
import 'services/providers/trade_provider.dart';
import 'services/providers/strategy_provider.dart';
import 'services/providers/stock_provider.dart';
import 'services/providers/theme_provider.dart';
import 'services/providers/api_provider.dart';
import 'services/database_service.dart';
import 'services/stock_service.dart';
import 'services/trade_service.dart';
import 'services/notification_service.dart';
import 'services/background_price_monitor.dart';
import 'widgets/password_lock_wrapper.dart';
// 导入WebView平台相关包
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化WebView平台
  initWebViewPlatform();
  
  // 初始化通知服务
  try {
    debugPrint('初始化通知服务...');
    await NotificationService.initialize();
    debugPrint('通知服务初始化成功');
    
    // 请求通知权限（仅Android）
    if (Platform.isAndroid) {
      final hasPermission = await NotificationService.requestPermission();
      debugPrint('通知权限: ${hasPermission ? "已授予" : "未授予"}');
    }
  } catch (e) {
    debugPrint('通知服务初始化失败: $e');
  }
  
  // 启动后台监控服务（仅Android）
  try {
    if (Platform.isAndroid) {
      debugPrint('启动后台价格监控服务...');
      await BackgroundPriceMonitor.startMonitoring();
      await BackgroundPriceMonitor.setMonitoringStatus(true);
      debugPrint('后台监控服务已启动');
    }
  } catch (e) {
    debugPrint('后台监控服务启动失败: $e');
  }
  
  // 根据平台选择适当的数据库实现
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    // 在桌面平台使用FFI
    debugPrint('在桌面平台 ${Platform.operatingSystem} 使用FFI数据库');
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  } else {
    debugPrint('在移动平台 ${Platform.operatingSystem} 使用标准数据库');
  }
  
  try {
    final databaseService = DatabaseService();
    final database = await databaseService.database;
    final stockService = StockService(database);
    final tradeService = TradeService(databaseService);
    
    // 预先初始化主题
    final themeProvider = ThemeProvider();
    // 初始化API提供者
    final apiProvider = ApiProvider();
    
    // 在应用启动时预加载策略数据
    debugPrint('应用启动：开始预加载策略数据...');
    try {
      // 这里不等待结果，让策略在后台加载
      apiProvider.initializeStrategies();
      debugPrint('策略数据预加载已启动');
    } catch (e) {
      debugPrint('策略数据预加载失败: $e');
    }
    
    runApp(
      MultiProvider(
        providers: [
          Provider<DatabaseService>.value(value: databaseService),
          Provider<StockService>.value(value: stockService),
          Provider<TradeService>.value(value: tradeService),
          ChangeNotifierProvider(create: (_) => TradeProvider(databaseService)),
          ChangeNotifierProvider(create: (_) => StrategyProvider(databaseService)),
          ChangeNotifierProvider(create: (_) => StockProvider(databaseService, stockService)),
          ChangeNotifierProvider.value(value: themeProvider), // 使用预初始化的ThemeProvider
          ChangeNotifierProvider.value(value: apiProvider), // 添加API Provider
        ],
        child: const MyApp(),
      ),
    );
  } catch (e) {
    debugPrint('应用初始化错误: $e');
    // 错误恢复启动
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => ApiProvider()),
        ],
        child: const MyApp(),
      ),
    );
  }
}

// 初始化WebView平台
void initWebViewPlatform() {
  try {
    // 根据平台配置WebView
    if (Platform.isAndroid) {
      debugPrint('初始化Android WebView');
      WebViewPlatform.instance = AndroidWebViewPlatform();
    } else if (Platform.isIOS) {
      debugPrint('初始化iOS WebView');
      WebViewPlatform.instance = WebKitWebViewPlatform();
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      debugPrint('当前平台 ${Platform.operatingSystem} 暂不支持内置WebView，将使用系统浏览器');
      // 对于桌面平台，我们不初始化WebView，而是在需要时使用url_launcher
      // 这样可以避免WebView初始化错误
    } else {
      debugPrint('当前平台 ${Platform.operatingSystem} 不支持WebView');
    }
  } catch (e) {
    debugPrint('WebView平台初始化失败: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    // 初始化API数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ApiProvider>().initialize();
    });
    
    return MaterialApp(
      title: '交易大陆',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.themeData,
      darkTheme: themeProvider.themeData, // 确保暗黑模式也使用我们的主题
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light, // 显式设置主题模式
      // 添加中文本地化支持
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'), // 中文（中国）
        Locale('en', 'US'), // 英文（美国）
      ],
      locale: const Locale('zh', 'CN'), // 默认中文
      routes: {
        '/ai_settings': (context) => const AISettingsScreen(),
      },
      home: const PasswordLockWrapper(
        child: LoginScreen(), 
      ),
    );
  }
}
