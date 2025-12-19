import 'stock_indicator.dart';
import '../services/industry_service.dart';

class WatchlistItem {
  final String code;
  final String name;
  final String market;
  final String strategy;
  final DateTime addedTime; // 加入关注的时间
  final Map<String, dynamic> originalDetails;
  
  // 实时价格信息（可能为空，需要异步更新）
  double? currentPrice;
  double? changePercent;
  int? volume;
  DateTime? priceUpdateTime;
  
  // 信号信息（通过批量查询获取）
  String? signalType;      // buy/sell/null
  String? signalReason;    // 信号原因
  double? signalConfidence; // 信号置信度
  DateTime? signalUpdateTime; // 信号更新时间

  WatchlistItem({
    required this.code,
    required this.name,
    required this.market,
    required this.strategy,
    required this.addedTime,
    required this.originalDetails,
    this.currentPrice,
    this.changePercent,
    this.volume,
    this.priceUpdateTime,
    this.signalType,
    this.signalReason,
    this.signalConfidence,
    this.signalUpdateTime,
  });

  // 市场代码转换为完整市场名称
  static String _convertMarketCode(String stockCode, String marketCode) {
    // 如果已经是完整的市场名称，直接返回
    if (marketCode.length > 3) {
      return marketCode;
    }
    
    // 根据股票代码推断完整市场名称
    if (stockCode.length >= 6) {
      final prefix = stockCode.substring(0, 3);
      
      // 深圳交易所
      if (prefix == '000' || prefix == '001' || prefix == '002' || prefix == '003') {
        return '主板';
      } else if (prefix == '300' || prefix == '301') {
        return '创业板';
      }
      // 上海交易所
      else if (prefix == '600' || prefix == '601' || prefix == '603' || prefix == '605') {
        return '主板';
      } else if (prefix == '688' || prefix == '689') {
        return '科创板';
      }
      // 北京交易所
      else if (prefix == '430' || prefix == '830' || prefix == '870') {
        return '北交所';
      }
      // B股
      else if (prefix == '900' || prefix == '200') {
        return 'B股';
      }
      // ETF（5开头的上海ETF，15开头的深圳ETF）- 与后端逻辑保持一致
      else if (stockCode.startsWith('5') || stockCode.startsWith('15')) {
        return 'ETF';
      }
    }
    
    // 根据市场代码推断
    switch (marketCode.toUpperCase()) {
      case 'SH':
        // 上海：688=科创板，5开头=ETF，其他=主板
        if (stockCode.startsWith('688')) return '科创板';
        if (stockCode.startsWith('5')) return 'ETF';
        return '主板';
      case 'SZ':
        // 深圳：300=创业板，15开头=ETF，其他=主板
        if (stockCode.startsWith('300')) return '创业板';
        if (stockCode.startsWith('15')) return 'ETF';
        return '主板';
      case 'BJ':
        return '北交所';
      case 'ETF':
        return 'ETF';
      default:
        return '其他';
    }
  }

  // 从StockIndicator创建WatchlistItem
  factory WatchlistItem.fromStockIndicator(StockIndicator stock) {
    return WatchlistItem(
      code: stock.code,
      name: stock.name,
      market: _convertMarketCode(stock.code, stock.market),
      strategy: stock.strategy,
      addedTime: DateTime.now(),
      originalDetails: stock.details,
      currentPrice: stock.price,
      changePercent: stock.changePercent,
      volume: stock.volume,
      priceUpdateTime: DateTime.now(),
    );
  }

