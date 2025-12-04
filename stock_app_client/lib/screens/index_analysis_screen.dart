import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';
import '../config/api_config.dart';
import '../services/http_client.dart' as http_client;

/// 专业指数分析页面 - TradingView级别的专业图表和分析
/// 仅支持三大核心指数：上证指数、深证成指、创业板指
class IndexAnalysisScreen extends StatefulWidget {
  const IndexAnalysisScreen({Key? key}) : super(key: key);

  @override
  State<IndexAnalysisScreen> createState() => _IndexAnalysisScreenState();
}

class _IndexAnalysisScreenState extends State<IndexAnalysisScreen> {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _isError = false;
  String _errorMessage = '';
  
  // 当前选中的指数
  String _selectedIndexCode = '000001.SH';
  String _selectedIndexName = '上证指数';
  
  // 三大核心指数列表
  List<Map<String, dynamic>> _indexList = [];
  
  // 专业分析数据
  Map<String, dynamic>? _technicalAnalysis;
  Map<String, dynamic>? _marketSentiment;
  Map<String, dynamic>? _keyMetrics;
  Map<String, dynamic>? _keyLevels;
  
  // 图表URL
  late String _chartUrl;

  @override
  void initState() {
    super.initState();
    _loadIndexList();
    _initChartUrl();
    _initWebView();
    _loadStatistics();
  }

  /// 初始化图表URL
  void _initChartUrl() {
    _chartUrl = '${ApiConfig.baseUrl}/api/index/chart?index_code=$_selectedIndexCode&days=180&theme=dark';
    debugPrint('指数图表URL: $_chartUrl');
  }

