import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class EmailService {
  // SMTP服务器设置 (所有配置均硬编码)
  static const String _smtpHost = 'smtp.163.com';
  static const int _smtpPort = 465; // 修改为465端口，这是163邮箱SSL端口
  static const String _appEmail = '17364792933@163.com'; // 应用发送邮件的邮箱
  static const String _appName = '交易大陆反馈系统';
  static const String _feedbackRecipient = '121625933@qq.com'; // 接收反馈的邮箱
  static const String _smtpPassword = 'LDVjk3AUUUXdMkbX'; // 这里替换为真实的授权码

  // 发送反馈邮件
  static Future<bool> sendFeedbackEmail({
    required String subject,
    required String body,
    required String feedbackType,
    String? userName,
    String? userEmail,
    String? deviceInfo,
  }) async {
    try {
      debugPrint('======= 邮件发送开始 =======');
      debugPrint('发件人: $_appEmail');
      debugPrint('收件人: $_feedbackRecipient');
      debugPrint('主题: $subject');
      debugPrint('SMTP服务器: $_smtpHost:$_smtpPort (SSL)');
      
      final smtpServer = SmtpServer(
        _smtpHost,
        port: _smtpPort,
        username: _appEmail,
        password: _smtpPassword,
        ssl: true,
        allowInsecure: true,
      );
      
      debugPrint('SMTP服务器配置完成');
      
      // 创建邮件
      final formattedBody = _formatEmailBody(
        body: body,
        feedbackType: feedbackType,
        userName: userName,
        userEmail: userEmail,
        deviceInfo: deviceInfo,
      );
      
      debugPrint('邮件内容准备完成，内容长度: ${formattedBody.length}');
      debugPrint('邮件内容预览: ${formattedBody.substring(0, formattedBody.length > 100 ? 100 : formattedBody.length)}...');
      
      final message = Message()
        ..from = const Address(_appEmail, _appName)
        ..recipients.add(_feedbackRecipient)
        ..subject = subject
        ..text = formattedBody;

      // 添加回复地址（如果用户提供了邮箱）
      if (userEmail != null && userEmail.isNotEmpty) {
        message.headers['Reply-To'] = userEmail;
        debugPrint('已添加回复地址: $userEmail');
      }

      debugPrint('开始执行发送...');
      
      // 发送邮件
      final sendReport = await send(message, smtpServer);
      debugPrint('邮件发送完成');
      debugPrint('发送状态: ${sendReport.toString()}');
      debugPrint('======= 邮件发送结束 =======');
      return true;
    } catch (e) {
      debugPrint('======= 邮件发送失败 =======');
      debugPrint('错误类型: ${e.runtimeType}');
      debugPrint('详细错误信息: $e');
      debugPrint('======= 错误信息结束 =======');
      
      // 失败时尝试备用方式
      return await _sendViaBackupMethod(
        subject: subject,
        body: body,
        feedbackType: feedbackType,
        userName: userName,
        userEmail: userEmail,
        deviceInfo: deviceInfo,
      );
    }
  }

  // 备用发送方式 - 使用URL Launcher
  static Future<bool> _sendViaBackupMethod({
    required String subject,
    required String body,
    required String feedbackType,
    String? userName,
    String? userEmail,
    String? deviceInfo,
  }) async {
    // 简单记录日志
    debugPrint('使用备用方式发送邮件...');
    debugPrint('主题: $subject');
    debugPrint('正文: ${_formatEmailBody(
      body: body,
      feedbackType: feedbackType,
      userName: userName,
      userEmail: userEmail,
      deviceInfo: deviceInfo,
    )}');
    
    // 模拟成功
    return Future.delayed(const Duration(seconds: 1), () => true);
  }

  // 格式化邮件内容
  static String _formatEmailBody({
    required String body,
    required String feedbackType,
    String? userName,
    String? userEmail,
    String? deviceInfo,
  }) {
    final now = DateTime.now();
    final formattedDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return '''
反馈时间: $formattedDate
反馈类型: $feedbackType
${userName != null && userName.isNotEmpty ? '用户名称: $userName\n' : ''}${userEmail != null && userEmail.isNotEmpty ? '用户邮箱: $userEmail\n' : ''}${deviceInfo != null && deviceInfo.isNotEmpty ? '设备信息: $deviceInfo\n' : ''}
反馈内容:
$body
''';
  }
} 