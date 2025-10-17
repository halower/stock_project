import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'dart:async';
import '../services/providers/api_provider.dart';
import '../services/providers/theme_provider.dart';
import '../services/providers/strategy_provider.dart';
import '../services/ai_filter_service.dart';
import '../models/ai_filter_result.dart';
import '../models/strategy.dart';
import '../config/api_config.dart';
import '../screens/strategy_screen.dart';

class AIFilterPanel extends StatefulWidget {
  const AIFilterPanel({super.key});

  @override
  State<AIFilterPanel> createState() => _AIFilterPanelState();
}

class _AIFilterPanelState extends State<AIFilterPanel> {
  final TextEditingController _filterController = TextEditingController();
  String _remainingCounts = '正在加载...';
  final bool _isExpanded = true; // 默认展开
  bool _canUseAIFilter = false;
  int? _selectedUserStrategyId; // 选中的用户策略ID
  bool _showCustomInput = true; // 显示自定义输入框
  bool _showUserStrategies = false; // 默认不显示用户策略选择器
  final bool _isMinimized = true; // 控制面板是否最小化，默认最小化
  bool _isResultExpanded = false; // 控制结果详情是否展开
  
  // 用于显示悬浮面板的键
  final GlobalKey _buttonKey = GlobalKey();
  // 控制过渡动画
  final bool _isAnimating = false;
  // 悬浮面板的位置
  OverlayEntry? _overlayEntry;
  // 保存Overlay的setState函数以便在进度流监听器中使用
  Function(VoidCallback)? _overlaySetState;
  // 进度流订阅
  StreamSubscription<AIFilterResult>? _progressSubscription;
  