  /// 加载指数列表
  Future<void> _loadIndexList() async {
    try {
      final url = '${ApiConfig.baseUrl}/api/index/list';
      final response = await http_client.HttpClient.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          if (mounted) {
            setState(() {
              _indexList = List<Map<String, dynamic>>.from(data['data']);
            });
          }
        }
      }
    } catch (e) {
      debugPrint('加载指数列表失败: $e');
    }
  }

  /// 加载专业分析数据
  Future<void> _loadStatistics() async {
    try {
      final url = '${ApiConfig.baseUrl}/api/index/analysis?index_code=$_selectedIndexCode&days=180&theme=dark';
      debugPrint('🔄 开始加载专业分析数据: $url');
      
      final response = await http_client.HttpClient.get(url);
      debugPrint('📡 响应状态码: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('📊 返回数据: ${data.keys}');
        debugPrint('✅ success: ${data['success']}');
        
        if (data['success'] == true) {
          if (mounted) {
            setState(() {
              _technicalAnalysis = data['technical_analysis'];
              _marketSentiment = data['market_sentiment'];
              _keyMetrics = data['key_metrics'];
              _keyLevels = data['key_levels'];
            });
          }
          debugPrint('✅ 专业分析数据加载成功');
          debugPrint('   - 技术分析: ${_technicalAnalysis != null ? "已加载" : "未加载"}');
          debugPrint('   - 市场情绪: ${_marketSentiment != null ? "已加载" : "未加载"}');
          debugPrint('   - 关键指标: ${_keyMetrics != null ? "已加载" : "未加载"}');
        } else {
          debugPrint('❌ API返回success=false: ${data['error']}');
        }
      } else {
        debugPrint('❌ HTTP错误: ${response.statusCode}');
        debugPrint('   响应内容: ${response.body}');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ 加载专业分析数据失败: $e');
      debugPrint('   堆栈: $stackTrace');
    }
  }

  /// 初始化WebView
  void _initWebView() {
    try {
      final controller = WebViewController();
      
      controller
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0x00000000))
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              if (mounted) {
                setState(() {
                  _isLoading = true;
                  _isError = false;
                });
              }
            },
            onPageFinished: (String url) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
              }
            },
            onWebResourceError: (WebResourceError error) {
              if (mounted) {
                setState(() {
                  _isError = true;
                  _isLoading = false;
                  _errorMessage = '加载图表错误: ${error.description}';
                });
              }
            },
          ),
        );
      
      if (mounted) {
        setState(() {
          _controller = controller;
        });
      }
      
      _loadChart();
    } catch (e) {
      debugPrint('初始化WebView失败: $e');
      if (mounted) {
        setState(() {
          _isError = true;
          _errorMessage = '初始化失败: $e';
        });
      }
    }
  }

  /// 加载图表
  void _loadChart() {
    try {
      _controller?.loadRequest(Uri.parse(_chartUrl));
    } catch (e) {
      debugPrint('加载图表失败: $e');
      if (mounted) {
        setState(() {
          _isError = true;
          _errorMessage = '加载图表失败: $e';
        });
      }
    }
  }

  /// 切换指数
  void _switchIndex(String indexCode, String indexName) {
    setState(() {
      _selectedIndexCode = indexCode;
      _selectedIndexName = indexName;
      _isLoading = true;
      _technicalAnalysis = null;
      _marketSentiment = null;
      _keyMetrics = null;
      _keyLevels = null;
    });
    
    _initChartUrl();
    _loadChart();
    _loadStatistics();
  }

  /// 构建三大核心指数选择器（移动端优化）
  Widget _buildIndexSelector() {
    if (_indexList.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              '加载指数列表中...',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _indexList.map((index) {
            final code = index['code'] as String;
            final name = index['name'] as String;
            final isSelected = code == _selectedIndexCode;
            
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _switchIndex(code, name),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                  color: isSelected 
                    ? Theme.of(context).primaryColor 
                        : Colors.grey.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: isSelected ? [
                        BoxShadow(
                          color: Theme.of(context).primaryColor.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ] : null,
                    ),
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected 
                          ? Colors.white 
                          : Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// 构建专业分析面板
  Widget _buildStatisticsCard() {
    if (_keyMetrics == null) {
      return const Card(
        margin: EdgeInsets.all(16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Text('正在加载专业分析数据...'),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          // 核心指标卡片
          _buildKeyMetricsCard(),
          
          // 关键点位卡片（散户最关心）
          if (_keyLevels != null) _buildKeyLevelsCard(),
          
          // 技术分析卡片
          if (_technicalAnalysis != null) _buildTechnicalAnalysisCard(),
          
          // 市场情绪卡片
          if (_marketSentiment != null) _buildMarketSentimentCard(),
        ],
      ),
    );
  }

  /// 构建核心指标卡片
  Widget _buildKeyMetricsCard() {
    if (_keyMetrics == null) return const SizedBox.shrink();

    final currentPrice = _keyMetrics!['current_price'] ?? 0.0;
    final change = _keyMetrics!['change'] ?? 0.0;
    final changePct = _keyMetrics!['change_pct'] ?? 0.0;
    final periodHigh = _keyMetrics!['period_high'] ?? 0.0;
    final periodLow = _keyMetrics!['period_low'] ?? 0.0;
    final periodReturn = _keyMetrics!['period_return'] ?? 0.0;
    final volatility = _keyMetrics!['volatility'] ?? 0.0;
    final maxDrawdown = _keyMetrics!['max_drawdown'] ?? 0.0;

    final isUp = change >= 0;
    final changeColor = isUp ? Colors.red : Colors.green;

    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题和价格
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedIndexName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentPrice.toStringAsFixed(2),
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: changeColor,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: changeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${isUp ? '+' : ''}${change.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: changeColor,
                      ),
                    ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${isUp ? '+' : ''}${changePct.toStringAsFixed(2)}%',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: changeColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24, thickness: 1),
            
            // 专业指标网格
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                _buildMetricItem('区间最高', periodHigh.toStringAsFixed(2), Icons.trending_up),
                _buildMetricItem('区间最低', periodLow.toStringAsFixed(2), Icons.trending_down),
                _buildMetricItem('区间涨幅', '${periodReturn >= 0 ? '+' : ''}${periodReturn.toStringAsFixed(2)}%', Icons.show_chart),
                _buildMetricItem('波动率', '${volatility.toStringAsFixed(2)}%', Icons.waves),
                _buildMetricItem('最大回撤', '${maxDrawdown.toStringAsFixed(2)}%', Icons.arrow_downward),
                _buildMetricItem('交易日', '${_keyMetrics!['total_trading_days'] ?? 0}天', Icons.calendar_today),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建指标项
  Widget _buildMetricItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建关键点位卡片（散户最关心的）
  Widget _buildKeyLevelsCard() {
    final currentPrice = _keyLevels!['current_price'] ?? 0.0;
    final supports = _keyLevels!['supports'] as List? ?? [];
    final resistances = _keyLevels!['resistances'] as List? ?? [];
    final targetPrices = _keyLevels!['target_prices'] ?? {};
    final tradingAdvice = _keyLevels!['trading_advice'] ?? {};

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.track_changes, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                const Text(
                  '关键点位',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '当前: ${currentPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            
            // 目标价位
            if (targetPrices.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.withOpacity(0.1), Colors.purple.withOpacity(0.1)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.flag, size: 16, color: Colors.blue[700]),
                        const SizedBox(width: 6),
                        Text(
                          '目标价位',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTargetPrice(
                            '上涨目标',
                            targetPrices['upside_target'],
                            targetPrices['upside_distance'],
                            targetPrices['probability_up'],
                            Colors.red,
                            Icons.arrow_upward,
                          ),
                        ),
                        Container(width: 1, height: 50, color: Colors.grey[300]),
                        Expanded(
                          child: _buildTargetPrice(
                            '下跌目标',
                            targetPrices['downside_target'],
                            targetPrices['downside_distance'],
                            targetPrices['probability_down'],
                            Colors.green,
                            Icons.arrow_downward,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            // 支撑位和压力位
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 支撑位
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.trending_down, size: 14, color: Colors.green[700]),
                          const SizedBox(width: 4),
                          Text(
                            '支撑位',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...supports.take(3).map((s) => _buildLevelItem(
                        s['level'],
                        s['price'],
                        s['distance_pct'],
                        Colors.green,
                      )).toList(),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // 压力位
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.trending_up, size: 14, color: Colors.red[700]),
                          const SizedBox(width: 4),
                          Text(
                            '压力位',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.red[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...resistances.take(3).map((r) => _buildLevelItem(
                        r['level'],
                        r['price'],
                        r['distance_pct'],
                        Colors.red,
                      )).toList(),
                    ],
                  ),
                ),
              ],
            ),
            
            // 交易建议
            if (tradingAdvice.isNotEmpty) ...[
              const Divider(height: 20),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb, size: 14, color: Colors.amber[800]),
                        const SizedBox(width: 6),
                        Text(
                          '交易建议',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildAdviceItem(
                          '止损',
                          tradingAdvice['stop_loss'],
                          tradingAdvice['stop_loss_pct'],
                          Colors.green,
                        ),
                        _buildAdviceItem(
                          '止盈',
                          tradingAdvice['take_profit'],
                          tradingAdvice['take_profit_pct'],
                          Colors.red,
                        ),
                        _buildAdviceItem(
                          '盈亏比',
                          tradingAdvice['risk_reward_ratio'],
                          null,
                          Colors.blue,
                        ),
                      ],
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

  /// 构建目标价格
  Widget _buildTargetPrice(String label, dynamic price, dynamic distance, dynamic probability, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          price?.toStringAsFixed(2) ?? '-',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          '${distance >= 0 ? '+' : ''}${distance?.toStringAsFixed(2) ?? '0'}%',
          style: TextStyle(
            fontSize: 11,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '概率: ${probability?.toStringAsFixed(0) ?? '0'}%',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  /// 构建点位项
  Widget _buildLevelItem(String label, dynamic price, dynamic distance, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price?.toStringAsFixed(2) ?? '-',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                '${distance >= 0 ? '+' : ''}${distance?.toStringAsFixed(1) ?? '0'}%',
                style: TextStyle(
                  fontSize: 10,
                  color: color.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建交易建议项
  Widget _buildAdviceItem(String label, dynamic value, dynamic? percent, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value is double && label != '盈亏比' 
            ? value.toStringAsFixed(2) 
            : value?.toStringAsFixed(1) ?? '-',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        if (percent != null)
          Text(
            '${percent >= 0 ? '+' : ''}${percent.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 10,
              color: color.withOpacity(0.7),
            ),
          ),
      ],
    );
  }

  /// 构建技术分析卡片
  Widget _buildTechnicalAnalysisCard() {
    final trend = _technicalAnalysis!['trend'] ?? '中性';
    final ma = _technicalAnalysis!['moving_averages'] ?? {};
    final macd = _technicalAnalysis!['macd'] ?? {};
    final rsi = _technicalAnalysis!['rsi'] ?? {};

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Theme.of(context).primaryColor, size: 20),
                const SizedBox(width: 8),
                const Text(
                  '技术分析',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            
            // 趋势判断
            _buildAnalysisRow('趋势', trend, _getTrendColor(trend)),
            
            // MACD信号
            if (macd['interpretation'] != null)
              _buildAnalysisRow('MACD', macd['interpretation'], _getSignalColor(macd['interpretation'])),
            
            // RSI信号
            if (rsi['interpretation'] != null)
              _buildAnalysisRow('RSI', '${rsi['value']?.toStringAsFixed(1) ?? ''} - ${rsi['interpretation']}', _getRSIColor(rsi['value'] ?? 50)),
            
            // 移动平均线
            if (ma.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '移动平均线',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildMAChip('MA5', ma['ma5']),
                  _buildMAChip('MA10', ma['ma10']),
                  _buildMAChip('MA20', ma['ma20']),
                  _buildMAChip('MA60', ma['ma60']),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建市场情绪卡片（真实多维度分析）
  Widget _buildMarketSentimentCard() {
    final sentiment = _marketSentiment!['sentiment'] ?? '中性';
    final sentimentScore = _marketSentiment!['sentiment_score'] ?? 50.0;
    final bullPowerRatio = _marketSentiment!['bull_power_ratio'] ?? 50.0;
    final bearPowerRatio = _marketSentiment!['bear_power_ratio'] ?? 50.0;
    final upDays = _marketSentiment!['up_days_20'] ?? 0;
    final downDays = _marketSentiment!['down_days_20'] ?? 0;
    final volTrend = _marketSentiment!['volume_trend'] ?? '平稳';
    final volRatio = _marketSentiment!['volume_ratio'] ?? 50.0;
    final momentum5d = _marketSentiment!['momentum_5d'] ?? 0.0;
    final momentum20d = _marketSentiment!['momentum_20d'] ?? 0.0;
    final consecutiveUp = _marketSentiment!['consecutive_up'] ?? 0;
    final consecutiveDown = _marketSentiment!['consecutive_down'] ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.psychology, color: Theme.of(context).primaryColor, size: 20),
                const SizedBox(width: 8),
                const Text(
                  '市场情绪分析',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            
            // 综合情绪评分
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _getSentimentColor(sentimentScore).withOpacity(0.1),
                    _getSentimentColor(sentimentScore).withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _getSentimentColor(sentimentScore).withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        sentiment,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: _getSentimentColor(sentimentScore),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getSentimentColor(sentimentScore),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${sentimentScore.toStringAsFixed(0)}分',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: sentimentScore / 100,
                      minHeight: 10,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getSentimentColor(sentimentScore),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '综合评分基于：涨跌比、多空力量、成交量、价格动能',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // 多空力量对比
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.balance, size: 14, color: Colors.grey[700]),
                      const SizedBox(width: 6),
                      Text(
                        '多空力量对比',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: bullPowerRatio.toInt(),
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4),
                              bottomLeft: Radius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: bearPowerRatio.toInt(),
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(4),
                              bottomRight: Radius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '多头 ${bullPowerRatio.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '空头 ${bearPowerRatio.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // 关键数据网格
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 2.2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                _buildSentimentMetric('上涨天数', '$upDays/20天', Colors.red, Icons.trending_up),
                _buildSentimentMetric('下跌天数', '$downDays/20天', Colors.green, Icons.trending_down),
                _buildSentimentMetric('成交量趋势', volTrend, Colors.blue, Icons.show_chart),
                _buildSentimentMetric('量比', '${volRatio.toStringAsFixed(0)}%', Colors.purple, Icons.bar_chart),
                _buildSentimentMetric('5日动能', '${momentum5d >= 0 ? '+' : ''}${momentum5d.toStringAsFixed(2)}%', 
                  momentum5d >= 0 ? Colors.red : Colors.green, Icons.speed),
                _buildSentimentMetric('20日动能', '${momentum20d >= 0 ? '+' : ''}${momentum20d.toStringAsFixed(2)}%', 
                  momentum20d >= 0 ? Colors.red : Colors.green, Icons.timeline),
              ],
            ),
            
            // 连续涨跌提示
            if (consecutiveUp > 0 || consecutiveDown > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: consecutiveUp > 0 ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      consecutiveUp > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 14,
                      color: consecutiveUp > 0 ? Colors.red : Colors.green,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      consecutiveUp > 0 ? '连续上涨 $consecutiveUp 天' : '连续下跌 $consecutiveDown 天',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: consecutiveUp > 0 ? Colors.red : Colors.green,
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

  /// 构建情绪指标
  Widget _buildSentimentMetric(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建分析行
  Widget _buildAnalysisRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
            value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建MA芯片
  Widget _buildMAChip(String label, dynamic value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Text(
        '$label: ${value?.toStringAsFixed(2) ?? '-'}',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.blue,
        ),
      ),
    );
  }


  /// 获取趋势颜色
  Color _getTrendColor(String trend) {
    if (trend.contains('上涨')) return Colors.red;
    if (trend.contains('下跌')) return Colors.green;
    return Colors.grey;
  }

  /// 获取信号颜色
  Color _getSignalColor(String signal) {
    if (signal.contains('多')) return Colors.red;
    if (signal.contains('空')) return Colors.green;
    return Colors.grey;
  }

  /// 获取RSI颜色
  Color _getRSIColor(double rsi) {
    if (rsi > 70) return Colors.red;
    if (rsi < 30) return Colors.green;
    return Colors.orange;
  }

  /// 获取情绪颜色
  Color _getSentimentColor(double score) {
    if (score >= 70) return Colors.red;
    if (score >= 60) return Colors.orange;
    if (score >= 40) return Colors.grey;
    if (score >= 30) return Colors.lightGreen;
    return Colors.green;
  }


  @override
  Widget build(BuildContext context) {
    // 检测横竖屏
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.show_chart, size: 20),
            const SizedBox(width: 8),
            const Text('专业指数分析'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadChart();
              _loadStatistics();
            },
            tooltip: '刷新数据',
          ),
        ],
        elevation: 0,
      ),
      body: Column(
        children: [
          // 三大核心指数选择器
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: _buildIndexSelector(),
          ),
          
          // 主要内容区域 - 根据横竖屏自适应布局
          Expanded(
            child: isLandscape ? _buildLandscapeLayout() : _buildPortraitLayout(),
          ),
        ],
      ),
    );
  }

  /// 竖屏布局（垂直滚动）
  Widget _buildPortraitLayout() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // 专业图表区域
          _buildChartArea(400),
          
          // 专业分析面板
          _buildStatisticsCard(),
        ],
      ),
    );
  }

  /// 横屏布局（左右分屏）
  Widget _buildLandscapeLayout() {
    return Row(
      children: [
        // 左侧：专业图表（占65%）
        Expanded(
          flex: 65,
          child: _buildChartArea(null),
        ),
        
        // 右侧：专业分析面板（占35%，可滚动）
        Expanded(
          flex: 35,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: Colors.grey.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: _buildStatisticsCard(),
          ),
        ),
      ],
    );
  }

  /// 构建图表区域
  Widget _buildChartArea(double? height) {
    return Container(
      height: height,
      color: Colors.black,
      child: Stack(
        children: [
          if (_controller != null)
            WebViewWidget(controller: _controller!),
          
          // 加载指示器
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 16),
                    Text(
                      '加载图表中...',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          
          // 错误提示
          if (_isError)
            Container(
              color: Colors.black.withOpacity(0.8),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _isError = false;
                            _isLoading = true;
                          });
                          _loadChart();
                        },
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('重新加载'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
