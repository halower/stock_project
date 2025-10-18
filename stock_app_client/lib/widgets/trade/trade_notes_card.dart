import 'package:flutter/material.dart';

/// 交易备注卡片组件
/// 
/// 从 add_trade_screen.dart 提取的独立组件
/// 负责显示和编辑交易备注
class TradeNotesCard extends StatelessWidget {
  final TextEditingController notesController;
  final bool isDarkMode;

  const TradeNotesCard({
    super.key,
    required this.notesController,
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
              ? [
                  const Color(0xFF2C2C2E),
                  const Color(0xFF1C1C1E),
                ]
              : [
                  Colors.white,
                  const Color(0xFFFAFAFA),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.grey.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildNotesField(),
          ],
        ),
      ),
    );
  }

  /// 构建标题栏
  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.purple.withOpacity(0.2),
                Colors.deepPurple.withOpacity(0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.note_alt_outlined,
            color: Colors.purple.shade400,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '备注',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
            letterSpacing: 0.5,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.purple.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.info_outline,
                size: 14,
                color: Colors.purple.shade400,
              ),
              const SizedBox(width: 4),
              Text(
                '选填',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.purple.shade400,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建备注输入框
  Widget _buildNotesField() {
    return TextFormField(
      controller: notesController,
      maxLines: 4,
      decoration: InputDecoration(
        hintText: '记录其他需要注意的信息...',
        hintStyle: TextStyle(
          color: isDarkMode
              ? Colors.grey.shade600
              : Colors.grey.shade400,
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
            color: isDarkMode
                ? Colors.grey.shade800
                : Colors.grey.shade200,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.purple.shade400,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
      style: TextStyle(
        color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
        fontSize: 14,
        height: 1.5,
      ),
    );
  }
}

