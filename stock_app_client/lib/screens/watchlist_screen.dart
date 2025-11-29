import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../models/watchlist_item.dart';
import '../services/watchlist_service.dart';
import '../services/providers/api_provider.dart';
import '../services/providers/stock_provider.dart';
import '../widgets/watchlist_item_widget.dart';
import '../widgets/professional_watchlist_header.dart';

// 添加排序枚举
enum SortOption {
  none,
  changePercentAsc,  // 涨幅从低到高
  changePercentDesc, // 涨幅从高到低
  addedTimeDesc,     // 加入时间从新到旧
  addedTimeAsc,      // 加入时间从旧到新
}

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> with TickerProviderStateMixin {
  List<WatchlistItem> _watchlistItems = [];
  List<WatchlistItem> _filteredItems = []; // 添加筛选后的列表
  bool _isLoading = true;
  bool _isUpdatingPrices = false;
  AnimationController? _refreshAnimationController;
  
  // 添加排序状态
  SortOption _currentSortOption = SortOption.none;
  // 信号筛选状态：null=全部, 'buy'=买入信号, 'sell'=卖出信号
  String? _selectedSignalFilter;
  
  // 排序选项的键
  static const String _sortOptionKey = 'watchlist_sort_option';
  
  // 上次订阅的时间戳
  DateTime? _lastSubscribeTime;
  
  @override
  void initState() {
    super.initState();
    _refreshAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _loadSortOption().then((_) => _loadWatchlist());
    
    // 延迟注册WebSocket价格更新处理器
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupWebSocketPriceUpdates();
    });
  }
  
  /// 确保WebSocket订阅有效
  void _ensureSubscription() {
    if (_watchlistItems.isEmpty) return;
    
    final now = DateTime.now();
    // 如果距离上次订阅超过3秒，重新订阅
    if (_lastSubscribeTime == null || 
        now.difference(_lastSubscribeTime!).inSeconds > 3) {
      final apiProvider = Provider.of<ApiProvider>(context, listen: false);
      if (apiProvider.wsService.isConnected) {
        debugPrint('[Watchlist] 确保订阅: ${_watchlistItems.length} 个股票');
        _subscribeWatchlistStocks();
        _lastSubscribeTime = now;
      }
    }
  }
  
  /// 设置WebSocket价格更新
  void _setupWebSocketPriceUpdates() {
    final apiProvider = Provider.of<ApiProvider>(context, listen: false);
    
    // 注册价格更新回调（不会覆盖 ApiProvider 的处理器）
    apiProvider.addPriceUpdateCallback(_handleWebSocketPriceUpdate);
    
    // 连接WebSocket（如果未连接）
    if (!apiProvider.wsService.isConnected) {
      apiProvider.connectWebSocket();
    }
    
    // 订阅备选池中所有股票
    _subscribeWatchlistStocks();
  }
  
  /// 订阅备选池中的股票
  Future<void> _subscribeWatchlistStocks() async {
    if (_watchlistItems.isEmpty) return;
    
    final apiProvider = Provider.of<ApiProvider>(context, listen: false);
    
    // 等待WebSocket连接
    int retries = 0;
    while (!apiProvider.wsService.isConnected && retries < 10) {
      await Future.delayed(const Duration(milliseconds: 500));
      retries++;
    }
    
    if (!apiProvider.wsService.isConnected) {
      debugPrint('[Watchlist] WebSocket未连接，无法订阅');
      return;
    }
    
    // 订阅每个股票
    for (var item in _watchlistItems) {
      apiProvider.wsService.subscribeStock(item.code);
      await Future.delayed(const Duration(milliseconds: 50)); // 避免过快发送
    }
    
    debugPrint('[Watchlist] 已订阅 ${_watchlistItems.length} 个股票');
  }
  
  /// 处理WebSocket价格更新（接收更新列表）
  /// 注意：只更新价格相关字段，保留信号字段不变
  void _handleWebSocketPriceUpdate(List<dynamic> updates) {
    try {
      if (updates.isEmpty) return;
      
      bool hasUpdate = false;
      final updatedItems = <WatchlistItem>[];
      
      for (var item in _watchlistItems) {
        // 查找该股票的价格更新
        final update = updates.firstWhere(
          (u) => u['code'] == item.code,
          orElse: () => null,
        );
        
        if (update != null) {
          // 创建更新后的WatchlistItem，保留原有的信号字段
          final updatedItem = WatchlistItem(
            code: item.code,
            name: item.name,
            market: item.market,
            strategy: item.strategy,
            addedTime: item.addedTime,
            originalDetails: item.originalDetails,
            currentPrice: (update['price'] as num?)?.toDouble() ?? item.currentPrice,
            changePercent: (update['change_percent'] as num?)?.toDouble() ?? item.changePercent,
            volume: (update['volume'] as num?)?.toInt() ?? item.volume,
            priceUpdateTime: DateTime.now(),
            // 保留信号字段不变
            signalType: item.signalType,
            signalReason: item.signalReason,
            signalConfidence: item.signalConfidence,
            signalUpdateTime: item.signalUpdateTime,
          );
          updatedItems.add(updatedItem);
          hasUpdate = true;
        } else {
          updatedItems.add(item);
        }
      }
      
      if (hasUpdate && mounted) {
        setState(() {
          _watchlistItems = updatedItems;
          _applyFiltersAndSort();
        });
        debugPrint('[Watchlist] WebSocket更新了价格');
      }
      
    } catch (e) {
      debugPrint('[Watchlist] 处理价格更新失败: $e');
    }
  }

  // 加载保存的排序选项
  Future<void> _loadSortOption() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sortOptionIndex = prefs.getInt(_sortOptionKey);
      if (sortOptionIndex != null && mounted) {
        setState(() {
          _currentSortOption = SortOption.values[sortOptionIndex];
        });
      }
    } catch (e) {
      print('加载排序选项失败: $e');
    }
  }

  // 保存排序选项
  Future<void> _saveSortOption() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_sortOptionKey, _currentSortOption.index);
    } catch (e) {
      print('保存排序选项失败: $e');
    }
  }

  @override
  void dispose() {
    // 移除价格更新回调
    try {
      final apiProvider = Provider.of<ApiProvider>(context, listen: false);
      apiProvider.removePriceUpdateCallback(_handleWebSocketPriceUpdate);
    } catch (e) {
      debugPrint('[Watchlist] 移除回调失败: $e');
    }
    _refreshAnimationController?.dispose();
    super.dispose();
  }

  Future<void> _loadWatchlist() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final watchlistItems = await WatchlistService.getWatchlistItems();
      if (mounted) {
        setState(() {
          _watchlistItems = watchlistItems;
          _filteredItems = watchlistItems; // 初始化筛选列表
          _isLoading = false;
        });
        
        // 应用当前排序选项和筛选
        _applyFiltersAndSort();
        
        // 自动更新价格（如果有需要更新的股票）
        _updatePricesIfNeeded();
        
        // 查询信号状态
        _updateSignals();
        
        // 订阅WebSocket价格更新
        debugPrint('[Watchlist] 加载完成，订阅 ${_watchlistItems.length} 个股票');
        _subscribeWatchlistStocks();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Text('加载备选池失败: $e'),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  // 检查是否需要更新价格，如果需要则自动更新
  Future<void> _updatePricesIfNeeded() async {
    final needsUpdate = _watchlistItems.any((item) => item.needsPriceUpdate);
    if (needsUpdate && !_isUpdatingPrices) {
      _updateAllPrices(showLoading: false);
    }
  }
  
  // 更新信号状态
  Future<void> _updateSignals() async {
    if (_watchlistItems.isEmpty) return;
    
    try {
      debugPrint('[Watchlist] 开始查询信号状态...');
      final updatedItems = await WatchlistService.updateWatchlistSignals();
      
      if (mounted) {
        setState(() {
          _watchlistItems = updatedItems;
          _applyFiltersAndSort();
        });
        
        // 统计信号
        final buyCount = updatedItems.where((item) => item.hasBuySignal).length;
        final sellCount = updatedItems.where((item) => item.hasSellSignal).length;
        debugPrint('[Watchlist] 信号更新完成: 买入 $buyCount, 卖出 $sellCount');
      }
    } catch (e) {
      debugPrint('[Watchlist] 更新信号失败: $e');
    }
  }

  // 批量更新所有股票价格
  Future<void> _updateAllPrices({bool showLoading = true}) async {
    if (_isUpdatingPrices) return;
    
    setState(() {
      _isUpdatingPrices = true;
    });

    if (showLoading) {
      _refreshAnimationController?.repeat();
    }

    try {
      final updatedItems = await WatchlistService.updateWatchlistPrices(forceUpdate: true);
      if (mounted) {
        setState(() {
          _watchlistItems = updatedItems;
        });
        
        // 应用当前排序选项
        if (_currentSortOption != SortOption.none) {
          _sortWatchlist();
        }
        
        if (showLoading) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text('价格更新完成'),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted && showLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Text('价格更新失败: $e'),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingPrices = false;
        });
        _refreshAnimationController?.stop();
        _refreshAnimationController?.reset();
      }
    }
  }

  Future<void> _clearWatchlist() async {
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
            const Text('确认清空'),
          ],
        ),
        content: const Text('确定要清空所有备选股票吗？此操作不可撤销。'),
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
            child: const Text('确定清空'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await WatchlistService.clearWatchlist();
      if (mounted) {
        if (success) {
          setState(() {
            _watchlistItems.clear();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text('备选池已清空'),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text('清空失败'),
                ],
              ),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    }
  }

  // 手动添加股票对话框
  void _showAddStockDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final codeController = TextEditingController();
    String selectedStrategy = 'volume_wave';
    bool isSearching = false;
    List<Map<String, dynamic>> searchResults = [];
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.65,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // 拖拽指示器
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                // 标题
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.add_circle_outline, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '手动添加股票',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // 搜索框
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    controller: codeController,
                    decoration: InputDecoration(
                      hintText: '输入股票代码或名称搜索',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: isSearching 
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : null,
                      filled: true,
                      fillColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onChanged: (value) async {
                      if (value.length >= 2) {
                        setModalState(() => isSearching = true);
                        try {
                          // 搜索股票
                          final results = await _searchStocks(value);
                          setModalState(() {
                            searchResults = results;
                            isSearching = false;
                          });
                        } catch (e) {
                          setModalState(() => isSearching = false);
                        }
                      } else {
                        setModalState(() => searchResults = []);
                      }
                    },
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // 策略选择
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Text(
                        '选择策略：',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedStrategy,
                              isExpanded: true,
                              dropdownColor: isDark ? Colors.grey.shade800 : Colors.white,
                              items: const [
                                DropdownMenuItem(value: 'volume_wave', child: Text('动量守恒')),
                                DropdownMenuItem(value: 'volume_wave_enhanced', child: Text('动量守恒增强版')),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setModalState(() => selectedStrategy = value);
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // 提示信息
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50.withOpacity(0.5),
                      border: Border.all(
                        color: Colors.orange.shade300,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.orange.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '建议从技术量化页面添加符合策略的股票',
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // 搜索结果列表
                Expanded(
                  child: searchResults.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '输入股票代码或名称搜索',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: searchResults.length,
                          itemBuilder: (context, index) {
                            final stock = searchResults[index];
                            final code = stock['code'] ?? stock['ts_code'] ?? '';
                            final name = stock['name'] ?? '';
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              color: isDark ? Colors.grey.shade800 : Colors.grey.shade50,
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.blue.shade400,
                                        Colors.blue.shade600,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      name.isNotEmpty ? name[0] : '?',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                title: Text(
                                  name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                subtitle: Text(
                                  code,
                                  style: TextStyle(
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  ),
                                ),
                                trailing: ElevatedButton(
                                  onPressed: () => _addStockToWatchlist(
                                    code: code.replaceAll('.SH', '').replaceAll('.SZ', '').replaceAll('.BJ', ''),
                                    name: name,
                                    strategy: selectedStrategy,
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6366F1),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  ),
                                  child: const Text('添加'),
                                ),
                              ),
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
  
  // 搜索股票 - 使用StockProvider的本地缓存数据
  Future<List<Map<String, dynamic>>> _searchStocks(String keyword) async {
    try {
      final stockProvider = Provider.of<StockProvider>(context, listen: false);
      
      // 使用StockProvider的搜索方法（会自动处理初始化）
      final results = await stockProvider.getStockSuggestions(keyword);
      
      debugPrint('[Watchlist] 搜索 "$keyword" 找到 ${results.length} 个结果');
      
      return results.take(20).toList(); // 最多返回20条
    } catch (e) {
      debugPrint('搜索股票失败: $e');
      return [];
    }
  }
  
  // 添加股票到备选池
  Future<void> _addStockToWatchlist({
    required String code,
    required String name,
    required String strategy,
  }) async {
    try {
      // 检查是否已存在
      final exists = _watchlistItems.any((item) => item.code == code);
      if (exists) {
        if (mounted) {
          Navigator.of(context).pop(); // 关闭对话框
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('$name 已在备选池中'),
                ],
              ),
              backgroundColor: Colors.orange.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
        return;
      }
      
      // 创建新的WatchlistItem
      final newItem = WatchlistItem(
        code: code,
        name: name,
        market: _inferMarket(code),
        strategy: strategy,
        addedTime: DateTime.now(),
        originalDetails: {'code': code, 'name': name, 'strategy': strategy},
      );
      
      // 添加到备选池
      final success = await WatchlistService.addToWatchlistItem(newItem);
      
      if (mounted) {
        Navigator.of(context).pop(); // 关闭对话框
        
        if (success) {
          // 重新加载备选池
          await _loadWatchlist();
          
          // 订阅新股票的价格更新
          final apiProvider = Provider.of<ApiProvider>(context, listen: false);
          apiProvider.subscribeStockPrice(code);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('已添加 $name 到备选池'),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text('添加失败'),
                ],
              ),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('添加股票失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('添加失败: $e'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }
  
  // 根据股票代码推断市场
  String _inferMarket(String code) {
    if (code.startsWith('6')) return '上证主板';
    if (code.startsWith('000') || code.startsWith('001') || code.startsWith('002') || code.startsWith('003')) return '深证主板';
    if (code.startsWith('300') || code.startsWith('301')) return '创业板';
    if (code.startsWith('688') || code.startsWith('689')) return '科创板';
    if (code.startsWith('8') || code.startsWith('4')) return '北交所';
    if (code.startsWith('5')) return 'ETF';
    return '其他';
  }

  // 排序选项对话框
  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.sort,
                          color: Colors.blue,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        '排序方式',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                _buildSortOptionTile(
                  setModalState: setModalState,
                  option: SortOption.none,
                  title: '默认排序',
                  subtitle: '不排序',
                ),
                _buildSortOptionTile(
                  setModalState: setModalState,
                  option: SortOption.addedTimeDesc,
                  title: '加入时间（新→旧）',
                  subtitle: '最近加入的排在前面',
                ),
                _buildSortOptionTile(
                  setModalState: setModalState,
                  option: SortOption.addedTimeAsc,
                  title: '加入时间（旧→新）',
                  subtitle: '最早加入的排在前面',
                ),
                _buildSortOptionTile(
                  setModalState: setModalState,
                  option: SortOption.changePercentDesc,
                  title: '涨幅从高到低',
                  subtitle: '先显示涨幅较大的股票',
                ),
                _buildSortOptionTile(
                  setModalState: setModalState,
                  option: SortOption.changePercentAsc,
                  title: '涨幅从低到高',
                  subtitle: '先显示跌幅较大的股票',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  // 构建排序选项项
  Widget _buildSortOptionTile({
    required StateSetter setModalState,
    required SortOption option,
    required String title,
    required String subtitle,
  }) {
    return InkWell(
                  onTap: () {
        setModalState(() {
          _currentSortOption = option;
                    });
                    Navigator.pop(context);
                    _sortWatchlist();
                    _saveSortOption();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: ListTile(
                      leading: Radio<SortOption>(
            value: option,
                        groupValue: _currentSortOption,
                        onChanged: (value) {
              setModalState(() {
                _currentSortOption = option;
                          });
                          Navigator.pop(context);
                          _sortWatchlist();
                          _saveSortOption();
                        },
                      ),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: _currentSortOption == option 
                          ? const Icon(Icons.check_circle, color: Colors.blue) 
                          : null,
                    ),
      ),
    );
  }

  // 应用筛选和排序
  void _applyFiltersAndSort() {
    setState(() {
      // 首先应用信号筛选
      if (_selectedSignalFilter == null) {
        _filteredItems = List.from(_watchlistItems);
      } else if (_selectedSignalFilter == 'buy') {
        _filteredItems = _watchlistItems.where((item) => item.hasBuySignal).toList();
      } else if (_selectedSignalFilter == 'sell') {
        _filteredItems = _watchlistItems.where((item) => item.hasSellSignal).toList();
      } else {
        _filteredItems = List.from(_watchlistItems);
      }
      
      // 然后应用排序
      switch (_currentSortOption) {
        case SortOption.changePercentDesc:
          _filteredItems.sort((a, b) {
            // 处理null值，将null值排在最后
            if (a.changePercent == null && b.changePercent == null) return 0;
            if (a.changePercent == null) return 1;
            if (b.changePercent == null) return -1;
            return b.changePercent!.compareTo(a.changePercent!);
          });
          break;
        case SortOption.changePercentAsc:
          _filteredItems.sort((a, b) {
            // 处理null值，将null值排在最后
            if (a.changePercent == null && b.changePercent == null) return 0;
            if (a.changePercent == null) return 1;
            if (b.changePercent == null) return -1;
            return a.changePercent!.compareTo(b.changePercent!);
          });
          break;
        case SortOption.addedTimeDesc:
          // 加入时间从新到旧
          _filteredItems.sort((a, b) => b.addedTime.compareTo(a.addedTime));
          break;
        case SortOption.addedTimeAsc:
          // 加入时间从旧到新
          _filteredItems.sort((a, b) => a.addedTime.compareTo(b.addedTime));
          break;
        case SortOption.none:
          // 保持当前筛选结果，不额外排序
          break;
      }
    });
  }

  // 处理信号筛选
  void _onSignalFilterSelected(String? signalFilter) {
    setState(() {
      _selectedSignalFilter = signalFilter;
    });
    _applyFiltersAndSort();
  }

  // 保持旧的排序方法兼容性
  void _sortWatchlist() {
    _applyFiltersAndSort();
  }

  @override
  Widget build(BuildContext context) {
    // 确保WebSocket订阅有效
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureSubscription();
    });
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF8F9FA),
      body: Column(
        children: [
          // 使用专业的头部组件
          ProfessionalWatchlistHeader(
            totalCount: _filteredItems.length,
            selectedSignalFilter: _selectedSignalFilter,
            onSignalFilterSelected: _onSignalFilterSelected,
            onRefresh: () {
              _loadWatchlist();
              _updateAllPrices();
            },
            onBack: () => Navigator.of(context).pop(),
            onSort: _showSortOptions,
            onClear: _clearWatchlist,
            onAddStock: _showAddStockDialog,
            isLoading: _isLoading || _isUpdatingPrices,
            buySignalCount: _watchlistItems.where((item) => item.hasBuySignal).length,
            sellSignalCount: _watchlistItems.where((item) => item.hasSellSignal).length,
          ),
          

          
          // 主要内容区域
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('加载备选池中...'),
          ],
        ),
      );
    }

    if (_filteredItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.star_border,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              '备选池为空',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '在股票列表中点击"加关注"来添加股票',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('返回股票列表'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadWatchlist,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _filteredItems.length,
        itemBuilder: (context, index) {
          final item = _filteredItems[index];
          return Dismissible(
            key: ValueKey(item.code),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B6B), Color(0xFFEE5A52)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(
                    Icons.delete_outline,
                    color: Colors.white,
                    size: 24,
                  ),
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
            confirmDismiss: (direction) async {
              return await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('确认删除'),
                  content: Text('确定要从备选池中移除 ${item.name}(${item.code}) 吗？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('删除'),
                    ),
                  ],
                ),
              );
            },
            onDismissed: (direction) async {
              try {
              final success = await WatchlistService.removeFromWatchlist(item.code);
              if (mounted) {
                if (success) {
                  setState(() {
                      // 从原始列表中移除（按code匹配，避免索引问题）
                      _watchlistItems.removeWhere((w) => w.code == item.code);
                      // 重新应用筛选和排序
                      _applyFiltersAndSort();
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('已从备选池移除 ${item.name}'),
                      backgroundColor: Colors.orange,
                      action: SnackBarAction(
                        label: '撤销',
                        textColor: Colors.white,
                        onPressed: () async {
                            try {
                          // 撤销删除，重新添加到备选池
                              final addSuccess = await WatchlistService.addToWatchlistItem(item);
                          if (addSuccess && mounted) {
                                // 重新加载备选池
                                await _loadWatchlist();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('已恢复 ${item.name} 到备选池'),
                                backgroundColor: Colors.green,
                              ),
                            );
                              }
                            } catch (e) {
                              debugPrint('撤销删除失败: $e');
                          }
                        },
                      ),
                    ),
                  );
                } else {
                    // 删除失败，重新加载列表以恢复UI状态
                    await _loadWatchlist();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('删除失败'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              } catch (e) {
                debugPrint('删除股票异常: $e');
                if (mounted) {
                  // 发生异常时重新加载列表
                  await _loadWatchlist();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('删除失败: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: WatchlistItemWidget(
              key: ValueKey('${item.code}_item'),
              item: item,
              onWatchlistChanged: () {
                // 当备选池状态改变时，刷新备选池
                _loadWatchlist();
              },
              allWatchlistItems: _filteredItems, // 传递所有筛选后的备选池股票列表
            ),
          );
        },
      ),
    );
  }
} 