  // 从JSON创建WatchlistItem
  factory WatchlistItem.fromJson(Map<String, dynamic> json) {
    final code = json['code'] ?? '';
    final rawMarket = json['market'] ?? '';
    
    return WatchlistItem(
      code: code,
      name: json['name'] ?? '',
      market: _convertMarketCode(code, rawMarket),
      strategy: json['strategy'] ?? '',
      addedTime: DateTime.parse(json['added_time'] ?? DateTime.now().toIso8601String()),
      originalDetails: json['original_details'] ?? {},
      currentPrice: json['current_price'] != null ? double.tryParse(json['current_price'].toString()) : null,
      changePercent: json['change_percent'] != null ? double.tryParse(json['change_percent'].toString()) : null,
      volume: json['volume'] != null ? int.tryParse(json['volume'].toString()) : null,
      priceUpdateTime: json['price_update_time'] != null 
          ? DateTime.parse(json['price_update_time']) 
          : null,
      signalType: json['signal_type'],
      signalReason: json['signal_reason'],
      signalConfidence: json['signal_confidence'] != null 
          ? double.tryParse(json['signal_confidence'].toString()) 
          : null,
      signalUpdateTime: json['signal_update_time'] != null 
          ? DateTime.parse(json['signal_update_time']) 
          : null,
    );
  }

  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'market': market,
      'strategy': strategy,
      'added_time': addedTime.toIso8601String(),
      'original_details': originalDetails,
      'current_price': currentPrice,
      'change_percent': changePercent,
      'volume': volume,
      'price_update_time': priceUpdateTime?.toIso8601String(),
      'signal_type': signalType,
      'signal_reason': signalReason,
      'signal_confidence': signalConfidence,
      'signal_update_time': signalUpdateTime?.toIso8601String(),
    };
  }

  // 更新价格信息
  WatchlistItem updatePrice({
    double? price,
    double? changePercent,
    int? volume,
  }) {
    return WatchlistItem(
      code: code,
      name: name,
      market: market,
      strategy: strategy,
      addedTime: addedTime,
      originalDetails: originalDetails,
      currentPrice: price ?? currentPrice,
      changePercent: changePercent ?? this.changePercent,
      volume: volume ?? this.volume,
      priceUpdateTime: DateTime.now(),
      signalType: signalType,
      signalReason: signalReason,
      signalConfidence: signalConfidence,
      signalUpdateTime: signalUpdateTime,
    );
  }
  
  // 更新信号信息
  WatchlistItem updateSignal({
    String? signalType,
    String? signalReason,
    double? confidence,
  }) {
    return WatchlistItem(
      code: code,
      name: name,
      market: market,
      strategy: strategy,
      addedTime: addedTime,
      originalDetails: originalDetails,
      currentPrice: currentPrice,
      changePercent: changePercent,
      volume: volume,
      priceUpdateTime: priceUpdateTime,
      signalType: signalType,
      signalReason: signalReason,
      signalConfidence: confidence,
      signalUpdateTime: DateTime.now(),
    );
  }
  
  // 是否有买入信号
  bool get hasBuySignal => signalType == 'buy';
  
  // 是否有卖出信号
  bool get hasSellSignal => signalType == 'sell';
  
  // 是否有任何信号
  bool get hasSignal => signalType != null;

  // 获取关注时长的友好显示文本
  String get watchDurationText {
    final now = DateTime.now();
    final duration = now.difference(addedTime);
    
    if (duration.inDays > 0) {
      return '${duration.inDays}天前';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}小时前';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }

  // 获取关注时长的详细文本
  String get watchDurationDetailText {
    final now = DateTime.now();
    final duration = now.difference(addedTime);
    
    if (duration.inDays > 0) {
      final hours = duration.inHours % 24;
      if (hours > 0) {
        return '${duration.inDays}天$hours小时';
      } else {
        return '${duration.inDays}天';
      }
    } else if (duration.inHours > 0) {
      final minutes = duration.inMinutes % 60;
      if (minutes > 0) {
        return '${duration.inHours}小时$minutes分钟';
      } else {
        return '${duration.inHours}小时';
      }
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}分钟';
    } else {
      return '刚刚关注';
    }
  }

  // 检查价格信息是否需要更新（超过5分钟）
  bool get needsPriceUpdate {
    if (priceUpdateTime == null) return true;
    final now = DateTime.now();
    return now.difference(priceUpdateTime!).inMinutes > 5;
  }

  // 获取行业信息（增强版）
  String? get industry {
    final originalIndustry = originalDetails['industry'] as String?;
    return IndustryService.enhanceIndustry(originalIndustry, code, name);
  }
  
  // 获取原始行业信息（未增强）
  String? get originalIndustry {
    return originalDetails['industry'] as String?;
  }

  // 转换为StockIndicator（用于兼容现有组件）
  StockIndicator toStockIndicator() {
    return StockIndicator(
      market: market,
      code: code,
      name: name,
      signal: '关注', // 备选池中的股票标记为"关注"
      price: currentPrice,
      changePercent: changePercent,
      volume: volume,
      details: originalDetails,
      strategy: strategy,
    );
  }
} 