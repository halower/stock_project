import 'stock_indicator.dart';

class AIFilterResult {
  // 原始筛选条件
  final String originalFilter;
  
  // 筛选结果列表
  final List<StockIndicator> stocks;
  
  // 筛选报告（总结结果）
  final String summary;
  
  // 当前处理进度
  final int processedCount;
  
  // 总共需要处理的数量
  final int totalCount;
  
  // 是否完成
  final bool completed;
  
  // 任务ID
  final String taskId;
  
  // 创建时间
  final DateTime createdAt;
  
  // 是否发生错误
  final bool hasError;
  
  // 错误信息
  final String? errorMessage;
  
  AIFilterResult({
    required this.originalFilter,
    required this.stocks,
    required this.summary,
    required this.processedCount,
    required this.totalCount,
    required this.completed,
    required this.taskId,
    required this.createdAt,
    this.hasError = false,
    this.errorMessage,
  });
  
  // 获取处理进度百分比
  double get progressPercentage {
    if (totalCount == 0) return 0.0;
    return processedCount / totalCount;
  }
  
  // 获取友好的进度文本
  String get progressText {
    if (hasError) {
      return '筛选出错: ${errorMessage ?? '未知错误'}';
    }
    
    if (completed) {
      return '完成: 找到 ${stocks.length} 只符合条件的股票';
    }
    
    if (processedCount == 0) {
      return '正在准备筛选...';
    }
    
    final percentage = (progressPercentage * 100).toStringAsFixed(1);
    return '正在筛选: $processedCount/$totalCount ($percentage%)';
  }
  
  // 获取结果状态
  String get statusText {
    if (hasError) {
      return '筛选出错';
    }
    
    if (completed) {
      if (stocks.isEmpty) {
        return '未找到符合条件的股票';
      }
      return '筛选完成';
    }
    
    return '筛选中...';
  }
  
  // 创建一个进行中的结果对象
  factory AIFilterResult.inProgress({
    required String originalFilter,
    required List<StockIndicator> currentStocks,
    required int processedCount,
    required int totalCount,
    required String taskId,
  }) {
    return AIFilterResult(
      originalFilter: originalFilter,
      stocks: currentStocks,
      summary: '处理中...',
      processedCount: processedCount,
      totalCount: totalCount,
      completed: false,
      taskId: taskId,
      createdAt: DateTime.now(),
    );
  }
  
  // 创建一个完成的结果对象
  factory AIFilterResult.completed({
    required String originalFilter,
    required List<StockIndicator> stocks,
    required String summary,
    required String taskId,
  }) {
    return AIFilterResult(
      originalFilter: originalFilter,
      stocks: stocks,
      summary: summary,
      processedCount: stocks.length,
      totalCount: stocks.length,
      completed: true,
      taskId: taskId,
      createdAt: DateTime.now(),
    );
  }
  
  // 创建一个错误结果
  factory AIFilterResult.error({
    required String originalFilter,
    required String errorMessage,
    required int totalCount,
    required String taskId,
  }) {
    return AIFilterResult(
      originalFilter: originalFilter,
      stocks: [],
      summary: '筛选出错: $errorMessage',
      processedCount: 0,
      totalCount: totalCount,
      completed: true,
      taskId: taskId,
      createdAt: DateTime.now(),
      hasError: true,
      errorMessage: errorMessage,
    );
  }
  
  // 创建一个进度更新
  AIFilterResult copyWithProgress({
    required int processedCount,
    required List<StockIndicator> currentStocks,
  }) {
    return AIFilterResult(
      originalFilter: originalFilter,
      stocks: currentStocks,
      summary: summary,
      processedCount: processedCount,
      totalCount: totalCount,
      completed: processedCount >= totalCount,
      taskId: taskId,
      createdAt: createdAt,
      hasError: hasError,
      errorMessage: errorMessage,
    );
  }
  
  // 创建完成时的更新
  AIFilterResult copyWithCompleted({
    required List<StockIndicator> stocks,
    required String summary,
  }) {
    return AIFilterResult(
      originalFilter: originalFilter,
      stocks: stocks,
      summary: summary,
      processedCount: stocks.length,
      totalCount: stocks.length,
      completed: true,
      taskId: taskId,
      createdAt: createdAt,
      hasError: hasError,
      errorMessage: errorMessage,
    );
  }
  
  // 创建错误时的更新
  AIFilterResult copyWithError({
    required String errorMessage,
  }) {
    return AIFilterResult(
      originalFilter: originalFilter,
      stocks: [],
      summary: '筛选出错: $errorMessage',
      processedCount: processedCount,
      totalCount: totalCount,
      completed: true,
      taskId: taskId,
      createdAt: createdAt,
      hasError: true,
      errorMessage: errorMessage,
    );
  }
} 