/// 增强的AI筛选服务
/// 集成技术指标计算和优化的提示词
/// 返回包含"观望"和"买入"信号的结果，提供更友好的用户体验
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/technical_indicators.dart';
import 'ai_config_service.dart';

class EnhancedAIFilterService {
  /// 分析单只股票
  /// [stockCode] 股票代码
  /// [stockName] 股票名称
  /// [klineData] K线数据 [{date, open, high, low, close, volume}, ...]
  /// [filterCriteria] 可选的筛选条件（用户自然语言输入）
  /// [industry] 所属行业
  /// 返回: {signal, reason, stop_loss, take_profit, confidence, technical_analysis}
  Future<Map<String, dynamic>?> analyzeStock({
    required String stockCode,
    required String stockName,
    required List<Map<String, dynamic>> klineData,
    String? filterCriteria,
    String? industry,
  }) async {
    try {
      if (klineData.length < 60) {
        print('K线数据不足，至少需要60条');
        return null;
      }
      
      // 提取价格数据
      final closes = klineData.map((k) => (k['close'] as num).toDouble()).toList();
      final highs = klineData.map((k) => (k['high'] as num).toDouble()).toList();
      final lows = klineData.map((k) => (k['low'] as num).toDouble()).toList();
      
      // 计算技术指标
      final ema5 = TechnicalIndicators.calculateEMA(closes, 5);
      final ema10 = TechnicalIndicators.calculateEMA(closes, 10);
      final ema20 = TechnicalIndicators.calculateEMA(closes, 20);
      final ema60 = TechnicalIndicators.calculateEMA(closes, 60);
      
      final rsi = TechnicalIndicators.calculateRSI(closes);
      final macd = TechnicalIndicators.calculateMACD(closes);
      final bollinger = TechnicalIndicators.calculateBollingerBands(closes);
      
      // 获取最新指标值
      final latestIndex = closes.length - 1;
      final currentPrice = closes[latestIndex];
      final currentRSI = rsi[latestIndex];
      final currentMACD = macd['macd']![latestIndex];
      final currentSignal = macd['signal']![latestIndex];
      final currentHistogram = macd['histogram']![latestIndex];
      
      // 趋势分析
      final overallTrend = TechnicalIndicators.analyzeTrend(
        ema5[latestIndex],
        ema10[latestIndex],
        ema20[latestIndex],
        ema60[latestIndex],
      );
      
      final rsiStatus = TechnicalIndicators.analyzeRSI(currentRSI);
      final macdDirection = TechnicalIndicators.analyzeMACDSignal(
        currentMACD,
        currentSignal,
        currentHistogram,
      );
      
      // 支撑阻力位（专业版：传入收盘价，计算多个关键价位）
      final supportResistance = TechnicalIndicators.calculateSupportResistance(
        highs,
        lows,
        closes: closes,
        period: 60, // 使用60天周期，更准确地识别日线级别支撑阻力
      );
      
      // 构建技术分析文本
      final technicalText = _buildTechnicalAnalysisText(
        currentPrice: currentPrice,
        ema5: ema5[latestIndex],
        ema10: ema10[latestIndex],
        ema20: ema20[latestIndex],
        ema60: ema60[latestIndex],
        rsi: currentRSI,
        macd: currentMACD,
        signal: currentSignal,
        histogram: currentHistogram,
        bollingerUpper: bollinger['upper']![latestIndex],
        bollingerMiddle: bollinger['middle']![latestIndex],
        bollingerLower: bollinger['lower']![latestIndex],
        support: supportResistance['support']!,
        resistance: supportResistance['resistance']!,
        overallTrend: overallTrend,
        rsiStatus: rsiStatus,
        macdDirection: macdDirection,
      );
      
      // 构建K线数据文本（最近30天）
      final startIndex = klineData.length > 30 ? klineData.length - 30 : 0;
      final recentKlines = klineData.sublist(startIndex);
      final klineText = _buildKlineDataText(recentKlines);
      
      // 调用AI分析（传入筛选条件和行业信息）
      final result = await _callAIAnalysis(
        filterCriteria: filterCriteria,
        stockCode: stockCode,
        stockName: stockName,
        industry: industry,
        currentPrice: currentPrice,
        klineText: klineText,
        technicalText: technicalText,
        overallTrend: overallTrend,
        rsiValue: currentRSI ?? 50,
        rsiStatus: rsiStatus,
        macdDirection: macdDirection,
        support: supportResistance['support']!,
        resistance: supportResistance['resistance']!,
        supportResistance: supportResistance, // 传递完整的支撑阻力位数据
      );
      
      return result;
    } catch (e) {
      print('分析股票失败: $e');
      return null;
    }
  }
  
