import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/watchlist_item.dart';
import '../services/watchlist_service.dart';
import '../widgets/watchlist_item_widget.dart';
import '../widgets/enhanced_watchlist_header.dart';
import '../widgets/professional_watchlist_header.dart';

// 添加排序枚举
enum SortOption {
  none,
  changePercentAsc,  // 涨幅从低到高
  changePercentDesc, // 涨幅从高到低
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
  // 添加市场筛选状态
  String? _selectedMarket;
  
  // 排序选项的键
  static const String _sortOptionKey = 'watchlist_sort_option';
  
  @override
  void initState() {
    super.initState();
    _refreshAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _loadSortOption().then((_) => _loadWatchlist());
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

  // 排序选项对话框
  void _showSortOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
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
                InkWell(
                  onTap: () {
                    setState(() {
                      _currentSortOption = SortOption.none;
                    });
                    Navigator.pop(context);
                    _sortWatchlist();
                    _saveSortOption();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: ListTile(
                      leading: Radio<SortOption>(
                        value: SortOption.none,
                        groupValue: _currentSortOption,
                        onChanged: (value) {
                          setState(() {
                            _currentSortOption = SortOption.none;
                          });
                          Navigator.pop(context);
                          _sortWatchlist();
                          _saveSortOption();
                        },
                      ),
                      title: const Text('默认排序'),
                      subtitle: const Text('按添加时间排序'),
                      trailing: _currentSortOption == SortOption.none 
                          ? const Icon(Icons.check_circle, color: Colors.blue) 
                          : null,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    setState(() {
                      _currentSortOption = SortOption.changePercentAsc;
                    });
                    Navigator.pop(context);
                    _sortWatchlist();
                    _saveSortOption();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: ListTile(
                      leading: Radio<SortOption>(
                        value: SortOption.changePercentAsc,
                        groupValue: _currentSortOption,
                        onChanged: (value) {
                          setState(() {
                            _currentSortOption = SortOption.changePercentAsc;
                          });
                          Navigator.pop(context);
                          _sortWatchlist();
                          _saveSortOption();
                        },
                      ),
                      title: const Text('涨幅从低到高'),
                      subtitle: const Text('先显示跌幅较大的股票'),
                      trailing: _currentSortOption == SortOption.changePercentAsc 
                          ? const Icon(Icons.check_circle, color: Colors.blue) 
                          : null,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    setState(() {
                      _currentSortOption = SortOption.changePercentDesc;
                    });
                    Navigator.pop(context);
                    _sortWatchlist();
                    _saveSortOption();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: ListTile(
                      leading: Radio<SortOption>(
                        value: SortOption.changePercentDesc,
                        groupValue: _currentSortOption,
                        onChanged: (value) {
                          setState(() {
                            _currentSortOption = SortOption.changePercentDesc;
                          });
                          Navigator.pop(context);
                          _sortWatchlist();
                          _saveSortOption();
                        },
                      ),
                      title: const Text('涨幅从高到低'),
                      subtitle: const Text('先显示涨幅较大的股票'),
                      trailing: _currentSortOption == SortOption.changePercentDesc 
                          ? const Icon(Icons.check_circle, color: Colors.blue) 
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 应用筛选和排序
  void _applyFiltersAndSort() {
    setState(() {
      // 首先应用市场筛选
      if (_selectedMarket == null) {
        _filteredItems = List.from(_watchlistItems);
      } else {
        _filteredItems = _watchlistItems.where((item) {
          return item.market == _selectedMarket;
        }).toList();
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
        case SortOption.none:
        default:
          // 保持当前筛选结果，不额外排序
          break;
      }
    });
  }

  // 处理市场筛选
  void _onMarketSelected(String? market) {
    setState(() {
      _selectedMarket = market;
    });
    _applyFiltersAndSort();
  }

  // 保持旧的排序方法兼容性
  void _sortWatchlist() {
    _applyFiltersAndSort();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF8F9FA),
      body: Column(
        children: [
          // 使用专业的头部组件
          ProfessionalWatchlistHeader(
            totalCount: _filteredItems.length,
            selectedMarket: _selectedMarket,
            onMarketSelected: _onMarketSelected,
            onRefresh: () {
              _loadWatchlist();
              _updateAllPrices();
            },
            onBack: () => Navigator.of(context).pop(),
            onSort: _showSortOptions,
            onClear: _clearWatchlist,
            isLoading: _isLoading || _isUpdatingPrices,
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
              final success = await WatchlistService.removeFromWatchlist(item.code);
              if (mounted) {
                if (success) {
                  setState(() {
                    _watchlistItems.removeAt(index);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('已从备选池移除 ${item.name}'),
                      backgroundColor: Colors.orange,
                      action: SnackBarAction(
                        label: '撤销',
                        textColor: Colors.white,
                        onPressed: () async {
                          // 撤销删除，重新添加到备选池
                          final addSuccess = await WatchlistService.addToWatchlist(item.toStockIndicator());
                          if (addSuccess && mounted) {
                            setState(() {
                              _watchlistItems.insert(index, item);
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('已恢复 ${item.name} 到备选池'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('删除失败'),
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