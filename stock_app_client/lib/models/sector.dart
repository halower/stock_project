// 板块数据模型

class Sector {
  final String tsCode;
  final String name;
  final int stockCount;
  final String exchange;
  final String listDate;
  final String type; // N=概念，I=行业

  Sector({
    required this.tsCode,
    required this.name,
    required this.stockCount,
    required this.exchange,
    required this.listDate,
    required this.type,
  });

  factory Sector.fromJson(Map<String, dynamic> json) {
    return Sector(
      tsCode: json['ts_code'] ?? '',
      name: json['name'] ?? '',
      stockCount: json['count'] ?? 0,
      exchange: json['exchange'] ?? '',
      listDate: json['list_date'] ?? '',
      type: json['type'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ts_code': tsCode,
      'name': name,
      'count': stockCount,
      'exchange': exchange,
      'list_date': listDate,
      'type': type,
    };
  }
}

class SectorMember {
  final String tsCode;
  final String stockCode;
  final String name;
  final double weight;
  final String inDate;
  final String outDate;

  SectorMember({
    required this.tsCode,
    required this.stockCode,
    required this.name,
    required this.weight,
    required this.inDate,
    required this.outDate,
  });

  factory SectorMember.fromJson(Map<String, dynamic> json) {
    return SectorMember(
      tsCode: json['ts_code'] ?? '',
      stockCode: json['stock_code'] ?? '',
      name: json['name'] ?? '',
      weight: (json['weight'] ?? 0).toDouble(),
      inDate: json['in_date'] ?? '',
      outDate: json['out_date'] ?? '',
    );
  }
}

class SectorStrength {
  final String sectorCode;
  final double avgChangePct;
  final int upCount;
  final int downCount;
  final int limitUpCount;
  final int limitDownCount;
  final double avgTurnoverRate;
  final double totalAmount;
  final LeadingStock? leadingStock;
  final int sampleCount;
  final int totalCount;
  final String timestamp;

  SectorStrength({
    required this.sectorCode,
    required this.avgChangePct,
    required this.upCount,
    required this.downCount,
    required this.limitUpCount,
    required this.limitDownCount,
    required this.avgTurnoverRate,
    required this.totalAmount,
    this.leadingStock,
    required this.sampleCount,
    required this.totalCount,
    required this.timestamp,
  });

  factory SectorStrength.fromJson(Map<String, dynamic> json) {
    return SectorStrength(
      sectorCode: json['sector_code'] ?? '',
      avgChangePct: (json['avg_change_pct'] ?? 0).toDouble(),
      upCount: json['up_count'] ?? 0,
      downCount: json['down_count'] ?? 0,
      limitUpCount: json['limit_up_count'] ?? 0,
      limitDownCount: json['limit_down_count'] ?? 0,
      avgTurnoverRate: (json['avg_turnover_rate'] ?? 0).toDouble(),
      totalAmount: (json['total_amount'] ?? 0).toDouble(),
      leadingStock: json['leading_stock'] != null
          ? LeadingStock.fromJson(json['leading_stock'])
          : null,
      sampleCount: json['sample_count'] ?? 0,
      totalCount: json['total_count'] ?? 0,
      timestamp: json['timestamp'] ?? '',
    );
  }
}

class LeadingStock {
  final String tsCode;
  final String name;
  final double changePct;

  LeadingStock({
    required this.tsCode,
    required this.name,
    required this.changePct,
  });

  factory LeadingStock.fromJson(Map<String, dynamic> json) {
    return LeadingStock(
      tsCode: json['ts_code'] ?? '',
      name: json['name'] ?? '',
      changePct: (json['change_pct'] ?? 0).toDouble(),
    );
  }
}

class SectorRanking {
  final String tsCode;
  final String name;
  final String type;
  final int stockCount;
  final double avgChangePct;
  final int upCount;
  final int downCount;
  final int limitUpCount;
  final double avgTurnoverRate;
  final double totalAmount;
  final LeadingStock? leadingStock;

  SectorRanking({
    required this.tsCode,
    required this.name,
    required this.type,
    required this.stockCount,
    required this.avgChangePct,
    required this.upCount,
    required this.downCount,
    required this.limitUpCount,
    required this.avgTurnoverRate,
    required this.totalAmount,
    this.leadingStock,
  });

  factory SectorRanking.fromJson(Map<String, dynamic> json) {
    return SectorRanking(
      tsCode: json['ts_code'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      stockCount: json['stock_count'] ?? 0,
      avgChangePct: (json['avg_change_pct'] ?? 0).toDouble(),
      upCount: json['up_count'] ?? 0,
      downCount: json['down_count'] ?? 0,
      limitUpCount: json['limit_up_count'] ?? 0,
      avgTurnoverRate: (json['avg_turnover_rate'] ?? 0).toDouble(),
      totalAmount: (json['total_amount'] ?? 0).toDouble(),
      leadingStock: json['leading_stock'] != null
          ? LeadingStock.fromJson(json['leading_stock'])
          : null,
    );
  }
}

class HotConcept {
  final String tsCode;
  final String name;
  final int stockCount;
  final double avgChangePct;
  final int upCount;
  final int limitUpCount;
  final double upRatio;
  final double heatScore;
  final LeadingStock? leadingStock;

  HotConcept({
    required this.tsCode,
    required this.name,
    required this.stockCount,
    required this.avgChangePct,
    required this.upCount,
    required this.limitUpCount,
    required this.upRatio,
    required this.heatScore,
    this.leadingStock,
  });

  factory HotConcept.fromJson(Map<String, dynamic> json) {
    return HotConcept(
      tsCode: json['ts_code'] ?? '',
      name: json['name'] ?? '',
      stockCount: json['stock_count'] ?? 0,
      avgChangePct: (json['avg_change_pct'] ?? 0).toDouble(),
      upCount: json['up_count'] ?? 0,
      limitUpCount: json['limit_up_count'] ?? 0,
      upRatio: (json['up_ratio'] ?? 0).toDouble(),
      heatScore: (json['heat_score'] ?? 0).toDouble(),
      leadingStock: json['leading_stock'] != null
          ? LeadingStock.fromJson(json['leading_stock'])
          : null,
    );
  }
}

