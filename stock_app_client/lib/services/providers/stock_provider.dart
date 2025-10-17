import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/stock.dart';
import '../database_service.dart';
import '../stock_service.dart';

class StockProvider with ChangeNotifier {
  final StockService? _stockService;
  final DatabaseService _databaseService;
  
  List<Stock> _stocks = [];
  bool _isLoading = false;
  bool _isInitialized = false;
  final Map<String, double> _stockATRValues = {}; // 缓存股票ATR值
  
  // 缓存配置
  static const String _lastUpdateKey = 'stock_list_last_update';
  // 设置缓存有效期为180天（半年）
  static const int _cacheValidDays = 180;

  // 公共构造函数 - 用于依赖注入
  StockProvider(this._databaseService, this._stockService) {
    // 在构造时异步初始化股票数据
    _initStockData();
  }

  // 私有构造函数
  StockProvider._() : _stockService = null, _databaseService = DatabaseService() {
    // 在构造时异步初始化股票数据
    _initStockData();
  }

  List<Stock> get stocks => _stocks;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;

  // 初始化股票数据
  Future<void> _initStockData() async {
    if (_isInitialized) {
      return;
    }
    
    try {
      print('StockProvider: 开始初始化股票数据...');
      _isLoading = true;
      notifyListeners();
      
      // 使用传入的StockService或创建新的
      StockService stockService;
      if (_stockService != null) {
        stockService = _stockService!;
      } else {
        // 为私有构造函数创建StockService
      final database = await _databaseService.database;
        stockService = StockService(database);
      }
      
      // 确保股票数据存在
      await stockService.ensureStockDataExists();
      
      // 加载股票数据到内存，不强制刷新
      await loadStocks(forceRefresh: false);
      
      _isInitialized = true;
      print('StockProvider: 股票数据初始化完成，共加载${_stocks.length}只股票');
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('StockProvider: 初始化股票数据失败: $e');
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // 检查是否应该刷新股票数据
  Future<bool> _shouldRefreshStockData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUpdate = prefs.getInt(_lastUpdateKey);
      
      if (lastUpdate == null) {
        return true; // 没有缓存，需要刷新
      }
      
      final lastUpdateTime = DateTime.fromMillisecondsSinceEpoch(lastUpdate);
      final now = DateTime.now();
      final difference = now.difference(lastUpdateTime).inDays;
      
      print('StockProvider: 上次更新时间: ${lastUpdateTime.toLocal()}, 距今: $difference 天');
      
      // 如果超过设定的缓存有效期，需要刷新
      return difference >= _cacheValidDays;
    } catch (e) {
      print('StockProvider: 检查缓存时间出错: $e');
      return true; // 出错时默认刷新
    }
  }
  
