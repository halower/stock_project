// 估值分析服务

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/valuation.dart';
import '../config/api_config.dart';

class ValuationService {
  static const String baseUrl = ApiConfig.apiBaseUrl;

  /// 估值分析筛选
  static Future<List<ValuationData>> screeningByValuation({
    ValuationFilters? filters,
    int limit = 100,
  }) async {
    try {
      final queryParams = filters?.toQueryParams() ?? {};
      queryParams['limit'] = limit.toString();

      final uri = Uri.parse('$baseUrl/valuation/screening').replace(
        queryParameters: queryParams,
      );

      final response = await http.get(
        uri,
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          final List<dynamic> resultList = data['data'];
          return resultList.map((json) => ValuationData.fromJson(json)).toList();
        } else {
          throw Exception(data['error'] ?? '估值分析失败');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      debugPrint('估值分析失败: $e');
      rethrow;
    }
  }

  /// 获取估值排名
  static Future<List<ValuationData>> getValuationRanking({
    String rankBy = 'pe',
    String order = 'asc',
    int limit = 100,
  }) async {
    try {
      final url = Uri.parse(
        '$baseUrl/valuation/ranking?rank_by=$rankBy&order=$order&limit=$limit',
      );

      final response = await http.get(
        url,
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          final List<dynamic> resultList = data['data'];
          return resultList.map((json) => ValuationData.fromJson(json)).toList();
        } else {
          throw Exception(data['error'] ?? '获取估值排名失败');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      debugPrint('获取估值排名失败: $e');
      rethrow;
    }
  }

  /// 获取个股估值详情
  static Future<ValuationDetail> getStockValuationDetail(String stockCode) async {
    try {
      final url = Uri.parse('$baseUrl/valuation/$stockCode/detail');

      final response = await http.get(
        url,
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          return ValuationDetail.fromJson(data);
        } else {
          throw Exception(data['error'] ?? '获取估值详情失败');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      debugPrint('获取估值详情失败: $e');
      rethrow;
    }
  }

  /// 低估值蓝筹筛选（预设）
  static Future<List<ValuationData>> getLowValueBlueChip({int limit = 50}) async {
    try {
      final url = Uri.parse('$baseUrl/valuation/preset/low-value-blue-chip?limit=$limit');

      final response = await http.get(
        url,
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          final List<dynamic> resultList = data['data'];
          return resultList.map((json) => ValuationData.fromJson(json)).toList();
        } else {
          throw Exception(data['error'] ?? '筛选失败');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      debugPrint('低估值蓝筹筛选失败: $e');
      rethrow;
    }
  }

  /// 高股息股票筛选（预设）
  static Future<List<ValuationData>> getHighDividendStocks({int limit = 50}) async {
    try {
      final url = Uri.parse('$baseUrl/valuation/preset/high-dividend?limit=$limit');

      final response = await http.get(
        url,
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          final List<dynamic> resultList = data['data'];
          return resultList.map((json) => ValuationData.fromJson(json)).toList();
        } else {
          throw Exception(data['error'] ?? '筛选失败');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      debugPrint('高股息股票筛选失败: $e');
      rethrow;
    }
  }

  /// 成长价值股筛选（预设）
  static Future<List<ValuationData>> getGrowthValueStocks({int limit = 50}) async {
    try {
      final url = Uri.parse('$baseUrl/valuation/preset/growth-value?limit=$limit');

      final response = await http.get(
        url,
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          final List<dynamic> resultList = data['data'];
          return resultList.map((json) => ValuationData.fromJson(json)).toList();
        } else {
          throw Exception(data['error'] ?? '筛选失败');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      debugPrint('成长价值股筛选失败: $e');
      rethrow;
    }
  }
}

