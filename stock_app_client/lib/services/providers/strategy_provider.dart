import 'package:flutter/foundation.dart';
import '../../models/strategy.dart';
import '../database_service.dart';

class StrategyProvider with ChangeNotifier {
  final DatabaseService _databaseService;
  List<Strategy> _strategies = [];
  bool _isLoading = false;

  StrategyProvider(this._databaseService);

  List<Strategy> get strategies => _strategies;
  bool get isLoading => _isLoading;

  Future<void> loadStrategies() async {
    _isLoading = true;
    notifyListeners();

    try {
      final records = await _databaseService.getStrategies();
      _strategies = records.map((record) => Strategy.fromMap(record)).toList();
    } catch (e) {
      print('Error loading strategies: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addStrategy(Strategy strategy) async {
    try {
      await _databaseService.insertStrategy(strategy);
      await loadStrategies();
    } catch (e) {
      print('Error adding strategy: $e');
      rethrow;
    }
  }

  Future<void> updateStrategy(Strategy strategy) async {
    try {
      await _databaseService.updateStrategy(strategy);
      await loadStrategies();
    } catch (e) {
      print('Error updating strategy: $e');
      rethrow;
    }
  }

  Future<void> deleteStrategy(int id) async {
    try {
      await _databaseService.deleteStrategy(id);
      await loadStrategies();
    } catch (e) {
      print('Error deleting strategy: $e');
      rethrow;
    }
  }

  Future<void> archiveStrategy(int id) async {
    try {
      final strategy = _strategies.firstWhere((s) => s.id == id);
      final updatedStrategy = strategy.copyWith(
        isActive: false,
        updateTime: DateTime.now(),
      );
      await _databaseService.updateStrategy(updatedStrategy);
      await loadStrategies();
    } catch (e) {
      print('Error archiving strategy: $e');
      rethrow;
    }
  }

  Future<void> activateStrategy(int id) async {
    try {
      final strategy = _strategies.firstWhere((s) => s.id == id);
      final updatedStrategy = strategy.copyWith(
        isActive: true,
        updateTime: DateTime.now(),
      );
      await _databaseService.updateStrategy(updatedStrategy);
      await loadStrategies();
    } catch (e) {
      print('Error activating strategy: $e');
      rethrow;
    }
  }

  // 获取策略统计数据
  Map<String, Map<String, dynamic>> get strategyStats {
    final stats = <String, Map<String, dynamic>>{};
    
    for (final strategy in _strategies) {
      if (!stats.containsKey(strategy.name)) {
        stats[strategy.name] = {
          'count': 0,
          'wins': 0,
          'totalProfit': 0.0,
        };
      }
      
      stats[strategy.name]!['count'] = stats[strategy.name]!['count']! + 1;
      const totalProfit = 0.0; // TODO: 从交易记录中获取实际盈亏
      if (totalProfit > 0) {
        stats[strategy.name]!['wins'] = stats[strategy.name]!['wins']! + 1;
      }
      stats[strategy.name]!['totalProfit'] = stats[strategy.name]!['totalProfit']! + totalProfit;
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