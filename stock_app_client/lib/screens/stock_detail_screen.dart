import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:stock_app/config/api_config.dart';
import '../services/providers/api_provider.dart';
import '../services/providers/theme_provider.dart';
import '../services/api_service.dart';
import '../services/watchlist_service.dart';
import '../models/stock_indicator.dart';
import '../widgets/custom_web_view.dart';
import '../widgets/stock_chart_web_view.dart';
import '../widgets/landscape_kline_widget.dart';
import '../widgets/tradingview_stock_switcher.dart';
import '../widgets/swipe_stock_switcher.dart';
import '../widgets/compact_swipe_switcher.dart';
import '../widgets/stock_ai_analysis.dart';
import '../widgets/stock_switcher_overlay.dart'; // 导入股票切换器
import 'news_markdown_view_screen.dart';
import 'package:webview_flutter/webview_flutter.dart';

class StockDetailScreen extends StatefulWidget {
  final String stockCode;
  final String stockName;
  final String? strategy; // 添加可选的策略参数
  final List<Map<String, String>>? availableStocks; // 添加可选的股票列表参数

  const StockDetailScreen({
    super.key,
    required this.stockCode,
    required this.stockName,
    this.strategy, // 可选策略参数
    this.availableStocks, // 可选股票列表参数
  });

  @override
  State<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends State<StockDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // 当前股票信息
  String _currentStockCode = '';
  String _currentStockName = '';
  int _currentTabIndex = 0;
  
  // 关注状态
  bool _isInWatchlist = false;
  bool _isLoadingWatchlist = false;
  
  // 横屏状态
  bool _isLandscapeMode = false;
  
