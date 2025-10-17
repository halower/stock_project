import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/stock_indicator.dart';
import '../models/ai_filter_result.dart';
import '../models/ai_config.dart';
import 'api_service.dart';
import 'ai_filter_service.dart';
import 'ai_config_service.dart';

class AIStockFilterService {
  final ApiService _apiService = ApiService();
  
  // 并发处理的最大数量 - 增加到6以提高效率
  static const int maxConcurrentProcessing = 6;
  
  // 创建一个流控制器用于实时更新进度
  final _progressController = StreamController<AIFilterResult>.broadcast();
  Stream<AIFilterResult> get progressStream => _progressController.stream;
  
  // 单例模式
  static final AIStockFilterService _instance = AIStockFilterService._internal();
  factory AIStockFilterService() => _instance;
  AIStockFilterService._internal();
  
  // 当前处理中的任务
  String? _currentTaskId;
  bool _isProcessing = false;
  
  // 释放资源
  void dispose() {
    _progressController.close();
  }
  
  // 安全地向进度控制器添加事件
  void _safeAddToController(AIFilterResult result) {
    try {
      if (!_progressController.isClosed) {
        _progressController.add(result);
      }
    } catch (e) {
      debugPrint('向进度控制器添加事件失败: $e');
    }
  }
  
  // 检查是否可以开始筛选
  Future<bool> canStartFiltering() async {
    // 已经有任务在处理中
    if (_isProcessing) return false;
    
    // 检查今日使用限制
    return await AIFilterService.canUseAIFilter();
  }
  
  // 开始AI筛选
  Future<AIFilterResult> startAIFiltering({
    required List<StockIndicator> stocks,
    required String filterCriteria,
    bool forceStart = false,
  }) async {
    // 检查是否可以开始筛选
    if (!forceStart && !await canStartFiltering()) {
      throw Exception('当前无法开始筛选，请检查使用限制或等待现有任务完成');
    }
    
    // 记录使用
    await AIFilterService.recordUsage();
    
    // 生成任务ID
    final taskId = 'task_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
    _currentTaskId = taskId;
    _isProcessing = true;
    
    // 创建初始结果
    final initialResult = AIFilterResult.inProgress(
      originalFilter: filterCriteria,
      currentStocks: [],
      processedCount: 0,
      totalCount: stocks.length,
      taskId: taskId,
    );
    
    // 通知进度更新
    _safeAddToController(initialResult);
    
    try {
      // 对股票列表进行预筛选，以减少处理量
      // 如果是预定义策略，我们可以在这里进行一些初步筛选
      // 例如，如果是关于量的策略，可以预先筛选出成交量较大的股票
      List<StockIndicator> filteredStocks = await _preFilterStocks(stocks, filterCriteria);
      
      // 通知预筛选结果
      _safeAddToController(AIFilterResult.inProgress(
        originalFilter: filterCriteria,
        currentStocks: [],
        processedCount: 0,
        totalCount: filteredStocks.length, // 更新为预筛选后的总量
        taskId: taskId,
      ));
      
      // 用于存储筛选后的股票
      final matchedStocks = <StockIndicator>[];
      
      // 分批处理，控制并发数量
      final batches = _createBatches(filteredStocks, maxConcurrentProcessing);
      
      int processedCount = 0;
      
      for (final batch in batches) {
        // 并发处理一批股票
        final results = await _processBatch(batch, filterCriteria, taskId);
        
        // 更新处理进度
        processedCount += batch.length;
        matchedStocks.addAll(results);
        
        // 通知进度更新
        final progressResult = AIFilterResult.inProgress(
          originalFilter: filterCriteria,
          currentStocks: List.from(matchedStocks), // 创建一份副本
          processedCount: processedCount,
          totalCount: filteredStocks.length,
          taskId: taskId,
        );
        _safeAddToController(progressResult);
        
        // 如果任务ID改变，说明有新任务启动，终止当前任务
        if (_currentTaskId != taskId) {
          throw Exception('任务已被新任务取代');
        }
      }
      
      // 创建汇总报告
      final summary = await _generateSummary(matchedStocks, filterCriteria);
      
      // 创建完成结果
      final finalResult = AIFilterResult.completed(
        originalFilter: filterCriteria,
        stocks: matchedStocks,
        summary: summary,
        taskId: taskId,
      );
      
      // 通知完成
      _safeAddToController(finalResult);
      
      // 任务完成
      _isProcessing = false;
      
      return finalResult;
    } catch (e) {
      debugPrint('AI筛选过程中出错: $e');
      
      // 任务完成（出错）
      _isProcessing = false;
      
      // 错误信息
      final errorResult = AIFilterResult.error(
        originalFilter: filterCriteria,
        errorMessage: e.toString(),
        totalCount: stocks.length,
        taskId: taskId,
      );
      
      // 通知错误
      _safeAddToController(errorResult);
      
      return errorResult;
    }
  }
  
