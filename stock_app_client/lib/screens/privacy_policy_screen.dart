import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('隐私政策'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // 复制隐私政策内容到剪贴板
              Clipboard.setData(const ClipboardData(text: _privacyPolicyText));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('隐私政策已复制到剪贴板'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            tooltip: '分享隐私政策',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.shield,
                  size: 56,
                  color: Color(0xFF2196F3),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '交易大陆隐私政策',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '生效日期：2025年6月1日',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            const _PrivacyPolicySection(
              title: '1. 引言',
              content:
                  '感谢您使用交易大陆应用("本应用")。作为个人学习作品，我深知个人信息对您的重要性，也尊重并保护每位用户的隐私权益。本隐私政策旨在向您说明我们如何收集、使用、存储、共享和保护您的个人信息，以及您享有的相关权利。',
            ),
            const _PrivacyPolicySection(
              title: '2. 信息存储与安全',
              content:
                  '本应用采用"本地存储"模式，您的交易记录、策略方案和个人设置等数据仅存储在您的设备上，不会上传至我们的服务器。这意味着:\n\n'
                  '• 您的交易记录完全私密，只有您能够访问\n'
                  '• 您的投资策略和决策过程不会被分享给第三方\n'
                  '• 您的资金状况和盈亏情况仅限个人查看\n\n'
                  '我们采取了行业标准的安全措施来保护您设备上的应用数据，包括：\n\n'
                  '• 数据加密存储，确保即使在设备丢失的情况下也能保护您的隐私\n'
                  '• 应用内安全机制，防止未经授权的访问',
            ),
            const _PrivacyPolicySection(
              title: '3. 我们收集的数据',
              content:
                  '为提供基本功能和服务优化，我们可能会收集：\n\n'
                  '• 设备信息：仅用于授权识别和确保一机一码的授权体系\n'
                  '• 应用使用数据：用于改善用户体验和性能优化\n'
                  '• 用户反馈：您主动提供的反馈和建议\n\n'
                  '重要说明：以上数据均以匿名、去标识化的方式处理，且我们不会收集您的：\n\n'
                  '• 具体交易记录和金额\n'
                  '• 投资组合详情\n'
                  '• 个人财务状况\n'
                  '• 账户密码等敏感信息',
            ),
            const _PrivacyPolicySection(
              title: '4. AI功能与隐私',
              content:
                  '当您使用应用内的AI功能进行交易分析或决策辅助时：\n\n'
                  '• 您的查询内容可能会传输至对应的AI服务提供商(如OpenAI、DeepSeek或Qwen)\n'
                  '• 我们不会在查询中包含您的个人身份信息\n'
                  '• 您可以在设置中选择使用自己的API密钥，以获得更高的隐私保障\n'
                  '• 您的历史查询记录仅保存在本地设备上',
            ),
            const _PrivacyPolicySection(
              title: '5. 数据备份与迁移',
              content:
                  '由于应用采用本地存储模式，我们建议您定期备份数据：\n\n'
                  '• 应用提供数据导出功能，可将交易数据导出为标准格式\n'
                  '• 您可以使用设备自带的备份功能对应用数据进行备份\n'
                  '• 更换设备时，您可通过导入导出功能迁移数据\n\n'
                  '请注意：数据备份的安全性取决于您所选择的存储位置，请确保备份文件的安全',
            ),
            const _PrivacyPolicySection(
              title: '6. 数据删除',
              content:
                  '您可以随时：\n\n'
                  '• 在应用内删除特定的交易记录\n'
                  '• 通过设置中的"清除缓存"功能删除临时数据\n'
                  '• 卸载应用将删除设备上存储的所有应用数据（除非您已进行备份）',
            ),
            const _PrivacyPolicySection(
              title: '7. 授权管理',
              content:
                  '我们采用"一机一码"的授权机制，这意味着：\n\n'
                  '• 您的授权码与特定设备绑定\n'
                  '• 设备标识信息仅用于验证授权有效性\n'
                  '• 我们不会将您的设备标识用于追踪或分析行为',
            ),
            const _PrivacyPolicySection(
              title: '8. 第三方服务',
              content:
                  '本应用可能包含以下第三方服务：\n\n'
                  '• AI服务提供商：用于提供智能分析功能\n'
                  '• 金融数据提供商：用于获取市场数据\n\n'
                  '对于这些第三方服务，我们建议您查阅其各自的隐私政策。我们已尽力选择具有良好隐私保护实践的合作伙伴。',
            ),
            const _PrivacyPolicySection(
              title: '9. 隐私政策更新',
              content:
                  '我们可能会不时更新本隐私政策。当我们进行重大变更时，会通过应用内通知的方式告知您。我们鼓励您定期查看本政策，以了解我们如何保护您的信息。',
            ),
            const _PrivacyPolicySection(
              title: '10. 联系我们',
              content:
                  '如果您对本隐私政策有任何疑问或建议，请通过以下方式联系我们：\n\n'
                  '• 应用内反馈功能\n\n'
                  '我们将在收到您的请求后15个工作日内回复。',
            ),
            const SizedBox(height: 32),
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      '交易大陆致力于保护您的隐私',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '您的信任是我最宝贵的资产',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _PrivacyPolicySection extends StatelessWidget {
  final String title;
  final String content;

  const _PrivacyPolicySection({
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

// 完整的隐私政策文本，用于复制分享
const _privacyPolicyText = '''
交易大陆隐私政策

生效日期：2023年12月1日

1. 引言

感谢您使用交易大陆应用("本应用")。我们深知个人信息对您的重要性，也尊重并保护每位用户的隐私权益。本隐私政策旨在向您说明我们如何收集、使用、存储、共享和保护您的个人信息，以及您享有的相关权利。

2. 信息存储与安全

本应用采用"本地存储"模式，您的交易记录、策略方案和个人设置等数据仅存储在您的设备上，不会上传至我们的服务器。这意味着:

• 您的交易记录完全私密，只有您能够访问
• 您的投资策略和决策过程不会被分享给第三方
• 您的资金状况和盈亏情况仅限个人查看

我们采取了行业标准的安全措施来保护您设备上的应用数据，包括：

• 数据加密存储，确保即使在设备丢失的情况下也能保护您的隐私
• 应用内安全机制，防止未经授权的访问

3. 我们收集的数据

为提供基本功能和服务优化，我们可能会收集：

• 设备信息：仅用于授权识别和确保一机一码的授权体系
• 应用使用数据：用于改善用户体验和性能优化
• 用户反馈：您主动提供的反馈和建议

重要说明：以上数据均以匿名、去标识化的方式处理，且我们不会收集您的：

• 具体交易记录和金额
• 投资组合详情
• 个人财务状况
• 账户密码等敏感信息

4. AI功能与隐私

当您使用应用内的AI功能进行交易分析或决策辅助时：

• 您的查询内容可能会传输至对应的AI服务提供商(如OpenAI、DeepSeek或Qwen)
• 我们不会在查询中包含您的个人身份信息
• 您可以在设置中选择使用自己的API密钥，以获得更高的隐私保障
• 您的历史查询记录仅保存在本地设备上

5. 数据备份与迁移

由于应用采用本地存储模式，我们建议您定期备份数据：

• 应用提供数据导出功能，可将交易数据导出为标准格式
• 您可以使用设备自带的备份功能对应用数据进行备份
• 更换设备时，您可通过导入导出功能迁移数据

请注意：数据备份的安全性取决于您所选择的存储位置，请确保备份文件的安全

6. 数据删除

您可以随时：

• 在应用内删除特定的交易记录
• 通过设置中的"清除缓存"功能删除临时数据
• 卸载应用将删除设备上存储的所有应用数据（除非您已进行备份）

7. 授权管理

我们采用"一机一码"的授权机制，这意味着：

• 您的授权码与特定设备绑定
• 设备标识信息仅用于验证授权有效性
• 我们不会将您的设备标识用于追踪或分析行为

8. 第三方服务

本应用可能包含以下第三方服务：

• AI服务提供商：用于提供智能分析功能
• 金融数据提供商：用于获取市场数据

对于这些第三方服务，我们建议您查阅其各自的隐私政策。我们已尽力选择具有良好隐私保护实践的合作伙伴。

9. 隐私政策更新

我们可能会不时更新本隐私政策。当我们进行重大变更时，会通过应用内通知的方式告知您。我们鼓励您定期查看本政策，以了解我们如何保护您的信息。

10. 联系我们

如果您对本隐私政策有任何疑问或建议，请通过以下方式联系我们：

• 应用内反馈功能

我们将在收到您的请求后15个工作日内回复。

交易大陆团队致力于保护您的隐私
您的信任是我们最宝贵的资产
'''; 