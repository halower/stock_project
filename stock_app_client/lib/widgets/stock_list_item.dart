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

class _StockListItemState extends State<StockListItem> {
  bool _isInWatchlist = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkWatchlistStatus();
    
    // 监听全局备选池状态变化
    WatchlistService.watchlistChangeNotifier.addListener(_onWatchlistChanged);
  }
  
  @override
  void dispose() {
    // 移除监听器
    WatchlistService.watchlistChangeNotifier.removeListener(_onWatchlistChanged);
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
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        elevation: 0,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StockDetailScreen(
                  stockCode: widget.stock.code,
                  stockName: widget.stock.name,
                strategy: widget.stock.strategy, // 传递策略参数
              ),
            ),
          );
        },
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).dividerColor.withOpacity(0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(18),
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
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          height: 1.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                                    const SizedBox(width: 6),
                                    // 优化股票代码样式 - 紧贴名称显示
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                                  fontSize: 11,
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
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                                        size: 11,
                                        color: _getIndustryColor(widget.stock.industry!),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        widget.stock.industry!,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                          color: _getIndustryColor(widget.stock.industry!),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                          const SizedBox(height: 8),
                          // 市场和策略标签
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
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
                    
                    // 右侧：价格信息
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // 价格
                        Text(
                          widget.stock.price != null ? '¥${widget.stock.price!.toStringAsFixed(2)}' : '-',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: priceColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // 涨跌幅
                        if (changeText.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: priceColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            changeText,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        else
                          Text(
                            '待分析',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                      ],
                  ),
                ],
              ),
              
                // 底部备选池操作区域
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? Colors.grey.shade800.withOpacity(0.3)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
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
                
                // AI分析结果（如果有）
                if (hasAIAnalysis) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.blue.shade100,
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.psychology_outlined,
                          size: 16,
                          color: Colors.blue.shade600,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${widget.stock.details['ai_analysis']}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade800,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
            ],
                    ),
                  ),
                ],
              ],
            ),
              ),
              
              // 行业标识条 - 左边缘彩色条带
              if (widget.stock.industry != null)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: _buildIndustryStripe(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // 构建行业标识条
  Widget _buildIndustryStripe() {
    final industryColor = _getIndustryColor(widget.stock.industry!);
    
    return Container(
      width: 4,
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
          topLeft: Radius.circular(16),
          bottomLeft: Radius.circular(16),
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

  // 构建备选池按钮
  Widget _buildWatchlistButton() {
    return GestureDetector(
      onTap: _toggleWatchlist,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: _isInWatchlist 
              ? LinearGradient(
                  colors: [Colors.orange.shade400, Colors.orange.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [Colors.blue.shade400, Colors.blue.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (_isInWatchlist ? Colors.orange : Colors.blue).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isLoading)
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
              _isInWatchlist ? '已在备选' : '加入备选',
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

  // 构建紧凑的标签组件
  Widget _buildCompactTag(String text, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 13,
              color: color.withOpacity(0.8),
            ),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color.withOpacity(0.9),
                letterSpacing: 0.2,
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
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
            fontSize: 10,
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
            size: 14,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 4),
          Text(
            'K线: ${widget.stock.details['kline_date']}',
            style: TextStyle(
              fontSize: 12,
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
            size: 14,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 4),
          Text(
            '${widget.stock.details['signal_date']}',
            style: TextStyle(
              fontSize: 12,
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
        fontSize: 12,
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