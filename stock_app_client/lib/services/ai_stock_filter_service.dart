import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/stock_indicator.dart';
import '../models/ai_filter_result.dart';
import 'api_service.dart';
import 'ai_filter_service.dart';
import 'enhanced_ai_filter_service.dart';

class AIStockFilterService {
  final ApiService _apiService = ApiService();
  final EnhancedAIFilterService _enhancedAIService = EnhancedAIFilterService();
  
  // 并发处理的最大数量 - 减少到3以避免API限流
  static const int maxConcurrentProcessing = 3;
  
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
      
      // 输出筛选统计
      debugPrint('');
      debugPrint('=' * 60);
      debugPrint('📊 AI筛选完成统计：');
      debugPrint('  原始股票数量: ${stocks.length} 只');
      debugPrint('  预筛选后数量: ${filteredStocks.length} 只');
      debugPrint('  实际分析数量: $processedCount 只');
      debugPrint('  符合条件数量: ${matchedStocks.length} 只');
      debugPrint('  过滤原因: 只保留"买入"信号的股票');
      debugPrint('=' * 60);
      debugPrint('');
      
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
    final originalCount = stocks.length;
    List<StockIndicator> filtered = stocks;
    
    // 示例：如果筛选条件包含"成交量"或"量能"关键词，可以预先筛选出成交量较大的股票
    if (filterCriteria.contains('成交量') || 
        filterCriteria.contains('量能') || 
        filterCriteria.contains('放量')) {
      // 按照成交量排序，取前70%
      final sortedByVolume = List<StockIndicator>.from(stocks)
        ..sort((a, b) => (b.volume ?? 0).compareTo(a.volume ?? 0));
      
      // 取前70%的数据 - 这个比例可以调整
      final int count = (sortedByVolume.length * 0.7).ceil();
      filtered = sortedByVolume.take(count).toList();
      debugPrint('📊 预筛选：根据成交量筛选，从 $originalCount 只股票中保留前 ${filtered.length} 只');
      return filtered;
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
      filtered = sortedByChange.take(count).toList();
      debugPrint('📊 预筛选：根据涨跌幅筛选，从 $originalCount 只股票中保留前 ${filtered.length} 只');
      return filtered;
    }
    
    // 默认情况，返回原始列表
    debugPrint('📊 预筛选：无特定条件，将分析全部 $originalCount 只股票');
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
  
  // 处理单个股票（使用前端增强AI分析）
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
      if (historyData.isEmpty || !historyData.containsKey('data')) {
        debugPrint('股票 ${stock.code} ${stock.name} 无历史数据');
        return null;
      }
      
      // 提取历史K线数据
      final historyList = historyData['data'] as List<dynamic>;
      
      // 确保历史数据按日期正确排序（从旧到新）
      historyList.sort((a, b) {
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

      // 至少需要60条K线数据进行技术分析
      if (historyList.length < 60) {
        debugPrint('股票 ${stock.code} ${stock.name} K线数据不足60条');
        return null;
      }
      
      // 取最近的数据（用于技术指标计算）
      final recentHistory = historyList.length > 120 
          ? historyList.sublist(historyList.length - 120) 
          : historyList;
      
      // 转换为 EnhancedAIFilterService 需要的格式
      final List<Map<String, dynamic>> klineData = recentHistory.map((item) {
        return {
          'date': item['date'] ?? item['trade_date'] ?? '',
          'open': (item['open'] as num?)?.toDouble() ?? 0.0,
          'high': (item['high'] as num?)?.toDouble() ?? 0.0,
          'low': (item['low'] as num?)?.toDouble() ?? 0.0,
          'close': (item['close'] as num?)?.toDouble() ?? 0.0,
          'volume': (item['volume'] as num?)?.toDouble() ?? 0.0,
        };
      }).toList();
      
      // 使用 EnhancedAIFilterService 进行完整的技术分析（包含筛选条件和行业信息）
      final analysisResult = await _enhancedAIService.analyzeStock(
        stockCode: stock.code,
        stockName: stock.name,
        klineData: klineData,
        filterCriteria: filterCriteria,  // 传入用户的筛选条件
        industry: stock.industry,  // 传入行业信息
      );
      
      // 如果分析失败，跳过该股票
      if (analysisResult == null) {
        debugPrint('股票 ${stock.code} ${stock.name} AI分析失败');
        return null;
      }
      
      // 获取信号类型
      final signal = analysisResult['signal'] as String?;
      
      // 只保留"买入"信号的股票（不再保留观望）
      if (signal != '买入') {
        debugPrint('📉 股票 ${stock.code} ${stock.name} 信号为 $signal，跳过（只保留买入信号）');
        return null;
      }
      
      debugPrint('✅ 股票 ${stock.code} ${stock.name} 符合条件，信号: $signal');

      
      // 创建带有AI分析结果的股票对象
      return _createMatchedStockWithAnalysis(stock, analysisResult);
    } catch (e) {
      debugPrint('处理股票 ${stock.code} ${stock.name} 时出错: $e');
      return null;
    }
  }
  
  // 创建带有完整AI分析结果的股票对象
  StockIndicator _createMatchedStockWithAnalysis(
    StockIndicator stock, 
    Map<String, dynamic> analysisResult
  ) {
    final Map<String, dynamic> newDetails = Map.from(stock.details);
    // 存储完整的结构化AI分析结果
    newDetails['ai_analysis'] = analysisResult;
    
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
      
      // 简单的汇总报告
      final summary = StringBuffer();
      summary.writeln('AI筛选完成！');
      summary.writeln('');
      summary.writeln('筛选出 ${filteredStocks.length} 只符合条件的股票：');
      summary.writeln('');
      
      // 按信号类型分组统计
      final buySignals = filteredStocks.where((s) {
        final analysis = s.details['ai_analysis'];
        if (analysis is Map) {
          return analysis['signal'] == '买入';
        }
        return false;
      }).length;
      
      final holdSignals = filteredStocks.length - buySignals;
      
      summary.writeln('买入信号: $buySignals 只');
      summary.writeln('观望信号: $holdSignals 只');
      summary.writeln('');
      
      // 列出前10只股票
      final topStocks = filteredStocks.take(10);
      summary.writeln('重点关注（前10只）：');
      for (final stock in topStocks) {
        final analysis = stock.details['ai_analysis'];
        String signal = '未知';
        String confidence = '未知';
        
        if (analysis is Map) {
          signal = analysis['signal'] ?? '未知';
          confidence = analysis['confidence'] ?? '未知';
        }
        
        summary.writeln('${stock.name}(${stock.code}) - 信号:$signal 置信度:$confidence');
      }
      
      return summary.toString();
    } catch (e) {
      debugPrint('生成汇总报告失败: $e');
      return '筛选出 ${filteredStocks.length} 只符合条件的股票';
    }
  }
}
