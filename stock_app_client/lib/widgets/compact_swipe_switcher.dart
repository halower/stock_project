import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/stock_indicator.dart';
import '../services/providers/api_provider.dart';
import '../services/providers/stock_provider.dart';

/// 紧凑型滑动股票切换器 - 直接在信息框内滑动
class CompactSwipeSwitcher extends StatefulWidget {
  final String currentStockCode;
  final String currentStockName;
  final Function(String stockCode, String stockName) onStockChanged;
  final bool isLandscape;
  final List<Map<String, String>>? availableStocks; // 添加可选的股票列表参数

  const CompactSwipeSwitcher({
    super.key,
    required this.currentStockCode,
    required this.currentStockName,
    required this.onStockChanged,
    this.isLandscape = false,
    this.availableStocks, // 可选股票列表参数
  });

  @override
  State<CompactSwipeSwitcher> createState() => _CompactSwipeSwitcherState();
}

class _CompactSwipeSwitcherState extends State<CompactSwipeSwitcher> {
  late PageController _pageController;
  List<Map<String, String>> _availableStocks = [];
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadAvailableStocks();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _loadAvailableStocks() {
    final apiProvider = Provider.of<ApiProvider>(context, listen: false);
    final scanResults = apiProvider.scanResults;
    
    if (widget.availableStocks != null && widget.availableStocks!.isNotEmpty) {
      _availableStocks = widget.availableStocks!;
    } else if (scanResults.isNotEmpty) {
      _availableStocks = scanResults.map((stock) => {
        'code': stock.code,
        'name': stock.name,
      }).toList();
    } else {
      final stockProvider = Provider.of<StockProvider>(context, listen: false);
      if (stockProvider.stocks.isNotEmpty) {
        _availableStocks = stockProvider.stocks.take(100).map((stock) => {
          'code': stock.code,
          'name': stock.name,
        }).toList();
      }
    }
    
    _currentIndex = _availableStocks.indexWhere(
      (stock) => stock['code'] == widget.currentStockCode,
    );
    if (_currentIndex == -1) _currentIndex = 0;
    
    _pageController = PageController(initialPage: _currentIndex);
    setState(() {});
  }

  void _onPageChanged(int index) {
    if (index >= 0 && index < _availableStocks.length) {
      final stock = _availableStocks[index];
      setState(() {
        _currentIndex = index;
      });
      
      // 延迟调用避免过于频繁的切换
      Future.delayed(const Duration(milliseconds: 150), () {
        widget.onStockChanged(stock['code']!, stock['name']!);
      });
    }
  }

  // 计算剩余股票数量
  int get _remainingStocks => _availableStocks.length - _currentIndex - 1;

  @override
  Widget build(BuildContext context) {
    if (_availableStocks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: widget.isLandscape ? MediaQuery.of(context).padding.top + 8 : 12,
      left: 12,
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: widget.isLandscape ? 220 : 200,
          ),
          height: 55, // 固定高度，紧凑设计
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.75),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Stack(
            children: [
              // 可滑动的股票信息
              PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _availableStocks.length,
                itemBuilder: (context, index) {
                  final stock = _availableStocks[index];
                  return _buildStockInfo(stock, index);
                },
              ),
              
              // 滑动提示指示器
              _buildSwipeIndicators(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStockInfo(Map<String, String> stock, int index) {
    final isSelected = index == _currentIndex;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 股票名称
          Text(
            stock['name']!,
            style: TextStyle(
              color: Colors.white,
              fontSize: widget.isLandscape ? 14 : 13,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          
          const SizedBox(height: 2),
          
          // 股票代码和进度信息
          Row(
            children: [
              // 股票代码
              Text(
                stock['code']!,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 11,
                ),
              ),
              
              const SizedBox(width: 12),
              
              // 当前位置指示
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.4),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  '${index + 1}/${_availableStocks.length}',
                  style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              
              const Spacer(),
              
              // 剩余数量提示
              if (_remainingStocks > 0)
                Text(
                  '还有${_remainingStocks}只',
                  style: TextStyle(
                    color: Colors.orange.withOpacity(0.8),
                    fontSize: 9,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeIndicators() {
    return Positioned(
      right: 8,
      top: 0,
      bottom: 0,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 向左滑动指示器
          if (_currentIndex > 0)
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Icon(
                Icons.chevron_left,
                color: Colors.white.withOpacity(0.6),
                size: 12,
              ),
            ),
          
          const SizedBox(height: 2),
          
          // 滑动提示点
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
          ),
          
          const SizedBox(height: 2),
          
          // 向右滑动指示器
          if (_currentIndex < _availableStocks.length - 1)
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Icon(
                Icons.chevron_right,
                color: Colors.white.withOpacity(0.6),
                size: 12,
              ),
            ),
        ],
      ),
    );
  }
} 