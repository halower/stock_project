import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:io' show Platform;
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui' as ui;

class StockChartWebView extends StatefulWidget {
  final String url;
  final Function(WebViewController)? onWebViewCreated;

  const StockChartWebView({
    Key? key,
    required this.url,
    this.onWebViewCreated,
  }) : super(key: key);

  @override
  State<StockChartWebView> createState() => _StockChartWebViewState();
}

class _StockChartWebViewState extends State<StockChartWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isError = false;
  String _errorMessage = '';
  
  // 修改为非late变量，提供默认值
  String _interactiveUrl = '';

  @override
  void initState() {
    super.initState();
    // 创建交互式页面URL - 确保在任何平台都初始化
    _interactiveUrl = _createInteractiveUrl(widget.url);
    debugPrint('StockChartWebView初始化，URL: ${widget.url}');
    debugPrint('交互式页面URL: $_interactiveUrl');
    
    // 只在移动平台初始化WebView
    if (!_isDesktop()) {
      _initWebView();
    }
  }
  
  // 创建包装交互式图表的URL
  String _createInteractiveUrl(String originalUrl) {
    // 创建一个更简单的HTML模板，包含交互式图表
    final String simpleHtmlTemplate = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=5.0, user-scalable=yes">
  <style>
    body {
      margin: 0;
      padding: 0;
      overflow: auto;
      touch-action: manipulation;
      -webkit-overflow-scrolling: touch;
    }
    iframe {
      width: 100%;
      height: 100vh;
      border: none;
    }
    .zoom-controls {
      position: fixed;
      bottom: 20px;
      right: 20px;
      display: flex;
      flex-direction: column;
      z-index: 9999;
    }
    .zoom-btn {
      width: 40px;
      height: 40px;
      margin: 5px;
      background: rgba(255, 255, 255, 0.8);
      border: 1px solid #ccc;
      border-radius: 50%;
      font-size: 24px;
      display: flex;
      align-items: center;
      justify-content: center;
      box-shadow: 0 2px 5px rgba(0,0,0,0.2);
    }
  </style>
</head>
<body>
  <iframe id="chartFrame" src="$originalUrl" allowfullscreen></iframe>
</body>
</html>
''';

    return 'data:text/html;charset=utf-8,${Uri.encodeComponent(simpleHtmlTemplate)}';
  }

  // 辅助方法：检查是否是桌面平台
  bool _isDesktop() {
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  void _initWebView() {
    try {
      // 创建控制器并进行配置
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0x00000000))
        // 设置手势
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              if (mounted) {
                setState(() {
                  _isLoading = true;
                  _isError = false;
                });
              }
              debugPrint('开始加载K线图: $url');
            },
            onPageFinished: (String url) async {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
              }
              debugPrint('K线图加载完成: $url');
              
              // 页面加载完成后，启用缩放功能和注入额外的JavaScript
              await _controller.enableZoom(true);
              _addAdditionalInteractivity();
            },
            onWebResourceError: (WebResourceError error) {
              if (mounted) {
                setState(() {
                  _isError = true;
                  _isLoading = false;
                  _errorMessage = '加载K线图错误: ${error.description}';
                });
              }
              debugPrint('K线图加载错误: ${error.description}');
            },
          ),
        );
      
      // 加载交互式页面，而不是直接加载原始URL
      try {
        if (_interactiveUrl.isEmpty) {
          throw Exception('交互式页面URL为空');
        }
        
        final uri = Uri.parse(_interactiveUrl);
        debugPrint('加载交互式图表页面: $_interactiveUrl');
        
        // 启用缩放，然后加载页面
        _controller.enableZoom(true).then((_) {
          _controller.loadRequest(uri);
          
          // 调用回调，传递控制器
          if (widget.onWebViewCreated != null) {
            widget.onWebViewCreated!(_controller);
          }
        });
      } catch (e) {
        debugPrint('加载K线图URL出错: $e');
        setState(() {
          _isError = true;
          _errorMessage = '无法加载K线图: ${widget.url}, 错误: $e';
        });
        
        // 如果出错，仍然尝试调用回调传递控制器
        if (widget.onWebViewCreated != null) {
          widget.onWebViewCreated!(_controller);
        }
      }
    } catch (e) {
      debugPrint('K线图WebView初始化错误: $e');
      setState(() {
        _isError = true;
        _errorMessage = '初始化K线图失败: $e';
      });
    }
  }
  
  // 添加额外的交互性，确保WebView可以正常接收手势
  Future<void> _addAdditionalInteractivity() async {
    try {
      // 注入JavaScript以增强缩放体验
      await _controller.runJavaScript('''
        // 确保页面接收所有手势
        document.body.style.touchAction = "manipulation";
        
        // 禁用默认的双击放大行为，我们将自己实现
        document.documentElement.addEventListener('dblclick', function(e) {
          e.preventDefault();
          console.log('双击事件已捕获');
        });
        
        // 修复可能的触摸事件问题
        document.addEventListener('touchmove', function(e) {
          // 允许多点触控的触摸事件传递
          if (e.touches.length > 1) {
            e.stopPropagation();
          }
        }, { passive: false });
      ''');
      
      debugPrint('成功注入额外的交互性JavaScript');
    } catch (e) {
      debugPrint('注入JavaScript错误: $e');
    }
  }
  
  // 在系统浏览器中打开URL
  Future<void> _openInBrowser() async {
    try {
      final uri = Uri.parse(widget.url);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法打开浏览器')),
        );
      }
    } catch (e) {
      debugPrint('打开浏览器出错: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('打开浏览器出错: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 处理桌面平台 - 提供浏览器打开选项
    if (_isDesktop()) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.open_in_browser, size: 50, color: Colors.blue),
            const SizedBox(height: 16),
            const Text(
              'Windows系统下使用外部浏览器显示K线图', 
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.launch),
              label: const Text('在浏览器中查看K线图'),
              onPressed: _openInBrowser,
            ),
          ],
        ),
      );
    }

    // 使用GestureDetector包装WebView，确保手势可以被正确处理
    return GestureDetector(
      // 禁用部分原生手势，避免与WebView内部的手势冲突
      onDoubleTap: null, // 禁用双击，让WebView内部处理
      child: Stack(
        children: [
          if (_isError)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 50, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(_errorMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
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
                ],
              ),
            )
          else
            WebViewWidget(
              controller: _controller,
              // 不使用gestureRecognizers，简化实现
            ),
            
          if (_isLoading && !_isError)
            Container(
              color: Colors.white70,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
            

        ],
      ),
    );
  }
} 