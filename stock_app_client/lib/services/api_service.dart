import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:io' as io;
import '../config/api_config.dart';
import 'http_client.dart';

class ApiService {
  // 使用配置文件中的API地址
  static const String baseUrl = ApiConfig.baseUrl;
  static const String apiBaseUrl = ApiConfig.apiBaseUrl;
  
  // 添加缓存
  static final Map<String, _CachedNewsData> _newsCache = {};
  
  // 默认策略常量
  static const String strategyVolumeWave = 'volume_wave';
  static const String strategyTrendContinuation = 'trend_continuation';
  
  // 缓存的消息面分析报告
  static Map<String, dynamic>? _newsAnalysisCache;
  static DateTime? _newsAnalysisCacheTime;
  
  // 获取股票列表
  Future<List<Map<String, dynamic>>> getAllStocks() async {
    try {
      // 修复URL构建方式，不再需要分页参数
      final url = '${ApiConfig.stocksEndpoint}';
      debugPrint('请求股票列表: $url');
      
      // 使用新的HttpClient发送请求
      final response = await HttpClient.get(url);
      
      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        final data = json.decode(responseBody);
        final stocksData = data['stocks'] as List<dynamic>;
        final total = data['total'] ?? stocksData.length;
        final returned = data['returned'] ?? stocksData.length;
        debugPrint('获取到股票信息: 返回${returned}只, 总计${total}只');
        
        return List<Map<String, dynamic>>.from(stocksData);
      } else {
        debugPrint('获取股票列表失败: ${response.statusCode}, ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('获取股票列表出错: $e');
      return [];
    }
  }
  
  // 获取买入信号股票列表
  Future<List<Map<String, dynamic>>> getBuySignalStocks({
    int limit = 500,
    bool forceRefresh = false,
    String strategy = '',
  }) async {
    try {
      // 如果未指定策略，使用默认波动策略
      final String strategyParam = strategy.isEmpty ? strategyVolumeWave : strategy;
      final url = '${ApiConfig.stockBuySignalEndpoint}?strategy=$strategyParam';
      debugPrint('=== 开始请求买入信号股票 ===');
      debugPrint('请求参数 - limit: $limit, forceRefresh: $forceRefresh, strategy: $strategy');
      debugPrint('最终策略参数: $strategyParam');
      debugPrint('请求URL: $url');
      debugPrint('ApiConfig.stockBuySignalEndpoint: ${ApiConfig.stockBuySignalEndpoint}');
      
      // 使用新的HttpClient发送请求
      debugPrint('开始发送HTTP请求...');
      final response = await HttpClient.get(url);
      debugPrint('HTTP响应状态码: ${response.statusCode}');
      debugPrint('HTTP响应头: ${response.headers}');
      
      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        debugPrint('响应体长度: ${responseBody.length}');
        debugPrint('完整响应体: $responseBody');
        
        if (responseBody.isEmpty) {
          debugPrint('警告: 响应体为空');
          return [];
        }
        
        try {
        final data = json.decode(responseBody);
          debugPrint('JSON解析成功，数据类型: ${data.runtimeType}');
          
          if (data is Map) {
            debugPrint('响应数据的所有字段: ${data.keys.toList()}');
          }
        
          // 数据可能直接是列表或者在嵌套字段中
        List<dynamic> stocksData = [];
        if (data is List) {
            debugPrint('数据是列表格式，长度: ${data.length}');
          stocksData = data;
        } else if (data is Map) {
            debugPrint('数据是Map格式，开始查找股票列表字段...');
            
            // 检查API标准响应格式: data.signals
            if (data.containsKey('data') && data['data'] is Map) {
              final dataMap = data['data'] as Map<String, dynamic>;
              debugPrint('找到data字段，检查其子字段: ${dataMap.keys.toList()}');
              
              if (dataMap.containsKey('signals') && dataMap['signals'] is List) {
                debugPrint('从data.signals字段中获取数据，长度: ${(dataMap['signals'] as List).length}');
                stocksData = dataMap['signals'] as List<dynamic>;
              }
            }
            
            // 如果data.signals没有找到，尝试查找其他可能的字段
            if (stocksData.isEmpty) {
              final possibleKeys = ['stocks', 'data', 'results', 'items', 'signals'];
          for (final key in possibleKeys) {
                debugPrint('检查字段: $key');
                if (data.containsKey(key)) {
                  debugPrint('找到字段 $key，类型: ${data[key].runtimeType}');
                  if (data[key] is List) {
                    debugPrint('从字段 $key 中获取数据，长度: ${(data[key] as List).length}');
              stocksData = data[key] as List<dynamic>;
              break;
                  }
                } else {
                  debugPrint('字段 $key 不存在');
                }
            }
          }
          
          // 如果没找到任何列表字段，可能数据本身就是空的
          if (stocksData.isEmpty && data.isEmpty) {
            debugPrint('API返回空数据');
            return [];
            } else if (stocksData.isEmpty) {
              debugPrint('警告: 未找到有效的股票数据列表');
              debugPrint('可用的字段: ${data.keys.toList()}');
              // 如果data字段存在但是Map类型，也打印其内容
              if (data.containsKey('data') && data['data'] is Map) {
                debugPrint('data字段内容: ${(data['data'] as Map).keys.toList()}');
              }
          }
        }
        
        if (stocksData.isEmpty) {
            debugPrint('错误: 无法解析API返回的数据格式');
            debugPrint('原始数据: $data');
          return [];
        }
        
          debugPrint('成功获取到买入信号股票: ${stocksData.length}只');
          
          // 打印前几个股票的详细信息用于调试
          for (int i = 0; i < stocksData.length && i < 3; i++) {
            debugPrint('股票 ${i + 1} 原始数据: ${stocksData[i]}');
          }
        
        // 确保每个股票对象包含latest_price, change_percent, volume, board字段
          final processedStocks = stocksData.map<Map<String, dynamic>>((item) {
          final stockMap = Map<String, dynamic>.from(item);
            
            
            // price -> latest_price -> price 
            if (stockMap.containsKey('price') && !stockMap.containsKey('latest_price')) {
              stockMap['latest_price'] = stockMap['price'];
              debugPrint('映射 price -> latest_price: ${stockMap['price']}');
            }
          
          // 确保将latest_price映射到price字段
          if (stockMap.containsKey('latest_price') && !stockMap.containsKey('price')) {
            stockMap['price'] = stockMap['latest_price'];
              debugPrint('映射 latest_price -> price: ${stockMap['latest_price']}');
          }
          
          // 确保market字段正确
          if (stockMap.containsKey('board') && !stockMap.containsKey('market')) {
            stockMap['market'] = stockMap['board'];
              debugPrint('映射 board -> market: ${stockMap['board']}');
            }
            
            // 从股票代码推断市场/板块信息
            if (!stockMap.containsKey('market') || stockMap['market'] == null || stockMap['market'].toString().isEmpty) {
              final code = stockMap['code'] ?? stockMap['ts_code'] ?? '';
              if (code.isNotEmpty) {
                String market = '未知';
                // 6位数字代码的判断逻辑
                if (code.length >= 6) {
                  final codePrefix = code.substring(0, 3);
                  final codeNum = code.substring(0, 6);
                  
                  // 深圳交易所
                  if (codePrefix == '000') {
                    market = '深证主板';
                  } else if (codePrefix == '001') {
                    market = '深证主板';
                  } else if (codePrefix == '002') {
                    market = '深证主板';
                  } else if (codePrefix == '003') {
                    market = '深证主板';
                  } else if (codePrefix == '300' || codePrefix == '301') {
                    market = '创业板'; // 300开头：老创业板，301开头：新创业板
                  }
                  // 上海交易所
                  else if (codePrefix == '600' || codePrefix == '601' || codePrefix == '603' || codePrefix == '605') {
                    market = '上证主板';
                  } else if (codePrefix == '688' || codePrefix == '689') {
                    market = '科创板'; // 688开头：科创板，689开头：科创板（预留）
                  }
                  // 北京交易所 
                  else if (codePrefix == '430' || codePrefix == '830' || codePrefix == '870') {
                    market = '北交所';
                  }
                  // 其他特殊代码
                  else if (codePrefix == '900') {
                    market = 'B股'; // 上海B股
                  } else if (codePrefix == '200') {
                    market = 'B股'; // 深圳B股
                  }
                                                        // 如果包含后缀，也要处理
                   else if (code.contains('.SZ')) {
                     if (code.startsWith('300') || code.startsWith('301')) {
                       market = '创业板';
                     } else if (code.startsWith('000') || code.startsWith('001') || code.startsWith('002') || code.startsWith('003')) {
                       market = '深证主板';
                     } else if (code.startsWith('200')) {
                       market = 'B股';
                     }
                   } else if (code.contains('.SH')) {
                     if (code.startsWith('688') || code.startsWith('689')) {
                       market = '科创板';
                     } else if (code.startsWith('600') || code.startsWith('601') || code.startsWith('603') || code.startsWith('605')) {
                       market = '上证主板';
                     } else if (code.startsWith('900')) {
                       market = 'B股';
                     }
                   } else if (code.contains('.BJ')) {
                     market = '北交所';
                   }
                }
                stockMap['market'] = market;
                debugPrint('推断市场: $code -> $market (前缀: ${code.length >= 3 ? code.substring(0, 3) : code})');
              }
          }
          
          // 确保有信号字段
          if (!stockMap.containsKey('signal')) {
            stockMap['signal'] = '买入';
          }
          
          // 确保有策略字段
          if (!stockMap.containsKey('strategy')) {
            stockMap['strategy'] = strategyParam;
          }
            
            // 确保有股票名称
            if (!stockMap.containsKey('stock_name') && stockMap.containsKey('name')) {
              stockMap['stock_name'] = stockMap['name'];
            }
            
            // 时间字段处理：支持新的 kline_date 和 calculated_time 字段
            // 这两个字段会直接传递给前端，不需要转换
            if (stockMap.containsKey('kline_date')) {
              debugPrint('K线日期: ${stockMap['kline_date']}');
            }
            
            if (stockMap.containsKey('calculated_time')) {
              debugPrint('计算触发时间: ${stockMap['calculated_time']}');
            }
            
            // 兼容旧的 signal_time 字段映射为 signal_date
            if (stockMap.containsKey('signal_time') && !stockMap.containsKey('signal_date')) {
              final signalTime = stockMap['signal_time'].toString();
              // 格式化时间显示：只显示日期和时间到分钟，不显示秒和毫秒
              if (signalTime.contains('T')) {
                final parts = signalTime.split('T');
                if (parts.length >= 2) {
                  final date = parts[0]; // 2025-06-15
                  final timePart = parts[1].split('.')[0]; // 15:09:55 (去掉毫秒)
                  final timeComponents = timePart.split(':');
                  if (timeComponents.length >= 2) {
                    final timeFormatted = '${timeComponents[0]}:${timeComponents[1]}'; // 15:09 (去掉秒)
                    stockMap['signal_date'] = '$date $timeFormatted';
                    debugPrint('映射 signal_time -> signal_date: ${stockMap['signal_date']}');
                  } else {
                    stockMap['signal_date'] = '$date $timePart';
                  }
                } else {
                  stockMap['signal_date'] = signalTime;
                }
              } else {
                stockMap['signal_date'] = signalTime;
              }
            }
            
            // 原因字段映射
            if (stockMap.containsKey('reason') && !stockMap.containsKey('signal_reason')) {
              stockMap['signal_reason'] = stockMap['reason'];
              debugPrint('映射 reason -> signal_reason: ${stockMap['reason']}');
            }
            
            // 确保涨跌幅字段 - 仅在确实没有有效数据时设置默认值
            if (!stockMap.containsKey('change_percent') || stockMap['change_percent'] == null) {
              // 尝试从其他字段获取涨跌幅数据
              if (stockMap.containsKey('change_pct') && stockMap['change_pct'] != null) {
                stockMap['change_percent'] = stockMap['change_pct'];
                debugPrint('映射 change_pct -> change_percent: ${stockMap['change_pct']}');
              } else if (stockMap.containsKey('pct_chg') && stockMap['pct_chg'] != null) {
                stockMap['change_percent'] = stockMap['pct_chg'];
                debugPrint('映射 pct_chg -> change_percent: ${stockMap['pct_chg']}');
              } else {
                // 如果完全没有涨跌幅数据，则设置为null而不是0
                stockMap['change_percent'] = null;
                debugPrint('股票 ${stockMap['code']} 没有涨跌幅数据');
              }
            } else {
              debugPrint('确认股票 ${stockMap['code']} 涨跌幅: ${stockMap['change_percent']}%');
            }
            
            // 确保成交量字段 (如果API没有提供)  
            if (!stockMap.containsKey('volume')) {
              stockMap['volume'] = 0; // 默认值
            }
          
          return stockMap;
        }).toList();
          
          // 打印处理后的前几个股票信息，重点检查涨跌幅
          for (int i = 0; i < processedStocks.length && i < 3; i++) {
            final stock = processedStocks[i];
            debugPrint('处理后股票 ${i + 1}: ${stock['code']} ${stock['name']}');
            debugPrint('  - 价格: ${stock['price'] ?? stock['latest_price']}');
            debugPrint('  - 涨跌幅: ${stock['change_percent']}%');
            debugPrint('  - 成交量: ${stock['volume']}');
            debugPrint('  - 原始数据键: ${stock.keys.join(', ')}');
          }
          
          debugPrint('=== 买入信号股票请求完成，返回 ${processedStocks.length} 只股票 ===');
          return processedStocks;
          
        } catch (jsonError) {
          debugPrint('JSON解析失败: $jsonError');
          debugPrint('原始响应体: $responseBody');
          return [];
        }
      } else {
        debugPrint('HTTP请求失败:');
        debugPrint('状态码: ${response.statusCode}');
        debugPrint('响应体: ${response.body}');
        debugPrint('响应头: ${response.headers}');
        return [];
      }
    } catch (e, stackTrace) {
      debugPrint('获取买入信号股票出错: $e');
      debugPrint('错误堆栈: $stackTrace');
      return [];
    }
  }
  
