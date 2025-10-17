import 'package:flutter/material.dart';
import '../services/ai_assistant_service.dart';
import '../models/strategy.dart';

class StrategyAssistantDialog extends StatefulWidget {
  final Function(Strategy) onStrategyGenerated;
  final Strategy? existingStrategy; // 添加可选的现有策略参数

  const StrategyAssistantDialog({
    super.key,
    required this.onStrategyGenerated,
    this.existingStrategy,
  });

  @override
  State<StrategyAssistantDialog> createState() => _StrategyAssistantDialogState();
}

class _StrategyAssistantDialogState extends State<StrategyAssistantDialog> {
  final _formKey = GlobalKey<FormState>();
  final _aiAssistantService = AIAssistantService();
  
  late String _selectedStockType;
  late String _selectedTimeFrame;
  late String _selectedRiskLevel;
  final _additionalInfoController = TextEditingController();
  
  bool _isGenerating = false;
  String? _errorMessage;
  
  final List<String> _stockTypes = ['蓝筹股', '成长股', '科技股', '消费股', '周期股', '通用'];
  final List<String> _timeFrames = ['日线', '周线', '月线', '季线'];
  final List<String> _riskLevels = ['低风险', '中风险', '高风险'];
  
  bool get _isImproveMode => widget.existingStrategy != null;

  @override
  void initState() {
    super.initState();
    
    // 如果是完善模式，使用现有策略的值作为默认值
    if (_isImproveMode) {
      // 尝试从现有策略中推断股票类型、时间周期和风险等级
      _selectedStockType = _inferStockType(widget.existingStrategy!);
      _selectedTimeFrame = _inferTimeFrame(widget.existingStrategy!);
      _selectedRiskLevel = _inferRiskLevel(widget.existingStrategy!);
      
      // 添加原策略的一些关键信息作为额外信息
      _additionalInfoController.text = '基于原有策略完善，原策略名称: ${widget.existingStrategy!.name}，'
          '原策略主要特点: ${widget.existingStrategy!.description ?? "无描述"}';
    } else {
      // 新建模式，使用默认值
      _selectedStockType = '通用';
      _selectedTimeFrame = '日线';
      _selectedRiskLevel = '中风险';
    }
  }
  
  // 根据策略内容推断股票类型
  String _inferStockType(Strategy strategy) {
    final description = strategy.description?.toLowerCase() ?? '';
    final entryConditions = strategy.entryConditions.join(' ').toLowerCase();
    
    if (description.contains('蓝筹') || entryConditions.contains('蓝筹')) return '蓝筹股';
    if (description.contains('成长') || entryConditions.contains('成长')) return '成长股';
    if (description.contains('科技') || entryConditions.contains('科技')) return '科技股';
    if (description.contains('消费') || entryConditions.contains('消费')) return '消费股';
    if (description.contains('周期') || entryConditions.contains('周期')) return '周期股';
    
    // 默认返回通用
    return '通用';
  }
  
  // 根据策略内容推断时间周期
  String _inferTimeFrame(Strategy strategy) {
    final description = strategy.description?.toLowerCase() ?? '';
    final conditions = (strategy.entryConditions + strategy.exitConditions).join(' ').toLowerCase();
    
    if (description.contains('日线') || conditions.contains('日线') || 
        conditions.contains('日均线') || conditions.contains('日k')) {
      return '日线';
    }
    if (description.contains('周线') || conditions.contains('周线') || 
        conditions.contains('周均线') || conditions.contains('周k')) {
      return '周线';
    }
    if (description.contains('月线') || conditions.contains('月线') || 
        conditions.contains('月均线') || conditions.contains('月k')) {
      return '月线';
    }
    if (description.contains('季线') || conditions.contains('季线')) return '季线';
    
    // 默认返回
    return '日线';
  }
  
  // 根据策略内容推断风险等级
  String _inferRiskLevel(Strategy strategy) {
    final description = strategy.description?.toLowerCase() ?? '';
    final riskControls = strategy.riskControls.join(' ').toLowerCase();
    
    if (description.contains('低风险') || riskControls.contains('低风险')) return '低风险';
    if (description.contains('高风险') || riskControls.contains('高风险')) return '高风险';
    
    // 默认返回中风险
    return '中风险';
  }

  @override
  void dispose() {
    _additionalInfoController.dispose();
    super.dispose();
  }

