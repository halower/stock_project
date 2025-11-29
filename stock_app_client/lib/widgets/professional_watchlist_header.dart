import 'package:flutter/material.dart';

class ProfessionalWatchlistHeader extends StatelessWidget {
  final int totalCount;
  final String? selectedSignalFilter;
  final Function(String?) onSignalFilterSelected;
  final VoidCallback? onRefresh;
  final VoidCallback? onBack;
  final VoidCallback? onSort;
  final VoidCallback? onClear;
  final VoidCallback? onAddStock;
  final bool isLoading;
  final int buySignalCount;
  final int sellSignalCount;

  const ProfessionalWatchlistHeader({
    super.key,
    required this.totalCount,
    this.selectedSignalFilter,
    required this.onSignalFilterSelected,
    this.onRefresh,
    this.onBack,
    this.onSort,
    this.onClear,
    this.onAddStock,
    this.isLoading = false,
    this.buySignalCount = 0,
    this.sellSignalCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [const Color(0xFF1A1A2E), const Color(0xFF16213E)]
              : [Colors.white, const Color(0xFFF8FAFC)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
      child: Column(
          children: [
            // 顶部导航栏
            _buildAppBar(context, isDark),
            
            // 信号筛选快捷按钮
            _buildSignalFilterChips(context, isDark),
            
            // 操作按钮行
            _buildActionButtons(context, isDark),
            
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
  
  // 顶部导航栏
  Widget _buildAppBar(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          // 返回按钮
          IconButton(
              onPressed: onBack ?? () => Navigator.of(context).pop(),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark 
                    ? Colors.white.withOpacity(0.1) 
                    : Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          
          // 标题
          Expanded(
            child: Column(
              children: [
                Text(
                  '我的备选池',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$totalCount 只股票',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          // 刷新按钮
          IconButton(
            onPressed: isLoading ? null : onRefresh,
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark 
                    ? Colors.white.withOpacity(0.1) 
                    : Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: isLoading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    )
                  : Icon(
                      Icons.refresh_rounded,
                      size: 18,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // 信号筛选快捷按钮
  Widget _buildSignalFilterChips(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // 全部
          Expanded(
            child: _buildFilterChip(
              context: context,
              label: '全部',
              count: null,
              isSelected: selectedSignalFilter == null,
              onTap: () => onSignalFilterSelected(null),
              isDark: isDark,
              gradientColors: [
                const Color(0xFF667EEA),
                const Color(0xFF764BA2),
              ],
              icon: Icons.apps_rounded,
            ),
          ),
          const SizedBox(width: 10),
          
          // 买入信号
          Expanded(
            child: _buildFilterChip(
              context: context,
              label: '买入',
              count: buySignalCount,
              isSelected: selectedSignalFilter == 'buy',
              onTap: () => onSignalFilterSelected('buy'),
              isDark: isDark,
              gradientColors: [
                const Color(0xFFFF4757),
                const Color(0xFFFF6348),
              ],
              icon: Icons.trending_up_rounded,
            ),
          ),
          const SizedBox(width: 10),
          
          // 卖出信号
          Expanded(
            child: _buildFilterChip(
              context: context,
              label: '卖出',
              count: sellSignalCount,
              isSelected: selectedSignalFilter == 'sell',
              onTap: () => onSignalFilterSelected('sell'),
              isDark: isDark,
              gradientColors: [
                const Color(0xFF26de81),
                const Color(0xFF20bf6b),
              ],
              icon: Icons.trending_down_rounded,
            ),
          ),
        ],
      ),
    );
  }

  // 单个筛选芯片
  Widget _buildFilterChip({
    required BuildContext context,
    required String label,
    required int? count,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    required List<Color> gradientColors,
    required IconData icon,
  }) {
    return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF2A2A3E), const Color(0xFF252538)]
                      : [Colors.white, const Color(0xFFF5F5F5)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          borderRadius: BorderRadius.circular(14),
            border: Border.all(
            color: isSelected
                ? Colors.white.withOpacity(0.3)
                : isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.06),
              width: 1.5,
            ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: gradientColors[0].withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
              BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
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
              size: 16,
              color: isSelected
                  ? Colors.white
                  : isDark
                      ? Colors.white60
                      : Colors.black54,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : isDark
                        ? Colors.white70
                        : Colors.black87,
              ),
            ),
            if (count != null && count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.25)
                      : gradientColors[0].withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : gradientColors[0],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 操作按钮行
  Widget _buildActionButtons(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          // 添加按钮 - 主要操作
          Expanded(
            flex: 2,
            child: _buildActionButton(
      context: context,
              icon: Icons.add_rounded,
              label: '添加',
              onTap: onAddStock,
              isDark: isDark,
              isPrimary: true,
            ),
                  ),
                  const SizedBox(width: 8),
          
          // 排序按钮
          Expanded(
            child: _buildActionButton(
              context: context,
              icon: Icons.swap_vert_rounded,
              label: '排序',
              onTap: onSort,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 8),
          
          // 清空按钮
          Expanded(
            child: _buildActionButton(
              context: context,
              icon: Icons.delete_outline_rounded,
              label: '清空',
              onTap: onClear,
                  isDark: isDark,
              isDestructive: true,
              ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    required bool isDark,
    bool isDestructive = false,
    bool isPrimary = false,
  }) {
    final Color primaryColor = isPrimary
        ? const Color(0xFF6366F1)
        : isDestructive
            ? const Color(0xFFEF4444)
            : isDark
                ? Colors.white70
                : Colors.black54;
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          gradient: isPrimary
              ? const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isPrimary
              ? null
              : isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: isPrimary
              ? null
              : Border.all(
                  color: isDestructive
                      ? const Color(0xFFEF4444).withOpacity(0.3)
                      : isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.08),
                  width: 1,
                ),
          boxShadow: isPrimary
              ? [
              BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: isPrimary ? Colors.white : primaryColor,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isPrimary ? Colors.white : primaryColor,
              ),
              ),
          ],
        ),
      ),
    );
  }
}
