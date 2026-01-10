// 估值数据模型

class ValuationData {
  final String tsCode;
  final String stockCode;
  final String stockName;
  final String tradeDate;
  final double close;
  final double pctChg;  // 涨跌幅（%）
  final double change;  // 涨跌额
  final double? pe;
  final double? peTtm;
  final double? pb;
  final double? ps;
  final double? psTtm;
  final double? dividendYield;
  final double? dividendYieldTtm;
  final double totalMv;
  final double circMv;
  final double marketValue; // 市值（亿元）
  final double turnoverRate;
  final double volumeRatio;

  ValuationData({
    required this.tsCode,
    required this.stockCode,
    required this.stockName,
    required this.tradeDate,
    required this.close,
    this.pctChg = 0,
    this.change = 0,
    this.pe,
    this.peTtm,
    this.pb,
    this.ps,
    this.psTtm,
    this.dividendYield,
    this.dividendYieldTtm,
    required this.totalMv,
    required this.circMv,
    required this.marketValue,
    required this.turnoverRate,
    required this.volumeRatio,
  });

  factory ValuationData.fromJson(Map<String, dynamic> json) {
    return ValuationData(
      tsCode: json['ts_code'] ?? '',
      stockCode: json['stock_code'] ?? '',
      stockName: json['stock_name'] ?? '',
      tradeDate: json['trade_date'] ?? '',
      close: (json['close'] ?? 0).toDouble(),
      pctChg: (json['pct_chg'] ?? 0).toDouble(),
      change: (json['change'] ?? 0).toDouble(),
      pe: json['pe'] != null ? (json['pe']).toDouble() : null,
      peTtm: json['pe_ttm'] != null ? (json['pe_ttm']).toDouble() : null,
      pb: json['pb'] != null ? (json['pb']).toDouble() : null,
      ps: json['ps'] != null ? (json['ps']).toDouble() : null,
      psTtm: json['ps_ttm'] != null ? (json['ps_ttm']).toDouble() : null,
      dividendYield: json['dv_ratio'] != null ? (json['dv_ratio']).toDouble() : null,
      dividendYieldTtm: json['dv_ttm'] != null ? (json['dv_ttm']).toDouble() : null,
      totalMv: (json['total_mv'] ?? 0).toDouble(),
      circMv: (json['circ_mv'] ?? 0).toDouble(),
      marketValue: (json['market_value'] ?? 0).toDouble(),
      turnoverRate: (json['turnover_rate'] ?? 0).toDouble(),
      volumeRatio: (json['volume_ratio'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ts_code': tsCode,
      'stock_code': stockCode,
      'stock_name': stockName,
      'trade_date': tradeDate,
      'close': close,
      'pct_chg': pctChg,
      'change': change,
      'pe': pe,
      'pe_ttm': peTtm,
      'pb': pb,
      'ps': ps,
      'ps_ttm': psTtm,
      'dv_ratio': dividendYield,
      'dv_ttm': dividendYieldTtm,
      'total_mv': totalMv,
      'circ_mv': circMv,
      'market_value': marketValue,
      'turnover_rate': turnoverRate,
      'volume_ratio': volumeRatio,
    };
  }
}

class ValuationDetail {
  final String stockCode;
  final String tsCode;
  final String stockName;
  final CurrentValuation currentValuation;
  final String timestamp;

  ValuationDetail({
    required this.stockCode,
    required this.tsCode,
    required this.stockName,
    required this.currentValuation,
    required this.timestamp,
  });

  factory ValuationDetail.fromJson(Map<String, dynamic> json) {
    return ValuationDetail(
      stockCode: json['stock_code'] ?? '',
      tsCode: json['ts_code'] ?? '',
      stockName: json['stock_name'] ?? '',
      currentValuation: CurrentValuation.fromJson(json['current_valuation'] ?? {}),
      timestamp: json['timestamp'] ?? '',
    );
  }
}

class CurrentValuation {
  final double close;
  final double? pe;
  final double? peTtm;
  final double? pb;
  final double? ps;
  final double? psTtm;
  final double? dividendYield;
  final double marketValue;
  final double circMarketValue;
  final double turnoverRate;
  final double volumeRatio;

  CurrentValuation({
    required this.close,
    this.pe,
    this.peTtm,
    this.pb,
    this.ps,
    this.psTtm,
    this.dividendYield,
    required this.marketValue,
    required this.circMarketValue,
    required this.turnoverRate,
    required this.volumeRatio,
  });

  factory CurrentValuation.fromJson(Map<String, dynamic> json) {
    return CurrentValuation(
      close: (json['close'] ?? 0).toDouble(),
      pe: json['pe'] != null ? (json['pe']).toDouble() : null,
      peTtm: json['pe_ttm'] != null ? (json['pe_ttm']).toDouble() : null,
      pb: json['pb'] != null ? (json['pb']).toDouble() : null,
      ps: json['ps'] != null ? (json['ps']).toDouble() : null,
      psTtm: json['ps_ttm'] != null ? (json['ps_ttm']).toDouble() : null,
      dividendYield: json['dividend_yield'] != null ? (json['dividend_yield']).toDouble() : null,
      marketValue: (json['market_value'] ?? 0).toDouble(),
      circMarketValue: (json['circ_market_value'] ?? 0).toDouble(),
      turnoverRate: (json['turnover_rate'] ?? 0).toDouble(),
      volumeRatio: (json['volume_ratio'] ?? 0).toDouble(),
    );
  }
}

class ValuationFilters {
  final double? peMin;
  final double? peMax;
  final double? pbMin;
  final double? pbMax;
  final double? psMin;
  final double? psMax;
  final double? dividendYieldMin;
  final double? marketValueMin;
  final double? marketValueMax;

  ValuationFilters({
    this.peMin,
    this.peMax,
    this.pbMin,
    this.pbMax,
    this.psMin,
    this.psMax,
    this.dividendYieldMin,
    this.marketValueMin,
    this.marketValueMax,
  });

  Map<String, dynamic> toQueryParams() {
    final params = <String, String>{};
    if (peMin != null) params['pe_min'] = peMin.toString();
    if (peMax != null) params['pe_max'] = peMax.toString();
    if (pbMin != null) params['pb_min'] = pbMin.toString();
    if (pbMax != null) params['pb_max'] = pbMax.toString();
    if (psMin != null) params['ps_min'] = psMin.toString();
    if (psMax != null) params['ps_max'] = psMax.toString();
    if (dividendYieldMin != null) params['dividend_yield_min'] = dividendYieldMin.toString();
    if (marketValueMin != null) params['market_value_min'] = marketValueMin.toString();
    if (marketValueMax != null) params['market_value_max'] = marketValueMax.toString();
    return params;
  }

  ValuationFilters copyWith({
    double? peMin,
    double? peMax,
    double? pbMin,
    double? pbMax,
    double? psMin,
    double? psMax,
    double? dividendYieldMin,
    double? marketValueMin,
    double? marketValueMax,
  }) {
    return ValuationFilters(
      peMin: peMin ?? this.peMin,
      peMax: peMax ?? this.peMax,
      pbMin: pbMin ?? this.pbMin,
      pbMax: pbMax ?? this.pbMax,
      psMin: psMin ?? this.psMin,
      psMax: psMax ?? this.psMax,
      dividendYieldMin: dividendYieldMin ?? this.dividendYieldMin,
      marketValueMin: marketValueMin ?? this.marketValueMin,
      marketValueMax: marketValueMax ?? this.marketValueMax,
    );
  }
}