  Future<void> _generateStrategy() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });
    
    try {
      // 添加原策略信息（如果是完善模式）
      String? additionalInfo = _additionalInfoController.text.isEmpty 
          ? null 
          : _additionalInfoController.text;
          
      if (_isImproveMode && widget.existingStrategy != null) {
        // 将原策略的具体条件添加到额外信息中
        final strategy = widget.existingStrategy!;
        final originalDetails = '''
原入场条件: ${strategy.entryConditions.join('; ')}
原出场条件: ${strategy.exitConditions.join('; ')}
原风险控制: ${strategy.riskControls.join('; ')}
''';
        
        additionalInfo = additionalInfo ?? '';
        if (additionalInfo.isNotEmpty) {
          additionalInfo += '\n\n';
        }
        additionalInfo += originalDetails;
      }
      
      final result = await _aiAssistantService.generateTradingStrategy(
        stockType: _selectedStockType,
        timeFrame: _selectedTimeFrame,
        riskLevel: _selectedRiskLevel,
        additionalInfo: additionalInfo,
        isImproveMode: _isImproveMode,
      );
      
      if (result['success']) {
        final data = result['data'];
        final strategy = Strategy(
          id: _isImproveMode ? null : widget.existingStrategy?.id, // 在完善模式下生成新的ID
          name: _isImproveMode ? "${data['name']} (已完善)" : data['name'],
          description: data['description'],
          entryConditions: List<String>.from(data['entryConditions']),
          exitConditions: List<String>.from(data['exitConditions']),
          riskControls: List<String>.from(data['riskControls']),
          createTime: DateTime.now(),
          isActive: true,
        );
        
        widget.onStrategyGenerated(strategy);
        
        // 如果有警告信息，在关闭对话框前显示提示
        if (result.containsKey('warning')) {
          // 使用备用方案，先关闭当前对话框
          Navigator.pop(context);
          
          // 显示备用方案提示
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['warning']),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: '知道了',
                textColor: Colors.white,
                onPressed: () {},
              ),
            ),
          );
        } else {
          Navigator.pop(context);
        }
      } else {
        setState(() {
          _errorMessage = '生成策略失败: ${result['error']}';
          _isGenerating = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '发生错误: $e';
        _isGenerating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        constraints: BoxConstraints(
          maxWidth: 450,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        // 使用SingleChildScrollView使内容可滚动
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ShaderMask(
                      shaderCallback: (rect) {
                        return const LinearGradient(
                          colors: [
                            Color(0xFF2F80ED), // 更现代的蓝色
                            Color(0xFF56CCF2), // 淡蓝色
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(rect);
                      },
                      child: const Icon(
                        Icons.psychology,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isImproveMode ? 'AI策略完善助手' : 'A股策略助手',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _isImproveMode 
                      ? '告诉我您的调整偏好，AI助手将完善您的策略' 
                      : '告诉我您的交易偏好，AI助手将为您生成一个完整的A股交易策略',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                
                // 股票类型选择
                Text(
                  '股票类型',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _stockTypes.map((type) => Theme(
                    data: Theme.of(context).copyWith(
                      chipTheme: ChipThemeData(
                        selectedColor: const Color(0xFF2196F3), // 更明显的蓝色
                        backgroundColor: Colors.grey.shade100,
                        labelStyle: TextStyle(
                          color: _selectedStockType == type ? Colors.white : Colors.grey.shade700,
                          fontSize: 13,
                          fontWeight: _selectedStockType == type ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                    child: ChoiceChip(
                      label: Text(type),
                    selected: _selectedStockType == type,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedStockType = type;
                        });
                      }
                    },
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 12),
                
                // 时间周期选择
                Text(
                  '时间周期',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _timeFrames.map((frame) => Theme(
                    data: Theme.of(context).copyWith(
                      chipTheme: ChipThemeData(
                        selectedColor: const Color(0xFF2196F3), // 更明显的蓝色
                        backgroundColor: Colors.grey.shade100,
                        labelStyle: TextStyle(
                          color: _selectedTimeFrame == frame ? Colors.white : Colors.grey.shade700,
                          fontSize: 13,
                          fontWeight: _selectedTimeFrame == frame ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                    child: ChoiceChip(
                      label: Text(frame),
                    selected: _selectedTimeFrame == frame,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedTimeFrame = frame;
                        });
                      }
                    },
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 12),
                
                // 风险等级选择
                Text(
                  '风险等级',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _riskLevels.map((level) => Theme(
                    data: Theme.of(context).copyWith(
                      chipTheme: ChipThemeData(
                        selectedColor: const Color(0xFF2196F3), // 更明显的蓝色
                        backgroundColor: Colors.grey.shade100,
                        labelStyle: TextStyle(
                          color: _selectedRiskLevel == level ? Colors.white : Colors.grey.shade700,
                          fontSize: 13,
                          fontWeight: _selectedRiskLevel == level ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                    child: ChoiceChip(
                      label: Text(level),
                    selected: _selectedRiskLevel == level,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedRiskLevel = level;
                        });
                      }
                    },
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 12),
                
                // 额外信息
                TextFormField(
                  controller: _additionalInfoController,
                  decoration: InputDecoration(
                    labelText: _isImproveMode ? '完善要求（可选）' : '额外信息（可选）',
                    hintText: _isImproveMode 
                        ? '例如：增加更多量化指标、强化风控措施等' 
                        : '例如：特定行业、板块、技术指标偏好等',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  maxLines: 3,
                  style: const TextStyle(fontSize: 14),
                ),
                
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Colors.red.shade800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
                
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isGenerating ? null : () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isGenerating ? null : _generateStrategy,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: _isGenerating
                          ? const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text('生成中...'),
                              ],
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ShaderMask(
                                  shaderCallback: (rect) {
                                    return const LinearGradient(
                                      colors: [
                                        Color(0xFF2F80ED), // 更现代的蓝色
                                        Color(0xFF56CCF2), // 淡蓝色
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ).createShader(rect);
                                  },
                                  child: const Icon(Icons.psychology, size: 18),
                                ),
                                const SizedBox(width: 8),
                                Text(_isImproveMode ? '完善策略' : '生成策略'),
                              ],
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
} 