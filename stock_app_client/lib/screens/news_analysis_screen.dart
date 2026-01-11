import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/api_service.dart';
import '../services/ai_config_service.dart';
import '../widgets/shimmer_loading.dart';
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
  bool _dataLoaded = false;  // ✅ 懒加载标志
  
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
    
    // ❌ 不要立即加载新闻
    // _loadLatestNews();
    
    // ✅ 懒加载：切换到此Tab时才加载
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_dataLoaded && mounted) {
        _dataLoaded = true;
        debugPrint('🔄 消息量化Tab：首次加载数据...');
        _loadLatestNews();
      }
    });
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
        String rawAnalysis = '';
        if (result.containsKey('data') && result['data'] is Map<String, dynamic>) {
          rawAnalysis = result['data']['analysis'] ?? '分析报告内容为空';
          debugPrint('已获取分析结果，长度: ${rawAnalysis.length}');
        } else {
          // 兼容可能的其他格式
          rawAnalysis = result['analysis'] ?? '分析报告内容为空';
          debugPrint('使用备选字段获取分析结果，长度: ${rawAnalysis.length}');
        }
        
        // ✅ 清理思考过程标签和多余内容
        _analysisResult = _cleanAnalysisContent(rawAnalysis);
        debugPrint('清理后分析结果长度: ${_analysisResult.length}');
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
  
  // 清理AI分析内容，彻底移除所有思考过程
  String _cleanAnalysisContent(String rawContent) {
    if (rawContent.isEmpty) return rawContent;
    
    String cleaned = rawContent;
    
    // 1. 移除 <think>...</think> 标签及其内容（最常见格式）
    cleaned = cleaned.replaceAll(RegExp(r'<think>.*?</think>', caseSensitive: false, dotAll: true), '');
    
    // 2. 移除单独的 </think> 或 <think> 标签
    cleaned = cleaned.replaceAll(RegExp(r'</?think>?', caseSensitive: false), '');
    
    // 3. 移除 "思考过程" 章节（## 或 ### 开头）
    cleaned = cleaned.replaceAll(RegExp(r'#{1,3}\s*思考过程.*?(?=#{1,3}|\Z)', caseSensitive: false, dotAll: true, multiLine: true), '');
    
    // 4. 移除 "【思考过程】" 段落
    cleaned = cleaned.replaceAll(RegExp(r'【思考过程】.*?(?=【|##|\Z)', caseSensitive: false, dotAll: true, multiLine: true), '');
    
    // 5. 移除 "2. 思考过程：" 这种格式
    cleaned = cleaned.replaceAll(RegExp(r'\d+\.\s*思考过程[：:].+?(?=\d+\.|##|\Z)', caseSensitive: false, dotAll: true, multiLine: true), '');
    
    // 6. 移除 "思考：" 开头的段落
    cleaned = cleaned.replaceAll(RegExp(r'思考[：:].+?(?=\n\n|##|\Z)', caseSensitive: false, dotAll: true, multiLine: true), '');
    
    // 7. 移除包含 "thinking" 的英文标记
    cleaned = cleaned.replaceAll(RegExp(r'</?thinking>?', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'<thinking>.*?</thinking>', caseSensitive: false, dotAll: true), '');
    
    // 8. 移除 "分析思路" 或 "分析逻辑" 章节（如果包含）
    cleaned = cleaned.replaceAll(RegExp(r'#{1,3}\s*(分析思路|分析逻辑|思路分析).*?(?=#{1,3}|\Z)', caseSensitive: false, dotAll: true, multiLine: true), '');
    
    // 9. 移除多余的空行（超过2个连续换行）
    cleaned = cleaned.replaceAll(RegExp(r'\n\s*\n\s*\n+'), '\n\n');
    
    // 10. 移除开头的空白字符和结尾的空白字符
    cleaned = cleaned.trim();
    
    // 11. 如果开头还有残留的标签，再次清理
    if (cleaned.startsWith(RegExp(r'</?think', caseSensitive: false))) {
      cleaned = cleaned.replaceFirst(RegExp(r'^</?think>?\s*', caseSensitive: false), '');
    }
    
    return cleaned;
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
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            // 在移动设备模式下，这个页面需要自己的菜单按钮
            Scaffold.of(context).openDrawer();
          },
        ),
        title: const Text(
          '消息量化',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
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
          // 最新财经资讯 - 专业金融风格
          _isLoadingNews
              ? const NewsListSkeleton(itemCount: 6) // 使用骨架屏替代
              : _latestNews.isEmpty
                  ? _buildEmptyNewsState()
                  : ListView.builder(
                      itemCount: _latestNews.length,
                      itemBuilder: (context, index) {
                        final news = _latestNews[index];
                        return _buildProfessionalNewsCard(news, index);
                      },
                    ),
          
          // 消息面AI解读 - 专业金融分析界面
          _isLoading
              ? _buildFinancialAnalysisLoading()
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
                      : _buildBeautifulAnalysisView(_analysisResult),
        ],
      ),
    );
  }

  // 构建专业金融风格的加载指示器
  Widget _buildFinancialLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF1565C0), const Color(0xFF1976D2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.shade300.withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(
              Icons.trending_up,
              color: Colors.white,
              size: 50,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '正在获取财经资讯...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1565C0),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '整合多源金融数据',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // 构建空新闻状态
  Widget _buildEmptyNewsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.newspaper,
              size: 40,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '暂无最新财经资讯',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '请稍后刷新获取最新市场动态',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadLatestNews,
            icon: const Icon(Icons.refresh),
            label: const Text('刷新资讯'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  // 构建专业金融风格的新闻卡片
  Widget _buildProfessionalNewsCard(Map<String, dynamic> news, int index) {
    final title = news['title'] ?? '无标题';
    final source = news['source'] ?? '未知来源';
    final datetime = news['datetime'] ?? '';
    final summary = news['summary'] ?? '';
    final url = news['url'] ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: InkWell(
          onTap: url.isNotEmpty ? () => _openNewsUrl(url) : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 新闻标题和重要性标签
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 重要性标识
                    Container(
                      width: 4,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade600,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          // 新闻元信息
                          Row(
                            children: [
                              _buildNewsMetaItem(Icons.source, source),
                              if (datetime.isNotEmpty) ...[
                                const SizedBox(width: 16),
                                _buildNewsMetaItem(Icons.access_time, datetime),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // 新闻摘要
                if (summary.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      summary,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 构建金融分析加载界面
  Widget _buildFinancialAnalysisLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF1565C0), const Color(0xFF1976D2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.shade300.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    Icons.analytics,
                    color: Colors.white,
                    size: 60,
                  ),
                ),
                Positioned(
                  bottom: 15,
                  right: 15,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      color: Colors.blue.shade700,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          const Text(
            'AI正在深度分析市场消息',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1565C0),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '整合多维度数据，生成专业投资分析报告',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: 200,
            child: LinearProgressIndicator(
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade600),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ),
    );
  }

  // 构建新闻元信息项
  Widget _buildNewsMetaItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  // 构建美化的AI分析视图
  Widget _buildBeautifulAnalysisView(String analysisContent) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // 过滤掉think部分
    String filteredContent = _filterThinkContent(analysisContent);
    
    return SingleChildScrollView(
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDarkMode
                ? [
                    const Color(0xFF1E1E1E).withOpacity(0.8),
                    const Color(0xFF2A2A2A).withOpacity(0.8),
                  ]
                : [
                    Colors.white.withOpacity(0.9),
                    const Color(0xFFF8F9FA).withOpacity(0.9),
                  ],
          ),
          boxShadow: [
            BoxShadow(
              color: isDarkMode 
                  ? Colors.black.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.2),
              blurRadius: 15,
              spreadRadius: 0,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(
            color: isDarkMode 
                ? Colors.white.withOpacity(0.1)
                : Colors.grey.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
                  child: MarkdownBody(
                    data: filteredContent,
                styleSheet: MarkdownStyleSheet(
                  // 标题样式
                  h1: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : const Color(0xFF1565C0),
                    height: 1.3,
                  ),
                  h2: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white70 : const Color(0xFF1976D2),
                    height: 1.3,
                  ),
                  h3: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white60 : const Color(0xFF2196F3),
                    height: 1.3,
                  ),
                  // 段落样式
                  p: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? Colors.white70 : Colors.black87,
                    height: 1.6,
                    fontWeight: FontWeight.w400,
                  ),
                  // 列表样式
                  listBullet: TextStyle(
                    color: isDarkMode ? Colors.white60 : const Color(0xFF1565C0),
                    fontSize: 16,
                  ),
                  // 代码块样式
                  codeblockDecoration: BoxDecoration(
                    color: isDarkMode 
                        ? const Color(0xFF2D2D2D) 
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDarkMode 
                          ? Colors.white.withOpacity(0.1) 
                          : Colors.grey.withOpacity(0.3),
                    ),
                  ),
                  code: TextStyle(
                    backgroundColor: isDarkMode 
                        ? const Color(0xFF3D3D3D) 
                        : Colors.grey.shade200,
                    color: isDarkMode 
                        ? const Color(0xFFBB86FC) 
                        : const Color(0xFF6A1B9A),
                    fontFamily: 'monospace',
                    fontSize: 14,
                  ),
                  // 引用块样式
                  blockquote: TextStyle(
                    color: isDarkMode ? Colors.white60 : Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                    fontSize: 15,
                  ),
                  blockquoteDecoration: BoxDecoration(
                    color: isDarkMode 
                        ? Colors.white.withOpacity(0.05) 
                        : Colors.blue.shade50,
                    border: Border(
                      left: BorderSide(
                        color: isDarkMode 
                            ? Colors.blue.withOpacity(0.5) 
                            : Colors.blue.shade300,
                        width: 4,
                      ),
                    ),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                  ),
                  // 表格样式
                  tableHead: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                    fontSize: 15,
                  ),
                  tableBody: TextStyle(
                    color: isDarkMode ? Colors.white70 : Colors.black87,
                    fontSize: 14,
                  ),
                  tableBorder: TableBorder.all(
                    color: isDarkMode 
                        ? Colors.white.withOpacity(0.2) 
                        : Colors.grey.shade300,
                    width: 1,
                  ),
                  // 分隔线样式
                  blockSpacing: 16,
                  listIndent: 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 过滤think内容
  String _filterThinkContent(String content) {
    // 移除<think>...</think>标签及其内容
    final thinkPattern = RegExp(r'<think>[\s\S]*?</think>', multiLine: true);
    String filtered = content.replaceAll(thinkPattern, '');
    
    // 移除多余的空行
    filtered = filtered.replaceAll(RegExp(r'\n\s*\n\s*\n'), '\n\n');
    
    return filtered.trim();
  }

  // 构建重要性标签
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