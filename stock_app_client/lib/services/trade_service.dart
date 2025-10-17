import '../models/trade_record.dart';
import 'database_service.dart';

class TradeService {
  final DatabaseService _databaseService;

  TradeService(this._databaseService);

  // 创建新的交易计划
  Future<int> createTradePlan(TradeRecord trade) async {
    final db = await _databaseService.database;
    
    // 设置初始状态为待执行
    final tradePlan = trade.copyWith(
      status: TradeStatus.pending,
      category: TradeCategory.plan,
      createTime: DateTime.now(),
      updateTime: DateTime.now(),
    );

    return await _databaseService.insertTradeRecord(tradePlan.toMap());
  }

  // 执行交易计划，创建交割单
  Future<int> executeTradePlan(TradeRecord tradePlan) async {
    final db = await _databaseService.database;
    
    // 计算盈亏
    double netProfit = 0;
    double profitRate = 0;
    double totalCost = 0;

    if (tradePlan.tradeType == TradeType.sell) {
      // 获取之前的买入记录
      final buyRecords = await db.query(
        'trade_records',
        where: 'stock_code = ? AND trade_type = ? AND status = ?',
        whereArgs: [tradePlan.stockCode, TradeType.buy.name, TradeStatus.completed.name],
        orderBy: 'create_time ASC',
      );

      if (buyRecords.isEmpty) {
        throw Exception('没有找到相关的买入交易记录');
      }

      // 计算盈亏
      final buyPrice = buyRecords.first['plan_price'] as double;
      final buyQuantity = buyRecords.first['plan_quantity'] as int;
      
      totalCost = tradePlan.actualPrice! * tradePlan.actualQuantity!;
      final commission = totalCost * 0.0003; // 假设手续费为0.03%
      final tax = totalCost * 0.001; // 假设印花税为0.1%
      
      netProfit = (tradePlan.actualPrice! - buyPrice) * tradePlan.actualQuantity! - commission - tax;
      profitRate = (tradePlan.actualPrice! - buyPrice) / buyPrice * 100;
    }

    final settlement = tradePlan.copyWith(
      status: TradeStatus.completed,
      category: TradeCategory.settlement,
      totalCost: totalCost,
      netProfit: netProfit,
      profitRate: profitRate,
      settlementDate: DateTime.now(),
      settlementStatus: '已完成',
      updateTime: DateTime.now(),
    );

    // 更新原交易计划状态
    await db.update(
      'trade_records',
      {'status': TradeStatus.completed.name},
      where: 'id = ?',
      whereArgs: [tradePlan.id],
    );

    return await _databaseService.insertTradeRecord(settlement.toMap());
  }

  // 更新交易记录
  Future<int> updateTrade(TradeRecord trade) async {
    return await _databaseService.updateTradeRecord(trade.id!, trade.toMap());
  }

  // 获取所有交易记录
  Future<List<TradeRecord>> getAllTrades() async {
    final records = await _databaseService.getTradeRecords();
    return records.map((record) => TradeRecord.fromMap(record)).toList();
  }

  // 获取特定股票的交易记录
  Future<List<TradeRecord>> getTradesByStock(String stockCode) async {
    final db = await _databaseService.database;
    final records = await db.query(
      'trade_records',
      where: 'stock_code = ?',
      whereArgs: [stockCode],
      orderBy: 'create_time DESC',
    );
    return records.map((record) => TradeRecord.fromMap(record)).toList();
  }

  // 计算持仓盈亏
  Future<Map<String, double>> calculatePositionProfit(String stockCode, double currentPrice) async {
    final db = await _databaseService.database;
    final trades = await db.query(
      'trade_records',
      where: 'stock_code = ? AND status = ? AND category = ?',
      whereArgs: [stockCode, TradeStatus.completed.name, TradeCategory.plan.name],
    );

    double totalCost = 0;
    int totalQuantity = 0;

    for (var trade in trades) {
      totalCost += (trade['total_cost'] as double);
      totalQuantity += trade['plan_quantity'] as int;
    }

    if (totalQuantity == 0) {
      return {
        'unrealizedProfit': 0,
        'profitPercentage': 0,
      };
    }

    final averageCost = totalCost / totalQuantity;
    final unrealizedProfit = (currentPrice - averageCost) * totalQuantity;
    final profitPercentage = ((currentPrice - averageCost) / averageCost) * 100;

    return {
      'unrealizedProfit': unrealizedProfit,
      'profitPercentage': profitPercentage,
    };
  }

  // 获取当前持仓
  Future<List<Map<String, dynamic>>> getCurrentPositions() async {
    final db = await _databaseService.database;
    final positions = await db.rawQuery('''
      SELECT 
        stock_code,
        stock_name,
        SUM(CASE WHEN trade_type = 'buy' THEN plan_quantity ELSE -plan_quantity END) as position_quantity,
        AVG(CASE WHEN trade_type = 'buy' THEN plan_price ELSE NULL END) as average_cost,
        MAX(trade_date) as last_trade_date
      FROM trade_records
      WHERE status = 'completed'
      GROUP BY stock_code, stock_name
      HAVING position_quantity > 0
    ''');

    return positions;
  }

  // 获取待执行的交易计划
  Future<List<TradeRecord>> getPendingTradePlans() async {
    final db = await _databaseService.database;
    final records = await db.query(
      'trade_records',
      where: 'status = ?',
      whereArgs: [TradeStatus.pending.name],
      orderBy: 'trade_date DESC',
    );
    return records.map((record) => TradeRecord.fromMap(record)).toList();
  }

  // 检查是否触发止损或止盈
  Future<bool> checkStopLossOrTakeProfit(String stockCode, double currentPrice) async {
    final db = await _databaseService.database;
    final trades = await db.query(
      'trade_records',
      where: 'stock_code = ? AND status = ? AND category = ?',
      whereArgs: [stockCode, TradeStatus.pending.name, TradeCategory.plan.name],
    );

    for (var trade in trades) {
      final stopLossPrice = trade['stop_loss_price'] as double?;
      final takeProfitPrice = trade['take_profit_price'] as double?;

      if (stopLossPrice != null && currentPrice <= stopLossPrice) {
        // 触发止损
        await _executeStopLoss(trade);
        return true;
      }

      if (takeProfitPrice != null && currentPrice >= takeProfitPrice) {
        // 触发止盈
        await _executeTakeProfit(trade);
        return true;
      }
    }

    return false;
  }

  // 执行止损
  Future<void> _executeStopLoss(Map<String, dynamic> trade) async {
    final db = await _databaseService.database;
    await db.update(
      'trade_records',
      {
        'status': TradeStatus.completed.name,
        'notes': '触发止损',
        'update_time': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [trade['id']],
    );
  }

  // 执行止盈
  Future<void> _executeTakeProfit(Map<String, dynamic> trade) async {
    final db = await _databaseService.database;
    await db.update(
      'trade_records',
      {
        'status': TradeStatus.completed.name,
        'notes': '触发止盈',
        'update_time': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [trade['id']],
    );
  }

  Future<TradeRecord> createTrade(TradeRecord trade) async {
    final db = await _databaseService.database;
    final now = DateTime.now();
    final record = trade.copyWith(
      createTime: now,
      updateTime: now,
    );
    final id = await db.insert('trade_records', record.toMap());
    return record.copyWith(id: id);
  }
} 