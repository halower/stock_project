import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/strategy.dart';
import '../services/providers/strategy_provider.dart';
import '../services/providers/theme_provider.dart';
import '../widgets/strategy_assistant_dialog.dart';
import 'strategy_edit_screen.dart';

class StrategyScreen extends StatefulWidget {
  const StrategyScreen({super.key});

  @override
  State<StrategyScreen> createState() => _StrategyScreenState();
}

class _StrategyScreenState extends State<StrategyScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleStrategyGenerated(Strategy strategy) {
    Provider.of<StrategyProvider>(context, listen: false).addStrategy(strategy);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('AI已成功生成新策略！'),
        backgroundColor: Theme.of(context).colorScheme.secondary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openStrategyAssistant() {
    showDialog(
      context: context,
      builder: (context) => StrategyAssistantDialog(
        onStrategyGenerated: _handleStrategyGenerated,
        existingStrategy: null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_graph, size: 24),
            SizedBox(width: 8),
            Text('交易策略'),
          ],
        ),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '活跃策略'),
            Tab(text: '归档策略'),
          ],
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.psychology),
            tooltip: 'AI策略助手',
            onPressed: _openStrategyAssistant,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '添加策略',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StrategyEditScreen()),
              );
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStrategyList(true),
          _buildStrategyList(false),
        ],
      ),
    );
  }

  Widget _buildStrategyList(bool active) {
    return Consumer<StrategyProvider>(
      builder: (context, strategyProvider, child) {
        final theme = Theme.of(context);
        
        if (strategyProvider.isLoading) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                ),
                const SizedBox(height: 16),
                Text(
                  '加载中...',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        final strategies = strategyProvider.strategies.where((strategy) => strategy.isActive == active).toList();
        
        if (strategies.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  active ? Icons.auto_graph : Icons.archive,
                  size: 64,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  active ? '暂无活跃策略' : '暂无归档策略',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  active ? '点击右上角添加策略或使用AI助手生成' : '归档的策略会显示在这里',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: strategies.length,
          itemBuilder: (context, index) {
            final strategy = strategies[index];
            return StrategyCard(
              strategy: strategy,
              onAIImprove: () {
                showDialog(
                  context: context,
                  builder: (context) => StrategyAssistantDialog(
                    onStrategyGenerated: _handleStrategyGenerated,
                    existingStrategy: strategy,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class StrategyCard extends StatelessWidget {
  final Strategy strategy;
  final VoidCallback onAIImprove;

  const StrategyCard({
    super.key, 
    required this.strategy,
    required this.onAIImprove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StrategyEditScreen(strategy: strategy),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 头部
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strategy.name,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            strategy.description ?? '无描述',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // 状态指示器
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: strategy.isActive ? Colors.green : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // 策略条件
                if (strategy.entryConditions.isNotEmpty) ...[
                  _buildConditionSection(
                    context,
                    '入场条件',
                    strategy.entryConditions,
                    Colors.green,
                  ),
                  const SizedBox(height: 12),
                ],
                
                if (strategy.exitConditions.isNotEmpty) ...[
                  _buildConditionSection(
                    context,
                    '离场条件',
                    strategy.exitConditions,
                    Colors.red,
                  ),
                  const SizedBox(height: 12),
                ],
                
                if (strategy.riskControls.isNotEmpty) ...[
                  _buildConditionSection(
                    context,
                    '风险控制',
                    strategy.riskControls,
                    Colors.orange,
                  ),
                  const SizedBox(height: 12),
                ],
                
                // 底部信息
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '创建于 ${DateFormat('yyyy-MM-dd').format(strategy.createTime)}',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    // AI改进按钮
                    TextButton.icon(
                      onPressed: onAIImprove,
                      icon: const Icon(Icons.psychology, size: 16),
                      label: const Text('AI改进'),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.primary,
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConditionSection(BuildContext context, String title, List<String> conditions, Color color) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...conditions.map((condition) => Padding(
          padding: const EdgeInsets.only(left: 12, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 4,
                margin: const EdgeInsets.only(top: 8, right: 8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Text(
                  condition,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }
} 