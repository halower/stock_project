import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:async';
import '../services/client_ai_service.dart';
import '../screens/ai_settings_screen.dart';

class StockAIAnalysis extends StatefulWidget {
  final String stockCode;
  final String stockName;

  const StockAIAnalysis({
    Key? key,
    required this.stockCode,
    required this.stockName,
  }) : super(key: key);

  @override
  State<StockAIAnalysis> createState() => _StockAIAnalysisState();
}

class _StockAIAnalysisState extends State<StockAIAnalysis> with SingleTickerProviderStateMixin {
  final ClientAIService _clientAIService = ClientAIService();
  
  bool _isLoading = false;
  bool _isAnalysisStarted = false;
  String _progressMessage = '点击开始进行AI分析';
  String _report = '';
  String _errorMessage = '';
  double _progress = 0.0;
  late AnimationController _animationController;
  bool _isFromCache = false; // 标记是否来自缓存
  bool _hasError = false; // 是否有错误
  bool _showConfigRequired = false; // 是否显示配置要求
  bool _isInitializing = true; // 初始化状态
  
  // 添加进度阶段控制
  final Map<String, double> _progressStages = {
    'started': 0.1,
    'data_collecting': 0.2,
    'technical_analysis': 0.4,
    'fundamental_analysis': 0.6,
    'market_sentiment': 0.8,
    'risk_assessment': 0.9,
    'completed': 1.0,
  };
  
  // 添加进度提示信息
  final Map<String, String> _stageMessages = {
    'started': '正在连接AI分析服务...',
    'data_collecting': '正在收集股票数据...',
    'technical_analysis': '正在进行技术面分析...',
    'fundamental_analysis': '正在进行基本面分析...',
    'market_sentiment': '正在分析市场情绪...',
    'risk_assessment': '正在进行风险评估...',
    'completed': '分析完成',
  };

  // 添加阶段时间控制
  final Map<String, Duration> _stageDurations = {
    'started': const Duration(seconds: 2),
    'data_collecting': const Duration(seconds: 3),
    'technical_analysis': const Duration(seconds: 10),
    'fundamental_analysis': const Duration(seconds: 10),
    'market_sentiment': const Duration(seconds: 10),
    'risk_assessment': const Duration(seconds: 10),
  };
  
  // 储存原始的响应数据
  Map<String, dynamic> _rawResponse = {};
  String _currentStage = 'started';
  Timer? _stageTimer;
  
  // 添加最后一步的进度控制
  Timer? _finalProgressTimer;
  double _finalProgress = 0.0;
  bool _isFinalStage = false;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animationController.repeat(reverse: true);
    
