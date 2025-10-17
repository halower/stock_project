import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/stock_info.dart';
import '../services/providers/stock_provider.dart';

class StockSelector extends StatefulWidget {
  final Function(StockInfo) onStockSelected;
  final String? initialValue;

  const StockSelector({
    super.key,
    required this.onStockSelected,
    this.initialValue,
  });

  @override
  State<StockSelector> createState() => _StockSelectorState();
}

class _StockSelectorState extends State<StockSelector> {
  final TextEditingController _searchController = TextEditingController();
  List<StockInfo> _filteredStocks = [];
  bool _isLoading = false;
  String? _selectedStock;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null) {
      _selectedStock = widget.initialValue;
      // 使用Provider获取股票代码匹配的名称
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final stockProvider = Provider.of<StockProvider>(context, listen: false);
        if (stockProvider.isInitialized) {
          _updateSelectedStockInfo();
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 从StockProvider获取已缓存的股票数据
  void _updateSelectedStockInfo() {
    if (_selectedStock == null) return;
    
    final stockProvider = Provider.of<StockProvider>(context, listen: false);
    final stockInfo = stockProvider.getStockByCode(_selectedStock!);
    
    if (stockInfo != null) {
      // 找到了匹配的股票，可以触发回调通知父组件
      widget.onStockSelected(StockInfo(
        code: stockInfo.code,
        name: stockInfo.name,
        market: '',
        industry: '',
        board: '',
        listingDate: '',
        totalShares: '',
        circulatingShares: '',
      ));
    }
  }

  void _filterStocks(String query) async {
    if (query.isEmpty) {
      setState(() {
        _filteredStocks = [];
        _isExpanded = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _isExpanded = true;
    });

    try {
      // 从StockProvider中获取已缓存的匹配结果
      final stockProvider = Provider.of<StockProvider>(context, listen: false);
      
      // 从缓存的股票数据中搜索，无需网络请求
      List<Map<String, dynamic>> suggestions = await stockProvider.getStockSuggestions(query);
      
      setState(() {
        _filteredStocks = suggestions.map((data) {
          return StockInfo(
            code: data['code'],
            name: data['name'],
            market: data['market'] ?? '',
            industry: data['industry'] ?? '',
            board: data['board'] ?? '',
            listingDate: data['listing_date'] ?? '',
            totalShares: data['total_shares'] ?? '',
            circulatingShares: data['circulating_shares'] ?? '',
          );
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('筛选股票时出错: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: '搜索股票代码或名称',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _filteredStocks = [];
                        _isExpanded = false;
                      });
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onChanged: _filterStocks,
          onTap: () {
            // 点击输入框时，如果已经有内容，则展开列表
            if (_searchController.text.isNotEmpty) {
              setState(() {
                _isExpanded = true;
              });
            }
          },
        ),
        const SizedBox(height: 8),
        if (_isExpanded)
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_filteredStocks.isEmpty)
            const Center(
              child: Text('未找到匹配的股票'),
            )
          else
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _filteredStocks.length,
                itemBuilder: (context, index) {
                  final stock = _filteredStocks[index];
                  final isSelected = _selectedStock == '${stock.market}${stock.code}';
                  return ListTile(
                    title: Text('${stock.market}${stock.code}'),
                    subtitle: Text(stock.name),
                    trailing: Text(
                      stock.industry,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    selected: isSelected,
                    selectedTileColor: Colors.blue.withOpacity(0.1),
                    onTap: () {
                      setState(() {
                        _selectedStock = '${stock.market}${stock.code}';
                        _isExpanded = false;  // 选择后关闭下拉列表
                        _searchController.text = '${stock.market}${stock.code} - ${stock.name}';  // 在输入框中显示选中的股票
                      });
                      widget.onStockSelected(stock);
                    },
                  );
                },
              ),
            ),
      ],
    );
  }
} 