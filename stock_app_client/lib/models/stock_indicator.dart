import 'package:flutter/foundation.dart';
import '../services/strategy_config_service.dart';
import '../services/industry_service.dart';

class StockIndicator {
  final String market;
  final String code;
  final String name;
  final String signal;
  final String? signalReason;
  final double? price;
  final double? changePercent;
  final int? volume;
  final double? volumeRatio; // 量能比率，大于1为放量，小于1为缩量
  final Map<String, dynamic> details;
  final String strategy;

  StockIndicator({
    required this.market,
    required this.code,
    required this.name,
    required this.signal,
    this.signalReason,
    this.price,
    this.changePercent,
    this.volume,
    this.volumeRatio,
    required this.details,
    required this.strategy,
  });

  factory StockIndicator.fromJson(Map<String, dynamic> json) {
    // 获取市场字段，可能是'market'或'board'
    String marketValue = '';
    if (json.containsKey('market') && json['market'] != null) {
      marketValue = json['market'].toString();
    } else if (json.containsKey('board') && json['board'] != null) {
      marketValue = json['board'].toString();
    }
    
    // 获取价格字段，可能是'price'或'latest_price'
    double? priceValue;
    if (json.containsKey('price') && json['price'] != null) {
      priceValue = double.tryParse(json['price'].toString());
    } else if (json.containsKey('latest_price') && json['latest_price'] != null) {
      priceValue = double.tryParse(json['latest_price'].toString());
    }
    
    // 获取涨跌幅
    double? changePercentValue;
    if (json.containsKey('change_percent') && json['change_percent'] != null) {
      changePercentValue = double.tryParse(json['change_percent'].toString());
    }
    
    // 获取成交量
    int? volumeValue;
    if (json.containsKey('volume') && json['volume'] != null) {
      if (json['volume'] is int) {
        volumeValue = json['volume'] as int;
      } else if (json['volume'] is double) {
        volumeValue = (json['volume'] as double).toInt();
      } else {
        volumeValue = int.tryParse(json['volume'].toString());
      }
      // 确保非空值
      if (volumeValue != null) {
        debugPrint('成功解析成交量: $volumeValue');
      } else {
        debugPrint('成交量解析失败，原始值: ${json['volume']}');
      }
    }
    
    // 获取量能比率
    double? volumeRatioValue;
    if (json.containsKey('volume_ratio') && json['volume_ratio'] != null) {
      volumeRatioValue = double.tryParse(json['volume_ratio'].toString());
    }
    
    // 获取策略信息
    String strategyValue = '';
    if (json.containsKey('strategy') && json['strategy'] != null) {
      strategyValue = json['strategy'].toString();
    } else if (json.containsKey('chart_url') && json['chart_url'] != null) {
      // 尝试从chart_url解析策略信息
      final String chartUrl = json['chart_url'].toString();
      if (chartUrl.contains('strategy=trend_continuation')) {
        strategyValue = 'trend_continuation';
      } else {
        strategyValue = 'volume_wave'; // 默认波动策略
      }
    } else {
      strategyValue = 'volume_wave'; // 默认波动策略
    }
    
    return StockIndicator(
      market: marketValue,
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      signal: json['signal'] ?? '买入', // 默认为买入
      signalReason: json['signal_reason'],
      price: priceValue,
      changePercent: changePercentValue,
      volume: volumeValue,
      volumeRatio: volumeRatioValue,
      details: json,
      strategy: strategyValue,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'market': market,
      'code': code,
      'name': name,
      'signal': signal,
      'signal_reason': signalReason,
      'price': price,
      'change_percent': changePercent,
      'volume': volume,
      'volume_ratio': volumeRatio,
      'details': details,
      'strategy': strategy,
    };
  }
  
  String get strategyName {
    // 优先使用API返回的strategy_name字段
    if (details.containsKey('strategy_name') && details['strategy_name'] != null) {
      return details['strategy_name'].toString();
    }
    
    // 如果没有strategy_name字段，返回策略代码，UI中应该使用异步方法获取真实名称
    return strategy.isEmpty ? '未知策略' : strategy;
  }
  
  // 获取行业信息（增强版）
  String? get industry {
    final originalIndustry = details.containsKey('industry') && details['industry'] != null
        ? details['industry'].toString().trim()
        : null;
    
    // 使用行业增强服务
    return IndustryService.enhanceIndustry(originalIndustry, code, name);
  }
  
  // 获取原始行业信息（未增强）
  String? get originalIndustry {
    if (details.containsKey('industry') && details['industry'] != null) {
      final industryStr = details['industry'].toString().trim();
      return industryStr.isNotEmpty ? industryStr : null;
    }
    return null;
  }
  
  // 获取策略名称的异步方法，UI中使用FutureBuilder调用此方法
  Future<String> getStrategyName() async {
    // 优先使用API返回的strategy_name字段
    if (details.containsKey('strategy_name') && details['strategy_name'] != null) {
      return details['strategy_name'].toString();
    }
    
    // 从StrategyConfigService获取策略名称（支持缓存）
    return await StrategyConfigService.getStrategyName(strategy);
  }
} 