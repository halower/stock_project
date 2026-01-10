import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'stock_chart_web_view.dart';
import 'dart:io' show Platform;

/// 大盘分析专用的横屏图表组件（无股票切换器）
class IndexLandscapeWidget extends StatefulWidget {
  final String url;
  final Widget? child;  // 可选的自定义内容
  final VoidCallback? onExitLandscape;

  const IndexLandscapeWidget({
    super.key,
    required this.url,
    this.child,
    this.onExitLandscape,
  });

  @override
  State<IndexLandscapeWidget> createState() => _IndexLandscapeWidgetState();
}

class _IndexLandscapeWidgetState extends State<IndexLandscapeWidget> {
  bool _isLandscape = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    // 退出时恢复竖屏
    if (_isLandscape) {
      _exitLandscape();
    }
    super.dispose();
  }

  void _toggleLandscape() {
    if (_isLandscape) {
      _exitLandscape();
    } else {
      _enterLandscape();
    }
  }

  void _enterLandscape() {
    setState(() {
      _isLandscape = true;
    });

    // 设置横屏
    if (Platform.isAndroid || Platform.isIOS) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      // 隐藏状态栏
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  void _exitLandscape() {
    setState(() {
      _isLandscape = false;
    });

    // 恢复竖屏
    if (Platform.isAndroid || Platform.isIOS) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      // 显示状态栏
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLandscape) {
      return _buildLandscapeView();
    } else {
      return _buildNormalView();
    }
  }

  Widget _buildNormalView() {
    return Stack(
      children: [
        // 大盘图表占满整个空间（使用自定义内容或默认WebView）
        widget.child ?? StockChartWebView(url: widget.url),
        
        // 横屏按钮悬浮在右上角
        Positioned(
          top: 8,
          right: 8,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _toggleLandscape,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.screen_rotation,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLandscapeView() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 全屏大盘图表（使用自定义内容或默认WebView）
          widget.child ?? StockChartWebView(url: widget.url),
          
          // 退出横屏按钮
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 10,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onExitLandscape ?? _toggleLandscape,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.screen_rotation,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

