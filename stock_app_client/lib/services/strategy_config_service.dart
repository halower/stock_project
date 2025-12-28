import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import 'http_client.dart';

// 备用的本地策略列表（仅在API完全失败时使用）
// ⚠️ 注意：这些策略必须与后端 app/trading/strategies/ 目录下注册的策略完全一致
List<Map<String, String>> _getDefaultStrategyList() {
  return [
    {'value': 'volume_wave', 'label': '量价突破', 'description': '基于成交量和价格波动的短线交易模型，通过检测特定波动模式产生买卖信号'},
    {'value': 'volume_wave_enhanced', 'label': '量价进阶', 'description': '量价突破的增强版，提供更精确的买卖信号和支撑阻力位识别'},
    {'value': 'volatility_conservation', 'label': '趋势追踪', 'description': '基于波动守恒原理的趋势追踪策略，识别关键支撑阻力位并提供止损止盈参考'},
  ];
}

class StrategyConfigService {
  static const String _strategiesKey = 'api_strategies_data';
  static const String _strategiesCacheTimeKey = 'api_strategies_cache_time';
  static const String _strategyNamesCacheKey = 'strategy_names_cache';
  static const String _strategyNamesCacheTimeKey = 'strategy_names_cache_time';
  static const int _cacheDuration = 24 * 60 * 60 * 1000; // 1天的缓存时间（毫秒）
  
  // 内存缓存，避免频繁读取SharedPreferences
  static List<Map<String, String>>? _memoryCache;
  static DateTime? _memoryCacheTime;
  static Map<String, String>? _strategyNamesCache; // 策略名称专用缓存
  static DateTime? _strategyNamesCacheTime;
  
  // 获取策略列表 - 优化版本，优先使用缓存
  static Future<List<Map<String, String>>> getStrategies() async {
    try {
      // 1. 首先检查内存缓存
      if (_memoryCache != null && _memoryCacheTime != null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final cacheAge = now - _memoryCacheTime!.millisecondsSinceEpoch;
        
        // 如果内存缓存未过期（1天），直接返回
        if (cacheAge < _cacheDuration) {
          final cacheAgeHours = (cacheAge / 1000 / 60 / 60).toStringAsFixed(1);
          debugPrint('使用内存缓存的策略列表数据（缓存年龄: ${cacheAgeHours}小时）');
          return _memoryCache!;
        } else {
          debugPrint('内存缓存已过期，清除内存缓存');
          _memoryCache = null;
          _memoryCacheTime = null;
        }
      }
      
      // 2. 检查本地缓存
      final cachedStrategies = await _getCachedStrategies();
      if (cachedStrategies != null) {
        debugPrint('使用本地缓存的策略列表数据');
        // 更新内存缓存
        _memoryCache = cachedStrategies;
        _memoryCacheTime = DateTime.now();
        return cachedStrategies;
      }
      
      // 3. 缓存都没有或已过期，从API获取
      debugPrint('缓存无效，从API获取最新策略列表数据');
      try {
        final result = await _fetchStrategiesFromApi();
        // 缓存获取到的结果
        await _cacheStrategies(result);
        // 更新内存缓存
        _memoryCache = result;
        _memoryCacheTime = DateTime.now();
        // 同时更新策略名称缓存
        await _updateStrategyNamesCache(result);
        return result;
      } catch (apiError) {
        debugPrint('API获取失败: $apiError，使用默认策略数据');
        // API失败时返回默认策略
        final defaultStrategies = _getDefaultStrategyList();
        // 也缓存默认策略，避免重复API调用
        _memoryCache = defaultStrategies;
        _memoryCacheTime = DateTime.now();
        return defaultStrategies;
      }
    } catch (e) {
      debugPrint('获取策略配置错误: $e');
      // 发生错误时返回默认策略列表
      return _getDefaultStrategyList();
    }
  }
  
  // 根据策略代码获取策略名称 - 优化版本，使用专用缓存
  static Future<String> getStrategyName(String strategyCode) async {
    try {
      // 1. 检查内存中的策略名称缓存
      if (_strategyNamesCache != null && _strategyNamesCacheTime != null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final cacheAge = now - _strategyNamesCacheTime!.millisecondsSinceEpoch;
        
        if (cacheAge < _cacheDuration) {
          final cachedName = _strategyNamesCache![strategyCode];
          if (cachedName != null) {
            debugPrint('使用内存缓存的策略名称: $strategyCode -> $cachedName');
            return cachedName;
          }
        } else {
          debugPrint('策略名称内存缓存已过期，清除缓存');
          _strategyNamesCache = null;
          _strategyNamesCacheTime = null;
        }
      }
      
      // 2. 检查本地缓存的策略名称
      final cachedName = await _getCachedStrategyName(strategyCode);
      if (cachedName != null) {
        debugPrint('使用本地缓存的策略名称: $strategyCode -> $cachedName');
        // 更新内存缓存
        _strategyNamesCache ??= {};
        _strategyNamesCache![strategyCode] = cachedName;
        _strategyNamesCacheTime = DateTime.now();
        return cachedName;
      }
      
      // 3. 从策略列表中获取
      final strategies = await getStrategies();
      final strategy = strategies.firstWhere(
        (item) => item['value'] == strategyCode,
        orElse: () => {},
      );
      
      if (strategy.isNotEmpty && strategy['label'] != null) {
        final name = strategy['label']!;
        // 缓存策略名称
        await _cacheStrategyName(strategyCode, name);
        // 更新内存缓存
        _strategyNamesCache ??= {};
        _strategyNamesCache![strategyCode] = name;
        _strategyNamesCacheTime = DateTime.now();
        return name;
      }
      
      // 4. 如果都没找到，返回策略代码本身
      debugPrint('未找到策略名称，返回策略代码: $strategyCode');
      return strategyCode;
    } catch (e) {
      debugPrint('获取策略名称出错: $e');
      return strategyCode;
    }
  }
  
