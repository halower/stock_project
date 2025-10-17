import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/api_service.dart';

import '../services/ai_config_service.dart';
import 'dart:convert';
import 'dart:math' as math;
import './news_web_view_screen.dart';

class NewsAnalysisScreen extends StatefulWidget {
  const NewsAnalysisScreen({Key? key}) : super(key: key);

  @override
  _NewsAnalysisScreenState createState() => _NewsAnalysisScreenState();
}

class _NewsAnalysisScreenState extends State<NewsAnalysisScreen> with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  String _analysisResult = '';
  String _errorMessage = '';
  List<Map<String, dynamic>> _latestNews = [];
  bool _isLoadingNews = false;
  
  // 动画控制器
  late AnimationController _animationController;
  
  // Tab控制器
  late TabController _tabController;

  bool _forceRefresh = false;

  @override
  void initState() {
    super.initState();
    
    // 初始化动画控制器
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    
    // 初始化Tab控制器
    _tabController = TabController(length: 2, vsync: this);
    
    // 添加Tab切换监听器
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        // 当切换到"消息面AI解读"Tab时（索引为1），才加载AI分析
        if (_tabController.index == 1) {
          if (_analysisResult.isEmpty && !_isLoading && _errorMessage.isEmpty) {
            debugPrint('用户切换到消息面AI解读Tab，开始加载AI分析');
            _loadAnalysisReport();
          }
        }
      }
    });
    
    // 只在初始化时加载最新财经资讯，不加载AI分析
    _loadLatestNews();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalysisReport() async {
    try {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      // 获取AI配置参数
      final effectiveApiKey = await AIConfigService.getEffectiveApiKey();
      final effectiveUrl = await AIConfigService.getEffectiveUrl();
      final effectiveModel = await AIConfigService.getEffectiveModel();

      // 确保有有效的AI配置
      if (effectiveApiKey == null || effectiveApiKey.isEmpty ||
          effectiveUrl == null || effectiveUrl.isEmpty) {
        setState(() {
          _errorMessage = '未配置完整的AI服务参数，请在AI模型设置中配置';
          _isLoading = false;
        });
        return;
      }

      // 调用API获取分析报告
      final result = await _apiService.getNewsAnalysis(
        aiModelName: effectiveModel ?? 'deepseek-ai/DeepSeek-R1-Distill-Qwen-7B',
        aiEndpoint: effectiveUrl,
        aiApiKey: effectiveApiKey,
        forceRefresh: _forceRefresh,
      );
      
      // 重置强制刷新标志
      _forceRefresh = false;

      // 打印返回的完整数据结构用于调试
      debugPrint('消息面分析响应数据: ${json.encode(result)}');

      if (!mounted) return;
      
      if (result['success'] == false || result['status'] == 'error') {
        setState(() {
          _errorMessage = result['message'] ?? '获取分析报告失败';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        // 正确访问嵌套的data.analysis字段
        if (result.containsKey('data') && result['data'] is Map<String, dynamic>) {
          _analysisResult = result['data']['analysis'] ?? '分析报告内容为空';
          debugPrint('已获取分析结果，长度: ${_analysisResult.length}');
        } else {
          // 兼容可能的其他格式
          _analysisResult = result['analysis'] ?? '分析报告内容为空';
          debugPrint('使用备选字段获取分析结果，长度: ${_analysisResult.length}');
        }
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('获取消息面分析报告出错: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = '发生错误: $e';
        _isLoading = false;
      });
    }
  }
  
  // 加载最新财经资讯
  Future<void> _loadLatestNews() async {
    try {
      if (!mounted) return;
      setState(() {
        _isLoadingNews = true;
      });
      
      final newsList = await _apiService.getLatestFinanceNews();
      
      if (!mounted) return;
      setState(() {
        _latestNews = newsList;
        _isLoadingNews = false;
      });
    } catch (e) {
      debugPrint('加载最新财经资讯出错: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingNews = false;
      });
    }
  }
  
  // 打开新闻链接
  Future<void> _openNewsUrl(String url) async {
    try {
      // 使用应用内导航，而不是外部浏览器
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => NewsWebViewScreen(url: url, title: '财经资讯'),
        ),
      );
    } catch (e) {
      debugPrint('打开链接出错: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('消息面量化分析'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : () {
              // 清除缓存并重新加载
              _apiService.clearNewsAnalysisCache();
              setState(() {
                _forceRefresh = true;
              });
              _loadAnalysisReport();
              _loadLatestNews();
            },
            tooltip: '刷新数据',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              text: '最新财经资讯',
              icon: Icon(Icons.newspaper),
            ),
            Tab(
              text: '消息面AI解读',
              icon: Icon(Icons.analytics),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 最新财经资讯
          _isLoadingNews
              ? const Center(child: CircularProgressIndicator())
              : _latestNews.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('暂无最新财经资讯'),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _loadLatestNews,
                            child: const Text('刷新'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _latestNews.length,
                      itemBuilder: (context, index) {
                        final news = _latestNews[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: ListTile(
                            title: Text(
                              news['title'] ?? '无标题',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (news['source'] != null || news['datetime'] != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      '${news['source'] ?? ''} · ${news['datetime'] ?? ''}',
                                      style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12),
                                    ),
                                  ),
                                if (news['summary'] != null && news['summary'].toString().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      news['summary'] ?? '',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                            ),
                            onTap: () {
                              if (news['url'] != null) {
                                _openNewsUrl(news['url']);
                              }
                            },
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          ),
                        );
                      },
                    ),
          
          // 消息面分析内容
          _isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 200,
                        height: 200,
                        child: CustomPaint(
                          painter: SpiderWebPainter(
                            animation: _animationController,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            color: Colors.blue.shade600,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'AI正在智能分析市场消息...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '正在整合多源数据，生成专业分析报告',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              : _errorMessage.isNotEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red.shade400,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              _apiService.clearNewsAnalysisCache();
                              setState(() {
                                _forceRefresh = true;
                              });
                              _loadAnalysisReport();
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('重新加载'),
                          ),
                        ],
                      ),
                    )
                  : _analysisResult.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.analytics_outlined,
                                size: 48,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                '暂无分析结果',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Markdown(
                          data: _analysisResult,
                          selectable: true,
                        ),
        ],
      ),
    );
  }
}