  /// 构建技术分析文本
  String _buildTechnicalAnalysisText({
    required double currentPrice,
    required double? ema5,
    required double? ema10,
    required double? ema20,
    required double? ema60,
    required double? rsi,
    required double? macd,
    required double? signal,
    required double? histogram,
    required double? bollingerUpper,
    required double? bollingerMiddle,
    required double? bollingerLower,
    required double support,
    required double resistance,
    required String overallTrend,
    required String rsiStatus,
    required String macdDirection,
  }) {
    final buffer = StringBuffer();
    
    buffer.writeln('【技术指标详情】');
    buffer.writeln('');
    
    // 均线系统
    buffer.writeln('均线系统:');
    if (ema5 != null) buffer.writeln('  EMA5: ${ema5.toStringAsFixed(2)}');
    if (ema10 != null) buffer.writeln('  EMA10: ${ema10.toStringAsFixed(2)}');
    if (ema20 != null) buffer.writeln('  EMA20: ${ema20.toStringAsFixed(2)}');
    if (ema60 != null) buffer.writeln('  EMA60: ${ema60.toStringAsFixed(2)}');
    buffer.writeln('  排列状态: ${_getTrendDescription(overallTrend)}');
    buffer.writeln('');
    
    // RSI
    buffer.writeln('RSI指标:');
    if (rsi != null) {
      buffer.writeln('  RSI(14): ${rsi.toStringAsFixed(2)}');
      buffer.writeln('  状态: ${_getRSIDescription(rsiStatus)}');
    }
    buffer.writeln('');
    
    // MACD
    buffer.writeln('MACD指标:');
    if (macd != null && signal != null) {
      buffer.writeln('  MACD: ${macd.toStringAsFixed(4)}');
      buffer.writeln('  信号线: ${signal.toStringAsFixed(4)}');
      if (histogram != null) {
        buffer.writeln('  柱状图: ${histogram.toStringAsFixed(4)}');
      }
      buffer.writeln('  方向: ${_getMACDDescription(macdDirection)}');
    }
    buffer.writeln('');
    
    // 布林带
    buffer.writeln('布林带:');
    if (bollingerUpper != null && bollingerMiddle != null && bollingerLower != null) {
      buffer.writeln('  上轨: ${bollingerUpper.toStringAsFixed(2)}');
      buffer.writeln('  中轨: ${bollingerMiddle.toStringAsFixed(2)}');
      buffer.writeln('  下轨: ${bollingerLower.toStringAsFixed(2)}');
      
      // 判断价格位置
      if (currentPrice > bollingerUpper) {
        buffer.writeln('  位置: 价格突破上轨，可能超买');
      } else if (currentPrice < bollingerLower) {
        buffer.writeln('  位置: 价格跌破下轨，可能超卖');
      } else {
        buffer.writeln('  位置: 价格在布林带内');
      }
    }
    buffer.writeln('');
    
    // 支撑阻力
    buffer.writeln('关键价位:');
    buffer.writeln('  支撑位: ${support.toStringAsFixed(2)}');
    buffer.writeln('  阻力位: ${resistance.toStringAsFixed(2)}');
    buffer.writeln('  当前价: ${currentPrice.toStringAsFixed(2)}');
    
    return buffer.toString();
  }
  
  /// 构建K线数据文本
  String _buildKlineDataText(List<Map<String, dynamic>> klines) {
    final buffer = StringBuffer();
    buffer.writeln('【近期K线数据】(最近30个交易日)');
    buffer.writeln('');
    buffer.writeln('**重要提示**: 下面的数据第一行是最新日期，越往下越旧。请重点分析最近几天的走势！');
    buffer.writeln('');
    
    // 反转顺序，让最新的在前面
    final reversedKlines = klines.reversed.toList();
    
    for (var i = 0; i < reversedKlines.length; i++) {
      final kline = reversedKlines[i];
      final date = kline['date'];
      final open = (kline['open'] as num).toDouble();
      final high = (kline['high'] as num).toDouble();
      final low = (kline['low'] as num).toDouble();
      final close = (kline['close'] as num).toDouble();
      final volume = (kline['volume'] as num).toDouble();
      
      final change = ((close - open) / open * 100).toStringAsFixed(2);
      
      // 标注最近的几天
      String prefix = '';
      if (i == 0) prefix = '【最新】';
      else if (i == 1) prefix = '【前一天】';
      else if (i == 2) prefix = '【前两天】';
      
      buffer.writeln('$prefix$date: 开${open.toStringAsFixed(2)} '
          '高${high.toStringAsFixed(2)} 低${low.toStringAsFixed(2)} '
          '收${close.toStringAsFixed(2)} 涨跌$change% '
          '量${(volume / 10000).toStringAsFixed(0)}万');
    }
    
    return buffer.toString();
  }
  