  @override
  void initState() {
    super.initState();
    _loadRemainingCounts();
    _checkFilterAvailability();
    
    // 加载策略列表
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final strategyProvider = Provider.of<StrategyProvider>(context, listen: false);
      if (strategyProvider.strategies.isEmpty) {
        strategyProvider.loadStrategies();
      }
    });
  }
  
  @override
  void dispose() {
    _removeOverlay();
    _filterController.dispose();
    _progressSubscription?.cancel();
    super.dispose();
  }
  
  // 加载剩余使用次数
  Future<void> _loadRemainingCounts() async {
    final counts = await AIFilterService.getRemainingCountText();
    if (mounted) {
      setState(() {
        _remainingCounts = counts;
      });
    }
  }
  
  // 检查是否可以使用AI筛选
  Future<void> _checkFilterAvailability() async {
    final canUse = await AIFilterService.canUseAIFilter();
    if (mounted) {
      setState(() {
        _canUseAIFilter = canUse;
      });
    }
  }
  
  // 移除悬浮面板
  void _removeOverlay() {
    if (_overlayEntry != null) {
      // 不再取消AI筛选任务，让它在后台继续运行
      // 只清理UI相关的资源
      
      // 取消进度流订阅，防止后续更新导致setState错误
      _progressSubscription?.cancel();
      _progressSubscription = null;
      
      // 移除Overlay
      _overlayEntry!.remove();
      _overlayEntry = null;
      
      // 清除Overlay的setState引用
      _overlaySetState = null;
    }
  }
  
  // 显示/隐藏悬浮面板
  void _toggleOverlay() {
    if (_overlayEntry != null) {
      _removeOverlay();
      return;
    }
    
    // 如果组件已销毁，不执行任何操作
    if (!mounted) return;
    
    final RenderBox renderBox = _buttonKey.currentContext!.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    
    // 使用StatefulBuilder来确保Overlay内部的状态能够正确更新
    _overlayEntry = OverlayEntry(
      builder: (context) => StatefulBuilder(
        builder: (context, setStateOverlay) {
          // 保存Overlay的setState函数以便在进度流监听器中使用
          _overlaySetState = setStateOverlay;
          
          return Positioned(
            top: position.dy + size.height,
            right: 8,
            width: MediaQuery.of(context).size.width * 0.85,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: _buildPopupContent(setStateOverlay),
            ),
          );
        }
      ),
    );
    
    // 确保在添加Overlay前再次检查mounted状态
    if (!mounted) return;
    
    Overlay.of(context).insert(_overlayEntry!);
    
    // 确保数据已加载
    _loadRemainingCounts();
    _checkFilterAvailability();
    
    // 加载策略列表
    final strategyProvider = Provider.of<StrategyProvider>(context, listen: false);
    if (strategyProvider.strategies.isEmpty) {
      strategyProvider.loadStrategies();
    }
    
    // 获取API提供者
    final apiProvider = Provider.of<ApiProvider>(context, listen: false);
    
    // 创建新的进度流订阅
    _progressSubscription?.cancel();
    _progressSubscription = apiProvider.aiFilterProgressStream.listen((result) {
      // 确保仅在Overlay存在且组件挂载时更新状态
      if (mounted && _overlayEntry != null && _overlaySetState != null) {
        try {
          _overlaySetState!(() {});
        } catch (e) {
          // 忽略setState错误，避免崩溃
          debugPrint('更新AI筛选进度UI时出错，可能面板已关闭: $e');
        }
      }
    });
  }
  
  // 构建弹出面板内容，接收setState函数以允许内部状态更新
  Widget _buildPopupContent([Function(VoidCallback)? setStateOverlay]) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final apiProvider = Provider.of<ApiProvider>(context);
    final strategyProvider = Provider.of<StrategyProvider>(context);
    
    // 使用setStateOverlay或setState
    void updateState(VoidCallback fn) {
      // 更新内部状态
      fn();
      // 如果有传入的setStateOverlay，也更新overlay状态
      if (setStateOverlay != null) {
        setStateOverlay(fn);
      }
    }
    
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题栏
          _buildPopupTitleBar(themeProvider, apiProvider),
          
          // 可滚动内容区域
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 筛选选项，移除_isExpanded判断，始终显示
                  const SizedBox(height: 12),
                  _buildFilterOptions(themeProvider, updateState),
                  
                  const SizedBox(height: 12),
                  // 启动按钮
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade500,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _canUseAIFilter && !apiProvider.isAIFiltering
                        ? () => _startFiltering(updateState)
                        : null,
                    child: Text(
                      apiProvider.isAIFiltering ? '处理中...' : '开始AI筛选',
                    ),
                  ),
                  
                  // 始终添加一个底部间距，确保不会贴在一起
                  const SizedBox(height: 16),
                  
                  // 处理中的进度显示
                  if (apiProvider.isAIFiltering) ...[
                    const SizedBox(height: 12),
                    _buildProgressIndicator(apiProvider),
                  ],
                  
                  // 筛选结果摘要（如果有且已完成）
                  if (apiProvider.aiFilterResult != null && 
                      apiProvider.aiFilterResult!.completed &&
                      !apiProvider.isAIFiltering) ...[
                    const SizedBox(height: 8),
                    _buildFilterSummary(apiProvider.aiFilterResult!, themeProvider, updateState),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),
          
          // 底部操作栏
          _buildPopupFooter(apiProvider, themeProvider),
        ],
      ),
    );
  }
  
  // 启动AI筛选，接收更新状态的函数
  Future<void> _startFiltering([Function(VoidCallback)? updateState]) async {
    // 如果组件已销毁，不执行任何操作
    if (!mounted) return;
    
    // 检查筛选条件
    String? errorMessage = _validateFilterSettings();
    if (errorMessage != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
      return;
    }
    
    // 检查是否可以使用AI筛选
    if (!_canUseAIFilter) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('今日AI筛选次数已用完')),
        );
      }
      return;
    }
    
    // 获取API提供者
    final apiProvider = Provider.of<ApiProvider>(context, listen: false);
    
    // 检查是否选择了具体市场（非全部）
    if (apiProvider.selectedMarket == '全部') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先选择具体市场（如创业板、科创板等）再进行AI筛选')),
        );
      }
      return;
    }
    
    // 如果没有扫描结果，提示用户先进行扫描
    if (apiProvider.scanResults.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先获取股票列表数据')),
        );
      }
      return;
    }
    
    // 组合筛选条件
    String filterCriteria = '';
    
    // 如果选择了用户策略
    if (_selectedUserStrategyId != null) {
      filterCriteria = _getUserStrategyDescription(_selectedUserStrategyId!);
    }
    
    // 如果有自定义输入，追加到筛选条件
    if (_filterController.text.trim().isNotEmpty) {
      if (filterCriteria.isNotEmpty) {
        filterCriteria += '\n\n额外筛选条件：';
      }
      filterCriteria += _filterController.text.trim();
    }
    
    // 获取当前面板状态标记，用于检测面板是否在请求完成前关闭
    final bool panelWasOpen = _overlayEntry != null;
    
    // 启动AI筛选
    try {
      await apiProvider.startAIFiltering(filterCriteria);
      
      // 如果组件已销毁或面板已关闭，不继续执行UI更新
      if (!mounted || (panelWasOpen && _overlayEntry == null)) {
        debugPrint('AI筛选完成，但面板已关闭或组件已销毁');
        return;
      }
      
      // 更新剩余使用次数
      await _loadRemainingCounts();
      await _checkFilterAvailability();
      
      // 再次检查组件是否已销毁
      if (!mounted) return;
      
      // 如果有提供更新函数，则更新UI
      if (updateState != null) {
        updateState(() {});
      } else if (mounted) {
        setState(() {});
      }
    } catch (e) {
      // 如果面板已关闭，只记录错误，不显示UI提示
      if (!mounted || (panelWasOpen && _overlayEntry == null)) {
        debugPrint('AI筛选出错，但面板已关闭，不显示错误: $e');
        return;
      }
      
      // 确保组件仍然挂载且面板打开
      if (mounted && _overlayEntry != null) {
        // 显示错误信息
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('启动AI筛选失败: $e'),
            action: SnackBarAction(
              label: '查看详情',
              onPressed: () => _showErrorDetailsDialog(e.toString(), filterCriteria),
            ),
          ),
        );
      }
    }
  }
  
  // 验证筛选设置
  String? _validateFilterSettings() {
    // 检查是否至少选择了一种筛选方式
    bool hasStrategySelected = _selectedUserStrategyId != null;
    bool hasCustomInput = _filterController.text.trim().isNotEmpty;
    
    if (!hasStrategySelected && !hasCustomInput) {
      return '请选择一个策略或输入筛选条件';
    }
    
    return null;
  }
  
  // 获取用户策略的描述
  String _getUserStrategyDescription(int strategyId) {
    final strategyProvider = Provider.of<StrategyProvider>(context, listen: false);
    final strategy = strategyProvider.strategies.firstWhere((s) => s.id == strategyId);
    
    // 构建策略描述
    String description = '使用【${strategy.name}】策略筛选股票。';
    
    if (strategy.description != null && strategy.description!.isNotEmpty) {
      description += '\n策略说明: ${strategy.description}';
    }
    
    description += '\n入场条件: ${strategy.entryConditions.join('; ')}';
    
    if (strategy.exitConditions.isNotEmpty) {
      description += '\n出场条件: ${strategy.exitConditions.join('; ')}';
    }
    
    if (strategy.riskControls.isNotEmpty) {
      description += '\n风险控制: ${strategy.riskControls.join('; ')}';
    }
    
    return description;
  }
  
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final apiProvider = Provider.of<ApiProvider>(context);
    
    // 仅显示AppBar中的AI图标按钮
    return Container(
      key: _buttonKey,
      child: IconButton(
        icon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
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
                  child: const Icon(Icons.psychology, size: 24),
                ),
                if (apiProvider.isAIFiltering)
                  const SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2F80ED)),
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                if (apiProvider.aiFilterResult != null && 
                    apiProvider.aiFilterResult!.completed &&
                    !apiProvider.isAIFiltering)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2F80ED),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 4),
            const Text(
              'AI筛选',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2F80ED),
              ),
            ),
          ],
        ),
        tooltip: 'AI智能筛选',
        onPressed: () => _toggleOverlay(),
      ),
    );
  }
  
  // 构建弹出窗口标题栏
  Widget _buildPopupTitleBar(ThemeProvider themeProvider, ApiProvider apiProvider) {
    // 是否有筛选结果
    final hasFilterResult = apiProvider.aiFilterResult != null && 
                      apiProvider.aiFilterResult!.completed &&
                      !apiProvider.isAIFiltering;
                      
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF2F80ED), // 更现代的蓝色
            Color(0xFF1A56CC), // 深蓝色
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (rect) {
              return LinearGradient(
                colors: [
                  Colors.white,
                  Colors.white.withOpacity(0.9)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(rect);
            },
            child: const Icon(
              Icons.psychology,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI智能筛选增强',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (hasFilterResult)
                  Text(
                    '已筛选: ${apiProvider.aiFilterResult!.stocks.length} 只股票',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _remainingCounts,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _canUseAIFilter 
                    ? Colors.white 
                    : Colors.yellow,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // 构建弹出窗口底部
  Widget _buildPopupFooter(ApiProvider apiProvider, ThemeProvider themeProvider) {
    // 如果没有筛选结果或正在筛选，不显示底部栏
    final hasFilterResult = apiProvider.aiFilterResult != null && 
                      apiProvider.aiFilterResult!.completed &&
                      !apiProvider.isAIFiltering;
    if (!hasFilterResult) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        border: Border(
          top: BorderSide(
            color: Colors.grey.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton.icon(
            icon: const Icon(Icons.close, size: 16),
            label: const Text('关闭面板'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[700],
              visualDensity: VisualDensity.compact,
              textStyle: const TextStyle(fontSize: 12),
            ),
            onPressed: _removeOverlay,
          ),
          TextButton.icon(
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('清除筛选'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red[400],
              visualDensity: VisualDensity.compact,
              textStyle: const TextStyle(fontSize: 12),
            ),
            onPressed: () {
              Provider.of<ApiProvider>(context, listen: false)
                  .clearAIFilterResult();
              _removeOverlay();
            },
          ),
        ],
      ),
    );
  }
  
  // 构建筛选选项，添加setState参数用于更新状态
  Widget _buildFilterOptions(ThemeProvider themeProvider, [Function(VoidCallback)? updateState]) {
    void toggleState(VoidCallback fn) {
      // 更新内部状态
      setState(fn);
      // 如果有传入的updateState，也更新overlay状态
      if (updateState != null) {
        updateState(fn);
      }
    }
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 筛选配置选项
          Row(
            children: [
              Expanded(
                child: _buildSelectionToggle(
                  title: '使用我的策略',
                  value: _showUserStrategies,
                  onChanged: (value) {
                    toggleState(() {
                      _showUserStrategies = value;
                    });
                  },
                  color: themeProvider.upColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSelectionToggle(
                  title: '自定义筛选',
                  value: _showCustomInput,
                  onChanged: (value) {
                    toggleState(() {
                      _showCustomInput = value;
                    });
                  },
                  color: themeProvider.upColor,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          
          // 显示用户策略选择器
          if (_showUserStrategies) 
            LimitedBox(
              maxHeight: 300, // 限制最大高度，避免溢出
              child: SingleChildScrollView(
                child: _buildUserStrategySelector(themeProvider, updateState),
              ),
            ),
          
          // 显示分隔线（如果两者都显示）
          if (_showUserStrategies && _showCustomInput) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
          ],
          
          // 显示自定义输入框
          if (_showCustomInput)
            _buildCustomStrategyInput(),
        ],
      ),
    );
  }
  
  // 构建选择切换按钮
  Widget _buildSelectionToggle({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: value ? color.withOpacity(0.1) : Colors.transparent,
            border: Border.all(
              color: value ? color : Colors.grey.withOpacity(0.5),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                value ? Icons.check_box : Icons.check_box_outline_blank,
                size: 18,
                color: value ? color : Colors.grey,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    color: value ? color : Colors.grey,
                    fontWeight: value ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // 构建用户策略选择器，添加updateState参数
  Widget _buildUserStrategySelector(ThemeProvider themeProvider, [Function(VoidCallback)? updateState]) {
    return Consumer<StrategyProvider>(
      builder: (context, strategyProvider, child) {
        // 如果正在加载策略
        if (strategyProvider.isLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        // 过滤活跃的策略
        final strategies = strategyProvider.strategies
            .where((s) => s.isActive)
            .toList();
        
        // 如果没有策略
        if (strategies.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info_outline, color: Colors.grey),
                const SizedBox(height: 8),
                const Text(
                  '暂无自定义策略',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // 先关闭Overlay面板
                    _removeOverlay();
                    // 使用MaterialPageRoute导航到策略页面
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const StrategyScreen(),
                      ),
                    );
                  },
                  child: const Text('前往创建策略'),
                ),
              ],
            ),
          );
        }

        void toggleState(VoidCallback fn) {
          // 更新内部状态
          setState(fn);
          // 如果有传入的updateState，也更新overlay状态
          if (updateState != null) {
            updateState(fn);
          }
        }
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '选择我的策略:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: strategies.length,
                itemBuilder: (context, index) {
                  final strategy = strategies[index];
                  final isSelected = strategy.id == _selectedUserStrategyId;
                  
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        toggleState(() {
                          if (isSelected) {
                            // 如果已选中，再次点击取消选择
                            _selectedUserStrategyId = null;
                          } else {
                            _selectedUserStrategyId = strategy.id;
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 12,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: isSelected
                                  ? themeProvider.upColor
                                  : Colors.grey,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    strategy.name,
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? themeProvider.upColor
                                          : null,
                                    ),
                                  ),
                                  if (strategy.description != null &&
                                      strategy.description!.isNotEmpty)
                                    Text(
                                      strategy.description!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // 显示所选策略的详细信息
            if (_selectedUserStrategyId != null) ...[
              const SizedBox(height: 8),
              _buildUserStrategyDetails(
                strategyProvider.strategies.firstWhere(
                  (s) => s.id == _selectedUserStrategyId,
                ),
                themeProvider,
              ),
            ],
          ],
        );
      },
    );
  }
  
  // 构建用户策略详情
  Widget _buildUserStrategyDetails(Strategy strategy, ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 入场条件
          if (strategy.entryConditions.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.login,
                  size: 14,
                  color: themeProvider.upColor,
                ),
                const SizedBox(width: 4),
                const Expanded(
                  child: Text(
                    '入场条件:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ...strategy.entryConditions.map((condition) => Padding(
              padding: const EdgeInsets.only(left: 18, bottom: 4),
              child: Text(
                '• $condition',
                style: const TextStyle(fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            )),
          ],
          
          // 出场条件
          if (strategy.exitConditions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.logout,
                  size: 14,
                  color: themeProvider.downColor,
                ),
                const SizedBox(width: 4),
                const Expanded(
                  child: Text(
                    '出场条件:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ...strategy.exitConditions.map((condition) => Padding(
              padding: const EdgeInsets.only(left: 18, bottom: 4),
              child: Text(
                '• $condition',
                style: const TextStyle(fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            )),
          ],
          
          // 风险控制
          if (strategy.riskControls.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.shield,
                  size: 14,
                  color: Colors.orange,
                ),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '风险控制:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ...strategy.riskControls.map((control) => Padding(
              padding: const EdgeInsets.only(left: 18, bottom: 4),
              child: Text(
                '• $control',
                style: const TextStyle(fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            )),
          ],
        ],
      ),
    );
  }
  
  // 构建自定义策略输入
  Widget _buildCustomStrategyInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '输入自然语言筛选条件:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _filterController,
          decoration: InputDecoration(
            hintText: '例如: 近期成交量持续放大且股价上涨',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: Colors.grey.withOpacity(0.1),
          ),
          maxLines: 2,
        ),
        // 添加底部额外间距
        const SizedBox(height: 8),
      ],
    );
  }
  
  // 构建筛选结果摘要，添加updateState参数
  Widget _buildFilterSummary(AIFilterResult result, ThemeProvider themeProvider, [Function(VoidCallback)? updateState]) {
    void toggleState(VoidCallback fn) {
      // 更新内部状态
      setState(fn);
      // 如果有传入的updateState，也更新overlay状态
      if (updateState != null) {
        updateState(fn);
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.shade50.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.blue.shade100,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 可点击的筛选条件标题行
          InkWell(
            onTap: () {
              toggleState(() {
                _isResultExpanded = !_isResultExpanded;
              });
            },
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.filter_list,
                    size: 16,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '筛选条件',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          result.originalFilter,
                          style: const TextStyle(fontSize: 12),
                          maxLines: _isResultExpanded ? null : 1,
                          overflow: _isResultExpanded ? null : TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isResultExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 18,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
          
          // 详细分析报告（展开时显示）
          if (_isResultExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.analytics,
                        size: 16,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '分析报告',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    result.summary,
                    style: const TextStyle(fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 构建进度指示器
  Widget _buildProgressIndicator(ApiProvider apiProvider) {
    final result = apiProvider.aiFilterResult;
    if (result == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题和百分比
          Row(
            children: [
              Icon(
                Icons.psychology,
                size: 16,
                color: Colors.blue.shade700,
              ),
              const SizedBox(width: 8),
              const Text(
                'AI分析进度',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${(result.progressPercentage * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 10),
          
          // 进度条
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: result.progressPercentage,
              minHeight: 10,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
            ),
          ),
          
          const SizedBox(height: 10),
          
          // 处理数量信息
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildInfoItem(
                      icon: Icons.bar_chart,
                      label: '总计',
                      value: '${result.totalCount}',
                      color: Colors.blue.shade700,
                    ),
                    _buildInfoItem(
                      icon: Icons.done_all,
                      label: '已处理',
                      value: '${result.processedCount}',
                      color: Colors.green.shade600,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildInfoItem(
                      icon: Icons.pending_actions,
                      label: '剩余',
                      value: '${result.totalCount - result.processedCount}',
                      color: Colors.orange,
                    ),
                    _buildInfoItem(
                      icon: Icons.check_circle,
                      label: '符合条件',
                      value: '${result.stocks.length}',
                      color: Colors.blue.shade700,
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // 如果出错，显示错误信息
          if (result.hasError && result.errorMessage != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '错误: ${result.errorMessage}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  // 构建信息项
  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 显示错误详情对话框
  void _showErrorDetailsDialog(String errorMessage, String filterCriteria) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('筛选错误详情'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('错误信息:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(errorMessage),
              const SizedBox(height: 16),
              const Text('筛选条件:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(filterCriteria),
              const SizedBox(height: 16),
              const Text(
                '调试建议:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '1. 检查网络连接\n'
                '2. 检查API设置和密钥\n'
                '3. 检查筛选条件是否过于复杂\n'
                '4. 如果使用自定义API，检查端点是否正确\n'
                '5. 尝试减少筛选条件的复杂度'
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
          TextButton(
            onPressed: () {
              // 复制错误信息到剪贴板
              final detailsText = 
                  '错误信息: $errorMessage\n\n'
                  '筛选条件: $filterCriteria\n\n'
                  '时间: ${DateTime.now().toString()}';
              
              // 使用剪贴板
              Clipboard.setData(ClipboardData(text: detailsText));
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('错误详情已复制到剪贴板')),
              );
            },
            child: const Text('复制详情'),
          ),
        ],
      ),
    );
  }
} 