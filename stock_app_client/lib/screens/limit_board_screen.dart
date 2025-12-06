/// 打板数据页面
/// 展示涨跌停、龙虎榜、连板统计等数据

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/limit_board_service.dart';
import '../models/limit_board_data.dart';
import '../utils/design_system.dart';
import 'stock_detail_screen.dart';

class LimitBoardScreen extends StatefulWidget {
  const LimitBoardScreen({super.key});

  @override
  State<LimitBoardScreen> createState() => _LimitBoardScreenState();
}

class _LimitBoardScreenState extends State<LimitBoardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  bool _isLoading = true;
  String? _errorMessage;
  LimitBoardSummary? _summary;
  
  // 选中的日期
  DateTime _selectedDate = DateTime.now();
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  /// 加载数据
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final tradeDate = DateFormat('yyyyMMdd').format(_selectedDate);
      final summary = await LimitBoardService.getSummary(tradeDate: tradeDate);
      
      setState(() {
        _summary = summary;
        _isLoading = false;
        if (summary == null) {
          _errorMessage = '暂无数据';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '加载失败: $e';
      });
    }
  }
  
  /// 选择日期
  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('zh', 'CN'),
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadData();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            Scaffold.of(context).openDrawer();
          },
        ),
        title: const Text('打板数据'),
        actions: [
          // 日期选择按钮
          TextButton.icon(
            onPressed: _selectDate,
            icon: const Icon(Icons.calendar_today, size: 18),
            label: Text(
              DateFormat('MM-dd').format(_selectedDate),
              style: const TextStyle(fontSize: 14),
            ),
          ),
          // 刷新按钮
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: '刷新数据',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: '概览'),
            Tab(text: '涨停板'),
            Tab(text: '跌停板'),
            Tab(text: '龙虎榜'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(_errorMessage!, style: TextStyle(color: Colors.grey[600])),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(isDark),
                    _buildUpLimitTab(isDark),
                    _buildDownLimitTab(isDark),
                    _buildTopListTab(isDark),
                  ],
                ),
    );
  }
  
  /// 构建概览标签页
  Widget _buildOverviewTab(bool isDark) {
    if (_summary == null) {
      return const Center(child: Text('暂无数据'));
    }
    
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 统计卡片
            _buildStatsCards(isDark),
            const SizedBox(height: 24),
            
            // 连板梯队
            _buildContinuousSection(isDark),
            const SizedBox(height: 24),
            
            // 最强板块统计
            if (_summary!.sectorStats.isNotEmpty)
              _buildSectorStatsSection(isDark),
            
            if (_summary!.sectorStats.isNotEmpty)
              const SizedBox(height: 24),
            
            // 高连板股票
            if (_summary!.topContinuous.isNotEmpty)
              _buildTopContinuousSection(isDark),
          ],
        ),
      ),
    );
  }
  
  /// 构建统计卡片
  Widget _buildStatsCards(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: '涨停',
            value: '${_summary!.upLimitCount}',
            icon: Icons.trending_up,
            color: AppDesignSystem.upColor,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: '跌停',
            value: '${_summary!.downLimitCount}',
            icon: Icons.trending_down,
            color: AppDesignSystem.downColor,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: '龙虎榜',
            value: '${_summary!.topListCount}',
            icon: Icons.leaderboard,
            color: Colors.orange,
            isDark: isDark,
          ),
        ),
      ],
    );
  }
  
  /// 构建单个统计卡片
  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppDesignSystem.darkBg2 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppDesignSystem.darkText3 : AppDesignSystem.lightText3,
            ),
          ),
        ],
      ),
    );
  }
  
  /// 构建连板梯队
  Widget _buildContinuousSection(bool isDark) {
    final stats = _summary!.continuousStats;
    if (stats.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // 按连板数排序，并过滤掉1连板（只显示2连板及以上）
    final sortedKeys = stats.keys.toList()
      ..sort((a, b) {
        final aNum = int.tryParse(a.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        final bNum = int.tryParse(b.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        return bNum.compareTo(aNum);
      });
    
    // 过滤掉1连板
    final filteredKeys = sortedKeys.where((key) {
      final days = int.tryParse(key.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      return days >= 2;
    }).toList();
    
    // 如果过滤后没有数据，不显示这个区块
    if (filteredKeys.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: AppDesignSystem.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '连板梯队',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? AppDesignSystem.darkText1 : AppDesignSystem.lightText1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: filteredKeys.map((key) {
            final count = stats[key] ?? 0;
            final days = int.tryParse(key.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            
            Color bgColor;
            if (days >= 5) {
              bgColor = Colors.red.shade600;
            } else if (days >= 3) {
              bgColor = Colors.orange.shade600;
            } else {
              bgColor = Colors.blue.shade600;
            }
            
            return GestureDetector(
              onTap: () => _showContinuousStocks(days, isDark),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [bgColor, bgColor.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: bgColor.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      key,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$count只',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
  
  /// 显示连板股票列表
  void _showContinuousStocks(int days, bool isDark) {
    // 筛选出对应连板天数的股票
    final stocks = _summary!.upLimitList
        .where((stock) => stock.limitTimes == days)
        .toList()
      ..sort((a, b) => b.pctChg.compareTo(a.pctChg)); // 按涨幅排序
    
    if (stocks.isEmpty) {
      return;
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: isDark ? AppDesignSystem.darkBg1 : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // 标题栏
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$days连板股票',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppDesignSystem.darkText1 : AppDesignSystem.lightText1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '共${stocks.length}只',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppDesignSystem.darkText3 : AppDesignSystem.lightText3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              
              // 股票列表
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: stocks.length,
                  itemBuilder: (context, index) {
                    return _buildClickableLimitStockItem(
                      stocks[index],
                      isDark,
                      showContinuous: true,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// 构建最强板块统计
  Widget _buildSectorStatsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.deepOrange,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '最强板块',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? AppDesignSystem.darkText1 : AppDesignSystem.lightText1,
              ),
            ),
            const Spacer(),
            Text(
              '涨停数量',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppDesignSystem.darkText3 : AppDesignSystem.lightText3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._summary!.sectorStats.take(8).map((sector) => 
          _buildSectorStatsItem(sector, isDark)
        ),
      ],
    );
  }
  
  /// 构建板块统计项
  Widget _buildSectorStatsItem(SectorStats sector, bool isDark) {
    // 根据涨停数量确定颜色
    Color getColorByCount(int count) {
      if (count >= 10) return Colors.red.shade600;
      if (count >= 5) return Colors.orange.shade600;
      if (count >= 3) return Colors.blue.shade600;
      return Colors.grey.shade600;
    }
    
    final color = getColorByCount(sector.count);
    
    return GestureDetector(
      onTap: () => _showSectorDetail(sector, isDark),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppDesignSystem.darkBg2 : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // 排名标识
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '${sector.count}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // 板块信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sector.sectorName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: isDark ? AppDesignSystem.darkText1 : AppDesignSystem.lightText1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '平均涨幅 ${sector.avgPctChg.toStringAsFixed(2)}%',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppDesignSystem.darkText3 : AppDesignSystem.lightText3,
                        ),
                      ),
                      if (sector.highContinuousCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${sector.highContinuousCount}只高连板',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.red.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            
            // 箭头图标
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: isDark ? AppDesignSystem.darkText4 : AppDesignSystem.lightText4,
            ),
          ],
        ),
      ),
    );
  }
  
  /// 显示板块详情
  void _showSectorDetail(SectorStats sector, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: isDark ? AppDesignSystem.darkBg1 : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // 标题栏
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sector.sectorName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppDesignSystem.darkText1 : AppDesignSystem.lightText1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${sector.count}只涨停 · 平均涨幅${sector.avgPctChg.toStringAsFixed(2)}%',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppDesignSystem.darkText3 : AppDesignSystem.lightText3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              
              // 股票列表
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: sector.stocks.length,
                  itemBuilder: (context, index) {
                    return _buildClickableLimitStockItem(
                      sector.stocks[index],
                      isDark,
                      showContinuous: true,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// 构建高连板股票
  Widget _buildTopContinuousSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '高连板龙头',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? AppDesignSystem.darkText1 : AppDesignSystem.lightText1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._summary!.topContinuous.take(10).map((stock) => 
          _buildLimitStockItem(stock, isDark, showContinuous: true)
        ),
      ],
    );
  }
  
  /// 构建涨停板标签页
  Widget _buildUpLimitTab(bool isDark) {
    if (_summary == null || _summary!.upLimitList.isEmpty) {
      return const Center(child: Text('暂无涨停数据'));
    }
    
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _summary!.upLimitList.length,
        itemBuilder: (context, index) {
          return _buildClickableLimitStockItem(_summary!.upLimitList[index], isDark);
        },
      ),
    );
  }
  
  /// 构建跌停板标签页
  Widget _buildDownLimitTab(bool isDark) {
    if (_summary == null || _summary!.downLimitList.isEmpty) {
      return const Center(child: Text('暂无跌停数据'));
    }
    
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _summary!.downLimitList.length,
        itemBuilder: (context, index) {
          return _buildClickableLimitStockItem(_summary!.downLimitList[index], isDark, isDown: true);
        },
      ),
    );
  }
  
  /// 构建龙虎榜标签页
  Widget _buildTopListTab(bool isDark) {
    if (_summary == null || _summary!.topList.isEmpty) {
      return const Center(child: Text('暂无龙虎榜数据'));
    }
    
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _summary!.topList.length,
        itemBuilder: (context, index) {
          return _buildClickableTopListItem(_summary!.topList[index], isDark);
        },
      ),
    );
  }
  
  /// 构建可点击的龙虎榜项（打开走势图）
  Widget _buildClickableTopListItem(TopListStock stock, bool isDark) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StockDetailScreen(
              stockCode: stock.tsCode,
              stockName: stock.name,
            ),
          ),
        );
      },
      child: _buildTopListItem(stock, isDark),
    );
  }
  
  /// 构建可点击的涨跌停股票项（打开走势图）
  Widget _buildClickableLimitStockItem(LimitStock stock, bool isDark, {bool isDown = false, bool showContinuous = false}) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StockDetailScreen(
              stockCode: stock.tsCode,
              stockName: stock.name,
            ),
          ),
        );
      },
      child: _buildLimitStockItem(stock, isDark, isDown: isDown, showContinuous: showContinuous),
    );
  }
  
  /// 构建涨跌停股票项
  Widget _buildLimitStockItem(LimitStock stock, bool isDark, {bool isDown = false, bool showContinuous = false}) {
    final color = isDown ? AppDesignSystem.downColor : AppDesignSystem.upColor;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppDesignSystem.darkBg2 : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // 连板标识
          if (showContinuous && stock.limitTimes > 1)
            Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: stock.limitTimes >= 5
                      ? [Colors.red.shade600, Colors.red.shade400]
                      : stock.limitTimes >= 3
                          ? [Colors.orange.shade600, Colors.orange.shade400]
                          : [Colors.blue.shade600, Colors.blue.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '${stock.limitTimes}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          
          // 股票信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      stock.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: isDark ? AppDesignSystem.darkText1 : AppDesignSystem.lightText1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      stock.code,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppDesignSystem.darkText3 : AppDesignSystem.lightText3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (stock.firstTime.isNotEmpty)
                      Text(
                        '首封 ${stock.firstTime}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppDesignSystem.darkText4 : AppDesignSystem.lightText4,
                        ),
                      ),
                    if (stock.openTimes > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '开板${stock.openTimes}次',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          
          // 价格和涨跌幅
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                stock.close.toStringAsFixed(2),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: color,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${stock.pctChg >= 0 ? '+' : ''}${stock.pctChg.toStringAsFixed(2)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  /// 构建龙虎榜项
  Widget _buildTopListItem(TopListStock stock, bool isDark) {
    final isUp = stock.pctChange >= 0;
    final color = isUp ? AppDesignSystem.upColor : AppDesignSystem.downColor;
    final netColor = stock.netAmount >= 0 ? AppDesignSystem.upColor : AppDesignSystem.downColor;
    
    // 格式化金额
    String formatAmount(double amount) {
      if (amount.abs() >= 10000) {
        return '${(amount / 10000).toStringAsFixed(2)}亿';
      } else {
        return '${amount.toStringAsFixed(2)}万';
      }
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppDesignSystem.darkBg2 : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 第一行：股票名称、代码、价格
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          stock.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: isDark ? AppDesignSystem.darkText1 : AppDesignSystem.lightText1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          stock.code,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppDesignSystem.darkText3 : AppDesignSystem.lightText3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stock.reason,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    stock.close.toStringAsFixed(2),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: color,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${isUp ? '+' : ''}${stock.pctChange.toStringAsFixed(2)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // 第二行：买入、卖出、净买入
          Row(
            children: [
              Expanded(
                child: _buildAmountItem(
                  '买入',
                  formatAmount(stock.lBuy),
                  AppDesignSystem.upColor,
                  isDark,
                ),
              ),
              Expanded(
                child: _buildAmountItem(
                  '卖出',
                  formatAmount(stock.lSell),
                  AppDesignSystem.downColor,
                  isDark,
                ),
              ),
              Expanded(
                child: _buildAmountItem(
                  '净买入',
                  formatAmount(stock.netAmount),
                  netColor,
                  isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  /// 构建金额项
  Widget _buildAmountItem(String label, String value, Color color, bool isDark) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? AppDesignSystem.darkText4 : AppDesignSystem.lightText4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