  // 获取卖出信号股票列表
  Future<List<Map<String, dynamic>>> getSellSignalStocks({
    int limit = 100,
    bool forceRefresh = false,
    String strategy = '',
  }) async {
    try {
      // 如果未指定策略，使用默认波动策略
      final String strategyParam = strategy.isEmpty ? strategyVolumeWave : strategy;
      final url = '${ApiConfig.stockSellSignalEndpoint}?limit=$limit&force_refresh=$forceRefresh&strategy=$strategyParam';
      debugPrint('请求卖出信号股票: $url');
      
      final response = await HttpClient.get(url);
      
      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        final data = json.decode(responseBody);
        final stocksData = data['stocks'] as List<dynamic>? ?? [];
        debugPrint('获取到卖出信号股票: ${stocksData.length}只');
        
        // 添加策略字段
        return List<Map<String, dynamic>>.from(stocksData.map((item) {
          final stockMap = Map<String, dynamic>.from(item);
          if (!stockMap.containsKey('strategy')) {
            stockMap['strategy'] = strategyParam;
          }
          return stockMap;
        }));
      } else {
        debugPrint('获取卖出信号股票失败: ${response.statusCode}, ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('获取卖出信号股票出错: $e');
      return [];
    }
  }
  
  // 股票代码前缀搜索
  Future<List<Map<String, dynamic>>> searchStocksByCode(String codePrefix) async {
    try {
      final url = '${ApiConfig.stockCodeSearchEndpoint}?code_prefix=$codePrefix';
      debugPrint('按代码前缀搜索股票: $url');
      
      final response = await HttpClient.get(url);
      
      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        final data = json.decode(responseBody);
        final stocksData = data['stocks'] as List<dynamic>;
        debugPrint('按代码前缀搜索到股票: ${stocksData.length}只');
        
        return List<Map<String, dynamic>>.from(stocksData);
      } else {
        debugPrint('按代码前缀搜索股票失败: ${response.statusCode}, ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('按代码前缀搜索股票出错: $e');
      return [];
    }
  }
  
  // 股票名称搜索
  Future<List<Map<String, dynamic>>> searchStocksByName(String name) async {
    try {
      final url = '${ApiConfig.stockNameSearchEndpoint}?name=$name';
      debugPrint('按名称搜索股票: $url');
      
      final response = await HttpClient.get(url);
      
      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        final data = json.decode(responseBody);
        final stocksData = data['stocks'] as List<dynamic>;
        debugPrint('按名称搜索到股票: ${stocksData.length}只');
        
        return List<Map<String, dynamic>>.from(stocksData);
      } else {
        debugPrint('按名称搜索股票失败: ${response.statusCode}, ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('按名称搜索股票出错: $e');
      return [];
    }
  }
  
  // 获取单个股票信息
  Future<Map<String, dynamic>> getStockInfo(String stockCode) async {
    try {
      final url = ApiConfig.getStockInfoUrl(stockCode);
      debugPrint('请求股票信息: $url');
      
      final response = await HttpClient.get(url);
      
      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        final data = json.decode(responseBody);
        debugPrint('获取到股票信息');
        return data;
      } else {
        debugPrint('获取股票信息失败: ${response.statusCode}, ${response.body}');
        return {};
      }
    } catch (e) {
      debugPrint('获取股票信息出错: $e');
      return {};
    }
  }
  
  // 获取股票历史数据 - 使用完整路径，stock_code作为查询参数
  Future<Map<String, dynamic>> getStockHistory(String stockCode, {
    String? startDate,
    String? endDate,
  }) async {
    try {
      final url = ApiConfig.getStockHistoryUrl(
        stockCode,
        startDate: startDate,
        endDate: endDate,
      );
      debugPrint('请求股票历史数据: $url');
      
      final response = await HttpClient.get(url);
      
      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        final data = json.decode(responseBody);
        
        // 返回完整响应数据 - API返回的是data字段，不是history字段
        if (data.containsKey('data') && data['data'] is List) {
          debugPrint('获取到股票历史数据，含${(data['data'] as List<dynamic>).length}条记录');
        } else {
          debugPrint('获取到股票历史数据，但格式不符合预期');
        }
        return data;
      } else {
        debugPrint('获取股票历史数据失败: ${response.statusCode}, ${response.body}');
        return {};
      }
    } catch (e) {
      debugPrint('获取股票历史数据出错: $e');
      return {};
    }
  }
  
  // 生成股票K线图表
  Future<Map<String, dynamic>> generateStockChart(String stockCode) async {
    try {
      final url = ApiConfig.getStockChartUrl(stockCode);
      debugPrint('请求生成股票K线图表: $url');
      
      final response = await HttpClient.get(url);
      
      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        final data = json.decode(responseBody);
        debugPrint('成功生成股票K线图表');
        
        return data;
      } else {
        debugPrint('生成股票K线图表失败: ${response.statusCode}, ${response.body}');
        return {};
      }
    } catch (e) {
      debugPrint('生成股票K线图表出错: $e');
      return {};
    }
  }
  