  /// 调用AI分析
  Future<Map<String, dynamic>?> _callAIAnalysis({
    String? filterCriteria,
    required String stockCode,
    required String stockName,
    String? industry,
    required double currentPrice,
    required String klineText,
    required String technicalText,
    required String overallTrend,
    required double rsiValue,
    required String rsiStatus,
    required String macdDirection,
    required double support,
    required double resistance,
    required Map<String, double> supportResistance, // 添加完整的支撑阻力位参数
  }) async {
    // 加载AI配置
    final config = await AIConfigService.loadConfig();
    
    // 检查配置是否有效
    final apiUrl = config.customUrl;
    final apiKey = config.apiKey;
    final model = config.model;
    
    if (apiUrl == null || apiUrl.isEmpty || apiKey == null || apiKey.isEmpty) {
      throw Exception('AI配置未设置或不完整');
    }
    
    // 构建优化的提示词（包含筛选条件和行业信息）
    final prompt = _buildPrompt(
      filterCriteria: filterCriteria,
      stockCode: stockCode,
      stockName: stockName,
      industry: industry,
      currentPrice: currentPrice,
      klineText: klineText,
      technicalText: technicalText,
      overallTrend: overallTrend,
      rsiValue: rsiValue,
      rsiStatus: rsiStatus,
      macdDirection: macdDirection,
      support: support,
      resistance: resistance,
      supportResistance: supportResistance, // 传递完整的支撑阻力位数据
    );
    
    // 调用AI API
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': model ?? 'gpt-3.5-turbo',
          'messages': [
            {'role': 'system', 'content': '你是一个专业的A股交易分析师。'},
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.7,
          'max_tokens': 1000,
          'stream': false,  // 关闭流式输出，加快响应速度
          'reasoning_effort': 'low',  // 降低推理强度，加快响应速度（适用于o1系列模型）
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final content = data['choices'][0]['message']['content'];
        
        // 解析JSON响应
        final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(content);
        if (jsonMatch != null) {
          final jsonStr = jsonMatch.group(0)!;
          final resultJson = jsonDecode(jsonStr) as Map<String, dynamic>;
          
          // 确保支撑阻力位数据存在（如果AI没有返回，则使用计算的值）
          if (!resultJson.containsKey('support') || resultJson['support'] == null) {
            resultJson['support'] = support;
          }
          if (!resultJson.containsKey('resistance') || resultJson['resistance'] == null) {
            resultJson['resistance'] = resistance;
          }
          
          // 如果没有盈亏比，尝试计算（修复计算逻辑）
          if (!resultJson.containsKey('risk_reward_ratio') || resultJson['risk_reward_ratio'] == null) {
            final stopLoss = resultJson['stop_loss'];
            final takeProfit = resultJson['take_profit'];
            if (stopLoss != null && takeProfit != null) {
              // 修复：确保stopLoss和takeProfit是数字类型
              final stopLossPrice = (stopLoss is num) ? stopLoss.toDouble() : double.tryParse(stopLoss.toString()) ?? 0;
              final takeProfitPrice = (takeProfit is num) ? takeProfit.toDouble() : double.tryParse(takeProfit.toString()) ?? 0;
              
              // 计算风险和收益（绝对值）
              final risk = ((currentPrice - stopLossPrice) / currentPrice * 100).abs();
              final reward = ((takeProfitPrice - currentPrice) / currentPrice * 100).abs();
              
              if (risk > 0) {
                final ratio = (reward / risk).toStringAsFixed(1);
                resultJson['risk_reward_ratio'] = '$ratio:1';
                
                // 调试日志
                debugPrint('📊 盈亏比计算: 当前价=$currentPrice, 止损=$stopLossPrice, 目标=$takeProfitPrice');
                debugPrint('   风险=${risk.toStringAsFixed(2)}%, 收益=${reward.toStringAsFixed(2)}%, 盈亏比=$ratio:1');
              }
            }
          }
          
          return resultJson;
        }
      }
      
      return null;
    } catch (e) {
      print('AI分析失败: $e');
      return null;
    }
  }
  
  /// 构建优化的提示词
  String _buildPrompt({
    String? filterCriteria,
    required String stockCode,
    required String stockName,
    String? industry,
    required double currentPrice,
    required String klineText,
    required String technicalText,
    required String overallTrend,
    required double rsiValue,
    required String rsiStatus,
    required String macdDirection,
    required double support,
    required double resistance,
    required Map<String, double> supportResistance, // 添加完整的支撑阻力位参数
  }) {
    // 构建筛选条件部分
    final filterSection = filterCriteria != null && filterCriteria.isNotEmpty
        ? '''
【用户筛选条件】
$filterCriteria

⚠️ **重要提示**：
- 请仔细检查该股票是否符合用户的筛选条件
- 如果筛选条件中提到了行业要求，请务必对比【股票信息】中的"所属行业"字段
- 如果筛选条件中提到了特定行业（如"半导体"、"新能源"等），而该股票不属于该行业，则应给出"观望"或"卖出"信号
- 技术面分析和筛选条件匹配度同等重要

评判标准：
- 技术面良好 + 完全符合筛选条件（包括行业匹配） → 买入信号
- 技术面一般 或 部分符合筛选条件 或 行业不完全匹配 → 观望信号
- 技术面较差 或 明显不符合筛选条件 或 行业完全不匹配 → 卖出信号

'''
        : '';
    
    // 获取当前日期
    final now = DateTime.now();
    final currentDate = '${now.year}年${now.month}月${now.day}日';
    
    return '''
你是一个专业的A股交易分析师，现在是$currentDate。请基于以下日线周期数据进行分析：

🚨 **极其重要的时间说明**：
1. **当前日期是 $currentDate（今天）**
2. **下面的K线数据是按时间倒序排列的：**
   - **标记【最新】的是最近的交易日（今天或最近一个交易日）**
   - **越往下越旧，最后一条是30个交易日之前的数据**
   - **请务必重点分析标记【最新】【前一天】【前两天】的数据！**
3. **短线分析重点**：
   - 散户最关心1-3天的短线机会
   - **请重点分析最近3-5个交易日的价格和成交量变化**
   - **不要把30天前的旧数据当作最新数据！**

【股票信息】
代码: $stockCode
名称: $stockName
${industry != null && industry.isNotEmpty ? '🏢 所属行业: $industry ⬅️ 如果用户筛选条件中提到行业，请务必检查此字段是否匹配！\n' : ''}当前价格: ¥${currentPrice.toStringAsFixed(2)}

$klineText

$technicalText

【当前技术状况分析】
- 整体趋势: ${_getTrendDescription(overallTrend)}
- RSI状态: ${rsiValue.toStringAsFixed(1)} (${_getRSIDescription(rsiStatus)})
- MACD方向: ${_getMACDDescription(macdDirection)}

📍 **关键价位分析（基于真实计算，不可编造）**：
当前价：¥${currentPrice.toStringAsFixed(2)}

🔴 阻力位（由近到远）：
  第1阻力：¥${resistance.toStringAsFixed(2)} (+${((resistance - currentPrice) / currentPrice * 100).toStringAsFixed(2)}%)
  第2阻力：¥${(resistance * 1.05).toStringAsFixed(2)} (+${((resistance * 1.05 - currentPrice) / currentPrice * 100).toStringAsFixed(2)}%)
  第3阻力：¥${(resistance * 1.10).toStringAsFixed(2)} (+${((resistance * 1.10 - currentPrice) / currentPrice * 100).toStringAsFixed(2)}%)

🟢 支撑位（由近到远）：
  第1支撑：¥${support.toStringAsFixed(2)} (${((support - currentPrice) / currentPrice * 100).toStringAsFixed(2)}%)
  第2支撑：¥${(support * 0.95).toStringAsFixed(2)} (${((support * 0.95 - currentPrice) / currentPrice * 100).toStringAsFixed(2)}%)
  第3支撑：¥${(support * 0.90).toStringAsFixed(2)} (${((support * 0.90 - currentPrice) / currentPrice * 100).toStringAsFixed(2)}%)

$filterSection【交易指导原则】
1. **技术分析主导** (权重70%)：趋势、支撑阻力、K线形态是主要依据
2. **风险管理** (权重30%)：考虑止损位置和盈亏比
3. **信号明确性**:
   - 强势上涨趋势 + 多个指标确认 ${filterCriteria != null && filterCriteria.isNotEmpty ? '+ 符合筛选条件' : ''} → 买入信号
   - 震荡整理、技术面不明确 ${filterCriteria != null && filterCriteria.isNotEmpty ? '或部分符合筛选条件' : ''} → 观望信号
   - 明显下跌趋势 ${filterCriteria != null && filterCriteria.isNotEmpty ? '或不符合筛选条件' : ''} → 卖出信号（但A股做多为主，可以观望）
4. **技术指标权重**: 趋势(均线排列) > RSI > MACD > 布林带

🚨 **盈亏比硬性要求（极其重要）**：
- **止损价设置原则（必须严格遵守）**：
  * ⚠️ **止损幅度必须控制在3-8%之间，绝对不能超过10%！**
  * **⚠️ 止损价必须从上述计算的支撑位中选择，禁止随意编造价格！**
  * 选择逻辑：
    - 优先使用第1支撑位（如果距离在3-8%之间）
    - 如果第1支撑位距离>8%，使用第2支撑位或当前价×0.95
    - 如果第1支撑位距离<3%，使用第2支撑位
  * 例如：当前价¥100.00，第1支撑¥95.00(-5%)，止损价应设为¥95.00或略低（¥94.00）
  
- **目标价设置原则**：
  * **⚠️ 目标价必须从上述计算的阻力位中选择，禁止随意编造价格！**
  * 选择逻辑：
    - 优先使用第1阻力位（如果距离在5-15%之间）
    - 如果第1阻力位太近（<3%），选择第2阻力位
    - 如果第1阻力位太远（>20%），使用第2阻力位或当前价×1.10
  * 必须确保盈利空间至少是止损空间的2倍
  
- **盈亏比计算与验证**：
  * 风险空间 = (当前价 - 止损价) / 当前价 × 100%
  * 盈利空间 = (目标价 - 当前价) / 当前价 × 100%
  * 盈亏比 = 盈利空间 / 风险空间
  * **⚠️ 风险空间必须≤8%，否则必须调整止损价！**
  * **必须确保盈亏比 ≥ 2:1，否则给出观望信号！**
  
- **专业示例（正确）**：
  * 当前价：¥0.80
  * 第1支撑：¥0.79（-1.25%）或¥0.77（-3.75%）
  * 第1阻力：¥0.81（+1.25%）或¥0.85（+6.25%）
  * **止损价必须选择：¥0.79、¥0.77或¥0.76（距离3-8%的支撑位）**
  * **目标价必须选择：¥0.81、¥0.85或¥0.88（能保证盈亏比≥2的阻力位）**
  * 盈亏比验证：如果止损¥0.76（-5%），目标¥0.88（+10%），盈亏比=10%/5%=2:1 ✅

- **错误示例（必须避免）**：
  * 当前价：¥0.80
  * 第1支撑：¥0.70（-12.5%）❌ 距离太远！
  * ❌ **禁止**设置止损价为¥0.70！
  * ✅ **正确**做法：忽略这个支撑位，使用第2支撑或当前价×0.95
  * ❌ **禁止**随意编造如¥0.79、¥0.62等不在支撑阻力位上的价格！
  * ✅ **必须**从计算出的支撑阻力位列表中选择！

【分析要求】
🚨 **再次强调时间重点**：
- 今天是 $currentDate
- 请重点分析**标记【最新】【前一天】【前两天】的K线数据**
- **这些是最近几天的数据，是短线分析的关键！**
- **不要分析30天前的旧数据，那些对短线交易没有意义！**

基于以上分析${filterCriteria != null && filterCriteria.isNotEmpty ? '和用户筛选条件' : ''}，请给出明确的交易信号。注意：
- 买入信号必须有明确的技术支撑${filterCriteria != null && filterCriteria.isNotEmpty ? '且完全符合筛选条件（特别是行业要求）' : ''}
- 观望信号用于技术面不明确或震荡整理的情况${filterCriteria != null && filterCriteria.isNotEmpty ? '，或部分符合筛选条件，或行业不完全匹配' : ''}
- ${filterCriteria != null && filterCriteria.isNotEmpty ? '如果用户筛选条件明确提到行业（如"半导体"、"新能源"等），而该股票行业不匹配，必须给出观望或卖出信号\n- ' : ''}
- **🚨🚨🚨 止损价和目标价必须严格从上述列出的支撑阻力位中选择！**
- **🚨🚨🚨 绝对禁止随意编造价格，必须使用：**
  * 止损价候选：第1支撑${support.toStringAsFixed(2)}、第2支撑${(support * 0.98).toStringAsFixed(2)}、或当前价×0.95
  * 目标价候选：第1阻力${resistance.toStringAsFixed(2)}、第2阻力${(resistance * 1.05).toStringAsFixed(2)}、或当前价×1.10
- **必须先计算盈亏比，如果<2:1，必须调整价格或改为观望信号！**
- 置信度基于多个指标的一致性${filterCriteria != null && filterCriteria.isNotEmpty ? '和筛选条件的匹配度（包括行业匹配）' : ''}
- 理由要简洁明了，50-100字，突出核心逻辑${filterCriteria != null && filterCriteria.isNotEmpty ? '和筛选条件匹配情况（如果行业不匹配，必须在理由中说明）' : ''}
- **所有分析必须基于最近几天（标记【最新】）的数据，而不是30天前的旧数据！**

请用以下JSON格式回复（只返回JSON，不要有其他文字）：
{
  "signal": "买入|观望|卖出",
  "reason": "简要分析理由(50-100字)",
  "stop_loss": 具体价格数字,
  "take_profit": 具体价格数字,
  "confidence": "高|中|低",
  "support": ${support.toStringAsFixed(2)},
  "resistance": ${resistance.toStringAsFixed(2)},
  "risk_reward_ratio": "盈亏比（如2.5:1或2.5）",
  "current_price": $currentPrice,
  "stop_loss_pct": "止损百分比（如-5.0）",
  "take_profit_pct": "止盈百分比（如+10.0）"
}

重要提示：
1. signal字段必须是"买入"、"观望"或"卖出"之一
2. reason要简洁，突出核心技术逻辑
3. stop_loss和take_profit必须是数字，不能为null
4. support和resistance必须使用上面提供的支撑阻力位数值（${support.toStringAsFixed(2)}和${resistance.toStringAsFixed(2)}）
5. risk_reward_ratio必须计算并填写实际的盈亏比（格式如"2.5:1"或"2.5"）
6. 即使是观望信号，也要给出合理的止损价和目标价供参考
7. **🚨 最重要：止损价和目标价必须基于上述计算的支撑阻力位！**
8. **禁止随意编造价格，必须从提供的支撑阻力位中选择！**
9. **先计算盈亏比，如果<2:1，必须调整价格或改为观望信号！**
10. **止损幅度通常3-8%，目标盈利必须≥止损的2倍**
11. **🚨 必须计算百分比：**
    - stop_loss_pct = (stop_loss - current_price) / current_price × 100
    - take_profit_pct = (take_profit - current_price) / current_price × 100
    - 格式如："-5.2"表示-5.2%，"+10.5"表示+10.5%
    - 确保百分比计算准确，小数点后保留1位

📌 **价格选择参考（必须遵守）**：
- **止损价选择（风险控制优先）**：
  * 第1步：检查第1支撑位距离当前价的百分比
  * 如果距离≤8%：可以使用第1支撑位或其下方2-3%
  * 如果距离>8%：❌ 不使用支撑位，改用当前价下方5-8%
  * 最终止损幅度必须在3-8%之间
  
- **目标价选择**：
  * 优先：第1阻力位（如果距离在5-15%之间）
  * 备选：第2阻力位（如果第1阻力太近）
  * 保底：当前价上方10-15%（如果阻力位太远）
  
- **⚠️ 核心原则**：
  * 止损幅度 3-8%（绝对不超过10%）
  * 盈亏比 ≥ 2:1
  * 如果无法同时满足，给出"观望"信号
''';
  }
  
  String _getTrendDescription(String trend) {
    switch (trend) {
      case 'strong_up':
        return '强势上涨(多头排列)';
      case 'up':
        return '上涨趋势';
      case 'neutral':
        return '震荡整理';
      case 'down':
        return '下跌趋势';
      case 'strong_down':
        return '强势下跌(空头排列)';
      default:
        return '未知';
    }
  }
  
  String _getRSIDescription(String status) {
    switch (status) {
      case 'overbought':
        return '超买';
      case 'oversold':
        return '超卖';
      case 'neutral':
        return '中性';
      default:
        return '未知';
    }
  }
  
  String _getMACDDescription(String direction) {
    switch (direction) {
      case 'bullish':
        return '金叉(看涨)';
      case 'bearish':
        return '死叉(看跌)';
      case 'neutral':
        return '中性';
      default:
        return '未知';
    }
  }
}
