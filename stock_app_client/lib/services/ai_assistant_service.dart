import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../models/ai_config.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import '../services/ai_config_service.dart';

// 添加自定义异常类
class ApiException implements Exception {
  final String message;
  final int statusCode;
  
  ApiException(this.message, this.statusCode);
  
  @override
  String toString() => message;
}

class CustomTimeoutException implements Exception {
  final String message;
  
  CustomTimeoutException(this.message);
  
  @override
  String toString() => message;
}

class AIAssistantService {
  // 调用AI API生成交易策略
  Future<Map<String, dynamic>> generateTradingStrategy({
    required String stockType,
    required String timeFrame,
    required String riskLevel,
    String? additionalInfo,
    bool isImproveMode = false,
  }) async {
    try {
      // 获取用户配置或默认配置
      // 获取有效的AI配置
      final effectiveApiEndpoint = await AIConfigService.getEffectiveUrl();
      final effectiveApiKey = await AIConfigService.getEffectiveApiKey();
      final effectiveModel = await AIConfigService.getEffectiveModel();
      
      // 检查配置是否有效
      if (effectiveApiEndpoint == null || effectiveApiEndpoint.isEmpty ||
          effectiveApiKey == null || effectiveApiKey.isEmpty) {
        throw Exception('AI配置无效，请先配置完整的API服务地址和API密钥');
      }
          
      // 构建API请求
      final requestBody = {
        'model': effectiveModel,
        'messages': [
          {
            'role': 'system',
            'content': '''
            你是一位专业的A股投资策略专家，擅长创建符合中国市场特点的交易策略。
            ${isImproveMode ? '你需要根据用户提供的现有策略进行完善和增强，保持原有策略的核心思想，但增加更多细节和精确性。' : '请根据用户提供的参数，创建一个完整的交易策略。'}
            
            重要说明：你必须直接返回纯JSON格式的响应，不要添加任何额外的前缀（如"```json"）或后缀（如"```"）。
            不要有任何解释、前言或其他内容，只返回一个JSON对象，格式如下：
            {
              "name": "策略名称",
              "description": "策略描述",
              "entryConditions": ["入场条件1", "入场条件2", ...],
              "exitConditions": ["出场条件1", "出场条件2", ...],
              "riskControls": ["风险控制1", "风险控制2", ...]
            }
            
            确保策略符合A股市场特点，包括涨跌停限制、交易时间和交易规则等。
            '''
          },
          {
            'role': 'user',
            'content': _buildPrompt(stockType, timeFrame, riskLevel, additionalInfo, isImproveMode),
          }
        ],
        'temperature': AIConfig.temperature,
        'max_tokens': AIConfig.maxTokens,
        'top_p': AIConfig.topP,
        'top_k': AIConfig.topK,
        'min_p': AIConfig.minP,
        'frequency_penalty': AIConfig.frequencyPenalty,
      };
      
      // 为了UI体验，增加一个短暂的延迟
      await Future.delayed(const Duration(seconds: 1));
      
      // 发送API请求
      if (kDebugMode) {
        print('正在发送策略生成请求...');
      }
      
      // 添加超时处理
      final response = await http.post(
        Uri.parse(effectiveApiEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $effectiveApiKey',
        },
        body: jsonEncode(requestBody),
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw CustomTimeoutException('请求超时，请稍后再试');
        },
      );
      
      if (response.statusCode != 200) {
        if (kDebugMode) {
          print('API请求失败: ${response.statusCode}');
          print('错误内容: ${response.body}');
        }
        throw ApiException('API调用失败: ${response.statusCode}', response.statusCode);
      }
      
      // 解析响应
      final jsonResponse = jsonDecode(response.body);
      final content = jsonResponse['choices'][0]['message']['content'] as String;
      
      try {
        // 清理可能存在的前缀后缀
        String cleanedContent = content;
        
        // 移除可能的markdown代码块前缀和后缀
        final jsonBlockPattern = RegExp(r'```(?:json)?\s*([\s\S]*?)```');
        final match = jsonBlockPattern.firstMatch(cleanedContent);
        if (match != null && match.group(1) != null) {
          cleanedContent = match.group(1)!.trim();
        }
        
        // 移除任何开头的非JSON字符（如解释文字）
        final jsonStart = cleanedContent.indexOf('{');
        if (jsonStart > 0) {
          cleanedContent = cleanedContent.substring(jsonStart);
        }
        
        // 尝试解析清理后的JSON内容
        final Map<String, dynamic> strategyData = jsonDecode(cleanedContent);
        
        if (kDebugMode) {
          print('成功解析策略数据');
        }
        
        return {
          'success': true,
          'data': {
            'name': strategyData['name'] ?? '未命名策略',
            'description': strategyData['description'] ?? '无描述',
            'entryConditions': List<String>.from(strategyData['entryConditions'] ?? []),
            'exitConditions': List<String>.from(strategyData['exitConditions'] ?? []),
            'riskControls': List<String>.from(strategyData['riskControls'] ?? []),
          },
        };
      } catch (e) {
        if (kDebugMode) {
          print('解析策略数据失败: $e');
          print('原始内容: $content');
        }
        
        // API返回的不是JSON格式，使用备用方案
        return {
          'success': false,
          'error': '无法解析AI响应为有效的策略格式: $e',
        };
      }
    } catch (e) {
      // 出现异常时，使用备用预设策略
      if (kDebugMode) {
        print('生成策略时出错: $e');
      }
      
      String errorMessage = '生成策略失败';
      
      if (e is CustomTimeoutException) {
        errorMessage = '请求超时，已使用本地策略作为备用';
      } else if (e is ApiException) {
        errorMessage = 'API请求失败（状态码: ${e.statusCode}），已使用本地策略作为备用';
      } else {
        errorMessage = '处理请求时出错: ${e.toString().substring(0, math.min(100, e.toString().length))}';
      }
      
      // 发生错误时使用备用策略
      final fallbackStrategy = _generateFallbackStrategy(stockType, timeFrame, riskLevel, additionalInfo);
      return {
        'success': true,
        'data': fallbackStrategy,
        'warning': errorMessage,
      };
    }
  }
  
  String _buildPrompt(String stockType, String timeFrame, String riskLevel, String? additionalInfo, bool isImproveMode) {
    final basicInfo = '''
    ${isImproveMode ? '我希望完善一个现有的A股交易策略，使其更加完善、专业和有效' : '请为我生成一个详细的A股交易策略'}，具有以下特点：
    - 股票类型：$stockType
    - 交易时间框架：$timeFrame
    - 风险等级：$riskLevel
    ${additionalInfo != null ? '- 额外信息：$additionalInfo' : ''}
    ''';
    
    const formatInfo = '''
    我需要一个纯JSON格式的策略，不包含任何markdown格式或其他装饰，严格按照以下结构：
    {
      "name": "策略名称（简短有力）",
      "description": "策略详细描述（100-200字）",
      "entryConditions": ["入场条件1", "入场条件2", ... 至少5条],
      "exitConditions": ["出场条件1", "出场条件2", ... 至少5条],
      "riskControls": ["风险控制1", "风险控制2", ... 至少5条]
    }
    ''';
    
    final improveInfo = isImproveMode ? '''
    请注意：
    1. 在完善策略时，保留原策略的核心思想，但可以增加更多细节、补充缺失的条件
    2. 提高策略的可操作性和量化程度，如添加具体的数值指标或百分比
    3. 更新或优化可能过时或不够优化的条件
    4. 确保策略的一致性，入场、出场和风控逻辑应相互配合
    ''' : '';
    
    const noteInfo = '''
    注意：
    1. 策略需符合A股市场特点，包括涨跌停限制、交易时间、交易规则等
    2. 请确保直接返回JSON对象，不要添加任何前缀（如```json）或后缀（如```）
    3. JSON格式必须严格有效，可以直接被解析
    ''';
    
    return basicInfo + formatInfo + improveInfo + noteInfo;
  }
  
  // 备用策略生成方法，当API调用失败时使用
  Map<String, dynamic> _generateFallbackStrategy(String stockType, String timeFrame, String riskLevel, String? additionalInfo) {
    // 根据不同的股票类型和风险等级生成不同的A股策略
    if (stockType == '蓝筹股' && riskLevel == '低风险') {
      return {
        'name': 'A股蓝筹价值投资策略',
        'description': '专注于投资A股市场中具有稳定业绩、良好分红历史的大型蓝筹股，追求长期稳定的资本增值和股息收入。',
        'entryConditions': [
          '市盈率(PE)低于行业平均水平20%',
          '连续3年以上稳定或增长的现金分红',
          '近5年营收年均增长率不低于GDP增速',
          '负债率低于行业平均水平',
          '自由现金流为正且稳定',
          '股价处于60日均线以下'
        ],
        'exitConditions': [
          '公司基本面恶化（连续两个季度业绩下滑）',
          '市盈率超过行业平均50%',
          '股息率下降至历史低位',
          '管理层出现重大变动或负面新闻',
          '达到预设的目标价格（成本的30%以上）',
          '股价跌破120日均线且成交量放大'
        ],
        'riskControls': [
          '单只股票最大仓位不超过总资产的8%',
          '行业分散投资，单一行业不超过25%',
          '定期检查持仓公司财务状况（每季度）',
          '设置10%的止损点',
          '分批建仓，首次买入不超过目标仓位的30%',
          '避开业绩预告前后的高波动期'
        ]
      };
    } else if (stockType == '成长股' && riskLevel == '高风险') {
      return {
        'name': 'A股成长股动量策略',
        'description': '聚焦于A股市场中具有高成长性的中小市值公司，通过技术指标捕捉价格突破形成的短期趋势，适合风险承受能力较高的投资者。',
        'entryConditions': [
          '近两个季度营收和净利润同比增长30%以上',
          '股价突破60日均线且成交量放大50%以上',
          'MACD指标金叉形成',
          '所处行业为国家政策支持的战略新兴产业',
          '机构持股比例环比增加',
          '股价未触及涨停板（避免追高）'
        ],
        'exitConditions': [
          '股价跌破20日均线',
          'MACD指标死叉形成',
          '量能持续萎缩3个交易日',
          '季度业绩低于市场预期',
          '获利达到预期目标（20%以上）',
          '大股东或高管减持'
        ],
        'riskControls': [
          '单只股票最大仓位不超过总资产的5%',
          '设置移动止损，初始止损为入场点下方的8%',
          '单日最大亏损达到账户的3%时停止交易',
          '避开重要经济数据和政策发布时段',
          '盈亏比至少为1:2才执行交易',
          '不参与ST、*ST等问题股票交易'
        ]
      };
    } else if (stockType == '科技股' && riskLevel == '中风险') {
      return {
        'name': 'A股科技龙头轮动策略',
        'description': '在A股科技板块中，通过行业轮动和技术分析，选择处于上升通道的科技龙头股进行波段操作。',
        'entryConditions': [
          '科技板块整体表现强于大盘指数',
          '目标公司为行业龙头（市占率前三）',
          '股价突破前期高点并有效站稳',
          '北向资金持续流入该股',
          '公司有明确的技术创新或产品升级路线',
          '量价配合，放量突破'
        ],
        'exitConditions': [
          '股价连续3天收阴且成交量萎缩',
          '所属板块轮动见顶信号出现',
          '技术指标超买（KDJ、RSI等）',
          '业绩不及预期或有重大利空消息',
          '大盘出现明显顶部信号',
          '获利达到15%以上'
        ],
        'riskControls': [
          '单只股票仓位控制在总资产的6%以内',
          '科技板块总仓位不超过40%',
          '分批买入，逐步加仓',
          '设置12%的硬性止损位',
          '高位获利时设置跟踪止盈',
          '关注科创板和创业板的交易规则差异'
        ]
      };
    } else if (stockType == '通用') {
      // 通用策略 - 适合各种类型的A股投资
      return {
        'name': 'A股通用量价策略',
        'description': '采用量价分析和多重技术指标相结合的方法，适用于各种类型的A股交易，具有较好的普适性和风险控制能力。',
        'entryConditions': [
          '股价站上20日均线且量能放大',
          '5日均线与10日均线呈多头排列',
          'RSI指标在30-70区间内上升',
          '成交量比前5日平均增加20%以上',
          '股价突破重要阻力位并有效站稳',
          '没有重大利空消息或技术破位风险'
        ],
        'exitConditions': [
          '股价跌破10日均线且量能萎缩',
          'RSI指标走出超买区间并掉头向下',
          '成交量连续3日萎缩至平均水平以下',
          '获利达到预期目标（15%以上）',
          '止损触发（跌破入场价8%）',
          '大盘出现系统性风险信号'
        ],
        'riskControls': [
          '单只股票最大仓位不超过总资产的8%',
          '设置8%的动态止损位',
          '总仓位控制在80%以内',
          '分批建仓，首次买入不超过计划仓位的50%',
          '定期评估持仓股票基本面变化',
          '遵循严格的资金管理规则'
        ]
      };
    } else {
      // 默认策略 - 适合一般A股投资
      return {
        'name': 'A股均线交叉趋势策略',
        'description': '基于短期与长期均线交叉信号进行A股交易，结合成交量和市场情绪指标，适合中等风险承受能力的投资者。',
        'entryConditions': [
          '5日均线上穿20日均线',
          '成交量较前5日平均增加30%以上',
          '股价处于上升通道中',
          'KDJ指标金叉',
          '市场情绪指标（如北向资金、融资余额）向好',
          '股价未超过前期高点10%以上（避免追高）'
        ],
        'exitConditions': [
          '5日均线下穿20日均线',
          '股价跌破关键支撑位',
          'KDJ指标死叉',
          '获利达到预期目标（10%以上）',
          '持仓超过15个交易日无明显上涨',
          '大盘出现明显下跌信号'
        ],
        'riskControls': [
          '单只标的持仓不超过总资产的10%',
          '设置8%的固定止损',
          '分批建仓与减仓',
          '避开财报发布前后的高波动期',
          '每周评估策略表现并调整参数',
          '关注市场整体估值水平，高估值时降低仓位'
        ]
      };
    }
  }
  
  // 非流式方式分析交易计划
  Future<Map<String, dynamic>> analyzeTradeNonStreaming({
    required String stockCode,
    required String stockName,
    required String tradeDirection,
    required String planPrice,
    required String stopLossPrice,
    required String takeProfitPrice,
    required String profitRiskRatio,
    required String marketPhase,
    required String actualTrend,
    required String trendStrength,
    required String entryDifficulty,
    required String positionPercentage,
    required String atrValue,
    required String atrMultiple,
    required String riskPercentage,
    required String tradeReason,
    required String strategyName,
    required String strategyDescription,
    required String strategyDetails,
    required String historyData,
  }) async {
    try {
      // 获取有效的AI配置
      final effectiveUrl = await AIConfigService.getEffectiveUrl();
      final effectiveApiKey = await AIConfigService.getEffectiveApiKey();
      final effectiveModel = await AIConfigService.getEffectiveModel();
      
      // 检查配置是否有效
      if (effectiveUrl == null || effectiveUrl.isEmpty ||
          effectiveApiKey == null || effectiveApiKey.isEmpty) {
        throw Exception('AI配置无效，请在设置中配置API服务地址和密钥');
      }
          
      final apiUrl = Uri.parse(effectiveUrl);
      
      final requestBody = {
        'model': effectiveModel,
        'messages': [
          {
            'role': 'system',
            'content': '''
            你是一位专业的股票交易分析师，擅长基于系统化交易策略和技术分析方法评估交易计划的成功率。
            
            请将回复分为两个独立部分:
            1. 分析结论：面向交易者的关键结果，必须包含三个要点：
               - 交易成功率评估：必须给出准确的百分比估计，并根据以下因素综合评判:
                 * 交易方向与市场趋势的一致性
                 * 入场价格在支撑/阻力位的位置
                 * 盈亏比的合理性(应≥1.5)
                 * 止损位是否符合市场波动性(ATR倍数)
                 * 市场阶段与趋势强度的匹配度
               - 参数优化建议：精确指出用户设置中需要调整的参数，如:
                 * 止损位过紧或过松
                 * 仓位比例不合理
                 * ATR倍数设置不当
                 * 风险比例超标
               - 交易决策建议：明确告知交易者是否应该执行交易，包括:
                 * 建议执行/不执行的明确意见
                 * 如建议执行，说明关键优势和注意事项
                 * 如不建议执行，提供具体的修改方案
               
            2. 思考过程：详细的分析逻辑和计算依据
            
            专业要求：
            - 成功率评估必须基于量化交易原则，而非主观猜测
            - 如果成功率低于40%，必须明确建议不要入场
            - 如果市场趋势与用户判断不符，必须指出并根据历史数据给出正确判断
            - 使用专业术语评估交易设置(如：趋势确认度、价格结构、支撑阻力、波动率适应性等)
            - 总是以简洁的要点清单和明确的交易建议结束分析
            '''
          },
          {
            'role': 'user',
            'content': '''
              请分析以下交易计划:
              
              股票: $stockCode $stockName
              交易方向: $tradeDirection
              计划价格: $planPrice
              止损价格: $stopLossPrice
              目标价格: $takeProfitPrice
              盈亏比: $profitRiskRatio
              用户选择的市场阶段: $marketPhase
              历史数据显示的实际趋势: $actualTrend
              趋势强度: $trendStrength
              入场难度: $entryDifficulty
              仓位比例: $positionPercentage%
              ATR值: $atrValue
              ATR倍数: $atrMultiple
              风险熔断: $riskPercentage%
              交易理由: $tradeReason
              
              交易策略: $strategyName
              策略描述: $strategyDescription
              $strategyDetails
              
              $historyData
              
              请提供：
              
              【分析结论】
              1. 交易成功率评估：准确百分比表示，基于交易方向、市场阶段、盈亏比、历史数据等综合分析
              2. 参数优化建议：指出交易参数中不合理的设置，并提供调整方案
              3. 交易决策建议：明确告知是否执行交易，如建议执行需说明优势，如不建议则提供具体修改方案
              4. 交易策略改进建议：如何完善当前策略，提高胜率和稳定性
              
              【思考过程】
              详细说明分析方法和推理过程，包括技术指标计算、趋势分析方法、市场阶段判断依据等
              
              格式要求：
              - 分析结论部分必须简洁明了，突出关键信息
              - 交易建议部分必须明确，交易者能一眼看出是否应该执行交易
              - 使用简单的Markdown格式提高可读性
              - 如有不良的参数设置，务必指出并提供明确的修正建议
            '''
          }
        ],
        'temperature': 0.7,
        'max_tokens': 1024, // 增加token以获得更完整的分析
        'stream': false,
        'enable_thinking': false, // 禁用思考过程，直接输出结论
        'min_p': 0.05,
        'top_p': 0.7,
        'top_k': 50,
        'frequency_penalty': 0.5,
        'n': 1,
        'stop': [],
      };
      
      // 发送HTTP请求
      final response = await http.post(
        apiUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $effectiveApiKey',
        },
        body: jsonEncode(requestBody),
      );
      
      if (response.statusCode != 200) {
        throw Exception('API调用失败: ${response.statusCode}');
      }
      
      // 解析响应
      final jsonResponse = jsonDecode(response.body);
      
      // 提取分析结果和思考过程
      final analysisResult = jsonResponse['choices'][0]['message']['content'] as String? ?? '';
      final thinkingProcess = jsonResponse['choices'][0]['message']['reasoning_content'] as String? ?? '';
      
      return {
        'analysisResult': analysisResult,
        'thinkingProcess': thinkingProcess.isEmpty ? '模型未提供思考过程' : "## 模型思考过程\n\n$thinkingProcess",
      };
    } catch (e) {
      print('AI分析服务错误: $e');
      return {
        'analysisResult': '分析失败: $e',
        'thinkingProcess': '分析过程出错',
      };
    }
  }
  
  // 智能分析交易设置并给出成功率
  Future<Map<String, dynamic>> analyzeTradeSettings({
    required Map<String, dynamic> tradeSettings,
    required List<Map<String, dynamic>> historyData,
  }) async {
    try {
      final stockCode = tradeSettings['stockCode'] as String? ?? '未知';
      final stockName = tradeSettings['stockName'] as String? ?? '未知';
      final tradeDirection = tradeSettings['direction'] as String? ?? '未知';
      final planPrice = tradeSettings['planPrice']?.toString() ?? '未知';
      final stopLossPrice = tradeSettings['stopLossPrice']?.toString() ?? '未知';
      final takeProfitPrice = tradeSettings['takeProfitPrice']?.toString() ?? '未知';
      final profitRiskRatio = tradeSettings['profitRiskRatio']?.toString() ?? '未知';
      final marketPhase = tradeSettings['marketPhase'] as String? ?? '未知';
      final actualTrend = tradeSettings['actualTrend'] as String? ?? '未知';
      final trendStrength = tradeSettings['trendStrength'] as String? ?? '未知';
      final entryDifficulty = tradeSettings['entryDifficulty'] as String? ?? '未知';
      final positionPercentage = tradeSettings['positionPercentage']?.toString() ?? '未知';
      final atrValue = tradeSettings['atrValue']?.toString() ?? '未知';
      final atrMultiple = tradeSettings['atrMultiple']?.toString() ?? '未知';
      final riskPercentage = tradeSettings['riskPercentage']?.toString() ?? '未知';
      final tradeReason = tradeSettings['reason'] as String? ?? '未知';
      final strategyName = tradeSettings['strategyName'] as String? ?? '未知';
      final strategyDescription = tradeSettings['strategyDescription'] as String? ?? '未知';
      final strategyDetails = tradeSettings['strategyDetails'] as String? ?? '未知';
      
      final historyDataStr = historyData.isEmpty ? '无历史数据' : 
          historyData.map((item) => '日期: ${item['date']}, 开盘: ${item['open']}, 收盘: ${item['close']}, 最高: ${item['high']}, 最低: ${item['low']}, 成交量: ${item['volume']}').join('\n');
      
      // 获取有效的AI配置
      final effectiveUrl = await AIConfigService.getEffectiveUrl();
      final effectiveApiKey = await AIConfigService.getEffectiveApiKey();
      final effectiveModel = await AIConfigService.getEffectiveModel();
      
      // 检查配置是否有效
      if (effectiveUrl == null || effectiveUrl.isEmpty ||
          effectiveApiKey == null || effectiveApiKey.isEmpty) {
        throw Exception('AI配置无效，请在设置中配置API服务地址和密钥');
      }
          
      final apiUrl = Uri.parse(effectiveUrl);
      
      final requestBody = {
        'model': effectiveModel,
        'messages': [
          {
            'role': 'system',
            'content': '''
            你是一位专业的股票交易分析师，擅长基于系统化交易策略和技术分析方法评估交易计划的成功率。
            
            请将回复分为两个独立部分:
            1. 分析结论：面向交易者的关键结果，必须包含三个要点：
               - 交易成功率评估：必须给出准确的百分比估计，并根据以下因素综合评判:
                 * 交易方向与市场趋势的一致性
                 * 入场价格在支撑/阻力位的位置
                 * 盈亏比的合理性(应≥1.5)
                 * 止损位是否符合市场波动性(ATR倍数)
                 * 市场阶段与趋势强度的匹配度
               - 参数优化建议：精确指出用户设置中需要调整的参数，如:
                 * 止损位过紧或过松
                 * 仓位比例不合理
                 * ATR倍数设置不当
                 * 风险比例超标
               - 交易决策建议：明确告知交易者是否应该执行交易，包括:
                 * 建议执行/不执行的明确意见
                 * 如建议执行，说明关键优势和注意事项
                 * 如不建议执行，提供具体的修改方案
               
            2. 思考过程：详细的分析逻辑和计算依据
            
            专业要求：
            - 成功率评估必须基于量化交易原则，而非主观猜测
            - 如果成功率低于40%，必须明确建议不要入场
            - 如果市场趋势与用户判断不符，必须指出并根据历史数据给出正确判断
            - 使用专业术语评估交易设置(如：趋势确认度、价格结构、支撑阻力、波动率适应性等)
            - 总是以简洁的要点清单和明确的交易建议结束分析
            '''
          },
          {
            'role': 'user',
            'content': '''
              请分析以下交易计划:
              
              股票: $stockCode $stockName
              交易方向: $tradeDirection
              计划价格: $planPrice
              止损价格: $stopLossPrice
              目标价格: $takeProfitPrice
              盈亏比: $profitRiskRatio
              用户选择的市场阶段: $marketPhase
              历史数据显示的实际趋势: $actualTrend
              趋势强度: $trendStrength
              入场难度: $entryDifficulty
              仓位比例: $positionPercentage%
              ATR值: $atrValue
              ATR倍数: $atrMultiple
              风险熔断: $riskPercentage%
              交易理由: $tradeReason
              
              交易策略: $strategyName
              策略描述: $strategyDescription
              $strategyDetails
              
              $historyDataStr
              
              请提供：
              
              【分析结论】
              1. 交易成功率评估：准确百分比表示，基于交易方向、市场阶段、盈亏比、历史数据等综合分析
              2. 参数优化建议：指出交易参数中不合理的设置，并提供调整方案
              3. 交易决策建议：明确告知是否执行交易，如建议执行需说明优势，如不建议则提供具体修改方案
              4. 交易策略改进建议：如何完善当前策略，提高胜率和稳定性
              
              【思考过程】
              详细说明分析方法和推理过程，包括技术指标计算、趋势分析方法、市场阶段判断依据等
              
              格式要求：
              - 分析结论部分必须简洁明了，突出关键信息
              - 交易建议部分必须明确，交易者能一眼看出是否应该执行交易
              - 使用简单的Markdown格式提高可读性
              - 如有不良的参数设置，务必指出并提供明确的修正建议
            '''
          }
        ],
        'temperature': 0.7,
        'max_tokens': 1024, // 增加token以获得更完整的分析
        'stream': false,
        'enable_thinking': false, // 禁用思考过程，直接输出结论
        'min_p': 0.05,
        'top_p': 0.7,
        'top_k': 50,
        'frequency_penalty': 0.5,
        'n': 1,
        'stop': [],
      };
      
      // 发送HTTP请求
      final response = await http.post(
        apiUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $effectiveApiKey',
        },
        body: jsonEncode(requestBody),
      );
      
      if (response.statusCode != 200) {
        throw Exception('API调用失败: ${response.statusCode}');
      }
      
      // 解析响应
      final jsonResponse = jsonDecode(response.body);
      
      // 提取分析结果和思考过程
      final analysisResult = jsonResponse['choices'][0]['message']['content'] as String? ?? '';
      final thinkingProcess = jsonResponse['choices'][0]['message']['reasoning_content'] as String? ?? '';
      
      return {
        'analysisResult': analysisResult,
        'thinkingProcess': thinkingProcess.isEmpty ? '模型未提供思考过程' : "## 模型思考过程\n\n$thinkingProcess",
      };
    } catch (e) {
      print('AI分析服务错误: $e');
      return {
        'analysisResult': '分析失败: $e',
        'thinkingProcess': '分析过程出错',
      };
    }
  }
  
  // 可以在这里添加其他AI助手相关的方法
} 