/// K线回放训练会话模型
class ReplayTrainingSession {
  final String stockCode;
  final String stockName;
  final double initialCapital; // 初始资金
  double currentCapital; // 当前资金
  int currentPosition; // 当前持仓数量
  double? positionCost; // 持仓成本
  final List<ReplayTrade> trades; // 交易记录
  final DateTime startTime;
  DateTime? endTime;
  
  ReplayTrainingSession({
    required this.stockCode,
    required this.stockName,
    required this.initialCapital,
    DateTime? startTime,
  })  : currentCapital = initialCapital,
        currentPosition = 0,
        positionCost = null,
        trades = [],
        startTime = startTime ?? DateTime.now();
  
  // 计算总盈亏
  double get totalProfitLoss => currentCapital - initialCapital;
  
  // 计算盈亏率
  double get profitLossRate => (totalProfitLoss / initialCapital) * 100;
  
  // 计算胜率
  double get winRate {
    if (trades.isEmpty) return 0;
    final winTrades = trades.where((t) => t.profitLoss > 0).length;
    return (winTrades / trades.length) * 100;
  }
  
  // 计算平均盈利
  double get averageProfit {
    if (trades.isEmpty) return 0;
    final profitTrades = trades.where((t) => t.profitLoss > 0);
    if (profitTrades.isEmpty) return 0;
    return profitTrades.map((t) => t.profitLoss).reduce((a, b) => a + b) / profitTrades.length;
  }
  
  // 计算平均亏损
  double get averageLoss {
    if (trades.isEmpty) return 0;
    final lossTrades = trades.where((t) => t.profitLoss < 0);
    if (lossTrades.isEmpty) return 0;
    return lossTrades.map((t) => t.profitLoss).reduce((a, b) => a + b) / lossTrades.length;
  }
  
  // 计算最大盈利
  double get maxProfit {
    if (trades.isEmpty) return 0;
    return trades.map((t) => t.profitLoss).reduce((a, b) => a > b ? a : b);
  }
  
  // 计算最大亏损
  double get maxLoss {
    if (trades.isEmpty) return 0;
    return trades.map((t) => t.profitLoss).reduce((a, b) => a < b ? a : b);
  }
  
  // 计算盈亏比
  double get profitLossRatio {
    if (averageLoss == 0) return 0;
    return averageProfit / averageLoss.abs();
  }
  
  // 计算交易次数
  int get totalTrades => trades.length;
  
  // 计算盈利次数
  int get winTrades => trades.where((t) => t.profitLoss > 0).length;
  
  // 计算亏损次数
  int get lossTrades => trades.where((t) => t.profitLoss < 0).length;
  
  // 计算持平次数
  int get breakEvenTrades => trades.where((t) => t.profitLoss == 0).length;
  
  // 结束训练
  void endSession() {
    endTime = DateTime.now();
  }
  
  // 获取训练时长（分钟）
  int get durationMinutes {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime).inMinutes;
  }
}

/// 单次交易记录
class ReplayTrade {
  final String action; // 'buy' or 'sell'
  final double price; // 交易价格
  final int quantity; // 交易数量
  final DateTime time; // 交易时间
  final String date; // K线日期
  final double profitLoss; // 盈亏金额（仅卖出时有值）
  final double profitLossRate; // 盈亏率（仅卖出时有值）
  
  ReplayTrade({
    required this.action,
    required this.price,
    required this.quantity,
    required this.time,
    required this.date,
    this.profitLoss = 0,
    this.profitLossRate = 0,
  });
  
  // 交易金额
  double get amount => price * quantity;
}

/// 技术指标配置
class TechnicalIndicator {
  final String name; // 指标名称
  final String type; // 指标类型：'MA', 'MACD', 'RSI', 'BOLL', 'KDJ'
  final Map<String, dynamic> params; // 指标参数
  final bool enabled; // 是否启用
  
  TechnicalIndicator({
    required this.name,
    required this.type,
    required this.params,
    this.enabled = true,
  });
  
  // 预设指标
  static List<TechnicalIndicator> getDefaultIndicators() {
    return [
      TechnicalIndicator(
        name: 'MA5',
        type: 'MA',
        params: {'period': 5, 'color': 'white'},
        enabled: true,
      ),
      TechnicalIndicator(
        name: 'MA10',
        type: 'MA',
        params: {'period': 10, 'color': 'yellow'},
        enabled: true,
      ),
      TechnicalIndicator(
        name: 'MA20',
        type: 'MA',
        params: {'period': 20, 'color': 'purple'},
        enabled: true,
      ),
      TechnicalIndicator(
        name: 'MA60',
        type: 'MA',
        params: {'period': 60, 'color': 'green'},
        enabled: false,
      ),
      TechnicalIndicator(
        name: 'MACD',
        type: 'MACD',
        params: {'fast': 12, 'slow': 26, 'signal': 9},
        enabled: false,
      ),
      TechnicalIndicator(
        name: 'RSI',
        type: 'RSI',
        params: {'period': 14},
        enabled: false,
      ),
      TechnicalIndicator(
        name: 'BOLL',
        type: 'BOLL',
        params: {'period': 20, 'std': 2},
        enabled: false,
      ),
      TechnicalIndicator(
        name: 'KDJ',
        type: 'KDJ',
        params: {'n': 9, 'k': 3, 'd': 3},
        enabled: false,
      ),
    ];
  }
}

