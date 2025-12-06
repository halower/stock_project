import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';

/// HTTP客户端工具类，用于处理所有HTTP请求，自动添加认证Token
class HttpClient {
  /// 获取带有认证Token的HTTP请求头
  static Map<String, String> getHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    // 如果启用了API Token认证，添加Token到请求头
    if (ApiConfig.apiTokenEnabled) {
      headers[ApiConfig.apiTokenHeaderName] = ApiConfig.apiToken;
    }
    
    return headers;
  }
  
  /// 发送GET请求
  static Future<http.Response> get(String url, {Map<String, String>? extraHeaders}) async {
    try {
      final uri = Uri.parse(url);
      final headers = getHeaders();
      
      // 合并额外的请求头
      if (extraHeaders != null) {
        headers.addAll(extraHeaders);
      }
      
      // 仅在开发模式下输出详细日志
      if (kDebugMode) {
        debugPrint('GET请求: $url');
      }
      
      final response = await http.get(
        uri,
        headers: headers,
      ).timeout(
        const Duration(seconds: 120),
        onTimeout: () {
          debugPrint('GET请求超时: $url');
          throw Exception('请求超时');
        },
      );
      
      _logResponse(response);
      return response;
    } catch (e) {
      debugPrint('GET请求出错: $e');
      rethrow;
    }
  }
  
  /// 发送POST请求
  static Future<http.Response> post(
    String url, 
    dynamic body, 
    {Map<String, String>? extraHeaders}
  ) async {
    try {
      final uri = Uri.parse(url);
      final headers = getHeaders();
      
      // 合并额外的请求头
      if (extraHeaders != null) {
        headers.addAll(extraHeaders);
      }
      
      // 将请求体转换为JSON字符串
      final jsonBody = json.encode(body);
      
      debugPrint('POST请求: $url');
      debugPrint('请求头: $headers');
      debugPrint('请求体: $jsonBody');
      
      final response = await http.post(
        uri,
        headers: headers,
        body: jsonBody,
      ).timeout(
        const Duration(seconds: 120),
        onTimeout: () {
          debugPrint('POST请求超时: $url');
          throw Exception('请求超时');
        },
      );
      
      _logResponse(response);
      return response;
    } catch (e) {
      debugPrint('POST请求出错: $e');
      rethrow;
    }
  }
  
  /// 发送PUT请求
  static Future<http.Response> put(
    String url, 
    dynamic body, 
    {Map<String, String>? extraHeaders}
  ) async {
    try {
      final uri = Uri.parse(url);
      final headers = getHeaders();
      
      // 合并额外的请求头
      if (extraHeaders != null) {
        headers.addAll(extraHeaders);
      }
      
      // 将请求体转换为JSON字符串
      final jsonBody = json.encode(body);
      
      debugPrint('PUT请求: $url');
      debugPrint('请求头: $headers');
      debugPrint('请求体: $jsonBody');
      
      final response = await http.put(
        uri,
        headers: headers,
        body: jsonBody,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('PUT请求超时: $url');
          throw Exception('请求超时');
        },
      );
      
      _logResponse(response);
      return response;
    } catch (e) {
      debugPrint('PUT请求出错: $e');
      rethrow;
    }
  }
  
  /// 发送DELETE请求
  static Future<http.Response> delete(
    String url, 
    {Map<String, String>? extraHeaders}
  ) async {
    try {
      final uri = Uri.parse(url);
      final headers = getHeaders();
      
      // 合并额外的请求头
      if (extraHeaders != null) {
        headers.addAll(extraHeaders);
      }
      
      debugPrint('DELETE请求: $url');
      debugPrint('请求头: $headers');
      
      final response = await http.delete(
        uri,
        headers: headers,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('DELETE请求超时: $url');
          throw Exception('请求超时');
        },
      );
      
      _logResponse(response);
      return response;
    } catch (e) {
      debugPrint('DELETE请求出错: $e');
      rethrow;
    }
  }
  
  /// 记录响应信息
  static void _logResponse(http.Response response) {
    // 仅在开发模式下输出详细日志
    if (kDebugMode) {
      debugPrint('响应状态码: ${response.statusCode}');
      
      if (response.statusCode == 401 || response.statusCode == 403) {
        debugPrint('认证失败: Token无效或未提供');
      }
      
      // 尝试解析响应体为JSON并记录
      if (response.body.isNotEmpty) {
        try {
          final responseBody = utf8.decode(response.bodyBytes);
          final truncatedBody = responseBody.length > 200 
              ? '${responseBody.substring(0, 200)}...' 
              : responseBody;
          debugPrint('响应体: $truncatedBody');
        } catch (e) {
          debugPrint('无法解析响应体: $e');
        }
      }
    }
  }
} 