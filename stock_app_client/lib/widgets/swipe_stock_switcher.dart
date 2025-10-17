import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/stock_indicator.dart';
import '../services/providers/api_provider.dart';
import '../services/providers/stock_provider.dart';

/// 支持滑动切换的股票切换器
class SwipeStockSwitcher extends StatefulWidget {
  final String currentStockCode;
  final String currentStockName;
  final Function(String stockCode, String stockName) onStockChanged;
  final bool isLandscape;

  const SwipeStockSwitcher({
    super.key,
    required this.currentStockCode,
    required this.currentStockName,
    required this.onStockChanged,
    this.isLandscape = false,
  });

  @override
  State<SwipeStockSwitcher> createState() => _SwipeStockSwitcherState();
}

class _SwipeStockSwitcherState extends State<SwipeStockSwitcher> {
  late PageController _pageController;
  List<Map<String, String>> _availableStocks = [];
  int _currentIndex = 0;
  bool _showStockList = false;

  @override
  void initState() {
    super.initState();
    _loadAvailableStocks();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _loadAvailableStocks() {
    final apiProvider = Provider.of<ApiProvider>(context, listen: false);
    final scanResults = apiProvider.scanResults;
    
    if (scanResults.isNotEmpty) {
      _availableStocks = scanResults.map((stock) => {
        'code': stock.code,
        'name': stock.name,
      }).toList();
    } else {
      final stockProvider = Provider.of<StockProvider>(context, listen: false);
      if (stockProvider.stocks.isNotEmpty) {
        _availableStocks = stockProvider.stocks.take(50).map((stock) => {
          'code': stock.code,
          'name': stock.name,
        }).toList();
      }
    }
    
    _currentIndex = _availableStocks.indexWhere(
      (stock) => stock['code'] == widget.currentStockCode,
    );
    if (_currentIndex == -1) _currentIndex = 0;
    
    setState(() {});
  }

  void _onPageChanged(int index) {
    if (index >= 0 && index < _availableStocks.length) {
      final stock = _availableStocks[index];
      setState(() {
        _currentIndex = index;
      });
      
      // 延迟调用避免过于频繁的切换
      Future.delayed(const Duration(milliseconds: 200), () {
        widget.onStockChanged(stock['code']!, stock['name']!);
      });
    }
  }

  void _toggleStockList() {
    setState(() {
      _showStockList = !_showStockList;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_availableStocks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: widget.isLandscape ? MediaQuery.of(context).padding.top + 8 : 12,
      left: 12,
      right: widget.isLandscape ? null : 80, // 为横屏按钮留空间
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 主股票信息显示区域
            _buildMainStockDisplay(),
            
            // 滑动股票列表（可展开/收起）
            if (_showStockList) _buildSwipeableStockList(),
          ],
        ),
      ),
    );
  }

  Widget _buildMainStockDisplay() {
    if (_currentIndex >= _availableStocks.length) return const SizedBox.shrink();
    
    final currentStock = _availableStocks[_currentIndex];
    
    return GestureDetector(
      onTap: _toggleStockList,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: widget.isLandscape ? 200 : 180,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.75),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 股票信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentStock['name']!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Text(
                        currentStock['code']!,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_currentIndex + 1}/${_availableStocks.length}',
                        style: TextStyle(
                          color: Colors.blue.withOpacity(0.8),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 8),
            
            // 滑动提示和展开图标
            Column(
              children: [
                AnimatedRotation(
                  turns: _showStockList ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white.withOpacity(0.8),
                    size: 16,
                  ),
                ),
                Icon(
                  Icons.swipe_left_outlined,
                  color: Colors.white.withOpacity(0.5),
                  size: 12,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwipeableStockList() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      height: 120,
      constraints: BoxConstraints(
        maxWidth: widget.isLandscape ? 300 : 250,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.swipe_left_outlined,
                  color: Colors.white.withOpacity(0.6),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  '左右滑动切换股票',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _toggleStockList,
                  child: Icon(
                    Icons.close,
                    color: Colors.white.withOpacity(0.6),
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
          
          // 可滑动的股票列表
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: _availableStocks.length,
              itemBuilder: (context, index) {
                final stock = _availableStocks[index];
                final isCenter = index == _currentIndex;
                
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: EdgeInsets.symmetric(
                    vertical: isCenter ? 4 : 12,
                    horizontal: 8,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isCenter 
                      ? Colors.blue.withOpacity(0.2)
                      : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isCenter 
                        ? Colors.blue.withOpacity(0.5)
                        : Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stock['name']!,
                        style: TextStyle(
                          color: isCenter ? Colors.blue : Colors.white,
                          fontSize: isCenter ? 14 : 12,
                          fontWeight: isCenter ? FontWeight.w600 : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            stock['code']!,
                            style: TextStyle(
                              color: isCenter 
                                ? Colors.blue.withOpacity(0.8)
                                : Colors.white.withOpacity(0.6),
                              fontSize: 10,
                            ),
                          ),
                          const Spacer(),
                          if (isCenter)
                            Icon(
                              Icons.play_arrow,
                              color: Colors.blue,
                              size: 16,
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 