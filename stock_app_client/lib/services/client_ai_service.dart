import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../services/ai_config_service.dart';
import '../utils/technical_indicators.dart';
import 'http_client.dart';

/// 客户端AI分析服务
/// 用于在客户端完成AI分析，不再调用后端接口
class ClientAIService {
  // 单例模式
  static final ClientAIService _instance = ClientAIService._internal();
  
  factory ClientAIService() {
    return _instance;
  }
  
  ClientAIService._internal() {
    debugPrint('ClientAIService初始化完成');
  }
  
  // 缓存前缀
  static const String _cachePrefix = 'ai_analysis_cache_';
  static const String _cacheTimePrefix = 'ai_analysis_time_';
  static const int _cacheValidityMinutes = 10; // 10分钟缓存

  /// 获取缓存键
  String _getCacheKey(String stockCode) {
    return '$_cachePrefix$stockCode';
  }

  /// 获取缓存时间键
  String _getCacheTimeKey(String stockCode) {
    return '$_cacheTimePrefix$stockCode';
  }

  /// 检查缓存是否存在且有效（10分钟内）- 公开方法
  Future<String?> getCachedAnalysis(String stockCode) async {
    return await _getCachedAnalysis(stockCode);
  }

  /// 检查缓存是否存在且有效（10分钟内）- 内部方法
  Future<String?> _getCachedAnalysis(String stockCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _getCacheKey(stockCode);
      final cacheTimeKey = _getCacheTimeKey(stockCode);
      
      final cachedData = prefs.getString(cacheKey);
      final cacheTimeStr = prefs.getString(cacheTimeKey);

      if (cachedData != null && cacheTimeStr != null) {
        final cacheTime = DateTime.parse(cacheTimeStr);
        final now = DateTime.now();
        final difference = now.difference(cacheTime).inMinutes;

        if (difference < _cacheValidityMinutes) {
          debugPrint('找到$stockCode的有效缓存分析报告（${difference}分钟前）');
          return cachedData;
        } else {
          debugPrint('$stockCode的缓存已过期（${difference}分钟前），清除缓存');
          await prefs.remove(cacheKey);
          await prefs.remove(cacheTimeKey);
        }
      }

      debugPrint('$stockCode没有有效的缓存分析报告');
      return null;
    } catch (e) {
      debugPrint('读取缓存失败: $e');
      return null;
    }
  }

  /// 保存分析结果到缓存（带时间戳）- 公开方法
  Future<void> saveAnalysisToCache(String stockCode, String analysis) async {
    return await _saveAnalysisToCache(stockCode, analysis);
  }

  /// 从后端查询是否有分析缓存
  Future<Map<String, dynamic>?> getRemoteAnalysisCache(String stockCode) async {
    try {
      final url = ApiConfig.getStockAIAnalysisCacheUrl(stockCode);
      debugPrint('查询后端分析缓存: $url');
      
      final response = await HttpClient.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('查询后端缓存超时');
          throw Exception('请求超时');
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        debugPrint('后端缓存查询响应: $jsonResponse');
        
        if (jsonResponse['success'] == true) {
          if (jsonResponse['has_cache'] == true && jsonResponse['analysis'] != null) {
            final analysis = jsonResponse['analysis'] as String;
            debugPrint('后端找到分析缓存，长度: ${analysis.length}');
            return {
              'has_cache': true,
              'analysis': analysis,
              'from_cache': jsonResponse['from_cache'] ?? true,
            };
          } else {
            debugPrint('后端没有该股票的分析缓存');
            return {
              'has_cache': false,
              'analysis': null,
            };
          }
        }
        
        return null;
      } else {
        debugPrint('查询后端缓存失败: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('查询后端分析缓存出错: $e');
      return null;
    }
  }

  /// 保存分析结果到缓存（带时间戳）- 内部方法
  Future<void> _saveAnalysisToCache(String stockCode, String analysis) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _getCacheKey(stockCode);
      final cacheTimeKey = _getCacheTimeKey(stockCode);
      final now = DateTime.now().toIso8601String();
      
      await prefs.setString(cacheKey, analysis);
      await prefs.setString(cacheTimeKey, now);
      debugPrint('已保存$stockCode的分析报告到缓存（10分钟有效期）');
    } catch (e) {
      debugPrint('保存缓存失败: $e');
    }
  }

  /// 清除特定股票的缓存
  Future<void> clearStockCache(String stockCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _getCacheKey(stockCode);
      final cacheTimeKey = _getCacheTimeKey(stockCode);
      await prefs.remove(cacheKey);
      await prefs.remove(cacheTimeKey);
      debugPrint('已清除$stockCode的AI分析缓存');
    } catch (e) {
      debugPrint('清除股票缓存失败: $e');
    }
  }

  /// 清除所有AI分析缓存
  Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final cacheKeys = keys.where((key) => 
          key.startsWith(_cachePrefix) || key.startsWith(_cacheTimePrefix)).toList();

      for (final key in cacheKeys) {
        await prefs.remove(key);
      }

      debugPrint('已清除所有AI分析缓存，共${cacheKeys.length}条');
    } catch (e) {
      debugPrint('清除所有缓存失败: $e');
    }
  }

  /// 获取股票AI分析（流式响应，支持缓存）
  Stream<Map<String, dynamic>> getStockAnalysisStream(
      String stockCode, String stockName,
      {bool forceRefresh = false}) async* {
    // 返回状态更新
    yield {
      'status': 'start',
      'message': '开始分析 $stockName ($stockCode)',
    };
    
    try {
      // 如果不是强制刷新，先检查缓存
      if (!forceRefresh) {
        yield {
          'status': 'checking_cache',
          'message': '检查本地缓存...',
        };

        final cachedAnalysis = await _getCachedAnalysis(stockCode);
        if (cachedAnalysis != null) {
          yield {
            'status': 'completed',
            'message': '从缓存加载分析报告',
            'analysis': cachedAnalysis,
            'from_cache': true,
          };
          return;
        }
      } else {
        // 强制刷新时清除缓存
        await clearStockCache(stockCode);
      }

      // 请求股票历史数据
      yield {
        'status': 'fetching_data',
        'message': '正在获取历史数据...',
      };
    
      debugPrint('开始获取股票历史数据: $stockCode');
      final stockData = await _fetchStockHistoryData(stockCode);
      debugPrint('股票历史数据获取完成: $stockCode');
    
      // 检查是否成功获取历史数据 - API返回的是data字段，不是history字段
      if (stockData['data'] is! List || (stockData['data'] as List).isEmpty) {
        debugPrint('历史数据验证失败: ${stockData.keys}');
    yield {
          'status': 'error',
          'message': '无法获取足够的历史数据进行分析',
    };
        return;
      }

      debugPrint('历史数据验证成功，数据条数: ${(stockData['data'] as List).length}');

      // 检查AI配置
      yield {
        'status': 'checking_ai_config',
        'message': '检查AI配置...',
      };

      final hasValidConfig = await AIConfigService.hasValidConfig();
      final isAdmin = await AIConfigService.isCurrentUserAdmin();
      
      debugPrint('AI配置检查结果 - 有效配置: $hasValidConfig, 管理员: $isAdmin');

      if (!hasValidConfig && !isAdmin) {
        // 普通用户且没有有效配置，需要先配置AI服务
        yield {
          'status': 'config_required',
          'message': '需要配置AI服务',
          'is_admin': false,
        };
        return;
      }
      
      // 开始AI分析
      yield {
        'status': 'analyzing',
        'message': '正在进行AI分析...',
      };
      
      // 调用AI分析
      final analysisText =
          await _generateAIAnalysisReport(stockCode, stockName, stockData, forceRefresh: forceRefresh);

      // 检查AI分析是否成功
      if (analysisText.isEmpty) {
        yield {
          'status': 'error',
          'message': 'AI分析服务暂时不可用，请检查AI配置或稍后重试',
        };
        return;
      }

      // 保存到缓存
      await _saveAnalysisToCache(stockCode, analysisText);
      
      // 分析完成
      yield {
        'status': 'completed',
        'message': '分析完成',
        'analysis': analysisText,
        'from_cache': false,
      };
    } catch (e) {
      debugPrint('AI分析出错: $e');
      yield {
        'status': 'error',
        'message': '生成分析报告失败: $e',
      };
    }
  }
  
  /// 获取股票历史数据 - 使用完整路径API
  Future<Map<String, dynamic>> _fetchStockHistoryData(String stockCode) async {
    try {
      // 使用完整路径API，stock_code作为查询参数
      final url = ApiConfig.getStockHistoryUrl(stockCode);
      debugPrint('请求股票历史数据: $url');
      
      // 添加超时控制和更详细的错误处理
      final response = await HttpClient.get(url).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('获取股票历史数据超时: $url');
          throw Exception('请求超时，请检查网络连接');
        },
      );

      debugPrint('收到股票历史数据响应，状态码: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        debugPrint('响应体长度: ${responseBody.length}');
        
        final data = json.decode(responseBody);
        
        // API返回的是data字段，不是history字段
        if (data.containsKey('data') && data['data'] is List) {
          final dataList = data['data'] as List<dynamic>;
          debugPrint('获取到股票历史数据，含${dataList.length}条记录');
          
          // 验证数据格式
          if (dataList.isNotEmpty) {
            debugPrint('数据样本: ${dataList.first}');
          }
          
        return data;
        } else {
          debugPrint('获取到股票历史数据，但格式不符合预期: ${data.keys}');
          return {'data': []};
        }
      } else {
        debugPrint('获取股票历史数据失败: ${response.statusCode}');
        debugPrint('错误响应: ${response.body}');
        return {'data': []};
      }
    } catch (e, stackTrace) {
      debugPrint('获取股票历史数据出错: $e');
      debugPrint('错误堆栈: $stackTrace');
      return {'data': []};
    }
  }
  
  /// 使用AI生成股票分析报告 - 新的POST接口
  Future<String> _generateAIAnalysisReport(String stockCode, String stockName,
      Map<String, dynamic> stockData, {bool forceRefresh = false}) async {
    try {
      debugPrint('开始通过AI分析股票: $stockCode ($stockName)');
      
      // 在客户端计算技术指标
      final indicators = _calculateTechnicalIndicators(stockData);
      debugPrint('技术指标计算完成: ${indicators.keys}');
      
      // 调用新的POST接口,传入计算好的指标
      final response = await _callAIAnalysisPostAPI(stockCode, stockData, indicators, forceRefresh: forceRefresh);
      
        if (response.isNotEmpty) {
        debugPrint('AI分析完成，生成报告长度: ${response.length}');
          return response;
      } else {
        debugPrint('AI服务返回空结果');
        return '';
      }
    } catch (e) {
      debugPrint('AI分析生成失败: $e');
      return '';
    }
  }

  /// 调用新的AI分析POST接口
  Future<String> _callAIAnalysisPostAPI(String stockCode, Map<String, dynamic> stockData, 
      Map<String, dynamic> indicators, {bool forceRefresh = false}) async {
    try {
      // 获取有效的AI配置
      final effectiveUrl = await AIConfigService.getEffectiveUrl();
      final effectiveApiKey = await AIConfigService.getEffectiveApiKey();
      final effectiveModel = await AIConfigService.getEffectiveModel();

      // 检查配置是否有效
      if (effectiveUrl == null ||
          effectiveUrl.isEmpty ||
          effectiveApiKey == null ||
          effectiveApiKey.isEmpty) {
        throw Exception('AI配置无效，请先配置完整的API服务地址和API密钥');
      }

      // 构建POST请求URL
      final url = ApiConfig.getStockAIAnalysisPostUrl();
      debugPrint('调用AI分析POST接口: $url');

      // 构建请求体（包含计算好的技术指标）
      final requestBody = {
        'stock_code': stockCode,
        'force_refresh': forceRefresh,
        'ai_model_name': effectiveModel,
        'ai_endpoint': effectiveUrl,
        'ai_api_key': effectiveApiKey,
        'indicators': indicators,  // 传入计算好的技术指标
      };

      debugPrint('POST请求体（含技术指标）: indicators=${indicators.keys}');

      final response = await HttpClient.post(url, requestBody);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final content = jsonResponse['analysis'] as String? ?? '';
        debugPrint('成功获取AI分析响应，内容长度: ${content.length}');
        return content;
      } else {
        debugPrint('AI分析POST接口调用失败: ${response.statusCode}');
        debugPrint('错误响应: ${response.body}');
        throw Exception('AI分析接口调用失败: HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('调用AI分析POST接口出错: $e');
      throw e;
    }
  }

  /// 直接调用AI服务（保留作为备用方案）
  Future<String> _callAIService(
      String prompt, String stockCode, String stockName) async {
    try {
      // 获取有效的AI配置
      final effectiveUrl = await AIConfigService.getEffectiveUrl();
      final effectiveApiKey = await AIConfigService.getEffectiveApiKey();
      final effectiveModel = await AIConfigService.getEffectiveModel();
          
      // 检查配置是否有效
      if (effectiveUrl == null ||
          effectiveUrl.isEmpty ||
          effectiveApiKey == null ||
          effectiveApiKey.isEmpty) {
        throw Exception('AI配置无效，请先配置完整的API服务地址和API密钥');
      }
          
      debugPrint('调用AI服务: $effectiveUrl');
      
      final requestBody = {
        'model': effectiveModel,
        'messages': [
          {
            'role': 'user',
            'content': prompt,
          }
        ],
        'stream': false,
        'max_tokens': 2048,
        'temperature': 0.7,
      };
      
      final response = await http.post(
        Uri.parse(effectiveUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $effectiveApiKey',
        },
        body: jsonEncode(requestBody),
      );
      
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final content =
            jsonResponse['choices'][0]['message']['content'] as String? ?? '';
        debugPrint('成功获取AI响应，内容长度: ${content.length}');
        return content;
      } else {
        debugPrint('AI API调用失败: ${response.statusCode}');
        debugPrint('错误响应: ${response.body}');
        throw Exception('AI API调用失败: HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('调用AI服务出错: $e');
      throw e;
    }
  }
  
  /// 客户端计算技术指标
  Map<String, dynamic> _calculateTechnicalIndicators(Map<String, dynamic> stockData) {
    if (!stockData.containsKey('data') || stockData['data'] is! List || (stockData['data'] as List).isEmpty) {
      return {};
    }

    final List<dynamic> history = stockData['data'];
    
    // 提取价格和成交量数据
    final closes = history.map((item) => (item['close'] as num?)?.toDouble() ?? 0.0).toList();
    final highs = history.map((item) => (item['high'] as num?)?.toDouble() ?? 0.0).toList();
    final lows = history.map((item) => (item['low'] as num?)?.toDouble() ?? 0.0).toList();
    final volumes = history.map((item) => (item['volume'] as num?)?.toDouble() ?? 0.0).toList();
    
    // 导入技术指标工具类
    final indicators = <String, dynamic>{};
    
    try {
      // 计算EMA均线
      final ema5 = TechnicalIndicators.calculateEMA(closes, 5);
      final ema10 = TechnicalIndicators.calculateEMA(closes, 10);
      final ema20 = TechnicalIndicators.calculateEMA(closes, 20);
      final ema60 = TechnicalIndicators.calculateEMA(closes, 60);
      
      indicators['ema'] = {
        'ema5': ema5.first,
        'ema10': ema10.first,
        'ema20': ema20.first,
        'ema60': ema60.first,
      };
      
      // 判断趋势
      indicators['trend'] = TechnicalIndicators.analyzeTrend(
        ema5.first, ema10.first, ema20.first, ema60.first
      );
      
      // 计算RSI
      final rsi = TechnicalIndicators.calculateRSI(closes);
      indicators['rsi'] = {
        'value': rsi.first,
        'status': TechnicalIndicators.analyzeRSI(rsi.first),
      };
      
      // 计算MACD
      final macdData = TechnicalIndicators.calculateMACD(closes);
      indicators['macd'] = {
        'macd': macdData['macd']?.first,
        'signal': macdData['signal']?.first,
        'histogram': macdData['histogram']?.first,
        'status': TechnicalIndicators.analyzeMACDSignal(
          macdData['macd']?.first,
          macdData['signal']?.first,
          macdData['histogram']?.first,
        ),
      };
      
      // 计算布林带
      final boll = TechnicalIndicators.calculateBollingerBands(closes);
      indicators['boll'] = {
        'upper': boll['upper']?.first,
        'middle': boll['middle']?.first,
        'lower': boll['lower']?.first,
      };
      
      // 计算ATR
      final atr = TechnicalIndicators.calculateATR(highs, lows, closes);
      indicators['atr'] = atr.first;
      
      // 计算支撑阻力位
      final sr = TechnicalIndicators.calculateSupportResistance(highs, lows);
      indicators['support_resistance'] = sr;
      
      // 添加当前价格信息
      indicators['current'] = {
        'price': closes.first,
        'high': highs.first,
        'low': lows.first,
        'volume': volumes.first,
      };
      
      debugPrint('技术指标计算完成');
    } catch (e) {
      debugPrint('计算技术指标出错: $e');
    }
    
    return indicators;
  }
  
  /// 构建专业的A股日线技术分析提示词
  String _buildAnalysisPromptWithData(
      String stockCode, String stockName, Map<String, dynamic> stockData) {
    final StringBuffer prompt = StringBuffer();
    
    prompt.write('''
你是一位资深的A股技术分析师，请对股票 $stockName ($stockCode) 进行专业的日线技术分析。

''');

    // 添加历史数据概要（如果有）
    if (stockData.containsKey('data') &&
        stockData['data'] is List &&
        stockData['data'].isNotEmpty) {
      prompt.write('## 日线数据\n\n');
      
      final List<dynamic> history = stockData['data'];
      final int dataPoints = history.length;
      
      // 添加日线K线数据
      prompt.write(
          '### 近期日K线数据（最近${dataPoints > 20 ? 20 : dataPoints}个交易日）：\n\n');
      prompt.write('日期 | 开盘 | 收盘 | 最高 | 最低 | 成交量(万手) | 成交额(万元)\n');
      prompt
          .write('---- | ---- | ---- | ---- | ---- | --------- | ----------\n');
      
      // 选取最近的20个交易日数据
      final recentData = history.take(20).toList();
      for (var i = 0; i < recentData.length; i++) {
        final item = recentData[i];
        final date = item['trade_date'] ?? item['date'] ?? '';
        final volume = (item['volume'] ?? 0) / 10000; // 转换为万手
        final amount = (item['amount'] ?? 0) / 10000; // 转换为万元
        prompt.write(
            '$date | ${item['open']} | ${item['close']} | ${item['high']} | ${item['low']} | ${volume.toStringAsFixed(2)} | ${amount.toStringAsFixed(0)}\n');
      }
      
      // 计算技术指标基础数据
      if (dataPoints >= 5) {
        final prices = history
            .take(5)
            .map((item) => item['close'] as double? ?? 0.0)
            .toList();
        final volumes = history
            .take(5)
            .map((item) => item['volume'] as double? ?? 0.0)
            .toList();
        
        final latestPrice = prices[0];
        final priceChange = latestPrice - prices[1];
        final priceChangePercent =
            (priceChange / prices[1] * 100).toStringAsFixed(2);
        final avgVolume =
            volumes.reduce((a, b) => a + b) / volumes.length / 10000;

        prompt.write('\n### 基础数据：\n');
        prompt.write('- 最新收盘价：${latestPrice}元\n');
        prompt.write('- 日涨跌幅：${priceChangePercent}%\n');
        prompt.write('- 近5日平均成交量：${avgVolume.toStringAsFixed(0)}万手\n\n');
      }
    }
    
    prompt.write('''
## 请进行以下专业技术分析：

### 1. 价格走势分析
- **趋势判断**：分析日线级别的主要趋势（上升/下降/横盘整理）
- **波浪结构**：识别当前所处的波浪位置和形态特征
- **价格形态**：识别重要的K线组合形态（如头肩顶底、双顶双底、三角形等）
- **缺口分析**：是否存在跳空缺口，缺口性质和回补概率

### 2. 支撑阻力分析
- **关键支撑位**：计算并标注重要的支撑价位（至少3个层级）
- **关键阻力位**：计算并标注重要的阻力价位（至少3个层级）
- **心理价位**：分析整数关口等心理价位的技术意义
- **前期高低点**：标注历史重要高低点位的支撑阻力作用

### 3. 均线系统分析
- **短期均线**：MA5、MA10的走势和交叉情况
- **中期均线**：MA20、MA30的支撑阻力作用
- **长期均线**：MA60、MA120的趋势指导意义
- **均线排列**：多头/空头排列状态和变化趋势

### 4. 技术指标分析
- **MACD指标**：DIF、DEA数值，柱状线变化，金叉死叉信号
- **RSI指标**：当前数值，超买超卖判断，背离情况
- **KDJ指标**：K、D、J三线数值和交叉状态
- **BOLL指标**：布林带开口状态，价格位置，压力支撑

### 5. 成交量分析
- **量价关系**：分析价涨量增、价跌量缩等经典量价配合
- **成交量形态**：识别放量突破、缩量整理等形态
- **换手率分析**：评估市场活跃度和资金参与程度
- **量能背离**：价格与成交量的背离信号

### 6. 市场结构分析
- **级别划分**：日线级别的买卖点识别
- **结构破坏**：重要结构位的突破确认
- **回调预期**：正常回调的空间和时间预期
- **风险控制点**：关键的止损位设定建议

### 7. 操作策略建议
- **短线策略**：1-3日的交易机会和风险点
- **中线策略**：1-4周的持仓建议和目标位
- **仓位管理**：建议的仓位配置和加减仓时机
- **风险提示**：主要技术风险点和应对策略

## 输出要求：
1. 使用专业的技术分析术语，体现分析师水准
2. 提供具体的价位数据，不要模糊表述
3. 给出明确的操作建议和风险控制措施
4. 分析要客观中性，避免过度主观判断
5. 使用Markdown格式，结构清晰，重点突出
6. 每个技术指标都要给出具体数值和信号判断

请基于提供的日线数据进行深度技术分析，给出专业、实用的分析报告。
''');

    return prompt.toString();
  }
}