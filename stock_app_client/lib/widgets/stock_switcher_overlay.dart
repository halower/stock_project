import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/stock_indicator.dart';
import '../services/providers/api_provider.dart';
import '../services/providers/stock_provider.dart';

class StockSwitcherOverlay extends StatefulWidget {
  final String currentStockCode;
  final String currentStockName;
  final Function(String stockCode, String stockName) onStockChanged;

  const StockSwitcherOverlay({
    Key? key,
    required this.currentStockCode,
    required this.currentStockName,
    required this.onStockChanged,
  }) : super(key: key);

  @override
  State<StockSwitcherOverlay> createState() => _StockSwitcherOverlayState();
}

class _StockSwitcherOverlayState extends State<StockSwitcherOverlay>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  bool _isVisible = false;
  List<Map<String, String>> _availableStocks = [];
  int _currentIndex = 0;
  
  @override
  void initState() {
    super.initState();
    
    _scrollController = ScrollController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _loadAvailableStocks();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _loadAvailableStocks() {
    final apiProvider = Provider.of<ApiProvider>(context, listen: false);
    
    // 从API提供者的扫描结果中获取股票列表
    final scanResults = apiProvider.scanResults;
    
    if (scanResults.isNotEmpty) {
      _availableStocks = scanResults.map((stock) {
        return {
          'code': stock.code,
          'name': stock.name,
        };
      }).toList();
    } else {
      // 如果扫描结果为空，从股票提供者获取
      final stockProvider = Provider.of<StockProvider>(context, listen: false);
      if (stockProvider.stocks.isNotEmpty) {
        _availableStocks = stockProvider.stocks.take(50).map((stock) {
          return {
            'code': stock.code,
            'name': stock.name,
          };
        }).toList();
      }
    }
    
    // 找到当前股票在列表中的位置
    _currentIndex = _availableStocks.indexWhere(
      (stock) => stock['code'] == widget.currentStockCode,
    );
    
    if (_currentIndex == -1) {
      // 如果当前股票不在列表中，添加到开头
      _availableStocks.insert(0, {
        'code': widget.currentStockCode,
        'name': widget.currentStockName,
      });
      _currentIndex = 0;
    }
    
    if (mounted) {
      setState(() {});
    }
  }

  void _toggleVisibility() {
    setState(() {
      _isVisible = !_isVisible;
    });
    
    if (_isVisible) {
      _animationController.forward();
      // 滚动到当前选中的股票
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients && _currentIndex > 0) {
          _scrollController.animateTo(
            _currentIndex * 120.0, // 每个项目的宽度
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    } else {
      _animationController.reverse();
    }
  }

  void _onStockSelected(int index) {
    if (index >= 0 && index < _availableStocks.length && index != _currentIndex) {
      final selectedStock = _availableStocks[index];
      final stockCode = selectedStock['code']!;
      final stockName = selectedStock['name']!;
      
      setState(() {
        _currentIndex = index;
      });
      
      // 提供触觉反馈
      HapticFeedback.lightImpact();
      
      // 调用回调
      widget.onStockChanged(stockCode, stockName);
      
      // 移除自动关闭功能，让用户手动关闭弹框
      // Future.delayed(const Duration(milliseconds: 800), () {
      //   if (mounted && _isVisible) {
      //     _toggleVisibility();
      //   }
      // });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_availableStocks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        // 切换按钮
        Positioned(
          top: 16,
          right: 16,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.mediumImpact();
                _toggleVisibility();
              },
              borderRadius: BorderRadius.circular(28),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.4),
                      Colors.black.withOpacity(0.3),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Icon(
                  _isVisible ? Icons.close : Icons.swap_horiz,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
        
        // 股票选择器
        if (_isVisible)
          Positioned(
            top: 80,
            left: 16,
            right: 16,
            child: SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.6),
                          Colors.black.withOpacity(0.5),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 顶部指示器
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        
                        // 标题
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            '选择股票 (${_availableStocks.length})',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        
                        // 股票列表
                        Container(
                          height: 100,
                          child: ListView.builder(
                            controller: _scrollController,
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: _availableStocks.length,
                            itemBuilder: (context, index) {
                              final stock = _availableStocks[index];
                              final isSelected = index == _currentIndex;
                              
                              return Container(
                                width: 110,
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                child: Material(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  child: InkWell(
                                    onTap: () => _onStockSelected(index),
                                    borderRadius: BorderRadius.circular(12),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        gradient: isSelected 
                                            ? LinearGradient(
                                                colors: [
                                                  Colors.blue.withOpacity(0.6),
                                                  Colors.blue.withOpacity(0.4),
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              )
                                            : null,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected 
                                              ? Colors.blue.withOpacity(0.8)
                                              : Colors.white.withOpacity(0.1),
                                          width: isSelected ? 2 : 1,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          if (isSelected)
                                            Container(
                                              margin: const EdgeInsets.only(bottom: 4),
                                              child: Icon(
                                                Icons.check_circle,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            ),
                                          Text(
                                            stock['name']!,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: isSelected 
                                                  ? FontWeight.bold 
                                                  : FontWeight.normal,
                                            ),
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            stock['code']!,
                                            style: TextStyle(
                                              color: isSelected 
                                                  ? Colors.white.withOpacity(0.9)
                                                  : Colors.white.withOpacity(0.6),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        
                        // 底部提示
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            '左右滑动查看更多股票',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
} 