class ApiConfig {
  // API 地址配置
  //http://101.200.47.169:8000/docs
  static const String baseUrl = 'http://101.200.47.169:8000';
  static const String apiBaseUrl = '$baseUrl/api';
  
  // API 端点 - 策略相关
  static const String strategiesEndpoint = '$apiBaseUrl/strategies';
  static const String strategyDetailEndpoint = '$apiBaseUrl/strategy';
  
  // 股票相关API端点
  static const String stocksEndpoint = '$apiBaseUrl/stocks';
  static const String stockBuySignalEndpoint = '$apiBaseUrl/stocks/signal/buy';
  static const String stockSellSignalEndpoint = '$apiBaseUrl/stocks/signal/sell';
  static const String stockCodeSearchEndpoint = '$apiBaseUrl/stocks/code_search';
  static const String stockNameSearchEndpoint = '$apiBaseUrl/stocks/name_search';
  static const String stockStatusEndpoint = '$apiBaseUrl/stocks/status';
  static const String stockBatchPriceEndpoint = '$apiBaseUrl/stocks/batch-price'; // 批量获取股票价格
  static const String stockRealTimePriceEndpoint = '$apiBaseUrl/stocks'; // 单个股票实时价格，后接股票代码/price
  
  // 股票历史数据API端点 - 使用查询参数方式
  static const String stockHistoryEndpoint = '$apiBaseUrl/stocks/history';
  
  // 单支股票信息API端点
  static const String getStockInfoEndpoint = '$apiBaseUrl/stocks/'; // 后接股票代码
  static const String getStockChartEndpoint = '$apiBaseUrl/stocks/'; // 后接股票代码/chart
  static const String getStockAnalysisEndpoint = '$apiBaseUrl/stocks/'; // 后接股票代码/analysis/stream
  
  // 新闻相关API端点
  static const String newsAnalysisEndpoint = '$apiBaseUrl/news/analysis';
  static const String latestNewsEndpoint = '$apiBaseUrl/news/latest';
  static const String stockNewsEndpoint = '$apiBaseUrl/public/stock_news';
  
  // 图表API端点
  static const String stockChartEndpoint = '$apiBaseUrl/chart/'; // 后接股票代码?strategy=策略名
  
  // API Token 配置
  static const String apiToken = 'eXvM4zU8nP9qWt3dRfKgH7jBcA2yE5sZ';
  static const bool apiTokenEnabled = true; // 设置为false可禁用Token验证
  
  // API Token 请求头名称
  static const String apiTokenHeaderName = 'X-API-Token';

  // 获取完整的URL
  static String getStockInfoUrl(String stockCode) => '$getStockInfoEndpoint$stockCode';
  
  // 使用完整路径获取股票历史数据，stock_code作为查询参数
  static String getStockHistoryUrl(String stockCode, {
    String? startDate,
    String? endDate,
  }) {
    var url = '$stockHistoryEndpoint?stock_code=$stockCode';
    if (startDate != null) url += '&start_date=$startDate';
    if (endDate != null) url += '&end_date=$endDate';
    return url;
  }
  
  static String getStockChartUrl(String stockCode) => '$getStockChartEndpoint$stockCode/chart';
  static String getStockAnalysisUrl(String stockCode) => '$getStockAnalysisEndpoint$stockCode/analysis/stream';
  static String getStockNewsUrl(String symbol) => '$stockNewsEndpoint?symbol=$symbol';
  static String getStockChartWithStrategyUrl(String stockCode, String strategy) => '$stockChartEndpoint$stockCode?strategy=$strategy';
  
  // AI分析POST接口 - 后端统一处理
  static String getStockAIAnalysisPostUrl() => '$apiBaseUrl/stocks/ai-analysis/simple';
  
  // AI分析缓存查询接口 - 检查后端是否有缓存
  static String getStockAIAnalysisCacheUrl(String stockCode) => '$apiBaseUrl/stocks/ai-analysis/cache?code=$stockCode';
} 