  @override
  void initState() {
    super.initState();
    
    // 初始化当前股票信息
    _currentStockCode = widget.stockCode;
    _currentStockName = widget.stockName;
    
    _tabController = TabController(length: 3, vsync: this);
    
    // 添加Tab切换监听器
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _currentTabIndex = _tabController.index;
        });
      }
    });
    
    // 检查股票是否已在关注列表中
    _checkWatchlistStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 处理股票切换
  void _onStockChanged(String stockCode, String stockName) {
    setState(() {
      _currentStockCode = stockCode;
      _currentStockName = stockName;
    });
    
    // 切换股票后重新检查关注状态
    _checkWatchlistStatus();
    
    // 这里可以添加一些切换股票后的处理逻辑
    debugPrint('股票已切换为: $stockName ($stockCode)');
  }

  // 检查股票是否在关注列表中
  Future<void> _checkWatchlistStatus() async {
    final isInWatchlist = await WatchlistService.isInWatchlist(_currentStockCode);
    if (mounted) {
      setState(() {
        _isInWatchlist = isInWatchlist;
      });
    }
  }

  // 切换关注状态
  Future<void> _toggleWatchlist() async {
    if (_isLoadingWatchlist) return;
    
    setState(() {
      _isLoadingWatchlist = true;
    });

    bool success;
    String message;
    
    if (_isInWatchlist) {
      success = await WatchlistService.removeFromWatchlist(_currentStockCode);
      message = success ? '已从关注列表移除' : '移除失败';
    } else {
      // 获取当前K线走势使用的策略参数
      final apiProvider = Provider.of<ApiProvider>(context, listen: false);
      final currentStrategy = widget.strategy ?? apiProvider.selectedStrategy;
      
      // 创建StockIndicator对象，保存当前策略参数
      final stockIndicator = StockIndicator(
        market: '', // 这里可以从API或其他地方获取市场信息
        code: _currentStockCode,
        name: _currentStockName,
        signal: '关注',
        details: {},
        strategy: currentStrategy, // 使用当前K线走势的策略参数
      );
      success = await WatchlistService.addToWatchlist(stockIndicator);
      message = success ? '已添加到关注列表' : '添加失败';
    }

    if (mounted) {
      setState(() {
        _isLoadingWatchlist = false;
        if (success) {
          _isInWatchlist = !_isInWatchlist;
        }
      });

      // 显示提示消息
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          backgroundColor: success 
              ? (_isInWatchlist ? Colors.green : Colors.orange)
              : Colors.red,
        ),
      );
    }
  }

  // 构建关注按钮
  Widget _buildWatchlistButton() {
    return GestureDetector(
      onTap: _toggleWatchlist,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: _isInWatchlist 
              ? LinearGradient(
                  colors: [
                    const Color(0xFFFFD700), // 金色
                    const Color(0xFFFF8C00), // 深橙色
                    const Color(0xFFFF6B35), // 橙红色
                  ],
                  stops: const [0.0, 0.6, 1.0],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [
                    const Color(0xFF9C27B0), // 紫色
                    const Color(0xFF673AB7), // 深紫色
                    const Color(0xFF3F51B5), // 靛蓝色
                  ],
                  stops: const [0.0, 0.6, 1.0],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.4),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: (_isInWatchlist ? const Color(0xFFFF8C00) : const Color(0xFF9C27B0)).withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isLoadingWatchlist)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            else
              Icon(
                _isInWatchlist ? Icons.star : Icons.star_border,
                size: 16,
                color: Colors.white,
              ),
            const SizedBox(width: 6),
            Text(
              _isInWatchlist ? '已关注' : '关注',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 切换横屏模式
  void _toggleLandscapeMode() {
    setState(() {
      _isLandscapeMode = !_isLandscapeMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    // 如果是横屏模式且在K线图Tab，显示全屏K线图
    if (_isLandscapeMode && _currentTabIndex == 0) {
      return _buildLandscapeKLineView();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('$_currentStockName ($_currentStockCode)'),
        actions: [
          // 关注按钮
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: _buildWatchlistButton(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'K线走势'),
            Tab(text: 'AI技术分析'),
            Tab(text: '个股新闻'),
          ],
          labelColor: themeProvider.upColor,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
          indicatorColor: themeProvider.upColor,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(), // 禁用TabBarView的滑动功能，避免与WebView冲突
        children: [
          // K线走势图选项卡
          KLineChartTab(
            stockCode: _currentStockCode,
            strategy: widget.strategy,
            onToggleLandscape: _toggleLandscapeMode,
            onStockChanged: _onStockChanged,
            availableStocks: widget.availableStocks, // 传递可选的股票列表
          ),
          AIAnalysisTab(stockCode: _currentStockCode, stockName: _currentStockName),
          StockNewsTab(stockCode: _currentStockCode),
        ],
      ),
    );
  }

  // 构建横屏K线图视图
  Widget _buildLandscapeKLineView() {
    final apiProvider = Provider.of<ApiProvider>(context, listen: false);
    String strategyToUse = widget.strategy ?? apiProvider.selectedStrategy;
    if (strategyToUse.isEmpty) {
      strategyToUse = 'volume_wave';
    }
    
    // 获取当前主题
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final String chartUrl = ApiConfig.getStockChartWithStrategyUrl(_currentStockCode, strategyToUse, isDarkMode: isDarkMode);
    
    // 设置横屏和隐藏系统UI
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 全屏K线图 - 使用key确保股票切换时重新加载
          StockChartWebView(
            key: ValueKey(_currentStockCode), // 使用股票代码作为key
            url: chartUrl,
          ),
          
          // 紧凑型滑动切换器（横屏版本）
          CompactSwipeSwitcher(
            currentStockCode: _currentStockCode,
            currentStockName: _currentStockName,
            onStockChanged: _onStockChanged,
            isLandscape: true,
            availableStocks: widget.availableStocks, // 传递可选的股票列表
          ),
          
          // 右上角按钮组（横屏模式）
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 备选池按钮（横屏版本）
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _toggleWatchlist,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: _isInWatchlist 
                            ? LinearGradient(
                                colors: [Colors.amber.shade400, Colors.orange.shade600],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : LinearGradient(
                                colors: [const Color(0xFF1E88E5), const Color(0xFF1565C0)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.8),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (_isInWatchlist ? Colors.orange : const Color(0xFF1E88E5)).withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: _isLoadingWatchlist
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Icon(
                              _isInWatchlist ? Icons.bookmark : Icons.bookmark_border,
                              color: Colors.white,
                              size: 22,
                            ),
                      ),
                    ),
                  ),
                
                const SizedBox(width: 8),
                
                // 退出横屏按钮
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      // 恢复竖屏和系统UI
                      SystemChrome.setPreferredOrientations([
                        DeviceOrientation.portraitUp,
                        DeviceOrientation.portraitDown,
                      ]);
                      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                      _toggleLandscapeMode();
                    },
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
              ],
            ),
          ),
          ),
        ],
      ),
    );
  }
}

