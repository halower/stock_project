// 估值分析页面

import 'package:flutter/material.dart';
import '../models/valuation.dart';
import '../services/valuation_service.dart';
import '../utils/financial_colors.dart';
import '../widgets/shimmer_loading.dart';
import 'stock_detail_screen.dart';

class ValuationScreeningScreen extends StatefulWidget {
  const ValuationScreeningScreen({super.key});

  @override
  State<ValuationScreeningScreen> createState() => _ValuationScreeningScreenState();
}

class _ValuationScreeningScreenState extends State<ValuationScreeningScreen> {
  bool _isLoading = false;
  String _error = '';
  List<ValuationData> _results = [];
  String _currentPreset = 'low-value'; // 当前选中的预设
  bool _dataLoaded = false;  // ✅ 懒加载标志

  // 筛选条件
  double _peMin = 0;
  double _peMax = 100;
  double _pbMin = 0;
  double _pbMax = 10;
  double _dividendYieldMin = 0;

  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    // ❌ 不要立即加载数据
    // _loadPresetData('low-value'); // 默认加载低估值蓝筹
    
    // ✅ 懒加载：切换到此Tab时才加载
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_dataLoaded && mounted) {
        _dataLoaded = true;
        debugPrint('🔄 估值分析Tab：首次加载数据...');
        _loadPresetData('low-value');
      }
    });
  }

  Future<void> _loadPresetData(String preset) async {
    setState(() {
      _isLoading = true;
      _error = '';
      _currentPreset = preset;
    });

    try {
      List<ValuationData> results;
      switch (preset) {
        case 'low-value':
          results = await ValuationService.getLowValueBlueChip(limit: 50);
          break;
        case 'high-dividend':
          results = await ValuationService.getHighDividendStocks(limit: 50);
          break;
        case 'growth-value':
          results = await ValuationService.getGrowthValueStocks(limit: 50);
          break;
        default:
          results = [];
      }

      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _customScreening() async {
    setState(() {
      _isLoading = true;
      _error = '';
      _currentPreset = 'custom';
    });

    try {
      final filters = ValuationFilters(
        peMin: _peMin > 0 ? _peMin : null,
        peMax: _peMax < 100 ? _peMax : null,
        pbMin: _pbMin > 0 ? _pbMin : null,
        pbMax: _pbMax < 10 ? _pbMax : null,
        dividendYieldMin: _dividendYieldMin > 0 ? _dividendYieldMin : null,
      );

      final results = await ValuationService.screeningByValuation(
        filters: filters,
        limit: 100,
      );

      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
          _showFilters = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
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
              child: const Icon(Icons.filter_alt, size: 24, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('估值分析', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('Valuation Analysis', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_showFilters ? Icons.close : Icons.tune),
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 快捷筛选按钮
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(child: _buildPresetChip('低估值蓝筹', 'low-value', Icons.diamond)),
                const SizedBox(width: 8),
                Expanded(child: _buildPresetChip('高股息', 'high-dividend', Icons.attach_money)),
                const SizedBox(width: 8),
                Expanded(child: _buildPresetChip('成长价值', 'growth-value', Icons.trending_up)),
              ],
            ),
          ),

          // 自定义筛选面板
          if (_showFilters) _buildFilterPanel(),

          // 结果统计
          if (_results.isNotEmpty && !_isLoading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '共筛选出 ${_results.length} 只股票',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ),

          // 结果列表
          Expanded(
            child: _buildResultList(),
          ),
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

  Widget _buildPresetChip(String label, String preset, IconData icon) {
    final isSelected = _currentPreset == preset;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return ElevatedButton(
      onPressed: () => _loadPresetData(preset),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected 
            ? FinancialColors.blueGradient[0]
            : (isDarkMode ? const Color(0xFF1E2329) : const Color(0xFFE8EBF0)),
        foregroundColor: isSelected 
            ? Colors.white 
            : (isDarkMode ? Colors.white70 : Colors.black87),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        elevation: isSelected ? 4 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: isSelected 
              ? BorderSide.none 
              : BorderSide(
                  color: isDarkMode 
                      ? Colors.white.withOpacity(0.1) 
                      : Colors.black.withOpacity(0.1),
                  width: 1,
                ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('自定义筛选条件', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          // PE范围
          Text('市盈率 (PE): ${_peMin.toStringAsFixed(0)} - ${_peMax.toStringAsFixed(0)}'),
          RangeSlider(
            values: RangeValues(_peMin, _peMax),
            min: 0,
            max: 100,
            divisions: 100,
            onChanged: (values) {
              setState(() {
                _peMin = values.start;
                _peMax = values.end;
              });
            },
          ),

          // PB范围
          Text('市净率 (PB): ${_pbMin.toStringAsFixed(1)} - ${_pbMax.toStringAsFixed(1)}'),
          RangeSlider(
            values: RangeValues(_pbMin, _pbMax),
            min: 0,
            max: 10,
            divisions: 100,
            onChanged: (values) {
              setState(() {
                _pbMin = values.start;
                _pbMax = values.end;
              });
            },
          ),

          // 股息率
          Text('股息率最低: ${_dividendYieldMin.toStringAsFixed(1)}%'),
          Slider(
            value: _dividendYieldMin,
            min: 0,
            max: 10,
            divisions: 100,
            onChanged: (value) {
              setState(() {
                _dividendYieldMin = value;
              });
            },
          ),

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _customScreening,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: FinancialColors.blueGradient[0],
                foregroundColor: Colors.white,
              ),
              child: const Text('开始筛选'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultList() {
    if (_isLoading) {
      return const ValuationListSkeleton();
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                '加载失败: $_error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadPresetData(_currentPreset),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('暂无数据', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadPresetData(_currentPreset),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _results.length,
        itemBuilder: (context, index) {
          final stock = _results[index];
          return _buildStockCard(stock);
        },
      ),
    );
  }

  Widget _buildStockCard(ValuationData stock) {
    // 根据涨跌幅确定颜色
    final priceColor = stock.pctChg >= 0 
        ? const Color(0xFFE53935) // 红色（涨）
        : const Color(0xFF4CAF50); // 绿色（跌）
    
    // 格式化涨跌幅显示
    final pctChgText = stock.pctChg >= 0 
        ? '+${stock.pctChg.toStringAsFixed(2)}%'
        : '${stock.pctChg.toStringAsFixed(2)}%';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Row(
          children: [
            Expanded(
              child: Text(
                stock.stockName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            // 价格和涨跌幅
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '¥${stock.close.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: priceColor,
                  ),
                ),
                Text(
                  pctChgText,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: priceColor,
                  ),
                ),
              ],
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${stock.stockCode} | 市值: ${stock.marketValue.toStringAsFixed(0)}亿',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildTag('PE', stock.peTtm?.toStringAsFixed(2) ?? '-', Colors.blue),
                const SizedBox(width: 8),
                _buildTag('PB', stock.pb?.toStringAsFixed(2) ?? '-', Colors.green),
                const SizedBox(width: 8),
                _buildTag('PS', stock.psTtm?.toStringAsFixed(2) ?? '-', Colors.orange),
                const SizedBox(width: 8),
                _buildTag('股息', stock.dividendYieldTtm != null ? '${stock.dividendYieldTtm!.toStringAsFixed(2)}%' : '-', Colors.purple),
              ],
            ),
          ],
        ),
        onTap: () {
          // 将当前筛选结果转换为股票列表格式
          final availableStocks = _results.map((s) => {
            'code': s.stockCode,
            'name': s.stockName,
          }).toList();
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StockDetailScreen(
                stockCode: stock.stockCode,
                stockName: stock.stockName,
                strategy: 'volume_wave', // 使用动量守恒策略，确保图表能正常加载
                availableStocks: availableStocks, // 传递当前筛选结果作为可切换的股票列表
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTag(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Text(
        '$label:$value',
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
