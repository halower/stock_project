import 'package:json_annotation/json_annotation.dart';

part 'stock.g.dart';

@JsonSerializable()
class Stock {
  final String code;
  final String name;
  final double? costPrice;
  final double? currentPrice;
  final int? quantity;
  final double? profit;
  final DateTime? addTime;
  final String? strategy;
  final String? notes;
  final String? watchReason;
  final double? targetPrice;
  final String market;
  final String industry;

  Stock({
    required this.code,
    required this.name,
    this.costPrice,
    this.currentPrice,
    this.quantity,
    this.profit,
    this.addTime,
    this.strategy,
    this.notes,
    this.watchReason,
    this.targetPrice,
    this.market = '',
    this.industry = '',
  });

  factory Stock.fromJson(Map<String, dynamic> json) => _$StockFromJson(json);
  Map<String, dynamic> toJson() => _$StockToJson(this);

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'name': name,
      'cost_price': costPrice,
      'current_price': currentPrice,
      'quantity': quantity,
      'add_time': addTime?.toIso8601String(),
      'strategy': strategy,
      'notes': notes,
      'watch_reason': watchReason,
      'target_price': targetPrice,
      'market': market,
      'industry': industry,
    };
  }

  factory Stock.fromMap(Map<String, dynamic> map) {
    return Stock(
      code: map['code'] as String,
      name: map['name'] as String,
      costPrice: map['cost_price'] as double?,
      currentPrice: map['current_price'] as double?,
      quantity: map['quantity'] as int?,
      addTime: map['add_time'] == null
          ? null
          : DateTime.parse(map['add_time'] as String),
      strategy: map['strategy'] as String?,
      notes: map['notes'] as String?,
      watchReason: map['watch_reason'] as String?,
      targetPrice: map['target_price'] as double?,
      market: map['market'] as String? ?? '',
      industry: map['industry'] as String? ?? '',
    );
  }

  Stock copyWith({
    String? code,
    String? name,
    double? costPrice,
    double? currentPrice,
    int? quantity,
    double? profit,
    DateTime? addTime,
    String? strategy,
    String? notes,
    String? watchReason,
    double? targetPrice,
    String? market,
    String? industry,
  }) {
    return Stock(
      code: code ?? this.code,
      name: name ?? this.name,
      costPrice: costPrice ?? this.costPrice,
      currentPrice: currentPrice ?? this.currentPrice,
      quantity: quantity ?? this.quantity,
      profit: profit ?? this.profit,
      addTime: addTime ?? this.addTime,
      strategy: strategy ?? this.strategy,
      notes: notes ?? this.notes,
      watchReason: watchReason ?? this.watchReason,
      targetPrice: targetPrice ?? this.targetPrice,
      market: market ?? this.market,
      industry: industry ?? this.industry,
    );
  }
}