  // 获取个股研报信息
  Future<Map<String, dynamic>> getStockResearchReport(String symbol) async {
    try {
      final url = "${ApiConfig.getStockAnalysisUrl(symbol)}?fresh_cache=false";
      debugPrint('请求个股研报信息: $url');
      
      final response = await HttpClient.get(url);
      
      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        final data = json.decode(responseBody);
        debugPrint('获取到个股研报信息');
        
        return data;
      } else {
        debugPrint('获取个股研报信息失败: ${response.statusCode}, ${response.body}');
        return {};
      }
    } catch (e) {
      debugPrint('获取个股研报信息出错: $e');
      return {};
    }
  }
  
  // 获取个股新闻
  Future<List<Map<String, dynamic>>> getStockNews(String symbol) async {
    // 检查缓存
    final now = DateTime.now();
    final cachedData = _newsCache[symbol];
    
    // 如果存在缓存且是今天的数据，直接返回
    if (cachedData != null && _isSameDay(cachedData.timestamp, now)) {
      debugPrint('使用缓存的新闻数据，股票代码: $symbol, 缓存时间: ${cachedData.timestamp}');
      return cachedData.newsList;
    }
    
    try {
      final url = ApiConfig.getStockNewsUrl(symbol);
      debugPrint('请求个股新闻: $url');
      
      final response = await HttpClient.get(url);
      
      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        debugPrint('获取到新闻响应数据，长度: ${responseBody.length}');
        
        try {
          final data = json.decode(responseBody);
          List<Map<String, dynamic>> newsList = [];
          
          // 新接口直接返回列表
          if (data is List) {
            debugPrint('获取到 ${data.length} 条新闻');
            newsList = List<Map<String, dynamic>>.from(data);
          } 
          // 兼容可能的旧接口(如果有)
          else if (data is Map<String, dynamic>) {
            debugPrint('获取到的是Map格式数据，尝试提取新闻列表');
            
            // 尝试从各种可能的字段提取列表
            final possibleKeys = ['data', 'news', 'items', 'results', 'articles'];
            for (final key in possibleKeys) {
              if (data.containsKey(key) && data[key] is List) {
                newsList = List<Map<String, dynamic>>.from(data[key]);
                debugPrint('从字段 $key 中提取到 ${newsList.length} 条新闻');
                break;
              }
            }
            
            if (newsList.isEmpty) {
              debugPrint('未找到有效的新闻列表字段');
            }
          } else {
            debugPrint('新闻数据既不是List也不是Map: ${data.runtimeType}');
          }
          
          // 保存到缓存
          if (newsList.isNotEmpty) {
            _newsCache[symbol] = _CachedNewsData(
              timestamp: now,
              newsList: newsList,
            );
            debugPrint('新闻数据已缓存，股票代码: $symbol, 新闻数: ${newsList.length}');
          }
          
          return newsList;
        } catch (e) {
          debugPrint('解析新闻数据失败: $e');
          debugPrint('响应内容: ${responseBody.substring(0, responseBody.length > 100 ? 100 : responseBody.length)}...');
          return [];
        }
      } else {
        debugPrint('获取个股新闻失败: ${response.statusCode}, ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('获取个股新闻出错: $e');
      return [];
    }
  }
  
  // 辅助方法：判断两个日期是否是同一天
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
  
  // 清除新闻缓存
  void clearNewsCache() {
    _newsCache.clear();
    debugPrint('新闻缓存已清除');
  }
  
  // 清除特定股票的新闻缓存
  void clearStockNewsCache(String symbol) {
    _newsCache.remove(symbol);
    debugPrint('股票 $symbol 的新闻缓存已清除');
  }
  
  // 获取数据状态统计
  Future<Map<String, dynamic>> getDataStatus() async {
    try {
      final uri = Uri.parse(ApiConfig.stockStatusEndpoint);
      debugPrint('请求数据状态统计: $uri');
      
      final response = await HttpClient.get(uri.toString());
      
      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        final data = json.decode(responseBody);
        debugPrint('获取到数据状态统计');
        
        return data;
      } else {
        debugPrint('获取数据状态统计失败: ${response.statusCode}, ${response.body}');
        return {};
      }
    } catch (e) {
      debugPrint('获取数据状态统计出错: $e');
      return {};
    }
  }
  
  // 获取股票AI分析(流式API)
  Stream<Map<String, dynamic>> getStockAnalysisStream(String stockCode) async* {
    try {
      final uri = Uri.parse('${ApiConfig.getStockAnalysisUrl(stockCode)}?force_refresh=false');
      debugPrint('请求股票AI分析(流式): $uri');
      
      final httpClient = io.HttpClient();
      final request = await httpClient.openUrl('GET', uri);
      final response = await request.close();
      
      if (response.statusCode == 200) {
        debugPrint('连接到AI分析流式API成功');
        
        // 处理NDJSON格式的流式响应 - 每行是一个独立的JSON对象
        await for (var line in response.transform(utf8.decoder).transform(const LineSplitter())) {
          if (line.isNotEmpty) {
            try {
              debugPrint('收到原始数据行: $line');
              final data = json.decode(line);
              debugPrint('成功解析JSON行: ${data['status']}');
              yield data;
            } catch (e) {
              debugPrint('解析AI数据行出错: $e, 原始数据: $line');
              yield {
                'status': 'error',
                'message': '数据解析失败: $e',
              };
            }
          }
        }
      } else {
        debugPrint('股票AI分析请求失败: ${response.statusCode}');
        yield {
          'status': 'error',
          'message': '请求失败，状态码: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('获取股票AI分析出错: $e');
      yield {
        'status': 'error',
        'message': '发生错误: $e',
      };
    }
  }
  
  // 获取消息面分析报告
  Future<Map<String, dynamic>> getNewsAnalysis({
    required String aiModelName,
    required String aiEndpoint,
    required String aiApiKey,
    bool forceRefresh = false,
  }) async {
    // 检查缓存是否有效（2小时内的缓存有效）
    final now = DateTime.now();
    if (!forceRefresh && _newsAnalysisCache != null && _newsAnalysisCacheTime != null) {
      final difference = now.difference(_newsAnalysisCacheTime!);
      if (difference.inHours < 2) {
        debugPrint('使用缓存的消息面分析报告, 缓存时间: $_newsAnalysisCacheTime');
        return _newsAnalysisCache!;
      }
    }
    
    try {
      const url = ApiConfig.newsAnalysisEndpoint;
      debugPrint('请求消息面分析报告: $url');
      
      // 准备请求体
      final requestBody = {
        'force_refresh': forceRefresh,
        'ai_model_name': aiModelName,
        'ai_endpoint': aiEndpoint,
        'ai_api_key': aiApiKey,
      };
      
      // 使用HttpClient.post替代http.post，确保添加API Token
      final response = await HttpClient.post(url, requestBody);
      
      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        debugPrint('消息面分析响应原始数据: ${responseBody.substring(0, responseBody.length > 200 ? 200 : responseBody.length)}...');
        final data = json.decode(responseBody);
        debugPrint('成功获取消息面分析报告');
        
        // 保存到缓存
        _newsAnalysisCache = data;
        _newsAnalysisCacheTime = now;
        
        return data;
      } else {
        debugPrint('获取消息面分析报告失败: ${response.statusCode}, ${response.body}');
        return {
          'success': false,
          'message': '请求失败，状态码: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('获取消息面分析报告出错: $e');
      return {
        'success': false,
        'message': '发生错误: $e',
      };
    }
  }
  
  // 清除消息面分析缓存
  void clearNewsAnalysisCache() {
    _newsAnalysisCache = null;
    _newsAnalysisCacheTime = null;
    debugPrint('消息面分析缓存已清除');
  }
  
  // 获取最新财经资讯
  Future<List<Map<String, dynamic>>> getLatestFinanceNews() async {
    try {
      const url = ApiConfig.latestNewsEndpoint;
      debugPrint('请求最新财经资讯: $url');
      
      // 使用HttpClient.get替代http.get，确保添加API Token
      final response = await HttpClient.get(url);
      
      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        debugPrint('最新财经资讯响应数据: ${responseBody.substring(0, responseBody.length > 100 ? 100 : responseBody.length)}...');
        final data = json.decode(responseBody);
        
        List<Map<String, dynamic>> newsList = [];
        
        // 尝试从数据中提取新闻列表
        if (data.containsKey('data') && data['data'] is Map<String, dynamic> && data['data'].containsKey('news')) {
          newsList = List<Map<String, dynamic>>.from(data['data']['news']);
          debugPrint('获取到 ${newsList.length} 条最新财经资讯');
        } else if (data.containsKey('news') && data['news'] is List) {
          newsList = List<Map<String, dynamic>>.from(data['news']);
          debugPrint('获取到 ${newsList.length} 条最新财经资讯');
        } else {
          debugPrint('未找到有效的新闻列表数据');
        }
        
        return newsList;
      } else {
        debugPrint('获取最新财经资讯失败: ${response.statusCode}, ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('获取最新财经资讯出错: $e');
      return [];
    }
  }

  // 批量获取股票实时价格
  Future<List<Map<String, dynamic>>> getBatchStockPrices(List<String> stockCodes) async {
    if (stockCodes.isEmpty) return [];
    
    try {
      // 将股票代码列表转换为逗号分隔的字符串
      final codesParam = stockCodes.join(',');
      final url = '${ApiConfig.stockBatchPriceEndpoint}?codes=$codesParam';
      debugPrint('批量获取股票价格: $url');
      
      final response = await HttpClient.get(url);
      
      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        final data = json.decode(responseBody);
        
        List<Map<String, dynamic>> priceData = [];
        
        // 处理不同的响应格式
        if (data is List) {
          priceData = List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data.containsKey('data') && data['data'] is List) {
          priceData = List<Map<String, dynamic>>.from(data['data']);
        } else if (data is Map && data.containsKey('stocks') && data['stocks'] is List) {
          priceData = List<Map<String, dynamic>>.from(data['stocks']);
        }
        
        debugPrint('批量获取到 ${priceData.length} 只股票的价格信息');
        return priceData;
      } else {
        debugPrint('批量获取股票价格失败: ${response.statusCode}, ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('批量获取股票价格出错: $e');
      return [];
    }
  }

  // 单独获取股票实时价格（备用方法）
  Future<Map<String, dynamic>?> getStockRealTimePrice(String stockCode) async {
    try {
      final url = '${ApiConfig.stockRealTimePriceEndpoint}/$stockCode/price';
      debugPrint('获取股票实时价格: $url');
      
      final response = await HttpClient.get(url);
      
      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        final data = json.decode(responseBody);
        debugPrint('获取到股票 $stockCode 的实时价格');
        return data;
      } else {
        debugPrint('获取股票实时价格失败: ${response.statusCode}, ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('获取股票实时价格出错: $e');
      return null;
    }
  }

  // 获取市场类型列表
  Future<List<Map<String, dynamic>>> getMarketTypes() async {
    try {
      final url = '$apiBaseUrl/market-types';
      debugPrint('获取市场类型列表: $url');
      
      final response = await HttpClient.get(url);
      
      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        final data = json.decode(responseBody);
        
        // 检查响应格式
        if (data is Map && data['code'] == 200 && data['data'] != null) {
          final marketData = data['data'] as Map<String, dynamic>;
          final marketTypes = marketData['market_types'] as List<dynamic>;
          debugPrint('获取到 ${marketTypes.length} 个市场类型');
          return List<Map<String, dynamic>>.from(marketTypes);
        } else {
          debugPrint('市场类型数据格式不正确');
          return _getDefaultMarketTypes();
        }
      } else {
        debugPrint('获取市场类型失败: ${response.statusCode}, ${response.body}');
        return _getDefaultMarketTypes();
      }
    } catch (e) {
      debugPrint('获取市场类型出错: $e');
      return _getDefaultMarketTypes();
    }
  }

  // 默认市场类型列表（降级方案）
  List<Map<String, dynamic>> _getDefaultMarketTypes() {
    return [
      {'code': 'all', 'name': '全部'},
      {'code': 'main_board', 'name': '主板'},
      {'code': 'gem', 'name': '创业板'},
      {'code': 'star', 'name': '科创板'},
      {'code': 'bse', 'name': '北交所'},
      {'code': 'etf', 'name': 'ETF'},
    ];
  }
}

// 缓存的新闻数据类
class _CachedNewsData {
  final DateTime timestamp;
  final List<Map<String, dynamic>> newsList;
  
  _CachedNewsData({
    required this.timestamp,
    required this.newsList,
  });
} 