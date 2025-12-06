import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/stock_indicator.dart';
import '../models/watchlist_item.dart';
import 'api_service.dart';

class WatchlistService {
  static const String _watchlistKey = 'stock_watchlist_v2'; // 更新版本
  static const String _legacyWatchlistKey = 'stock_watchlist'; // 旧版本兼容
  
  // 添加状态变化通知
  static final ValueNotifier<int> watchlistChangeNotifier = ValueNotifier<int>(0);
  
  // API服务实例
  static final ApiService _apiService = ApiService();
  
  // 通知状态变化
  static void _notifyChange() {
    watchlistChangeNotifier.value++;
  }

  // 获取备选池列表（新版本，返回WatchlistItem）
  static Future<List<WatchlistItem>> getWatchlistItems() async {
    try {
      // 移除频繁的调试日志，只在出错时打印
      final prefs = await SharedPreferences.getInstance();
      final watchlistJson = prefs.getString(_watchlistKey);
      
      if (watchlistJson == null || watchlistJson.isEmpty) {
        // 尝试从旧版本迁移数据
        final migratedItems = await _migrateFromLegacyWatchlist();
        return migratedItems;
      }
      
      final List<dynamic> watchlistData = json.decode(watchlistJson);
      final items = watchlistData.map((item) => WatchlistItem.fromJson(item)).toList();
      
      // 重新处理市场信息，确保历史数据也正确显示市场
      final updatedItems = items.map((item) {
        if (item.market == '其他' || item.market.isEmpty || item.market.length <= 3) {
          // 使用静态方法重新计算市场信息
          final originalData = Map<String, dynamic>.from(item.originalDetails);
          originalData['market'] = item.market; // 确保原始市场代码可用
          originalData['code'] = item.code; // 确保股票代码可用
          
          // 通过fromJson重新创建，会自动调用_convertMarketCode
          return WatchlistItem.fromJson({
            'code': item.code,
            'name': item.name,
            'market': item.market,
            'strategy': item.strategy,
            'added_time': item.addedTime.toIso8601String(),
            'original_details': originalData,
            'current_price': item.currentPrice,
            'change_percent': item.changePercent,
            'volume': item.volume,
            'price_update_time': item.priceUpdateTime?.toIso8601String(),
          });
        }
        return item;
      }).toList();
      
      return updatedItems;
    } catch (e) {
      debugPrint('获取备选池失败: $e');
      return [];
    }
  }
  
  // 获取备选池列表（兼容旧接口，返回StockIndicator）
  static Future<List<StockIndicator>> getWatchlist() async {
    try {
      final watchlistItems = await getWatchlistItems();
      return watchlistItems.map((item) => item.toStockIndicator()).toList();
    } catch (e) {
      debugPrint('获取备选池失败: $e');
      return [];
    }
  }

  // 从旧版本数据迁移
  static Future<List<WatchlistItem>> _migrateFromLegacyWatchlist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacyWatchlistJson = prefs.getString(_legacyWatchlistKey);
      
      if (legacyWatchlistJson == null || legacyWatchlistJson.isEmpty) {
        return [];
      }
      
      final List<dynamic> legacyData = json.decode(legacyWatchlistJson);
      final List<WatchlistItem> migratedItems = legacyData
          .map((item) => StockIndicator.fromJson(item))
          .map((stock) => WatchlistItem.fromStockIndicator(stock))
          .toList();
      
      // 保存迁移后的数据
      await _saveWatchlistItems(migratedItems);
      
      // 删除旧数据
      await prefs.remove(_legacyWatchlistKey);
      