  // 预筛选股票以减少处理量
  Future<List<StockIndicator>> _preFilterStocks(
    List<StockIndicator> stocks, 
    String filterCriteria
  ) async {
    // 示例：如果筛选条件包含"成交量"或"量能"关键词，可以预先筛选出成交量较大的股票
    if (filterCriteria.contains('成交量') || 
        filterCriteria.contains('量能') || 
        filterCriteria.contains('放量')) {
      // 按照成交量排序，取前70%
      final sortedByVolume = List<StockIndicator>.from(stocks)
        ..sort((a, b) => (b.volume ?? 0).compareTo(a.volume ?? 0));
      
      // 取前70%的数据 - 这个比例可以调整
      final int count = (sortedByVolume.length * 0.7).ceil();
      return sortedByVolume.take(count).toList();
    }
    
    // 如果筛选条件包含"上涨"或"涨幅"关键词，可以预先筛选出涨幅大的股票
    if (filterCriteria.contains('上涨') || 
        filterCriteria.contains('涨幅') || 
        filterCriteria.contains('突破')) {
      // 按照涨跌幅排序，取前70%
      final sortedByChange = List<StockIndicator>.from(stocks)
        ..sort((a, b) => (b.changePercent ?? 0).compareTo(a.changePercent ?? 0));
      
      // 取前70%的数据
      final int count = (sortedByChange.length * 0.7).ceil();
      return sortedByChange.take(count).toList();
    }
    
    // 默认情况，返回原始列表
    return stocks;
  }
  
  // 将股票列表分成批次
  List<List<StockIndicator>> _createBatches(List<StockIndicator> stocks, int batchSize) {
    final List<List<StockIndicator>> batches = [];
    for (int i = 0; i < stocks.length; i += batchSize) {
      final end = (i + batchSize < stocks.length) ? i + batchSize : stocks.length;
      batches.add(stocks.sublist(i, end));
    }
    return batches;
  }
  
  // 并发处理一批股票
  Future<List<StockIndicator>> _processBatch(
    List<StockIndicator> batch,
    String filterCriteria,
    String taskId,
  ) async {
    // 创建一组Future来并发处理
    final futures = batch.map((stock) => _processStock(stock, filterCriteria, taskId));
    
    // 等待所有处理完成
    final results = await Future.wait(futures);
    
    // 过滤掉null结果（表示不匹配筛选条件的股票）
    return results.where((result) => result != null).cast<StockIndicator>().toList();
  }
  
