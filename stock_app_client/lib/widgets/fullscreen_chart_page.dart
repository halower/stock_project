import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:io' show Platform;

/// 全屏横屏图表页面
/// 专门用于横屏全屏查看图表，独立于原页面，不会干扰WebView交互
class FullscreenChartPage extends StatefulWidget {
  final String chartUrl;
  final String title;

  const FullscreenChartPage({
    super.key,
    required this.chartUrl,
    this.title = '图表详情',
  });

  @override
  State<FullscreenChartPage> createState() => _FullscreenChartPageState();
}

class _FullscreenChartPageState extends State<FullscreenChartPage> {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _isError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _enterLandscape();
    _initWebView();
  }

  @override
  void dispose() {
    _exitLandscape();
    super.dispose();
  }

  /// 进入横屏模式
  void _enterLandscape() {
    if (Platform.isAndroid || Platform.isIOS) {
      // 设置横屏
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      // 全屏沉浸模式
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  /// 退出横屏模式
  void _exitLandscape() {
    if (Platform.isAndroid || Platform.isIOS) {
      // 恢复竖屏
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      // 恢复系统UI
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  /// 初始化WebView
  Future<void> _initWebView() async {
    try {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.black)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (url) {
              if (mounted) {
                setState(() {
                  _isLoading = true;
                  _isError = false;
                });
              }
            },
            onPageFinished: (url) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
              }
            },
            onWebResourceError: (error) {
              debugPrint('WebView加载错误: ${error.description}');
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _isError = true;
                  _errorMessage = '加载失败: ${error.description}';
                });
              }
            },
          ),
        );

      if (mounted) {
        setState(() {
          _controller = controller;
        });
      }

      // 加载图表
      controller.loadRequest(Uri.parse(widget.chartUrl));
    } catch (e) {
      debugPrint('初始化WebView失败: $e');
      if (mounted) {
        setState(() {
          _isError = true;
          _errorMessage = '初始化失败: $e';
        });
      }
    }
  }

  /// 重新加载图表
  void _reloadChart() {
    setState(() {
      _isLoading = true;
      _isError = false;
    });
    _controller?.loadRequest(Uri.parse(widget.chartUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // WebView图表
          if (_controller != null)
            WebViewWidget(controller: _controller!),

          // 加载指示器
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 16),
                    Text(
                      '加载图表中...',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),

          // 错误提示
          if (_isError)
            Container(
              color: Colors.black.withOpacity(0.8),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _reloadChart,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('重新加载'),
                    ),
                  ],
                ),
              ),
            ),

          // 底部工具栏（不遮挡图表顶部的分析工具按钮）
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildToolbar(),
          ),
        ],
      ),
    );
  }

  /// 构建底部工具栏
  Widget _buildToolbar() {
    return Container(
      padding: EdgeInsets.only(
        top: 8,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.black.withOpacity(0.0),
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 返回按钮
          _buildToolButton(
            icon: Icons.arrow_back,
            label: '返回竖屏',
            onTap: () => Navigator.of(context).pop(),
          ),
          
          // 标题
          Expanded(
            child: Text(
              widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          // 刷新按钮
          _buildToolButton(
            icon: Icons.refresh,
            label: '刷新',
            onTap: _reloadChart,
          ),
        ],
      ),
    );
  }
  
  /// 构建工具按钮（带文字）
  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 打开全屏横屏图表页面的便捷方法
Future<void> openFullscreenChart(
  BuildContext context, {
  required String chartUrl,
  String title = '图表详情',
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => FullscreenChartPage(
        chartUrl: chartUrl,
        title: title,
      ),
    ),
  );
}