  // 从API获取策略列表
  static Future<List<Map<String, String>>> _fetchStrategiesFromApi() async {
    try {
      const url = ApiConfig.strategiesEndpoint;
      debugPrint('从API获取策略列表: $url');
      
      // 使用HttpClient.get代替直接http.get，确保添加API Token
      final response = await HttpClient.get(url).timeout(
        const Duration(seconds: 30), // 减少超时时间
        onTimeout: () {
          debugPrint('API请求超时，将使用默认策略数据');
          throw Exception('API请求超时');
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final List<dynamic> strategies = data['strategies'] ?? [];
        
        debugPrint('API返回策略数据: ${strategies.length}个');
        
        // 将API返回的策略转换为应用需要的格式
        final result = strategies.map<Map<String, String>>((item) {
          final mappedItem = <String, String>{
            'value': item['code']?.toString() ?? '',
            'label': item['name']?.toString() ?? '未命名策略',
            'description': item['description']?.toString() ?? '',
          };
          return mappedItem;
        }).toList();
        
        // 验证策略数据是否有效
        if (result.isEmpty) {
          debugPrint('API返回的策略列表为空，将使用默认策略数据');
          return _getDefaultStrategyList();
        }
        
        // 检查是否有无效项
        final validItems = result.where((item) => 
            item['value'] != null && 
            item['value']!.isNotEmpty && 
            item['label'] != null && 
            item['label']!.isNotEmpty).toList();
            
        if (validItems.isEmpty) {
          debugPrint('API返回的策略都无效，使用默认策略数据');
          return _getDefaultStrategyList();
        }
        
        debugPrint('成功从API获取策略列表: ${validItems.length}个有效策略');
        return validItems;
      } else {
        debugPrint('API请求失败，状态码: ${response.statusCode}，将使用默认策略数据');
        throw Exception('API请求失败: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('获取策略列表出错: $e，将使用默认策略数据');
      rethrow; // 重新抛出异常，让调用方处理
    }
  }
  
  // 从缓存中获取策略列表
  static Future<List<Map<String, String>>?> _getCachedStrategies() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 获取缓存时间戳
      final cacheTimeStr = prefs.getString(_strategiesCacheTimeKey);
      if (cacheTimeStr == null) {
        return null; // 没有缓存时间
      }
      
      final cacheTime = int.tryParse(cacheTimeStr) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // 检查缓存是否过期（1天）
      if (now - cacheTime > _cacheDuration) {
        debugPrint('策略列表缓存已过期（超过1天）');
        return null;
      }
      
      // 获取缓存的策略数据
      final cachedData = prefs.getString(_strategiesKey);
      if (cachedData == null || cachedData.isEmpty) {
        return null;
      }
      
      final List<dynamic> decodedData = json.decode(cachedData);
      
      debugPrint('从本地缓存读取到${decodedData.length}个策略');
      
      final strategies = decodedData.map<Map<String, String>>((item) {
        return <String, String>{
          'value': item['value']?.toString() ?? '',
          'label': item['label']?.toString() ?? '',
          'description': item['description']?.toString() ?? '',
        };
      }).toList();
      
      // 检查是否有无效项
      final validItems = strategies.where((item) => 
          item['value'] != null && 
          item['value']!.isNotEmpty && 
          item['label'] != null && 
          item['label']!.isNotEmpty).toList();
          
      if (validItems.isEmpty) {
        debugPrint('缓存中没有有效策略项，将返回null以重新获取');
        return null;
      }
      
      debugPrint('成功加载缓存的策略列表: ${validItems.length}个有效策略');
      return validItems;
    } catch (e) {
      debugPrint('解析缓存的策略数据失败: $e');
      return null;
    }
  }
  
  // 获取缓存的策略名称
  static Future<String?> _getCachedStrategyName(String strategyCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 获取缓存时间戳
      final cacheTimeStr = prefs.getString(_strategyNamesCacheTimeKey);
      if (cacheTimeStr == null) {
        return null;
      }
      
      final cacheTime = int.tryParse(cacheTimeStr) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // 检查缓存是否过期（1天）
      if (now - cacheTime > _cacheDuration) {
        debugPrint('策略名称缓存已过期（超过1天）');
        return null;
      }
      
      // 获取缓存的策略名称数据
      final cachedData = prefs.getString(_strategyNamesCacheKey);
      if (cachedData == null || cachedData.isEmpty) {
        return null;
      }
      
      final Map<String, dynamic> decodedData = json.decode(cachedData);
      return decodedData[strategyCode]?.toString();
    } catch (e) {
      debugPrint('获取缓存的策略名称失败: $e');
      return null;
    }
  }
  
