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
  bool _showConfigRequired = false; // 是否显示配置要求
  bool _isInitializing = true; // 初始化状态
  
  // 添加进度阶段控制 - 优化为技术分析相关
  final Map<String, double> _progressStages = {
    'started': 0.1,
    'fetching_data': 0.25,
    'calculating_indicators': 0.4,
    'bull_analysis': 0.6,
    'bear_analysis': 0.8,
    'final_verdict': 0.95,
    'completed': 1.0,
  };
  
  // 添加进度提示信息 - 优化为多空辩论流程
  final Map<String, String> _stageMessages = {
    'started': '🚀 启动AI多空辩论分析...',
    'fetching_data': '📊 获取K线数据...',
    'calculating_indicators': '🧮 计算技术指标...',
    'bull_analysis': '🐂 多方正在分析看涨理由...',
    'bear_analysis': '🐻 空方正在分析看跌理由...',
    'final_verdict': '⚖️ 综合研判中...',
    'completed': '✅ 分析完成',
  };

  // 添加阶段时间控制
  final Map<String, Duration> _stageDurations = {
    'started': const Duration(seconds: 1),
    'fetching_data': const Duration(seconds: 2),
    'calculating_indicators': const Duration(seconds: 2),
    'bull_analysis': const Duration(seconds: 8),
    'bear_analysis': const Duration(seconds: 8),
    'final_verdict': const Duration(seconds: 5),
  };
  
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
    
    // 每300毫秒增加0.1%的进度，最多到99%，避免用户认为已完成
    _finalProgressTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      if (_finalProgress < 0.09) {  // 从95%到99%，不到100%
        setState(() {
          _finalProgress += 0.001;
          _progress = 0.95 + _finalProgress;
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
        
        // 处理不同状态
        switch (data['status']) {
          case 'started':
            _updateStage('started');
            break;
            
          case 'checking_cache':
            _updateStage('started');
            break;
            
          case 'fetching_data':
            _updateStage('fetching_data');
            break;
            
          case 'checking_ai_config':
            _updateStage('calculating_indicators');
            break;
            
          case 'analyzing':
            _updateStage('bull_analysis');
            break;
            
          case 'config_required':
            setState(() {
              _isLoading = false;
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
            
            if (!mounted) return;
            
            setState(() {
              _isLoading = false;
              _progress = 1.0;  // 只有在真正完成时才设置为100%
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
            
            // 分析结果内容 - 优化展示多空辩论
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.blue.shade50.withOpacity(0.3),
                    Colors.white.withOpacity(0.3),
                    Colors.red.shade50.withOpacity(0.3),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.blue.shade200,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题栏
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade600, Colors.purple.shade600],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(14),
                        topRight: Radius.circular(14),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.psychology, color: Colors.white, size: 24),
                        const SizedBox(width: 8),
                        const Text(
                          'AI 多空辩论分析',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // 分析内容
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: MarkdownBody(
                      data: _report,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                        // 确保文本颜色适配主题
                        p: Theme.of(context).textTheme.bodyMedium,
                        h1: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                        h2: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.purple.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                        h3: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.indigo.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                        listBullet: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.blue.shade600,
                        ),
                        strong: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // 底部提示信息 - 美化版
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade50, Colors.purple.shade50],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade600, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '分析说明',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isFromCache 
                      ? '📌 此分析结果来自10分钟内的本地缓存，可节约流量。如需最新分析请点击"刷新分析"。'
                      : _report.isNotEmpty 
                        ? '📌 此分析采用多空辩论模式，更贴近真实市场博弈。\n💡 重点关注短线机会(1-3天)，适合散户操作。\n⚠️ 技术指标由客户端计算后传递给AI分析。'
                        : '📌 分析结果已保存到本地缓存，10分钟内有效。',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    
    // 未开始分析时，显示分析按钮界面 - 美化版
    if (!_isAnalysisStarted) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 主图标
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.blue.shade400, Colors.purple.shade400],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.psychology,
                size: 64,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 30),
            
            // 标题
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                '点击下方按钮开始对\n${widget.stockName}进行AI多空辩论分析',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // 特性说明
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                children: [
                  _buildFeatureRow(Icons.trending_up, '多空辩论模式'),
                  const SizedBox(height: 8),
                  _buildFeatureRow(Icons.access_time, '关注短线机会(1-3天)'),
                  const SizedBox(height: 8),
                  _buildFeatureRow(Icons.calculate, '客户端计算技术指标'),
                ],
              ),
            ),
            const SizedBox(height: 30),
            
            // 开始按钮
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: LinearGradient(
                  colors: [Colors.blue.shade600, Colors.purple.shade600],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _startAnalysis,
                icon: const Icon(Icons.play_arrow, color: Colors.white),
                label: const Text(
                  '开始分析',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
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
                    colors: [Colors.red.shade400, Colors.blue.shade600],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '🐻',
                          style: TextStyle(fontSize: 24),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'VS',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '🐂',
                          style: TextStyle(fontSize: 24),
                        ),
                      ],
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
                      '多空辩论分析中',
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
              
              // 圆形进度指示器 - 多空对决风格
              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Colors.red.shade100,
                      Colors.blue.shade100,
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.2),
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
                        strokeWidth: 10,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.grey.shade200,
                        ),
                      ),
                    ),
                    
                    // 进度圆环 - 渐变色从红到蓝
                    SizedBox(
                      width: 140,
                      height: 140,
                      child: AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          // 根据进度改变颜色：前半段红色(空方)，后半段蓝色(多方)
                          Color progressColor;
                          if (_progress < 0.5) {
                            progressColor = Colors.red.shade400;
                          } else if (_progress < 0.8) {
                            progressColor = Colors.blue.shade400;
                          } else {
                            progressColor = Colors.green.shade400;
                          }
                          
                          return CircularProgressIndicator(
                            value: _progress,
                            strokeWidth: 10,
                            strokeCap: StrokeCap.round,
                            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                          );
                        },
                      ),
                    ),
                    
                    // 中心内容 - 显示当前阶段图标
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getCurrentStageIcon(),
                          size: 45,
                          color: _getProgressColor(),
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
        return Icons.rocket_launch;
      case 'fetching_data':
        return Icons.show_chart;
      case 'calculating_indicators':
        return Icons.calculate;
      case 'bull_analysis':
        return Icons.trending_up;
      case 'bear_analysis':
        return Icons.trending_down;
      case 'final_verdict':
        return Icons.balance;
      case 'completed':
        return Icons.check_circle;
      default:
        return Icons.psychology;
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
          children: stages.map((stage) {
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
      case 'fetching_data':
        return '获取数据';
      case 'calculating_indicators':
        return '计算指标';
      case 'bull_analysis':
        return '🐂多方';
      case 'bear_analysis':
        return '🐻空方';
      case 'final_verdict':
        return '⚖️研判';
      case 'completed':
        return '完成';
      default:
        return '进行中';
    }
  }
  
  // 构建特性行
  Widget _buildFeatureRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.blue.shade600),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: Colors.blue.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}