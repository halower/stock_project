import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/stock_indicator.dart';
import '../services/providers/api_provider.dart';
import '../services/providers/theme_provider.dart';
import '../widgets/ai_filter_panel.dart';
import '../widgets/stock_list_item.dart';
import 'stock_detail_screen.dart';
import 'watchlist_screen.dart';
import '../services/strategy_config_service.dart';
import '../services/watchlist_service.dart';

class StockScannerScreen extends StatefulWidget {
  const StockScannerScreen({super.key});

  @override
  State<StockScannerScreen> createState() => _StockScannerScreenState();
}

class _StockScannerScreenState extends State<StockScannerScreen> {
  String _selectedMarket = '全部';
  // 市场列表改为从ApiProvider动态获取，不再硬编码
  List<String> _markets = ['全部']; // 默认只有"全部"，等待从后端加载
  // 当前选择的策略 - 从ApiProvider动态获取
  String _selectedStrategy = '';
  // 添加一个标记，控制是否自动加载数据
  final bool _autoLoadData = false;
  // 添加一个变量跟踪是否是首次加载
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    
    debugPrint('初始市场: $_selectedMarket');
    debugPrint('初始策略: $_selectedStrategy');
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 获取ApiProvider
      final apiProvider = Provider.of<ApiProvider>(context, listen: false);
      
      // 同步当前选择的市场和策略
      setState(() {
        _selectedMarket = apiProvider.selectedMarket.isEmpty ? '全部' : apiProvider.selectedMarket;
        _selectedStrategy = apiProvider.selectedStrategy;
      });
      
      debugPrint('同步后的市场: $_selectedMarket');
      debugPrint('同步后的策略: $_selectedStrategy');
      
      // 加载市场类型列表
      await _loadMarketTypes();
      
