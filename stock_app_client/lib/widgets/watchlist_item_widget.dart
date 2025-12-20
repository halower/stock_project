import 'package:flutter/material.dart';
import 'dart:ui';
import '../models/watchlist_item.dart';
import '../screens/stock_detail_screen.dart';
import '../services/strategy_config_service.dart';
import '../services/industry_service.dart';

class WatchlistItemWidget extends StatelessWidget {
  final WatchlistItem item;
  final VoidCallback? onWatchlistChanged;
  final List<WatchlistItem>? allWatchlistItems; // 添加所有备选池股票列表参数
  
  const WatchlistItemWidget({
    super.key,
    required this.item,
    this.onWatchlistChanged,
    this.allWatchlistItems, // 可选的所有备选池股票列表
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enhancedIndustry = item.industry;
    final industryColor = enhancedIndustry != null && enhancedIndustry.isNotEmpty 
        ? IndustryService.getIndustryColor(enhancedIndustry) 
        : null;
    
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          // 🎨 玻璃拟态效果 - 毛玻璃背景
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF1E293B).withOpacity(0.7),
                    const Color(0xFF334155).withOpacity(0.5),
                  ]
                : [
                    Colors.white.withOpacity(0.9),
                    const Color(0xFFF8FAFC).withOpacity(0.8),
                  ],
          ),
          borderRadius: BorderRadius.circular(24),
          // 🌟 高级阴影系统 - 三层阴影
          boxShadow: [
            // 第一层：主阴影 - 彩色光晕
            BoxShadow(
              color: isDark 
                  ? const Color(0xFF3B82F6).withOpacity(0.15)
                  : const Color(0xFF3B82F6).withOpacity(0.12),
              blurRadius: 30,
              offset: const Offset(0, 12),
              spreadRadius: -5,
            ),
            // 第二层：深度阴影
            BoxShadow(
              color: isDark 
                  ? Colors.black.withOpacity(0.5)
                  : Colors.grey.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: -2,
            ),
            // 第三层：细节阴影
            BoxShadow(
              color: isDark 
                  ? Colors.black.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
          ],
          // 🎭 玻璃边框 - 半透明高光
          border: Border.all(
            color: isDark 
                ? Colors.white.withOpacity(0.1) 
                : Colors.white.withOpacity(0.6),
            width: 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () {
              List<Map<String, String>>? availableStocks;
              if (allWatchlistItems != null && allWatchlistItems!.isNotEmpty) {
                availableStocks = allWatchlistItems!.map((watchlistItem) => {
                  'code': watchlistItem.code,
                  'name': watchlistItem.name,
                }).toList();
              }
              
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StockDetailScreen(
                    stockCode: item.code,
                    stockName: item.name,
                    strategy: item.strategy,
                    availableStocks: availableStocks,
                  ),
                ),
              );
            },
            splashColor: Colors.blue.withOpacity(0.1),
            highlightColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 第一行：股票基本信息
                  Row(
                    children: [
                      // 股票信息
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 股票代码和市场
                            Row(
                              children: [
                                Text(
                                  item.code,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : Colors.black,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                _buildMarketBadge(item.market),
                                // 信号标签
                                if (item.hasSignal) ...[
                                  const SizedBox(width: 8),
                                  _buildSignalBadge(item, isDark),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            // 股票名称
                            Text(
                              item.name,
                              style: TextStyle(
                                fontSize: 16,
                                color: isDark ? Colors.grey[400] : Colors.grey[700],
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.3,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      
                      // 价格信息（美化版）
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (item.currentPrice != null) ...[
                            Text(
                              '¥${item.currentPrice!.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: _getPriceColor(item.changePercent),
                                shadows: [
                                  Shadow(
                                    blurRadius: 10,
                                    color: _getPriceColor(item.changePercent).withOpacity(0.3),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (item.changePercent != null)
                              _buildPriceChangeBadge(item.changePercent!),
                          ] else ...[
                            Text(
                              '获取中...',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[500],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // 第二行：标签区域（美化版）- 同一行显示
                  Row(
                    children: [
                      // 行业标签
                      if (enhancedIndustry != null && enhancedIndustry.isNotEmpty)
                        _buildIndustryBadge(enhancedIndustry, industryColor!),
                      
                      // 策略标签
                      if (enhancedIndustry != null && enhancedIndustry.isNotEmpty)
                        const SizedBox(width: 8),
                      FutureBuilder<String>(
                        future: StrategyConfigService.getStrategyName(item.strategy),
                        builder: (context, snapshot) {
                          final strategyName = snapshot.data ?? item.strategy;
                          return _buildStrategyBadge(strategyName);
                        },
                      ),
                      
                      // 关注时长标签
                      const SizedBox(width: 8),
                      _buildWatchDurationBadge(item.watchDurationText),
                      
                      // 弹性空间，确保标签靠左对齐
                      const Expanded(child: SizedBox()),
                    ],
                  ),
                ],
              ),
            ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 构建市场标签 - 🎨 霓虹光效3D设计
  Widget _buildMarketBadge(String market) {
    final marketColor = _getMarketColor(market);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        // 🌈 多层渐变
        gradient: LinearGradient(
          colors: [
            marketColor,
            Color.lerp(marketColor, Colors.white, 0.1)!,
            marketColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(14),
        // 🎭 玻璃边框
        border: Border.all(
          color: Colors.white.withOpacity(0.6),
          width: 1.5,
        ),
        // 🌟 霓虹光晕 - 三层阴影
        boxShadow: [
          // 外层光晕
          BoxShadow(
            color: marketColor.withOpacity(0.6),
            blurRadius: 20,
            offset: const Offset(0, 0),
            spreadRadius: 2,
          ),
          // 中层光晕
          BoxShadow(
            color: marketColor.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
          // 内层阴影（3D效果）
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
            spreadRadius: -1,
          ),
        ],
      ),
      child: Center(
        child: Text(
          _getMarketShortName(market),
          style: TextStyle(
            fontSize: 11,
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            // 文字阴影增强立体感
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // 构建信号标签（买入/卖出）
  Widget _buildSignalBadge(WatchlistItem item, bool isDark) {
    final isBuy = item.hasBuySignal;
    final isSell = item.hasSellSignal;
    
    if (!isBuy && !isSell) return const SizedBox.shrink();
    
    // 买入信号：红色渐变，卖出信号：绿色渐变
    final List<Color> gradientColors = isBuy 
        ? [const Color(0xFFFF4757), const Color(0xFFFF6348)]  // 红色渐变
        : [const Color(0xFF26de81), const Color(0xFF20bf6b)]; // 绿色渐变
    
    final IconData signalIcon = isBuy ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
    final String signalText = isBuy ? '买' : '卖';
    
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: gradientColors[0].withOpacity(0.5),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                  spreadRadius: 1,
                ),
                // 添加脉冲光晕效果
                BoxShadow(
                  color: gradientColors[0].withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  signalIcon,
                  size: 14,
                  color: Colors.white,
                ),
                const SizedBox(width: 3),
                Text(
                  signalText,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    shadows: [
                      Shadow(
                        blurRadius: 4,
                        color: Colors.black26,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 构建价格变化标签 - 🎨 动态霓虹效果
  Widget _buildPriceChangeBadge(double changePercent) {
    final priceColor = _getPriceColor(changePercent);
    final isPositive = changePercent >= 0;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        // 🌈 动态渐变
        gradient: LinearGradient(
          colors: [
            priceColor,
            Color.lerp(priceColor, Colors.white, 0.2)!,
            priceColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(12),
        // 玻璃边框
        border: Border.all(
          color: Colors.white.withOpacity(0.6),
          width: 1.5,
        ),
        // 🌟 强烈的霓虹光晕
        boxShadow: [
          // 外层强光
          BoxShadow(
            color: priceColor.withOpacity(0.8),
            blurRadius: 25,
            offset: const Offset(0, 0),
            spreadRadius: 3,
          ),
          // 中层光晕
          BoxShadow(
            color: priceColor.withOpacity(0.5),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
          // 内层阴影
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
            spreadRadius: -1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPositive ? Icons.trending_up : Icons.trending_down,
            size: 13,
            color: Colors.white,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          const SizedBox(width: 4),
          Text(
            '${isPositive ? '+' : ''}${changePercent.toStringAsFixed(2)}%',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 构建行业标签（缩小版）
  Widget _buildIndustryBadge(String industry, Color color) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.2),
            color.withOpacity(0.1),
            color.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              IndustryService.getIndustryIcon(industry),
              size: 12,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            industry.length > 4 ? '${industry.substring(0, 4)}...' : industry,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  // 构建策略标签（缩小版）
  Widget _buildStrategyBadge(String strategyName) {
    // 使用现代化的渐变蓝色
    const strategyColor = Color(0xFF3B82F6); // 更现代的蓝色
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            strategyColor.withOpacity(0.15),
            const Color(0xFF60A5FA).withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: strategyColor.withOpacity(0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: strategyColor.withOpacity(0.12),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.analytics,
              size: 12,
              color: Color(0xFF2196F3),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            strategyName.length > 6 ? '${strategyName.substring(0, 6)}...' : strategyName,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF2196F3),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  // 构建关注时长标签（缩小版）- 优化为蓝色系
  Widget _buildWatchDurationBadge(String duration) {
    const durationColor = Color(0xFF6366F1); // 靛蓝色
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            durationColor.withOpacity(0.15),
            durationColor.withOpacity(0.08),
            durationColor.withOpacity(0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: durationColor.withOpacity(0.25), width: 1),
        boxShadow: [
          BoxShadow(
            color: durationColor.withOpacity(0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: durationColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.calendar_today,
              size: 12,
              color: Color(0xFF6366F1),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            duration,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF6366F1),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  // 获取市场颜色 - 统一蓝色系主题
  Color _getMarketColor(String market) {
    if (market.contains('创业板')) return const Color(0xFF3B82F6); // 蓝色
    if (market.contains('科创板')) return const Color(0xFF6366F1); // 靛蓝
    if (market.contains('北交所')) return const Color(0xFF8B5CF6); // 紫罗兰
    if (market.contains('深证主板') || market.contains('主板') && market.contains('深')) return const Color(0xFF0EA5E9); // 天蓝
    if (market.contains('上证主板') || market.contains('主板') && market.contains('上')) return const Color(0xFF2563EB); // 宝蓝
    if (market.contains('ETF')) return const Color(0xFF7C3AED); // 紫色
    if (market.contains('主板')) return const Color(0xFF3B82F6); // 通用蓝色
    return const Color(0xFF64748B); // 灰蓝
  }

  // 获取市场显示名称
  String _getMarketShortName(String market) {
    if (market.contains('创业板')) return '创业板';
    if (market.contains('科创板')) return '科创板';
    if (market.contains('北交所')) return '北交所';
    if (market.contains('ETF')) return 'ETF';
    if (market.contains('主板')) return '主板';
    return market; // 返回原始名称
  }

  // 获取价格颜色
  Color _getPriceColor(double? changePercent) {
    if (changePercent == null) return Colors.grey;
    if (changePercent > 0) return const Color(0xFFE53E3E);
    if (changePercent < 0) return const Color(0xFF38A169);
    return Colors.grey;
  }


} 