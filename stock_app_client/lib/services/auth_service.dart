import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'device_info_service.dart';

class AuthService {
  static const String _authCodeKey = 'auth_code';
  static const String _authExpiryKey = 'auth_expiry';
  static const String _isAdminKey = 'is_admin';
  static const String _deviceFingerprintKey = 'auth_device_fingerprint';
  static const String _masterKey = 'Abc@12345'; // 生成授权码的主密钥
  static const String _adminAuthCode = 'Qwe@1324bnm'; // 管理员固定授权码
  
  // 检查授权状态
  static Future<bool> isAuthorized() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 检查是否是管理员
    final isAdmin = prefs.getBool(_isAdminKey) ?? false;
    if (isAdmin) {
      debugPrint('管理员用户，授权有效');
      return true;
    }
    
    // 检查普通用户授权
    final authCode = prefs.getString(_authCodeKey);
    final authExpiry = prefs.getInt(_authExpiryKey);
    final savedDeviceFingerprint = prefs.getString(_deviceFingerprintKey);
    
    if (authCode == null) {
      debugPrint('授权检查失败：未找到授权码');
      return false;
    }
    
    if (authExpiry == null) {
      debugPrint('授权检查失败：未找到过期时间');
      return false;
    }
    
    // 首先检查存储的过期时间
    final now = DateTime.now().millisecondsSinceEpoch;
    final expiryDate = DateTime.fromMillisecondsSinceEpoch(authExpiry);
    final nowDate = DateTime.fromMillisecondsSinceEpoch(now);
    final remainingDays = (authExpiry - now) / (24 * 60 * 60 * 1000);
    
    debugPrint('授权检查: 当前时间=${nowDate.toString()}, 过期时间=${expiryDate.toString()}, 剩余天数=${remainingDays.toStringAsFixed(1)}');
    
    if (authExpiry <= now) {
      debugPrint('授权已过期（存储的过期时间）');
      return false;
    }
    
    // 获取当前设备指纹
    final currentDeviceFingerprint = await DeviceInfoService.getDeviceFingerprint();
    
    // 如果设备指纹不匹配，则授权无效
    if (savedDeviceFingerprint != null && 
        savedDeviceFingerprint.isNotEmpty && 
        savedDeviceFingerprint != currentDeviceFingerprint) {
      debugPrint('设备指纹不匹配：已存储的 $savedDeviceFingerprint，当前的 $currentDeviceFingerprint');
      return false;
    }
    
    // 最后验证授权码的完整性
    if (!_validateAuthCode(authCode)) {
      debugPrint('授权码验证失败');
      return false;
    }
    