// 蜘蛛网加载效果绘制器
class SpiderWebPainter extends CustomPainter {
  final Animation<double> animation;
  
  SpiderWebPainter({required this.animation}) : super(repaint: animation);
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    
    // 绘制蜘蛛网同心圆
    for (int i = 1; i <= 5; i++) {
      final currentRadius = radius * i / 5;
      canvas.drawCircle(center, currentRadius, paint);
    }
    
    // 绘制蜘蛛网辐射线
    for (int i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final dx = radius * math.cos(angle);
      final dy = radius * math.sin(angle);
      canvas.drawLine(center, center + Offset(dx, dy), paint);
    }
    
    // 绘制蜘蛛网上的蜘蛛
    final spiderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    
    // 蜘蛛的位置随动画变化
    final animValue = animation.value;
    final spiderAngle = animValue * 2 * math.pi;
    final webPosition = 0.3 + 0.6 * animValue; // 在30%-90%的半径范围内移动
    
    final spiderX = center.dx + radius * webPosition * math.cos(spiderAngle);
    final spiderY = center.dy + radius * webPosition * math.sin(spiderAngle);
    final spiderPosition = Offset(spiderX, spiderY);
    
    // 绘制蜘蛛身体
    canvas.drawCircle(spiderPosition, 8, spiderPaint);
    
    // 绘制蜘蛛腿
    for (int i = 0; i < 8; i++) {
      final legAngle = i * math.pi / 4 + animValue * math.pi / 2;
      const legLength = 12.0;
      final legEndX = spiderPosition.dx + legLength * math.cos(legAngle);
      final legEndY = spiderPosition.dy + legLength * math.sin(legAngle);
      canvas.drawLine(spiderPosition, Offset(legEndX, legEndY), 
          Paint()..color = Colors.black..strokeWidth = 1.5);
    }
    
    // 绘制蜘蛛的丝
    final thread = Path();
    thread.moveTo(center.dx, center.dy);
    
    // 蜘蛛丝随机波动
    final cp1x = center.dx + (spiderPosition.dx - center.dx) * 0.3 + math.sin(animValue * 6) * 10;
    final cp1y = center.dy + (spiderPosition.dy - center.dy) * 0.3 + math.cos(animValue * 5) * 10;
    final cp2x = center.dx + (spiderPosition.dx - center.dx) * 0.7 + math.sin(animValue * 4) * 10;
    final cp2y = center.dy + (spiderPosition.dy - center.dy) * 0.7 + math.cos(animValue * 7) * 10;
    
    thread.cubicTo(cp1x, cp1y, cp2x, cp2y, spiderPosition.dx, spiderPosition.dy);
    
    canvas.drawPath(thread, Paint()
      ..color = Colors.grey
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8);
  }
  
  @override
  bool shouldRepaint(covariant SpiderWebPainter oldDelegate) {
    return true;
  }
} 