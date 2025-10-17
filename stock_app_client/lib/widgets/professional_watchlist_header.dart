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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isDestructive 
            ? Colors.red.withOpacity(0.1)
            : Theme.of(context).primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDestructive 
              ? Colors.red.withOpacity(0.3)
              : Theme.of(context).primaryColor.withOpacity(0.3),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 20,
              color: isDestructive 
                ? Colors.red
                : Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDestructive 
                  ? Colors.red
                  : Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择市场'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            '全部', '主板', '创业板', '科创板', '北交所'
          ].map((market) => ListTile(
            title: Text(market),
            onTap: () {
              onMarketSelected(market == '全部' ? null : market);
              Navigator.pop(context);
            },
            selected: selectedMarket == market || 
                     (market == '全部' && selectedMarket == null),
          )).toList(),
        ),
      ),
    );
  }
} 