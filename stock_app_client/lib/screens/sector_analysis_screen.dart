// 板块分析页面

import 'package:flutter/material.dart';
import '../models/sector.dart';
import '../services/sector_service.dart';
import '../utils/financial_colors.dart';
import 'stock_detail_screen.dart';

class SectorAnalysisScreen extends StatefulWidget {
  const SectorAnalysisScreen({super.key});

  @override
  State<SectorAnalysisScreen> createState() => _SectorAnalysisScreenState();
}

class _SectorAnalysisScreenState extends State<SectorAnalysisScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  String _error = '';

  // 板块排名数据
  List<SectorRanking> _sectorRankings = [];
  // 热门概念数据
  List<HotConcept> _hotConcepts = [];

  String _rankType = 'change'; // change, amount, turnover

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      if (_tabController.index == 0) {
        // 加载板块排名
        final rankings = await SectorService.getSectorRanking(
          rankType: _rankType,
          limit: 50,
        );
        setState(() {
          _sectorRankings = rankings;
          _isLoading = false;
        });
      } else {
        // 加载热门概念
        final concepts = await SectorService.getHotConcepts(limit: 30);
        setState(() {
          _hotConcepts = concepts;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF0F1419) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            Scaffold.of(context).openDrawer();
          },
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    FinancialColors.blueGradient[0],
                    FinancialColors.blueGradient[1],
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.dashboard, size: 24, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('板块分析', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('Sector Analysis', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          onTap: (index) {
            _loadData();
          },
          tabs: const [
            Tab(text: '行业排名'),
            Tab(text: '热门行业'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
      children: [
        _buildSectorRankingTab(),
        _buildHotIndustriesTab(),
      ],
      ),
      drawer: Drawer(
        child: Builder(
          builder: (context) {
            // 获取父级 HomeScreen 的 Scaffold
            final parentScaffold = context.findAncestorStateOfType<ScaffoldState>();
            if (parentScaffold != null && parentScaffold.hasDrawer) {
              // 关闭当前 drawer 并打开父级 drawer
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.of(context).pop();
                parentScaffold.openDrawer();
              });
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildSectorRankingTab() {
    return Column(
      children: [
        // 排序选择
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text('排序方式：', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  children: [
                    _buildRankTypeChip('涨跌幅', 'change'),
                    _buildRankTypeChip('成交额', 'amount'),
                    _buildRankTypeChip('换手率', 'turnover'),
                  ],
                ),
              ),
            ],
          ),
        ),
        // 列表
        Expanded(
          child: _buildContent(
            _sectorRankings,
            (ranking) => _buildSectorRankingItem(ranking),
          ),
        ),
      ],
    );
  }

  Widget _buildRankTypeChip(String label, String value) {
    final isSelected = _rankType == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _rankType = value;
          });
          _loadData();
        }
      },
    );
  }

  Widget _buildHotIndustriesTab() {
    return _buildContent(
      _hotConcepts,
      (concept) => _buildHotConceptItem(concept),
    );
  }

  Widget _buildContent<T>(List<T> data, Widget Function(T) itemBuilder) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('加载失败: $_error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (data.isEmpty) {
      return const Center(child: Text('暂无数据'));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: data.length,
        itemBuilder: (context, index) => itemBuilder(data[index]),
      ),
    );
  }

  Widget _buildSectorRankingItem(SectorRanking ranking) {
    final isPositive = ranking.avgChangePct >= 0;
    final changeColor = isPositive ? FinancialColors.profit : FinancialColors.loss;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: changeColor.withOpacity(0.2),
          child: Text(
            '${ranking.limitUpCount}',
            style: TextStyle(color: changeColor, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          ranking.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '成分股: ${ranking.stockCount} | 涨停: ${ranking.limitUpCount} | 上涨: ${ranking.upCount}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${isPositive ? '+' : ''}${ranking.avgChangePct.toStringAsFixed(2)}%',
              style: TextStyle(
                color: changeColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (ranking.leadingStock != null)
              Text(
                ranking.leadingStock!.name,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
          ],
        ),
        onTap: () => _showSectorDetail(ranking.tsCode, ranking.name),
      ),
    );
  }

  Widget _buildHotConceptItem(HotConcept concept) {
    final isPositive = concept.avgChangePct >= 0;
    final changeColor = isPositive ? FinancialColors.profit : FinancialColors.loss;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.orange.withOpacity(0.7),
                Colors.red.withOpacity(0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${concept.limitUpCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const Text(
                '涨停',
                style: TextStyle(color: Colors.white, fontSize: 10),
              ),
            ],
          ),
        ),
        title: Text(
          concept.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '成分股: ${concept.stockCount} | 上涨比例: ${concept.upRatio.toStringAsFixed(1)}% | 热度: ${concept.heatScore.toStringAsFixed(0)}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${isPositive ? '+' : ''}${concept.avgChangePct.toStringAsFixed(2)}%',
              style: TextStyle(
                color: changeColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (concept.leadingStock != null)
              Text(
                concept.leadingStock!.name,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
          ],
        ),
        onTap: () => _showSectorDetail(concept.tsCode, concept.name),
      ),
    );
  }

  void _showSectorDetail(String sectorCode, String sectorName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    sectorName,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: FutureBuilder<Map<String, dynamic>>(
                    future: SectorService.getSectorDetail(sectorCode),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(child: Text('加载失败: ${snapshot.error}'));
                      }

                      final detail = snapshot.data!;
                      final members = detail['members'] as List<SectorMember>;

                      return ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: members.length,
                        itemBuilder: (context, index) {
                          final member = members[index];
                          // 判断是否有价格数据（只要price字段存在就显示，即使为0）
                          final hasPrice = member.price != null;
                          final price = member.price ?? 0;
                          final changePct = member.changePct ?? 0;
                          final isPositive = changePct > 0;
                          final isNegative = changePct < 0;
                          
                          // 调试日志
                          if (index == 0) {
                            debugPrint('📊 第一个成分股: ${member.name}, price=$price, changePct=$changePct, hasPrice=$hasPrice');
                          }
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(member.name),
                              subtitle: Text(member.stockCode),
                              trailing: hasPrice
                                  ? Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        // 显示价格
                                        Text(
                                          price > 0 ? '¥${price.toStringAsFixed(2)}' : '--',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        // 显示涨跌幅（带颜色）
                                        Text(
                                          '${isPositive ? '+' : ''}${changePct.toStringAsFixed(2)}%',
                                          style: TextStyle(
                                            color: isPositive
                                                ? Colors.red
                                                : isNegative
                                                    ? Colors.green
                                                    : Colors.grey,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    )
                                  : const Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: () {
                                Navigator.pop(context);
                                // 构建板块股票列表
                                final stockList = members.map((m) => {
                                  'code': m.stockCode,
                                  'name': m.name,
                                }).toList();
                                
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => StockDetailScreen(
                                      stockCode: member.stockCode,
                                      stockName: member.name,
                                      availableStocks: stockList,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