      // 首次进入时，检查是否需要加载数据
      if (_isFirstLoad) {
        // 先确保策略正确初始化
        await _initializeStrategies();
        
        // 主动加载数据，确保调用后端API
        debugPrint('=== 首次加载，开始调用后端API ===');
        await _loadData();
        
        _isFirstLoad = false;
      }
    });
  }

  // 初始化策略并确保它们正确加载
  Future<void> _initializeStrategies() async {
    try {
      // 不再清除缓存，让策略服务自己管理缓存
      debugPrint('初始化策略列表');
      
      // 使用ApiProvider加载策略（会使用缓存）
      final apiProvider = Provider.of<ApiProvider>(context, listen: false);
      
      // 如果策略列表为空，才刷新
      if (apiProvider.strategies.isEmpty) {
        debugPrint('策略列表为空，需要加载');
      await apiProvider.refreshStrategies();
      } else {
        debugPrint('策略列表已存在，使用现有数据: ${apiProvider.strategies.length} 个策略');
      }
      
      // 更新当前选择的策略
      setState(() {
        _selectedStrategy = apiProvider.selectedStrategy;
      });
    } catch (e) {
      debugPrint('初始化策略失败: $e');
    }
  }

  // 加载市场类型列表
  Future<void> _loadMarketTypes() async {
    try {
      debugPrint('开始加载市场类型列表...');
      final apiProvider = Provider.of<ApiProvider>(context, listen: false);
      
      // 如果市场类型已加载，直接使用
      if (apiProvider.marketTypesLoaded && apiProvider.marketTypes.isNotEmpty) {
        debugPrint('市场类型已加载，使用现有数据: ${apiProvider.marketTypes.length} 个类型');
        setState(() {
          _markets = apiProvider.marketTypes.map((m) => m['name'] as String).toList();
        });
      } else {
        debugPrint('市场类型未加载，从后端获取...');
        await apiProvider.refreshMarketTypes();
        
        if (apiProvider.marketTypes.isNotEmpty) {
          setState(() {
            _markets = apiProvider.marketTypes.map((m) => m['name'] as String).toList();
          });
          debugPrint('成功加载市场类型: $_markets');
        } else {
          debugPrint('市场类型加载失败，使用默认列表');
          // 使用默认市场列表作为降级方案
          setState(() {
            _markets = ['全部', '主板', '创业板', '科创板', '北交所', 'ETF'];
          });
        }
      }
    } catch (e) {
      debugPrint('加载市场类型失败: $e');
      // 使用默认市场列表作为降级方案
      setState(() {
        _markets = ['全部', '主板', '创业板', '科创板', '北交所', 'ETF'];
      });
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    
    final apiProvider = Provider.of<ApiProvider>(context, listen: false);
    
    // 打印策略列表信息
    debugPrint('策略列表大小: ${apiProvider.strategies.length}');
    for (final strategy in apiProvider.strategies) {
      debugPrint('策略: ${strategy['value'] ?? '空值'} - ${strategy['label']}');
    }
    
    // 检查策略列表是否有空值
    bool hasEmptyValues = apiProvider.strategies.any((s) => s['value'] == null || s['value']!.isEmpty);
    if (hasEmptyValues) {
      debugPrint('警告: 存在策略值为空的情况，尝试重新初始化策略');
      await _initializeStrategies();
    }
    
    // 使用当前的市场和策略进行筛选
    if (_selectedMarket != apiProvider.selectedMarket) {
      await apiProvider.selectMarket(_selectedMarket);
    }
    
    if (_selectedStrategy != apiProvider.selectedStrategy) {
      await apiProvider.selectStrategy(_selectedStrategy);
    }
    
    // 主动触发股票扫描，这会调用后端API
    debugPrint('=== 开始主动触发股票扫描 ===');
    await apiProvider.scanStocksByIndicator(
      market: _selectedMarket,
      strategy: _selectedStrategy,
    );
    debugPrint('=== 股票扫描完成 ===');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('技术面量化分析'),
        actions: [
          // 备选池按钮 - 使用ValueListenableBuilder监听状态变化，与AI图标保持一致的高度
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Container(
              margin: const EdgeInsets.only(bottom: 4.0),
              child: ValueListenableBuilder<int>(
                valueListenable: WatchlistService.watchlistChangeNotifier,
                builder: (context, changeCount, child) {
                  return FutureBuilder<int>(
                    future: WatchlistService.getWatchlistCount(),
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      return Stack(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.star_border),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const WatchlistScreen()),
                              );
                            },
                            tooltip: '我的备选池',
                          ),
                          if (count > 0)
                            Positioned(
                              right: 6,
                              top: 6,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Text(
                                  count > 99 ? '99+' : count.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
          // 将AI筛选图标放到右上角，并增加底部边距
          Padding(
            padding: const EdgeInsets.only(right: 8.0, bottom: 4.0),
            child: Container(
              margin: const EdgeInsets.only(bottom: 4.0),
              child: const AIFilterPanel(),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 合规性提醒横幅
          _buildDisclaimerBanner(context),
          
          // 筛选区域
          Card(
            margin: const EdgeInsets.all(8.0),
            elevation: 1.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Consumer<ApiProvider>(
                builder: (context, apiProvider, child) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 筛选选项区域
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 模型选择
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.model_training,
                                        size: 14,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '模型',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surface,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                                      ),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: apiProvider.strategies.isEmpty
                                          ? const Center(
                                              child: SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              ),
                                            )
                                          : Builder(
                                              builder: (context) {
                                                // 确保选择的策略在列表中存在
                                                final hasSelectedStrategy = apiProvider.strategies.any((item) => item['value'] == _selectedStrategy);
                                                final effectiveValue = hasSelectedStrategy 
                                                    ? _selectedStrategy 
                                                    : (apiProvider.strategies.firstWhere(
                                                        (item) => item['value'] != null && item['value']!.isNotEmpty,
                                                        orElse: () => {'value': '', 'label': '默认策略'}
                                                      )['value'] ?? '');
                                                
                                                // 如果effectiveValue为空或null，显示加载提示（极少情况）
                                                if (effectiveValue.isEmpty) {
                                                  debugPrint('有效值为空，显示加载中');
                                                  return const Center(
                                                    child: SizedBox(
                                                      width: 16,
                                                      height: 16,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                    ),
                                                  );
                                                }
                                                
                                                debugPrint('下拉框使用值: $effectiveValue, 原始值: $_selectedStrategy, 匹配: $hasSelectedStrategy');
                                                
                                                // 防御式检查 - 确保列表中的每个项目都有唯一的非空值
                                                final itemValues = apiProvider.strategies
                                                    .map((item) => item['value'])
                                                    .where((value) => value != null && value.isNotEmpty)
                                                    .toList();
                                                final uniqueValues = itemValues.toSet().toList();
                                                
                                                debugPrint('项目值: $itemValues');
                                                debugPrint('唯一值: $uniqueValues');
                                                
                                                if (itemValues.length != uniqueValues.length) {
                                                  debugPrint('警告：存在重复的策略值');
                                                }
                                                
                                                return DropdownButton<String>(
                                                  value: effectiveValue,
                                                  isExpanded: true,
                                                  isDense: true,
                                                  icon: const Icon(Icons.arrow_drop_down, size: 20),
                                                  items: apiProvider.strategies.map((Map<String, String> item) {
                                                    final itemValue = item['value'] ?? '';
                                                    debugPrint('构建下拉项: $itemValue - ${item['label']}');
                                                    
                                                    // 防止出现空值
                                                    if (itemValue.isEmpty) {
                                                      return DropdownMenuItem<String>(
                                                        value: 'default_placeholder',
                                                        child: Text(
                                                          item['label'] ?? '未命名策略',
                                                          style: TextStyle(
                                                            color: Theme.of(context).colorScheme.onSurface,
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                    
                                                    return DropdownMenuItem<String>(
                                                      value: itemValue,
                                                      child: Text(
                                                        item['label'] ?? '未命名策略',
                                                            style: TextStyle(
                                                              color: Theme.of(context).colorScheme.onSurface,
                                                              fontSize: 13,
                                                            ),
                                                      ),
                                                    );
                                                  }).toList(),
                                                  onChanged: (String? newValue) {
                                                    if (newValue != null && newValue.isNotEmpty) {
                                                      debugPrint('选择策略: $newValue');
                                                      setState(() {
                                                        _selectedStrategy = newValue;
                                                      });
                                                      
                                                      // 使用选中的策略重新扫描
                                                      apiProvider.selectStrategy(newValue);
                                                    }
                                                  },
                                                );
                                              },
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 10),
                            
                            // 市场选择
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.business,
                                        size: 14,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '市场',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surface,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                                      ),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _selectedMarket,
                                        isExpanded: true,
                                        isDense: true,
                                        icon: const Icon(Icons.arrow_drop_down, size: 20),
                                        items: _markets.map((String market) {
                                          return DropdownMenuItem<String>(
                                            value: market,
                                            child: Text(
                                              market,
                                              style: TextStyle(
                                                color: Theme.of(context).colorScheme.onSurface,
                                                fontSize: 13,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (String? newValue) {
                                          if (newValue != null) {
                                            setState(() {
                                              _selectedMarket = newValue;
                                            });
                                            
                                            // 选择市场并刷新结果（前端筛选，无需等待）
                                            apiProvider.selectMarket(newValue);
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      // 股票数量显示 - 移动到筛选区域底部
                      if (!apiProvider.isLoading) 
                        Padding(
                          padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.bar_chart,
                                size: 16,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '显示 ${_getResultCount(apiProvider)} 只股票',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.secondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              if (apiProvider.isAIFiltering)
                                Row(
                                  children: [
                                    SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'AI分析中...',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        
                      // AI筛选进度显示
                      if (apiProvider.isAIFiltering && apiProvider.aiFilterResult != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          child: _buildAIProgressIndicator(apiProvider),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
          // 股票列表
          Expanded(
            child: _buildStockList(),
          ),
        ],
      ),
    );
  }
  
  // 获取要显示的结果数量
  int _getResultCount(ApiProvider apiProvider) {
    // 如果有AI筛选结果并且已完成，则显示筛选后的数量
    if (apiProvider.aiFilterResult != null && 
        apiProvider.aiFilterResult!.completed && 
        !apiProvider.isAIFiltering) {
      return apiProvider.aiFilterResult!.stocks.length;
    }
    // 否则显示常规扫描结果数量
    return apiProvider.scanResults.length;
  }
  
  // 获取要显示的股票列表
  List<StockIndicator> _getStocksToDisplay(ApiProvider apiProvider) {
    // 如果有AI筛选结果并且已完成，则显示筛选后的列表
    if (apiProvider.aiFilterResult != null && 
        apiProvider.aiFilterResult!.completed && 
        !apiProvider.isAIFiltering) {
      return apiProvider.aiFilterResult!.stocks;
    }
    // 否则显示常规扫描结果
    return apiProvider.scanResults;
  }
  
  Widget _buildStockList() {
    return Consumer<ApiProvider>(
      builder: (context, apiProvider, child) {
        if (apiProvider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (apiProvider.error.isNotEmpty) {
          return Center(
            child: Text('加载错误: ${apiProvider.error}'),
          );
        }

        final stocksToDisplay = _getStocksToDisplay(apiProvider);
        
        if (stocksToDisplay.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: 56,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                const Text('没有找到符合条件的股票'),
              ],
            ),
          );
        }

        // 使用ListView.builder显示股票列表
        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: stocksToDisplay.length,
          itemBuilder: (context, index) {
            final stock = stocksToDisplay[index];
            // 显示AI分析结果（如果来自AI筛选）
            final showAIAnalysis = apiProvider.aiFilterResult != null && 
                apiProvider.aiFilterResult!.completed;
            return StockListItem(
              stock: stock,
              showAIAnalysis: showAIAnalysis,
              onWatchlistChanged: () {
                // 当备选池状态变化时，刷新AppBar中的计数
                setState(() {});
              },
            );
          },
        );
      },
    );
  }
  
  // 格式化成交量显示
  String _formatVolume(int? volume) {
    if (volume == null) return '-';
    
    if (volume >= 100000000) {
      return '${(volume / 100000000).toStringAsFixed(2)}亿';
    } else if (volume >= 10000) {
      return '${(volume / 10000).toStringAsFixed(2)}万';
    } else {
      return volume.toString();
    }
  }
  
  // 构建AI筛选进度指示器
  Widget _buildAIProgressIndicator(ApiProvider apiProvider) {
    final result = apiProvider.aiFilterResult;
    if (result == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题和百分比
          Row(
            children: [
              ShaderMask(
                shaderCallback: (rect) {
                  return const LinearGradient(
                    colors: [
                      Color(0xFF2F80ED), // 更现代的蓝色
                      Color(0xFF56CCF2), // 淡蓝色
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(rect);
                },
                child: const Icon(
                Icons.psychology,
                size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'AI分析进度',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${(result.progressPercentage * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 10),
          
          // 进度条
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: result.progressPercentage,
              minHeight: 10,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
            ),
          ),
          
          const SizedBox(height: 10),
          
          // 处理数量信息
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '已处理: ${result.processedCount}/${result.totalCount}',
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                '剩余: ${result.totalCount - result.processedCount}',
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                '符合条件: ${result.stocks.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 合规性提醒横幅
  Widget _buildDisclaimerBanner(BuildContext context) {
    // 使用StatefulBuilder来管理横幅的显示状态
    return StatefulBuilder(
      builder: (context, setState) {
        // 在本地状态中跟踪横幅是否可见
        final ValueNotifier<bool> showBanner = ValueNotifier<bool>(true);
        
        return ValueListenableBuilder<bool>(
          valueListenable: showBanner,
          builder: (context, isVisible, child) {
            if (!isVisible) {
              return const SizedBox.shrink(); // 不显示横幅
            }
            
            return Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.amber.shade700,
                    Colors.amber.shade500,
                    Colors.amber.shade700,
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildScrollingText(
                          '风险提示：本页面提供的量化模型均为个人学习作品,结果仅供参考，不构成投资建议。投资有风险，入市需谨慎。用户应自行对投资决策承担责任。',
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          showBanner.value = false;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
  
  // 创建自动滚动文本组件
  Widget _buildScrollingText(String text) {
    return StatefulBuilder(
      builder: (context, setState) {
        // 使用ScrollController实现自动滚动
        final ScrollController scrollController = ScrollController();
        
        // 使用后置帧回调开始滚动
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // 定期执行滚动动画
          Future.delayed(const Duration(seconds: 2), () {
            if (scrollController.hasClients) {
              final maxScroll = scrollController.position.maxScrollExtent;
              if (maxScroll > 0) {
                scrollController.animateTo(
                  maxScroll,
                  duration: Duration(seconds: maxScroll ~/ 20 + 5), // 根据内容长度调整滚动时间
                  curve: Curves.linear,
                ).then((_) {
                  // 滚动到末尾后，回到开始位置
                  Future.delayed(const Duration(seconds: 1), () {
                    if (scrollController.hasClients) {
                      scrollController.animateTo(
                        0,
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOut,
                      );
                    }
                  });
                });
              }
            }
          });
        });
        
        return SingleChildScrollView(
          controller: scrollController,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(), // 禁用手动滚动
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      },
    );
  }
} 