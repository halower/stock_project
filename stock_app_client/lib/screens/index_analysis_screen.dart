import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';
import '../config/api_config.dart';
import '../services/http_client.dart' as http_client;

/// 指数分析页面 - 展示大盘指数的K线图表和分析数据
class IndexAnalysisScreen extends StatefulWidget {
  const IndexAnalysisScreen({Key? key}) : super(key: key);

  @override
  State<IndexAnalysisScreen> createState() => _IndexAnalysisScreenState();
}

class _IndexAnalysisScreenState extends State<IndexAnalysisScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isError = false;
  String _errorMessage = '';
  
  // 当前选中的指数
  String _selectedIndexCode = '000001.SH';
  String _selectedIndexName = '上证指数';
  
  // 指数列表
  List<Map<String, dynamic>> _indexList = [];
  
  // 统计数据
  Map<String, dynamic>? _statistics;
  
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
    _chartUrl = '${ApiConfig.baseUrl}/api/index/chart?index_code=$_selectedIndexCode&days=180';
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
          setState(() {
            _indexList = List<Map<String, dynamic>>.from(data['data']);
          });
        }
      }
    } catch (e) {
      debugPrint('加载指数列表失败: $e');
    }
  }

  /// 加载统计数据
  Future<void> _loadStatistics() async {
    try {
      final url = '${ApiConfig.baseUrl}/api/index/analysis?index_code=$_selectedIndexCode&days=180';
      final response = await http_client.HttpClient.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['statistics'] != null) {
          setState(() {
            _statistics = data['statistics'];
          });
        }
      }
    } catch (e) {
      debugPrint('加载统计数据失败: $e');
    }
  }

  /// 初始化WebView
  void _initWebView() {
    try {
      _controller = WebViewController();
      
      _controller
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
      
      _loadChart();
    } catch (e) {
      debugPrint('初始化WebView失败: $e');
      setState(() {
        _isError = true;
        _errorMessage = '初始化失败: $e';
      });
    }
  }

  /// 加载图表
  void _loadChart() {
    try {
      _controller.loadRequest(Uri.parse(_chartUrl));
    } catch (e) {
      debugPrint('加载图表失败: $e');
      setState(() {
        _isError = true;
        _errorMessage = '加载图表失败: $e';
      });
    }
  }

  /// 切换指数
  void _switchIndex(String indexCode, String indexName) {
    setState(() {
      _selectedIndexCode = indexCode;
      _selectedIndexName = indexName;
      _isLoading = true;
      _statistics = null;
    });
    
    _initChartUrl();
    _loadChart();
    _loadStatistics();
  }

  /// 构建指数选择器
  Widget _buildIndexSelector() {
    if (_indexList.isEmpty) {
      return const SizedBox.shrink();
    }

    // 只显示前三个指数
    final displayIndices = _indexList.take(3).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: displayIndices.map((index) {
            final code = index['code'] as String;
            final name = index['name'] as String;
            final isSelected = code == _selectedIndexCode;
            
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(name),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    _switchIndex(code, name);
                  }
                },
                selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
                labelStyle: TextStyle(
                  color: isSelected 
                    ? Theme.of(context).primaryColor 
                    : Theme.of(context).textTheme.bodyMedium?.color,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// 构建统计信息卡片
  Widget _buildStatisticsCard() {
    if (_statistics == null) {
      return const SizedBox.shrink();
    }

    final latestClose = _statistics!['latest_close'] ?? 0.0;
    final latestChange = _statistics!['latest_change'] ?? 0.0;
    final latestPctChg = _statistics!['latest_pct_chg'] ?? 0.0;
    final periodHigh = _statistics!['period_high'] ?? 0.0;
    final periodLow = _statistics!['period_low'] ?? 0.0;
    final periodReturn = _statistics!['period_return'] ?? 0.0;
    final upDays = _statistics!['up_days'] ?? 0;
    final downDays = _statistics!['down_days'] ?? 0;

    final isUp = latestChange >= 0;
    final changeColor = isUp ? Colors.red : Colors.green;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 最新价格和涨跌
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedIndexName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      latestClose.toStringAsFixed(2),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: changeColor,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isUp ? '+' : ''}${latestChange.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: changeColor,
                      ),
                    ),
                    Text(
                      '${isUp ? '+' : ''}${latestPctChg.toStringAsFixed(2)}%',
                      style: TextStyle(
                        fontSize: 16,
                        color: changeColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            // 统计信息
            _buildStatRow('区间最高', periodHigh.toStringAsFixed(2)),
            _buildStatRow('区间最低', periodLow.toStringAsFixed(2)),
            _buildStatRow('区间涨幅', '${periodReturn >= 0 ? '+' : ''}${periodReturn.toStringAsFixed(2)}%'),
            _buildStatRow('上涨天数', '$upDays天'),
            _buildStatRow('下跌天数', '$downDays天'),
          ],
        ),
      ),
    );
  }

  /// 构建统计行
  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('大盘分析'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadChart();
              _loadStatistics();
            },
            tooltip: '刷新',
          ),
        ],
      ),
      body: Column(
        children: [
          // 指数选择器
          _buildIndexSelector(),
          
          // 统计信息卡片
          _buildStatisticsCard(),
          
          // 图表
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                
                // 加载指示器
                if (_isLoading)
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
                
                // 错误提示
                if (_isError)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _isError = false;
                              _isLoading = true;
                            });
                            _loadChart();
                          },
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