      debugPrint('成功迁移 ${migratedItems.length} 个备选池项目');
      return migratedItems;
    } catch (e) {
      debugPrint('迁移备选池数据失败: $e');
      return [];
    }
  }

  // 保存备选池列表
  static Future<bool> _saveWatchlistItems(List<WatchlistItem> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final watchlistJson = json.encode(items.map((item) => item.toJson()).toList());
      return await prefs.setString(_watchlistKey, watchlistJson);
    } catch (e) {
      debugPrint('保存备选池失败: $e');
      return false;
    }
  }
  
  // 添加股票到备选池（新版本）
  static Future<bool> addToWatchlist(StockIndicator stock) async {
    try {
      final watchlistItems = await getWatchlistItems();
      
      // 检查是否已存在
      if (watchlistItems.any((item) => item.code == stock.code)) {
        return true; // 已存在，返回成功
      }
      
      // 创建新的WatchlistItem
      final newItem = WatchlistItem.fromStockIndicator(stock);
      watchlistItems.add(newItem);
      
      final success = await _saveWatchlistItems(watchlistItems);
      
      if (success) {
        _notifyChange(); // 通知状态变化
      }
      
      return success;
    } catch (e) {
      debugPrint('添加到备选池失败: $e');
      return false;
    }
  }
  
  // 添加WatchlistItem到备选池（直接传入WatchlistItem对象）
  static Future<bool> addToWatchlistItem(WatchlistItem item) async {
    try {
      final watchlistItems = await getWatchlistItems();
      
      // 检查是否已存在
      if (watchlistItems.any((existingItem) => existingItem.code == item.code)) {
        debugPrint('股票 ${item.code} 已在备选池中');
        return true; // 已存在也算成功
      }
      
      watchlistItems.add(item);
      
      final success = await _saveWatchlistItems(watchlistItems);
      
      if (success) {
        _notifyChange(); // 通知状态变化
        debugPrint('成功添加 ${item.name} (${item.code}) 到备选池');
      }
      
      return success;
    } catch (e) {
      debugPrint('添加到备选池失败: $e');
      return false;
    }
  }
  
  // 从备选池移除股票
  static Future<bool> removeFromWatchlist(String stockCode) async {
    try {
      final watchlistItems = await getWatchlistItems();
      final originalLength = watchlistItems.length;
      
      watchlistItems.removeWhere((item) => item.code == stockCode);
      
      // 如果没有变化，说明股票不在列表中
      if (watchlistItems.length == originalLength) {
        return true; // 不在列表中也算成功
      }
      
      final success = await _saveWatchlistItems(watchlistItems);
      
      if (success) {
        _notifyChange(); // 通知状态变化
      }
      
      return success;
    } catch (e) {
      debugPrint('从备选池移除失败: $e');
      return false;
    }
  }
  
  // 检查股票是否在备选池中
  static Future<bool> isInWatchlist(String stockCode) async {
    try {
      final watchlistItems = await getWatchlistItems();
      return watchlistItems.any((item) => item.code == stockCode);
    } catch (e) {
      debugPrint('检查备选池状态失败: $e');
      return false;
    }
  }
  
  // 清空备选池
  static Future<bool> clearWatchlist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final success = await prefs.remove(_watchlistKey);
      
      if (success) {
        _notifyChange(); // 通知状态变化
      }
      
      return success;
    } catch (e) {
      debugPrint('清空备选池失败: $e');
      return false;
    }
  }
  
  // 获取备选池数量
  static Future<int> getWatchlistCount() async {
    try {
      final watchlistItems = await getWatchlistItems();
      return watchlistItems.length;
    } catch (e) {
      debugPrint('获取备选池数量失败: $e');
      return 0;
    }
  }

  // 批量更新备选池股票的实时价格
  static Future<List<WatchlistItem>> updateWatchlistPrices({bool forceUpdate = false}) async {
    try {
      final watchlistItems = await getWatchlistItems();
      
      if (watchlistItems.isEmpty) {
        return watchlistItems;
      }

      // 筛选需要更新价格的股票
      final itemsNeedUpdate = forceUpdate 
          ? watchlistItems 
          : watchlistItems.where((item) => item.needsPriceUpdate).toList();

      if (itemsNeedUpdate.isEmpty) {
        debugPrint('所有备选池股票价格都是最新的，无需更新');
        return watchlistItems;
      }

      debugPrint('需要更新价格的股票数量: ${itemsNeedUpdate.length}');
      
      // 获取需要更新的股票代码列表
      final stockCodes = itemsNeedUpdate.map((item) => item.code).toList();
      
      // 批量获取最新价格
      final priceDataList = await _apiService.getBatchStockPrices(stockCodes);
      
      // 创建价格数据映射
      final priceMap = <String, Map<String, dynamic>>{};
      for (final priceData in priceDataList) {
        final code = priceData['code']?.toString();
        if (code != null) {
          priceMap[code] = priceData;
        }
      }
      
      // 更新价格信息
      final updatedItems = watchlistItems.map((item) {
        final priceData = priceMap[item.code];
        if (priceData != null) {
          return item.updatePrice(
            price: priceData['price'] != null ? double.tryParse(priceData['price'].toString()) : null,
            changePercent: priceData['change_percent'] != null ? double.tryParse(priceData['change_percent'].toString()) : null,
            volume: priceData['volume'] != null ? int.tryParse(priceData['volume'].toString()) : null,
          );
        }
        return item;
      }).toList();
      
      // 保存更新后的数据
      await _saveWatchlistItems(updatedItems);
      
      debugPrint('成功更新 ${priceMap.length} 只股票的价格信息');
      return updatedItems;
    } catch (e) {
      debugPrint('更新备选池价格失败: $e');
      // 返回原数据
      return await getWatchlistItems();
    }
  }

  // 更新单个股票的价格信息
  static Future<WatchlistItem?> updateSingleStockPrice(String stockCode) async {
    try {
      final priceData = await _apiService.getStockRealTimePrice(stockCode);
      if (priceData == null) return null;

      final watchlistItems = await getWatchlistItems();
      final itemIndex = watchlistItems.indexWhere((item) => item.code == stockCode);
      
      if (itemIndex == -1) return null;

      final updatedItem = watchlistItems[itemIndex].updatePrice(
        price: priceData['price'] != null ? double.tryParse(priceData['price'].toString()) : null,
        changePercent: priceData['change_percent'] != null ? double.tryParse(priceData['change_percent'].toString()) : null,
        volume: priceData['volume'] != null ? int.tryParse(priceData['volume'].toString()) : null,
      );

      watchlistItems[itemIndex] = updatedItem;
      await _saveWatchlistItems(watchlistItems);

      return updatedItem;
    } catch (e) {
      debugPrint('更新单个股票价格失败: $e');
      return null;
    }
  }
  
  /// 批量查询备选池股票的信号状态
  /// 返回更新了信号信息的股票列表
  static Future<List<WatchlistItem>> updateWatchlistSignals() async {
    try {
      final watchlistItems = await getWatchlistItems();
      
      if (watchlistItems.isEmpty) {
        return watchlistItems;
      }
      
      debugPrint('[WatchlistService] 开始批量查询 ${watchlistItems.length} 只股票的信号');
      
      // 构建请求数据：每只股票使用其对应的策略
      final stocks = watchlistItems.map((item) => {
        'code': item.code,
        'strategy': item.strategy.isNotEmpty ? item.strategy : 'volume_wave',
      }).toList();
      
      // 调用API批量查询
      final signalResults = await _apiService.batchCheckSignals(stocks);
      
      if (signalResults == null || signalResults.isEmpty) {
        debugPrint('[WatchlistService] 批量查询信号返回为空');
        return watchlistItems;
      }
      
      // 将结果转换为Map方便查找
      final signalMap = <String, Map<String, dynamic>>{};
      for (var result in signalResults) {
        final code = result['code'] as String?;
        if (code != null) {
          signalMap[code] = result;
        }
      }
      
      // 更新每个股票的信号信息
      final updatedItems = watchlistItems.map((item) {
        final signalInfo = signalMap[item.code];
        if (signalInfo != null) {
          final signalType = signalInfo['signal'] as String?;
          debugPrint('[WatchlistService] ${item.code} 信号: $signalType');
          return item.updateSignal(
            signalType: signalType,
            signalReason: signalInfo['signal_reason'] as String?,
            confidence: signalInfo['confidence'] != null 
                ? double.tryParse(signalInfo['confidence'].toString()) 
                : null,
          );
        }
        return item;
      }).toList();
      
      // 统计信号数量
      final buyCount = updatedItems.where((item) => item.hasBuySignal).length;
      final sellCount = updatedItems.where((item) => item.hasSellSignal).length;
      debugPrint('[WatchlistService] 信号查询完成: 买入信号 $buyCount 个, 卖出信号 $sellCount 个');
      
      // 保存更新后的数据
      await _saveWatchlistItems(updatedItems);
      
      return updatedItems;
    } catch (e) {
      debugPrint('[WatchlistService] 批量查询信号失败: $e');
      return await getWatchlistItems();
    }
  }
} 