/// K线走势图选项卡
class KLineChartTab extends StatefulWidget {
  final String stockCode;
  final String? strategy; // 添加可选的策略参数
  final VoidCallback? onToggleLandscape;
  final Function(String stockCode, String stockName)? onStockChanged;
  final List<Map<String, String>>? availableStocks; // 添加可选的股票列表参数
  
  const KLineChartTab({
    Key? key,
    required this.stockCode,
    this.strategy, // 可选策略参数
    this.onToggleLandscape,
    this.onStockChanged,
    this.availableStocks, // 可选股票列表参数
  }) : super(key: key);
  
  @override
  State<KLineChartTab> createState() => _KLineChartTabState();
}

class _KLineChartTabState extends State<KLineChartTab> with AutomaticKeepAliveClientMixin {
  bool _isLoading = false;
  final bool _hasError = false;
  final String _errorMessage = '';
  
  // 添加控制器引用
  WebViewController? _webViewController;
  String? _currentStockCode; // 跟踪当前股票代码
  Key _webViewKey = UniqueKey(); // 用于强制重建WebView
  
  @override
  bool get wantKeepAlive => true; // 保持状态，避免重新加载
  
  @override
  void initState() {
    super.initState();
    _currentStockCode = widget.stockCode;
  }
  
  @override
  void didUpdateWidget(KLineChartTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    
      // 检测股票代码是否变化
  if (widget.stockCode != _currentStockCode) {
    debugPrint('股票代码变化: $_currentStockCode -> ${widget.stockCode}');
    _currentStockCode = widget.stockCode;
    _webViewKey = UniqueKey(); // 强制重建WebView
    _webViewController = null; // 清空旧的controller引用
    _reloadChart();
  }
  }
  
  // 重新加载K线图
  void _reloadChart() {
    debugPrint('重建K线图 - 新股票代码: $_currentStockCode');
    
    setState(() {
      _isLoading = true;
      // WebView将因为key变化而完全重建
    });
    
    // 延迟2秒后更新加载状态，给新WebView时间加载
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }
  
  // 刷新K线图
  void _refreshChart() {
    _reloadChart();
  }
  
  @override
  Widget build(BuildContext context) {
    super.build(context); // 必须调用super.build
    
    // 优先使用传入的策略参数，如果没有则使用ApiProvider中的选中策略
    final apiProvider = Provider.of<ApiProvider>(context, listen: false);
    String strategyToUse = widget.strategy ?? apiProvider.selectedStrategy;
    
    // 只有在策略参数为空时才使用默认策略
    if (strategyToUse.isEmpty) {
      strategyToUse = 'volume_wave'; // 默认使用波动策略
      debugPrint('策略参数为空，使用默认策略: $strategyToUse');
    }
    
    // 获取当前主题
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final String chartUrl = ApiConfig.getStockChartWithStrategyUrl(_currentStockCode ?? widget.stockCode, strategyToUse, isDarkMode: isDarkMode);
    
    debugPrint('加载K线图: $chartUrl, 使用策略: $strategyToUse, 主题: ${isDarkMode ? "暗色" : "亮色"}');
    
    return AbsorbPointer(
      absorbing: false, // 不吸收点击事件，允许WebView接收触摸
      child: Stack(
        children: [
          // K线图使用WebView加载，确保占满整个空间
          SizedBox(
            width: double.infinity,
            height: MediaQuery.of(context).size.height,
                    child: Stack(
          children: [
            // K线图WebView - 使用key确保股票切换时重新加载
            StockChartWebView(
              key: ValueKey(_currentStockCode ?? widget.stockCode),
              url: chartUrl,
            ),
            
                          // 紧凑型滑动切换器
              if (widget.onStockChanged != null)
                CompactSwipeSwitcher(
                  currentStockCode: _currentStockCode ?? widget.stockCode,
                  currentStockName: widget.stockCode,
                  onStockChanged: widget.onStockChanged!,
                  isLandscape: false,
                  availableStocks: widget.availableStocks, // 传递可选的股票列表
                ),
            
            // 横屏按钮 - 移动到右下角方便单手操作
            Positioned(
              bottom: 20,
              right: 20,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onToggleLandscape,
                  borderRadius: BorderRadius.circular(25),
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.screen_rotation,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
          ),
          
          // 加载指示器
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
            
          // 错误信息
          if (_hasError)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 50, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(_errorMessage, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshChart,
                    child: const Text('重试'),
                  ),
                ],
              ),
            ),
            

        ],
      ),
    );
  }
}