    debugPrint('授权检查通过');
    return true;
  }
  
  // 检查是否是管理员
  static Future<bool> isAdmin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isAdminKey) ?? false;
  }
  
  // 验证授权码并保存
  static Future<bool> validateAndSaveAuthCode(String code) async {
    // 检查是否是管理员授权码
    if (code == _adminAuthCode) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isAdminKey, true);
      return true;
    }
    
    // 普通用户验证
    if (!_validateAuthCode(code)) {
      return false;
    }
    
    try {
      // 从授权码中提取过期时间和设备指纹
      final data = _decodeAuthCode(code);
      if (data == null) {
        return false;
      }
      
      final expiry = data['expiry'] as int;
      final prefs = await SharedPreferences.getInstance();
      
      // 获取当前设备指纹
      final currentDeviceFingerprint = await DeviceInfoService.getDeviceFingerprint();
      
      // 检查设备指纹的安全等级（降低要求）
      final securityLevel = await DeviceInfoService.getSecurityLevel();
      if (securityLevel < 2) {
        debugPrint('设备安全等级过低: $securityLevel，要求至少2级');
        return false;
      }
      
      // 检查授权码是否包含设备指纹信息
      final deviceFingerprint = data.containsKey('deviceId') ? data['deviceId'] as String : null;
      
      // 如果授权码绑定了设备指纹，验证是否匹配
      if (deviceFingerprint != null && deviceFingerprint.isNotEmpty) {
        if (deviceFingerprint != currentDeviceFingerprint) {
          debugPrint('设备标识不匹配：授权码绑定的设备 $deviceFingerprint，当前设备 $currentDeviceFingerprint');
          return false;
        }
        
        // 验证设备指纹的完整性
        if (!await _validateDeviceFingerprintIntegrity(currentDeviceFingerprint)) {
          debugPrint('设备指纹完整性验证失败');
          return false;
        }
        
        debugPrint('设备标识匹配成功！');
      } else {
        // 对于未绑定设备的授权码，记录警告日志
        debugPrint('警告：使用未绑定设备的授权码');
      }
      
      // 保存授权码、过期时间、设备指纹，并设置非管理员
      await prefs.setString(_authCodeKey, code);
      await prefs.setInt(_authExpiryKey, expiry);
      await prefs.setString(_deviceFingerprintKey, currentDeviceFingerprint);
      await prefs.setBool(_isAdminKey, false);
      
      // 记录授权绑定信息
      await _logAuthBinding(currentDeviceFingerprint, deviceFingerprint);
      
      debugPrint('授权码已绑定到设备: $currentDeviceFingerprint');
      return true;
    } catch (e) {
      debugPrint('保存授权码时出错: $e');
      return false;
    }
  }
  
  // 验证设备指纹完整性
  static Future<bool> _validateDeviceFingerprintIntegrity(String fingerprint) async {
    try {
      // 重新获取设备指纹并比较
      final freshFingerprint = await DeviceInfoService.getDeviceFingerprint();
      return fingerprint == freshFingerprint;
    } catch (e) {
      debugPrint('验证设备指纹完整性时出错: $e');
      return false;
    }
  }
  
  // 记录授权绑定信息
  static Future<void> _logAuthBinding(String currentFingerprint, String? authFingerprint) async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    final logEntry = {
      'timestamp': timestamp,
      'currentDevice': currentFingerprint,
      'authDevice': authFingerprint,
      'bindingType': authFingerprint != null ? 'device_bound' : 'device_free',
    };
    
    // 获取现有日志
    final existingLogs = prefs.getStringList('auth_binding_logs') ?? [];
    existingLogs.add(json.encode(logEntry));
    
    // 只保留最近10条记录
    if (existingLogs.length > 10) {
      existingLogs.removeAt(0);
    }
    
    await prefs.setStringList('auth_binding_logs', existingLogs);
  }
  
  // 生成普通授权码（不绑定设备）
  static String generateAuthCode(int months) {
    if (months <= 0 || months > 12) {
      throw ArgumentError('授权月数必须大于0且不超过12个月');
    }
    
    // 计算过期时间（当前时间 + 月数）
    final now = DateTime.now();
    // 使用正确的月份计算方式
    int targetYear = now.year;
    int targetMonth = now.month + months;
    
    // 处理月份超过12的情况
    while (targetMonth > 12) {
      targetYear++;
      targetMonth -= 12;
    }
    
    final expiry = DateTime(targetYear, targetMonth, now.day, now.hour, now.minute, now.second)
        .millisecondsSinceEpoch;
    
    // 添加调试信息
    final expiryDate = DateTime.fromMillisecondsSinceEpoch(expiry);
    debugPrint('生成授权码: 当前时间=${now.toString()}, 过期时间=${expiryDate.toString()}, 有效期=${months}个月');
    
    // 创建包含过期时间和随机数的数据
    final random = Random.secure();
    final randomInt = random.nextInt(1000000);
    final data = {
      'expiry': expiry,
      'random': randomInt,
    };
    
    return _encodeAuthData(data);
  }
  
  // 生成指定天数的授权码
  static String generateAuthCodeWithDays(int days) {
    if (days <= 0) {
      throw ArgumentError('授权天数必须大于0');
    }
    
    // 计算过期时间（当前时间 + 天数）
    final now = DateTime.now();
    final expiry = now.add(Duration(days: days)).millisecondsSinceEpoch;
    
    // 创建包含过期时间和随机数的数据
    final random = Random.secure();
    final randomInt = random.nextInt(1000000);
    final data = {
      'expiry': expiry,
      'random': randomInt,
    };
    
    return _encodeAuthData(data);
  }
  
  // 生成绑定设备的授权码
  static String generateAuthCodeWithDeviceId(int months, String deviceId) {
    if (months <= 0 || months > 12) {
      throw ArgumentError('授权月数必须大于0且不超过12个月');
    }
    
    if (deviceId.isEmpty) {
      throw ArgumentError('设备标识不能为空');
    }
    
    // 计算过期时间（当前时间 + 月数）
    final now = DateTime.now();
    // 使用正确的月份计算方式
    int targetYear = now.year;
    int targetMonth = now.month + months;
    
    // 处理月份超过12的情况
    while (targetMonth > 12) {
      targetYear++;
      targetMonth -= 12;
    }
    
    final expiry = DateTime(targetYear, targetMonth, now.day, now.hour, now.minute, now.second)
        .millisecondsSinceEpoch;
    
    // 创建包含过期时间、随机数和设备ID的数据
    final random = Random.secure();
    final randomInt = random.nextInt(1000000);
    final data = {
      'expiry': expiry,
      'random': randomInt,
      'deviceId': deviceId,
    };
    
    return _encodeAuthData(data);
  }
  
  // 生成绑定设备的指定天数授权码
  static String generateAuthCodeWithDeviceIdAndDays(int days, String deviceId) {
    if (days <= 0) {
      throw ArgumentError('授权天数必须大于0');
    }
    
    if (deviceId.isEmpty) {
      throw ArgumentError('设备标识不能为空');
    }
    
    // 计算过期时间（当前时间 + 天数）
    final now = DateTime.now();
    final expiry = now.add(Duration(days: days)).millisecondsSinceEpoch;
    
    // 创建包含过期时间、随机数和设备ID的数据
    final random = Random.secure();
    final randomInt = random.nextInt(1000000);
    final data = {
      'expiry': expiry,
      'random': randomInt,
      'deviceId': deviceId,
    };
    
    return _encodeAuthData(data);
  }
  
  // 编码授权数据为授权码
  static String _encodeAuthData(Map<String, dynamic> data) {
    // 将数据转为JSON字符串
    final jsonData = jsonEncode(data);
    
    // 基础加密：Base64编码
    final base64Data = base64.encode(utf8.encode(jsonData));
    
    // 添加HMAC校验，使用主密钥计算
    final hmac = _calculateHmac(base64Data);
    
    // 组合HMAC和数据，再次Base64编码
    final combined = '$hmac:$base64Data';
    final finalCode = base64.encode(utf8.encode(combined))
        .replaceAll('/', '_')  // 替换URL不安全字符
        .replaceAll('+', '-')
        .replaceAll('=', '');
        
    return finalCode;
  }
  
  // 验证授权码是否有效
  static bool _validateAuthCode(String code) {
    try {
      final data = _decodeAuthCode(code);
      if (data == null) {
        debugPrint('授权码解码失败');
        return false;
      }
      
      final expiry = data['expiry'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // 添加调试信息
      final expiryDate = DateTime.fromMillisecondsSinceEpoch(expiry);
      final nowDate = DateTime.fromMillisecondsSinceEpoch(now);
      final remainingDays = (expiry - now) / (24 * 60 * 60 * 1000);
      
      debugPrint('授权码验证: 当前时间=${nowDate.toString()}, 过期时间=${expiryDate.toString()}, 剩余天数=${remainingDays.toStringAsFixed(1)}');
      
      return expiry > now;
    } catch (e) {
      debugPrint('验证授权码时出错: $e');
      return false;
    }
  }
  
  // 从授权码解析数据
  static Map<String, dynamic>? _decodeAuthCode(String code) {
    try {
      // 替换回URL安全字符
      final safeCode = code
          .replaceAll('_', '/')
          .replaceAll('-', '+');
          
      // 添加必要的填充以满足Base64编码要求
      final padding = 4 - (safeCode.length % 4);
      final paddedCode = safeCode + ('=' * (padding == 4 ? 0 : padding));
      
      // 解码Base64
      final decodedBytes = base64.decode(paddedCode);
      final decodedString = utf8.decode(decodedBytes);
      
      // 分离HMAC和数据
      final parts = decodedString.split(':');
      if (parts.length != 2) {
        return null;
      }
      
      final hmac = parts[0];
      final base64Data = parts[1];
      
      // 验证HMAC
      final calculatedHmac = _calculateHmac(base64Data);
      if (hmac != calculatedHmac) {
        return null;
      }
      
      // 解码数据
      final jsonBytes = base64.decode(base64Data);
      final jsonString = utf8.decode(jsonBytes);
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      
      return data;
    } catch (e) {
      debugPrint('解析授权码时出错: $e');
      return null;
    }
  }
  
  // 计算HMAC值
  static String _calculateHmac(String data) {
    final key = utf8.encode(_masterKey);
    final bytes = utf8.encode(data);
    final hmacSha256 = Hmac(sha256, key);
    final digest = hmacSha256.convert(bytes);
    
    return digest.toString().substring(0, 8);  // 取前8个字符作为HMAC值
  }
  
  // 清除授权信息
  static Future<void> clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_authCodeKey);
    await prefs.remove(_authExpiryKey);
    await prefs.remove(_isAdminKey);
    await prefs.remove(_deviceFingerprintKey);
  }
  
  // 获取授权剩余天数，管理员返回-1表示永久
  static Future<int> getAuthRemainingDays() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 检查是否是管理员
      final isAdmin = prefs.getBool(_isAdminKey) ?? false;
      if (isAdmin) {
        return -1; // 表示永久授权
      }
      
      final authExpiry = prefs.getInt(_authExpiryKey);
      
      if (authExpiry == null) {
        return 0;
      }
      
      final now = DateTime.now().millisecondsSinceEpoch;
      if (authExpiry <= now) {
        return 0;
      }
      
      // 计算剩余天数
      final remainingMs = authExpiry - now;
      return (remainingMs / (24 * 60 * 60 * 1000)).ceil();
    } catch (e) {
      debugPrint('获取授权剩余天数时出错: $e');
      return 0;
    }
  }
  
  // 获取绑定的设备指纹
  static Future<String?> getBoundDeviceFingerprint() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_deviceFingerprintKey);
  }
  
  // 获取授权绑定日志
  static Future<List<Map<String, dynamic>>> getAuthBindingLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final logs = prefs.getStringList('auth_binding_logs') ?? [];
    
    return logs.map((log) {
      try {
        return json.decode(log) as Map<String, dynamic>;
      } catch (e) {
        return <String, dynamic>{'error': 'Invalid log entry'};
      }
    }).toList();
  }
} 