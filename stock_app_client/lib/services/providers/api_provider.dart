import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import '../../models/stock_indicator.dart';
import '../../models/stock_detailed_info.dart';
import '../../models/ai_filter_result.dart';
import '../api_service.dart';
import '../ai_stock_filter_service.dart';
import '../strategy_config_service.dart';
import '../websocket_service.dart';

// 获取默认策略列表（仅在API完全失败时使用，策略名称将通过API动态获取）
List<Map<String, String>> _getEmergencyStrategies() {
  return [
    {'value': 'volume_wave', 'label': 'volume_wave'},
    {'value': 'trend_continuation', 'label': 'trend_continuation'},
  ];
}

class ApiProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final AIStockFilterService _aiFilterService = AIStockFilterService();
  final WebSocketService _wsService = WebSocketService();
  
  // 价格更新回调列表（用于备选池等其他页面监听）
  final List<Function(List<dynamic>)> _priceUpdateCallbacks = [];
  
  // 状态变量
  bool _isLoading = false;
  String _error = '';
  
  // 扫描结果
  List<StockIndicator> _scanResults = [];
  
  // 当前选中的市场
  String _selectedMarket = '全部'; // 默认为全部市场
  
  // 当前选中的策略
  String _selectedStrategy = ''; // 默认为空，等待从后端加载
  
  // 当前查看的股票详情
  final Map<String, StockDetailedInfo> _stockDetailsCache = {};
  
  // AI筛选结果
  AIFilterResult? _aiFilterResult;
  bool _isAIFiltering = false;
  
  // 策略列表
  List<Map<String, String>> _strategies = [];
  
  // 市场类型列表
  List<Map<String, dynamic>> _marketTypes = [];
  bool _marketTypesLoaded = false;
  
  // 添加一个变量来存储原始的全量数据
  List<StockIndicator> _allStocksCache = [];
  
  // 添加一个订阅管理器，防止释放后的通知引起错误
  final List<StreamSubscription> _subscriptions = [];
  bool _disposed = false;
  
  // Getters
  bool get isLoading => _isLoading;
  String get error => _error;
  List<StockIndicator> get scanResults => _scanResults;
  String get selectedMarket => _selectedMarket;
  String get selectedStrategy => _selectedStrategy;
  String get selectedStrategyName {
    // 根据策略列表查找策略名称
    final strategy = _strategies.firstWhere(
      (item) => item['value'] == _selectedStrategy,
      orElse: () => {'value': _selectedStrategy, 'label': _selectedStrategy.isEmpty ? '未知策略' : _selectedStrategy},
    );
    return strategy['label'] ?? '未知策略';
  }
  AIFilterResult? get aiFilterResult => _aiFilterResult;
  bool get isAIFiltering => _isAIFiltering;
  Stream<AIFilterResult> get aiFilterProgressStream => _aiFilterService.progressStream;
  List<Map<String, String>> get strategies => _strategies;
  List<Map<String, dynamic>> get marketTypes => _marketTypes;
  bool get marketTypesLoaded => _marketTypesLoaded;
  
  ApiProvider() {
    // 监听AI筛选进度
    final subscription = _aiFilterService.progressStream.listen((result) {
      // 如果Provider已销毁，不更新状态
      if (_disposed) return;
      
      _aiFilterResult = result;
      _isAIFiltering = !result.completed;
      
      try {
        notifyListeners();
      } catch (e) {
        debugPrint('AI筛选进度通知时出错，可能监听器已销毁: $e');
      }
    });
    _subscriptions.add(subscription);
    
    // 延迟初始化WebSocket（避免启动时阻塞）
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!_disposed) {
        // 注册WebSocket价格更新处理器
        _wsService.registerHandler('price_update', _handlePriceUpdate);
        // 监听WebSocket状态变化
        _wsService.addListener(_onWebSocketStatusChanged);
      }
    });
    
    // 立即从服务器加载策略
    debugPrint('ApiProvider初始化: 开始从后端加载策略列表');
    _loadStrategies();
    
    // 立即从服务器加载市场类型
    debugPrint('ApiProvider初始化: 开始从后端加载市场类型列表');
    _loadMarketTypes();
  }
  
  // ==================== WebSocket相关方法 ====================
  
  /// WebSocket连接状态
  WebSocketStatus get wsStatus => _wsService.status;
  WebSocketService get wsService => _wsService;
  
  /// 连接WebSocket
  Future<void> connectWebSocket() async {
    try {
      // 从配置中获取WebSocket URL
      const baseUrl = ApiService.baseUrl;
      final wsUrl = baseUrl.replaceFirst('http', 'ws') + '/ws/stock/prices';
      
      debugPrint('[API] 连接WebSocket: $wsUrl');
      await _wsService.connect(wsUrl);
    } catch (e) {
      debugPrint('[API] WebSocket连接失败: $e');
    }
  }
  
  /// 异步连接WebSocket（不阻塞主流程）
  void _connectWebSocketAsync(String strategy) {
    // 延迟执行，避免阻塞UI
    Future.delayed(const Duration(seconds: 2), () async {
      if (_disposed) return;
      
      try {
        if (!_wsService.isConnected) {
          debugPrint('[API] 信号加载完成，尝试连接WebSocket...');
          await connectWebSocket();
          
          // 等待连接建立
          await Future.delayed(const Duration(milliseconds: 500));
        }
        
        // 订阅当前策略的价格更新
        if (_wsService.isConnected && strategy.isNotEmpty) {
          subscribeStrategyPrices(strategy);
        }
      } catch (e) {
        debugPrint('[API] WebSocket连接/订阅失败: $e');
        // 失败不影响主流程
      }
    });
  }
  
  /// 订阅策略价格更新
  void subscribeStrategyPrices(String strategy) {
    if (_wsService.isConnected) {
      _wsService.subscribeStrategy(strategy);
      debugPrint('[API] 订阅策略价格: $strategy');
    } else {
      debugPrint('[API] WebSocket未连接，无法订阅');
    }
  }
  
  /// 订阅单个股票价格更新
  void subscribeStockPrice(String stockCode) {
    if (_wsService.isConnected) {
      _wsService.subscribeStock(stockCode);
      debugPrint('[API] 订阅股票价格: $stockCode');
    } else {
      debugPrint('[API] WebSocket未连接，无法订阅股票');
    }
  }
  
  /// 取消订阅单个股票价格更新
  void unsubscribeStockPrice(String stockCode) {
    if (_wsService.isConnected) {
      _wsService.unsubscribeStock(stockCode);
      debugPrint('[API] 取消订阅股票价格: $stockCode');
    }
  }
  
  /// 注册价格更新回调（用于备选池等页面）
  void addPriceUpdateCallback(Function(List<dynamic>) callback) {
    if (!_priceUpdateCallbacks.contains(callback)) {
      _priceUpdateCallbacks.add(callback);
      debugPrint('[API] 注册价格更新回调，当前回调数: ${_priceUpdateCallbacks.length}');
    }
  }
  
  /// 移除价格更新回调
  void removePriceUpdateCallback(Function(List<dynamic>) callback) {
    _priceUpdateCallbacks.remove(callback);
    debugPrint('[API] 移除价格更新回调，当前回调数: ${_priceUpdateCallbacks.length}');
  }
  
  /// 处理价格更新
  void _handlePriceUpdate(Map<String, dynamic> message) {
    try {
      debugPrint('[API] 收到价格更新消息: ${message.keys}');
      debugPrint('[API] data类型: ${message['data']?.runtimeType}');
      
      final updates = message['data'] as List<dynamic>?;
      
      if (updates == null || updates.isEmpty) {
        debugPrint('[API] updates为空或null');
        return;
      }
      
      debugPrint('[API] 收到 ${updates.length} 个价格更新');
      debugPrint('[API] 当前_scanResults数量: ${_scanResults.length}');
      
      // 打印前3个更新的股票代码
      if (updates.length > 0) {
        final updateCodes = updates.take(3).map((u) => u['code']).toList();
        debugPrint('[API] 推送的股票代码（前3个）: $updateCodes');
      }
      
      // 打印前3个_scanResults的股票代码
      if (_scanResults.isNotEmpty) {
        final scanCodes = _scanResults.take(3).map((s) => s.code).toList();
        debugPrint('[API] _scanResults的股票代码（前3个）: $scanCodes');
      }
      
      int updateCount = 0;
      
      // 创建更新后的列表
      final updatedResults = <StockIndicator>[];
      
      for (var signal in _scanResults) {
        // 查找是否有该股票的价格更新
        final update = updates.firstWhere(
          (u) => u['code'] == signal.code,
          orElse: () => null,
        );
        
        if (update != null) {
          final oldPrice = signal.price;
          final newPrice = (update['price'] as num?)?.toDouble() ?? signal.price;
          final oldChange = signal.changePercent;
          final newChange = (update['change_percent'] as num?)?.toDouble() ?? signal.changePercent;
          
          debugPrint('[API] 更新 ${signal.code}: price $oldPrice → $newPrice, change $oldChange% → $newChange%');
          
          // 创建新的StockIndicator对象（因为是final字段）
          updatedResults.add(StockIndicator(
            market: signal.market,
            code: signal.code,
            name: signal.name,
            signal: signal.signal,
            signalReason: signal.signalReason,
            price: newPrice,
            changePercent: newChange,
            volume: (update['volume'] as num?)?.toInt() ?? signal.volume,
            volumeRatio: signal.volumeRatio,
            details: signal.details,
            strategy: signal.strategy,
          ));
          updateCount++;
        } else {
          updatedResults.add(signal);
        }
      }
      
      if (updateCount > 0) {
        _scanResults = updatedResults;
        debugPrint('[API] ✅ WebSocket更新了 $updateCount 个股票的价格，准备刷新UI');
        _safeNotifyListeners();
        debugPrint('[API] ✅ UI刷新通知已发送');
      } else {
        debugPrint('[API] ⚠️ 没有匹配的股票被更新');
      }
      
      // 通知所有注册的回调（用于备选池等页面）
      for (var callback in _priceUpdateCallbacks) {
        try {
          callback(updates);
        } catch (e) {
          debugPrint('[API] 价格更新回调执行失败: $e');
        }
      }
      
    } catch (e) {
      debugPrint('[API] 处理价格更新失败: $e');
    }
  }
  
  /// WebSocket状态变化处理
  void _onWebSocketStatusChanged() {
    _safeNotifyListeners();
    
    // 如果连接成功，自动订阅当前策略
    if (_wsService.isConnected && _selectedStrategy.isNotEmpty) {
      subscribeStrategyPrices(_selectedStrategy);
    }
  }
  
  @override
  void dispose() {
    _disposed = true;
    // 取消所有订阅
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    // 断开WebSocket连接
    _wsService.dispose();
    super.dispose();
  }
  
  // 安全地通知监听器，防止在Provider销毁后调用
  void _safeNotifyListeners() {
    if (!_disposed) {
      try {
        notifyListeners();
      } catch (e) {
        debugPrint('通知监听器出错: $e');
      }
    }
  }
  
  // 加载策略列表
  Future<void> _loadStrategies() async {
    try {
      debugPrint('开始从后端加载策略列表...');
      final strategies = await StrategyConfigService.getStrategies();
      debugPrint('成功加载策略列表: ${strategies.length}个策略');
      
      // 检查是否有无效的策略项（值为空的情况）
      final validStrategies = strategies.where((item) {
        final hasValue = item['value'] != null && item['value']!.isNotEmpty;
        final hasLabel = item['label'] != null && item['label']!.isNotEmpty;
        return hasValue && hasLabel;
      }).toList();
      
      debugPrint('有效策略数量: ${validStrategies.length}/${strategies.length}');
      
      // 优先使用后端返回的策略数据
      if (validStrategies.isNotEmpty) {
        _strategies = validStrategies;
        
        // 设置默认选中第一个策略
        if (_selectedStrategy.isEmpty || !_strategies.any((item) => item['value'] == _selectedStrategy)) {
          _selectedStrategy = _strategies.first['value']!;
          debugPrint('设置默认选中策略: $_selectedStrategy');
        }
        
        debugPrint('成功设置策略列表，当前选中: $_selectedStrategy');
        for (var strategy in _strategies) {
          debugPrint('策略: ${strategy['value']} - ${strategy['label']}');
        }
        
        notifyListeners();
      } else {
        debugPrint('后端返回的策略列表为空或无效，使用紧急策略列表');
        _strategies = _getEmergencyStrategies();
        _selectedStrategy = _strategies.first['value']!;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('从后端加载策略列表失败: $e - 使用紧急策略列表');
      _strategies = _getEmergencyStrategies();
      _selectedStrategy = _strategies.first['value']!;
      notifyListeners();
    }
  }
  
  // 加载市场类型列表
  Future<void> _loadMarketTypes() async {
    try {
      debugPrint('开始从后端加载市场类型列表...');
      final marketTypes = await _apiService.getMarketTypes();
      debugPrint('成功加载市场类型列表: ${marketTypes.length}个类型');
      
      if (marketTypes.isNotEmpty) {
        _marketTypes = marketTypes;
        _marketTypesLoaded = true;
        
        debugPrint('成功设置市场类型列表');
        for (var market in _marketTypes) {
          debugPrint('市场类型: ${market['code']} - ${market['name']}');
        }
        
        notifyListeners();
      } else {
        debugPrint('后端返回的市场类型列表为空');
        _marketTypesLoaded = false;
      }
    } catch (e) {
      debugPrint('从后端加载市场类型列表失败: $e');
      _marketTypesLoaded = false;
    }
  }
  
  // 刷新市场类型列表
  Future<void> refreshMarketTypes() async {
    _marketTypesLoaded = false;
    await _loadMarketTypes();
  }
  
  // 刷新策略列表
  Future<void> refreshStrategies() async {
    try {
      // 先设置为加载中状态
      _isLoading = true;
      notifyListeners();
      
      final strategies = await StrategyConfigService.refreshStrategies();
      debugPrint('刷新策略列表成功: ${strategies.length}个策略');
      
      // 只有当服务器返回非空列表时才更新
      if (strategies.isNotEmpty) {
        // 检查策略项是否有空值字段，筛选出有效的策略
        final validStrategies = strategies.where((item) {
          final hasValue = item['value'] != null && item['value']!.isNotEmpty;
          final hasLabel = item['label'] != null && item['label']!.isNotEmpty;
          return hasValue && hasLabel;
        }).toList();
        
        debugPrint('有效策略数量: ${validStrategies.length}/${strategies.length}');
        
        if (validStrategies.isNotEmpty) {
          _strategies = validStrategies;
          
          // 检查当前选择的策略是否在新列表中存在
          if (!_strategies.any((item) => item['value'] == _selectedStrategy)) {
            debugPrint('当前选择的策略 $_selectedStrategy 不在最新列表中，重置为第一个策略');
            _selectedStrategy = _strategies.first['value']!;
          }
        } else {
          debugPrint('没有有效策略，将使用紧急策略列表');
          _strategies = _getEmergencyStrategies();
        }
      } else {
        debugPrint('刷新的策略列表为空，使用紧急策略列表');
        _strategies = _getEmergencyStrategies();
      }
      
      _isLoading = false;
      notifyListeners();
      return;
    } catch (e) {
      debugPrint('刷新策略列表失败: $e');
      // 使用紧急策略列表作为备选
      _strategies = _getEmergencyStrategies();
      _isLoading = false;
      notifyListeners();
      rethrow; // 将错误向上传递
    }
  }
  
  // 获取股票指标扫描结果
  Future<void> scanStocksByIndicator({String? market, String? strategy}) async {
    // 使用微任务确保状态更新不在构建过程中执行
    Future.microtask(() {
      _isLoading = true;
      notifyListeners();
    });
    
    try {
      final List<Map<String, dynamic>> results;
      
      // 使用传入的策略参数，如果没有则使用已选择的策略
      final String strategyParam = strategy ?? _selectedStrategy;
      
      // 获取买入信号股票列表，并传入策略参数
      if (_selectedMarket == '全部' || _selectedMarket.isEmpty) {
        // 全部市场，获取买入信号
        results = await _apiService.getBuySignalStocks(strategy: strategyParam);
      } else {
        // 筛选特定市场，此处需要后端支持按市场筛选功能
        // 如果后端未实现，这里的逻辑需要调整
        results = await _apiService.getBuySignalStocks(strategy: strategyParam);
      }
      
      _scanResults = results.map((item) => StockIndicator.fromJson(item)).toList();
      
      // 如果需要按市场过滤前端数据
      if (_selectedMarket != '全部' && _selectedMarket.isNotEmpty) {
        _scanResults = _scanResults
            .where((stock) => stock.market.contains(_selectedMarket))
            .toList();
      }
      
      _error = '';
      
      // 清除之前的AI筛选结果
      _aiFilterResult = null;
      
      // 使用微任务确保状态更新不在构建过程中执行
      Future.microtask(() {
        _isLoading = false;
        notifyListeners();
      });
      
      // 异步连接WebSocket（不阻塞主流程）
      _connectWebSocketAsync(strategyParam);
    } catch (e) {
      _error = '获取指标扫描结果失败: $e';
      debugPrint(_error);
      
      // 使用微任务确保状态更新不在构建过程中执行
      Future.microtask(() {
        _isLoading = false;
        notifyListeners();
      });
    }
  }
  
  // 选择市场并刷新结果
  Future<void> selectMarket(String market) async {
    // 如果市场选择没有变化，直接返回
    if (_selectedMarket == market) return;
    
    // 记录当前选择的市场
    _selectedMarket = market;
    
    // 如果缓存中没有数据，需要从后端获取
    if (_allStocksCache.isEmpty) {
      _isLoading = true;
      notifyListeners();
      
      try {
        final results = await _apiService.getBuySignalStocks(strategy: _selectedStrategy);
        _allStocksCache = results.map((item) => StockIndicator.fromJson(item)).toList();
      } catch (e) {
        _error = '获取股票数据失败: $e';
        debugPrint(_error);
        _isLoading = false;
        notifyListeners();
        return;
      }
    } else {
      // 如果只是切换板块而非首次加载，不显示加载状态，直接在前端筛选
      debugPrint('使用缓存数据在前端筛选市场: $market');
    }
    
    // 根据选择的市场筛选股票
    if (market == '全部') {
      _scanResults = List.from(_allStocksCache);
    } else if (market == '主板') {
      // 主板包括上证主板、深证主板，以及直接标记为"主板"的股票
      _scanResults = _allStocksCache
          .where((stock) => 
              stock.market == '上证主板' || 
              stock.market == '深证主板' ||
              stock.market == '主板' ||
              stock.market.contains('主板'))
          .toList();
      debugPrint('主板筛选: 从${_allStocksCache.length}只股票中筛选出${_scanResults.length}只');
      // 打印前5只股票的市场信息用于调试
      if (_allStocksCache.isNotEmpty) {
        debugPrint('缓存中前5只股票的市场信息:');
        for (var i = 0; i < _allStocksCache.length && i < 5; i++) {
          debugPrint('  ${_allStocksCache[i].name}(${_allStocksCache[i].code}): ${_allStocksCache[i].market}');
        }
      }
    } else if (market == 'ETF') {
      // ETF筛选逻辑：包含ETF、etf，以及通过股票代码推断的ETF
      _scanResults = _allStocksCache
          .where((stock) => 
              stock.market == 'ETF' || 
              stock.market == 'etf' ||
              stock.market.contains('ETF') ||
              stock.market.contains('etf') ||
              // 通过股票代码推断ETF（以51、15开头的代码）
              (stock.code.startsWith('51') || stock.code.startsWith('15')))
          .toList();
      debugPrint('ETF筛选: 从${_allStocksCache.length}只股票中筛选出${_scanResults.length}只');
    } else {
      // 在前端筛选特定市场
      _scanResults = _allStocksCache
          .where((stock) => stock.market.contains(market))
          .toList();
    }
    
    debugPrint('筛选后结果数: ${_scanResults.length}/${_allStocksCache.length}');
    
    // 清除之前的AI筛选结果
    _aiFilterResult = null;
    
    // 如果之前是加载状态，更新UI
    if (_isLoading) {
      _isLoading = false;
    }
    
    notifyListeners();
  }
  
  // 选择策略并更新扫描结果
  Future<void> selectStrategy(String strategy) async {
    if (_selectedStrategy == strategy) return;
    
    debugPrint('切换策略: 从 $_selectedStrategy 到 $strategy');
    
    // 使用微任务确保状态更新不在构建过程中执行
    Future.microtask(() async {
      _selectedStrategy = strategy;
      _isLoading = true;
      notifyListeners();
      
      try {
        // 切换策略需要重新从后端获取数据
        final results = await _apiService.getBuySignalStocks(strategy: strategy);
        _allStocksCache = results.map((item) => StockIndicator.fromJson(item)).toList();
        
        // 应用当前市场筛选
        if (_selectedMarket == '全部' || _selectedMarket.isEmpty) {
          _scanResults = List.from(_allStocksCache);
        } else if (_selectedMarket == '主板') {
          // 主板包括上证主板、深证主板，以及直接标记为"主板"的股票
          _scanResults = _allStocksCache
              .where((stock) => 
                  stock.market == '上证主板' || 
                  stock.market == '深证主板' ||
                  stock.market == '主板' ||
                  stock.market.contains('主板'))
              .toList();
        } else if (_selectedMarket == 'ETF') {
          // ETF筛选逻辑：包含ETF、etf，以及通过股票代码推断的ETF
          _scanResults = _allStocksCache
              .where((stock) => 
                  stock.market == 'ETF' || 
                  stock.market == 'etf' ||
                  stock.market.contains('ETF') ||
                  stock.market.contains('etf') ||
                  // 通过股票代码推断ETF（以51、15开头的代码）
                  (stock.code.startsWith('51') || stock.code.startsWith('15')))
              .toList();
          debugPrint('ETF筛选: 从${_allStocksCache.length}只股票中筛选出${_scanResults.length}只');
        } else {
          _scanResults = _allStocksCache
              .where((stock) => stock.market.contains(_selectedMarket))
              .toList();
        }
      } catch (e) {
        _error = '获取策略数据失败: $e';
        debugPrint(_error);
      } finally {
        _isLoading = false;
        // 清除之前的AI筛选结果
        _aiFilterResult = null;
        notifyListeners();
      }
    });
  }
  
  // 获取股票详情信息
  Future<StockDetailedInfo?> getStockInfo(String symbol) async {
    // 检查缓存
    if (_stockDetailsCache.containsKey(symbol)) {
      debugPrint('从缓存获取股票详情: $symbol');
      return _stockDetailsCache[symbol];
    }
    
    // 使用微任务确保状态更新不在构建过程中执行
    Future.microtask(() {
      _isLoading = true;
      notifyListeners();
    });
    
    try {
      debugPrint('开始请求股票详情API: $symbol');
      final data = await _apiService.getStockInfo(symbol);
      if (data.isEmpty) {
        _error = '获取股票信息失败: 返回数据为空';
        debugPrint(_error);
        // 使用微任务确保状态更新不在构建过程中执行
        Future.microtask(() {
          _isLoading = false;
          notifyListeners();
        });
        return null;
      }
      
      // 调试输出数据结构
      debugPrint('获取到数据键: ${data.keys.join(', ')}');
      
      final stockInfo = StockDetailedInfo.fromJson(data);
      // 添加到缓存
      _stockDetailsCache[symbol] = stockInfo;
      _error = '';
      
      // 调试输出转换后的数据
      debugPrint('数据转换成功，基本信息键: ${stockInfo.basicInfo.keys.join(', ')}');
      
      // 使用微任务确保状态更新不在构建过程中执行
      Future.microtask(() {
        _isLoading = false;
        notifyListeners();
      });
      
      return stockInfo;
    } catch (e) {
      _error = '获取股票信息失败: $e';
      debugPrint(_error);
      
      // 使用微任务确保状态更新不在构建过程中执行
      Future.microtask(() {
        _isLoading = false;
        notifyListeners();
      });
      
      return null;
    }
  }
  
  // 启动AI筛选
  Future<AIFilterResult> startAIFiltering(String filterCriteria) async {
    try {
      // 检查筛选条件是否为空
      if (filterCriteria.trim().isEmpty) {
        throw Exception('筛选条件不能为空');
      }
      
      // 检查扫描结果是否为空
      if (_scanResults.isEmpty) {
        throw Exception('没有可用的股票数据进行筛选');
      }
      
      // 检查是否选择了具体市场（非全部）
      if (_selectedMarket == '全部' || _selectedMarket.isEmpty) {
        throw Exception('请先选择具体市场（如创业板、科创板等）再进行AI筛选');
      }
      
      // 记录筛选开始信息
      debugPrint('开始AI筛选，条件: ${filterCriteria.substring(0, min(filterCriteria.length, 100))}...，股票数量: ${_scanResults.length}');
      
      // 标记为正在筛选
      _isAIFiltering = true;
      _safeNotifyListeners();
      
      // 创建初始进度通知
      final initialProgress = AIFilterResult.inProgress(
        originalFilter: filterCriteria,
        currentStocks: [],
        processedCount: 0,
        totalCount: _scanResults.length,
        taskId: 'preparing_${DateTime.now().millisecondsSinceEpoch}',
      );
      _aiFilterResult = initialProgress;
      _safeNotifyListeners();
      
      // 开始AI筛选
      final result = await _aiFilterService.startAIFiltering(
        stocks: _scanResults,
        filterCriteria: filterCriteria,
      );
      
      // 记录筛选完成信息
      debugPrint('AI筛选完成，共筛选出 ${result.stocks.length} 只股票，总处理: ${result.processedCount}/${result.totalCount}');
      
      // 更新筛选结果
      _aiFilterResult = result;
      _isAIFiltering = false;
      _safeNotifyListeners();
      
      return result;
    } catch (e) {
      // 记录详细错误信息
      final errorDetails = {
        'error_message': e.toString(),
        'filter_criteria': filterCriteria,
        'scan_results_count': _scanResults.length,
        'timestamp': DateTime.now().toIso8601String(),
      };
      _error = 'AI筛选失败: $e';
      debugPrint('AI筛选失败详情: ${jsonEncode(errorDetails)}');
      
      _isAIFiltering = false;
      
      // 检查是否是特定类型的错误
      String errorMessage = e.toString();
      if (errorMessage.contains('API认证失败') || errorMessage.contains('API Key')) {
        errorMessage = 'API认证失败，请检查设置中的API密钥';
      } else if (errorMessage.contains('请求过于频繁') || errorMessage.contains('429')) {
        errorMessage = 'API请求过于频繁，请稍后再试';
      } else if (errorMessage.contains('服务器错误') || errorMessage.contains('500')) {
        errorMessage = 'AI服务器暂时不可用，请稍后再试';
      }
      
      // 返回错误结果
      final errorResult = AIFilterResult.error(
        originalFilter: filterCriteria,
        errorMessage: errorMessage,
        totalCount: _scanResults.length,
        taskId: 'error_${DateTime.now().millisecondsSinceEpoch}',
      );
      
      _aiFilterResult = errorResult;
      _safeNotifyListeners();
      
      return errorResult;
    }
  }
  
  // 清除AI筛选结果
  void clearAIFilterResult() {
    _aiFilterResult = null;
    _safeNotifyListeners();
  }
  
  // 初始化数据
  Future<void> initialize() async {
    await scanStocksByIndicator();
  }
  
  // 初始化策略数据（公共方法）
  Future<void> initializeStrategies() async {
    await _loadStrategies();
  }
  
  // 清除缓存
  void clearCache() {
    _stockDetailsCache.clear();
  }
  
  // 异步获取当前选中策略的名称
  Future<String> getSelectedStrategyName() async {
    try {
      return await StrategyConfigService.getStrategyName(_selectedStrategy);
    } catch (e) {
      debugPrint('获取选中策略名称出错: $e');
      return selectedStrategyName;
    }
  }
} 