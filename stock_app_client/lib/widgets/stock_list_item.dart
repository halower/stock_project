import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/stock_indicator.dart';
import '../services/providers/theme_provider.dart';
import '../services/watchlist_service.dart';
import '../screens/stock_detail_screen.dart';

class StockListItem extends StatefulWidget {
  final StockIndicator stock;
  final bool showAIAnalysis;
  final VoidCallback? onWatchlistChanged;
  
  const StockListItem({
    super.key,
    required this.stock,
    this.showAIAnalysis = false,
    this.onWatchlistChanged,
  });

  @override
  State<StockListItem> createState() => _StockListItemState();
}

class _StockListItemState extends State<StockListItem> with SingleTickerProviderStateMixin {
  bool _isInWatchlist = false;
  bool _isLoading = false;
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;
  bool _isInitialized = false;
  bool _isAIAnalysisExpanded = false; // AI分析展开状态

  @override
  void initState() {
    super.initState();
    _checkWatchlistStatus();
    
    // 监听全局备选池状态变化
    WatchlistService.watchlistChangeNotifier.addListener(_onWatchlistChanged);
    
    // 初始化光晕动画 - 更快更明显
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000), // 2秒更快
    )..repeat();
    
    _shimmerAnimation = Tween<double>(
      begin: -1.5,
      end: 1.5,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.linear, // 线性更流畅
    ));
    
    _isInitialized = true;
  }
  
  @override
  void dispose() {
    // 移除监听器
    WatchlistService.watchlistChangeNotifier.removeListener(_onWatchlistChanged);
    _shimmerController.dispose();
    super.dispose();
  }
  
  // 全局备选池状态变化回调
  void _onWatchlistChanged() {
    _checkWatchlistStatus();
  }

  @override
  void didUpdateWidget(StockListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当widget更新时重新检查状态，确保状态同步
    if (oldWidget.stock.code != widget.stock.code) {
      _checkWatchlistStatus();
    }
  }

  // 检查股票是否在备选池中
  Future<void> _checkWatchlistStatus() async {
    final isInWatchlist = await WatchlistService.isInWatchlist(widget.stock.code);
    if (mounted) {
      setState(() {
        _isInWatchlist = isInWatchlist;
      });
    }
  }

  // 切换备选池状态
  Future<void> _toggleWatchlist() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    bool success;
    String message;
    
    if (_isInWatchlist) {
      success = await WatchlistService.removeFromWatchlist(widget.stock.code);
      message = success ? '已从备选池移除' : '移除失败';
    } else {
      success = await WatchlistService.addToWatchlist(widget.stock);
      message = success ? '已添加到备选池' : '添加失败';
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
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

      // 通知父组件状态变化
      if (success && widget.onWatchlistChanged != null) {
        widget.onWatchlistChanged!();
      }
    }
  }

  // 公开方法供外部调用，用于状态同步
  void refreshWatchlistStatus() {
    _checkWatchlistStatus();
  }

  @override
  Widget build(BuildContext context) {
    // 如果动画未初始化，返回简单版本
    if (!_isInitialized) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: const Card(
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ),
      );
    }
    
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    // 确定价格文本颜色
    Color priceColor;
    if (widget.stock.changePercent == null || widget.stock.changePercent == 0) {
      priceColor = Colors.grey.shade600;
    } else if (widget.stock.changePercent! > 0) {
      priceColor = themeProvider.upColor;
    } else {
      priceColor = themeProvider.downColor;
    }
    
    // 格式化涨跌幅
    String changeText = '';
    if (widget.stock.changePercent != null) {
      final sign = widget.stock.changePercent! > 0 ? '+' : '';
      changeText = '$sign${widget.stock.changePercent!.toStringAsFixed(2)}%';
    }
    
    // 检查是否有AI分析结果
    final hasAIAnalysis = widget.showAIAnalysis && 
        widget.stock.details.containsKey('ai_analysis') && 
        widget.stock.details['ai_analysis'] != null;
    
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
    return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Material(
        color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
        elevation: 0,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StockDetailScreen(
                  stockCode: widget.stock.code,
                  stockName: widget.stock.name,
                      strategy: widget.stock.strategy,
              ),
            ),
          );
        },
              borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
                  // 背景光晕效果
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: CustomPaint(
                        painter: _ShimmerPainter(
                          animation: _shimmerAnimation.value,
                          color: _getPriceColor().withOpacity(0.1),
                          isDarkMode: isDarkMode,
                        ),
                      ),
                    ),
                  ),
                  
                  // 主内容容器
              Container(
            decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDarkMode
                            ? [
                                const Color(0xFF1A1F2E).withOpacity(0.95),
                                const Color(0xFF0F1419).withOpacity(0.98),
                              ]
                            : [
                                Colors.white.withOpacity(0.95),
                                const Color(0xFFFAFBFC).withOpacity(0.98),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(14),
              border: Border.all(
                        width: 1.5,
                        color: _getPriceColor().withOpacity(0.4), // 增加边框不透明度
              ),
              boxShadow: [
                BoxShadow(
                          color: _getPriceColor().withOpacity(0.25), // 增加阴影不透明度
                          blurRadius: 16, // 增加模糊
                          spreadRadius: 1,
                          offset: const Offset(0, 4),
                ),
                BoxShadow(
                          color: Colors.black.withOpacity(isDarkMode ? 0.4 : 0.08), // 增加深度
                          blurRadius: 24,
                          spreadRadius: 0,
                          offset: const Offset(0, 8),
                ),
              ],
            ),
                    padding: const EdgeInsets.all(14),
          child: Column(
            children: [
                // 主要信息行
              Row(
                children: [
                    // 左侧：股票信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          // 股票名称和代码 - 优化布局，让代码和名称更靠近
                        Row(
                          children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    // 股票名称
                            Flexible(
                              child: Text(
                                        widget.stock.name,
                                style: const TextStyle(
                                          fontSize: 15, // 减小字体 16→15
                                          fontWeight: FontWeight.w600,
                                          height: 1.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                                    const SizedBox(width: 5), // 减少间距 6→5
                                    // 优化股票代码样式 - 紧贴名称显示
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2), // 减少内边距 6→5
                              decoration: BoxDecoration(
                                        color: Theme.of(context).primaryColor.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(3),
                                        border: Border.all(
                                          color: Theme.of(context).primaryColor.withOpacity(0.2),
                                          width: 0.5,
                                        ),
                              ),
                              child: Text(
                                        widget.stock.code,
                                style: TextStyle(
                                  fontSize: 10, // 减小字体 11→10
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(context).primaryColor.withOpacity(0.8),
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ),
                                    // 触发时间（如果有）
                                    _buildCalculatedTimeWidget(),
                                  ],
                                      ),
                                    ),
                                  ],
                                ),
                              // 行业信息（如果有）
                              if (widget.stock.industry != null) ...[
                                const SizedBox(height: 3), // 减少间距 4→3
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2), // 减少内边距 6→5
                                  decoration: BoxDecoration(
                                    color: _getIndustryColor(widget.stock.industry!).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: _getIndustryColor(widget.stock.industry!).withOpacity(0.3),
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.business_outlined,
                                        size: 10, // 减小图标 11→10
                                        color: _getIndustryColor(widget.stock.industry!),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        widget.stock.industry!,
                                        style: TextStyle(
                                          fontSize: 9, // 减小字体 10→9
                                          fontWeight: FontWeight.w500,
                                          color: _getIndustryColor(widget.stock.industry!),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                          const SizedBox(height: 6), // 减少间距 8→6
                          // 市场和策略标签
                          Wrap(
                            spacing: 6, // 减少间距 8→6
                            runSpacing: 3, // 减少间距 4→3
                            children: [
                              // 市场标签
                              _buildCompactTag(
                                _getDisplayMarketName(widget.stock.market),
                                _getMarketColor(_getDisplayMarketName(widget.stock.market)),
                              ),
                              // 策略标签
                              FutureBuilder<String>(
                                future: widget.stock.getStrategyName(),
                                builder: (context, snapshot) {
                                  return _buildCompactTag(
                                    snapshot.hasData ? snapshot.data! : widget.stock.strategyName,
                                    Colors.blue.shade600,
                                    icon: Icons.analytics_outlined,
                                  );
                                },
                              ),
                              // 量能比率标签
                              if (widget.stock.volumeRatio != null)
                                _buildVolumeRatioTag(),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                    const SizedBox(width: 16),
                    
                    // 右侧：价格信息（科技感增强）
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // 价格（带发光效果）
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                priceColor.withOpacity(0.1),
                                priceColor.withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: priceColor.withOpacity(0.3),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: priceColor.withOpacity(0.2),
                                blurRadius: 8,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: Text(
                          widget.stock.price != null ? '¥${widget.stock.price!.toStringAsFixed(2)}' : '-',
                          style: TextStyle(
                              fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: priceColor,
                              letterSpacing: 0.5,
                              shadows: [
                                Shadow(
                                  color: priceColor.withOpacity(0.3),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // 涨跌幅（霓虹灯效果）
                        if (changeText.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                priceColor,
                                priceColor.withOpacity(0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: priceColor.withOpacity(0.5),
                                blurRadius: 8,
                                spreadRadius: 0,
                              ),
                              BoxShadow(
                                color: priceColor.withOpacity(0.3),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                widget.stock.changePercent! > 0 
                                    ? Icons.arrow_drop_up 
                                    : Icons.arrow_drop_down,
                                color: Colors.white,
                                size: 16,
                              ),
                              Text(
                            changeText,
                              style: const TextStyle(
                                  fontSize: 11,
                                color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                              ),
                              ),
                            ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                            '待分析',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                  ),
                ],
              ),
              
                // 底部备选池操作区域
                const SizedBox(height: 10), // 减少间距 12→10
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(7), // 减少内边距 8→7
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? Colors.grey.shade800.withOpacity(0.3)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(7), // 减少圆角 8→7
                  ),
                  child: Row(
                    children: [
                      // 时间信息（如果有）
                      _buildTimeInfo(),
                      
                      const Spacer(),
                      
                      // 备选池按钮
                      _buildWatchlistButton(),
                    ],
                  ),
                ),
                
                // AI分析结果（可展开）
                if (hasAIAnalysis) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isAIAnalysisExpanded = !_isAIAnalysisExpanded;
                      });
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        // 金融风格的渐变色：深蓝到靛蓝
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF1E3A8A).withOpacity(0.08),  // 深蓝色
                            const Color(0xFF4F46E5).withOpacity(0.06),  // 靛蓝色
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          width: 1.5,
                          color: const Color(0xFF4F46E5).withOpacity(0.25),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4F46E5).withOpacity(0.1),
                            blurRadius: 8,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // AI图标（金融风格）
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF1E3A8A),  // 深蓝
                                      Color(0xFF4F46E5),  // 靛蓝
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF4F46E5).withOpacity(0.3),
                                      blurRadius: 6,
                                      spreadRadius: 0,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.psychology,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFF1E3A8A),
                                                Color(0xFF4F46E5),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'AI分析',
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        Icon(
                                          _isAIAnalysisExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                          size: 18,
                                          color: const Color(0xFF4F46E5),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    _buildAIAnalysisContent(isDarkMode),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
              ),
              
                  // 行业标识条 - 左边缘彩色条带（带脉冲效果）
              if (widget.stock.industry != null)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: _buildIndustryStripe(),
                ),
                  
                  // 顶部科技光效 - 增强
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(14),
                        topRight: Radius.circular(14),
                      ),
                      child: Container(
                        height: 3, // 增加高度
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              _getPriceColor().withOpacity(0.8), // 增加不透明度
                              _getPriceColor(), // 中心完全不透明
                              _getPriceColor().withOpacity(0.8),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _getPriceColor().withOpacity(0.5),
                              blurRadius: 8,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  // 获取价格颜色
  Color _getPriceColor() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    if (widget.stock.changePercent == null || widget.stock.changePercent == 0) {
      return Colors.grey.shade600;
    } else if (widget.stock.changePercent! > 0) {
      return themeProvider.upColor;
    } else {
      return themeProvider.downColor;
    }
  }

  // 构建行业标识条
  Widget _buildIndustryStripe() {
    final industryColor = _getIndustryColor(widget.stock.industry!);
    
    return Container(
      width: 3, // 减少宽度 4→3
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            industryColor,
            industryColor.withOpacity(0.7),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(14), // 减少圆角 16→14
          bottomLeft: Radius.circular(14), // 减少圆角 16→14
        ),
        boxShadow: [
          BoxShadow(
            color: industryColor.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(2, 0),
          ),
        ],
      ),
    );
  }
  
  // 构建AI分析内容（支持展开/收起）
  Widget _buildAIAnalysisContent(bool isDarkMode) {
    final aiAnalysis = widget.stock.details['ai_analysis'];
    
    // 尝试解析为结构化数据
    Map<String, dynamic>? analysisData;
    String displayText = '';
    
    if (aiAnalysis is Map) {
      analysisData = Map<String, dynamic>.from(aiAnalysis);
      displayText = analysisData['reason'] ?? '';
    } else if (aiAnalysis is String) {
      displayText = aiAnalysis;
    }
    
    final textColor = isDarkMode ? Colors.white.withOpacity(0.9) : const Color(0xFF1A202C);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 如果是结构化数据，先显示操作建议和置信度（始终显示）
        if (analysisData != null) ...[
          Row(
            children: [
              // 操作建议
              if (analysisData['signal'] != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: _getSignalGradient(analysisData['signal']),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: _getSignalColor(analysisData['signal']).withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getSignalIcon(analysisData['signal']),
                        size: 13,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        analysisData['signal'],
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
              
              // 置信度
              if (analysisData['confidence'] != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getConfidenceColor(analysisData['confidence']),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: _getConfidenceColor(analysisData['confidence']).withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getConfidenceIcon(analysisData['confidence']),
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${analysisData['confidence']}置信',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        
        // 显示理由（始终显示，可展开查看全文）
        Text(
          displayText,
          style: TextStyle(
            fontSize: 11,
            color: textColor,
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
          maxLines: _isAIAnalysisExpanded ? null : 2,
          overflow: _isAIAnalysisExpanded ? null : TextOverflow.ellipsis,
        ),
        
        // 如果是结构化数据且已展开，显示详细信息
        if (_isAIAnalysisExpanded && analysisData != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 止损价
                if (analysisData['stop_loss'] != null)
                  _buildInfoRow(
                    '止损价',
                    '¥${analysisData['stop_loss']}',
                    const Color(0xFFEF4444),  // 鲜艳的红色
                    isDarkMode,
                    Icons.trending_down,
                  ),
                
                // 目标价
                if (analysisData['take_profit'] != null) ...[
                  const SizedBox(height: 4),
                  _buildInfoRow(
                    '目标价',
                    '¥${analysisData['take_profit']}',
                    const Color(0xFF10B981),  // 鲜艳的绿色
                    isDarkMode,
                    Icons.trending_up,
                  ),
                ],
                
                // 技术分析详情
                if (analysisData['technical_analysis'] != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '技术分析',
                    style: TextStyle(
                      fontSize: 10,
                      color: textColor.withOpacity(0.7),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildTechnicalAnalysis(analysisData['technical_analysis'], textColor, isDarkMode),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
  
  // 构建信息行（带图标）
  Widget _buildInfoRow(String label, String value, Color valueColor, bool isDarkMode, [IconData? icon]) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 14,
            color: valueColor,
          ),
          const SizedBox(width: 4),
        ],
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 11,
            color: isDarkMode ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: valueColor,
            borderRadius: BorderRadius.circular(5),
            boxShadow: [
              BoxShadow(
                color: valueColor.withOpacity(0.3),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }
  
  // 构建技术分析详情
  Widget _buildTechnicalAnalysis(dynamic technicalData, Color textColor, bool isDarkMode) {
    if (technicalData is! Map) return const SizedBox.shrink();
    
    final Map<String, dynamic> data = Map<String, dynamic>.from(technicalData);
    final List<Widget> items = [];
    
    // 按照结构顺序显示
    final fields = [
      {'key': 'overall_trend', 'label': '整体趋势'},
      {'key': 'short_term_trend', 'label': '短期趋势'},
      {'key': 'rsi_status', 'label': 'RSI状态'},
      {'key': 'rsi_value', 'label': 'RSI值'},
      {'key': 'macd_direction', 'label': 'MACD方向'},
      {'key': 'support', 'label': '支撑位'},
      {'key': 'resistance', 'label': '阻力位'},
    ];
    
    for (final field in fields) {
      final key = field['key'] as String;
      final label = field['label'] as String;
      
      if (data[key] != null) {
        String value = '';
        if (data[key] is num) {
          value = data[key].toString();
          if (key == 'support' || key == 'resistance') {
            value = '¥$value';
          }
        } else {
          value = data[key].toString();
        }
        
        items.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              children: [
                Text(
                  '$label: ',
                  style: TextStyle(
                    fontSize: 9,
                    color: textColor.withOpacity(0.6),
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 9,
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items,
    );
  }
  
  // 获取信号颜色（金融风格）
  Color _getSignalColor(String signal) {
    switch (signal) {
      case '买入':
        return const Color(0xFFEF4444);  // 鲜艳的红色
      case '卖出':
        return const Color(0xFF10B981);  // 鲜艳的绿色
      case '观望':
        return const Color(0xFFF59E0B);  // 鲜艳的橙色
      default:
        return const Color(0xFF6B7280);  // 灰色
    }
  }
  
  // 获取信号渐变色
  LinearGradient _getSignalGradient(String signal) {
    switch (signal) {
      case '买入':
        return const LinearGradient(
          colors: [Color(0xFFEF4444), Color(0xFFDC2626)],  // 红色渐变
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case '卖出':
        return const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],  // 绿色渐变
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case '观望':
        return const LinearGradient(
          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],  // 橙色渐变
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      default:
        return const LinearGradient(
          colors: [Color(0xFF6B7280), Color(0xFF4B5563)],  // 灰色渐变
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }
  
  // 获取信号图标
  IconData _getSignalIcon(String signal) {
    switch (signal) {
      case '买入':
        return Icons.arrow_circle_up;  // 向上箭头
      case '卖出':
        return Icons.arrow_circle_down;  // 向下箭头
      case '观望':
        return Icons.visibility;  // 眼睛图标
      default:
        return Icons.help_outline;
    }
  }
  
  // 获取置信度颜色（更鲜艳）
  Color _getConfidenceColor(String confidence) {
    switch (confidence) {
      case '高':
        return const Color(0xFF10B981);  // 鲜艳的绿色
      case '中':
        return const Color(0xFF3B82F6);  // 鲜艳的蓝色
      case '低':
        return const Color(0xFF8B5CF6);  // 鲜艳的紫色
      default:
        return const Color(0xFF6B7280);  // 灰色
    }
  }
  
  // 获取置信度图标
  IconData _getConfidenceIcon(String confidence) {
    switch (confidence) {
      case '高':
        return Icons.verified;  // 认证图标
      case '中':
        return Icons.star_half;  // 半星
      case '低':
        return Icons.info_outline;  // 信息图标
      default:
        return Icons.help_outline;
    }
  }
  
  // 根据行业类型返回对应的颜色
  Color _getIndustryColor(String industry) {
    // 使用专业的交易APP色彩方案，避免过于粉嫩的颜色
    final hash = industry.hashCode;
    final colors = [
      const Color(0xFF1E40AF), // 深蓝色 - 专业稳重
      const Color(0xFF059669), // 深绿色 - 成长稳健
      const Color(0xFF7C2D12), // 深棕色 - 传统行业
      const Color(0xFF4338CA), // 深靛蓝 - 科技行业
      const Color(0xFF0891B2), // 深青色 - 新兴产业
      const Color(0xFFB45309), // 深橙色 - 制造业
      const Color(0xFF9333EA), // 深紫色 - 创新行业
      const Color(0xFF16A34A), // 深墨绿 - 环保能源
      const Color(0xFFDC2626), // 深红色 - 金融地产
      const Color(0xFF6B7280), // 深灰色 - 其他行业
    ];
    
    return colors[hash.abs() % colors.length];
  }

  // 构建备选池按钮（金融风格）
  Widget _buildWatchlistButton() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final buttonColor = _isInWatchlist ? const Color(0xFFFF9800) : themeProvider.upColor;
    
    return GestureDetector(
      onTap: _toggleWatchlist,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _isInWatchlist 
                ? [
                    const Color(0xFFFF9800), // 橙色
                    const Color(0xFFFF6D00),
                  ]
                : [
                    const Color(0xFF1E40AF), // 深蓝色
                    const Color(0xFF3730A3).withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isLoading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            else
              Icon(
                _isInWatchlist ? Icons.star : Icons.star_border,
                size: 15,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                  ),
                ],
              ),
            const SizedBox(width: 6),
            Text(
              _isInWatchlist ? '已在备选' : '加入备选',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
                shadows: [
                  Shadow(
                    color: Colors.black26,
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 构建紧凑的标签组件（科技感增强）
  Widget _buildCompactTag(String text, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.2),
            color.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 6,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 11,
              color: color,
              shadows: [
                Shadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 2,
                ),
              ],
            ),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
                letterSpacing: 0.3,
                shadows: [
                  Shadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 2,
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // 获取显示用的市场名称 - 将上证主板和深证主板合并为主板
  String _getDisplayMarketName(String market) {
    switch (market) {
      case '上证主板':
      case '深证主板':
        return '主板';
      default:
        return market;
    }
  }

  // 根据市场类型返回对应的颜色
  Color _getMarketColor(String market) {
    switch (market) {
      case '创业板':
        return const Color(0xFF10B981); // 绿色
      case '科创板':
        return const Color(0xFF8B5CF6); // 紫色
      case '主板': // 合并后的主板
        return const Color(0xFF3B82F6); // 蓝色
      case '上证主板':
        return const Color(0xFF3B82F6); // 蓝色
      case '深证主板':
        return const Color(0xFF06B6D4); // 青色
      case '北交所':
        return const Color(0xFFEF4444); // 红色
      case 'B股':
        return const Color(0xFF6B7280); // 灰色
      default:
        return const Color(0xFF64748B); // 默认灰色
    }
  }

  // 构建量能比率标签 - 与其他标签样式一致
  Widget _buildVolumeRatioTag() {
    final volumeRatio = widget.stock.volumeRatio!;
    final isHighVolume = volumeRatio >= 1.0; // 大于等于1为放量
    
    // 确定颜色和文本
    Color tagColor;
    String volumeText;
    IconData volumeIcon;
    
    if (isHighVolume) {
      // 放量 - 使用红色系
      tagColor = Colors.red.shade600;
      volumeText = '放量${volumeRatio.toStringAsFixed(1)}';
      volumeIcon = Icons.trending_up;
    } else {
      // 缩量 - 使用绿色系
      tagColor = Colors.green.shade600;
      volumeText = '缩量${volumeRatio.toStringAsFixed(1)}';
      volumeIcon = Icons.trending_down;
    }
    
    return _buildCompactTag(
      volumeText,
      tagColor,
      icon: volumeIcon,
    );
  }

  // 构建触发时间小部件（放在股票代码后面）
  Widget _buildCalculatedTimeWidget() {
    // 检查是否有计算触发时间
    if (widget.stock.details.containsKey('calculated_time') && 
        widget.stock.details['calculated_time'] != null) {
      return Container(
        margin: const EdgeInsets.only(left: 5), // 减少边距 6→5
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2), // 减少内边距 6→5
        decoration: BoxDecoration(
          color: Colors.orange.shade100,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: Colors.orange.shade300,
            width: 0.5,
          ),
        ),
        child: Text(
          '触发: ${_formatCalculatedTime(widget.stock.details['calculated_time'])}',
          style: TextStyle(
            fontSize: 9, // 减小字体 10→9
            fontWeight: FontWeight.w500,
            color: Colors.orange.shade700,
            letterSpacing: 0.2,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  // 构建时间信息显示（简化版，只显示K线日期）
  Widget _buildTimeInfo() {
    // 优先显示K线日期
    if (widget.stock.details.containsKey('kline_date') && 
        widget.stock.details['kline_date'] != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.candlestick_chart_outlined,
            size: 12, // 减小图标 14→12
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 3), // 减少间距 4→3
          Text(
            'K线: ${widget.stock.details['kline_date']}',
            style: TextStyle(
              fontSize: 11, // 减小字体 12→11
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }
    
    // 兼容旧的signal_date字段
    if (widget.stock.details.containsKey('signal_date')) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schedule_outlined,
            size: 12, // 减小图标 14→12
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 3), // 减少间距 4→3
          Text(
            '${widget.stock.details['signal_date']}',
            style: TextStyle(
              fontSize: 11, // 减小字体 12→11
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }
    
    // 默认显示
    return Text(
      '最新信号',
      style: TextStyle(
        fontSize: 11, // 减小字体 12→11
        color: Colors.grey.shade600,
        fontWeight: FontWeight.w500,
      ),
    );
  }
  
  // 格式化计算触发时间，只显示小时分钟
  String _formatCalculatedTime(String calculatedTime) {
    try {
      final DateTime dateTime = DateTime.parse(calculatedTime);
      final String time = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      return time;
    } catch (e) {
      // 如果解析失败，返回原始字符串
      return calculatedTime;
    }
  }
}

// 光晕特效绘制器
class _ShimmerPainter extends CustomPainter {
  final double animation;
  final Color color;
  final bool isDarkMode;

  _ShimmerPainter({
    required this.animation,
    required this.color,
    required this.isDarkMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 增强光晕效果 - 更明显
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          color.withOpacity(0),
          color.withOpacity(isDarkMode ? 0.3 : 0.15), // 增加不透明度
          color.withOpacity(isDarkMode ? 0.3 : 0.15),
          color.withOpacity(0),
        ],
        stops: [
          (animation - 0.2).clamp(0.0, 1.0),
          (animation).clamp(0.0, 1.0),
          (animation + 0.1).clamp(0.0, 1.0),
          (animation + 0.3).clamp(0.0, 1.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    // 绘制光晕效果
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      paint,
    );
    
    // 添加更明显的脉冲光点
    final pulseX = size.width * ((animation + 1.5) / 3);
    final pulsePaint = Paint()
      ..color = color.withOpacity(isDarkMode ? 0.4 : 0.2) // 增加不透明度
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30); // 增加模糊半径
    
    canvas.drawCircle(
      Offset(pulseX, size.height / 2),
      40, // 增加光点大小
      pulsePaint,
    );
    
    // 添加第二个光点增强效果
    final pulsePaint2 = Paint()
      ..color = color.withOpacity(isDarkMode ? 0.25 : 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
    
    canvas.drawCircle(
      Offset(pulseX, size.height / 2),
      60,
      pulsePaint2,
    );
  }

  @override
  bool shouldRepaint(_ShimmerPainter oldDelegate) => true;
} 