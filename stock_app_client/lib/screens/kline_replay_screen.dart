/// 增强版K线回放训练屏幕
/// 类似TradingView的专业回放功能
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/kline_replay_service.dart';
import '../services/providers/theme_provider.dart';
import '../services/providers/api_provider.dart';
import '../widgets/replay_control_panel.dart';
import '../widgets/stock_k_line_chart.dart';
import '../models/replay_training_session.dart';
import 'dart:async';
import 'dart:math';

class EnhancedKLineReplayScreen extends StatefulWidget {
  const EnhancedKLineReplayScreen({super.key});

  @override
  State<EnhancedKLineReplayScreen> createState() => _EnhancedKLineReplayScreenState();
}

class _EnhancedKLineReplayScreenState extends State<EnhancedKLineReplayScreen> {
  final KLineReplayService _replayService = KLineReplayService();
  String? _selectedStockCode;
  String? _selectedStockName;
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _autoPlayTimer;
  bool _isLandscape = false;
  
  // 训练会话
  ReplayTrainingSession? _session;
  double _initialCapital = 100000; // 默认10万初始资金
  
  // 技术指标
  List<TechnicalIndicator> _indicators = TechnicalIndicator.getDefaultIndicators();
  
  @override
  void initState() {
    super.initState();
    // 自动加载股票并开始训练
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoLoadAndStartTraining();
    });
  }
  
  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _replayService.dispose();
    // 恢复竖屏
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }
  
  /// 自动加载股票并开始训练
  Future<void> _autoLoadAndStartTraining() async {
    await _loadRandomStock();
    if (_selectedStockCode != null) {
      _startTraining();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    // 横屏模式使用全屏布局
    if (_isLandscape) {
      return _buildLandscapeLayout(themeProvider);
    }
    
    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) {
            final parentScaffold = context.findAncestorStateOfType<ScaffoldState>();
            if (parentScaffold != null && parentScaffold.hasDrawer) {
              return IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () {
                  parentScaffold.openDrawer();
                },
              );
            }
            return const SizedBox.shrink();
          },
        ),
        title: Text(_selectedStockName ?? '专业K线回放训练'),
        actions: [
          // 随机选股按钮（训练中也可用）
          IconButton(
            icon: const Icon(Icons.shuffle),
            onPressed: () async {
              // 如果正在训练，直接结束并显示报告
              if (_session != null) {
                await _endTraining();
              }
              
              // 加载新股票并开始训练
              await _loadRandomStock();
              if (_selectedStockCode != null) {
                _startTraining();
              }
            },
            tooltip: '随机选股',
          ),
          // 横屏/竖屏切换
          IconButton(
            icon: Icon(_isLandscape ? Icons.screen_lock_portrait : Icons.screen_lock_landscape),
            onPressed: _toggleOrientation,
            tooltip: _isLandscape ? '竖屏' : '横屏',
          ),
          // 技术指标设置 - 使用更明显的图标和样式
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue, width: 1.5),
            ),
            child: IconButton(
              icon: const Icon(Icons.insights, color: Colors.blue),
              onPressed: _showIndicatorSettings,
              tooltip: '技术指标',
            ),
          ),
          // 训练设置
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showTrainingSettings,
            tooltip: '训练设置',
          ),
        ],
      ),
      body: Column(
        children: [
          // 训练信息栏
          if (_session != null && !_isLandscape) _buildTrainingInfoBar(),
          
          // K线图表区域
          Expanded(
            flex: 3,
            child: _buildChartArea(themeProvider),
          ),
          
          // 交易按钮区域
          if (_replayService.isReplayActive && !_replayService.isReplayFinished)
            _buildTradingButtons(),
          
          // 回放控制面板
          ReplayControlPanel(
            replayService: _replayService,
            onPlayPause: _togglePlayPause,
            onNext: _nextCandle,
            onPrevious: _previousCandle,
            onSpeedChange: (int speed) => _changeSpeed(speed.toDouble()),
            onReset: _resetReplay,
            onSeek: (int index) {
              setState(() {}); // 通知UI更新
            },
          ),
        ],
      ),
    );
  }
  
  /// 构建训练信息栏（添加滑动支持）
  Widget _buildTrainingInfoBar() {
    if (_session == null) return const SizedBox.shrink();
    
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(
            color: Colors.blue.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // 训练信息（可滑动）
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // 初始资金
                  _buildInfoItem(
                    '初始',
                    '¥${(_session!.initialCapital / 10000).toStringAsFixed(1)}万',
                    Icons.account_balance_wallet,
                  ),
                  const SizedBox(width: 12),
                  
                  // 当前资金
                  _buildInfoItem(
                    '当前',
                    '¥${(_session!.currentCapital / 10000).toStringAsFixed(2)}万',
                    Icons.account_balance,
                    color: _session!.currentCapital >= _session!.initialCapital
                        ? Colors.red
                        : Colors.green,
                  ),
                  const SizedBox(width: 12),
                  
                  // 盈亏
                  _buildInfoItem(
                    '盈亏',
                    '${_session!.totalProfitLoss >= 0 ? '+' : ''}¥${_session!.totalProfitLoss.toStringAsFixed(0)}',
                    Icons.trending_up,
                    color: _session!.totalProfitLoss >= 0 ? Colors.red : Colors.green,
                  ),
                  const SizedBox(width: 12),
                  
                  // 盈亏率
                  _buildInfoItem(
                    '收益率',
                    '${_session!.profitLossRate >= 0 ? '+' : ''}${_session!.profitLossRate.toStringAsFixed(2)}%',
                    Icons.percent,
                    color: _session!.profitLossRate >= 0 ? Colors.red : Colors.green,
                  ),
                  const SizedBox(width: 12),
                  
                  // 交易次数和胜率
                  _buildInfoItem(
                    '交易',
                    '${_session!.totalTrades}次',
                    Icons.assessment,
                  ),
                  const SizedBox(width: 12),
                  
                  _buildInfoItem(
                    '胜率',
                    '${_session!.winRate.toStringAsFixed(1)}%',
                    Icons.emoji_events,
                    color: _session!.winRate >= 50 ? Colors.orange : Colors.grey,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoItem(String label, String value, IconData icon, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color ?? Colors.grey),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10, 
                color: Colors.grey,
                height: 1.2,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
                height: 1.2,
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  /// 构建图表区域
  Widget _buildChartArea(ThemeProvider themeProvider) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadRandomStock,
              child: const Text('重新选择'),
            ),
          ],
        ),
      );
    }
    
    if (_selectedStockCode == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.candlestick_chart, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '请选择股票开始训练',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }
    
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _replayService.visibleDataStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('暂无数据'));
        }
        
        return Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
            child: StockKLineChart(
              data: snapshot.data!,
              showVolume: true,
              indicators: _indicators.where((i) => i.enabled).toList(),
              trades: _session?.trades, // 传递交易记录
            ),
            ),
            
            // 当前价格信息
            Positioned(
              top: 16,
              left: 16,
              child: _buildCurrentPriceInfo(snapshot.data!.last),
            ),
            
            // 持仓信息
            if (_session != null && _session!.currentPosition > 0)
              Positioned(
                top: 16,
                right: 16,
                child: _buildPositionInfo(),
              ),
          ],
        );
      },
    );
  }
  
  /// 构建当前价格信息（缩小版）
  Widget _buildCurrentPriceInfo(Map<String, dynamic> currentCandle) {
    final open = currentCandle['open'] ?? 0.0;
    final high = currentCandle['high'] ?? 0.0;
    final low = currentCandle['low'] ?? 0.0;
    final close = currentCandle['close'] ?? 0.0;
    final volume = currentCandle['volume'] ?? 0.0;
    final date = currentCandle['trade_date'] ?? '';
    
    // 计算涨跌幅
    final change = close - open;
    final changePercent = open > 0 ? (change / open) * 100 : 0.0;
    final isRise = change >= 0;
    final changeColor = isRise ? Colors.red : Colors.green;
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$_selectedStockName',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
              height: 1.2,
            ),
          ),
          Text(
            date,
            style: const TextStyle(
              color: Colors.white70, 
              fontSize: 9,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          _buildPriceRow('开', open),
          _buildPriceRow('高', high),
          _buildPriceRow('低', low),
          _buildPriceRow('收', close, bold: true),
          const SizedBox(height: 2),
          // 涨跌幅
          Row(
            children: [
              Text(
                '涨跌: ',
                style: const TextStyle(
                  color: Colors.white70, 
                  fontSize: 10,
                  height: 1.2,
                ),
              ),
              Text(
                '${isRise ? '+' : ''}${changePercent.toStringAsFixed(2)}%',
                style: TextStyle(
                  color: changeColor,
                  fontSize: 10,
                  height: 1.2,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          // 成交量
          Row(
            children: [
              Text(
                '量: ',
                style: const TextStyle(
                  color: Colors.white70, 
                  fontSize: 10,
                  height: 1.2,
                ),
              ),
              Text(
                _formatVolume(volume),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  /// 格式化成交量
  String _formatVolume(double volume) {
    if (volume >= 100000000) {
      return '${(volume / 100000000).toStringAsFixed(2)}亿';
    } else if (volume >= 10000) {
      return '${(volume / 10000).toStringAsFixed(2)}万';
    } else {
      return volume.toStringAsFixed(0);
    }
  }
  
  Widget _buildPriceRow(String label, double price, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              color: Colors.white70, 
              fontSize: 10,
              height: 1.2,
            ),
          ),
          Text(
            price.toStringAsFixed(2),
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              height: 1.2,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
  
  /// 构建持仓信息
  Widget _buildPositionInfo() {
    if (_session == null || _session!.currentPosition == 0) {
      return const SizedBox.shrink();
    }
    
    final currentPrice = _replayService.currentCandle?['close'] ?? 0.0;
    final positionValue = currentPrice * _session!.currentPosition;
    final costValue = (_session!.positionCost ?? 0) * _session!.currentPosition;
    final unrealizedPL = positionValue - costValue;
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.8),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '持仓',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_session!.currentPosition}股',
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
          Text(
            '¥${_session!.positionCost?.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
          Text(
            '${unrealizedPL >= 0 ? '+' : ''}${unrealizedPL.toStringAsFixed(0)}',
            style: TextStyle(
              color: unrealizedPL >= 0 ? Colors.yellow : Colors.orange,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  /// 构建交易按钮
  Widget _buildTradingButtons() {
    if (_session == null) return const SizedBox.shrink();
    
    final currentPrice = _replayService.currentCandle?['close'] ?? 0.0;
    final canBuy = _session!.currentCapital >= currentPrice * 100; // 至少能买1手
    final canSell = _session!.currentPosition > 0;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Row(
        children: [
          // 买入按钮
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: canBuy ? () => _executeTrade('buy') : null,
              icon: const Icon(Icons.arrow_upward, size: 18),
              label: const Text('买入', style: TextStyle(fontSize: 14)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                disabledBackgroundColor: Colors.grey[300],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 卖出按钮
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: canSell ? () => _executeTrade('sell') : null,
              icon: const Icon(Icons.arrow_downward, size: 18),
              label: const Text('卖出', style: TextStyle(fontSize: 14)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                disabledBackgroundColor: Colors.grey[300],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 结束按钮
          Expanded(
            flex: 1,
            child: OutlinedButton(
              onPressed: _session != null ? _endTraining : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey[700],
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: Colors.grey[400]!),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('结束', style: TextStyle(fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
  
  /// 加载随机股票
  Future<void> _loadRandomStock() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final apiProvider = Provider.of<ApiProvider>(context, listen: false);
      final scanResults = apiProvider.scanResults;
      
      if (scanResults.isNotEmpty) {
        final random = Random();
        final randomStock = scanResults[random.nextInt(scanResults.length)];
        _selectedStockCode = randomStock.code;
        _selectedStockName = randomStock.name;
      } else {
        final stockCodes = ['600519', '000858', '601318', '600036', '000001'];
        final random = Random();
        _selectedStockCode = stockCodes[random.nextInt(stockCodes.length)];
        _selectedStockName = '随机股票';
      }
      
      await _replayService.loadStock(_selectedStockCode!);
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '加载失败: $e';
      });
    }
  }
  
  /// 开始训练
  void _startTraining() {
    if (_selectedStockCode == null || _selectedStockName == null) return;
    
    setState(() {
      _session = ReplayTrainingSession(
        stockCode: _selectedStockCode!,
        stockName: _selectedStockName!,
        initialCapital: _initialCapital,
      );
    });
    
    // 启动回放并自动开始播放
    _replayService.startReplay();
    // 自动启动播放定时器
    _autoPlayTimer = Timer.periodic(
      const Duration(milliseconds: 1000),
      (_) => _nextCandle(),
    );
  }
  
  /// 执行交易
  void _executeTrade(String action) async {
    if (_session == null) return;
    
    final currentCandle = _replayService.currentCandle;
    if (currentCandle == null) return;
    
    final price = currentCandle['close'] as double;
    final date = currentCandle['trade_date'] as String;
    
    if (action == 'buy') {
      // 买入：使用所有可用资金
      final maxQuantity = (_session!.currentCapital / price).floor();
      final quantity = (maxQuantity ~/ 100) * 100; // 整手
      
      if (quantity < 100) {
        _showMessage('资金不足，无法买入');
        return;
      }
      
      final cost = price * quantity;
      _session!.currentCapital -= cost;
      _session!.currentPosition += quantity;
      _session!.positionCost = price;
      
      final trade = ReplayTrade(
        action: 'buy',
        price: price,
        quantity: quantity,
        time: DateTime.now(),
        date: date,
      );
      
      _session!.trades.add(trade);
      _showMessage('买入成功: ${quantity}股 @¥${price.toStringAsFixed(2)}');
      
    } else if (action == 'sell') {
      // 卖出：卖出所有持仓
      final quantity = _session!.currentPosition;
      final revenue = price * quantity;
      final cost = (_session!.positionCost ?? 0) * quantity;
      final profitLoss = revenue - cost;
      final profitLossRate = cost > 0 ? (profitLoss / cost) * 100 : 0;
      
      _session!.currentCapital += revenue;
      _session!.currentPosition = 0;
      _session!.positionCost = null;
      
      final trade = ReplayTrade(
        action: 'sell',
        price: price,
        quantity: quantity,
        time: DateTime.now(),
        date: date,
        profitLoss: profitLoss.toDouble(),
        profitLossRate: profitLossRate.toDouble(),
      );
      
      _session!.trades.add(trade);
      _showMessage(
        '卖出成功: ${quantity}股 @¥${price.toStringAsFixed(2)}\n'
        '盈亏: ${profitLoss >= 0 ? '+' : ''}¥${profitLoss.toStringAsFixed(2)} (${profitLossRate.toStringAsFixed(2)}%)'
      );
    }
    
    setState(() {});
  }
  
  /// 结束训练
  Future<void> _endTraining() async {
    if (_session == null) return;
    
    _session!.endSession();
    await _showTrainingReport();
  }
  
  /// 显示训练报告（类似TradingView样式）
  Future<void> _showTrainingReport() async {
    if (_session == null) return;
    
    final isProfitable = _session!.totalProfitLoss >= 0;
    
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 顶部盈亏展示（大标题）
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: (isProfitable ? Colors.red : Colors.green).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      isProfitable ? Icons.trending_up : Icons.trending_down,
                      size: 48,
                      color: isProfitable ? Colors.red : Colors.green,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${isProfitable ? '+' : ''}¥${_session!.totalProfitLoss.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: isProfitable ? Colors.red : Colors.green,
                      ),
                    ),
                    Text(
                      '${isProfitable ? '+' : ''}${_session!.profitLossRate.toStringAsFixed(2)}%',
                      style: TextStyle(
                        fontSize: 18,
                        color: isProfitable ? Colors.red : Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // 详细数据
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildTVReportRow('股票', '${_session!.stockName}'),
                    _buildTVReportRow('时长', '${_session!.durationMinutes}分钟'),
                    const Divider(height: 20),
                    _buildTVReportRow('初始', '¥${(_session!.initialCapital / 10000).toStringAsFixed(1)}万'),
                    _buildTVReportRow('最终', '¥${(_session!.currentCapital / 10000).toStringAsFixed(2)}万'),
                    const Divider(height: 20),
                    _buildTVReportRow('交易', '${_session!.totalTrades}次'),
                    _buildTVReportRow('胜率', '${_session!.winRate.toStringAsFixed(1)}%'),
                    _buildTVReportRow('盈亏比', _session!.profitLossRatio.toStringAsFixed(2)),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // 操作按钮
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, 'end'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('结束'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, 'new'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('继续训练'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    
    // 根据用户选择执行操作
    if (result == 'new') {
      // 继续训练：自动加载新股票
      await _loadRandomStock();
      if (_selectedStockCode != null) {
        _startTraining();
      }
    } else if (result == 'end') {
      // 结束：停止定时器，清空会话，保持K线显示
      _autoPlayTimer?.cancel();
      _autoPlayTimer = null;
      setState(() {
        _session = null; // 清空训练会话
      });
    }
  }
  
  /// TradingView风格的报告行
  Widget _buildTVReportRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
  
  /// 显示训练设置
  void _showTrainingSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('训练设置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: '初始资金',
                prefixText: '¥',
                suffixText: '元',
              ),
              keyboardType: TextInputType.number,
              controller: TextEditingController(text: _initialCapital.toStringAsFixed(0)),
              onChanged: (value) {
                final capital = double.tryParse(value);
                if (capital != null && capital > 0) {
                  _initialCapital = capital;
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
  
  /// 显示技术指标设置（紧凑版）
  void _showIndicatorSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        title: Row(
          children: [
            const Icon(Icons.insights, color: Colors.blue, size: 20),
            const SizedBox(width: 8),
            const Text('技术指标', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 280,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _indicators.length,
            itemBuilder: (context, index) {
              final indicator = _indicators[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: indicator.enabled 
                      ? Colors.blue.withOpacity(0.08) 
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: indicator.enabled ? Colors.blue.withOpacity(0.3) : Colors.grey.shade300,
                    width: 1,
                  ),
                ),
                child: CheckboxListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  title: Text(
                    indicator.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: indicator.enabled ? FontWeight.w600 : FontWeight.normal,
                      color: indicator.enabled ? Colors.blue.shade700 : Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    indicator.type,
                    style: TextStyle(
                      fontSize: 11,
                      color: indicator.enabled ? Colors.blue.shade600 : Colors.grey.shade600,
                    ),
                  ),
                  value: indicator.enabled,
                  activeColor: Colors.blue,
                  onChanged: (value) {
                    setState(() {
                      _indicators[index] = TechnicalIndicator(
                        name: indicator.name,
                        type: indicator.type,
                        params: indicator.params,
                        enabled: value ?? false,
                      );
                    });
                    Navigator.pop(context);
                    _showIndicatorSettings();
                  },
                  secondary: Icon(
                    Icons.show_chart,
                    color: indicator.enabled ? Colors.blue : Colors.grey.shade400,
                    size: 18,
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('关闭', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
  
  /// 显示消息
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  // 控制面板回调函数
  void _togglePlayPause() {
    if (_replayService.isPlaying) {
      _autoPlayTimer?.cancel();
      _replayService.pause();
    } else {
      _replayService.play();
      // 使用默认1000毫秒（1x速度）启动定时器
      _autoPlayTimer = Timer.periodic(
        const Duration(milliseconds: 1000),
        (_) => _nextCandle(),
      );
    }
    setState(() {}); // 通知UI更新
  }
  
  void _nextCandle() {
    _replayService.nextCandle();
    setState(() {});
  }
  
  void _previousCandle() {
    _replayService.previousCandle();
    setState(() {});
  }
  
  void _changeSpeed(double speedInMilliseconds) {
    // speedInMilliseconds是毫秒值，如3333、2000、1000等
    if (_replayService.isPlaying) {
      _autoPlayTimer?.cancel();
      _autoPlayTimer = Timer.periodic(
        Duration(milliseconds: speedInMilliseconds.toInt()),
        (_) => _nextCandle(),
      );
    }
  }
  
  void _resetReplay() {
    _autoPlayTimer?.cancel();
    _replayService.reset();
    // 重置训练会话但保留股票信息
    if (_selectedStockCode != null && _selectedStockName != null) {
      setState(() {
        _session = ReplayTrainingSession(
          stockCode: _selectedStockCode!,
          stockName: _selectedStockName!,
          initialCapital: _initialCapital,
        );
      });
    }
  }
  
  /// 切换横屏/竖屏
  void _toggleOrientation() {
    setState(() {
      _isLandscape = !_isLandscape;
    });
    
    if (_isLandscape) {
      // 切换到横屏
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      // 切换到竖屏
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
  }
  
  /// 构建横屏布局（类似TradingView）
  Widget _buildLandscapeLayout(ThemeProvider themeProvider) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 全屏K线图
          Column(
            children: [
              // K线图表区域（全屏）
              Expanded(
                child: _buildChartArea(themeProvider),
              ),
              
              // 底部控制栏
              Container(
                color: Colors.black.withOpacity(0.8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    // 交易按钮（紧凑版）
                    if (_session != null && _replayService.isReplayActive && !_replayService.isReplayFinished) ...[
                      _buildCompactTradeButton('买入', Colors.red, true, _canBuy()),
                      const SizedBox(width: 8),
                      _buildCompactTradeButton('卖出', Colors.green, false, _canSell()),
                      const SizedBox(width: 16),
                    ],
                    
                    // 回放控制（紧凑版）
                    Expanded(
                      child: ReplayControlPanel(
                        replayService: _replayService,
                        onPlayPause: _togglePlayPause,
                        onNext: _nextCandle,
                        onPrevious: _previousCandle,
                        onSpeedChange: (int speed) => _changeSpeed(speed.toDouble()),
                        onReset: _resetReplay,
                        onSeek: (int index) {
                          setState(() {}); // 通知UI更新
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // 左上角：股票信息和当前价格
          if (_replayService.currentCandle != null)
            Positioned(
              top: 8,
              left: 8,
              child: _buildCurrentPriceInfo(_replayService.currentCandle!),
            ),
          
          // 右上角：持仓信息
          if (_session != null && _session!.currentPosition > 0)
            Positioned(
              top: 8,
              right: 8,
              child: _buildPositionInfo(),
            ),
          
          // 右上角工具栏
          Positioned(
            top: 8,
            right: _session != null && _session!.currentPosition > 0 ? 120 : 8,
            child: Row(
              children: [
                // 随机选股
                _buildFloatingButton(
                  icon: Icons.shuffle,
                  tooltip: '随机选股',
                  onPressed: () async {
                    // 如果正在训练，直接结束并显示报告
                    if (_session != null) {
                      await _endTraining();
                    }
                    
                    // 加载新股票并开始训练
                    await _loadRandomStock();
                    if (_selectedStockCode != null) {
                      _startTraining();
                    }
                  },
                ),
                const SizedBox(width: 8),
                // 竖屏切换
                _buildFloatingButton(
                  icon: Icons.screen_lock_portrait,
                  tooltip: '竖屏',
                  onPressed: _toggleOrientation,
                ),
                const SizedBox(width: 8),
                // 技术指标
                _buildFloatingButton(
                  icon: Icons.insights,
                  tooltip: '技术指标',
                  onPressed: _showIndicatorSettings,
                  color: Colors.blue,
                ),
                const SizedBox(width: 8),
                // 训练设置
                _buildFloatingButton(
                  icon: Icons.settings,
                  tooltip: '训练设置',
                  onPressed: _showTrainingSettings,
                ),
                if (_session != null) ...[
                  const SizedBox(width: 8),
                  // 结束训练
                  _buildFloatingButton(
                    icon: Icons.stop_circle,
                    tooltip: '结束训练',
                    onPressed: _endTraining,
                    color: Colors.red,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  /// 构建浮动按钮
  Widget _buildFloatingButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color ?? Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: IconButton(
        icon: Icon(icon, color: color ?? Colors.white, size: 20),
        onPressed: onPressed,
        tooltip: tooltip,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(
          minWidth: 36,
          minHeight: 36,
        ),
      ),
    );
  }
  
  /// 构建紧凑交易按钮
  Widget _buildCompactTradeButton(String label, Color color, bool isBuy, bool enabled) {
    return ElevatedButton(
      onPressed: enabled ? () => _executeTrade(isBuy ? 'buy' : 'sell') : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey[700],
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        minimumSize: const Size(60, 32),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
  
  /// 检查是否可以买入
  bool _canBuy() {
    if (_session == null) return false;
    final currentCandle = _replayService.currentCandle;
    if (currentCandle == null) return false;
    final currentPrice = currentCandle['close'] as double;
    return _session!.currentCapital >= currentPrice * 100; // 至少能买1手
  }
  
  /// 检查是否可以卖出
  bool _canSell() {
    if (_session == null) return false;
    return _session!.currentPosition > 0;
  }
}

