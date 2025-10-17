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
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark 
                ? Colors.black.withOpacity(0.4)
                : Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
        border: Border.all(
          color: isDark 
              ? Colors.white.withOpacity(0.1) 
              : Colors.grey.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            // 准备股票列表数据，如果有备选池列表就使用，否则为null
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
                  availableStocks: availableStocks, // 传递备选池股票列表
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 第一行：股票基本信息
                Row(
                  children: [
                    // 左侧行业色块指示器
                    if (industryColor != null)
                      Container(
                        width: 4,
                        height: 40,
                        decoration: BoxDecoration(
                          color: industryColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    if (industryColor != null) const SizedBox(width: 12),
                    
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
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 10),
                              _buildMarketBadge(item.market),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // 股票名称
                          Text(
                            item.name,
                            style: TextStyle(
                              fontSize: 16,
                              color: isDark ? Colors.grey[300] : Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // 价格信息
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (item.currentPrice != null) ...[
                          Text(
                            '¥${item.currentPrice!.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _getPriceColor(item.changePercent),
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (item.changePercent != null)
                            _buildPriceChangeBadge(item.changePercent!),
                        ] else ...[
                          Text(
                            '获取中...',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // 第二行：标签区域（分开显示，避免拥挤）
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // 行业标签（使用增强的行业信息）
                    if (enhancedIndustry != null && enhancedIndustry.isNotEmpty)
                      _buildIndustryBadge(enhancedIndustry, industryColor!),
                    
                    // 策略标签
                    FutureBuilder<String>(
                      future: StrategyConfigService.getStrategyName(item.strategy),
                      builder: (context, snapshot) {
                        final strategyName = snapshot.data ?? item.strategy;
                        return _buildStrategyBadge(strategyName);
                      },
                    ),
                    
                    // 关注时长标签
                    _buildWatchDurationBadge(item.watchDurationText),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 构建市场标签
  Widget _buildMarketBadge(String market) {
    return Container(
      height: 32, // 统一高度
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getMarketColor(market),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: _getMarketColor(market).withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          _getMarketShortName(market),
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // 构建价格变化标签
  Widget _buildPriceChangeBadge(double changePercent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _getPriceColor(changePercent),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '${changePercent >= 0 ? '+' : ''}${changePercent.toStringAsFixed(2)}%',
        style: const TextStyle(
          fontSize: 12,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // 构建行业标签（升级版，使用更好的图标和样式）
  Widget _buildIndustryBadge(String industry, Color color) {
    return Container(
      height: 32, // 统一高度
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            IndustryService.getIndustryIcon(industry),
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            industry.length > 6 ? '${industry.substring(0, 6)}...' : industry,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  // 构建策略标签
  Widget _buildStrategyBadge(String strategyName) {
    return Container(
      height: 32, // 统一高度
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF2196F3).withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2196F3).withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2196F3).withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.timeline,
            size: 14,
            color: Color(0xFF2196F3),
          ),
          const SizedBox(width: 4),
          Text(
            strategyName.length > 10 ? '${strategyName.substring(0, 10)}...' : strategyName,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF2196F3),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // 构建关注时长标签（美化颜色）
  Widget _buildWatchDurationBadge(String duration) {
    return Container(
      height: 32, // 统一高度
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF8E24AA).withOpacity(0.15), // 紫色渐变
            const Color(0xFF7B1FA2).withOpacity(0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF8E24AA).withOpacity(0.4), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8E24AA).withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.schedule,
            size: 14,
            color: Color(0xFF8E24AA),
          ),
          const SizedBox(width: 4),
          Text(
            duration,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF8E24AA),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
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

  // 获取市场简称
  String _getMarketShortName(String market) {
    if (market.contains('创业板')) return '创';
    if (market.contains('科创板')) return '科';
    if (market.contains('北交所')) return '北';
    if (market.contains('深证主板') || market.contains('主板') && market.contains('深')) return '深';
    if (market.contains('上证主板') || market.contains('主板') && market.contains('上')) return '沪';
    if (market.contains('ETF')) return '指';
    if (market.contains('主板')) return '主'; // 通用的主板标识
    return '其他';
  }

  // 获取价格颜色
  Color _getPriceColor(double? changePercent) {
    if (changePercent == null) return Colors.grey;
    if (changePercent > 0) return const Color(0xFFE53E3E);
    if (changePercent < 0) return const Color(0xFF38A169);
    return Colors.grey;
  }


} 