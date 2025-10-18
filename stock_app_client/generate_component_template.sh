#!/bin/bash

# AddTradeScreen 组件生成脚本
# 用法: ./generate_component_template.sh ComponentName

if [ -z "$1" ]; then
  echo "用法: ./generate_component_template.sh ComponentName"
  echo "示例: ./generate_component_template.sh StockSelectionCard"
  exit 1
fi

COMPONENT_NAME=$1
FILE_NAME=$(echo $COMPONENT_NAME | sed 's/\([A-Z]\)/_\L\1/g' | sed 's/^_//')
FILE_PATH="lib/widgets/trade/${FILE_NAME}.dart"

# 创建组件文件
cat > "$FILE_PATH" << EOF
import 'package:flutter/material.dart';

/// ${COMPONENT_NAME}组件
/// 
/// 从 add_trade_screen.dart 提取的独立组件
class ${COMPONENT_NAME} extends StatelessWidget {
  final bool isDarkMode;

  const ${COMPONENT_NAME}({
    super.key,
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
            _buildContent(),
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
                Colors.blue.withOpacity(0.2),
                Colors.lightBlue.withOpacity(0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.widgets_outlined,
            color: Colors.blue.shade400,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '${COMPONENT_NAME}',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  /// 构建内容
  Widget _buildContent() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.grey.shade900.withOpacity(0.3)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'TODO: 实现${COMPONENT_NAME}的内容',
        style: TextStyle(
          color: isDarkMode ? Colors.white70 : Colors.black87,
        ),
      ),
    );
  }
}
EOF

echo "✅ 组件模板已创建: $FILE_PATH"
echo ""
echo "下一步:"
echo "1. 打开 $FILE_PATH"
echo "2. 从 add_trade_screen.dart 复制对应的 _build 方法"
echo "3. 调整 Props 和回调函数"
echo "4. 在主屏幕中使用并测试"

