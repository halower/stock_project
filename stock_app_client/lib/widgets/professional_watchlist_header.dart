import 'package:flutter/material.dart';

class ProfessionalWatchlistHeader extends StatelessWidget {
  final int totalCount;
  final String? selectedMarket;
  final Function(String?) onMarketSelected;
  final VoidCallback? onRefresh;
  final VoidCallback? onBack;
  final VoidCallback? onSort;
  final VoidCallback? onClear;
  final bool isLoading;

  const ProfessionalWatchlistHeader({
    super.key,
    required this.totalCount,
    this.selectedMarket,
    required this.onMarketSelected,
    this.onRefresh,
    this.onBack,
    this.onSort,
    this.onClear,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).cardColor,
      child: Column(
        children: [
          // 导航栏
          AppBar(
            title: Text('我的备选池 ($totalCount)'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: onBack ?? () => Navigator.of(context).pop(),
            ),
            actions: [
              // 刷新按钮
              if (onRefresh != null)
                IconButton(
                  icon: isLoading 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                  onPressed: isLoading ? null : onRefresh,
                ),
            ],
          ),
          
          // 操作按钮行
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // 市场筛选按钮
                Expanded(
                  child: _buildActionButton(
                    context,
                    icon: Icons.filter_list,
                    label: '市场',
                    onTap: () => _showFilterDialog(context),
                  ),
                ),
                const SizedBox(width: 8),
                
                // 排序按钮  
                Expanded(
                  child: _buildActionButton(
                    context,
                    icon: Icons.sort,
                    label: '排序',
                    onTap: onSort,
                  ),
                ),
                const SizedBox(width: 8),
                
                // 清空按钮
                Expanded(
                  child: _buildActionButton(
                    context,
                    icon: Icons.delete_sweep,
                    label: '清空',
                    onTap: onClear,
                    isDestructive: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    bool isDestructive = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDestructive
                  ? [
                      Colors.red.withOpacity(0.15),
                      Colors.red.withOpacity(0.08),
                    ]
                  : [
                      primaryColor.withOpacity(0.15),
                      primaryColor.withOpacity(0.08),
                    ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDestructive
                  ? Colors.red.withOpacity(0.3)
                  : primaryColor.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (isDestructive ? Colors.red : primaryColor).withOpacity(0.1),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isDestructive ? Colors.red : primaryColor,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDestructive ? Colors.red : primaryColor,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              Row(
                children: [
                  Icon(
                    Icons.filter_list,
                    color: Theme.of(context).primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '选择市场',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // 市场选项
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  '全部', '主板', '创业板', '科创板', '北交所', 'ETF'
                ].map((market) => _buildMarketChip(
                  market: market,
                  isSelected: selectedMarket == market || 
                            (market == '全部' && selectedMarket == null),
                  onTap: () {
                    onMarketSelected(market == '全部' ? null : market);
                    Navigator.pop(context);
                  },
                  isDark: isDark,
                )).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMarketChip({
    required String market,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final marketColor = _getMarketColor(market);
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    marketColor,
                    Color.lerp(marketColor, Colors.black, 0.1)!,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              : LinearGradient(
                  colors: [
                    isDark ? const Color(0xFF2D2D2D) : Colors.grey.withOpacity(0.1),
                    isDark ? const Color(0xFF252525) : Colors.grey.withOpacity(0.05),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? Colors.white.withOpacity(0.4)
                : isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: marketColor.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Text(
          market,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : Colors.grey[700]),
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  Color _getMarketColor(String market) {
    switch (market) {
      case '主板':
        return const Color(0xFF3B82F6);
      case '创业板':
        return const Color(0xFFFF9800);
      case '科创板':
        return const Color(0xFFE91E63);
      case '北交所':
        return const Color(0xFF9C27B0);
      case 'ETF':
        return const Color(0xFF8E24AA);
      default: // 全部
        return const Color(0xFF2196F3);
    }
  }
} 