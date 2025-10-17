import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import '../services/email_service.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String _selectedType = '功能建议';
  bool _isSending = false;

  // 反馈类型列表
  final List<String> _feedbackTypes = [
    '功能建议',
    '问题报告',
    '使用咨询',
    '其他反馈'
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  // 发送邮件反馈
  Future<void> _sendFeedback() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      // 构建邮件内容
      final String emailSubject = '[$_selectedType] ${_titleController.text}';
      final String deviceInfo = '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
      
      // 使用邮件服务发送
      final bool sent = await EmailService.sendFeedbackEmail(
        subject: emailSubject,
        body: _contentController.text,
        feedbackType: _selectedType,
        userName: _nameController.text,
        userEmail: _emailController.text,
        deviceInfo: deviceInfo,
      );
      
      if (sent) {
        if (mounted) {
          // 发送成功
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('反馈已成功发送，感谢您的反馈！'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.green,
            ),
          );
          
          // 清空表单
          _nameController.clear();
          _emailController.clear();
          _titleController.clear();
          _contentController.clear();
          setState(() {
            _selectedType = '功能建议';
          });
        }
      } else {
        // 如果直接发送失败，尝试使用URL Launcher方式
        await _sendViaEmailApp(emailSubject, deviceInfo);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('发送反馈时出错: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }
  
  // 使用邮件应用发送（备用方案）
  Future<void> _sendViaEmailApp(String emailSubject, String deviceInfo) async {
    // 构建邮件内容
    final String emailBody = '''
反馈类型: $_selectedType
用户名称: ${_nameController.text}
用户邮箱: ${_emailController.text}
设备信息: $deviceInfo

反馈内容:
${_contentController.text}
''';

    // 使用URL Launcher发送邮件
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: '121625933@qq.com', // 指定接收邮箱
      queryParameters: {
        'subject': emailSubject,
        'body': emailBody,
      },
    );

    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('请在邮件应用中发送反馈'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('无法启动邮件应用，请检查设备设置'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('发送反馈'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 说明文字
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '您的反馈对我们很重要',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '请填写以下表单，您的反馈将发送到我们的技术支持邮箱。我们将认真阅读每一条反馈，并持续改进产品体验。',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // 反馈类型
              const Text(
                '反馈类型',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                items: _feedbackTypes.map((type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedType = value!;
                  });
                },
              ),
              
              const SizedBox(height: 16),
              
              // 用户名称
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: '您的姓名 (选填)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // 用户邮箱
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: '您的邮箱 (选填)',
                  hintText: '用于接收后续回复',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    // 简单的邮箱格式验证
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                      return '请输入有效的邮箱地址';
                    }
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // 反馈标题
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: '反馈标题',
                  hintText: '简要描述您的反馈',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入反馈标题';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // 反馈内容
              TextFormField(
                controller: _contentController,
                decoration: InputDecoration(
                  labelText: '反馈内容',
                  hintText: '请详细描述您的反馈内容，包括遇到的问题或建议',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                maxLines: 8,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入反馈内容';
                  }
                  if (value.length < 10) {
                    return '反馈内容至少10个字符';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 24),
              
              // 提交按钮
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSending ? null : _sendFeedback,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSending
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('提交中...'),
                          ],
                        )
                      : const Text('提交反馈'),
                ),
              ),
              
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
} 