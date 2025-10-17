import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:io' show Platform;

class CustomWebView extends StatefulWidget {
  final String url;
  final String title;

  const CustomWebView({
    Key? key,
    required this.url,
    this.title = '网页浏览',
  }) : super(key: key);

  @override
  State<CustomWebView> createState() => _CustomWebViewState();
}

class _CustomWebViewState extends State<CustomWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _canGoBack = false;
  bool _isError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    try {
      // 创建控制器
      _controller = WebViewController();
      
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
              debugPrint('开始加载页面: $url');
            },
            onPageFinished: (String url) async {
              if (mounted) {
                bool canGoBack = false;
                try {
                  canGoBack = await _controller.canGoBack();
                } catch (e) {
                  debugPrint('检查返回状态出错: $e');
                }
                
                setState(() {
                  _isLoading = false;
                  _canGoBack = canGoBack;
                });
              }
              debugPrint('页面加载完成: $url');
            },
            onWebResourceError: (WebResourceError error) {
              if (mounted) {
                setState(() {
                  _isError = true;
                  _isLoading = false;
                  _errorMessage = '加载错误: ${error.description}';
                });
              }
              debugPrint('网页资源错误: ${error.description}');
            },
            onNavigationRequest: (NavigationRequest request) {
              debugPrint('导航请求: ${request.url}');
              return NavigationDecision.navigate;
            },
          ),
        );
      
      // 加载页面
      try {
        _controller.loadRequest(Uri.parse(widget.url));
      } catch (e) {
        debugPrint('加载URL出错: $e');
        setState(() {
          _isError = true;
          _errorMessage = '无法加载URL: ${widget.url}';
        });
      }
    } catch (e) {
      debugPrint('WebView初始化错误: $e');
      setState(() {
        _isError = true;
        _errorMessage = '初始化WebView失败: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 处理Windows平台 - WebView不支持
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.desktop_windows, size: 64, color: Colors.grey),
              const SizedBox(height: 20),
              const Text('桌面平台暂不支持WebView', 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text('无法加载页面: ${widget.url}', 
                style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('返回'),
              ),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: !_canGoBack,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        
        if (_canGoBack) {
          try {
            await _controller.goBack();
          } catch (e) {
            debugPrint('返回上一页出错: $e');
            Navigator.of(context).pop();
          }
        } else {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (_canGoBack) {
                try {
                  await _controller.goBack();
                } catch (e) {
                  debugPrint('返回上一页出错: $e');
                  Navigator.of(context).pop();
                }
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _controller.reload(),
            ),
          ],
        ),
        body: Stack(
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
          ],
        ),
        bottomNavigationBar: !_isError ? NavigationControls(controller: _controller) : null,
      ),
    );
  }
}

class NavigationControls extends StatelessWidget {
  final WebViewController controller;

  const NavigationControls({Key? key, required this.controller}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).primaryColor.withOpacity(0.1),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () async {
              try {
                if (await controller.canGoBack()) {
                  await controller.goBack();
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已经是第一页')),
                    );
                  }
                }
              } catch (e) {
                debugPrint('返回操作出错: $e');
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios),
            onPressed: () async {
              try {
                if (await controller.canGoForward()) {
                  await controller.goForward();
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已经是最后一页')),
                    );
                  }
                }
              } catch (e) {
                debugPrint('前进操作出错: $e');
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => controller.reload(),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
} 