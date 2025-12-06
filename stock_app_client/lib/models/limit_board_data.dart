/// 打板数据模型
/// 涨跌停、龙虎榜、连板统计等数据

/// 涨跌停股票数据
class LimitStock {
  final String tradeDate;
  final String tsCode;
  final String name;
  final double close;
  final double pctChg;
  final double amp; // 振幅
  final double fcRatio; // 封成比
  final double flRatio; // 封流比
  final double fdAmount; // 封单金额
  final String firstTime; // 首次封板时间
  final String lastTime; // 最后封板时间
  final int openTimes; // 开板次数
  final String upStat; // 连板统计
  final int limitTimes; // 连板次数
  final String limit; // 涨跌停状态
  final double? upLimit; // 涨停价
  final double? downLimit; // 跌停价
  final double? vol; // 成交量
  final double? amount; // 成交额

  LimitStock({
    required this.tradeDate,
    required this.tsCode,
    required this.name,
    required this.close,
    required this.pctChg,
    this.amp = 0,
    this.fcRatio = 0,
    this.flRatio = 0,
    this.fdAmount = 0,
    this.firstTime = '',
    this.lastTime = '',
    this.openTimes = 0,
    this.upStat = '',
    this.limitTimes = 1,
    this.limit = '',
    this.upLimit,
    this.downLimit,
    this.vol,
    this.amount,
  });

  factory LimitStock.fromJson(Map<String, dynamic> json) {
    return LimitStock(
      tradeDate: json['trade_date'] ?? '',
      tsCode: json['ts_code'] ?? '',
      name: json['name'] ?? '',
      close: (json['close'] ?? 0).toDouble(),
      pctChg: (json['pct_chg'] ?? 0).toDouble(),
      amp: (json['amp'] ?? 0).toDouble(),
      fcRatio: (json['fc_ratio'] ?? 0).toDouble(),
      flRatio: (json['fl_ratio'] ?? 0).toDouble(),
      fdAmount: (json['fd_amount'] ?? 0).toDouble(),
      firstTime: json['first_time'] ?? '',
      lastTime: json['last_time'] ?? '',
      openTimes: json['open_times'] ?? 0,
      upStat: json['up_stat'] ?? '',
      limitTimes: json['limit_times'] ?? 1,
      limit: json['limit'] ?? '',
      upLimit: json['up_limit']?.toDouble(),
      downLimit: json['down_limit']?.toDouble(),
      vol: json['vol']?.toDouble(),
      amount: json['amount']?.toDouble(),
    );
  }
  
  /// 获取纯股票代码（去除后缀）
  String get code => tsCode.split('.').first;
  
  /// 获取市场后缀
  String get market => tsCode.contains('.') ? tsCode.split('.').last : '';
}

/// 龙虎榜股票数据
class TopListStock {
  final String tradeDate;
  final String tsCode;
  final String name;
  final double close;
  final double pctChange;
  final double turnoverRate;
  final double amount; // 总成交额
  final double lSell; // 龙虎榜卖出额
  final double lBuy; // 龙虎榜买入额
  final double lAmount; // 龙虎榜成交额
  final double netAmount; // 龙虎榜净买入额
  final double netRate; // 净买入占比
  final double amountRate; // 成交额占比
  final double floatValues; // 流通市值
  final String reason; // 上榜原因

  TopListStock({
    required this.tradeDate,
    required this.tsCode,
    required this.name,
    required this.close,
    required this.pctChange,
    this.turnoverRate = 0,
    this.amount = 0,
    this.lSell = 0,
    this.lBuy = 0,
    this.lAmount = 0,
    this.netAmount = 0,
    this.netRate = 0,
    this.amountRate = 0,
    this.floatValues = 0,
    this.reason = '',
  });

  factory TopListStock.fromJson(Map<String, dynamic> json) {
    return TopListStock(
      tradeDate: json['trade_date'] ?? '',
      tsCode: json['ts_code'] ?? '',
      name: json['name'] ?? '',
      close: (json['close'] ?? 0).toDouble(),
      pctChange: (json['pct_change'] ?? 0).toDouble(),
      turnoverRate: (json['turnover_rate'] ?? 0).toDouble(),
      amount: (json['amount'] ?? 0).toDouble(),
      lSell: (json['l_sell'] ?? 0).toDouble(),
      lBuy: (json['l_buy'] ?? 0).toDouble(),
      lAmount: (json['l_amount'] ?? 0).toDouble(),
      netAmount: (json['net_amount'] ?? 0).toDouble(),
      netRate: (json['net_rate'] ?? 0).toDouble(),
      amountRate: (json['amount_rate'] ?? 0).toDouble(),
      floatValues: (json['float_values'] ?? 0).toDouble(),
      reason: json['reason'] ?? '',
    );
  }
  
  /// 获取纯股票代码（去除后缀）
  String get code => tsCode.split('.').first;
}

/// 打板综合数据
class LimitBoardSummary {
  final String tradeDate;
  final int upLimitCount;
  final int downLimitCount;
  final int topListCount;
  final Map<String, int> continuousStats; // 连板统计 {"2连板": 10, "3连板": 5, ...}
  final List<LimitStock> upLimitList; // 涨停列表
  final List<LimitStock> downLimitList; // 跌停列表
  final List<TopListStock> topList; // 龙虎榜列表
  final List<LimitStock> topContinuous; // 高连板股票
  final String updateTime;

  LimitBoardSummary({
    required this.tradeDate,
    this.upLimitCount = 0,
    this.downLimitCount = 0,
    this.topListCount = 0,
    this.continuousStats = const {},
    this.upLimitList = const [],
    this.downLimitList = const [],
    this.topList = const [],
    this.topContinuous = const [],
    this.updateTime = '',
  });

  factory LimitBoardSummary.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as Map<String, dynamic>? ?? {};
    final statsRaw = summary['continuous_stats'] as Map<String, dynamic>? ?? {};
    final stats = statsRaw.map((key, value) => MapEntry(key, value as int));
    
    return LimitBoardSummary(
      tradeDate: json['trade_date'] ?? '',
      upLimitCount: summary['up_limit_count'] ?? 0,
      downLimitCount: summary['down_limit_count'] ?? 0,
      topListCount: summary['top_list_count'] ?? 0,
      continuousStats: stats,
      upLimitList: (json['up_limit'] as List<dynamic>? ?? [])
          .map((e) => LimitStock.fromJson(e as Map<String, dynamic>))
          .toList(),
      downLimitList: (json['down_limit'] as List<dynamic>? ?? [])
          .map((e) => LimitStock.fromJson(e as Map<String, dynamic>))
          .toList(),
      topList: (json['top_list'] as List<dynamic>? ?? [])
          .map((e) => TopListStock.fromJson(e as Map<String, dynamic>))
          .toList(),
      topContinuous: (json['top_continuous'] as List<dynamic>? ?? [])
          .map((e) => LimitStock.fromJson(e as Map<String, dynamic>))
          .toList(),
      updateTime: json['update_time'] ?? '',
    );
  }
  
  /// 获取最高连板数
  int get maxContinuousDays {
    if (continuousStats.isEmpty) return 0;
    int max = 0;
    for (final key in continuousStats.keys) {
      final match = RegExp(r'(\d+)连板').firstMatch(key);
      if (match != null) {
        final days = int.tryParse(match.group(1) ?? '0') ?? 0;
        if (days > max) max = days;
      }
    }
    return max;
  }
}