  // 缓存策略列表
  static Future<void> _cacheStrategies(List<Map<String, String>> strategies) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 保存当前时间戳
      final now = DateTime.now().millisecondsSinceEpoch;
      await prefs.setString(_strategiesCacheTimeKey, now.toString());
      
      // 保存策略数据
      final encodedData = json.encode(strategies);
      await prefs.setString(_strategiesKey, encodedData);
      
      debugPrint('策略列表已成功缓存（${strategies.length}个策略）');
    } catch (e) {
      debugPrint('缓存策略列表失败: $e');
    }
  }
  
  // 缓存单个策略名称
  static Future<void> _cacheStrategyName(String strategyCode, String strategyName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 获取现有缓存
      Map<String, String> namesCache = {};
      final cachedData = prefs.getString(_strategyNamesCacheKey);
      if (cachedData != null && cachedData.isNotEmpty) {
        final Map<String, dynamic> decodedData = json.decode(cachedData);
        namesCache = decodedData.map((key, value) => MapEntry(key, value.toString()));
      }
      
      // 添加新的策略名称
      namesCache[strategyCode] = strategyName;
      
      // 保存更新后的缓存
      final now = DateTime.now().millisecondsSinceEpoch;
      await prefs.setString(_strategyNamesCacheTimeKey, now.toString());
      await prefs.setString(_strategyNamesCacheKey, json.encode(namesCache));
      
      debugPrint('策略名称已缓存: $strategyCode -> $strategyName');
    } catch (e) {
      debugPrint('缓存策略名称失败: $e');
    }
  }
  
  // 更新策略名称缓存（从策略列表）
  static Future<void> _updateStrategyNamesCache(List<Map<String, String>> strategies) async {
    try {
      final Map<String, String> namesCache = {};
      for (final strategy in strategies) {
        final code = strategy['value'];
        final name = strategy['label'];
        if (code != null && name != null && code.isNotEmpty && name.isNotEmpty) {
          namesCache[code] = name;
        }
      }
      
      if (namesCache.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final now = DateTime.now().millisecondsSinceEpoch;
        await prefs.setString(_strategyNamesCacheTimeKey, now.toString());
        await prefs.setString(_strategyNamesCacheKey, json.encode(namesCache));
        
        // 更新内存缓存
        _strategyNamesCache = namesCache;
        _strategyNamesCacheTime = DateTime.now();
        
        debugPrint('批量更新策略名称缓存: ${namesCache.length}个策略');
      }
    } catch (e) {
      debugPrint('更新策略名称缓存失败: $e');
    }
  }
  
  // 强制刷新策略列表
  static Future<List<Map<String, String>>> refreshStrategies() async {
    try {
      debugPrint('强制刷新策略列表');
      
      // 清除内存缓存
      _memoryCache = null;
      _memoryCacheTime = null;
      _strategyNamesCache = null;
      _strategyNamesCacheTime = null;
      
      final result = await _fetchStrategiesFromApi();
      await _cacheStrategies(result);
      await _updateStrategyNamesCache(result);
      
      // 更新内存缓存
      _memoryCache = result;
      _memoryCacheTime = DateTime.now();
      
      return result;
    } catch (e) {
      debugPrint('刷新策略列表失败: $e');
      // 返回默认策略列表
      final defaultStrategies = _getDefaultStrategyList();
      _memoryCache = defaultStrategies;
      _memoryCacheTime = DateTime.now();
      return defaultStrategies;
    }
  }
  
  // 清除缓存
  static Future<void> clearCache() async {
    try {
      // 清除内存缓存
      _memoryCache = null;
      _memoryCacheTime = null;
      _strategyNamesCache = null;
      _strategyNamesCacheTime = null;
      
      // 清除本地缓存
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_strategiesKey);
      await prefs.remove(_strategiesCacheTimeKey);
      await prefs.remove(_strategyNamesCacheKey);
      await prefs.remove(_strategyNamesCacheTimeKey);
      debugPrint('策略列表和策略名称缓存已清除');
    } catch (e) {
      debugPrint('清除策略缓存失败: $e');
    }
  }
}