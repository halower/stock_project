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
      debugPrint('开始获取备选池数据...');
      final prefs = await SharedPreferences.getInstance();
      final watchlistJson = prefs.getString(_watchlistKey);
      
      debugPrint('备选池JSON数据: ${watchlistJson?.substring(0, watchlistJson.length > 100 ? 100 : watchlistJson.length)}...');
      
      if (watchlistJson == null || watchlistJson.isEmpty) {
        debugPrint('备选池数据为空，尝试从旧版本迁移...');
        // 尝试从旧版本迁移数据
        final migratedItems = await _migrateFromLegacyWatchlist();
        debugPrint('迁移完成，获得 ${migratedItems.length} 个项目');
        return migratedItems;
      }
      
      final List<dynamic> watchlistData = json.decode(watchlistJson);
      final items = watchlistData.map((item) => WatchlistItem.fromJson(item)).toList();
      debugPrint('成功解析备选池数据，共 ${items.length} 个项目');
      
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
      
      // 打印前3个项目的详细信息用于调试
      for (int i = 0; i < updatedItems.length && i < 3; i++) {
        final item = updatedItems[i];
        debugPrint('备选池项目 $i: ${item.code} - ${item.name}');
        debugPrint('  市场: ${item.market}');
        debugPrint('  策略: ${item.strategy}');
        debugPrint('  原始数据: ${item.originalDetails}');
      }
      
      return updatedItems;
    } catch (e) {
      debugPrint('获取备选池失败: $e');
      debugPrint('错误堆栈: ${StackTrace.current}');
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
} 