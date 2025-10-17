import 'package:flutter/foundation.dart';
import '../../models/trade_record.dart';
import '../database_service.dart';
import '../trade_service.dart';

class TradeProvider with ChangeNotifier {
  final DatabaseService _databaseService;
  final TradeService _tradeService;
  List<TradeRecord> _tradeRecords = [];
  bool _isLoading = false;

  TradeProvider(this._databaseService)
      : _tradeService = TradeService(_databaseService);

  List<TradeRecord> get tradeRecords => _tradeRecords;
  bool get isLoading => _isLoading;
  
  // 获取有效的交易记录（过滤掉周末的交易）
  List<TradeRecord> get validTradeRecords {
    return _tradeRecords.where((record) {
      // 过滤掉周六(6)和周日(7)的交易
      return record.tradeDate.weekday < 6;
    }).toList();
  }
  
  // 获取周末的交易记录
  List<TradeRecord> get weekendTradeRecords {
    return _tradeRecords.where((record) {
      // 只返回周六(6)和周日(7)的交易
      return record.tradeDate.weekday >= 6;
    }).toList();
  }
  
  // 检查是否存在周末交易记录
  bool get hasWeekendRecords => weekendTradeRecords.isNotEmpty;

  Future<void> loadTradeRecords() async {
    _isLoading = true;
    notifyListeners();

    try {
      _tradeRecords = await _tradeService.getAllTrades();
    } catch (e) {
      print('Error loading trade records: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addTradePlan(TradeRecord record) async {
    try {
      await _tradeService.createTradePlan(record);
      await loadTradeRecords();
    } catch (e) {
      print('Error adding trade plan: $e');
      rethrow;
    }
  }

  Future<void> executeTradePlan(TradeRecord record) async {
    try {
      await _tradeService.executeTradePlan(record);
      await loadTradeRecords();
    } catch (e) {
      print('Error executing trade plan: $e');
      rethrow;
    }
  }

  Future<void> updateTradeRecord(TradeRecord record) async {
    try {
      await _tradeService.updateTrade(record);
      await loadTradeRecords();
    } catch (e) {
      print('Error updating trade record: $e');
      rethrow;
    }
  }

  Future<void> deleteTradeRecord(int id) async {
    try {
      await _databaseService.deleteTradeRecord(id);
      await loadTradeRecords();
    } catch (e) {
      print('Error deleting trade record: $e');
      rethrow;
    }
  }
  
  // 删除所有周末交易记录
  Future<void> deleteAllWeekendRecords() async {
    try {
      final weekendRecords = weekendTradeRecords;
      for (var record in weekendRecords) {
        if (record.id != null) {
          await _databaseService.deleteTradeRecord(record.id!);
        }
      }
      await loadTradeRecords();
    } catch (e) {
      print('Error deleting weekend records: $e');
      rethrow;
    }
  }

  // 计算统计数据 - 使用有效交易记录
  double get totalProfit {
    return validTradeRecords.fold(
        0.0, (sum, record) => sum + (record.netProfit ?? 0));
  }

  double get winRate {
    if (validTradeRecords.isEmpty) return 0;
    int winningTrades =
        validTradeRecords.where((record) => (record.netProfit ?? 0) > 0).length;
    return (winningTrades / validTradeRecords.length) * 100;
  }

  double get averageProfit {
    if (validTradeRecords.isEmpty) return 0;
    return totalProfit / validTradeRecords.length;
  }

  double get averageProfitRate {
    if (validTradeRecords.isEmpty) return 0;
    final totalRate = validTradeRecords.fold<double>(
      0.0,
      (sum, record) => sum + (record.profitRate ?? 0),
    );
    return totalRate / validTradeRecords.length;
  }

  // 获取策略统计数据 - 使用有效交易记录
  Map<String, Map<String, dynamic>> get strategyStats {
    final stats = <String, Map<String, dynamic>>{};

    for (final record in validTradeRecords) {
      final strategyName = record.strategy ?? '未指定策略';
      if (!stats.containsKey(strategyName)) {
        stats[strategyName] = {
          'count': 0,
          'wins': 0,
          'totalProfit': 0.0,
        };
      }

      stats[strategyName]!['count'] = stats[strategyName]!['count']! + 1;
      final profit = record.netProfit ?? 0;
      if (profit > 0) {
        stats[strategyName]!['wins'] = stats[strategyName]!['wins']! + 1;
      }
      stats[strategyName]!['totalProfit'] =
          stats[strategyName]!['totalProfit']! + profit;
    }

    // 计算胜率和平均盈亏
    for (final strategy in stats.keys) {
      final count = stats[strategy]!['count'] as int;
      final wins = stats[strategy]!['wins'] as int;
      final totalProfit = stats[strategy]!['totalProfit'] as double;

      stats[strategy]!['winRate'] = count > 0 ? (wins / count * 100) : 0.0;
      stats[strategy]!['avgProfit'] = count > 0 ? (totalProfit / count) : 0.0;
    }

    return stats;
  }
}
