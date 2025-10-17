import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/stock_indicator.dart';
import '../services/providers/api_provider.dart';
import '../services/providers/stock_provider.dart';

/// TradingView风格的股票切换器
class TradingViewStockSwitcher extends StatefulWidget {
  final String currentStockCode;
  final String currentStockName;
  final Function(String stockCode, String stockName) onStockChanged;
  final bool isLandscape;

  const TradingViewStockSwitcher({
    super.key,
    required this.currentStockCode,
    required this.currentStockName,
    required this.onStockChanged,
    this.isLandscape = false,
  });

  @override
  State<TradingViewStockSwitcher> createState() => _TradingViewStockSwitcherState();
}

class _TradingViewStockSwitcherState extends State<TradingViewStockSwitcher>
    with SingleTickerProviderStateMixin {
  
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  
  bool _isExpanded = false;
  List<Map<String, String>> _availableStocks = [];
  int _currentIndex = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _loadAvailableStocks();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
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
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    
    if (_isExpanded) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  void _selectStock(String code, String name) {
    widget.onStockChanged(code, name);
    _toggleExpanded();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLandscape) {
      return _buildLandscapeVersion();
    } else {
      return _buildPortraitVersion();
    }
  }

  Widget _buildPortraitVersion() {
    return Positioned(
      top: 12,
      left: 12,
      child: _buildSwitcherContent(),
    );
  }

  Widget _buildLandscapeVersion() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 12,
      child: _buildSwitcherContent(),
    );
  }

  Widget _buildSwitcherContent() {
    return Material(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 主按钮 - 显示当前股票
          _buildMainButton(),
          
          // 展开的股票列表
          if (_isExpanded) _buildExpandedList(),
        ],
      ),
    );
  }

  Widget _buildMainButton() {
    return GestureDetector(
      onTap: _toggleExpanded,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 180),
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
                    widget.currentStockName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.currentStockCode,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 8),
            
            // 展开图标
            AnimatedRotation(
              turns: _isExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.keyboard_arrow_down,
                color: Colors.white.withOpacity(0.8),
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedList() {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: _slideAnimation.value,
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(top: 4),
        constraints: const BoxConstraints(
          maxWidth: 200,
          maxHeight: 280,
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
            // 搜索框（简化版）
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Text(
                '选择股票 (${_availableStocks.length})',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
            ),
            
            // 股票列表
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: _availableStocks.length,
                  itemBuilder: (context, index) {
                    final stock = _availableStocks[index];
                    final isSelected = stock['code'] == widget.currentStockCode;
                    
                    return _buildStockItem(
                      code: stock['code']!,
                      name: stock['name']!,
                      isSelected: isSelected,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockItem({
    required String code,
    required String name,
    required bool isSelected,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectStock(code, name),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected 
              ? Colors.blue.withOpacity(0.2)
              : Colors.transparent,
          ),
          child: Row(
            children: [
              // 选中指示器
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue : Colors.transparent,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              
              const SizedBox(width: 8),
              
              // 股票信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: isSelected ? Colors.blue : Colors.white,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      code,
                      style: TextStyle(
                        color: isSelected 
                          ? Colors.blue.withOpacity(0.8)
                          : Colors.white.withOpacity(0.6),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              
              // 选中图标
              if (isSelected)
                Icon(
                  Icons.check,
                  color: Colors.blue,
                  size: 16,
                ),
            ],
          ),
        ),
      ),
    );
  }
} 