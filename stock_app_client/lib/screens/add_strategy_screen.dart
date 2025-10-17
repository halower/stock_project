import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/strategy.dart';
import '../services/providers/strategy_provider.dart';
import '../services/providers/theme_provider.dart';
import '../widgets/strategy_assistant_dialog.dart';

class AddStrategyScreen extends StatefulWidget {
  const AddStrategyScreen({super.key});

  @override
  State<AddStrategyScreen> createState() => _AddStrategyScreenState();
}

class _AddStrategyScreenState extends State<AddStrategyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _entryConditionController = TextEditingController();
  final _exitConditionController = TextEditingController();
  final _riskControlController = TextEditingController();

  final List<String> _entryConditions = [];
  final List<String> _exitConditions = [];
  final List<String> _riskControls = [];
  
  // AI辅助填写示例建议
  final Map<String, List<String>> _aiSuggestions = {
    'entryConditions': [
      'MACD指标金叉形成',
      '股价突破20日均线且成交量放大',
      '相对强弱指数(RSI)从超卖区回升',
      '股价站上所有主要均线',
      'KDJ指标金叉形成',
    ],
    'exitConditions': [
      'MACD指标死叉形成',
      '股价跌破20日均线',
      '相对强弱指数(RSI)进入超买区',
      '获利达到10%目标',
      'KDJ指标死叉形成',
    ],
    'riskControls': [
      '单笔交易亏损不超过总资金的2%',
      '设置8%的移动止损',
      '重大利空消息出现时立即止损',
      '分批建仓，首次仓位不超过总仓位的30%',
      '高波动时段减少交易频率',
    ],
  };

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _entryConditionController.dispose();
    _exitConditionController.dispose();
    _riskControlController.dispose();
    super.dispose();
  }

  void _addEntryCondition() {
    if (_entryConditionController.text.isNotEmpty) {
      setState(() {
        _entryConditions.add(_entryConditionController.text);
        _entryConditionController.clear();
      });
    }
  }

  void _addExitCondition() {
    if (_exitConditionController.text.isNotEmpty) {
      setState(() {
        _exitConditions.add(_exitConditionController.text);
        _exitConditionController.clear();
      });
    }
  }

  void _addRiskControl() {
    if (_riskControlController.text.isNotEmpty) {
      setState(() {
        _riskControls.add(_riskControlController.text);
        _riskControlController.clear();
      });
    }
  }

  void _removeEntryCondition(int index) {
    setState(() {
      _entryConditions.removeAt(index);
    });
  }

  void _removeExitCondition(int index) {
    setState(() {
      _exitConditions.removeAt(index);
    });
  }

  void _removeRiskControl(int index) {
    setState(() {
      _riskControls.removeAt(index);
    });
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      if (_entryConditions.isEmpty || _exitConditions.isEmpty || _riskControls.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请至少添加一个入场条件、出场条件和风险控制')),
        );
        return;
      }

      final strategy = Strategy(
        name: _nameController.text,
        description: _descriptionController.text,
        entryConditions: _entryConditions,
        exitConditions: _exitConditions,
        riskControls: _riskControls,
        createTime: DateTime.now(),
      );

      context.read<StrategyProvider>().addStrategy(strategy);
      Navigator.pop(context);
    }
  }
  
  // 打开AI策略助手（全自动生成策略）
  void _openAIAssistant() {
    showDialog(
      context: context,
      builder: (context) => StrategyAssistantDialog(
        onStrategyGenerated: (strategy) {
          context.read<StrategyProvider>().addStrategy(strategy);
          // 关闭当前添加页面
          Navigator.pop(context);
          
          // 显示成功信息
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('AI已成功生成新策略！'),
              backgroundColor: Color(0xFF4CAF50),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        existingStrategy: null,
      ),
    );
  }
  
  // 添加AI示例条件
  void _addAISuggestion(String type) {
    final suggestions = _aiSuggestions[type] ?? [];
    if (suggestions.isEmpty) return;
    
    if (type == 'entryConditions') {
      setState(() {
        // 随机选择一个未使用的建议
        final unusedSuggestions = suggestions.where((s) => !_entryConditions.contains(s)).toList();
        if (unusedSuggestions.isNotEmpty) {
          final suggestion = unusedSuggestions[DateTime.now().millisecondsSinceEpoch % unusedSuggestions.length];
          _entryConditionController.text = suggestion;
        }
      });
    } else if (type == 'exitConditions') {
      setState(() {
        final unusedSuggestions = suggestions.where((s) => !_exitConditions.contains(s)).toList();
        if (unusedSuggestions.isNotEmpty) {
          final suggestion = unusedSuggestions[DateTime.now().millisecondsSinceEpoch % unusedSuggestions.length];
          _exitConditionController.text = suggestion;
        }
      });
    } else if (type == 'riskControls') {
      setState(() {
        final unusedSuggestions = suggestions.where((s) => !_riskControls.contains(s)).toList();
        if (unusedSuggestions.isNotEmpty) {
          final suggestion = unusedSuggestions[DateTime.now().millisecondsSinceEpoch % unusedSuggestions.length];
          _riskControlController.text = suggestion;
        }
      });
    }
  }
  
  // 一键填充常用策略名称和描述（AI辅助）
  void _fillBasicInfo() {
    final strategyTypes = [
      {'name': '均线交叉趋势策略', 'desc': '基于短期与长期均线交叉信号进行交易，结合成交量和市场情绪指标，适合中等风险承受能力的投资者。'},
      {'name': '动量反转策略', 'desc': '通过寻找价格超买或超卖的情况，在市场情绪极端时逆势操作，把握短期价格修正的机会。'},
      {'name': '突破交易策略', 'desc': '在价格突破重要支撑或阻力位时入场，追踪趋势发展，适合有一定交易经验的投资者。'},
      {'name': '价值投资策略', 'desc': '专注于寻找被低估的优质企业，基于基本面分析和估值指标，适合长期投资，具有较强的抗跌性。'},
      {'name': '波段操作策略', 'desc': '在中期趋势内进行高抛低吸，通过技术指标确定超买超卖区域，适合震荡市场环境。'},
    ];
    
    final selectedStrategy = strategyTypes[DateTime.now().millisecondsSinceEpoch % strategyTypes.length];
    
    setState(() {
      if (_nameController.text.isEmpty) {
        _nameController.text = selectedStrategy['name']!;
      }
      if (_descriptionController.text.isEmpty) {
        _descriptionController.text = selectedStrategy['desc']!;
      }
    });
  }
  
  // 一键批量添加多个条件（智能推荐组合）
  void _bulkAddConditions(String type) {
    final suggestions = _aiSuggestions[type] ?? [];
    if (suggestions.isEmpty) return;
    
    // 随机选择3个建议添加
    final shuffled = List<String>.from(suggestions)..shuffle();
    final toAdd = shuffled.take(3).toList();
    
    setState(() {
      if (type == 'entryConditions') {
        for (var suggestion in toAdd) {
          if (!_entryConditions.contains(suggestion)) {
            _entryConditions.add(suggestion);
          }
        }
      } else if (type == 'exitConditions') {
        for (var suggestion in toAdd) {
          if (!_exitConditions.contains(suggestion)) {
            _exitConditions.add(suggestion);
          }
        }
      } else if (type == 'riskControls') {
        for (var suggestion in toAdd) {
          if (!_riskControls.contains(suggestion)) {
            _riskControls.add(suggestion);
          }
        }
      }
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('AI已为您添加${toAdd.length}个${_getTypeName(type)}！'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  String _getTypeName(String type) {
    switch (type) {
      case 'entryConditions': return '入场条件';
      case 'exitConditions': return '出场条件';
      case 'riskControls': return '风险控制';
      default: return '条件';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('添加交易策略'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.psychology),
              tooltip: 'AI生成策略',
              onPressed: _openAIAssistant,
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 基本信息部分
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '基本信息',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.smart_toy),
                          tooltip: 'AI辅助填写',
                          onPressed: _fillBasicInfo,
                          color: const Color(0xFF4CAF50),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: '策略名称',
                        hintText: '输入策略名称',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入策略名称';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: '策略描述',
                        hintText: '输入策略描述（可选）',
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
            
            // 入场条件部分
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '入场条件',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.smart_toy),
                              tooltip: 'AI辅助填写',
                              onPressed: () => _addAISuggestion('entryConditions'),
                              color: const Color(0xFF4CAF50),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              tooltip: '添加条件',
                              onPressed: _addEntryCondition,
                              color: theme.colorScheme.primary,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _entryConditionController,
                      decoration: const InputDecoration(
                        hintText: '输入入场条件',
                      ),
                      onFieldSubmitted: (_) => _addEntryCondition(),
                    ),
                    if (_entryConditions.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        '已添加条件:',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._buildConditionsList(_entryConditions, _removeEntryCondition),
                    ],
                  ],
                ),
              ),
            ),
            
            // 出场条件部分
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '出场条件',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.smart_toy),
                              tooltip: 'AI辅助填写',
                              onPressed: () => _addAISuggestion('exitConditions'),
                              color: const Color(0xFF4CAF50),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              tooltip: '添加条件',
                              onPressed: _addExitCondition,
                              color: theme.colorScheme.primary,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _exitConditionController,
                      decoration: const InputDecoration(
                        hintText: '输入出场条件',
                      ),
                      onFieldSubmitted: (_) => _addExitCondition(),
                    ),
                    if (_exitConditions.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        '已添加条件:',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._buildConditionsList(_exitConditions, _removeExitCondition),
                    ],
                  ],
                ),
              ),
            ),
            
            // 风险控制部分
            Card(
              margin: const EdgeInsets.only(bottom: 24),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '风险控制',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.smart_toy),
                              tooltip: 'AI辅助填写',
                              onPressed: () => _addAISuggestion('riskControls'),
                              color: const Color(0xFF4CAF50),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              tooltip: '添加条件',
                              onPressed: _addRiskControl,
                              color: theme.colorScheme.primary,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _riskControlController,
                      decoration: const InputDecoration(
                        hintText: '输入风险控制措施',
                      ),
                      onFieldSubmitted: (_) => _addRiskControl(),
                    ),
                    if (_riskControls.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        '已添加措施:',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._buildConditionsList(_riskControls, _removeRiskControl),
                    ],
                  ],
                ),
              ),
            ),
            
            ElevatedButton(
              onPressed: _submitForm,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                '保存策略',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  List<Widget> _buildConditionsList(List<String> conditions, Function(int) onRemove) {
    final theme = Theme.of(context);
    return conditions.asMap().entries.map((entry) {
      final index = entry.key;
      final condition = entry.value;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  condition,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: () => onRemove(index),
              color: theme.colorScheme.error,
              tooltip: '删除',
              iconSize: 20,
            ),
          ],
        ),
      );
    }).toList();
  }
} 