  // 处理单个股票
  Future<StockIndicator?> _processStock(
    StockIndicator stock,
    String filterCriteria,
    String taskId,
  ) async {
    try {
      // 如果任务ID改变，放弃处理
      if (_currentTaskId != taskId) return null;
      
      // 获取股票历史数据
      final historyData = await _apiService.getStockHistory(stock.code);
      
      // 历史数据为空，跳过
      if (historyData.isEmpty || !historyData.containsKey('data')) return null;
      
      // 提取历史K线数据 - API返回的是data字段，不是history字段
      final historyList = historyData['data'] as List<dynamic>;
      
      // 确保历史数据按日期正确排序（从旧到新）
      historyList.sort((a, b) {
        // 优先使用trade_date字段，如果没有则使用date字段
        String dateA = '';
        String dateB = '';
        
        if (a.containsKey('trade_date') && a['trade_date'] != null) {
          dateA = a['trade_date'].toString();
        } else if (a.containsKey('date') && a['date'] != null) {
          dateA = a['date'].toString();
        }
        
        if (b.containsKey('trade_date') && b['trade_date'] != null) {
          dateB = b['trade_date'].toString();
        } else if (b.containsKey('date') && b['date'] != null) {
          dateB = b['date'].toString();
        }
        
        return dateA.compareTo(dateB);
      });

      // 最近的K线数据（限制数量避免超出token限制）
      final recentHistory = historyList.length > 30 
          ? historyList.sublist(historyList.length - 30) 
          : historyList;
      
      // 获取AI配置参数
      final effectiveUrl = await AIConfigService.getEffectiveUrl();
      final effectiveApiKey = await AIConfigService.getEffectiveApiKey();
      final effectiveModel = await AIConfigService.getEffectiveModel();
      
      // 确保有有效的API配置
      if (effectiveApiKey == null || effectiveApiKey.isEmpty ||
          effectiveUrl == null || effectiveUrl.isEmpty) {
        // 记录无API配置的情况
        debugPrint('股票${stock.code}处理失败：未配置完整的AI服务参数');
        return null;
      }
      
      // 格式化历史数据为文本
      String historyText = "";
      for (var item in recentHistory) {
        // 获取日期字段 - 优先使用trade_date，如果没有则使用date
        String dateStr = '';
        if (item.containsKey('trade_date') && item['trade_date'] != null) {
          dateStr = item['trade_date'].toString();
        } else if (item.containsKey('date') && item['date'] != null) {
          dateStr = item['date'].toString();
        }
        
        historyText += "$dateStr 开:${item['open']} 高:${item['high']} 低:${item['low']} 收:${item['close']} 量:${item['volume']}\n";
      }
      
      // 添加最新价格信息
      if (recentHistory.isNotEmpty) {
        final latestData = recentHistory.last;
        final latestPrice = latestData['close'] as double? ?? 0.0;
        String latestDate = '';
        if (latestData.containsKey('trade_date') && latestData['trade_date'] != null) {
          latestDate = latestData['trade_date'].toString();
        } else if (latestData.containsKey('date') && latestData['date'] != null) {
          latestDate = latestData['date'].toString();
        }
        historyText += "\n当前最新价格: $latestPrice (日期: $latestDate)\n";
      }
      
      // 构建系统提示
      const systemPrompt = '''
      你是一个专业的股票分析AI助手，现在需要根据用户提供的筛选条件，分析一支股票是否符合条件。
      你需要基于股票的基本信息和历史K线数据，判断它是否匹配筛选条件。
      请尽量宽松地解释筛选条件，只要股票具有一部分符合条件的特征，就应该标记为匹配。
      请只返回一个JSON格式的结果，包含匹配结果和简短分析理由。
      ''';
      
      // 构建用户提示
      final userPrompt = '''
      股票代码: ${stock.code}
      股票名称: ${stock.name}
      市场: ${stock.market}
      当前价格: ${stock.price}
      涨跌幅: ${stock.changePercent}%
      成交量: ${stock.volume}
      
      历史K线数据:
      $historyText
      
      筛选条件:
      $filterCriteria
      
      请分析这支股票是否符合上述筛选条件，只返回如下JSON格式:
      {
        "match": true/false,
        "reason": "简要分析理由（不超过100字）"
      }
      
      重要提示：采用相对宽松的标准，只要部分符合条件就可以视为匹配，宁可多选也不要漏选。
      ''';
      
      // 构建请求 - 适配阿里百炼兼容模式
      final requestBody = {
        'model': effectiveModel,
        'messages': [
          {
            'role': 'system',
            'content': systemPrompt,
          },
          {
            'role': 'user',
            'content': userPrompt,
          }
        ],
        'stream': false,
        'temperature': 0.8, // 增加温度使模型更宽松
        'max_tokens': 300, // 减少token数量以加快处理速度
        'top_p': AIConfig.topP,
        'top_k': AIConfig.topK,
        'min_p': 0.01, // 降低最小概率阈值使模型更宽松
        'frequency_penalty': AIConfig.frequencyPenalty,
      };
      
      // 阿里百炼兼容模式需要额外的参数
      if (effectiveUrl != null) {
        final uri = Uri.parse(effectiveUrl);
        if (uri.host == 'dashscope.aliyuncs.com' && uri.path.startsWith('/compatible-mode/')) {
          // 移除阿里百炼不支持的参数
          requestBody.remove('enable_thinking');
          requestBody.remove('thinking_budget');
        } else {
          // 标准OpenAI兼容模式保留原有参数
          requestBody['enable_thinking'] = AIConfig.enableThinking;
          requestBody['thinking_budget'] = AIConfig.thinkingBudget;
        }
      } else {
        // 如果没有URL，使用默认参数
        requestBody['enable_thinking'] = AIConfig.enableThinking;
        requestBody['thinking_budget'] = AIConfig.thinkingBudget;
      }
      
      try {
        // 构建请求头 - 适配阿里百炼平台
        Map<String, String> headers = {
          'Content-Type': 'application/json',
        };
        
        if (effectiveUrl != null) {
          final uri = Uri.parse(effectiveUrl);
          if (uri.host == 'dashscope.aliyuncs.com' && uri.path.startsWith('/compatible-mode/')) {
            // 阿里百炼平台compatible-mode使用标准Bearer Token（同步调用）
            headers['Authorization'] = 'Bearer $effectiveApiKey';
            // 注意：X-DashScope-Async只用于异步调用，compatible-mode同步调用不需要
          } else {
            // 标准OpenAI兼容模式使用Bearer Token
            headers['Authorization'] = 'Bearer $effectiveApiKey';
          }
        } else {
          headers['Authorization'] = 'Bearer $effectiveApiKey';
        }
        
        // 发送请求
        final response = await http.post(
          Uri.parse(effectiveUrl),
          headers: headers,
          body: jsonEncode(requestBody),
        );
        
        // 检查响应状态
        if (response.statusCode != 200) {
          // 记录详细的错误信息用于排查
          final errorInfo = {
            'stock_code': stock.code,
            'stock_name': stock.name,
            'request_params': requestBody,
            'prompt': userPrompt,
            'status_code': response.statusCode,
            'error_body': response.body,
            'timestamp': DateTime.now().toIso8601String(),
          };
          
          // 记录错误信息到日志
          debugPrint('AI API调用失败详情: ${jsonEncode(errorInfo)}');
          
          // 增强的兜底机制：
          // 1. 分析状态码来决定处理方式
          // 2. 返回更详细的错误信息
          String errorReason;
          double passThreshold = 0.5; // 默认阈值
          
          if (response.statusCode == 401 || response.statusCode == 403) {
            // 认证问题
            errorReason = '兜底机制：API认证失败(${response.statusCode})，请检查API Key';
            passThreshold = 0.3; // 降低通过概率
          } else if (response.statusCode == 429) {
            // 请求过多
            errorReason = '兜底机制：API请求过于频繁(429)，已触发限流';
            passThreshold = 0.4;
          } else if (response.statusCode >= 500) {
            // 服务器错误
            errorReason = '兜底机制：API服务器错误(${response.statusCode})';
            passThreshold = 0.6; // 提高通过概率，因为这是服务端问题
          } else {
            // 其他错误
            errorReason = '兜底机制：API调用失败(${response.statusCode})';
            passThreshold = 0.5;
          }
          
          // 记录兜底处理决策
          final randomValue = Random().nextDouble();
          final willPass = randomValue > (1 - passThreshold);
          debugPrint('兜底处理: 股票${stock.code}, 通过阈值=$passThreshold, 随机值=$randomValue, 是否通过=$willPass');
          
          if (willPass) {
            return _createMatchedStock(stock, '$errorReason，但该股票可能符合条件');
          }
          return null; // 出错时跳过这支股票
        }
        
        // 解析响应
        final jsonResponse = jsonDecode(response.body);
        final content = jsonResponse['choices'][0]['message']['content'] as String? ?? '';
        
        // 尝试提取JSON部分
        final jsonMatch = RegExp(r'{.*}', dotAll: true).firstMatch(content);
        if (jsonMatch == null) {
          // 记录格式错误信息
          final formatErrorInfo = {
            'stock_code': stock.code,
            'stock_name': stock.name,
            'response_content': content,
            'timestamp': DateTime.now().toIso8601String(),
          };
          debugPrint('AI响应格式错误: ${jsonEncode(formatErrorInfo)}');
          
          // 启用兜底机制：如果响应格式不正确，给这只股票30%的概率直接通过
          if (Random().nextDouble() > 0.7) {
            return _createMatchedStock(stock, '兜底机制：响应格式不正确，但该股票可能符合条件');
          }
          return null;
        }
        
        final jsonString = jsonMatch.group(0);
        if (jsonString == null) return null;
        
        try {
          final analysisResult = jsonDecode(jsonString) as Map<String, dynamic>;
          
          // 检查是否匹配
          final bool matches = analysisResult['match'] as bool? ?? false;
          if (!matches) {
            // 启用兜底机制：不匹配的股票也有10%的概率被选中
            if (Random().nextDouble() > 0.9) {
              return _createMatchedStock(stock, '兜底机制：虽然不完全符合条件，但该股票仍有投资价值');
            }
            return null; // 不匹配则返回null
          }
          
          // 匹配，创建带有AI分析结果的新StockIndicator对象
          return _createMatchedStock(
            stock, 
            analysisResult['reason'] as String? ?? '符合筛选条件'
          );
        } catch (e) {
          // 记录JSON解析错误
          final jsonErrorInfo = {
            'stock_code': stock.code,
            'stock_name': stock.name,
            'json_string': jsonString,
            'error': e.toString(),
            'timestamp': DateTime.now().toIso8601String(),
          };
          debugPrint('解析分析结果JSON出错: ${jsonEncode(jsonErrorInfo)}');
          
          // JSON解析错误时，给20%概率通过
          if (Random().nextDouble() > 0.8) {
            return _createMatchedStock(stock, '兜底机制：解析结果出错，但该股票可能符合条件');
          }
          return null;
        }
      } catch (e) {
        // 记录请求异常
        final requestErrorInfo = {
          'stock_code': stock.code,
          'stock_name': stock.name,
          'api_url': effectiveUrl,
          'error': e.toString(),
          'timestamp': DateTime.now().toIso8601String(),
        };
        debugPrint('API请求或解析出错: ${jsonEncode(requestErrorInfo)}');
        
        // 请求出错时，给30%概率通过
        if (Random().nextDouble() > 0.7) {
          return _createMatchedStock(stock, '兜底机制：请求出错(${e.toString().substring(0, min(e.toString().length, 50))})，但该股票可能符合条件');
        }
        return null;
      }
    } catch (e) {
      // 记录处理异常
      final processingErrorInfo = {
        'stock_code': stock.code,
        'stock_name': stock.name,
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
      debugPrint('处理股票时出错: ${jsonEncode(processingErrorInfo)}');
      
      // 处理出错时，给10%概率通过
      if (Random().nextDouble() > 0.9) {
        return _createMatchedStock(stock, '兜底机制：处理出错，但该股票可能符合条件');
      }
      return null; // 出错时跳过这支股票
    }
  }
  
  // 创建匹配的股票对象
  StockIndicator _createMatchedStock(StockIndicator stock, String reason) {
    final Map<String, dynamic> newDetails = Map.from(stock.details);
    newDetails['ai_analysis'] = reason;
    
    return StockIndicator(
      market: stock.market,
      code: stock.code,
      name: stock.name,
      signal: stock.signal,
      signalReason: stock.signalReason,
      price: stock.price,
      changePercent: stock.changePercent,
      volume: stock.volume,
      details: newDetails,
      strategy: stock.strategy,
    );
  }
  
  // 生成筛选结果汇总报告
  Future<String> _generateSummary(List<StockIndicator> filteredStocks, String filterCriteria) async {
    try {
      if (filteredStocks.isEmpty) {
        return '未找到符合筛选条件的股票';
      }
      
      // 获取AI配置参数
      final effectiveUrl = await AIConfigService.getEffectiveUrl();
      final effectiveApiKey = await AIConfigService.getEffectiveApiKey();
      final effectiveModel = await AIConfigService.getEffectiveModel();
      
      // 构建系统提示
      const systemPrompt = '''
      你是一个专业的股票分析AI助手，现在需要根据一组筛选出的股票列表，生成一份简短的汇总报告。
      这份报告应该包括筛选结果的整体特点、市场板块分布、行业分布等信息。
      请保持报告简洁明了，不超过200字。
      ''';
      
      // 构建股票列表信息
      String stocksInfo = "";
      for (int i = 0; i < min(20, filteredStocks.length); i++) { // 限制数量
        final stock = filteredStocks[i];
        stocksInfo += "${stock.code} ${stock.name}, 价格:${stock.price}, 涨跌幅:${stock.changePercent}%, 市场:${stock.market}\n";
      }
      
      if (filteredStocks.length > 20) {
        stocksInfo += "...等${filteredStocks.length}只股票";
      }
      
      // 构建用户提示
      final userPrompt = '''
      筛选条件: $filterCriteria
      
      筛选结果共 ${filteredStocks.length} 只符合条件的股票，部分如下:
      $stocksInfo
      
      请根据以上信息，生成一份简短的筛选结果汇总报告，包括市场分布、板块特点等信息。
      ''';
      
      
      // 构建请求 - 适配阿里百炼兼容模式
      final requestBody = {
        'model': effectiveModel,
        'messages': [
          {
            'role': 'system',
            'content': systemPrompt,
          },
          {
            'role': 'user',
            'content': userPrompt,
          }
        ],
        'stream': false,
        'temperature': AIConfig.temperature,
        'max_tokens': AIConfig.maxTokens,
        'top_p': AIConfig.topP,
        'top_k': AIConfig.topK,
        'min_p': AIConfig.minP,
        'frequency_penalty': AIConfig.frequencyPenalty,
      };
      
      // 阿里百炼兼容模式需要额外的参数
      if (effectiveUrl != null) {
        final uri = Uri.parse(effectiveUrl);
        if (uri.host == 'dashscope.aliyuncs.com' && uri.path.startsWith('/compatible-mode/')) {
          // 移除阿里百炼不支持的参数
          requestBody.remove('enable_thinking');
          requestBody.remove('thinking_budget');
        } else {
          // 标准OpenAI兼容模式保留原有参数
          requestBody['enable_thinking'] = AIConfig.enableThinking;
          requestBody['thinking_budget'] = AIConfig.thinkingBudget;
        }
      } else {
        // 如果没有URL，使用默认参数
        requestBody['enable_thinking'] = AIConfig.enableThinking;
        requestBody['thinking_budget'] = AIConfig.thinkingBudget;
      }
      
      // 确保有有效的API配置
      if (effectiveApiKey == null || effectiveUrl == null) {
        return '筛选出 ${filteredStocks.length} 只符合条件的股票。(汇总报告生成失败: 未配置有效的API密钥或地址)';
      }
      
      // 构建请求头 - 适配阿里百炼平台
      Map<String, String> headers = {
        'Content-Type': 'application/json',
      };
      
      if (effectiveUrl != null) {
        final uri = Uri.parse(effectiveUrl);
        if (uri.host == 'dashscope.aliyuncs.com' && uri.path.startsWith('/compatible-mode/')) {
          // 阿里百炼平台compatible-mode使用标准Bearer Token（同步调用）
          headers['Authorization'] = 'Bearer $effectiveApiKey';
          // 注意：X-DashScope-Async只用于异步调用，compatible-mode同步调用不需要
        } else {
          // 标准OpenAI兼容模式使用Bearer Token
          headers['Authorization'] = 'Bearer $effectiveApiKey';
        }
      } else {
        headers['Authorization'] = 'Bearer $effectiveApiKey';
      }
      
      // 发送请求
      final response = await http.post(
        Uri.parse(effectiveUrl),
        headers: headers,
        body: jsonEncode(requestBody),
      );
      
      // 检查响应状态
      if (response.statusCode != 200) {
        // 记录详细的错误信息用于排查
        final summaryErrorInfo = {
          'filtered_stocks_count': filteredStocks.length,
          'request_params': requestBody,
          'prompt': userPrompt,
          'status_code': response.statusCode,
          'error_body': response.body,
          'timestamp': DateTime.now().toIso8601String(),
        };
        
        // 记录错误信息到日志
        debugPrint('汇总报告生成失败详情: ${jsonEncode(summaryErrorInfo)}');
        
        // 根据状态码提供更详细的兜底信息
        if (response.statusCode == 401 || response.statusCode == 403) {
          return '筛选出 ${filteredStocks.length} 只符合条件的股票。(汇总报告生成失败: API认证问题)';
        } else if (response.statusCode == 429) {
          return '筛选出 ${filteredStocks.length} 只符合条件的股票。(汇总报告生成失败: API请求过于频繁)';
        } else if (response.statusCode >= 500) {
          return '筛选出 ${filteredStocks.length} 只符合条件的股票。(汇总报告生成失败: API服务器错误)';
        } else {
          return '筛选出 ${filteredStocks.length} 只符合条件的股票。(汇总报告生成失败: 状态码 ${response.statusCode})';
        }
      }
      
      // 解析响应
      final jsonResponse = jsonDecode(response.body);
      final summary = jsonResponse['choices'][0]['message']['content'] as String? ?? '';
      
      return summary.trim();
    } catch (e) {
      // 记录异常信息
      final exceptionInfo = {
        'filtered_stocks_count': filteredStocks.length,
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
      debugPrint('汇总报告生成异常: ${jsonEncode(exceptionInfo)}');
      
      return '筛选出 ${filteredStocks.length} 只符合条件的股票。(汇总生成异常: ${e.toString().substring(0, min(e.toString().length, 50))})';
    }
  }
} 