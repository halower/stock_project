import 'package:flutter/material.dart';
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
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF1E1E1E),
                    const Color(0xFF2D2D2D),
                  ]
                : [
                    Colors.white,
                    const Color(0xFFF8F9FA),
                  ],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: isDark 
                  ? Colors.black.withOpacity(0.6)
                  : Colors.grey.withOpacity(0.15),
              blurRadius: 25,
              offset: const Offset(0, 12),
              spreadRadius: 0,
            ),
          ],
          border: Border.all(
            color: isDark 
                ? Colors.white.withOpacity(0.08) 
                : Colors.grey.withOpacity(0.08),
            width: 1.5,
          ),
        ),
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
                      // 左侧行业色块指示器（美化版）
                      if (industryColor != null)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          width: 5,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                industryColor,
                                industryColor.withOpacity(0.8),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: industryColor.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      if (industryColor != null) const SizedBox(width: 16),
                      
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
    );
  }

  // 构建市场标签（缩小版）
  Widget _buildMarketBadge(String market) {
    final marketColor = _getMarketColor(market);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            marketColor,
            Color.lerp(marketColor, Colors.black, 0.1)!,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.4), width: 1),
        boxShadow: [
          BoxShadow(
            color: marketColor.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Center(
        child: Text(
          _getMarketShortName(market),
          style: const TextStyle(
            fontSize: 11,
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  // 构建价格变化标签（缩小版）
  Widget _buildPriceChangeBadge(double changePercent) {
    final priceColor = _getPriceColor(changePercent);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            priceColor,
            Color.lerp(priceColor, Colors.black, 0.15)!,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: priceColor.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            changePercent >= 0 ? Icons.trending_up : Icons.trending_down,
            size: 12,
            color: Colors.white,
          ),
          const SizedBox(width: 3),
          Text(
            '${changePercent >= 0 ? '+' : ''}${changePercent.toStringAsFixed(2)}%',
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
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
    const strategyColor = Color(0xFF2196F3);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            strategyColor.withOpacity(0.2),
            strategyColor.withOpacity(0.1),
            strategyColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: strategyColor.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: strategyColor.withOpacity(0.15),
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
              color: strategyColor.withOpacity(0.2),
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

  // 构建关注时长标签（缩小版）
  Widget _buildWatchDurationBadge(String duration) {
    const durationColor = Color(0xFF8E24AA);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            durationColor.withOpacity(0.2),
            durationColor.withOpacity(0.1),
            durationColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: durationColor.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: durationColor.withOpacity(0.15),
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
              color: durationColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.calendar_today,
              size: 12,
              color: Color(0xFF8E24AA),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            duration,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF8E24AA),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  // 获取市场颜色
  Color _getMarketColor(String market) {
    if (market.contains('创业板')) return const Color(0xFFFF9800);
    if (market.contains('科创板')) return const Color(0xFFE91E63);
    if (market.contains('北交所')) return const Color(0xFF9C27B0);
    if (market.contains('深证主板') || market.contains('主板') && market.contains('深')) return const Color(0xFF4CAF50);
    if (market.contains('上证主板') || market.contains('主板') && market.contains('上')) return const Color(0xFF2196F3);
    if (market.contains('ETF')) return const Color(0xFF9C27B0); // ETF使用紫色
    if (market.contains('主板')) return const Color(0xFF3B82F6); // 通用的主板颜色
    return const Color(0xFF607D8B);
  }

  // 获取市场显示名称（使用完整名称）
  String _getMarketShortName(String market) {
    if (market.contains('创业板')) return '创业板';
    if (market.contains('科创板')) return '科创板';
    if (market.contains('北交所')) return '北交所';
    if (market.contains('深证主板') || market.contains('主板') && market.contains('深')) return '深主板';
    if (market.contains('上证主板') || market.contains('主板') && market.contains('上')) return '沪主板';
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