/// AI分析选项卡
class AIAnalysisTab extends StatefulWidget {
  final String stockCode;
  final String stockName;
  
  const AIAnalysisTab({
    Key? key,
    required this.stockCode,
    required this.stockName,
  }) : super(key: key);
  
  @override
  State<AIAnalysisTab> createState() => _AIAnalysisTabState();
}

class _AIAnalysisTabState extends State<AIAnalysisTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // 保持状态，避免重新加载
  
  @override
  Widget build(BuildContext context) {
    super.build(context); // 必须调用super.build
    
    return StockAIAnalysis(
      stockCode: widget.stockCode,
      stockName: widget.stockName,
    );
  }
}

/// 个股新闻选项卡
class StockNewsTab extends StatefulWidget {
  final String stockCode;
  
  const StockNewsTab({
    Key? key,
    required this.stockCode,
  }) : super(key: key);
  
  @override
  State<StockNewsTab> createState() => _StockNewsTabState();
}

class _StockNewsTabState extends State<StockNewsTab> with AutomaticKeepAliveClientMixin {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  List<Map<String, dynamic>> _stockNewsList = [];
  
  @override
  bool get wantKeepAlive => true; // 保持状态，避免重新加载
  
  @override
  void initState() {
    super.initState();
    _loadStockNews();
  }
  
  Future<void> _loadStockNews() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });
    
    try {
      debugPrint('开始加载个股新闻: ${widget.stockCode}');
      
      final newsList = await _apiService.getStockNews(widget.stockCode);
      
      if (mounted) {
        setState(() {
          _stockNewsList = newsList;
          _isLoading = false;
          
          if (_stockNewsList.isEmpty) {
            debugPrint('没有找到个股新闻');
          } else {
            debugPrint('成功加载 ${_stockNewsList.length} 条个股新闻');
          }
        });
      }
    } catch (e) {
      debugPrint('加载个股新闻出错: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = '无法加载个股新闻: $e';
          _isLoading = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    super.build(context); // 必须调用super.build
    
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            Provider.of<ThemeProvider>(context).upColor,
          ),
        ),
      );
    }
    
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 50, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadStockNews,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    
    if (_stockNewsList.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.newspaper, size: 50, color: Colors.grey),
            SizedBox(height: 16),
            Text('暂无新闻资讯', style: TextStyle(color: Colors.grey)),
          ],
        )
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _stockNewsList.length,
      itemBuilder: (context, index) {
        final newsItem = _stockNewsList[index];
        return _buildNewsCard(newsItem);
      },
    );
  }
  
  Widget _buildNewsCard(Map<String, dynamic> newsItem) {
    // 使用新的API字段名称
    final title = newsItem['新闻标题'] ?? '未知标题';
    final source = newsItem['文章来源'] ?? '未知来源';
    final date = newsItem['发布时间'] ?? '';
    final url = newsItem['新闻链接'] ?? '';
    final content = newsItem['新闻内容'] ?? '';
    final keyword = newsItem['关键词'] ?? '';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 新闻标题和来源
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                
                const SizedBox(height: 8),
                
                // 来源和时间
                Row(
                  children: [
                    Icon(
                      Icons.source,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      source,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (date.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        date,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
                
                // 关键词标签
                if (keyword.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2F80ED).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      keyword,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF2F80ED),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                
                // 内容预览
                if (content.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    content,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          
          // 操作按钮
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                // Markdown查看按钮（推荐）
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: url.isNotEmpty ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NewsMarkdownViewScreen(
                            url: url,
                            title: title,
                            summary: content,
                          ),
                        ),
                      );
                    } : null,
                    icon: const Icon(Icons.auto_fix_high, size: 16),
                    label: const Text('智能阅读'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2F80ED),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // 原网页查看按钮
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: url.isNotEmpty ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CustomWebView(url: url, title: '新闻详情'),
                        ),
                      );
                    } : null,
                    icon: const Icon(Icons.web, size: 16),
                    label: const Text('原网页'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2F80ED),
                      side: const BorderSide(color: Color(0xFF2F80ED)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 