    // 初始化时检查缓存和远程数据
    _checkInitialData();
  }

  /// 初始化时检查缓存，优先级：本地缓存 > 后端缓存 > 显示分析按钮
  Future<void> _checkInitialData() async {
    try {
      // 1. 先检查本地缓存（10分钟内有效）
      final localCachedAnalysis = await _clientAIService.getCachedAnalysis(widget.stockCode);
      if (localCachedAnalysis != null && mounted) {
        setState(() {
          _report = localCachedAnalysis;
          _isFromCache = true;
          _isAnalysisStarted = true;
          _isInitializing = false;
        });
        debugPrint('初始化时找到有效本地缓存，直接显示');
        return;
      }

      // 2. 本地没有缓存，查询后端是否有缓存
      debugPrint('本地无缓存，查询后端缓存');
      final remoteCacheResult = await _clientAIService.getRemoteAnalysisCache(widget.stockCode);
      
      if (remoteCacheResult != null && mounted) {
        if (remoteCacheResult['has_cache'] == true && remoteCacheResult['analysis'] != null) {
          // 后端有缓存，直接显示
          final analysis = remoteCacheResult['analysis'] as String;
          setState(() {
            _report = analysis;
            _isFromCache = false; // 来自后端，不是本地缓存
            _isAnalysisStarted = true;
            _isInitializing = false;
          });
          // 保存到本地缓存
          await _clientAIService.saveAnalysisToCache(widget.stockCode, analysis);
          debugPrint('从后端获取到分析缓存，已保存到本地');
          return;
        } else {
          // 后端没有缓存，显示分析按钮界面
          debugPrint('后端也没有缓存，显示分析按钮界面');
          setState(() {
            _isAnalysisStarted = false; // 显示分析按钮
            _isInitializing = false;
          });
          return;
        }
      }

      // 3. 查询失败，显示分析按钮界面
      debugPrint('查询后端缓存失败，显示分析按钮界面');
      if (mounted) {
        setState(() {
          _isAnalysisStarted = false; // 显示分析按钮
          _isInitializing = false;
        });
      }
    } catch (e) {
      debugPrint('初始化检查数据出错: $e');
      // 出错时显示分析按钮界面
      if (mounted) {
        setState(() {
          _isAnalysisStarted = false; // 显示分析按钮
          _isInitializing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _stageTimer?.cancel();
    _finalProgressTimer?.cancel();
    super.dispose();
  }
  
  void _updateStage(String stage) {
    if (_stageTimer != null) {
      _stageTimer!.cancel();
    }
    
    setState(() {
      _currentStage = stage;
      _progressMessage = _stageMessages[stage]!;
      _progress = _progressStages[stage]!;
      
      // 检查是否是最后一步
      _isFinalStage = stage == 'risk_assessment';
      if (_isFinalStage) {
        _startFinalProgress();
      } else {
        _finalProgressTimer?.cancel();
        _finalProgress = 0.0;
      }
    });

    if (stage != 'completed' && _stageDurations.containsKey(stage)) {
      _stageTimer = Timer(_stageDurations[stage]!, () {
        // 获取下一个阶段
        final stages = _progressStages.keys.toList();
        final currentIndex = stages.indexOf(stage);
        if (currentIndex < stages.length - 1) {
          _updateStage(stages[currentIndex + 1]);
        }
      });
    }
  }

  void _startFinalProgress() {
    _finalProgressTimer?.cancel();
    _finalProgress = 0.0;
    
    // 每200毫秒增加0.2%的进度，直到99.8%
    _finalProgressTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (_finalProgress < 0.098) {  // 从90%到99.8%
        setState(() {
          _finalProgress += 0.002;
          _progress = 0.9 + _finalProgress;
        });
      } else {
        timer.cancel();
      }
    });
  }
  
  Future<void> _startAnalysis({bool forceRefresh = false}) async {
    if (_isLoading) {
      return; // 避免重复启动
    }
    
    setState(() {
      _isAnalysisStarted = true;
      _isLoading = true;
      _progressMessage = forceRefresh ? '正在刷新分析...' : _stageMessages['started']!;
      _report = '';
      _errorMessage = '';
      _progress = 0.0;
      _finalProgress = 0.0;
      _isFinalStage = false;
      _rawResponse = {};
      _currentStage = 'started';
      _isFromCache = false;
    });
    
    // 开始第一个阶段
    _updateStage('started');
    
    try {
      // 使用客户端AI服务获取分析，支持强制刷新
      final stream = _clientAIService.getStockAnalysisStream(widget.stockCode, widget.stockName, forceRefresh: forceRefresh);
      
      await for (final data in stream) {
        if (!mounted) return;
        
        debugPrint('处理AI分析流数据: ${data['status']}');
        
        // 保存原始响应
        _rawResponse = data;
        
        // 处理不同状态
        switch (data['status']) {
          case 'started':
            _updateStage('started');
            break;
            
          case 'checking_cache':
            setState(() {
              _progressMessage = data['message'] ?? '检查本地缓存...';
              _progress = 0.05;
            });
            break;
            
          case 'fetching_data':
            setState(() {
              _progressMessage = data['message'] ?? '正在获取历史数据...';
              _progress = 0.15;
            });
            break;
            
          case 'checking_ai_config':
            setState(() {
              _progressMessage = data['message'] ?? '检查AI配置...';
              _progress = 0.25;
            });
            break;
            
          case 'analyzing':
            setState(() {
              _progressMessage = data['message'] ?? '正在进行AI分析...';
              _progress = 0.3;
            });
            break;
            
          case 'config_required':
            setState(() {
              _isLoading = false;
              _hasError = true;
              _errorMessage = '需要配置AI服务才能使用分析功能';
              _showConfigRequired = true;
            });
            break;
            
          case 'processing':
            setState(() {
              // 更新进度消息
              if (data.containsKey('stage') && _stageMessages.containsKey(data['stage'])) {
                _updateStage(data['stage']);
              } else {
                _progressMessage = data['message'] ?? '正在分析...';
              }
              
              // 如果有部分内容，实时显示
              if (data.containsKey('content')) {
                _report += data['content'];
              }
            });
            break;
            
          case 'completed':
            _stageTimer?.cancel();
            _finalProgressTimer?.cancel();
            // 检查是否来自缓存
            final fromCache = data['from_cache'] == true;
            if (!fromCache) {
            // 添加一个短暂的延迟，让用户看到100%
            await Future.delayed(const Duration(milliseconds: 500));
            }
            if (!mounted) return;
            
            setState(() {
              _isLoading = false;
              _progress = 1.0;
              _isFromCache = fromCache;
              _progressMessage = fromCache ? '已从缓存加载' : _stageMessages['completed']!;
              
              // 详细调试completed数据
              debugPrint('收到completed状态数据: $data');
              
              // 首先尝试从analysis字段获取报告内容
              if (data.containsKey('analysis') && data['analysis'] is String && data['analysis'].isNotEmpty) {
                _report = data['analysis'];
                debugPrint('从analysis字段获取到报告内容，长度: ${_report.length}');
              }
              // 如果analysis字段没有内容，尝试从data字段获取
              else if (data.containsKey('data')) {
                debugPrint('尝试从data字段获取内容: ${data['data']}');
                if (data['data'] is Map<String, dynamic>) {
                  final reportData = data['data'] as Map<String, dynamic>;
                  debugPrint('data字段是Map: ${reportData.keys}');
                  if (reportData.containsKey('report')) {
                    // 如果已经有内容，则追加
                    if (_report.isEmpty) {
                      _report = reportData['report'];
                    } else {
                      _report += reportData['report'];
                    }
                    debugPrint('成功提取报告，长度: ${_report.length}');
                  } else {
                    _report = '未找到报告内容';
                    debugPrint('报告字段不存在');
                  }
                } else {
                  _report = '数据格式错误: data字段不是Map';
                  debugPrint('data字段不是Map: ${data['data'].runtimeType}');
                }
              } else {
                _report = data['message'] ?? '分析完成，但未返回报告内容';
                debugPrint('未找到report字段');
              }
              
              // 如果报告还是空，尝试使用原始响应的其他字段
              if (_report.isEmpty || _report == '分析完成，但未返回报告内容') {
                // 遍历所有字段，查找可能包含内容的字段
                data.forEach((key, value) {
                  if (value is String && value.length > 50 && key != 'status' && key != 'message') {
                    _report = value;
                    debugPrint('从字段 $key 中找到内容');
                  }
                });
                
                // 如果仍然没有内容，使用备用提示
                if (_report.isEmpty || _report == '分析完成，但未返回报告内容') {
                  _report = '''
# ${widget.stockName} (${widget.stockCode}) 分析报告

很抱歉，AI分析服务未能返回详细内容。这可能是由于以下原因：

1. 网络连接问题
2. 服务器暂时不可用
3. 分析模型处理异常

建议您稍后再试，或查看其他股票分析工具和资源。
''';
                }
              }
            });
            break;
            
          case 'error':
            _stageTimer?.cancel();
            _finalProgressTimer?.cancel();
            setState(() {
              _isLoading = false;
              _errorMessage = data['message'] ?? '分析过程中发生错误';
            });
            break;
            
          default:
            debugPrint('未知状态: ${data['status']}');
            break;
        }
      }
    } catch (e) {
      // 内部处理错误，不向外传递
      debugPrint('AI分析流处理异常: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '连接AI分析服务失败: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 初始化加载状态
    if (_isInitializing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text(
              '正在检查缓存...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    // 有分析结果时，直接显示结果（无论是缓存还是新分析的）
    if (_report.isNotEmpty && !_isLoading) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题和缓存状态
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${widget.stockName} (${widget.stockCode}) ',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                                     if (_isFromCache) ...[
                     Container(
                       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                       decoration: BoxDecoration(
                         color: Colors.green,
                         borderRadius: BorderRadius.circular(12),
                       ),
                       child: const Text(
                         '来自本地缓存',
                         style: TextStyle(
                           color: Colors.white,
                           fontSize: 12,
                           fontWeight: FontWeight.bold,
                         ),
                       ),
                     ),
                   ] else if (_report.isNotEmpty) ...[
                     Container(
                       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                       decoration: BoxDecoration(
                         color: Colors.blue,
                         borderRadius: BorderRadius.circular(12),
                       ),
                       child: const Text(
                         '来自后端服务',
                         style: TextStyle(
                           color: Colors.white,
                           fontSize: 12,
                           fontWeight: FontWeight.bold,
                         ),
                       ),
                     ),
                   ],
                  // 添加菜单按钮
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'refresh') {
                        _startAnalysis(forceRefresh: true);
                      } else if (value == 'restart') {
                        setState(() {
                          _isAnalysisStarted = false;
                          _report = '';
                          _errorMessage = '';
                          _isFromCache = false;
                        });
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'refresh',
                        child: Row(
                          children: [
                            Icon(Icons.refresh, size: 18),
                            SizedBox(width: 8),
                            Text('刷新分析'),
                          ],
                        ),
                      )
                    ],
                  ),
                ],
              ),
            ),
            
            // 分析结果内容
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[850]  // 暗色模式：深灰色背景
                    : Colors.grey[50],   // 亮色模式：浅灰色背景
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[700]!  // 暗色模式：灰色边框
                      : Colors.grey[300]!,  // 亮色模式：浅灰色边框
                ),
              ),
              child: MarkdownBody(
                data: _report,
                selectable: true,
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                  // 确保文本颜色适配主题
                  p: Theme.of(context).textTheme.bodyMedium,
                  h1: Theme.of(context).textTheme.headlineMedium,
                  h2: Theme.of(context).textTheme.headlineSmall,
                  h3: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            
            // 底部提示信息
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[600], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isFromCache 
                        ? '此分析结果来自10分钟内的本地缓存，可节约流量。如需最新分析请点击"刷新分析"。'
                        : _report.isNotEmpty 
                          ? '此分析结果来自后端缓存，已同步保存到本地缓存，10分钟内有效。'
                          : '分析结果已保存到本地缓存，10分钟内有效。',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[600],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    
    // 未开始分析时，显示分析按钮界面
    if (!_isAnalysisStarted) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.psychology,
              size: 64,
              color: Colors.blue,
            ),
            const SizedBox(height: 20),
            Text(
              '点击下方按钮开始对${widget.stockName}进行AI分析',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '分析将基于技术面、基本面和市场情绪综合评估',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _startAnalysis,
              icon: const Icon(Icons.play_arrow),
              label: const Text('开始分析'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }
    
    // 正在加载
    if (_isLoading) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade50,
              Colors.white,
              Colors.purple.shade50,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              
              // 现代化标题设计
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade600, Colors.purple.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.psychology_outlined,
                      color: Colors.white,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.stockName} (${widget.stockCode})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'AI智能分析中',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              // 圆形进度指示器
              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue.shade100,
                      Colors.purple.shade100,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 背景圆环
                    SizedBox(
                      width: 140,
                      height: 140,
                      child: CircularProgressIndicator(
                        value: 1.0,
                        strokeWidth: 8,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.grey.shade200,
                        ),
                      ),
                    ),
                    
                    // 进度圆环
                    SizedBox(
                      width: 140,
                      height: 140,
                      child: AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          return CircularProgressIndicator(
                            value: _progress,
                            strokeWidth: 8,
                            strokeCap: StrokeCap.round,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color.lerp(
                                Colors.blue.shade400,
                                Colors.purple.shade400,
                                _animationController.value,
                              )!,
                            ),
                          );
                        },
                      ),
                    ),
                    
                    // 中心内容
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedBuilder(
                          animation: _animationController,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: 1.0 + (_animationController.value * 0.1),
                              child: Icon(
                                Icons.auto_awesome,
                                size: 40,
                                color: Color.lerp(
                                  Colors.blue.shade600,
                                  Colors.purple.shade600,
                                  _animationController.value,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(_progress * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 30),
              
              // 当前状态消息卡片
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _getProgressColor().withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _getCurrentStageIcon(),
                            color: _getProgressColor(),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _progressMessage,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2D3748),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // 进度阶段指示器
                    _buildStageIndicators(),
                  ],
                ),
              ),
              
              const SizedBox(height: 30),
              
              // 实时分析内容（如果有）
              if (_report.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.green.shade50,
                        Colors.blue.shade50,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.green.shade200,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.auto_stories_outlined,
                            color: Colors.green.shade600,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '实时分析结果',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.1),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: MarkdownBody(
                          data: _report,
                          selectable: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
    
    // 分析出错
    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 20),
            const Text(
              '分析过程中出现错误',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 30),
            if (_showConfigRequired) ...[
              // 显示配置AI服务的按钮
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AISettingsScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.settings),
                label: const Text('配置AI服务'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _isAnalysisStarted = false;
                    _errorMessage = '';
                    _showConfigRequired = false;
                    _hasError = false;
                  });
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('返回'),
              ),
            ] else ...[
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isAnalysisStarted = false;
                  _errorMessage = '';
                    _hasError = false;
                });
              },
              icon: const Icon(Icons.refresh),
              label: const Text('重新开始'),
            ),
            ],
          ],
        ),
      );
    }

    // 默认情况：显示空白或加载状态
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
  
  // 获取进度条颜色
  Color _getProgressColor() {
    if (_progress < 0.3) {
      return Colors.blue.shade500;
    } else if (_progress < 0.6) {
      return Colors.indigo.shade500;
    } else if (_progress < 0.9) {
      return Colors.purple.shade500;
    } else {
      return Colors.green.shade500;
    }
  }

  IconData _getCurrentStageIcon() {
    switch (_currentStage) {
      case 'started':
        return Icons.connect_without_contact;
      case 'data_collecting':
        return Icons.data_usage;
      case 'technical_analysis':
        return Icons.analytics;
      case 'fundamental_analysis':
        return Icons.bar_chart;
      case 'market_sentiment':
        return Icons.sentiment_satisfied;
      case 'risk_assessment':
        return Icons.security;
      case 'completed':
        return Icons.check_circle;
      default:
        return Icons.help;
    }
  }

  Widget _buildStageIndicators() {
    final stages = _progressStages.keys.toList();
    return Column(
      children: [
        // 阶段标签
        Text(
          '分析阶段',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        
        // 阶段指示器
        Container(
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(2),
          ),
          child: Stack(
            children: [
              // 进度填充
              FractionallySizedBox(
                widthFactor: _progress,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  height: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.blue.shade400,
                        Colors.purple.shade400,
                        Colors.green.shade400,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 12),
        
        // 阶段点
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: stages.asMap().entries.map((entry) {
            final index = entry.key;
            final stage = entry.value;
            final stageProgress = _progressStages[stage]!;
            final isActive = _progress >= stageProgress;
            final isCurrent = _currentStage == stage;
            
            return Expanded(
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: isCurrent ? 12 : 8,
                    height: isCurrent ? 12 : 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive 
                        ? _getProgressColor() 
                        : Colors.grey.shade300,
                      boxShadow: isCurrent ? [
                        BoxShadow(
                          color: _getProgressColor().withOpacity(0.5),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ] : [],
                    ),
                    child: isCurrent ? 
                      AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          return Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _getProgressColor().withOpacity(
                                0.7 + (0.3 * _animationController.value)
                              ),
                            ),
                          );
                        },
                      ) : null,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // 阶段标签
                  Text(
                    _getStageDisplayName(stage),
                    style: TextStyle(
                      fontSize: 10,
                      color: isActive 
                        ? _getProgressColor() 
                        : Colors.grey.shade500,
                      fontWeight: isCurrent 
                        ? FontWeight.w600 
                        : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  String _getStageDisplayName(String stage) {
    switch (stage) {
      case 'started':
        return '启动';
      case 'data_collecting':
        return '数据收集';
      case 'technical_analysis':
        return '技术分析';
      case 'fundamental_analysis':
        return '基本面';
      case 'market_sentiment':
        return '市场情绪';
      case 'risk_assessment':
        return '风险评估';
      case 'completed':
        return '完成';
      default:
        return '进行中';
    }
  }
}