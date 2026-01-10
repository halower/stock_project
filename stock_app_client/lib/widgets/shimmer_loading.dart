import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../utils/design_system.dart';

/// 金融应用专用骨架屏组件
/// 提供多种预设样式，适用于不同场景

class ShimmerLoading extends StatelessWidget {
  final Widget child;
  final bool isLoading;
  final Color? baseColor;
  final Color? highlightColor;

  const ShimmerLoading({
    super.key,
    required this.child,
    this.isLoading = true,
    this.baseColor,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLoading) return child;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Shimmer.fromColors(
      baseColor: baseColor ?? (isDark ? const Color(0xFF1A1A1A) : const Color(0xFFE8E8E8)),
      highlightColor: highlightColor ?? (isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF5F5F5)),
      period: const Duration(milliseconds: 1500),
      child: child,
    );
  }
}

/// 股票列表项骨架屏
class StockListItemSkeleton extends StatelessWidget {
  const StockListItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ShimmerLoading(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // 股票代码和名称区域
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildShimmerBox(width: 80, height: 16, isDark: isDark),
                  const SizedBox(height: 6),
                  _buildShimmerBox(width: 50, height: 12, isDark: isDark),
                ],
              ),
            ),
            // 价格区域
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildShimmerBox(width: 70, height: 18, isDark: isDark),
                  const SizedBox(height: 6),
                  _buildShimmerBox(width: 50, height: 12, isDark: isDark),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // 涨跌幅区域
            _buildShimmerBox(width: 70, height: 32, isDark: isDark, borderRadius: 6),
          ],
        ),
      ),
    );
  }
}

/// 股票列表骨架屏（多条）
class StockListSkeleton extends StatelessWidget {
  final int itemCount;
  
  const StockListSkeleton({
    super.key,
    this.itemCount = 8,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: itemCount,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: Theme.of(context).dividerColor.withOpacity(0.5),
      ),
      itemBuilder: (context, index) => const StockListItemSkeleton(),
    );
  }
}

/// K线图骨架屏
class KLineChartSkeleton extends StatelessWidget {
  final double height;
  
  const KLineChartSkeleton({
    super.key,
    this.height = 300,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ShimmerLoading(
      child: Container(
        height: height,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 顶部标题区域
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildShimmerBox(width: 120, height: 20, isDark: isDark),
                _buildShimmerBox(width: 80, height: 16, isDark: isDark),
              ],
            ),
            const SizedBox(height: 20),
            // 图表区域
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(20, (index) {
                  // 模拟K线的随机高度
                  final height = 30.0 + (index * 7 % 100);
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _buildShimmerBox(
                            width: double.infinity,
                            height: height,
                            isDark: isDark,
                            borderRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),
            // 底部时间轴
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(5, (index) => 
                _buildShimmerBox(width: 40, height: 10, isDark: isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 数据卡片骨架屏
class DataCardSkeleton extends StatelessWidget {
  final double height;
  
  const DataCardSkeleton({
    super.key,
    this.height = 120,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ShimmerLoading(
      child: Container(
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFE8E8E8),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildShimmerBox(width: 100, height: 18, isDark: isDark),
                _buildShimmerBox(width: 60, height: 14, isDark: isDark),
              ],
            ),
            const Spacer(),
            // 主要数据
            _buildShimmerBox(width: 150, height: 32, isDark: isDark),
            const SizedBox(height: 8),
            // 辅助数据
            Row(
              children: [
                _buildShimmerBox(width: 80, height: 14, isDark: isDark),
                const SizedBox(width: 16),
                _buildShimmerBox(width: 60, height: 14, isDark: isDark),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 指标网格骨架屏
class MetricsGridSkeleton extends StatelessWidget {
  final int crossAxisCount;
  final int itemCount;
  
  const MetricsGridSkeleton({
    super.key,
    this.crossAxisCount = 2,
    this.itemCount = 6,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ShimmerLoading(
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 2.2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        itemCount: itemCount,
        itemBuilder: (context, index) => Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildShimmerBox(width: 50, height: 10, isDark: isDark),
              const SizedBox(height: 6),
              _buildShimmerBox(width: 70, height: 16, isDark: isDark),
            ],
          ),
        ),
      ),
    );
  }
}

/// 交易记录骨架屏
class TradeRecordSkeleton extends StatelessWidget {
  const TradeRecordSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ShimmerLoading(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFE8E8E8),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部：股票名称和日期
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _buildShimmerBox(width: 24, height: 24, isDark: isDark, borderRadius: 4),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildShimmerBox(width: 80, height: 16, isDark: isDark),
                        const SizedBox(height: 4),
                        _buildShimmerBox(width: 50, height: 12, isDark: isDark),
                      ],
                    ),
                  ],
                ),
                _buildShimmerBox(width: 70, height: 14, isDark: isDark),
              ],
            ),
            const SizedBox(height: 16),
            // 中间：价格和数量
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMetricColumn(isDark),
                _buildMetricColumn(isDark),
                _buildMetricColumn(isDark),
              ],
            ),
            const SizedBox(height: 12),
            // 底部：盈亏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildShimmerBox(width: 60, height: 14, isDark: isDark),
                  _buildShimmerBox(width: 100, height: 20, isDark: isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMetricColumn(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildShimmerBox(width: 40, height: 10, isDark: isDark),
        const SizedBox(height: 4),
        _buildShimmerBox(width: 60, height: 16, isDark: isDark),
      ],
    );
  }
}