  // 更新最后刷新时间
  Future<void> _updateLastRefreshTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastUpdateKey, DateTime.now().millisecondsSinceEpoch);
      print('StockProvider: 已更新股票数据缓存时间戳');
    } catch (e) {
      print('StockProvider: 更新缓存时间戳失败: $e');
    }
  }

  Future<void> loadStocks({bool forceRefresh = true}) async {
    // 如果不是强制刷新且已有数据，直接返回，不显示加载状态
    if (!forceRefresh && _stocks.isNotEmpty) {
      print('StockProvider: 已有股票数据(${_stocks.length}只)，无需重新加载');
      return;
    }
    
    // 只有在需要刷新或没有数据时才显示加载状态
    _isLoading = true;
    notifyListeners();
    
    try {
      if (forceRefresh) {
        // 强制刷新时，从网络获取最新数据
        print('StockProvider: 强制刷新股票数据...');
        await _stockService?.refreshStocks(forceRefresh: true);
      }
      
      // 从数据库加载股票数据
      final records = await _databaseService.getStocks();
      _stocks = records.map((record) => Stock.fromMap(record)).toList();
      
      print('StockProvider: 从数据库加载了${_stocks.length}只股票');
      
      // 如果数据量太少，可能是API限制或获取失败，尝试使用默认数据
      if (_stocks.isEmpty || (_stocks.length < 1000 && forceRefresh)) {
        print('StockProvider: 警告 - 股票数据太少(${_stocks.length}只)，可能需要检查API配置');
      }
    } catch (e) {
      print('StockProvider: 加载股票失败: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 静默初始化股票数据（不触发UI加载状态）
  Future<void> _silentInitStockData() async {
    if (_isInitialized) return;
    
    try {
      print('StockProvider: 开始静默初始化股票数据...');
      
      // 使用传入的StockService或创建新的
      StockService stockService;
      if (_stockService != null) {
        stockService = _stockService!;
      } else {
        // 为私有构造函数创建StockService
        final database = await _databaseService.database;
        stockService = StockService(database);
      }
      
      // 确保股票数据存在（不强制刷新，静默处理）
      await stockService.ensureStockDataExists();
      
      // 静默加载股票数据到内存
      await _silentLoadStocks();
      
      _isInitialized = true;
      print('StockProvider: 静默初始化完成，共加载${_stocks.length}只股票');
      
      // 静默初始化不通知UI更新
      // notifyListeners(); // 注释掉，避免触发UI重建
    } catch (e) {
      print('StockProvider: 静默初始化股票数据失败: $e');
    }
  }

  // 静默加载股票数据（不触发UI加载状态）
  Future<void> _silentLoadStocks() async {
    try {
      print('StockProvider: 开始静默加载股票数据...');
      
      // 不设置 _isLoading = true，避免触发UI加载状态
      final records = await _databaseService.getStocks();
      _stocks = records.map((record) => Stock.fromMap(record)).toList();
      
      print('StockProvider: 静默加载完成，共${_stocks.length}只股票');
      
      // 如果数据量太少，不进行任何操作，避免触发加载状态
      if (_stocks.isEmpty) {
        print('StockProvider: 警告 - 静默加载时未获取到股票数据');
      }
      
      // 静默加载时不通知UI更新，避免触发重建
      // notifyListeners(); // 注释掉这行
    } catch (e) {
      print('StockProvider: 静默加载股票失败: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getStockSuggestions(String query) async {
    // 确保已初始化（但不触发UI加载状态）
    if (!_isInitialized) {
      // 静默初始化，不影响UI
      await _silentInitStockData();
    }
    
    if (query.isEmpty) {
      print('StockProvider: 搜索查询为空，返回空列表');
      return [];
    }
    
    try {
      print('StockProvider: 正在查询股票: "$query", 当前股票列表大小: ${_stocks.length}');
      
      // 如果没有数据，尝试静默加载，但不显示加载状态
      if (_stocks.isEmpty) {
        print('StockProvider: 股票数据为空，尝试静默加载...');
        await _silentLoadStocks();
        print('StockProvider: 静默加载后股票数据量: ${_stocks.length}只');
      }
      
      // 转换为小写以实现不区分大小写的搜索
      final lowercaseQuery = query.toLowerCase();
      
      // 直接从内存中的已缓存数据中搜索，无需发起网络请求
      final exactCodeMatches = <Stock>[];
      final codeMatches = <Stock>[];
      final nameMatches = <Stock>[];
      final combinedMatches = <Stock>[];
      
      // 第一轮：尝试精确匹配股票代码或代码前缀匹配
      for (var stock in _stocks) {
        // 完全匹配代码
        if (stock.code == query) {
          exactCodeMatches.add(stock);
          continue;
        }
        
        // 代码前缀匹配（股票代码以查询字符串开头）
        if (stock.code.toLowerCase().startsWith(lowercaseQuery)) {
          codeMatches.add(stock);
          continue;
        }
        
        // 股票名称包含查询字符串
        if (stock.name.toLowerCase().contains(lowercaseQuery)) {
          nameMatches.add(stock);
          continue;
        }
        
        // 结合名称和代码的模糊匹配
        if (stock.code.toLowerCase().contains(lowercaseQuery) || 
            _containsChineseChars(stock.name, query)) {
          combinedMatches.add(stock);
        }
      }
      
      // 组合搜索结果，按优先级排序
      final allMatches = [
        ...exactCodeMatches,
        ...codeMatches,
        ...nameMatches,
        ...combinedMatches,
      ];
      
      final suggestions = allMatches
          .take(15) // 增加返回数量以提供更多匹配选择
          .map((stock) => {
                'code': stock.code,
                'name': stock.name,
                'market': stock.market,
                'industry': stock.industry,
              })
          .toList();
      
      print('StockProvider: 搜索结果数量: ${suggestions.length}');
      if (suggestions.isNotEmpty) {
        print('StockProvider: 前3个结果: ${suggestions.take(3)}');
      }
      
      return suggestions;
    } catch (e) {
      print('StockProvider: 获取股票建议失败: $e');
      return [];
    }
  }
  
  // 辅助方法：检查股票名称是否包含中文查询字符
  bool _containsChineseChars(String stockName, String query) {
    // 对于中文搜索，允许部分匹配
    if (query.contains(RegExp(r'[\u4e00-\u9fa5]'))) {
      for (int i = 0; i < query.length; i++) {
        if (stockName.contains(query[i])) {
          return true;
        }
      }
    }
    return false;
  }

  // 获取股票ATR值
  Future<double?> getStockATR(String stockCode) async {
    // 如果缓存中有，则直接返回
    if (_stockATRValues.containsKey(stockCode)) {
      return _stockATRValues[stockCode];
    }
    
    try {
      // 从API获取股票历史数据计算ATR
      final atrValue = await _stockService?.calculateATR(stockCode);
      
      if (atrValue != null) {
        // 缓存ATR值
        _stockATRValues[stockCode] = atrValue;
      }
      
      return atrValue;
    } catch (e) {
      print('StockProvider: 获取股票ATR值失败: $e');
      return null;
    }
  }

  Future<void> updateStockPrice(String code, double newPrice) async {
    try {
      // 更新股票价格
      for (var i = 0; i < _stocks.length; i++) {
        if (_stocks[i].code == code) {
          _stocks[i] = _stocks[i].copyWith(currentPrice: newPrice);
        }
      }
      notifyListeners();
    } catch (e) {
      print('StockProvider: 更新股票价格失败: $e');
    }
  }
  
  // 根据股票代码获取股票名称
  String? getStockNameByCode(String code) {
    final stock = _stocks.firstWhere(
      (s) => s.code == code,
      orElse: () => Stock(code: '', name: ''),
    );
    
    return stock.name.isEmpty ? null : stock.name;
  }
  
  // 根据股票代码获取股票基本信息
  Stock? getStockByCode(String code) {
    try {
      return _stocks.firstWhere((s) => s.code == code);
    } catch (e) {
      return null;
    }
  }
  
  // 刷新股票数据库
  Future<bool> refreshStockDatabase() async {
    try {
      print('StockProvider: 开始刷新股票数据库...');
      _isLoading = true;
      notifyListeners();
      
      // 重置初始化标志
      _isInitialized = false;
      
      // 重新初始化股票数据
      await _stockService?.refreshStocks(forceRefresh: true);
      await loadStocks(forceRefresh: true);
      
      // 更新缓存时间戳
      await _updateLastRefreshTime();
      
      _isInitialized = true;
      print('StockProvider: 股票数据库刷新完成，共加载${_stocks.length}只股票');
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      print('StockProvider: 刷新股票数据库失败: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  // 获取股票历史数据
  Future<List<Map<String, dynamic>>> getStockHistoryData(String stockCode) async {
    try {
      // 从StockService获取历史数据
      final database = await _databaseService.database;
      final stockService = StockService(database);
      final historyData = await stockService.getStockHistoryData(stockCode);
      
      print('StockProvider: 获取股票$stockCode的历史数据，共${historyData.length}条');
      return historyData;
    } catch (e) {
      print('StockProvider: 获取股票历史数据失败: $e');
      return [];
    }
  }
  
  // 获取股票当前价格
  Future<double?> getCurrentPrice(String stockCode) async {
    try {
      // 通过StockService获取股票最新价格
      final database = await _databaseService.database;
      final stockService = StockService(database);
      final price = await stockService.getCurrentPrice(stockCode);
      
      if (price != null) {
        print('StockProvider: 获取股票$stockCode的当前价格: $price');
        return price;
      } else {
        print('StockProvider: 无法获取股票$stockCode的当前价格');
        return null;
      }
    } catch (e) {
      print('StockProvider: 获取股票当前价格失败: $e');
      return null;
    }
  }
} 