import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/strategy.dart';
import '../services/providers/strategy_provider.dart';
import '../widgets/strategy_assistant_dialog.dart';

class StrategyEditScreen extends StatefulWidget {
  final Strategy? strategy;

  const StrategyEditScreen({
    super.key,
    this.strategy,
  });

  @override
  State<StrategyEditScreen> createState() => _StrategyEditScreenState();
}

class _StrategyEditScreenState extends State<StrategyEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _entryConditionsController = TextEditingController();
  final _exitConditionsController = TextEditingController();
  final _riskControlsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.strategy != null) {
      _nameController.text = widget.strategy!.name;
      _descriptionController.text = widget.strategy!.description ?? '';
      _entryConditionsController.text = widget.strategy!.entryConditions.join('\n');
      _exitConditionsController.text = widget.strategy!.exitConditions.join('\n');
      _riskControlsController.text = widget.strategy!.riskControls.join('\n');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _entryConditionsController.dispose();
    _exitConditionsController.dispose();
    _riskControlsController.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final strategy = Strategy(
        id: widget.strategy?.id,
        name: _nameController.text,
        description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
        entryConditions: _entryConditionsController.text
            .split('\n')
            .where((line) => line.trim().isNotEmpty)
            .toList(),
        exitConditions: _exitConditionsController.text
            .split('\n')
            .where((line) => line.trim().isNotEmpty)
            .toList(),
        riskControls: _riskControlsController.text
            .split('\n')
            .where((line) => line.trim().isNotEmpty)
            .toList(),
        createTime: widget.strategy?.createTime ?? DateTime.now(),
        updateTime: DateTime.now(),
        isActive: widget.strategy?.isActive ?? true,
      );

      final provider = Provider.of<StrategyProvider>(context, listen: false);
      
      if (widget.strategy == null) {
        provider.addStrategy(strategy);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('策略已添加')),
        );
      } else {
        provider.updateStrategy(strategy);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('策略已更新')),
        );
      }
      
      Navigator.of(context).pop();
    }
  }

  void _archiveStrategy() {
    if (widget.strategy != null) {
      final provider = Provider.of<StrategyProvider>(context, listen: false);
      final updatedStrategy = widget.strategy!.copyWith(isActive: false);
      provider.updateStrategy(updatedStrategy);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('策略已归档')),
      );
      Navigator.of(context).pop();
    }
  }

  void _deleteStrategy() {
    if (widget.strategy != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('删除策略'),
          content: const Text('确定要删除这个策略吗？此操作无法撤销。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                final provider = Provider.of<StrategyProvider>(context, listen: false);
                provider.deleteStrategy(widget.strategy!.id!);
                Navigator.of(context).pop(); // 关闭对话框
                Navigator.of(context).pop(); // 返回上一页
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('策略已删除')),
                );
              },
              child: const Text('删除'),
            ),
          ],
        ),
      );
    }
  }

  void _improveWithAI() {
    showDialog(
      context: context,
      builder: (context) => StrategyAssistantDialog(
        onStrategyGenerated: (strategy) {
          // 用AI生成的策略内容更新表单
          _nameController.text = strategy.name;
          _descriptionController.text = strategy.description ?? '';
          _entryConditionsController.text = strategy.entryConditions.join('\n');
          _exitConditionsController.text = strategy.exitConditions.join('\n');
          _riskControlsController.text = strategy.riskControls.join('\n');
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('AI已完善策略内容')),
          );
        },
        existingStrategy: widget.strategy,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(widget.strategy == null ? '添加策略' : '编辑策略'),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        actions: [
          if (widget.strategy != null) ...[
            IconButton(
              icon: const Icon(Icons.psychology),
              tooltip: 'AI完善',
              onPressed: _improveWithAI,
            ),
            IconButton(
              icon: const Icon(Icons.archive),
              onPressed: _archiveStrategy,
              tooltip: '归档策略',
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteStrategy,
              tooltip: '删除策略',
            ),
          ],
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '基本信息',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: '策略名称',
                        hintText: '输入策略名称',
                        border: OutlineInputBorder(),
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
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.login,
                          color: Colors.blue,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '入场条件',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _entryConditionsController,
                      decoration: const InputDecoration(
                        hintText: '每行输入一个入场条件',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 5,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请至少输入一个入场条件';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.logout,
                          color: Colors.green,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '出场条件',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _exitConditionsController,
                      decoration: const InputDecoration(
                        hintText: '每行输入一个出场条件',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 5,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请至少输入一个出场条件';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.security,
                          color: Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '风控措施',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _riskControlsController,
                      decoration: const InputDecoration(
                        hintText: '每行输入一个风控措施',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 5,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请至少输入一个风控措施';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  widget.strategy == null ? '创建策略' : '保存修改',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 