/// 交易记录列表骨架屏
class TradeRecordListSkeleton extends StatelessWidget {
  final int itemCount;
  
  const TradeRecordListSkeleton({
    super.key,
    this.itemCount = 5,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: itemCount,
      itemBuilder: (context, index) => const TradeRecordSkeleton(),
    );
  }
}

/// 新闻列表骨架屏
class NewsListSkeleton extends StatelessWidget {
  final int itemCount;
  
  const NewsListSkeleton({
    super.key,
    this.itemCount = 6,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ShimmerLoading(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFE8E8E8),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              _buildShimmerBox(width: double.infinity, height: 18, isDark: isDark),
              const SizedBox(height: 8),
              _buildShimmerBox(width: 200, height: 18, isDark: isDark),
              const SizedBox(height: 12),
              // 摘要
              _buildShimmerBox(width: double.infinity, height: 14, isDark: isDark),
              const SizedBox(height: 4),
              _buildShimmerBox(width: double.infinity, height: 14, isDark: isDark),
              const SizedBox(height: 4),
              _buildShimmerBox(width: 150, height: 14, isDark: isDark),
              const SizedBox(height: 12),
              // 底部信息
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildShimmerBox(width: 80, height: 12, isDark: isDark),
                  _buildShimmerBox(width: 60, height: 12, isDark: isDark),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 大盘分析骨架屏
class IndexAnalysisSkeleton extends StatelessWidget {
  const IndexAnalysisSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: const [
          // 图表区域
          KLineChartSkeleton(height: 350),
          SizedBox(height: 16),
          // 核心指标卡片
          DataCardSkeleton(height: 180),
          SizedBox(height: 8),
          // 关键点位
          DataCardSkeleton(height: 200),
          SizedBox(height: 8),
          // 技术分析
          DataCardSkeleton(height: 160),
        ],
      ),
    );
  }
}

/// 全屏加载骨架屏
class FullScreenSkeleton extends StatelessWidget {
  final String? message;
  
  const FullScreenSkeleton({
    super.key,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      color: isDark ? const Color(0xFF000000) : const Color(0xFFF8FAFC),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 动态脉冲Logo
            _PulsingLogoSkeleton(isDark: isDark),
            if (message != null) ...[
              const SizedBox(height: 24),
              Text(
                message!,
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.black54,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 脉冲Logo骨架
class _PulsingLogoSkeleton extends StatefulWidget {
  final bool isDark;
  
  const _PulsingLogoSkeleton({required this.isDark});

  @override
  State<_PulsingLogoSkeleton> createState() => _PulsingLogoSkeletonState();
}

class _PulsingLogoSkeletonState extends State<_PulsingLogoSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppDesignSystem.primary.withOpacity(0.3 * _animation.value),
                  AppDesignSystem.primary.withOpacity(0.1),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppDesignSystem.primary.withOpacity(0.2 * _animation.value),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(
              Icons.trending_up,
              size: 40,
              color: AppDesignSystem.primary.withOpacity(0.6 + 0.4 * _animation.value),
            ),
          ),
        );
      },
    );
  }
}

/// 辅助方法：创建骨架盒子
Widget _buildShimmerBox({
  required double width,
  required double height,
  required bool isDark,
  double borderRadius = 4,
}) {
  return Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFE8E8E8),
      borderRadius: BorderRadius.circular(borderRadius),
    ),
  );
}

/// 估值分析列表骨架屏
class ValuationListSkeleton extends StatelessWidget {
  const ValuationListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 8,
      itemBuilder: (context, index) {
        return const ValuationCardSkeleton();
      },
    );
  }
}

/// 估值卡片骨架屏
class ValuationCardSkeleton extends StatelessWidget {
  const ValuationCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ShimmerLoading(
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部：股票名称和价格
              Row(
                children: [
                  // 股票名称
                  Container(
                    width: 100,
                    height: 18,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFE8E8E8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const Spacer(),
                  // 价格和涨跌幅
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        width: 70,
                        height: 16,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFE8E8E8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 50,
                        height: 13,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFE8E8E8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 代码和市值
              Container(
                width: 150,
                height: 12,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFE8E8E8),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 12),
              // 估值标签行
              Row(
                children: [
                  _buildTagSkeleton(isDark),
                  const SizedBox(width: 8),
                  _buildTagSkeleton(isDark),
                  const SizedBox(width: 8),
                  _buildTagSkeleton(isDark),
                  const SizedBox(width: 8),
                  _buildTagSkeleton(isDark),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTagSkeleton(bool isDark) {
    return Container(
      width: 60,
      height: 24,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFE8E8E8),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

