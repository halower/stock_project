import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/trade_record.dart';
import '../services/providers/trade_provider.dart';
import '../widgets/shimmer_loading.dart';
import 'add_trade_screen.dart';
import 'settlement_screen.dart';

class TradeRecordScreen extends StatefulWidget {
  const TradeRecordScreen({super.key});

  @override
  State<TradeRecordScreen> createState() => _TradeRecordScreenState();
}

class _TradeRecordScreenState extends State<TradeRecordScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _dataLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // 只有2个Tab
    
    // ✅ 懒加载：切换到此Tab时才加载交易记录
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_dataLoaded && mounted) {
        _dataLoaded = true;
        debugPrint('🔄 交易记录Tab：首次加载数据...');
        context.read<TradeProvider>().loadTradeRecords();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF000000) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            // 在移动设备模式下，这个页面需要自己的菜单按钮
            // 通过Builder获取正确的context来访问HomeScreen的Scaffold
            Scaffold.of(context).openDrawer();
          },
        ),
        title: const Text(
          '交易记录',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF1976D2),
                  Color(0xFF0D47A1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1976D2).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddTradeScreen()),
              );
            },
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF667EEA),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF667EEA),
          indicatorWeight: 3,
          tabs: const [
            Tab(text: '交易计划'),
            Tab(text: '交割单'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTradePlansTab(),
          _buildSettlementsTab(),
        ],
      ),
    );
  }

  Widget _buildTradePlansTab() {
    return Consumer<TradeProvider>(
      builder: (context, tradeProvider, child) {
        if (tradeProvider.isLoading) {
          // 使用骨架屏替代简单的加载圈
          return const TradeRecordListSkeleton(itemCount: 5);
        }

        final tradePlans = tradeProvider.tradeRecords.where((record) => 
          record.category == TradeCategory.plan).toList();
        
        if (tradePlans.isEmpty) {
          return _buildEmptyState(
            icon: Icons.assignment_outlined,
            title: '暂无交易计划',
            subtitle: '点击右上角 + 号创建新的交易计划',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: tradePlans.length,
          itemBuilder: (context, index) {
            final record = tradePlans[index];
            return ModernTradeRecordCard(
              record: record,
              onExecute: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SettlementScreen(tradePlan: record),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSettlementsTab() {
    return Consumer<TradeProvider>(
      builder: (context, tradeProvider, child) {
        if (tradeProvider.isLoading) {
          // 使用骨架屏替代简单的加载圈
          return const TradeRecordListSkeleton(itemCount: 5);
        }

        final settlements = tradeProvider.tradeRecords.where((record) => 
          record.status == TradeStatus.completed && record.category == TradeCategory.settlement).toList();
        
        if (settlements.isEmpty) {
          return _buildEmptyState(
            icon: Icons.receipt_long_outlined,
            title: '暂无交割单',
            subtitle: '完成交易计划后将生成交割单',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: settlements.length,
          itemBuilder: (context, index) {
            final record = settlements[index];
            return Dismissible(
              key: ValueKey(record.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B6B), Color(0xFFEE5A52)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(Icons.delete_outline, color: Colors.white, size: 24),
                    SizedBox(width: 8),
                    Text(
                      '删除',
                      style: TextStyle(
                  color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                        ),
                      ],
                ),
              ),
              onDismissed: (direction) {
                context.read<TradeProvider>().deleteTradeRecord(record.id!);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('已删除${record.stockName}(${record.stockCode})的交割单'),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
              child: ModernTradeRecordCard(
                record: record,
                onExecute: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SettlementScreen(tradePlan: record),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWeekendRecordsTab() {
    return Consumer<TradeProvider>(
      builder: (context, tradeProvider, child) {
        if (tradeProvider.isLoading) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF667EEA)),
                ),
                SizedBox(height: 16),
                Text('加载周末记录中...'),
              ],
            ),
          );
        }

        final weekendRecords = tradeProvider.weekendTradeRecords;
        
        if (weekendRecords.isEmpty) {
          return _buildEmptyState(
            icon: Icons.weekend_outlined,
            title: '暂无周末记录',
            subtitle: '周末交易记录会在此处显示',
          );
        }

        return Column(
          children: [
            // 添加批量删除按钮
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: () => _confirmDeleteAllWeekendRecords(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                ),
                icon: const Icon(Icons.delete_sweep),
                label: const Text('删除所有周末记录'),
              ),
            ),
            
            // 显示周末记录列表
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: weekendRecords.length,
                itemBuilder: (context, index) {
                  final record = weekendRecords[index];
                  return Dismissible(
                    key: ValueKey(record.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B6B), Color(0xFFEE5A52)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(Icons.delete_outline, color: Colors.white, size: 24),
                          SizedBox(width: 8),
                          Text(
                            '删除',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    onDismissed: (direction) {
                      context.read<TradeProvider>().deleteTradeRecord(record.id!);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('已删除${record.stockName}(${record.stockCode})的周末记录'),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    },
                    child: ModernTradeRecordCard(
                      record: record,
                      onExecute: null, // 周末记录不能执行
                      isWeekendRecord: true, // 标记为周末记录
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
  
  // 确认删除所有周末记录
  Future<void> _confirmDeleteAllWeekendRecords(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                color: Colors.red.shade600,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text('确认删除'),
          ],
        ),
        content: const Text('确定要删除所有周末交易记录吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('取消', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('确定删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await context.read<TradeProvider>().deleteAllWeekendRecords();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已删除所有周末交易记录'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.grey.shade100,
                  Colors.grey.shade50,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              icon,
              size: 64,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class ModernTradeRecordCard extends StatelessWidget {
  final TradeRecord record;
  final VoidCallback? onExecute;
  final bool isWeekendRecord; // 新增参数，用于区分周末记录

  const ModernTradeRecordCard({
    super.key,
    required this.record,
    this.onExecute,
    this.isWeekendRecord = false, // 默认不是周末记录
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    // A股色彩风格：红涨绿跌
    final profitColor = (record.netProfit ?? 0) >= 0 ? const Color(0xFFDC2626) : const Color(0xFF059669);

    // 计算动态盈亏比
    double profitRiskRatio = 0.0;
    if (record.planPrice != null && record.stopLossPrice != null && record.takeProfitPrice != null) {
      final riskPerUnit = (record.planPrice! - record.stopLossPrice!).abs();
      final rewardPerUnit = (record.takeProfitPrice! - record.planPrice!).abs();
      
      if (riskPerUnit > 0) {
        profitRiskRatio = rewardPerUnit / riskPerUnit;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode 
              ? [
                  const Color(0xFF2C2C2E),
                  const Color(0xFF1C1C1E),
                ]
              : [
                  Colors.white,
                  const Color(0xFFFAFAFA),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDarkMode 
                ? Colors.black.withOpacity(0.3)
                : Colors.grey.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: isDarkMode 
                ? Colors.white.withOpacity(0.02)
                : Colors.white.withOpacity(0.8),
            blurRadius: 1,
            offset: const Offset(0, 1),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
      child: InkWell(
          borderRadius: BorderRadius.circular(20),
        onTap: onExecute,
        child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 顶部：股票信息和状态
                Row(
                  children: [
                    // 股票代码和名称
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF667EEA).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFF667EEA).withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  record.stockCode,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF667EEA),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                record.stockName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                              
                              // 添加周末记录标记
                              if (isWeekendRecord || record.isWeekendRecord)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '周末',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red.shade800,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // 交易状态标识
                    _buildStatusBadge(context),
                  ],
                ),
              
              const SizedBox(height: 16),
                
                // 市场阶段和趋势强度标签
                if (record.marketPhase != null || record.trendStrength != null) ...[
              Row(
                    children: [
                      if (record.marketPhase != null) ...[
                        _buildModernChip(
                          _getMarketPhaseText(record.marketPhase!),
                          _getMarketPhaseColor(record.marketPhase!),
                      ),
                        const SizedBox(width: 8),
                      ],
                      if (record.trendStrength != null)
                        _buildModernChip(
                          _getTrendStrengthText(record.trendStrength!),
                          _getTrendStrengthColor(record.trendStrength!),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                
                // 价格信息网格
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDarkMode 
                        ? Colors.grey.shade800.withOpacity(0.2)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDarkMode 
                          ? Colors.grey.shade700.withOpacity(0.3)
                          : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                                                      Expanded(
                              child: _buildInfoItem(
                                '进场价格',
                                '¥${record.planPrice?.toStringAsFixed(2) ?? '0.00'}',
                                Icons.gps_fixed,
                              ),
                            ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildInfoItem(
                              '计划数量',
                              '${record.planQuantity}股',
                              Icons.layers,
                            ),
                          ),
                        ],
                      ),
                      
                      if (record.actualPrice != null && record.actualQuantity != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoItem(
                                '出场价格',
                                '¥${record.actualPrice!.toStringAsFixed(2)}',
                                Icons.check_circle,
                                valueColor: profitColor,
                              ),
                        ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildInfoItem(
                                '实际数量',
                                '${record.actualQuantity}股',
                                Icons.done_all,
                                valueColor: profitColor,
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoItem(
                                '止损价',
                                '¥${record.stopLossPrice?.toStringAsFixed(2) ?? '0.00'}',
                                Icons.trending_down,
                                valueColor: const Color(0xFF059669), // A股绿色：止损
                              ),
                        ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildInfoItem(
                                '目标价',
                                '¥${record.takeProfitPrice?.toStringAsFixed(2) ?? '0.00'}',
                                Icons.trending_up,
                                valueColor: const Color(0xFFDC2626), // A股红色：止盈
                        ),
                            ),
                          ],
                        ),
                      ],
                      
                      if (record.positionPercentage != null) ...[
                        const SizedBox(height: 12),
                        _buildInfoItem(
                          '仓位占比',
                          '${record.positionPercentage}%',
                          Icons.pie_chart,
                            ),
                      ],
                    ],
                  ),
              ),
              
                // 盈亏信息（如果有）
              if (record.netProfit != null) ...[
                const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: (record.netProfit ?? 0) >= 0 
                            ? [
                                const Color(0xFFDC2626).withOpacity(0.1),
                                const Color(0xFFDC2626).withOpacity(0.05),
                              ]
                            : [
                                const Color(0xFF059669).withOpacity(0.1),
                                const Color(0xFF059669).withOpacity(0.05),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                    ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: profitColor.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: profitColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            (record.netProfit ?? 0) >= 0 ? Icons.trending_up : Icons.trending_down,
                            color: profitColor,
                            size: 20,
                          ),
                    ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                                '交易盈亏',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                      ),
                              const SizedBox(height: 2),
                      Text(
                                '¥${record.netProfit!.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                              color: profitColor,
                            ),
                      ),
                    ],
                  ),
                        ),
                        if (record.profitRate != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                                '收益率',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                      ),
                              const SizedBox(height: 2),
                      Text(
                                '${record.profitRate!.toStringAsFixed(2)}%',
                                style: TextStyle(
                                  fontSize: 16,
                              fontWeight: FontWeight.bold,
                                  color: profitColor,
                            ),
                      ),
                    ],
                  ),
                ],
                    ),
                  ),
                ],
                
                // 盈亏比信息（如果有）
                if (profitRiskRatio > 0) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.balance,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '盈亏比: ',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                            ),
                      ),
                      Text(
                        profitRiskRatio.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 14,
                              fontWeight: FontWeight.bold,
                          color: profitRiskRatio >= 3 ? const Color(0xFFDC2626) : Colors.orange,
                            ),
                      ),
                    ],
                  ),
                ],
                
                // 时间信息
                const SizedBox(height: 16),
                  Row(
                    children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 6),
                      Text(
                      DateFormat('yyyy-MM-dd HH:mm').format(record.tradeDate),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const Spacer(),
                    if (record.status == TradeStatus.pending)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 12,
                              color: Colors.orange.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '待执行',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                      ),
              ],
                ),
                ],
              ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildStatusBadge(BuildContext context) {
    Color bgColor = Colors.grey.withOpacity(0.1);
    Color textColor = Colors.grey;
    IconData icon = Icons.help_outline;
    String text = '未知';

    // 内部函数用于设置交易类型显示
    void setTradeTypeDisplay() {
    if (record.status == TradeStatus.completed) {
      final isProfit = (record.netProfit ?? 0) >= 0;
      bgColor = isProfit 
          ? const Color(0xFFDC2626).withOpacity(0.1) 
          : const Color(0xFF059669).withOpacity(0.1);
      textColor = isProfit ? const Color(0xFFDC2626) : const Color(0xFF059669);
      icon = isProfit ? Icons.trending_up : Icons.trending_down;
      text = isProfit ? '盈利' : '亏损';
    } else {
      final isBuy = record.tradeType == TradeType.buy;
      bgColor = isBuy 
          ? const Color(0xFFDC2626).withOpacity(0.1) 
          : const Color(0xFF059669).withOpacity(0.1);
      textColor = isBuy ? const Color(0xFFDC2626) : const Color(0xFF059669);
      icon = isBuy ? Icons.arrow_downward : Icons.arrow_upward;
      text = isBuy ? '买入' : '卖出';
      }
    }

    // 优先显示行业信息，如果没有行业信息则显示交易类型
    if (record.stockCode.isNotEmpty) {
      // 这里可以通过股票代码获取行业信息
      // 暂时使用模拟的行业数据，实际应该从数据库或API获取
      final industry = _getStockIndustry(record.stockCode);
      
      if (industry != null && industry.isNotEmpty) {
        // 显示行业信息
        final industryColor = _getIndustryColor(industry);
        bgColor = industryColor.withOpacity(0.15);
        textColor = industryColor;
        icon = Icons.business_center;
        text = industry.length > 6 ? '${industry.substring(0, 6)}...' : industry;
      } else {
        // 如果没有行业信息，继续显示交易类型
        setTradeTypeDisplay();
      }
    } else {
      setTradeTypeDisplay();
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            bgColor,
            bgColor.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: textColor.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: textColor.withOpacity(0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  // 根据股票代码获取行业信息的方法
  String? _getStockIndustry(String stockCode) {
    // 这里是模拟数据，实际应用中应该从数据库查询
    // 可以通过Provider或Service从数据库获取股票的行业信息
    final industryMap = {
      '300606': '光学器件',
      '300409': '软件开发',
      '600000': '银行',
      '000001': '银行',
      '000002': '房地产',
      '600036': '银行',
      '000858': '白酒',
      '002415': '白酒',
      '600519': '白酒',
      '000568': '医药',
      '300760': '医疗器械',
      '688036': '芯片',
      '002594': '新能源',
      '300750': '新能源汽车',
    };
    
    return industryMap[stockCode];
  }

  // 获取行业颜色（专业化配色方案）
  Color _getIndustryColor(String industry) {
    // 使用更专业的配色方案，避免过于粉嫩的颜色
    final colorMap = {
      '光学器件': const Color(0xFF2563EB), // 专业蓝
      '软件开发': const Color(0xFF7C3AED), // 深紫
      '银行': const Color(0xFF059669), // 深绿
      '房地产': const Color(0xFFB45309), // 金褐色
      '白酒': const Color(0xFFDC2626), // 深红
      '医药': const Color(0xFF0891B2), // 青蓝
      '医疗器械': const Color(0xFF0D9488), // 青绿
      '芯片': const Color(0xFF4338CA), // 靛蓝
      '新能源': const Color(0xFF16A34A), // 新绿
      '新能源汽车': const Color(0xFFEA580C), // 橙色
    };
    
    return colorMap[industry] ?? const Color(0xFF6B7280); // 默认灰色
  }
  
  Widget _buildModernChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
          color: color.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
  
  Widget _buildInfoItem(
    String label,
    String value,
    IconData icon, {
    Color? valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: Colors.grey.shade500,
            ),
            const SizedBox(width: 4),
            Text(
              label,
                    style: TextStyle(
                      fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
                        ),
                      ],
                    ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: valueColor ?? Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  String _getMarketPhaseText(MarketPhase phase) {
    switch (phase) {
      case MarketPhase.buildingBottom:
        return '筑底';
      case MarketPhase.rising:
        return '上升';
      case MarketPhase.consolidation:
        return '盘整';
      case MarketPhase.topping:
        return '做头';
      case MarketPhase.falling:
        return '下降';
    }
  }

  Color _getMarketPhaseColor(MarketPhase phase) {
    switch (phase) {
      case MarketPhase.buildingBottom:
        return Colors.blue;
      case MarketPhase.rising:
        return const Color(0xFFDC2626); // A股红色
      case MarketPhase.consolidation:
        return Colors.purple; // 盘整阶段用紫色
      case MarketPhase.topping:
        return Colors.orange;
      case MarketPhase.falling:
        return const Color(0xFF059669); // A股绿色
    }
  }
  
  String _getTrendStrengthText(TrendStrength strength) {
    switch (strength) {
      case TrendStrength.strong:
        return '强势';
      case TrendStrength.medium:
        return '中等';
      case TrendStrength.weak:
        return '弱势';
    }
  }
  
  Color _getTrendStrengthColor(TrendStrength strength) {
    switch (strength) {
      case TrendStrength.strong:
        return const Color(0xFFDC2626);
      case TrendStrength.medium:
        return Colors.orange;
      case TrendStrength.weak:
        return const Color(0xFF059669);
    }
  }
} 