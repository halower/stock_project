import 'package:flutter/material.dart';

/// 交易原因卡片组件
class TradeReasonCard extends StatelessWidget {
  final TextEditingController reasonController;
  final bool isDarkMode;

  const TradeReasonCard({
    super.key,
    required this.reasonController,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [const Color(0xFF2C2C2E), const Color(0xFF1C1C1E)]
              : [Colors.white, const Color(0xFFFAFAFA)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.grey.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.orange.withOpacity(0.2),
                        Colors.deepOrange.withOpacity(0.2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.lightbulb_outline,
                    color: Colors.orange.shade400,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '交易原因',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, size: 14, color: Colors.red.shade400),
                      const SizedBox(width: 4),
                      Text(
                        '必填',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade400,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: reasonController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: '请详细说明交易理由...\n\n建议包括：\n• 技术分析依据\n• 基本面支撑\n• 市场环境判断',
                hintStyle: TextStyle(
                  color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
                  fontSize: 14,
                ),
                filled: true,
                fillColor: isDarkMode
                    ? Colors.grey.shade900.withOpacity(0.3)
                    : Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.orange.shade400, width: 2),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入交易原因';
                }
                if (value.trim().length < 10) {
                  return '交易原因至少需要10个字符';
                }
                return null;
              },
              style: TextStyle(
                color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

