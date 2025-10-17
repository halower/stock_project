import 'package:json_annotation/json_annotation.dart';

part 'stock_info.g.dart';

@JsonSerializable(
  explicitToJson: true,
  includeIfNull: false,
  createFactory: true,
  createToJson: true,
)
class StockInfo {
  @JsonKey(name: '证券代码', defaultValue: '')
  final String code;
  @JsonKey(name: '证券简称', defaultValue: '')
  final String name;
  @JsonKey(name: 'market', defaultValue: '')
  final String market;
  @JsonKey(name: '所属行业', defaultValue: '')
  final String industry;
  @JsonKey(name: '板块', defaultValue: '')
  final String board;
  @JsonKey(name: '上市日期', defaultValue: '')
  final String listingDate;
  @JsonKey(name: '总股本', defaultValue: '')
  final String totalShares;
  @JsonKey(name: '流通股本', defaultValue: '')
  final String circulatingShares;

  StockInfo({
    required this.code,
    required this.name,
    required this.market,
    required this.industry,
    required this.board,
    required this.listingDate,
    required this.totalShares,
    required this.circulatingShares,
  });

  factory StockInfo.fromJson(Map<String, dynamic> json) => _$StockInfoFromJson(json);
  Map<String, dynamic> toJson() => _$StockInfoToJson(this);
} 