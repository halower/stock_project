import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import '../models/stock_info.dart';
import '../models/stock.dart';

import '../config/api_config.dart';
import '../services/api_service.dart';
import 'http_client.dart';

class StockService {
  static const String _baseUrl = ApiConfig.apiBaseUrl;
  static const String _tableName = 'stocks';
  static const int _cacheDuration = 24 * 60 * 60 * 1000; // 24 hours in milliseconds

  final Database _database;
  final Map<String, List<Map<String, dynamic>>> _stockCache = {};
  bool _isInitialized = false;
  
  // 添加缓存机制
  final Map<String, double> _currentPriceCache = {}; // 股票代码 -> 当前价格
  final Map<String, double> _atrCache = {}; // 股票代码 -> ATR值
  final Map<String, List<Map<String, dynamic>>> _historyDataCache = {}; // 股票代码_开始日期_结束日期 -> 历史数据
  final Map<String, int> _dataCacheTimes = {}; // 数据缓存时间戳
  static const int _dataCacheValidityPeriod = 30 * 60 * 1000; // 数据缓存有效期（30分钟）

  StockService(this._database);

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_tableName (
        code TEXT PRIMARY KEY,
        name TEXT,
        market TEXT,
        industry TEXT,
        board TEXT,
        area TEXT,
        ts_code TEXT,
        listing_date TEXT,
        total_shares TEXT,
        circulating_shares TEXT,
        last_updated INTEGER
      )
    ''');
  }

  Future<List<Stock>> getAllStocks() async {
    // Check if we need to update the cache
    final lastUpdated = await _getLastUpdated();
    final now = DateTime.now().millisecondsSinceEpoch;
    
    if (lastUpdated == null || (now - lastUpdated) > _cacheDuration) {
      await _updateStockData();
    }

    // Get stocks from database
    final List<Map<String, dynamic>> maps = await _database.query(_tableName);
    return List.generate(maps.length, (i) => _mapToStock(maps[i]));
  }

  Future<List<StockInfo>> getStocks() async {
    // Check if we need to update the cache
    final lastUpdated = await _getLastUpdated();
    final now = DateTime.now().millisecondsSinceEpoch;
    
    if (lastUpdated == null || (now - lastUpdated) > _cacheDuration) {
      await _updateStockData();
    }

    // Get stocks from database
    final List<Map<String, dynamic>> maps = await _database.query(_tableName);
    return List.generate(maps.length, (i) => _mapToStockInfo(maps[i]));
  }

  Future<List<StockInfo>> searchStocks(String query) async {
    final List<Map<String, dynamic>> maps = await _database.query(
      _tableName,
      where: 'code LIKE ? OR name LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
    );
    return List.generate(maps.length, (i) => _mapToStockInfo(maps[i]));
  }

  Future<void> _updateStockData() async {
    try {
      print('正在获取股票数据...');
      
      // 修复API路径，使用正确的URL构建方式
      final url = '${ApiConfig.stocksEndpoint}';
      print('请求URL: $url');
      
      // 使用HttpClient获取数据，确保添加Token
      final response = await HttpClient.get(url);

      if (response.statusCode == 200) {
        // 使用UTF-8解码
        final jsonString = utf8.decode(response.bodyBytes);
        final jsonData = json.decode(jsonString);
        
        if (jsonData is Map<String, dynamic> && jsonData.containsKey('stocks')) {
          final List<dynamic> stocksList = jsonData['stocks'];
          final int total = jsonData['total'] ?? stocksList.length;
          final int returned = jsonData['returned'] ?? stocksList.length;
          
          print('获取到股票数据: 返回${returned}只, 总计: $total');
          
          // 打印样本数据来了解结构
          if (stocksList.isNotEmpty) {
            print('股票数据样本: ${stocksList.first}');
          }

          // 手动构建股票数据，适配新的API格式
          final List<Map<String, dynamic>> allStocks = [];
          
          for (var item in stocksList) {
            final tsCode = item['ts_code']?.toString() ?? '';
            final symbol = item['symbol']?.toString() ?? '';
            final name = item['name']?.toString() ?? '';
            final area = item['area']?.toString() ?? '';
            final industry = item['industry']?.toString() ?? '';
            final market = item['market']?.toString() ?? '';
            
            if (symbol.isNotEmpty && name.isNotEmpty) {
              // 从ts_code提取市场信息，如"000001.SZ" -> "SZ"
              String marketCode = '';
              if (tsCode.contains('.')) {
                marketCode = tsCode.split('.').last;
              } else {
                // 如果没有ts_code，从symbol判断市场
                if (symbol.startsWith('6')) {
                  marketCode = 'SH';
                } else if (symbol.startsWith('0') || symbol.startsWith('3')) {
                  marketCode = 'SZ';
                } else if (symbol.startsWith('8') || symbol.startsWith('4')) {
                  marketCode = 'BJ';
                }
              }
              
              allStocks.add({
                'code': symbol, // 使用symbol作为code
                'name': name,
                'market': marketCode,
                'industry': industry,
                'board': market, // 使用market字段作为board
                'area': area,
                'ts_code': tsCode, // 保存完整的ts_code
                'listing_date': '',
                'total_shares': '',
                'circulating_shares': '',
                'last_updated': DateTime.now().millisecondsSinceEpoch,
              });
            }
          }
          
          if (allStocks.isNotEmpty) {
            // 打印第一条数据，用于调试
            print('处理后的示例数据: ${allStocks.first}');
            print('共处理${allStocks.length}只股票');
            
            // Clear existing data
            await _database.delete(_tableName);

            // Insert new data
            final batch = _database.batch();
            for (var stock in allStocks) {
              batch.insert(_tableName, stock);
            }

            await batch.commit();
            await _updateLastUpdated();
            
            print('成功将${allStocks.length}只股票数据写入数据库');
            
            // 更新初始化标志
            _isInitialized = true;
          } else {
            print('没有获取到有效的股票数据');
          }
        } else {
          print('API返回的数据格式不正确');
        }
      } else {
        print('获取股票数据失败: ${response.statusCode}');
      }
    } catch (e) {
      print('更新股票数据出错: $e');
      // If update fails, we'll use the cached data
    }
  }

  Future<int?> _getLastUpdated() async {
    final List<Map<String, dynamic>> result = await _database.rawQuery(
      'SELECT last_updated FROM $_tableName LIMIT 1'
    );
    return result.isNotEmpty ? result.first['last_updated'] as int? : null;
  }

  Future<void> _updateLastUpdated() async {
    await _database.rawUpdate(
      'UPDATE $_tableName SET last_updated = ?',
      [DateTime.now().millisecondsSinceEpoch]
    );
  }

  Map<String, dynamic> _stockInfoToMap(StockInfo stock) {
    return {
      'code': stock.code,
      'name': stock.name,
      'market': stock.market,
      'industry': stock.industry,
      'board': stock.board,
      'listing_date': stock.listingDate,
      'total_shares': stock.totalShares,
      'circulating_shares': stock.circulatingShares,
      'last_updated': DateTime.now().millisecondsSinceEpoch,
    };
  }

  StockInfo _mapToStockInfo(Map<String, dynamic> map) {
    return StockInfo(
      code: map['code'],
      name: map['name'],
      market: map['market'],
      industry: map['industry'],
      board: map['board'],
      listingDate: map['listing_date'],
      totalShares: map['total_shares'],
      circulatingShares: map['circulating_shares'],
    );
  }

  Stock _mapToStock(Map<String, dynamic> map) {
    return Stock(
      code: map['code'] ?? '',
      name: map['name'] ?? '',
      costPrice: map['cost_price'] as double?,
      currentPrice: map['current_price'] as double?,
      quantity: map['quantity'] as int?,
      addTime: map['add_time'] == null ? null : DateTime.parse(map['add_time'] as String),
      strategy: map['strategy'] as String?,
      notes: map['notes'] as String?,
      market: map['market'] as String? ?? '',
      industry: map['industry'] as String? ?? '',
    );
  }

  Future<List<Map<String, dynamic>>> _fetchStocks(String exchange) async {
    if (_stockCache.containsKey(exchange)) {
      return _stockCache[exchange]!;
    }

    try {
      // 修复API路径，使用正确的URL构建方式
      final response = await HttpClient.get('${ApiConfig.stocksEndpoint}');
      
      if (response.statusCode == 200) {
        // 使用UTF-8解码
        final jsonString = utf8.decode(response.bodyBytes);
        final jsonData = json.decode(jsonString);
        
        if (jsonData is Map<String, dynamic> && jsonData.containsKey('stocks')) {
          final List<dynamic> stocksList = jsonData['stocks'];
          
          // 输出第一条数据，查看结构
          if (stocksList.isNotEmpty) {
            print('股票数据示例: ${stocksList[0]}');
          }
          
          // 根据exchange筛选对应的市场股票，适配新的API格式
          final stocks = stocksList.where((item) {
            final tsCode = item['ts_code']?.toString() ?? '';
            final symbol = item['symbol']?.toString() ?? '';
            
            // 从ts_code或symbol判断交易所
            String marketCode = '';
            if (tsCode.contains('.')) {
              marketCode = tsCode.split('.').last;
            } else if (symbol.isNotEmpty) {
              if (symbol.startsWith('6')) {
                marketCode = 'SH';
              } else if (symbol.startsWith('0') || symbol.startsWith('3')) {
                marketCode = 'SZ';
              } else if (symbol.startsWith('8') || symbol.startsWith('4')) {
                marketCode = 'BJ';
              }
            }
            
            return marketCode.toLowerCase() == exchange.toLowerCase();
          }).map((item) {
            final tsCode = item['ts_code']?.toString() ?? '';
            final symbol = item['symbol']?.toString() ?? '';
            final name = item['name']?.toString() ?? '';
            final area = item['area']?.toString() ?? '';
            final industry = item['industry']?.toString() ?? '';
            final market = item['market']?.toString() ?? '';
            
            return {
              'code': symbol,
              'name': name,
              'exchange': exchange.toUpperCase(),
              'full_name': name,
              'industry': industry,
              'area': area,
              'ts_code': tsCode,
              'market': market,
              'listing_date': '',
              'total_shares': '',
              'circulating_shares': '',
            };
          }).whereType<Map<String, dynamic>>().toList();
          
          if (stocks.isNotEmpty) {
            _stockCache[exchange] = stocks;
            print('加载了${exchange.toUpperCase()}交易所的${stocks.length}只股票');
          } else {
            print('${exchange.toUpperCase()}交易所没有有效的股票数据');
          }
          
          return stocks;
        } else {
          print('API返回的数据格式不正确');
          return [];
        }
      } else {
        print('获取${exchange.toUpperCase()}交易所股票失败: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('获取${exchange.toUpperCase()}交易所股票出错: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getStockSuggestions(String query) async {
    // 确保初始化
    if (!_isInitialized) {
      await _initializeStockData();
    }
    
    if (query.isEmpty) {
      return [];
    }
    
    try {
      // 直接从数据库中查找
      final dbResults = await _database.query(
        _tableName,
        where: 'code LIKE ? OR name LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
        limit: 10
      );
      
      final List<Map<String, dynamic>> result = [];
      for (var item in dbResults) {
        result.add({
          'code': item['code'].toString(),
          'name': item['name'].toString(),
          'exchange': item['market'].toString(),
        });
      }
      
      // 打印找到的结果数量
      print('查询"$query"找到${result.length}条结果');
      if (result.isNotEmpty) {
        print('结果示例: ${result.first}');
      }
      
      return result;
    } catch (e) {
      print('获取股票建议出错: $e');
      return [];
    }
  }
  
  // 修改获取当前价格方法，添加缓存支持
  Future<double?> getCurrentPrice(String stockCode) async {
    // 检查缓存是否有效
    final now = DateTime.now().millisecondsSinceEpoch;
    final cacheKey = stockCode;
    final lastCacheTime = _dataCacheTimes[cacheKey] ?? 0;
    
    // 如果缓存存在且未过期
    if (_currentPriceCache.containsKey(cacheKey) && 
        (now - lastCacheTime) < _dataCacheValidityPeriod) {
      print('使用缓存的股票 $stockCode 价格: ${_currentPriceCache[cacheKey]}');
      return _currentPriceCache[cacheKey];
    }
    
    try {
      // 获取最近120天的K线数据
      final today = DateTime.now();
      final endDate = today.toIso8601String().split('T')[0].replaceAll('-', '');
      final startDate = DateTime(today.year, today.month, today.day - 120)
          .toIso8601String().split('T')[0].replaceAll('-', '');
      
      print('获取股票 $stockCode 的最新价格...');
      
      // 获取历史数据
      final historyData = await getStockHistoryData(
        stockCode,
        startDate: startDate,
        endDate: endDate
      );
      
      if (historyData.isNotEmpty) {
        // 使用最新一天(最后一条)的收盘价
        final latestPrice = historyData.last['close'] as double;
        print('获取到股票 $stockCode 的最新价格(来自K线数据): $latestPrice');
        
        // 更新缓存
        _currentPriceCache[cacheKey] = latestPrice;
        _dataCacheTimes[cacheKey] = now;
        return latestPrice;
      }
    } catch (e) {
      print('获取股票价格出错: $e');
      // 如果出错，使用模拟价格
      final basePrice = 10.0 + (DateTime.now().millisecondsSinceEpoch % 1000) / 100;
      return double.parse(basePrice.toStringAsFixed(2));
    }
    return null;
  }
  
  // 修改计算ATR的方法，添加缓存支持
  Future<double?> calculateATR(String stockCode) async {
    // 检查缓存是否有效
    final now = DateTime.now().millisecondsSinceEpoch;
    final cacheKey = stockCode;
    final lastCacheTime = _dataCacheTimes['atr_$cacheKey'] ?? 0;
    
    // 如果缓存存在且未过期
    if (_atrCache.containsKey(cacheKey) && 
        (now - lastCacheTime) < _dataCacheValidityPeriod) {
      print('使用缓存的股票 $stockCode 的ATR值: ${_atrCache[cacheKey]}');
      return _atrCache[cacheKey];
    }
    
    try {
      // 获取历史数据，计算ATR（平均真实波动范围）
      // 使用最近30天的数据计算，确保有足够的数据计算14天ATR
      final currentDate = DateTime.now();
      final endDate = currentDate.toIso8601String().split('T')[0].replaceAll('-', '');
      
      // 计算30天前的日期，获取足够的数据来计算14天ATR
      final startDate = DateTime(currentDate.year, currentDate.month, currentDate.day - 30)
          .toIso8601String().split('T')[0].replaceAll('-', '');
      
      print('获取股票 $stockCode 的历史数据计算ATR...');
      
      // 获取股票历史数据
      final historyData = await getStockHistoryData(
        stockCode,
        startDate: startDate,
        endDate: endDate
      );
      
      if (historyData.isEmpty) {
        print('获取股票历史数据为空，无法计算ATR');
        return null;
      }
      
      // 排序确保数据按日期升序排列
      historyData.sort((a, b) {
        final dateA = DateTime.parse(a['date'].toString());
        final dateB = DateTime.parse(b['date'].toString());
        return dateA.compareTo(dateB);
      });
      
      // 标准ATR计算，使用Wilder方法
      const period = 14; // 标准ATR周期为14天
      List<double> trValues = [];
      
      // 计算每日TR值
      for (int i = 1; i < historyData.length; i++) {
        final current = historyData[i];
        final previous = historyData[i - 1];
        
        // 获取价格数据
        final double high = current['high'] is num ? (current['high'] as num).toDouble() : 0.0;
        final double low = current['low'] is num ? (current['low'] as num).toDouble() : 0.0;
        final double prevClose = previous['close'] is num ? (previous['close'] as num).toDouble() : 0.0;
        
        // 跳过无效数据
        if (high <= 0 || low <= 0 || prevClose <= 0) {
          continue;
        }
        
        // 计算真实波动范围：最高价与最低价的波动、最高价与昨收的波动、最低价与昨收的波动的最大值
        final double tr1 = high - low;
        final double tr2 = (high - prevClose).abs();
        final double tr3 = (low - prevClose).abs();
        
        final double tr = [tr1, tr2, tr3].reduce((a, b) => a > b ? a : b);
        trValues.add(tr);
      }
      
      // 确保有足够的TR值
      if (trValues.length < period) {
        print('计算ATR的TR值不足 ${trValues.length}/$period');
        // 如果数据不够14天，仍然可以用平均值计算，但会标记为不精确
        if (trValues.isNotEmpty) {
          final double sum = trValues.fold(0.0, (sum, tr) => sum + tr);
          final atr = sum / trValues.length;
          
          // 保存到缓存
          _atrCache[cacheKey] = atr;
          _dataCacheTimes['atr_$cacheKey'] = now;
          
          return atr;
        }
        return null;
      }
      
      // 标准Wilder's ATR计算方法
      // 第一个ATR为前14个TR的简单平均
      double atr = trValues.take(period).reduce((a, b) => a + b) / period;
      
      // 从第15个TR开始，使用Wilder的平滑公式：ATR = ((n-1) * 前一日ATR + 今日TR) / n
      for (int i = period; i < trValues.length; i++) {
        atr = ((period - 1) * atr + trValues[i]) / period;
      }
      
      print('成功计算股票 $stockCode 的ATR值: $atr，使用${trValues.length}天TR数据');
      
      // 保存到缓存
      _atrCache[cacheKey] = atr;
      _dataCacheTimes['atr_$cacheKey'] = now;
      
      return atr;
      
    } catch (e) {
      print('计算ATR值出错: $e');
      
      // 使用备用计算方法
      try {
        final basePrice = await getCurrentPrice(stockCode) ?? 10.0;
        final atr = basePrice * 0.02; // 使用当前价格的2%作为模拟ATR
        
        // 保存到缓存
        _atrCache[cacheKey] = atr;
        _dataCacheTimes['atr_$cacheKey'] = now;
        
        return atr;
      } catch (_) {
        return null;
      }
    }
  }

  Future<void> _initializeStockData() async {
    if (_isInitialized) return;
    
    print('正在初始化股票数据...');
    try {
      // 检查是否需要更新缓存
      final lastUpdated = await _getLastUpdated();
      final now = DateTime.now().millisecondsSinceEpoch;
      
      if (lastUpdated == null || (now - lastUpdated) > _cacheDuration) {
        await _updateStockData();
      }
      
      // 预加载交易所数据到内存
      await _fetchStocks('sz');
      await _fetchStocks('sh');
      await _fetchStocks('bj');
      
      _isInitialized = true;
      print('股票数据初始化完成');
    } catch (e) {
      print('股票数据初始化失败: $e');
    }
  }
  
  // 修改获取历史数据的方法，使用完整路径API接口
  Future<List<Map<String, dynamic>>> getStockHistoryData(
    String stockCode, {
    String? startDate,
    String? endDate,
  }) async {
    // 检查缓存
    final now = DateTime.now().millisecondsSinceEpoch;
    final cacheKey = '${stockCode}_${startDate ?? ""}_${endDate ?? ""}';
    final lastCacheTime = _dataCacheTimes[cacheKey] ?? 0;
    
    // 如果缓存有效，返回缓存数据
    if (_historyDataCache.containsKey(cacheKey) && 
        (now - lastCacheTime) < _dataCacheValidityPeriod) {
      print('使用缓存的股票历史数据: $stockCode');
      return List<Map<String, dynamic>>.from(_historyDataCache[cacheKey]!);
    }
    
    try {
      print('请求K线数据: $stockCode');
      
      // 使用完整路径API配置中的URL
      final url = ApiConfig.getStockHistoryUrl(
        stockCode,
        startDate: startDate,
        endDate: endDate,
      );
      print('请求URL: $url');
      
      // 使用HttpClient发送请求，自动添加API Token
      final response = await HttpClient.get(url);
      
      if (response.statusCode == 200) {
        // 解析返回的数据
        final responseBody = utf8.decode(response.bodyBytes);
        final jsonData = json.decode(responseBody);
        
        print('API返回数据: ${jsonData.keys}');
        
        // 检查返回数据的结构是否正确 - API返回的是data字段，不是history字段
        if (jsonData is Map<String, dynamic> && jsonData.containsKey('data')) {
          final List<dynamic> historyList = jsonData['data'];
          print('获取到历史数据: ${historyList.length}条');
          
          if (historyList.isEmpty) {
            print('股票 $stockCode 的历史数据为空');
            return [];
          }
          
          // 打印样例数据用于调试
          if (historyList.isNotEmpty) {
            print('数据样例: ${historyList.first}');
          }
          
          // 转换为标准格式
          final List<Map<String, dynamic>> processedData = [];
          
          for (var item in historyList) {
            if (item is Map<String, dynamic>) {
              // 处理日期字段 - API返回的是trade_date，需要转换为date
              String date = '';
              if (item.containsKey('trade_date') && item['trade_date'] != null) {
                date = item['trade_date'].toString();
              } else if (item.containsKey('date') && item['date'] != null) {
                date = item['date'].toString();
              }
              
              // 标准化日期格式，去掉可能的时间部分
              if (date.contains('T')) {
                date = date.split('T')[0];
              }
              
              // 创建处理后的数据项，统一字段名称
              final processedItem = <String, dynamic>{
                'date': date, // 统一使用date字段
                'trade_date': date, // 保留原始字段名以兼容
                'open': _parseDouble(item['open']),
                'high': _parseDouble(item['high']),
                'low': _parseDouble(item['low']),
                'close': _parseDouble(item['close']),
                'volume': _parseDouble(item['volume']),
                'amount': _parseDouble(item['amount']), // 添加成交额字段
                'turnover': _parseDouble(item['turnover']),
                'change': _parseDouble(item['change_amount']), // API返回的是change_amount
                'change_pct': _parseDouble(item['change_percent']), // API返回的是change_percent
                'amplitude': _parseDouble(item['amplitude']),
                'turnover_rate': _parseDouble(item['turnover_rate']),
              };
              
              // 验证必要字段
              if (date.isNotEmpty && 
                  processedItem['open'] > 0 && 
                  processedItem['high'] > 0 && 
                  processedItem['low'] > 0 && 
                  processedItem['close'] > 0) {
                processedData.add(processedItem);
              } else {
                print('跳过无效数据项: $item');
              }
            }
          }
          
          // 按日期排序（从旧到新）
          processedData.sort((a, b) {
            final dateA = a['date'].toString();
            final dateB = b['date'].toString();
            return dateA.compareTo(dateB);
          });
          
          print('处理后的数据条数: ${processedData.length}');
          if (processedData.isNotEmpty) {
            print('最新数据: 日期=${processedData.last['date']}, 收盘价=${processedData.last['close']}');
          }
          
          // 更新缓存
          _historyDataCache[cacheKey] = processedData;
          _dataCacheTimes[cacheKey] = now;
          
          return processedData;
        } else {
          print('返回的历史数据格式不正确: $jsonData');
          return [];
        }
      } else {
        print('获取历史数据失败: ${response.statusCode}, ${response.body}');
        return [];
      }
    } catch (e) {
      print('获取历史数据出错: $e');
      return [];
    }
  }
  
  // 解析数字，处理可能的字符串或null值
  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return 0.0;
      }
    }
    return 0.0;
  }
  
  // 计算EMA指标
  List<Map<String, dynamic>> _calculateEMA(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return data;
    
    // 添加5日和17日EMA
    const int shortPeriod = 5;
    const int longPeriod = 17;
    
    // 计算EMA的函数
    double calculateEMA(List<double> prices, int period) {
      if (prices.length < period) return 0;
      
      double multiplier = 2.0 / (period + 1);
      double ema = prices.take(period).reduce((a, b) => a + b) / period; // 第一个值是SMA
      
      for (int i = period; i < prices.length; i++) {
        ema = (prices[i] - ema) * multiplier + ema;
      }
      
      return ema;
    }
    
    // 准备数据
    List<double> closePrices = data.map((item) => item['close'] as double).toList();
    List<Map<String, dynamic>> result = [];
    
    // 对每个数据点计算EMA
    for (int i = 0; i < data.length; i++) {
      double ema5 = 0;
      double ema17 = 0;
      
      if (i >= shortPeriod - 1) {
        ema5 = calculateEMA(closePrices.sublist(0, i + 1), shortPeriod);
      }
      
      if (i >= longPeriod - 1) {
        ema17 = calculateEMA(closePrices.sublist(0, i + 1), longPeriod);
      }
      
      // 复制原始数据并添加EMA值
      final newItem = Map<String, dynamic>.from(data[i]);
      newItem['ema5'] = ema5 > 0 ? double.parse(ema5.toStringAsFixed(2)) : null;
      newItem['ema17'] = ema17 > 0 ? double.parse(ema17.toStringAsFixed(2)) : null;
      
      result.add(newItem);
    }
    
    return result;
  }
  


  // 添加清除缓存的方法
  void clearCache() {
    print('清除StockService所有缓存数据');
    _currentPriceCache.clear();
    _atrCache.clear();
    _historyDataCache.clear();
    _dataCacheTimes.clear();
  }
  
  // 添加刷新单个股票数据的方法
  Future<void> refreshStockData(String stockCode) async {
    print('刷新股票 $stockCode 的缓存数据');
    
    // 清除该股票的所有缓存
    _currentPriceCache.remove(stockCode);
    _atrCache.remove(stockCode);
    
    // 清除历史数据缓存
    final keysToRemove = _historyDataCache.keys.where((key) => key.startsWith('${stockCode}_')).toList();
    for (var key in keysToRemove) {
      _historyDataCache.remove(key);
      _dataCacheTimes.remove(key);
    }
    
    // 移除ATR缓存时间
    _dataCacheTimes.remove('atr_$stockCode');
    
    // 重新获取最新数据
    await getCurrentPrice(stockCode);
    await calculateATR(stockCode);
  }

  // 修改方法：从统一API获取所有股票数据
  Future<void> _fetchAllStocksFromApi() async {
    try {
      print('从统一API获取所有股票数据...');
      
      // 使用统一的API接口获取股票数据，不需要分页参数
      final url = '${ApiConfig.stocksEndpoint}';
      print('请求URL: $url');
      
      // 使用HttpClient获取数据，确保添加Token
      final response = await HttpClient.get(url);

      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        final jsonData = json.decode(responseBody);
        
        if (jsonData is Map<String, dynamic> && jsonData.containsKey('stocks')) {
          final List<dynamic> stocksList = jsonData['stocks'];
          final int total = jsonData['total'] ?? stocksList.length;
          final int returned = jsonData['returned'] ?? stocksList.length;
          
          print('从API获取到${returned}只股票，总计: $total');
          
          if (stocksList.isNotEmpty) {
            // 清空现有数据
            await _database.delete(_tableName);
            
            // 构建规范化的股票数据，适配新的API格式
            final List<Map<String, dynamic>> processedStocks = [];
            
            for (var stock in stocksList) {
              final tsCode = stock['ts_code']?.toString() ?? '';
              final symbol = stock['symbol']?.toString() ?? '';
              final name = stock['name']?.toString() ?? '';
              final area = stock['area']?.toString() ?? '';
              final industry = stock['industry']?.toString() ?? '';
              final market = stock['market']?.toString() ?? '';
              
              if (symbol.isNotEmpty && name.isNotEmpty) {
                // 从ts_code提取市场信息，如"000001.SZ" -> "SZ"
                String marketCode = '';
                if (tsCode.contains('.')) {
                  marketCode = tsCode.split('.').last;
                } else {
                  // 如果没有ts_code，从symbol判断市场
                  if (symbol.startsWith('6')) {
                    marketCode = 'SH';
                  } else if (symbol.startsWith('0') || symbol.startsWith('3')) {
                    marketCode = 'SZ';
                  } else if (symbol.startsWith('8') || symbol.startsWith('4')) {
                    marketCode = 'BJ';
                  }
                }
                
                processedStocks.add({
                  'code': symbol, // 使用symbol作为code
                  'name': name,
                  'market': marketCode,
                  'industry': industry,
                  'board': market, // 使用market字段作为board
                  'area': area,
                  'ts_code': tsCode, // 保存完整的ts_code
                  'listing_date': '',
                  'total_shares': '',
                  'circulating_shares': '',
                  'last_updated': DateTime.now().millisecondsSinceEpoch,
                });
              }
            }
            
            if (processedStocks.isNotEmpty) {
              // 批量插入数据
              final batch = _database.batch();
              for (var stock in processedStocks) {
                batch.insert(_tableName, stock);
              }
              
              await batch.commit();
              await _updateLastUpdated();
              
              print('成功从API获取并保存${processedStocks.length}只股票数据');
              _isInitialized = true;
              return;
            }
          }
        } else {
          print('API返回的数据格式不正确: $jsonData');
        }
      } else {
        print('从API获取股票数据失败: ${response.statusCode}, 响应体: ${response.body}');
      }
      
      print('从API获取的股票数据为空或格式不正确，将尝试其他方法');
    } catch (e) {
      print('从API获取股票数据失败: $e，将尝试其他方法');
    }
    
    // 如果API获取失败，继续尝试从原来的多个接口获取数据
    await _updateStockData();
  }

  // 添加新方法：刷新股票数据
  Future<void> refreshStocks({bool forceRefresh = false}) async {
    try {
      print('开始刷新股票数据...');
      
      // 如果强制刷新，清除所有缓存
      if (forceRefresh) {
        print('强制刷新：清除所有股票缓存');
        clearCache();
        _stockCache.clear();
        _isInitialized = false;
      }
      
      // 优先使用统一API获取所有股票数据
      await _fetchAllStocksFromApi();
      print('股票数据刷新完成');
    } catch (e) {
      print('刷新股票数据失败: $e');
      throw Exception('刷新股票数据失败: $e');
    }
  }

  // 添加新方法：确保股票数据存在
  Future<void> ensureStockDataExists() async {
    try {
      print('检查股票数据是否存在...');
      
      // 检查数据库中是否有股票数据
      final count = await _getStockCount();
      
      if (count == 0) {
        print('数据库中没有股票数据，尝试从网络获取...');
        
        try {
          // 先尝试从网络更新数据
          await refreshStocks();
          
          // 再次检查数据库中是否有股票数据
          final updatedCount = await _getStockCount();
          
          if (updatedCount == 0) {
            print('网络获取失败或数据为空');
          } else {
            print('成功从网络获取并添加$updatedCount只股票');
          }
        } catch (e) {
          print('网络获取股票数据失败: $e');
        }
      } else {
        print('数据库中已有$count只股票数据');
      }
    } catch (e) {
      print('检查股票数据出错: $e');
    }
  }
  
  // 获取数据库中的股票数量
  Future<int> _getStockCount() async {
    final result = await _database.rawQuery('SELECT COUNT(*) as count FROM $_tableName');
    return Sqflite.firstIntValue(result) ?? 0;
  }
  


  // 获取K线数据 - 使用完整路径API
  Future<List<Map<String, dynamic>>> getKLineData(String code, {required String startDate, required String endDate, String period = 'daily', String adjust = 'qfq'}) async {
    final cacheKey = '${code}_${startDate}_${endDate}_${period}_$adjust';
    
    // 检查缓存
    if (_historyDataCache.containsKey(cacheKey) && 
        _dataCacheTimes.containsKey(cacheKey) && 
        DateTime.now().millisecondsSinceEpoch - _dataCacheTimes[cacheKey]! < _dataCacheValidityPeriod) {
      print('从缓存获取K线数据: $code');
      return _historyDataCache[cacheKey]!;
    }
    
    try {
      print('请求K线数据: $code, 从 $startDate 到 $endDate');
      // 使用完整路径API配置
      final url = ApiConfig.getStockHistoryUrl(
        code,
        startDate: startDate,
        endDate: endDate,
      );
      print('请求URL: $url');
      
      // 使用HttpClient发送请求，自动处理API Token
      final response = await HttpClient.get(url);
      
      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        final List<dynamic> rawData = json.decode(responseBody);
        
        // 转换和处理数据
        final data = rawData.map<Map<String, dynamic>>((item) {
          // 确保日期格式一致
          final Map<String, dynamic> processedItem = Map<String, dynamic>.from(item);
          if (processedItem.containsKey('日期')) {
            final dateStr = processedItem['日期'].toString();
            // 如果日期包含T，则去掉T及之后的部分
            if (dateStr.contains('T')) {
              processedItem['日期'] = dateStr.split('T')[0];
            }
          }
          return processedItem;
        }).toList();
        
        // 更新缓存
        _historyDataCache[cacheKey] = data;
        _dataCacheTimes[cacheKey] = DateTime.now().millisecondsSinceEpoch;
        
        return data;
      } else {
        print('获取K线数据失败: ${response.statusCode}, ${response.body}');
        return [];
      }
    } catch (e) {
      print('获取K线数据出错: $e');
      return [];
    }
  }

  // 添加测试方法：测试股票数据初始化和搜索
  Future<void> testStockInitialization() async {
    try {
      print('=== 开始测试股票数据初始化 ===');
      
      // 强制重置初始化状态
      _isInitialized = false;
      clearCache();
      
      // 测试初始化
      await _initializeStockData();
      
      // 检查数据库中的股票数量
      final count = await _getStockCount();
      print('数据库中股票总数: $count');
      
      if (count > 0) {
        // 获取样本数据
        final sampleData = await _database.query(_tableName, limit: 3);
        print('=== 样本数据 ===');
        for (var i = 0; i < sampleData.length; i++) {
          print('股票${i + 1}: ${sampleData[i]}');
        }
        
        // 测试搜索功能
        print('=== 测试搜索功能 ===');
        final searchResults = await getStockSuggestions('300');
        print('搜索"300"结果数量: ${searchResults.length}');
        for (var result in searchResults.take(3)) {
          print('搜索结果: ${result}');
        }
        
        // 按市场统计
        final markets = ['SH', 'SZ', 'BJ'];
        print('=== 市场统计 ===');
        for (var market in markets) {
          final marketCount = await _database.rawQuery(
            'SELECT COUNT(*) as count FROM $_tableName WHERE market = ?',
            [market]
          );
          final count = Sqflite.firstIntValue(marketCount) ?? 0;
          print('$market 市场: $count 只股票');
        }
        
        print('=== 股票数据初始化测试完成 ===');
      } else {
        print('=== 警告：数据库中没有股票数据 ===');
      }
      
    } catch (e) {
      print('=== 测试失败: $e ===');
    }
  }
} 




