/// 打板分析服务
/// 获取涨跌停、龙虎榜、连板统计等数据

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/limit_board_data.dart';

class LimitBoardService {
  static const String _baseUrl = '${ApiConfig.apiBaseUrl}/limit-board';
  
  /// 获取请求头
  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (ApiConfig.apiTokenEnabled)
      ApiConfig.apiTokenHeaderName: ApiConfig.apiToken,
  };
  
  /// 获取涨停板列表
  static Future<List<LimitStock>> getUpLimitList({String? tradeDate}) async {
    try {
      var url = '$_baseUrl/up-limit';
      if (tradeDate != null) {
        url += '?trade_date=$tradeDate';
      }
      
      debugPrint('请求涨停板数据: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final list = (data['data'] as List<dynamic>? ?? [])
              .map((e) => LimitStock.fromJson(e as Map<String, dynamic>))
              .toList();
          debugPrint('获取涨停板数据成功: ${list.length}只');
          return list;
        }
      }
      
      debugPrint('获取涨停板数据失败: ${response.statusCode}');
      return [];
    } catch (e) {
      debugPrint('获取涨停板数据异常: $e');
      return [];
    }
  }
  
  /// 获取跌停板列表
  static Future<List<LimitStock>> getDownLimitList({String? tradeDate}) async {
    try {
      var url = '$_baseUrl/down-limit';
      if (tradeDate != null) {
        url += '?trade_date=$tradeDate';
      }
      
      debugPrint('请求跌停板数据: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final list = (data['data'] as List<dynamic>? ?? [])
              .map((e) => LimitStock.fromJson(e as Map<String, dynamic>))
              .toList();
          debugPrint('获取跌停板数据成功: ${list.length}只');
          return list;
        }
      }
      
      debugPrint('获取跌停板数据失败: ${response.statusCode}');
      return [];
    } catch (e) {
      debugPrint('获取跌停板数据异常: $e');
      return [];
    }
  }
  
  /// 获取龙虎榜数据
  static Future<List<TopListStock>> getTopList({String? tradeDate}) async {
    try {
      var url = '$_baseUrl/top-list';
      if (tradeDate != null) {
        url += '?trade_date=$tradeDate';
      }
      
      debugPrint('请求龙虎榜数据: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final list = (data['data'] as List<dynamic>? ?? [])
              .map((e) => TopListStock.fromJson(e as Map<String, dynamic>))
              .toList();
          debugPrint('获取龙虎榜数据成功: ${list.length}只');
          return list;
        }
      }
      
      debugPrint('获取龙虎榜数据失败: ${response.statusCode}');
      return [];
    } catch (e) {
      debugPrint('获取龙虎榜数据异常: $e');
      return [];
    }
  }
  
  /// 获取打板综合数据
  static Future<LimitBoardSummary?> getSummary({String? tradeDate}) async {
    try {
      var url = '$_baseUrl/summary';
      if (tradeDate != null) {
        url += '?trade_date=$tradeDate';
      }
      
      debugPrint('请求打板综合数据: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: _headers,
      ).timeout(const Duration(seconds: 60));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final summary = LimitBoardSummary.fromJson(data);
          debugPrint('获取打板综合数据成功: 涨停${summary.upLimitCount}只, 跌停${summary.downLimitCount}只');
          return summary;
        }
      }
      
      debugPrint('获取打板综合数据失败: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('获取打板综合数据异常: $e');
      return null;
    }
  }
  
  /// 获取连板统计
  static Future<Map<String, dynamic>?> getContinuousStats({String? tradeDate}) async {
    try {
      var url = '$_baseUrl/continuous-stats';
      if (tradeDate != null) {
        url += '?trade_date=$tradeDate';
      }
      
      debugPrint('请求连板统计: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          debugPrint('获取连板统计成功');
          return data;
        }
      }
      
      debugPrint('获取连板统计失败: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('获取连板统计异常: $e');
      return null;
    }
  }
  
  /// 获取游资明细
  static Future<List<HotMoneyDetail>> getHotMoneyDetail({String? tradeDate, String? tsCode}) async {
    try {
      var url = '$_baseUrl/hot-money-detail';
      final params = <String>[];
      if (tradeDate != null && tradeDate.isNotEmpty) {
        params.add('trade_date=$tradeDate');
      }
      if (tsCode != null && tsCode.isNotEmpty) {
        params.add('ts_code=$tsCode');
      }
      if (params.isNotEmpty) {
        url += '?${params.join('&')}';
      }
      
      debugPrint('请求游资明细: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> list = data['data'] ?? [];
          final hotMoneyList = list.map((e) => HotMoneyDetail.fromJson(e as Map<String, dynamic>)).toList();
          debugPrint('获取游资明细成功: ${hotMoneyList.length}条');
          return hotMoneyList;
        }
      }
      
      debugPrint('获取游资明细失败: ${response.statusCode}');
      return [];
    } catch (e) {
      debugPrint('获取游资明细异常: $e');
      return [];
    }
  }
}

