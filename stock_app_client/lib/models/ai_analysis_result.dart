/// AI分析结果模型
/// 包含买入信号、理由、止损价、目标价、置信度等信息
/// 简化版本，不依赖代码生成
library;

class AIAnalysisResult {
  /// 信号类型：买入、观望、卖出
  final String signal;
  
  /// 分析理由（包含趋势判断和技术依据）
  final String reason;
  
  /// 止损价
  final double? stopLoss;
  
  /// 目标价
  final double? takeProfit;
  
  /// 置信度：高、中、低
  final String confidence;
  
  /// 技术分析详情
  final TechnicalAnalysis? technicalAnalysis;
  
  /// 风险提示
  final String? riskWarning;
  
  AIAnalysisResult({
    required this.signal,
    required this.reason,
    this.stopLoss,
    this.takeProfit,
    required this.confidence,
    this.technicalAnalysis,
    this.riskWarning,
  });
  
  /// 从JSON创建实例
  factory AIAnalysisResult.fromJson(Map<String, dynamic> json) {
    return AIAnalysisResult(
      signal: json['signal'] as String? ?? '观望',
      reason: json['reason'] as String? ?? '',
      stopLoss: (json['stop_loss'] as num?)?.toDouble(),
      takeProfit: (json['take_profit'] as num?)?.toDouble(),
      confidence: json['confidence'] as String? ?? '中',
      technicalAnalysis: json['technical_analysis'] != null
          ? TechnicalAnalysis.fromJson(json['technical_analysis'] as Map<String, dynamic>)
          : null,
      riskWarning: json['risk_warning'] as String?,
    );
  }
  
  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'signal': signal,
      'reason': reason,
      'stop_loss': stopLoss,
      'take_profit': takeProfit,
      'confidence': confidence,
      'technical_analysis': technicalAnalysis?.toJson(),
      'risk_warning': riskWarning,
    };
  }
  
  /// 是否为买入信号
  bool get isBuySignal => signal == '买入';
  
  /// 是否为卖出信号
  bool get isSellSignal => signal == '卖出';
  
  /// 是否为观望信号
  bool get isHoldSignal => signal == '观望';
  
  /// 置信度等级 (1-3)
  int get confidenceLevel {
    switch (confidence) {
      case '高':
        return 3;
      case '中':
        return 2;
      case '低':
        return 1;
      default:
        return 1;
    }
  }
  
  /// 获取信号颜色
  String get signalColor {
    if (isBuySignal) return 'red';
    if (isSellSignal) return 'green';
    return 'orange';
  }
  
  /// 获取置信度颜色
  String get confidenceColor {
    switch (confidenceLevel) {
      case 3:
        return 'green';
      case 2:
        return 'orange';
      case 1:
        return 'grey';
      default:
        return 'grey';
    }
  }
}

class TechnicalAnalysis {
  /// 整体趋势
  final String overallTrend;
  
  /// 短期趋势
  final String shortTermTrend;
  
  /// RSI状态
  final String rsiStatus;
  
  /// RSI值
  final double? rsiValue;
  
  /// MACD方向
  final String macdDirection;
  
  /// 支撑位
  final double? support;
  
  /// 阻力位
  final double? resistance;
  
  /// 关键价位
  final List<double>? keyLevels;
  
  TechnicalAnalysis({
    required this.overallTrend,
    required this.shortTermTrend,
    required this.rsiStatus,
    this.rsiValue,
    required this.macdDirection,
    this.support,
    this.resistance,
    this.keyLevels,
  });
  
  /// 从JSON创建实例
  factory TechnicalAnalysis.fromJson(Map<String, dynamic> json) {
    return TechnicalAnalysis(
      overallTrend: json['overall_trend'] as String? ?? '未知',
      shortTermTrend: json['short_term_trend'] as String? ?? '未知',
      rsiStatus: json['rsi_status'] as String? ?? '中性',
      rsiValue: (json['rsi_value'] as num?)?.toDouble(),
      macdDirection: json['macd_direction'] as String? ?? '中性',
      support: (json['support'] as num?)?.toDouble(),
      resistance: (json['resistance'] as num?)?.toDouble(),
      keyLevels: (json['key_levels'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
    );
  }
  
  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'overall_trend': overallTrend,
      'short_term_trend': shortTermTrend,
      'rsi_status': rsiStatus,
      'rsi_value': rsiValue,
      'macd_direction': macdDirection,
      'support': support,
      'resistance': resistance,
      'key_levels': keyLevels,
    };
  }
}

/// 股票AI筛选结果（扩展原有模型）
class StockAIFilterResult {
  /// 股票代码
  final String code;
  
  /// 股票名称
  final String name;
  
  /// 当前价格
  final double price;
  
  /// 涨跌幅
  final double changePercent;
  
  /// AI分析结果
  final AIAnalysisResult aiAnalysis;
  
  /// 分析时间
  final DateTime analyzedAt;
  
  StockAIFilterResult({
    required this.code,
    required this.name,
    required this.price,
    required this.changePercent,
    required this.aiAnalysis,
    required this.analyzedAt,
  });
  
  /// 从JSON创建实例
  factory StockAIFilterResult.fromJson(Map<String, dynamic> json) {
    return StockAIFilterResult(
      code: json['code'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      changePercent: (json['change_percent'] as num).toDouble(),
      aiAnalysis: AIAnalysisResult.fromJson(
        json['ai_analysis'] as Map<String, dynamic>,
      ),
      analyzedAt: DateTime.parse(json['analyzed_at'] as String),
    );
  }
  
  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'price': price,
      'change_percent': changePercent,
      'ai_analysis': aiAnalysis.toJson(),
      'analyzed_at': analyzedAt.toIso8601String(),
    };
  }
  
  /// 是否为买入信号
  bool get isBuySignal => aiAnalysis.isBuySignal;
  
  /// 是否为观望信号
  bool get isHoldSignal => aiAnalysis.isHoldSignal;
  
  /// 是否为卖出信号
  bool get isSellSignal => aiAnalysis.isSellSignal;
}
