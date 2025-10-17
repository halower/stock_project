import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

class PasswordLockService {
  // 密码锁相关的存储键
  static const String _passwordLockEnabledKey = 'password_lock_enabled';
  static const String _passwordHashKey = 'password_hash';
  static const String _lockTimeoutKey = 'password_lock_timeout'; // 单位：分钟
  
  // 获取密码锁是否启用
  static Future<bool> isPasswordLockEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_passwordLockEnabledKey) ?? false;
  }
  
  // 设置密码锁是否启用
  static Future<void> setPasswordLockEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_passwordLockEnabledKey, enabled);
  }
  
  // 设置密码
  static Future<bool> setPassword(String password) async {
    if (password.isEmpty) {
      return false;
    }
    
    try {
      final hash = _hashPassword(password);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_passwordHashKey, hash);
      return true;
    } catch (e) {
      debugPrint('设置密码失败: $e');
      return false;
    }
  }
  
  // 验证密码
  static Future<bool> verifyPassword(String password) async {
    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString(_passwordHashKey);
    
    if (storedHash == null) {
      return false;
    }
    
    final inputHash = _hashPassword(password);
    return inputHash == storedHash;
  }
  
  // 设置锁定超时时间（分钟）
  static Future<void> setLockTimeout(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lockTimeoutKey, minutes);
  }
  
  // 获取锁定超时时间（分钟）
  static Future<int> getLockTimeout() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_lockTimeoutKey) ?? 5; // 默认5分钟
  }
  
  // 清除密码
  static Future<void> clearPassword() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_passwordHashKey);
    await prefs.setBool(_passwordLockEnabledKey, false);
  }
  
  // 辅助方法：密码加密
  static String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
} 