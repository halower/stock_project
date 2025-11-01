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
  
  // 训练会话
  ReplayTrainingSession? _session;
  double _initialCapital = 100000; // 默认10万初始资金
  
  // 技术指标
  List<TechnicalIndicator> _indicators = TechnicalIndicator.getDefaultIndicators();
  String? _subChartIndicator; // 当前选中的附图指标 (MACD/RSI/KDJ)
  
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
    
    // 自动检测屏幕方向
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;
    
    // 横屏模式使用全屏布局
    if (isLandscape) {
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
          // 随机选股按钮 - 使用更直观的图标
          Container(
            margin: const EdgeInsets.only(right: 8),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade400, Colors.deepOrange.shade500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.autorenew, color: Colors.white, size: 20),
              padding: EdgeInsets.zero,
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
              tooltip: '换一只股票',
          ),
          ),
          // 技术指标设置 - 使用更直观的图标
          Container(
            margin: const EdgeInsets.only(right: 8),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.blue.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.timeline, color: Colors.white, size: 20),
              padding: EdgeInsets.zero,
              onPressed: _showIndicatorSettings,
              tooltip: '技术指标',
            ),
          ),
          // 训练设置 - 使用人民币符号和比特币金色
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color.from(alpha: 1, red: 0.941, green: 0.561, blue: 0.286), Color(0xFFFFB800)], // 比特币金色渐变
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFFFFD700).withValues(alpha: 0.4), // 金色阴影
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.currency_yuan, color: Colors.white, size: 20), // 人民币符号
              padding: EdgeInsets.zero,
            onPressed: _showTrainingSettings,
            tooltip: '训练设置',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 训练信息栏（竖屏时显示）
          if (_session != null) _buildTrainingInfoBar(),
          
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
  
  /// 构建训练信息栏（添加滑动支持）- 紧凑版设计
  Widget _buildTrainingInfoBar() {
    if (_session == null) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade50,
            Colors.blue.shade100.withValues(alpha: 0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: Colors.blue.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // 当前资金
            _buildInfoCard(
              '当前资金',
                    '¥${(_session!.currentCapital / 10000).toStringAsFixed(2)}万',
              Icons.account_balance_wallet,
              _session!.currentCapital >= _session!.initialCapital
                        ? Colors.red
                        : Colors.green,
                  ),
            const SizedBox(width: 8),
                  
                  // 盈亏
            _buildInfoCard(
              '总盈亏',
                    '${_session!.totalProfitLoss >= 0 ? '+' : ''}¥${_session!.totalProfitLoss.toStringAsFixed(0)}',
                    Icons.trending_up,
              _session!.totalProfitLoss >= 0 ? Colors.red : Colors.green,
                  ),
            const SizedBox(width: 8),
                  
                  // 盈亏率
            _buildInfoCard(
                    '收益率',
                    '${_session!.profitLossRate >= 0 ? '+' : ''}${_session!.profitLossRate.toStringAsFixed(2)}%',
              Icons.show_chart,
              _session!.profitLossRate >= 0 ? Colors.red : Colors.green,
                  ),
            const SizedBox(width: 8),
                  
            // 交易次数
            _buildInfoCard(
                    '交易',
                    '${_session!.totalTrades}次',
              Icons.swap_horiz,
              Colors.blue,
                  ),
            const SizedBox(width: 8),
                  
            // 胜率
            _buildInfoCard(
                    '胜率',
                    '${_session!.winRate.toStringAsFixed(1)}%',
                    Icons.emoji_events,
              _session!.winRate >= 50 ? Colors.amber : Colors.grey,
                  ),
                ],
              ),
      ),
    );
  }
  
  /// 构建信息卡片 - 紧凑版
  Widget _buildInfoCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
      children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 1),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
                  height: 1.2,
                  letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ],
      ),
    );
  }
  
  /// 构建图表区域
  Widget _buildChartArea(ThemeProvider themeProvider) {
    if (_isLoading) {
      return Container(
        color: themeProvider.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    
    if (_errorMessage != null) {
      return Container(
        color: themeProvider.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        child: Center(
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
        ),
      );
    }
    
    if (_selectedStockCode == null) {
      return Container(
        color: themeProvider.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        child: Center(
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
        ),
      );
    }
    
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _replayService.visibleDataStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            color: themeProvider.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            child: const Center(child: Text('暂无数据')),
          );
        }
        
        return Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: themeProvider.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
            border: Border.all(
              color: Colors.grey.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
          children: [
            Padding(
                  padding: const EdgeInsets.all(12.0),
            child: StockKLineChart(
                    key: ValueKey('${_indicators.map((i) => '${i.name}_${i.enabled}').join('_')}_$_subChartIndicator'), // 使用key强制重建
              data: snapshot.data!,
              showVolume: true,
              indicators: _indicators.where((i) => i.enabled).toList(),
              trades: _session?.trades, // 传递交易记录
              subChartIndicator: _subChartIndicator, // 传递附图指标
            ),
            ),
            
                // 当前价格信息 - 精致设计
            Positioned(
              top: 16,
              left: 16,
              child: _buildCurrentPriceInfo(snapshot.data!.last),
            ),
            
                // 持仓信息 - 精致设计
            if (_session != null && _session!.currentPosition > 0)
              Positioned(
                top: 16,
                right: 16,
                child: _buildPositionInfo(),
              ),
          ],
            ),
          ),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withValues(alpha: 0.75),
            Colors.black.withValues(alpha: 0.65),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
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
              const Text(
                '涨跌: ',
                style: TextStyle(
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
              const Text(
                '量: ',
                style: TextStyle(
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
  
  /// 构建持仓信息 - 精致设计
  Widget _buildPositionInfo() {
    if (_session == null || _session!.currentPosition == 0) {
      return const SizedBox.shrink();
    }
    
    final currentPrice = _replayService.currentCandle?['close'] ?? 0.0;
    final positionValue = currentPrice * _session!.currentPosition;
    final costValue = (_session!.positionCost ?? 0) * _session!.currentPosition;
    final unrealizedPL = positionValue - costValue;
    final plColor = unrealizedPL >= 0 ? Colors.red : Colors.green;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            plColor.withValues(alpha: 0.9),
            plColor.withValues(alpha: 0.75),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: plColor.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            children: [
              Icon(Icons.inventory_2, color: Colors.white, size: 14),
              SizedBox(width: 4),
              Text(
            '持仓',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
                  fontSize: 12,
                  height: 1.2,
            ),
          ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${_session!.currentPosition}股',
            style: const TextStyle(
              color: Colors.white, 
              fontSize: 11,
              height: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '成本 ¥${_session!.positionCost?.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white70, 
              fontSize: 10,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${unrealizedPL >= 0 ? '+' : ''}¥${unrealizedPL.toStringAsFixed(0)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                height: 1.2,
              fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// 构建交易按钮 - 精致设计
  Widget _buildTradingButtons() {
    if (_session == null) return const SizedBox.shrink();
    
    final currentPrice = _replayService.currentCandle?['close'] ?? 0.0;
    final canBuy = _session!.currentCapital >= currentPrice * 100; // 至少能买1手
    final canSell = _session!.currentPosition > 0;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.grey.shade50,
            Colors.grey.shade100,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
        border: Border(
          top: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        children: [
          // 买入按钮 - 精致设计
          Expanded(
            flex: 2,
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                gradient: canBuy
                    ? LinearGradient(
                        colors: [Colors.red.shade400, Colors.red.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: canBuy ? null : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(12),
                boxShadow: canBuy
                    ? [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
            child: ElevatedButton.icon(
              onPressed: canBuy ? () => _executeTrade('buy') : null,
                icon: const Icon(Icons.arrow_upward, size: 20),
                label: const Text('买入', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          ),
          const SizedBox(width: 12),
          // 卖出按钮 - 精致设计
          Expanded(
            flex: 2,
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                gradient: canSell
                    ? LinearGradient(
                        colors: [Colors.green.shade400, Colors.green.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: canSell ? null : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(12),
                boxShadow: canSell
                    ? [
                        BoxShadow(
                          color: Colors.green.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
            child: ElevatedButton.icon(
              onPressed: canSell ? () => _executeTrade('sell') : null,
                icon: const Icon(Icons.arrow_downward, size: 20),
                label: const Text('卖出', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          ),
          const SizedBox(width: 12),
          // 结束训练按钮 - 精致设计
          Expanded(
            flex: 1,
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade400, Colors.deepOrange.shade500],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _endTraining,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                ),
              ),
                child: const Text('结束', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 10,
        child: SingleChildScrollView(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white,
                Colors.grey.shade50,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 顶部盈亏展示（紧凑设计）
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isProfitable 
                        ? [Colors.red.shade400, Colors.red.shade600]
                        : [Colors.green.shade400, Colors.green.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isProfitable ? Colors.red : Colors.green).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                  children: [
                    Icon(
                      isProfitable ? Icons.trending_up : Icons.trending_down,
                          size: 28,
                          color: Colors.white,
                    ),
                        const SizedBox(width: 12),
                    Text(
                      '${isProfitable ? '+' : ''}¥${_session!.totalProfitLoss.toStringAsFixed(2)}',
                          style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                      '${isProfitable ? '+' : ''}${_session!.profitLossRate.toStringAsFixed(2)}%',
                        style: const TextStyle(
                        fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // 详细数据区域 - 紧凑版
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // 综合信息卡片
              Container(
                      padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.grey.shade50,
                            Colors.grey.shade100.withValues(alpha: 0.5),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.grey.withValues(alpha: 0.2),
                          width: 1,
                        ),
                ),
                child: Column(
                  children: [
                          _buildCompactReportRow('股票', _session!.stockName, Icons.candlestick_chart, Colors.blue),
                          const Divider(height: 20, thickness: 0.5),
                          _buildCompactReportRow('时长', '${_session!.durationMinutes}分钟', Icons.access_time, Colors.orange),
                          const Divider(height: 20, thickness: 0.5),
                          _buildCompactReportRow('最终资金', '¥${(_session!.currentCapital / 10000).toStringAsFixed(2)}万', Icons.account_balance_wallet, Colors.green),
                          const Divider(height: 20, thickness: 0.5),
                          _buildCompactReportRow('交易次数', '${_session!.totalTrades}次', Icons.swap_horiz, Colors.purple),
                          const Divider(height: 20, thickness: 0.5),
                          _buildCompactReportRow('胜率', '${_session!.winRate.toStringAsFixed(1)}%', Icons.emoji_events, Colors.amber),
                          const Divider(height: 20, thickness: 0.5),
                          _buildCompactReportRow('盈亏比', _session!.profitLossRatio.toStringAsFixed(2), Icons.balance, Colors.teal),
                  ],
                ),
              ),
              
                    const SizedBox(height: 20),
              
                    // 操作按钮 - 精致设计
              Row(
                children: [
                  Expanded(
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, 'end'),
                      style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey.shade700,
                                padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                              child: const Text('结束', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.blue.shade400, Colors.blue.shade600],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, 'new'),
                      style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                                shadowColor: Colors.transparent,
                                padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                              child: const Text('继续训练', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                    ),
                  ),
                ],
              ),
            ],
                ),
              ),
            ],
            ),
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
  
  /// 构建紧凑报告行
  Widget _buildCompactReportRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
            ),
          ),
          Text(
            value,
          style: TextStyle(
              fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
            ),
          ),
        ],
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
  
  /// 显示技术指标设置（精致紧凑版）
  void _showIndicatorSettings() {
    // 分离主图指标和附图指标
    final mainIndicators = _indicators.where((i) => ['EMA', 'BOLL'].contains(i.type)).toList();
    final subIndicators = _indicators.where((i) => ['MACD', 'RSI', 'KDJ'].contains(i.type)).toList();
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 顶部标题栏 - 紧凑设计
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.blue.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.timeline, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          '技术指标', 
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 20),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                
                // 内容区域
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 主图指标标题
                      Row(
                        children: [
                          Container(
                            width: 3,
                            height: 14,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.blue.shade400, Colors.blue.shade600],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '主图指标',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      
                      // 主图指标列表 - 紧凑卡片
                      ...mainIndicators.map((indicator) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () {
                                Navigator.pop(context);
                                setState(() {
                                  // 按名称查找并更新指标
                                  final index = _indicators.indexWhere((i) => i.name == indicator.name);
                                  if (index != -1) {
                                    _indicators[index] = TechnicalIndicator(
                                      name: indicator.name,
                                      type: indicator.type,
                                      params: indicator.params,
                                      enabled: !indicator.enabled,
                                    );
                                  }
                                });
                                Future.delayed(const Duration(milliseconds: 100), () {
                                  _showIndicatorSettings();
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: indicator.enabled 
                                      ? Colors.blue.withValues(alpha: 0.06) 
                                      : Colors.grey.withValues(alpha: 0.02),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: indicator.enabled 
                                        ? Colors.blue.withValues(alpha: 0.25) 
                                        : Colors.grey.withValues(alpha: 0.15),
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // 指标图标
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        gradient: indicator.enabled
                                            ? LinearGradient(
                                                colors: [Colors.blue.shade300, Colors.blue.shade500],
                                              )
                                            : null,
                                        color: indicator.enabled ? null : Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(
                                        Icons.show_chart,
                                        color: indicator.enabled ? Colors.white : Colors.grey.shade500,
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        indicator.name,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: indicator.enabled ? FontWeight.w600 : FontWeight.w500,
                                          color: indicator.enabled ? Colors.blue.shade700 : Colors.grey.shade700,
                                          height: 1.2,
                                        ),
                                      ),
                                    ),
                                    // 勾选框
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        gradient: indicator.enabled
                                            ? LinearGradient(
                                                colors: [Colors.blue.shade400, Colors.blue.shade600],
                                              )
                                            : null,
                                        color: indicator.enabled ? null : Colors.transparent,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: indicator.enabled ? Colors.blue.shade600 : Colors.grey.shade300,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: indicator.enabled
                                          ? const Icon(Icons.check, color: Colors.white, size: 14)
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                      
                      const SizedBox(height: 16),
                      
                      // 附图指标标题
                      Row(
                        children: [
                          Container(
                            width: 3,
                            height: 14,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.purple.shade400, Colors.purple.shade600],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '附图指标',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.purple.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '单选',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.purple.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      
                      // 附图指标列表 - 紧凑卡片
                      ...subIndicators.map((indicator) {
                        final isSelected = _subChartIndicator == indicator.type && indicator.enabled;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () {
                                Navigator.pop(context);
                                setState(() {
                                  // 如果当前已选中，则取消选中
                                  if (isSelected) {
                                    _subChartIndicator = null;
                                    // 按名称查找并更新指标
                                    final index = _indicators.indexWhere((i) => i.name == indicator.name);
                                    if (index != -1) {
                                      _indicators[index] = TechnicalIndicator(
                                        name: indicator.name,
                                        type: indicator.type,
                                        params: indicator.params,
                                        enabled: false,
                                      );
                                    }
                                  } else {
                                    // 取消其他附图指标的选中状态
                                    for (int i = 0; i < _indicators.length; i++) {
                                      if (['MACD', 'RSI', 'KDJ'].contains(_indicators[i].type)) {
                                        _indicators[i] = TechnicalIndicator(
                                          name: _indicators[i].name,
                                          type: _indicators[i].type,
                                          params: _indicators[i].params,
                                          enabled: false,
                                        );
                                      }
                                    }
                                    // 选中当前指标 - 按名称查找
                                    _subChartIndicator = indicator.type;
                                    final index = _indicators.indexWhere((i) => i.name == indicator.name);
                                    if (index != -1) {
                                      _indicators[index] = TechnicalIndicator(
                                        name: indicator.name,
                                        type: indicator.type,
                                        params: indicator.params,
                                        enabled: true,
                                      );
                                    }
                                  }
                                });
                                Future.delayed(const Duration(milliseconds: 100), () {
                                  _showIndicatorSettings();
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected 
                                      ? Colors.purple.withValues(alpha: 0.06) 
                                      : Colors.grey.withValues(alpha: 0.02),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected 
                                        ? Colors.purple.withValues(alpha: 0.25) 
                                        : Colors.grey.withValues(alpha: 0.15),
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // 指标图标
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        gradient: isSelected
                                            ? LinearGradient(
                                                colors: [Colors.purple.shade300, Colors.purple.shade500],
                                              )
                                            : null,
                                        color: isSelected ? null : Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(
                                        Icons.bar_chart,
                                        color: isSelected ? Colors.white : Colors.grey.shade500,
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        indicator.name,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                          color: isSelected ? Colors.purple.shade700 : Colors.grey.shade700,
                                          height: 1.2,
                                        ),
                                      ),
                                    ),
                                    // 单选框
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        gradient: isSelected
                                            ? LinearGradient(
                                                colors: [Colors.purple.shade400, Colors.purple.shade600],
                                              )
                                            : null,
                                        color: isSelected ? null : Colors.transparent,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected ? Colors.purple.shade600 : Colors.grey.shade300,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: isSelected
                                          ? const Icon(Icons.circle, color: Colors.white, size: 10)
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
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
  
  /// 构建横屏布局（类似TradingView）
  Widget _buildLandscapeLayout(ThemeProvider themeProvider) {
    return Scaffold(
      backgroundColor: themeProvider.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      body: SafeArea(
        child: Stack(
        children: [
          // 全屏K线图
          Column(
            children: [
              // K线图表区域（全屏）
              Expanded(
                child: _buildChartArea(themeProvider),
              ),
              
                // 底部超紧凑控制栏
              Container(
                  color: Colors.black.withValues(alpha: 0.9),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  height: 50, // 固定高度，避免溢出
                child: Row(
                  children: [
                      // 交易按钮（超紧凑版）
                    if (_session != null && _replayService.isReplayActive && !_replayService.isReplayFinished) ...[
                        _buildMiniTradeButton('买', Colors.red, true, _canBuy()),
                        const SizedBox(width: 4),
                        _buildMiniTradeButton('卖', Colors.green, false, _canSell()),
                      const SizedBox(width: 8),
                    ],
                    
                      // 回放控制（超紧凑版）
                    Expanded(
                        child: _buildCompactReplayControls(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
            // 左上角：股票信息和当前价格（缩小版）
          if (_replayService.currentCandle != null)
            Positioned(
              top: 8,
              left: 8,
                child: _buildCompactPriceInfo(_replayService.currentCandle!),
              ),
            
            // 左下角：训练信息（浮动显示）
            if (_session != null)
              Positioned(
                bottom: 55,
                left: 8,
                child: _buildFloatingTrainingInfo(),
            ),
          
          // 右上角：持仓信息
          if (_session != null && _session!.currentPosition > 0)
            Positioned(
              top: 8,
              right: 8,
                child: _buildCompactPositionInfo(),
            ),
          
            // 右上角：只保留结束按钮（横屏简化操作）
            if (_session != null)
          Positioned(
            top: 8,
                right: _session!.currentPosition > 0 ? 100 : 8,
                child: _buildMiniFloatingButton(
                  icon: Icons.close,
                    onPressed: _endTraining,
                    color: Colors.red,
            ),
          ),
        ],
        ),
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
  
  /// 构建超小浮动按钮（横屏专用）
  Widget _buildMiniFloatingButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: color != null 
              ? [color.withValues(alpha: 0.8), color]
              : [Colors.grey.shade700, Colors.grey.shade900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: (color ?? Colors.grey).withValues(alpha: 0.4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 18),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    );
  }
  
  /// 构建超小交易按钮（横屏专用）
  Widget _buildMiniTradeButton(String label, Color color, bool isBuy, bool enabled) {
    return SizedBox(
      width: 40,
      height: 36,
      child: ElevatedButton(
      onPressed: enabled ? () => _executeTrade(isBuy ? 'buy' : 'sell') : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey[700],
          padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
        ),
      ),
      child: Text(
        label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
        ),
      ),
    );
  }
  
  /// 构建紧凑价格信息（横屏专用）
  Widget _buildCompactPriceInfo(Map<String, dynamic> currentCandle) {
    final close = currentCandle['close'] ?? 0.0;
    final open = currentCandle['open'] ?? 0.0;
    final change = close - open;
    final changePercent = open > 0 ? (change / open) * 100 : 0.0;
    final isRise = change >= 0;
    final changeColor = isRise ? Colors.red : Colors.green;
    
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(4),
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
              fontSize: 10,
              height: 1.2,
            ),
          ),
          Text(
            '${close.toStringAsFixed(2)}',
            style: TextStyle(
              color: changeColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          Text(
            '${isRise ? '+' : ''}${changePercent.toStringAsFixed(2)}%',
            style: TextStyle(
              color: changeColor,
              fontSize: 9,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
  
  /// 构建紧凑持仓信息（横屏专用）
  Widget _buildCompactPositionInfo() {
    if (_session == null || _session!.currentPosition == 0) {
      return const SizedBox.shrink();
    }
    
    final currentPrice = _replayService.currentCandle?['close'] ?? 0.0;
    final positionValue = currentPrice * _session!.currentPosition;
    final costValue = (_session!.positionCost ?? 0) * _session!.currentPosition;
    final unrealizedPL = positionValue - costValue;
    
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '持仓 ${_session!.currentPosition}股',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              height: 1.2,
            ),
          ),
          Text(
            '${unrealizedPL >= 0 ? '+' : ''}${unrealizedPL.toStringAsFixed(0)}',
            style: TextStyle(
              color: unrealizedPL >= 0 ? Colors.yellow : Colors.orange,
              fontSize: 10,
              height: 1.2,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  /// 构建浮动训练信息（横屏专用）
  Widget _buildFloatingTrainingInfo() {
    if (_session == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Colors.blue.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMiniInfoItem(
            '资金',
            '${(_session!.currentCapital / 10000).toStringAsFixed(1)}万',
            _session!.currentCapital >= _session!.initialCapital ? Colors.red : Colors.green,
          ),
          const SizedBox(width: 8),
          _buildMiniInfoItem(
            '盈亏',
            '${_session!.profitLossRate >= 0 ? '+' : ''}${_session!.profitLossRate.toStringAsFixed(1)}%',
            _session!.profitLossRate >= 0 ? Colors.red : Colors.green,
          ),
          const SizedBox(width: 8),
          _buildMiniInfoItem(
            '胜率',
            '${_session!.winRate.toStringAsFixed(0)}%',
            _session!.winRate >= 50 ? Colors.orange : Colors.grey,
          ),
        ],
      ),
    );
  }
  
  /// 构建超小信息项
  Widget _buildMiniInfoItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 8,
            color: Colors.grey,
            height: 1.2,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color,
            height: 1.2,
          ),
        ),
      ],
    );
  }
  
  /// 构建紧凑回放控制（横屏专用）
  Widget _buildCompactReplayControls() {
    return StreamBuilder<int>(
      stream: _replayService.currentIndexStream,
      builder: (context, snapshot) {
        final current = snapshot.data ?? 30;
        final total = _replayService.totalCandles;
        
        return Row(
          children: [
            // 重置
            IconButton(
              icon: const Icon(Icons.replay, size: 16),
              onPressed: _resetReplay,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              color: Colors.white70,
            ),
            // 上一根
            IconButton(
              icon: const Icon(Icons.skip_previous, size: 18),
              onPressed: _previousCandle,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              color: Colors.white,
            ),
            // 播放/暂停
            IconButton(
              icon: Icon(
                _replayService.isPlaying ? Icons.pause : Icons.play_arrow,
                size: 24,
              ),
              onPressed: _togglePlayPause,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              color: Colors.blue,
            ),
            // 下一根
            IconButton(
              icon: const Icon(Icons.skip_next, size: 18),
              onPressed: _nextCandle,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              color: Colors.white,
            ),
            // 进度条
            Expanded(
              child: total > 30 ? Slider(
                value: current.toDouble().clamp(30.0, total.toDouble() - 1),
                min: 30.0,
                max: total > 30 ? total.toDouble() - 1 : 31.0,
                onChanged: (value) {
                  _replayService.seekTo(value.toInt());
                  setState(() {});
                },
                activeColor: Colors.blue,
              ) : const SizedBox.shrink(),
            ),
            // 当前进度
            Text(
              '$current/$total',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                height: 1.2,
              ),
            ),
            const SizedBox(width: 8),
            // 速度选择
            PopupMenuButton<int>(
              initialValue: 1000,
              onSelected: (speed) => _changeSpeed(speed.toDouble()),
              icon: const Icon(Icons.speed, size: 16, color: Colors.white70),
              padding: EdgeInsets.zero,
              itemBuilder: (context) => [
                const PopupMenuItem(value: 3333, child: Text('0.3x')),
                const PopupMenuItem(value: 2000, child: Text('0.5x')),
                const PopupMenuItem(value: 1000, child: Text('1x')),
                const PopupMenuItem(value: 500, child: Text('2x')),
                const PopupMenuItem(value: 250, child: Text('4x')),
              ],
            ),
          ],
        );
      },
    );
  }
}




