import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:io' show Platform;
import 'dart:convert' show utf8;
// 导入API服务
import '../config/api_config.dart'; // 导入配置
import '../services/http_client.dart'; // 导入自定义HttpClient

// 本地常量
const String strategyVolumeWave = 'volume_wave';

class StockChartScreen extends StatefulWidget {
  final String stockCode;
  final String stockName;
  final String strategy; // 添加策略参数

  const StockChartScreen({
    Key? key,
    required this.stockCode,
    required this.stockName,
    this.strategy = '', // 默认为空，将使用默认策略
  }) : super(key: key);

  @override
  State<StockChartScreen> createState() => _StockChartScreenState();
}

class _StockChartScreenState extends State<StockChartScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isError = false;
  String _errorMessage = '';
  
  // 图表URL - 使用API服务的chartBaseUrl和策略参数
  late final String _chartUrl;

  @override
  void initState() {
    super.initState();
    
    // 确定要使用的策略参数
    final String strategyParam = widget.strategy.isNotEmpty ? 
        widget.strategy : strategyVolumeWave;
    
    // 获取当前主题
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // 构建图表URL，包含策略参数和主题
    _chartUrl = ApiConfig.getStockChartWithStrategyUrl(widget.stockCode, strategyParam, isDarkMode: isDarkMode);
    
    _initWebView();
    // 添加调试输出
    debugPrint('StockChartScreen 初始化完成，chartUrl=$_chartUrl');
  }

  void _initWebView() {
    try {
      // 创建控制器
      _controller = WebViewController();
      debugPrint('WebViewController 创建成功');
      
      // 基本配置
      _controller
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0x00000000))
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              if (mounted) {
                setState(() {
                  _isLoading = true;
                  _isError = false;
                });
              }
              debugPrint('开始加载K线图表: $url');
            },
            onPageFinished: (String url) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
              }
              debugPrint('K线图表加载完成: $url');
            },
            onWebResourceError: (WebResourceError error) {
              if (mounted) {
                setState(() {
                  _isError = true;
                  _isLoading = false;
                  _errorMessage = '加载K线图表错误: ${error.description}';
                });
              }
              debugPrint('K线图表加载错误: ${error.description}');
            },
          ),
        );
      
      // 加载页面
      try {
        debugPrint('准备加载K线图表: $_chartUrl');
        
        // 使用HttpClient发送请求，确保包含API令牌
        _loadChartWithAuth();
      } catch (e) {
        debugPrint('加载K线图表URL出错: $e');
        setState(() {
          _isError = true;
          _errorMessage = '无法加载K线图表: $_chartUrl, 错误: $e';
        });
      }
    } catch (e) {
      debugPrint('K线图表WebView初始化错误: $e');
      setState(() {
        _isError = true;
        _errorMessage = '初始化K线图表失败: $e';
      });
    }
  }
  
  // 使用HttpClient加载图表，确保包含API令牌
  Future<void> _loadChartWithAuth() async {
    try {
      // 使用HttpClient发送请求，自动添加API令牌
      final response = await HttpClient.get(_chartUrl);
      
      if (response.statusCode == 200) {
        // 获取响应HTML内容
        final htmlContent = utf8.decode(response.bodyBytes);
        debugPrint('成功获取图表HTML内容，长度: ${htmlContent.length}');
        
        // 加载HTML内容
        _controller.loadHtmlString(htmlContent, baseUrl: Uri.parse(_chartUrl).origin);
      } else {
        debugPrint('获取图表内容失败: ${response.statusCode}, ${response.reasonPhrase}');
        setState(() {
          _isError = true;
          _errorMessage = '获取图表内容失败，服务器返回: ${response.statusCode}';
        });
      }
    } catch (e) {
      debugPrint('请求图表内容出错: $e');
      setState(() {
        _isError = true;
        _errorMessage = '获取图表内容出错: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 直接显示WebView，去掉AppBar
    return Scaffold(
      // 移除AppBar，直接显示WebView内容
      body: _buildBody(),
    );
  }
  
  Widget _buildBody() {
    // 处理Windows平台 - WebView不支持
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.desktop_windows, size: 64, color: Colors.grey),
            const SizedBox(height: 20),
            const Text('桌面平台暂不支持WebView', 
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text('无法加载K线图表: $_chartUrl', 
              style: TextStyle(color: Colors.grey[600])),
            // 添加返回按钮
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('返回'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        if (_isError)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 20),
                Text(_errorMessage, 
                  style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isError = false;
                      _isLoading = true;
                    });
                    _controller.reload();
                  },
                  child: const Text('重试'),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('返回'),
                ),
              ],
            ),
          )
        else
          WebViewWidget(controller: _controller),
          
        if (_isLoading && !_isError)
          Container(
            color: Colors.white70,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
          
        // 添加一个返回按钮覆盖在WebView上
        Positioned(
          top: 40,
          left: 10,
          child: SafeArea(
            child: FloatingActionButton.small(
              backgroundColor: Colors.white.withOpacity(0.7),
              foregroundColor: Colors.black,
              onPressed: () => Navigator.pop(context),
              child: const Icon(Icons.arrow_back),
            ),
          ),
        ),
      ],
    );
  }
} 