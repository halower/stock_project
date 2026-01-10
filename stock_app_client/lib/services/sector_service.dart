// 板块分析服务

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/sector.dart';
import '../config/api_config.dart';

class SectorService {
  static const String baseUrl = ApiConfig.apiBaseUrl;

  /// 获取板块列表
  static Future<List<Sector>> getSectorList({String exchange = 'A'}) async {
    try {
      final url = Uri.parse('$baseUrl/sector/list?exchange=$exchange');
      final response = await http.get(
        url,
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          final List<dynamic> sectorList = data['data'];
          return sectorList.map((json) => Sector.fromJson(json)).toList();
        } else {
          throw Exception(data['error'] ?? '获取板块列表失败');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      debugPrint('获取板块列表失败: $e');
      rethrow;
    }
  }

  /// 获取板块成分股
  static Future<List<SectorMember>> getSectorMembers(String sectorCode) async {
    try {
      final url = Uri.parse('$baseUrl/sector/$sectorCode/members');
      final response = await http.get(
        url,
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          final List<dynamic> memberList = data['data'];
          return memberList.map((json) => SectorMember.fromJson(json)).toList();
        } else {
          throw Exception(data['error'] ?? '获取成分股失败');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      debugPrint('获取板块成分股失败: $e');
      rethrow;
    }
  }

  /// 获取板块强度
  static Future<SectorStrength> getSectorStrength(String sectorCode) async {
    try {
      final url = Uri.parse('$baseUrl/sector/$sectorCode/strength');
      final response = await http.get(
        url,
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          return SectorStrength.fromJson(data);
        } else {
          throw Exception(data['error'] ?? '获取板块强度失败');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      debugPrint('获取板块强度失败: $e');
      rethrow;
    }
  }

  /// 获取板块排名
  static Future<List<SectorRanking>> getSectorRanking({
    String rankType = 'change',
    int limit = 50,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/sector/ranking?rank_type=$rankType&limit=$limit');
      final response = await http.get(
        url,
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          final List<dynamic> rankingList = data['data'];
          return rankingList.map((json) => SectorRanking.fromJson(json)).toList();
        } else {
          throw Exception(data['error'] ?? '获取板块排名失败');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      debugPrint('获取板块排名失败: $e');
      rethrow;
    }
  }

  /// 获取热门概念
  static Future<List<HotConcept>> getHotConcepts({int limit = 20}) async {
    try {
      final url = Uri.parse('$baseUrl/sector/hot-concepts?limit=$limit');
      final response = await http.get(
        url,
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          final List<dynamic> conceptList = data['data'];
          return conceptList.map((json) => HotConcept.fromJson(json)).toList();
        } else {
          throw Exception(data['error'] ?? '获取热门概念失败');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      debugPrint('获取热门概念失败: $e');
      rethrow;
    }
  }

  /// 获取板块详情
  static Future<Map<String, dynamic>> getSectorDetail(String sectorCode) async {
    try {
      final url = Uri.parse('$baseUrl/sector/$sectorCode/detail');
      final response = await http.get(
        url,
        headers: ApiConfig.headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          // 调试日志：检查API返回的原始数据
          final membersList = data['members'] as List;
          if (membersList.isNotEmpty) {
            debugPrint('📊 板块成分股原始数据: ${membersList[0]}');
          }
          
          final members = membersList
              .map((m) => SectorMember.fromJson(m))
              .toList();
          
          // 调试日志：检查解析后的数据
          if (members.isNotEmpty) {
            debugPrint('📊 解析后: name=${members[0].name}, price=${members[0].price}, changePct=${members[0].changePct}');
          }
          
          return {
            'members': members,
            'strength': data['strength'] != null
                ? SectorStrength.fromJson(data['strength'])
                : null,
            'member_count': data['member_count'] ?? 0,
          };
        } else {
          throw Exception(data['error'] ?? '获取板块详情失败');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      debugPrint('获取板块详情失败: $e');
      rethrow;
    }
  }
}

