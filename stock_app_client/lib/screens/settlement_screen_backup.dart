import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/trade_record.dart';
import '../services/providers/trade_provider.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import '../services/stock_service.dart';
import '../services/database_service.dart';

class SettlementScreen extends StatefulWidget {
  final TradeRecord tradePlan;

  const SettlementScreen({
    Key? key,
    required this.tradePlan,
  }) : super(key: key);

  @override
  State<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends State<SettlementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _commissionController = TextEditingController(text: '0.0');  // 默认为0
  final _taxController = TextEditingController(text: '0.0');  // 默认为0
  final _notesController = TextEditingController();

  List<Map<String, dynamic>> _kLineData = [];
  bool _isLoading = true;
  
  // K线图状态
  double _minY = 0;
  double _maxY = 0;
  int _selectedIndex = -1;
  
  // 控制详情视图
  bool _showDetailView = false;
  Map<String, dynamic>? _selectedPoint;

  late DatabaseService _databaseService;

  @override
  void initState() {
    super.initState();
    
    // 初始化数据库服务
    _databaseService = Provider.of<DatabaseService>(context, listen: false);
    
    // 加载K线数据
    _loadKLineData();
  }

  Future<void> _loadKLineData() async {
    setState(() {
      _isLoading = true;
      _kLineData = []; // 清空现有数据
    });
    
    try {
      final stockCode = widget.tradePlan.stockCode;
      print('加载股票 $stockCode 的K线数据...');
      
      // 获取当前日期和30天前的日期
      final currentDate = DateTime.now();
      final endDate = currentDate.toIso8601String().split('T')[0].replaceAll('-', '');
      final startDate = DateTime(currentDate.year, currentDate.month, currentDate.day - 90)
          .toIso8601String().split('T')[0].replaceAll('-', '');
      
      // 获取历史数据
      final stockService = StockService(await _databaseService.database);
      final historyData = await stockService.getStockHistoryData(
        stockCode,
        startDate: startDate,
        endDate: endDate,
      );
      
      if (historyData.isNotEmpty) {
        // 过滤有效数据
        final validData = historyData.where((data) {
          final high = data['high'] as double?;
          final low = data['low'] as double?;
          final close = data['close'] as double?;
          return high != null && high > 0 && 
                 low != null && low > 0 && 
                 close != null && close > 0;
        }).toList();
        
        print('有效K线数据: ${validData.length}条');
        
        if (mounted) {
          setState(() {
            // 确保复制数据，避免引用问题
            _kLineData = List<Map<String, dynamic>>.from(validData);
            
            if (validData.isNotEmpty) {
              try {
                // 找出价格范围，留出上下10%的空间
                final prices = validData.expand((data) => [
                  data['high'] as double, 
                  data['low'] as double,
                ]).toList();
                
                if (prices.isNotEmpty) {
                  _minY = (prices.reduce((a, b) => a < b ? a : b) * 0.9);
                  _maxY = (prices.reduce((a, b) => a > b ? a : b) * 1.1);
                  
                  print('价格范围: $_minY - $_maxY');
                } else {
                  // 设置默认价格范围
                  final defaultPrice = widget.tradePlan.planPrice ?? 10.0;
                  _minY = defaultPrice * 0.9;
                  _maxY = defaultPrice * 1.1;
                  print('使用默认价格范围: $_minY - $_maxY');
                }
                
                // 预设好交易表单数据
                final lastPrice = validData.last['close'] as double? ?? 0.0;
                if (lastPrice > 0) {
                  _priceController.text = lastPrice.toStringAsFixed(2);
                  print('设置表单默认价格: $lastPrice');
                } else {
                  // 使用计划价格作为默认值
                  _priceController.text = (widget.tradePlan.planPrice ?? 0.0).toStringAsFixed(2);
                }
                
                _quantityController.text = (widget.tradePlan.planQuantity ?? 0).toString();
              } catch (e) {
                print('处理价格范围时出错: $e');
                // 设置默认价格范围
                final defaultPrice = widget.tradePlan.planPrice ?? 10.0;
                _minY = defaultPrice * 0.9;
                _maxY = defaultPrice * 1.1;
              }
            } else {
              print('过滤后无有效K线数据');
              // 设置默认价格范围
              final defaultPrice = widget.tradePlan.planPrice ?? 10.0;
              _minY = defaultPrice * 0.9;
              _maxY = defaultPrice * 1.1;
            }
          });
        }
      } else {
        print('未能加载到K线数据');
        if (mounted) {
          setState(() {
            // 设置默认价格范围
            final defaultPrice = widget.tradePlan.planPrice ?? 10.0;
            _minY = defaultPrice * 0.9;
            _maxY = defaultPrice * 1.1;
            
            // 设置默认交易表单数据
            _priceController.text = (widget.tradePlan.planPrice ?? 0.0).toStringAsFixed(2);
            _quantityController.text = (widget.tradePlan.planQuantity ?? 0).toString();
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('无法获取K线数据，请检查网络连接'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print('加载K线数据失败: $e');
      if (e is Error) {
        print('错误堆栈: ${e.stackTrace}');
      }
      
      if (mounted) {
        setState(() {
          // 设置默认价格范围
          final defaultPrice = widget.tradePlan.planPrice ?? 10.0;
          _minY = defaultPrice * 0.9;
          _maxY = defaultPrice * 1.1;
          
          // 设置默认交易表单数据
          _priceController.text = (widget.tradePlan.planPrice ?? 0.0).toStringAsFixed(2);
          _quantityController.text = (widget.tradePlan.planQuantity ?? 0).toString();
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载K线数据失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : null,
      appBar: AppBar(
        title: const Text('交易结算'),
        elevation: isDarkMode ? 0 : 1,
        backgroundColor: isDarkMode ? const Color(0xFF1A1A1A) : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTradePlanInfo(),
            const SizedBox(height: 24),
            _buildKLineChart(),
            const SizedBox(height: 24),
            _buildSettlementForm(),
            // 添加底部间距，确保滚动到底部时有足够空间
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTradePlanInfo() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode 
            ? [
                const Color(0xFF1E3A8A).withOpacity(0.3),
                const Color(0xFF1E40AF).withOpacity(0.2),
                const Color(0xFF1D4ED8).withOpacity(0.1),
              ]
            : [
                const Color(0xFFF0F9FF),
                const Color(0xFFE0F2FE),
                const Color(0xFFBAE6FD).withOpacity(0.3),
              ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isDarkMode 
              ? Colors.blue.withOpacity(0.1)
              : Colors.blue.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: isDarkMode 
              ? Colors.black.withOpacity(0.2)
              : Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
        ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 股票标题和状态
            _buildStockHeader(),
            const SizedBox(height: 20),
            
            // 关键数据展示
            _buildKeyMetricsRow(),
            const SizedBox(height: 20),
            
            // 详细信息卡片组
            _buildInfoCardGroup(),
          ],
        ),
      ),
    );
  }

  Widget _buildStockHeader() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final tradeType = widget.tradePlan.tradeType;
    
    // A股风格颜色：红涨绿跌
    final redColor = const Color(0xFFFF4444); // A股红色
    final greenColor = const Color(0xFF00AA00); // A股绿色
    
    return Row(
      children: [
        // 股票图标和名称
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 股票名称和代码
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDarkMode 
                      ? [
                          const Color(0xFF1E40AF).withOpacity(0.3),
                          const Color(0xFF3B82F6).withOpacity(0.2),
                        ]
                      : [
                          const Color(0xFFDBeafe),
                          const Color(0xFFBFDBFE),
                        ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDarkMode 
                      ? const Color(0xFF3B82F6).withOpacity(0.5)
                      : const Color(0xFF60A5FA).withOpacity(0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isDarkMode ? Colors.blue : Colors.blue.shade300).withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // 股票图标
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDarkMode 
                          ? const Color(0xFF3B82F6).withOpacity(0.2)
                          : const Color(0xFF60A5FA).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.candlestick_chart,
                        color: isDarkMode ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 股票名称和代码
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.tradePlan.stockName}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : const Color(0xFF1E40AF),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.tradePlan.stockCode,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isDarkMode ? Colors.grey[400] : const Color(0xFF64748B),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              
              // 交易类型标签 - 专业金融风格
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: tradeType == TradeType.buy 
                      ? [
                          redColor.withOpacity(0.15),
                          redColor.withOpacity(0.08),
                        ]
                      : [
                          greenColor.withOpacity(0.15),
                          greenColor.withOpacity(0.08),
                        ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: tradeType == TradeType.buy ? redColor : greenColor,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (tradeType == TradeType.buy ? redColor : greenColor).withOpacity(0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 图标背景
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: (tradeType == TradeType.buy ? redColor : greenColor).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        tradeType == TradeType.buy ? Icons.arrow_upward : Icons.arrow_downward,
                        color: tradeType == TradeType.buy ? redColor : greenColor,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tradeType == TradeType.buy ? '买入' : '卖出',
                      style: TextStyle(
                        color: tradeType == TradeType.buy ? redColor : greenColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }


  Widget _buildTradeStatusBadge() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // 确定状态信息
    String statusText;
    IconData statusIcon;
    Color statusColor;
    
    if (widget.tradePlan.netProfit != null) {
      final isProfit = widget.tradePlan.netProfit! >= 0;
      statusText = isProfit ? '盈利交易' : '亏损交易';
      statusIcon = isProfit ? Icons.trending_up : Icons.trending_down;
      statusColor = isProfit 
        ? (isDarkMode ? Colors.green[400]! : Colors.green[600]!)
        : (isDarkMode ? Colors.red[400]! : Colors.red[600]!);
    } else {
      statusText = widget.tradePlan.tradeType == TradeType.buy ? '买入计划' : '卖出计划';
      statusIcon = widget.tradePlan.tradeType == TradeType.buy 
        ? Icons.arrow_downward 
        : Icons.arrow_upward;
      statusColor = widget.tradePlan.tradeType == TradeType.buy
        ? (isDarkMode ? Colors.red[400]! : Colors.red[600]!) // A股红色：买入
        : (isDarkMode ? Colors.green[400]! : Colors.green[600]!); // A股绿色：卖出
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusColor.withOpacity(0.15),
            statusColor.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            statusIcon,
            size: 18,
            color: statusColor,
          ),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyMetricsRow() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Row(
      children: [
        // 计划价格
        Expanded(
          child: _buildMetricCard(
            '进场价格',
            '¥${(widget.tradePlan.planPrice ?? 0).toStringAsFixed(2)}',
            Icons.price_check_outlined,
            isDarkMode ? Colors.blue[300]! : Colors.blue[600]!,
          ),
        ),
        const SizedBox(width: 12),
        
        // 计划数量
        Expanded(
          child: _buildMetricCard(
            '计划数量',
            '${widget.tradePlan.planQuantity ?? 0}股',
            Icons.format_list_numbered_outlined,
            isDarkMode ? Colors.purple[300]! : Colors.purple[600]!,
          ),
        ),
        const SizedBox(width: 12),
        
        // 盈亏比或净盈亏
        Expanded(
          child: widget.tradePlan.netProfit != null
            ? _buildMetricCard(
                '净盈亏',
                widget.tradePlan.netProfit! >= 0
                  ? '+¥${widget.tradePlan.netProfit!.toStringAsFixed(2)}'
                  : '-¥${widget.tradePlan.netProfit!.abs().toStringAsFixed(2)}',
                widget.tradePlan.netProfit! >= 0 
                  ? Icons.trending_up 
                  : Icons.trending_down,
                widget.tradePlan.netProfit! >= 0
                  ? (isDarkMode ? Colors.green[300]! : Colors.green[600]!)
                  : (isDarkMode ? Colors.red[300]! : Colors.red[600]!),
              )
            : _buildMetricCard(
                '盈亏比',
                _calculateProfitRiskRatio().toStringAsFixed(2),
                Icons.analytics_outlined,
                isDarkMode ? Colors.orange[300]! : Colors.orange[600]!,
              ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode 
            ? [
                color.withOpacity(0.15),
                color.withOpacity(0.05),
              ]
            : [
                color.withOpacity(0.08),
                color.withOpacity(0.03),
              ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(isDarkMode ? 0.3 : 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 图标
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(isDarkMode ? 0.2 : 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(height: 8),
          // 标签
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          // 数值
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  double _calculateProfitRiskRatio() {
    final planPrice = widget.tradePlan.planPrice ?? 0.0;
    final stopLossPrice = widget.tradePlan.stopLossPrice ?? 0.0;
    final takeProfitPrice = widget.tradePlan.takeProfitPrice ?? 0.0;
    
    if (planPrice > 0 && stopLossPrice > 0) {
      final riskPerUnit = (planPrice - stopLossPrice).abs();
      final rewardPerUnit = (takeProfitPrice - planPrice).abs();
      
      if (riskPerUnit > 0) {
        return rewardPerUnit / riskPerUnit;
      }
    }
    return 0.0;
  }

  Widget _buildInfoCardGroup() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildCompactInfoCard()),
            const SizedBox(width: 12),
            Expanded(child: _buildRiskInfoCard()),
          ],
        ),
        const SizedBox(height: 12),
            _buildStrategyInfoCard(),
      ],
    );
  }

  Widget _buildCompactInfoCard() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode 
          ? Colors.white.withOpacity(0.05)
          : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode 
            ? Colors.white.withOpacity(0.1)
            : Colors.white.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 18,
                color: isDarkMode ? Colors.blue[300] : Colors.blue[600],
              ),
              const SizedBox(width: 6),
              Text(
                '价格信息',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.blue[300] : Colors.blue[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          if (widget.tradePlan.stopLossPrice != null)
            _buildPriceItem('止损价', widget.tradePlan.stopLossPrice!, 
              isDarkMode ? Colors.green[300]! : Colors.green[600]!), // A股绿色：亏损
          
          if (widget.tradePlan.takeProfitPrice != null)
            _buildPriceItem('止盈价', widget.tradePlan.takeProfitPrice!, 
              isDarkMode ? Colors.red[300]! : Colors.red[600]!), // A股红色：盈利
          
          if (widget.tradePlan.actualPrice != null)
            _buildPriceItem('实际价', widget.tradePlan.actualPrice!, 
              isDarkMode ? Colors.orange[300]! : Colors.orange[600]!),
        ],
      ),
    );
  }

  Widget _buildRiskInfoCard() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode 
          ? Colors.white.withOpacity(0.05)
          : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode 
            ? Colors.white.withOpacity(0.1)
            : Colors.white.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.shield_outlined,
                size: 18,
                color: isDarkMode ? Colors.orange[300] : Colors.orange[600],
              ),
              const SizedBox(width: 6),
              Text(
                '风险控制',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.orange[300] : Colors.orange[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          if (widget.tradePlan.positionPercentage != null)
            _buildInfoItem('仓位比例', '${widget.tradePlan.positionPercentage!.toStringAsFixed(1)}%'),
          
          if (widget.tradePlan.riskPercentage != null)
            _buildInfoItem('风险比例', '${widget.tradePlan.riskPercentage!.toStringAsFixed(1)}%'),
          
          _buildInfoItem('盈亏比', _calculateProfitRiskRatio().toStringAsFixed(2)),
        ],
      ),
    );
  }

  Widget _buildPriceItem(String label, double price, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          Text(
            '¥${price.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
        ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoCard() {
    // 获取当前主题以检测是否为暗色模式
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // 计算盈亏比
    double profitRiskRatio = 0.0;
    final planPrice = widget.tradePlan.planPrice ?? 0.0;
    final stopLossPrice = widget.tradePlan.stopLossPrice ?? 0.0;
    final takeProfitPrice = widget.tradePlan.takeProfitPrice ?? 0.0;
    
    if (planPrice > 0 && stopLossPrice > 0) {
      final riskPerUnit = (planPrice - stopLossPrice).abs();
      final rewardPerUnit = (takeProfitPrice - planPrice).abs();
      
      if (riskPerUnit > 0) {
        profitRiskRatio = rewardPerUnit / riskPerUnit;
      }
    }
    
    return Card(
      elevation: 0,
      color: isDarkMode ? const Color(0xFF252525) : Colors.grey[100],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '交易基本信息',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.blue[300] : null,
              ),
            ),
            Divider(color: isDarkMode ? Colors.grey.shade700 : null),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      // 使用盈亏状态代替交易类型
                      if (widget.tradePlan.netProfit != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: widget.tradePlan.netProfit! >= 0 
                                ? (isDarkMode ? Colors.green.withOpacity(0.2) : Colors.green.withOpacity(0.1))
                                : (isDarkMode ? Colors.red.withOpacity(0.2) : Colors.red.withOpacity(0.1)),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: widget.tradePlan.netProfit! >= 0 
                                  ? (isDarkMode ? Colors.green.withOpacity(0.6) : Colors.green.withOpacity(0.5))
                                  : (isDarkMode ? Colors.red.withOpacity(0.6) : Colors.red.withOpacity(0.5)),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                widget.tradePlan.netProfit! >= 0 
                                    ? Icons.trending_up 
                                    : Icons.trending_down,
                                size: 16,
                                color: widget.tradePlan.netProfit! >= 0 
                                    ? (isDarkMode ? Colors.green[300] : Colors.green)
                                    : (isDarkMode ? Colors.red[300] : Colors.red),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.tradePlan.netProfit! >= 0 ? '盈利交易' : '亏损交易',
                                style: TextStyle(
                                  color: widget.tradePlan.netProfit! >= 0 
                                      ? (isDarkMode ? Colors.green[300] : Colors.green)
                                      : (isDarkMode ? Colors.red[300] : Colors.red),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: widget.tradePlan.tradeType == TradeType.buy
                                ? (isDarkMode ? Colors.green.withOpacity(0.2) : Colors.green.withOpacity(0.1))
                                : (isDarkMode ? Colors.red.withOpacity(0.2) : Colors.red.withOpacity(0.1)),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: widget.tradePlan.tradeType == TradeType.buy
                                  ? (isDarkMode ? Colors.green.withOpacity(0.6) : Colors.green.withOpacity(0.5))
                                  : (isDarkMode ? Colors.red.withOpacity(0.6) : Colors.red.withOpacity(0.5)),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                widget.tradePlan.tradeType == TradeType.buy ? Icons.arrow_downward : Icons.arrow_upward,
                                size: 16,
                                color: widget.tradePlan.tradeType == TradeType.buy 
                                    ? (isDarkMode ? Colors.green[300] : Colors.green)
                                    : (isDarkMode ? Colors.red[300] : Colors.red),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.tradePlan.tradeType == TradeType.buy ? '买入' : '卖出',
                                style: TextStyle(
                                  color: widget.tradePlan.tradeType == TradeType.buy 
                                      ? (isDarkMode ? Colors.green[300] : Colors.green)
                                      : (isDarkMode ? Colors.red[300] : Colors.red),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                if (widget.tradePlan.marketPhase != null)
                  Expanded(
                    child: Text(
                      '盘趋阶段: ${_getMarketPhaseName(widget.tradePlan.marketPhase!)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isDarkMode ? Colors.grey[300] : null,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '进场价格: ¥${widget.tradePlan.planPrice?.toStringAsFixed(2) ?? '0.00'}',
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey[300] : null,
                    ),
                  ),
                ),
                if (widget.tradePlan.priceTriggerType != null)
                  Expanded(
                    child: Text(
                      '触发类型: ${widget.tradePlan.priceTriggerType == PriceTriggerType.breakout ? '突破' : '回调'}',
                      style: TextStyle(
                        color: isDarkMode ? Colors.grey[300] : null,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            
            // 添加止损价格和目标价格到交易基本信息卡片中
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.trending_down,
                        size: 14,
                        color: isDarkMode ? Colors.green[300] : Colors.green, // A股绿色：亏损
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '止损价: ¥${widget.tradePlan.stopLossPrice?.toStringAsFixed(2) ?? '0.00'}',
                        style: TextStyle(
                          color: isDarkMode ? Colors.grey[300] : null,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.trending_up,
                        size: 14,
                        color: isDarkMode ? Colors.red[300] : Colors.red, // A股红色：盈利
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '目标价: ¥${widget.tradePlan.takeProfitPrice?.toStringAsFixed(2) ?? '0.00'}',
                        style: TextStyle(
                          color: isDarkMode ? Colors.grey[300] : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '计划数量: ${widget.tradePlan.planQuantity ?? 0}',
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey[300] : null,
                    ),
                  ),
                ),
                if (widget.tradePlan.positionPercentage != null)
                  Expanded(
                    child: Text(
                      '仓位占比: ${widget.tradePlan.positionPercentage}%',
                      style: TextStyle(
                        color: isDarkMode ? Colors.grey[300] : null,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '建仓方式: ${widget.tradePlan.positionBuildingMethod == PositionBuildingMethod.oneTime ? '一次性建仓' : '分批建仓'}',
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey[300] : null,
                    ),
                  ),
                ),
                if (widget.tradePlan.trendStrength != null)
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          '趋势强度: ',
                          style: TextStyle(
                            color: isDarkMode ? Colors.grey[300] : null,
                          ),
                        ),
                        Text(
                          _getTrendStrengthName(widget.tradePlan.trendStrength!),
                          style: TextStyle(
                            color: isDarkMode 
                                ? _getTrendStrengthColorDark(widget.tradePlan.trendStrength!)
                                : _getTrendStrengthColor(widget.tradePlan.trendStrength!),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            
            if (widget.tradePlan.entryDifficulty != null)
              Row(
                children: [
                  Text(
                    '下单质量: ',
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey[300] : null,
                    ),
                  ),
                  _buildAnimatedDifficultyStars(widget.tradePlan.entryDifficulty!),
                ],
              ),
            
            const SizedBox(height: 8),
            
            if (widget.tradePlan.createTime != null)
              Text(
                '创建时间: ${DateFormat('yyyy-MM-dd').format(widget.tradePlan.createTime!)}',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[300] : null,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStrategyInfoCard() {
    // 获取当前主题以检测是否为暗色模式
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      elevation: 0,
      color: isDarkMode ? const Color(0xFF252525) : Colors.grey[100],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '交易策略',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.blue[300] : null,
              ),
            ),
            Divider(color: isDarkMode ? Colors.grey.shade700 : null),
            
            if (widget.tradePlan.strategy != null) ...[
              Text(
                '策略: ${widget.tradePlan.strategy}',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[300] : null,
                ),
              ),
              const SizedBox(height: 8),
            ],
            
            if (widget.tradePlan.reason != null && widget.tradePlan.reason!.isNotEmpty) ...[
              Text(
                '开仓理由:',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[300] : null,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: isDarkMode 
                      ? Border.all(color: Colors.grey.shade800) 
                      : null,
                ),
                child: Text(
                  widget.tradePlan.reason!,
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey[300] : null,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            
            if (widget.tradePlan.invalidationCondition != null && widget.tradePlan.invalidationCondition!.isNotEmpty) ...[
              Text(
                '策略失效条件:',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[300] : null,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isDarkMode ? Colors.orange.shade800.withOpacity(0.5) : Colors.orange.shade200,
                  ),
                ),
                child: Text(
                  widget.tradePlan.invalidationCondition!,
                  style: TextStyle(
                    color: isDarkMode ? Colors.orange[300] : null,
                  ),
                ),
              ),
            ],
            
            if (widget.tradePlan.notes != null && widget.tradePlan.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '备注:',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[300] : null,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: isDarkMode 
                      ? Border.all(color: Colors.grey.shade800) 
                      : null,
                ),
                child: Text(
                  widget.tradePlan.notes!,
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey[300] : null,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRiskControlCard() {
    // 获取当前主题以检测是否为暗色模式
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // 计算动态盈亏比
    double profitRiskRatio = 0.0;
    final planPrice = widget.tradePlan.planPrice ?? 0.0;
    final stopLossPrice = widget.tradePlan.stopLossPrice ?? 0.0;
    final takeProfitPrice = widget.tradePlan.takeProfitPrice ?? 0.0;
    
    if (planPrice > 0 && stopLossPrice > 0) {
      final riskPerUnit = (planPrice - stopLossPrice).abs();
      final rewardPerUnit = (takeProfitPrice - planPrice).abs();
      
      if (riskPerUnit > 0) {
        profitRiskRatio = rewardPerUnit / riskPerUnit;
      }
    }
    
    Color profitRatioColor = isDarkMode ? Colors.grey[400]! : Colors.grey;
    if (profitRiskRatio >= 3) {
      profitRatioColor = isDarkMode ? Colors.green[300]! : Colors.green;
    } else if (profitRiskRatio > 0) {
      profitRatioColor = isDarkMode ? Colors.orange[300]! : Colors.orange;
    }
    
    return Card(
      elevation: 0,
      color: isDarkMode ? const Color(0xFF252525) : Colors.grey[100],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '风险控制',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.blue[300] : null,
              ),
            ),
            Divider(color: isDarkMode ? Colors.grey.shade700 : null),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (widget.tradePlan.atrValue != null && widget.tradePlan.atrMultiple != null)
                  Expanded(
                    child: Text(
                      'ATR止损: ${widget.tradePlan.atrValue! * widget.tradePlan.atrMultiple!}点',
                      style: TextStyle(
                        color: isDarkMode ? Colors.grey[300] : null,
                      ),
                    ),
                  ),
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        '动态盈亏比: ',
                        style: TextStyle(
                          color: isDarkMode ? Colors.grey[300] : null,
                        ),
                      ),
                      Text(
                        profitRiskRatio > 0 ? profitRiskRatio.toStringAsFixed(2) : '未知',
                        style: TextStyle(
                          color: profitRatioColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            if (widget.tradePlan.riskPercentage != null)
              Row(
                children: [
                  Icon(
                    Icons.shield,
                    size: 16,
                    color: (widget.tradePlan.riskPercentage ?? 0) <= 2.0 
                        ? (isDarkMode ? Colors.green[300] : Colors.green) 
                        : (isDarkMode ? Colors.orange[300] : Colors.orange),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '风险熔断: 单笔最大亏损 ${widget.tradePlan.riskPercentage}%',
                    style: TextStyle(
                      color: (widget.tradePlan.riskPercentage ?? 0) <= 2.0 
                          ? (isDarkMode ? Colors.green[300] : Colors.green[700]) 
                          : (isDarkMode ? Colors.orange[300] : Colors.orange[700]),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
  
  String _getMarketPhaseName(MarketPhase phase) {
    switch (phase) {
      case MarketPhase.buildingBottom:
        return '筑底阶段';
      case MarketPhase.rising:
        return '上升阶段';
      case MarketPhase.consolidation:
        return '盘整阶段';
      case MarketPhase.topping:
        return '做头阶段';
      case MarketPhase.falling:
        return '下降阶段';
    }
  }
  
  String _getTrendStrengthName(TrendStrength strength) {
    switch (strength) {
      case TrendStrength.strong:
        return '强';
      case TrendStrength.medium:
        return '中';
      case TrendStrength.weak:
        return '弱';
    }
  }
  
  Color _getTrendStrengthColor(TrendStrength strength) {
    switch (strength) {
      case TrendStrength.strong:
        return Colors.red;
      case TrendStrength.medium:
        return Colors.orange;
      case TrendStrength.weak:
        return Colors.green;
    }
  }
  
  // 暗色模式下的趋势强度颜色
  Color _getTrendStrengthColorDark(TrendStrength strength) {
    switch (strength) {
      case TrendStrength.strong:
        return Colors.red[300]!;
      case TrendStrength.medium:
        return Colors.orange[300]!;
      case TrendStrength.weak:
        return Colors.green[300]!;
    }
  }
  
  Color _getDifficultyColor(EntryDifficulty difficulty) {
    return Colors.amber; // 统一使用金色
  }
  
  // 暗色模式下的难度星级颜色
  Color _getDifficultyColorDark(EntryDifficulty difficulty) {
    return Colors.amber[300]!; // 暗色模式下使用较亮的金色
  }
  
  String _getDifficultyLabel(EntryDifficulty difficulty) {
    switch (difficulty) {
      case EntryDifficulty.veryEasy:
        return '极高质量';
      case EntryDifficulty.easy:
        return '高质量';
      case EntryDifficulty.medium:
        return '中等质量';
      case EntryDifficulty.hard:
        return '较低质量';
      case EntryDifficulty.veryHard:
        return '低质量';
    }
  }
  
  Widget _buildAnimatedDifficultyStars(EntryDifficulty difficulty) {
    final int starCount = difficulty.index + 1; // 从1到5颗星
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color starColor = isDarkMode ? _getDifficultyColorDark(difficulty) : _getDifficultyColor(difficulty);
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(starCount, (index) {
          return TweenAnimationBuilder(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 300 + (index * 150)), // 每个星星依次出现
            curve: Curves.elasticOut,
            builder: (context, double value, child) {
              return Transform.scale(
                scale: value,
                child: Padding(
                  padding: const EdgeInsets.only(right: 1.0),
                  child: Text(
                    '⭐',
                    style: TextStyle(
                      fontSize: 14,
                      color: starColor,
                      shadows: [
                        Shadow(
                          color: starColor.withOpacity(0.7),
                          blurRadius: 3.0 * value,
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }),
        const SizedBox(width: 4),
        // 添加难度文字标签
        Text(
          _getDifficultyLabel(difficulty),
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildKLineChart() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    if (_isLoading) {
      return Container(
        height: 350,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDarkMode 
              ? [
                  const Color(0xFF1F2937).withOpacity(0.8),
                  const Color(0xFF111827).withOpacity(0.9),
                ]
              : [
                  const Color(0xFFF8FAFC),
                  const Color(0xFFF1F5F9),
                ],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: isDarkMode 
                ? Colors.black.withOpacity(0.3)
                : Colors.grey.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
          child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDarkMode 
                    ? Colors.blue.withOpacity(0.1)
                    : Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDarkMode ? Colors.blue[300]! : Colors.blue[600]!,
                  ),
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '正在加载K线数据...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.grey[300] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_kLineData.isEmpty) {
      return Container(
        height: 350,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDarkMode 
              ? [
                  const Color(0xFF1F2937).withOpacity(0.8),
                  const Color(0xFF111827).withOpacity(0.9),
                ]
              : [
                  const Color(0xFFF8FAFC),
                  const Color(0xFFF1F5F9),
                ],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: isDarkMode 
                ? Colors.black.withOpacity(0.3)
                : Colors.grey.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDarkMode 
                    ? Colors.grey.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Icon(
                  Icons.candlestick_chart_outlined,
                  size: 48,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[500],
                ),
              ),
              const SizedBox(height: 20),
                Text(
                  '暂无K线数据',
                  style: TextStyle(
                  color: isDarkMode ? Colors.grey[300] : Colors.grey[600],
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
              Text(
                '无法获取历史价格数据',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                  onPressed: _loadKLineData,
                icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('重新加载'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDarkMode ? Colors.blue[700] : Colors.blue[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                ),
              ],
          ),
        ),
      );
    }
    
    // 使用有效的K线数据
    final validKLineData = _kLineData;
    
    // 获取计划价格、止损价格和目标价格
    final planPrice = widget.tradePlan.planPrice ?? 0.0;
    final stopLossPrice = widget.tradePlan.stopLossPrice ?? 0.0;
    final takeProfitPrice = widget.tradePlan.takeProfitPrice ?? 0.0;
    
    // 使用类属性中的最大最小值，确保它们已经被正确设置
    var minY = _minY;
    var maxY = _maxY;
    
    print('准备显示K线图，数据点数: ${validKLineData.length}');
    
    // 如果计划价格在范围之外，扩展Y轴范围
    if (planPrice > 0 && (planPrice < minY || planPrice > maxY)) {
      if (planPrice < minY) minY = planPrice * 0.95;
      if (planPrice > maxY) maxY = planPrice * 1.05;
    }
    
    // 如果止损价格在范围之外，扩展Y轴范围
    if (stopLossPrice > 0 && (stopLossPrice < minY || stopLossPrice > maxY)) {
      if (stopLossPrice < minY) minY = stopLossPrice * 0.95;
      if (stopLossPrice > maxY) maxY = stopLossPrice * 1.05;
    }
    
    // 如果目标价格在范围之外，扩展Y轴范围
    if (takeProfitPrice > 0 && (takeProfitPrice < minY || takeProfitPrice > maxY)) {
      if (takeProfitPrice < minY) minY = takeProfitPrice * 0.95;
      if (takeProfitPrice > maxY) maxY = takeProfitPrice * 1.05;
    }
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode 
            ? [
                const Color(0xFF1F2937).withOpacity(0.8),
                const Color(0xFF111827).withOpacity(0.9),
              ]
            : [
                const Color(0xFFF8FAFC),
                const Color(0xFFF1F5F9),
              ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isDarkMode 
              ? Colors.black.withOpacity(0.3)
              : Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
        ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 图表标题栏
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDarkMode 
                    ? [
                        const Color(0xFF1E40AF).withOpacity(0.2),
                        const Color(0xFF3B82F6).withOpacity(0.1),
                      ]
                    : [
                        const Color(0xFFEFF6FF),
                        const Color(0xFFDBEAFE),
                      ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDarkMode 
                    ? const Color(0xFF3B82F6).withOpacity(0.3)
                    : const Color(0xFF93C5FD).withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  // 图标
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDarkMode
                          ? [
                              const Color(0xFF3B82F6).withOpacity(0.3),
                              const Color(0xFF2563EB).withOpacity(0.2),
                            ]
                          : [
                              const Color(0xFF93C5FD).withOpacity(0.4),
                              const Color(0xFF60A5FA).withOpacity(0.3),
                            ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.candlestick_chart,
                      color: isDarkMode ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  // 标题和描述
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'K线走势图',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${validKLineData.length}天历史数据',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 300,
              child: LineChart(
                LineChartData(
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      tooltipBgColor: isDarkMode 
                          ? Colors.grey[800]!.withOpacity(0.8) 
                          : Colors.blueGrey.withOpacity(0.8),
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((touchedSpot) {
                          final spotIndex = touchedSpot.spotIndex;
                          if (spotIndex >= 0 && spotIndex < validKLineData.length) {
                            final data = validKLineData[spotIndex];
                            try {
                              final dataDateStr = data['date'] != null 
                                ? data['date'].toString() 
                                : data['trade_date'] != null 
                                  ? data['trade_date'].toString() 
                                  : '';
                                  
                              if (dataDateStr.isNotEmpty) {
                                final date = DateTime.parse(dataDateStr.split('T')[0]).toLocal();
                                final formattedDate = DateFormat('yyyy-MM-dd').format(date);
                                
                                return LineTooltipItem(
                                  formattedDate,
                                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  children: [
                                    TextSpan(
                                      text: '\n开:${data['open']?.toStringAsFixed(2)}',
                                      style: const TextStyle(color: Colors.white70),
                                    ),
                                    TextSpan(
                                      text: ' 收:${data['close']?.toStringAsFixed(2)}',
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                    TextSpan(
                                      text: '\n高:${data['high']?.toStringAsFixed(2)}',
                                      style: TextStyle(color: isDarkMode ? Colors.greenAccent[200] : Colors.greenAccent),
                                    ),
                                    TextSpan(
                                      text: ' 低:${data['low']?.toStringAsFixed(2)}',
                                      style: TextStyle(color: isDarkMode ? Colors.redAccent[100] : Colors.redAccent),
                                    ),
                                  ],
                                );
                              }
                            } catch (e) {
                              print('解析日期出错: $e，原始数据: $data');
                            }
                          }
                          return null;
                        }).toList();
                      },
                    ),
                    touchCallback: (event, touchResponse) {
                      if (touchResponse?.lineBarSpots != null && touchResponse!.lineBarSpots!.isNotEmpty) {
                        final index = touchResponse.lineBarSpots!.first.spotIndex;
                        setState(() {
                          _selectedIndex = index;
                          
                          // 处理点击事件，显示详细数据
                          if (event is FlTapUpEvent && index >= 0 && index < validKLineData.length) {
                            _selectedPoint = validKLineData[index];
                            _showDetailView = true;
                          }
                        });
                      } else {
                        setState(() {
                          _selectedIndex = -1;
                        });
                      }
                    },
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    drawHorizontalLine: true,
                    horizontalInterval: (maxY - minY) / 5,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
                        strokeWidth: 0.5,
                      );
                    },
                    getDrawingVerticalLine: (value) {
                      return FlLine(
                        color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
                        strokeWidth: 0.5,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toStringAsFixed(2),
                            style: TextStyle(
                              fontSize: 10,
                              color: isDarkMode ? Colors.grey[400] : null,
                            ),
                          );
                        },
                        reservedSize: 40,
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: validKLineData.length > 10 ? validKLineData.length / 5 : 1,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < validKLineData.length && index % 5 == 0) {
                            try {
                              final dateStr = validKLineData[index]['date'] != null 
                                ? validKLineData[index]['date'].toString() 
                                : validKLineData[index]['trade_date'] != null
                                  ? validKLineData[index]['trade_date'].toString()
                                  : '';
                                  
                              if (dateStr.isNotEmpty) {
                                final date = DateTime.parse(dateStr.split('T')[0]);
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    DateFormat('MM-dd').format(date),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDarkMode ? Colors.grey[400] : null,
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              print('解析日期出错: $e，原始数据: ${validKLineData[index]}');
                            }
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(
                      color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                      width: 0.5,
                    ),
                  ),
                  minX: 0,
                  maxX: validKLineData.length.toDouble() - 1,
                  minY: minY,
                  maxY: maxY,
                  lineBarsData: [
                    // 收盘价线
                    LineChartBarData(
                      spots: List.generate(validKLineData.length, (index) {
                        final data = validKLineData[index];
                        return FlSpot(
                          index.toDouble(),
                          data['close'] as double,
                        );
                      }),
                      isCurved: false,
                      color: isDarkMode ? Colors.blue[400] : Colors.blue,
                      barWidth: 2,
                      dotData: const FlDotData(
                        show: false,
                      ),
                    ),
                    
                    // 计划价格水平线
                    if (planPrice > 0)
                      LineChartBarData(
                        spots: [
                          FlSpot(0, planPrice),
                          FlSpot(validKLineData.length.toDouble() - 1, planPrice),
                        ],
                        isCurved: false,
                        color: Colors.grey[700], // 深灰色：进场价格，更精细美观
                        barWidth: 1,
                        dotData: const FlDotData(show: false),
                        dashArray: [6, 3],
                      ),
                    
                    // 止损价格水平线
                    if (stopLossPrice > 0)
                      LineChartBarData(
                        spots: [
                          FlSpot(0, stopLossPrice),
                          FlSpot(validKLineData.length.toDouble() - 1, stopLossPrice),
                        ],
                        isCurved: false,
                        color: isDarkMode ? Colors.green[400]! : Colors.green, // A股绿色：止损（亏损）
                        barWidth: 1.5,
                        dotData: const FlDotData(show: false),
                        dashArray: [2, 2],
                      ),
                    
                    // 目标价格水平线
                    if (takeProfitPrice > 0)
                      LineChartBarData(
                        spots: [
                          FlSpot(0, takeProfitPrice),
                          FlSpot(validKLineData.length.toDouble() - 1, takeProfitPrice),
                        ],
                        isCurved: false,
                        color: isDarkMode ? Colors.red[400]! : Colors.red, // A股红色：止盈（盈利）
                        barWidth: 1.5,
                        dotData: const FlDotData(show: false),
                        dashArray: [2, 2],
                      ),
                      
                    // 如果有实际成交价，标记实际买卖点
                    if (widget.tradePlan.actualPrice != null && widget.tradePlan.actualPrice! > 0)
                      LineChartBarData(
                        spots: [
                          // 尝试找到与实际成交日期最接近的点
                          FlSpot(
                            widget.tradePlan.settlementDate != null 
                                ? _findClosestDataPointIndex(validKLineData, widget.tradePlan.settlementDate!).toDouble()
                                : validKLineData.length.toDouble() * 0.8, 
                            widget.tradePlan.actualPrice!
                          ),
                        ],
                        isCurved: false,
                        color: Colors.transparent,
                        barWidth: 0,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            final bool isProfit = widget.tradePlan.netProfit != null && widget.tradePlan.netProfit! >= 0;
                            final bool isLoss = widget.tradePlan.netProfit != null && widget.tradePlan.netProfit! < 0;
                            
                            // 根据交易类型和盈亏状态选择不同标记
                            if (widget.tradePlan.tradeType == TradeType.buy) {
                              // 买入交易
                              return FlDotCrossPainter(
                                color: isProfit ? Colors.green.shade700 : (isLoss ? Colors.red.shade700 : Colors.green.shade600),
                                width: 2.5,
                                size: 14,
                              );
                            } else {
                              // 卖出交易
                              return FlDotCirclePainter(
                                radius: 10,
                                color: isProfit ? Colors.green.shade700.withOpacity(0.8) : (isLoss ? Colors.red.shade700.withOpacity(0.8) : Colors.red.shade600.withOpacity(0.8)),
                                strokeWidth: 2,
                                strokeColor: Colors.white,
                              );
                            }
                          },
                        ),
                      ),
                      
                    // 添加实际成交标记点
                    LineChartBarData(
                      spots: [
                        FlSpot(validKLineData.length.toDouble() * 0.8, widget.tradePlan.actualPrice ?? 0.0),
                      ],
                      isCurved: false,
                      color: Colors.transparent,
                      barWidth: 0,
                      dotData: FlDotData(
                        show: widget.tradePlan.actualPrice != null && widget.tradePlan.actualPrice! > 0,
                        getDotPainter: (spot, percent, barData, index) {
                          final isCloseToTarget = widget.tradePlan.takeProfitPrice != null && 
                              widget.tradePlan.actualPrice != null &&
                              (widget.tradePlan.actualPrice! - widget.tradePlan.takeProfitPrice!).abs() < 
                              (widget.tradePlan.planPrice ?? 0) * 0.01;
                              
                          final isCloseToStopLoss = widget.tradePlan.stopLossPrice != null && 
                              widget.tradePlan.actualPrice != null &&
                              (widget.tradePlan.actualPrice! - widget.tradePlan.stopLossPrice!).abs() < 
                              (widget.tradePlan.planPrice ?? 0) * 0.01;
                          
                          final Color dotColor = isCloseToTarget 
                              ? Colors.green.shade700
                              : isCloseToStopLoss 
                                ? Colors.red.shade700
                                : widget.tradePlan.tradeType == TradeType.buy 
                                  ? Colors.green
                                  : Colors.red;
                                  
                          // 使用正确的FlDotCirclePainter并添加一些视觉效果
                          return FlDotCirclePainter(
                            radius: 8,
                            color: dotColor.withOpacity(0.8),
                            strokeWidth: 3,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                    ),
                  ],
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      // 添加价格标签
                      if (planPrice > 0)
                        HorizontalLine(
                          y: planPrice,
                          color: Colors.grey[700], // 深灰色：进场价格，更精细美观
                          strokeWidth: 1,
                          dashArray: [6, 3],
                          label: HorizontalLineLabel(
                            show: true,
                            alignment: Alignment.topRight,
                            padding: const EdgeInsets.only(right: 10.0, bottom: 3.0),
                            style: TextStyle(
                              color: Colors.grey[700], // 深灰色：进场价格，更精细美观
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                            labelResolver: (line) => '进场价 ${planPrice.toStringAsFixed(2)}',
                          ),
                        ),
                      
                      if (stopLossPrice > 0)
                        HorizontalLine(
                          y: stopLossPrice,
                          color: Colors.green, // A股绿色：止损（亏损）
                          strokeWidth: 1,
                          dashArray: [2, 2],
                          label: HorizontalLineLabel(
                            show: true,
                            alignment: Alignment.topRight,
                            padding: const EdgeInsets.only(right: 8.0, bottom: 2.0),
                            style: const TextStyle(
                              color: Colors.green, // A股绿色：止损（亏损）
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                            labelResolver: (line) => '止损价 ${stopLossPrice.toStringAsFixed(2)}',
                          ),
                        ),
                      
                      if (takeProfitPrice > 0)
                        HorizontalLine(
                          y: takeProfitPrice,
                          color: Colors.red, // A股红色：止盈（盈利）
                          strokeWidth: 1,
                          dashArray: [2, 2],
                          label: HorizontalLineLabel(
                            show: true,
                            alignment: Alignment.topRight,
                            padding: const EdgeInsets.only(right: 8.0, bottom: 2.0),
                            style: const TextStyle(
                              color: Colors.red, // A股红色：止盈（盈利）
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                            labelResolver: (line) => '目标价 ${takeProfitPrice.toStringAsFixed(2)}',
                          ),
                        ),
                        
                      // 添加实际成交价格线
                      if (widget.tradePlan.actualPrice != null && widget.tradePlan.actualPrice! > 0)
                        HorizontalLine(
                          y: widget.tradePlan.actualPrice!,
                          color: widget.tradePlan.tradeType == TradeType.buy ? Colors.green.shade800 : Colors.red.shade800,
                          strokeWidth: 1.5,
                          label: HorizontalLineLabel(
                            show: true,
                            alignment: Alignment.topLeft,
                            padding: const EdgeInsets.only(left: 8.0, bottom: 2.0),
                            style: TextStyle(
                              color: widget.tradePlan.tradeType == TradeType.buy ? Colors.green.shade800 : Colors.red.shade800,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                            labelResolver: (line) => '实际成交价 ${widget.tradePlan.actualPrice!.toStringAsFixed(2)}',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            
            // 图例标识
            Wrap(
              spacing: 16,
              children: [
                _buildChartLegend('K线', isDarkMode ? Colors.blue[400]! : Colors.blue),
                _buildChartLegend(
                  '进场价 ${planPrice.toStringAsFixed(2)}', 
                  Colors.grey[700]! // 深灰色：进场价格，更精细美观
                ),
                _buildChartLegend('止损价 ${stopLossPrice.toStringAsFixed(2)}', isDarkMode ? Colors.green[400]! : Colors.green), // A股绿色：止损
                _buildChartLegend('目标价 ${takeProfitPrice.toStringAsFixed(2)}', isDarkMode ? Colors.red[400]! : Colors.red), // A股红色：止盈
                if (widget.tradePlan.actualPrice != null && widget.tradePlan.netProfit != null) 
                  _buildChartLegend(
                    widget.tradePlan.netProfit! >= 0
                        ? '成交价 ${widget.tradePlan.actualPrice!.toStringAsFixed(2)} (盈利)'
                        : '成交价 ${widget.tradePlan.actualPrice!.toStringAsFixed(2)} (亏损)',
                    widget.tradePlan.netProfit! >= 0 
                        ? (isDarkMode ? Colors.green[300]! : Colors.green.shade700)
                        : (isDarkMode ? Colors.red[300]! : Colors.red.shade700)
                  ),
                if (widget.tradePlan.actualPrice != null && widget.tradePlan.netProfit == null)
                  _buildChartLegend(
                    '成交价 ${widget.tradePlan.actualPrice!.toStringAsFixed(2)}',
                    widget.tradePlan.tradeType == TradeType.buy 
                        ? (isDarkMode ? Colors.green[300]! : Colors.green.shade700)
                        : (isDarkMode ? Colors.red[300]! : Colors.red.shade700)
                  ),
              ],
            ),
            
            // 显示详细K线数据
            if (_showDetailView && _selectedPoint != null)
              _buildDetailCard(),
            if (!_showDetailView || _selectedPoint == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Center(
                  child: Text(
                    '点击K线图上的点查看详细数据',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildChartLegend(String text, Color color) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 3,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? Colors.grey[300] : color,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailCard() {
    if (_selectedPoint == null) return const SizedBox.shrink();
    
    final currentIndex = _kLineData.indexOf(_selectedPoint!);
    final dateStr = _selectedPoint!['date'].toString().split('T')[0];
    final open = double.parse(_selectedPoint!['open'].toString());
    final close = double.parse(_selectedPoint!['close'].toString());
    final high = double.parse(_selectedPoint!['high'].toString());
    final low = double.parse(_selectedPoint!['low'].toString());
    final volume = double.parse(_selectedPoint!['volume'].toString());
    
    // 获取前后日数据
    Map<String, dynamic>? prevData;
    Map<String, dynamic>? nextData;
    
    if (currentIndex > 0 && currentIndex < _kLineData.length) {
      prevData = _kLineData[currentIndex - 1];
    }
    if (currentIndex >= 0 && currentIndex < _kLineData.length - 1) {
      nextData = _kLineData[currentIndex + 1];
    }
    
    // 计算涨跌幅
    final changePercent = (close - open) / open * 100;
    final isPositive = close >= open;
    
    // K线形态识别
    String kLineType = _getKLinePattern(open, high, low, close);
    
    // 获取当前主题以检测是否为暗色模式
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // 定义颜色，确保非空
    final redColor = isDarkMode ? Colors.red[300]! : Colors.red;
    final greenColor = isDarkMode ? Colors.green[300]! : Colors.green;
    final blueColor = isDarkMode ? Colors.blue[300]! : Colors.blue.shade700;
    
    return Card(
      elevation: 3,
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isDarkMode ? const Color(0xFF2C2C2C) : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
                          // 标题栏
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '详细数据分析',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 20, color: isDarkMode ? Colors.white70 : null),
                  onPressed: () {
                    setState(() {
                      _showDetailView = false;
                      _selectedPoint = null;
                    });
                  },
                ),
              ],
            ),
            Divider(color: isDarkMode ? Colors.grey.shade600 : null),
            
            // 日期和K线形态
                Row(
                  children: [
                    Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    dateStr,
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                          color: isPositive 
                      ? Colors.red.withOpacity(0.1) 
                      : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        kLineType,
                        style: TextStyle(
                      color: isPositive ? Colors.red : Colors.green,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 三日K线对比
            Row(
              children: [
                // 前一日K线
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '前一日',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 45,
                        height: 65,
                        decoration: BoxDecoration(
                          color: isDarkMode 
                            ? const Color(0xFF1C1C1E) 
                            : Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.withOpacity(0.3)),
                        ),
                        child: prevData != null 
                          ? CustomPaint(
                              painter: KLinePainter(
                                open: double.parse(prevData['open'].toString()),
                                high: double.parse(prevData['high'].toString()),
                                low: double.parse(prevData['low'].toString()),
                                close: double.parse(prevData['close'].toString()),
                                isPositive: double.parse(prevData['close'].toString()) >= double.parse(prevData['open'].toString()),
                                redColor: redColor,
                                greenColor: greenColor,
                                isDarkMode: isDarkMode,
                              ),
                            )
                          : Center(
                              child: Icon(
                                Icons.remove,
                                color: Colors.grey[400],
                                size: 20,
                              ),
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        prevData != null 
                          ? prevData['date'].toString().split('T')[0].substring(5)
                          : '--',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // 当日K线（突出显示）
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '当日',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 60,
                        height: 80,
                        decoration: BoxDecoration(
                          color: isDarkMode 
                            ? const Color(0xFF1C1C1E) 
                            : Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.6),
                            width: 2,
                          ),
                        ),
                        child: CustomPaint(
                          painter: KLinePainter(
                            open: open,
                            high: high,
                            low: low,
                            close: close,
                            isPositive: isPositive,
                            redColor: redColor,
                            greenColor: greenColor,
                            isDarkMode: isDarkMode,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateStr.substring(5),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // 后一日K线
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '后一日',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 45,
                        height: 65,
                        decoration: BoxDecoration(
                          color: isDarkMode 
                            ? const Color(0xFF1C1C1E) 
                            : Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.withOpacity(0.3)),
                        ),
                        child: nextData != null 
                          ? CustomPaint(
                              painter: KLinePainter(
                                open: double.parse(nextData['open'].toString()),
                                high: double.parse(nextData['high'].toString()),
                                low: double.parse(nextData['low'].toString()),
                                close: double.parse(nextData['close'].toString()),
                                isPositive: double.parse(nextData['close'].toString()) >= double.parse(nextData['open'].toString()),
                                redColor: redColor,
                                greenColor: greenColor,
                                isDarkMode: isDarkMode,
                              ),
                            )
                          : Center(
                              child: Icon(
                                Icons.remove,
                                color: Colors.grey[400],
                                size: 20,
                              ),
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        nextData != null 
                          ? nextData['date'].toString().split('T')[0].substring(5)
                          : '--',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                        ),
                    ),
                  ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Divider(color: isDarkMode ? Colors.grey.shade600 : null),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _buildDetailItem('开盘', open.toStringAsFixed(2), 
                    isPositive ? redColor : greenColor,
                    isDarkMode),
                ),
                Expanded(
                  child: _buildDetailItem('收盘', close.toStringAsFixed(2), 
                    isPositive ? redColor : greenColor,
                    isDarkMode),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _buildDetailItem('最高', high.toStringAsFixed(2), 
                    redColor,
                    isDarkMode),
                ),
                Expanded(
                  child: _buildDetailItem('最低', low.toStringAsFixed(2), 
                    greenColor,
                    isDarkMode),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _buildDetailItem('涨跌幅', '${changePercent.toStringAsFixed(2)}%', 
                    changePercent >= 0 ? redColor : greenColor,
                    isDarkMode),
                ),
                Expanded(
                  child: _buildDetailItem('成交量', '${(volume / 10000).toStringAsFixed(2)}万手', 
                    blueColor,
                    isDarkMode),
                ),
              ],
            ),
            
            if (widget.tradePlan.actualPrice != null) ...[
              Divider(color: isDarkMode ? Colors.grey.shade600 : null),
              Row(
                children: [
                  Text(
                    '交易价与当日价格比较：', 
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: _buildComparisonItem(
                      '对比开盘', 
                      '${((widget.tradePlan.actualPrice! - open) / open * 100).toStringAsFixed(2)}%',
                      widget.tradePlan.actualPrice! >= open ? redColor : greenColor,
                      isDarkMode
                    ),
                  ),
                  Expanded(
                    child: _buildComparisonItem(
                      '对比收盘',
                      '${((widget.tradePlan.actualPrice! - close) / close * 100).toStringAsFixed(2)}%',
                      widget.tradePlan.actualPrice! >= close ? redColor : greenColor,
                      isDarkMode
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildDetailItem(String label, String value, Color valueColor, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? Colors.grey[400] : Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
  
  Widget _buildComparisonItem(String label, String value, Color valueColor, bool isDarkMode) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13,
            color: isDarkMode ? Colors.white70 : null,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSettlementForm() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // A股风格颜色（保留redColor用于其他地方）
    final redColor = const Color(0xFFFF4444); // A股红色
    
    return Container(
      decoration: BoxDecoration(
        // 专业金融风格背景
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode 
            ? [
                const Color(0xFF1F2937).withOpacity(0.8),
                const Color(0xFF111827).withOpacity(0.9),
              ]
            : [
                const Color(0xFFF8FAFC),
                const Color(0xFFF1F5F9),
              ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDarkMode 
            ? const Color(0xFF374151).withOpacity(0.5)
            : const Color(0xFFE2E8F0).withOpacity(0.8),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode 
              ? Colors.black.withOpacity(0.3)
              : Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题 - 专业金融风格
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDarkMode
                      ? [
                          const Color(0xFF1E40AF).withOpacity(0.25),
                          const Color(0xFF3B82F6).withOpacity(0.15),
                        ]
                      : [
                          const Color(0xFFEFF6FF),
                          const Color(0xFFDBEAFE),
                        ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDarkMode 
                      ? const Color(0xFF3B82F6).withOpacity(0.4)
                      : const Color(0xFF93C5FD).withOpacity(0.6),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // 图标容器
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDarkMode
                            ? [
                                const Color(0xFF3B82F6).withOpacity(0.3),
                                const Color(0xFF2563EB).withOpacity(0.2),
                              ]
                            : [
                                const Color(0xFF93C5FD).withOpacity(0.5),
                                const Color(0xFF60A5FA).withOpacity(0.4),
                              ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_outlined,
                        color: isDarkMode ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    // 标题文字
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '交易结算',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '填写实际成交信息',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode ? Colors.grey[400] : const Color(0xFF64748B),
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // 如果有实际成交价和数量，显示交易金额和盈亏信息
              if (widget.tradePlan.actualPrice != null && widget.tradePlan.actualQuantity != null)
                Column(
                  children: [
                    _buildTransactionSummary(),
                    const SizedBox(height: 24),
                  ],
                ),
              
              TextFormField(
                controller: _priceController,
                decoration: _buildInputDecoration(
                  '实际成交价格',
                  '请输入实际成交价格',
                  Icons.price_change_outlined,
                  isDarkMode,
                ),
                keyboardType: TextInputType.number,
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                  fontSize: 16,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入实际成交价格';
                  }
                  if (double.tryParse(value) == null) {
                    return '请输入有效的价格';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _quantityController,
                decoration: _buildInputDecoration(
                  '实际成交数量',
                  '请输入实际成交数量',
                  Icons.format_list_numbered,
                  isDarkMode,
                ),
                keyboardType: TextInputType.number,
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                  fontSize: 16,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入实际成交数量';
                  }
                  if (int.tryParse(value) == null) {
                    return '请输入有效的数量';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              TextFormField(
                controller: _commissionController,
                decoration: _buildInputDecoration(
                  '手续费（可选）',
                  '请输入手续费',
                  Icons.monetization_on_outlined,
                  isDarkMode,
                ),
                keyboardType: TextInputType.number,
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                  fontSize: 16,
                ),
              ),
              
              const SizedBox(height: 16),
              TextFormField(
                controller: _taxController,
                decoration: _buildInputDecoration(
                  '税费（可选）',
                  '请输入税费',
                  Icons.account_balance_outlined,
                  isDarkMode,
                ),
                keyboardType: TextInputType.number,
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                  fontSize: 16,
                ),
              ),
              
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: _buildInputDecoration(
                  '备注',
                  '请输入交易备注信息（选填）',
                  Icons.note_outlined,
                  isDarkMode,
                ),
                maxLines: 3,
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),
              
              // A股风格保存按钮
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      redColor,
                      redColor.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: redColor.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _saveSettlement,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.save_outlined,
                        size: 20,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '保存结算',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // A股风格输入框装饰
  InputDecoration _buildInputDecoration(String label, String hint, IconData icon, bool isDarkMode) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: isDarkMode ? Colors.blue[400] : Colors.blue[600]),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDarkMode ? Colors.grey[600]! : Colors.grey[400]!,
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDarkMode ? Colors.blue[400]! : Colors.blue[600]!,
          width: 2,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDarkMode ? Colors.grey[600]! : Colors.grey[400]!,
          width: 1,
        ),
      ),
      fillColor: isDarkMode ? const Color(0xFF2D2D2D) : const Color(0xFFF8F9FA),
      filled: true,
      labelStyle: TextStyle(
        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
      ),
      hintStyle: TextStyle(
        color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
      ),
    );
  }

  void _saveSettlement() {
    if (_formKey.currentState!.validate()) {
      try {
        final priceValue = double.parse(_priceController.text);
        final quantityValue = int.parse(_quantityController.text);
        final commissionValue = double.tryParse(_commissionController.text) ?? 0.0;
        final taxValue = double.tryParse(_taxController.text) ?? 0.0;
        
        // 计算实际成本或收入
        double totalAmount = 0.0; // 交易总金额（不含手续费税费）
        double totalCost = 0.0;   // 总成本/收入（含手续费税费）
        double? netProfit;
        double? profitRate;
        double buyAmount = 0.0;   // 买入金额
        double lossAmount = 0.0;  // 亏损金额
        double profitRatio = 0.0; // 盈亏比例
        
        print('交易类型: ${widget.tradePlan.tradeType}, 计划价格: ${widget.tradePlan.planPrice}, 实际价格: $priceValue');
        
        totalAmount = priceValue * quantityValue;
        
        if (widget.tradePlan.tradeType == TradeType.buy) {
          // 买入交易：
          // 交易总金额 = 价格 * 数量
          // 总成本 = 交易总金额 + 手续费 + 税费
          buyAmount = totalAmount; // 记录买入金额
          totalCost = totalAmount + commissionValue + taxValue;
          
          // 买入交易的盈亏计算：
          // 1. 如果实际价格高于计划价格，则为盈利 (可以以更高的价格卖出)
          // 2. 如果实际价格低于计划价格，则为亏损 (买入成本更高)
          if (widget.tradePlan.planPrice != null) {
            final planTotalAmount = widget.tradePlan.planPrice! * quantityValue;
            final planTotalCost = planTotalAmount + commissionValue + taxValue;
            
            // 正值表示盈利(实际价格高于计划价格)，负值表示亏损(实际价格低于计划价格)
            netProfit = totalCost - planTotalCost;
            
            // 计算亏损金额（如果是亏损）
            if (netProfit < 0) {
              lossAmount = netProfit.abs();
            }
            
            profitRate = totalCost > 0 ? (netProfit / totalCost) * 100 : null;
            
            // 计算盈亏比例（风险回报比）
            if (widget.tradePlan.stopLossPrice != null && widget.tradePlan.takeProfitPrice != null) {
              final potentialProfit = (widget.tradePlan.takeProfitPrice! - priceValue).abs();
              final potentialLoss = (widget.tradePlan.stopLossPrice! - priceValue).abs();
              if (potentialLoss > 0) {
                profitRatio = potentialProfit / potentialLoss;
              }
            }
            
            print('买入交易 - 计划成本: $planTotalCost, 实际成本: $totalCost, 盈亏: $netProfit, 盈亏率: $profitRate%, 买入金额: $buyAmount, 亏损金额: $lossAmount, 盈亏比例: $profitRatio');
          }
        } else {
          // 卖出交易：
          // 交易总金额 = 价格 * 数量
          // 总收入 = 交易总金额 - 手续费 - 税费
          totalCost = totalAmount - commissionValue - taxValue;
          
          // 卖出交易的盈亏计算：基于卖出收入与买入成本的比较
          if (widget.tradePlan.planPrice != null && widget.tradePlan.planQuantity != null) {
            // 计算原始计划收入
            final planTotalAmount = widget.tradePlan.planPrice! * quantityValue;
            final planTotalCost = planTotalAmount - commissionValue - taxValue;
            
            // 卖出交易中，实际价格低于计划价格为亏损，反之为盈利
            netProfit = totalCost - planTotalCost;
            
            // 计算亏损金额（如果是亏损）
            if (netProfit < 0) {
              lossAmount = netProfit.abs();
            }
            
            // 卖出盈亏率是基于计划收入的
            profitRate = planTotalCost > 0 ? (netProfit / planTotalCost) * 100 : null;
            
            // 尝试获取之前的买入记录来计算盈亏比例
            // 使用交易计划的计划买入价格作为参考
            buyAmount = widget.tradePlan.planPrice! * quantityValue;
            
            print('卖出交易: 计划收入=$planTotalCost, 实际收入=$totalCost, 盈亏=$netProfit, 盈亏率=$profitRate%, 买入金额=$buyAmount, 亏损金额=$lossAmount');
          }
        }

        print('结算总结: 交易总金额=$totalAmount, 手续费=$commissionValue, 税费=$taxValue, 净盈亏=$netProfit, 盈亏率=$profitRate%, 买入金额=$buyAmount, 亏损金额=$lossAmount, 盈亏比例=$profitRatio');

      final settlement = widget.tradePlan.copyWith(
          actualPrice: priceValue,
          actualQuantity: quantityValue,
          commission: commissionValue,
          tax: taxValue,
          notes: _notesController.text,
          settlementDate: DateTime.now(),
          settlementStatus: '已完成',
          status: TradeStatus.completed,
          category: TradeCategory.settlement,
          totalCost: totalCost,
          netProfit: netProfit,
          profitRate: profitRate,
          updateTime: DateTime.now(),
      );

        // 保存结算信息
        context.read<TradeProvider>().updateTradeRecord(settlement).then((_) {
          // 显示一个成功消息，包含盈亏情况
          if (netProfit != null) {
            final isProfit = netProfit >= 0;
            final message = isProfit 
                ? '交易结算成功，盈利: +¥${netProfit.toStringAsFixed(2)} (+${profitRate?.toStringAsFixed(2)}%)' 
                : '交易结算成功，亏损: ¥${netProfit.abs().toStringAsFixed(2)} (-${profitRate?.abs().toStringAsFixed(2)}%)';
                
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: isProfit ? Colors.green : Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
          
      Navigator.pop(context, settlement);
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }

  Widget _buildTransactionSummary() {
    final tradeType = widget.tradePlan.tradeType;
    final isCompletedTrade = widget.tradePlan.actualPrice != null && widget.tradePlan.actualQuantity != null;
    
    // 计算交易金额和成本
    double? totalAmount = isCompletedTrade ? 
        widget.tradePlan.actualPrice! * widget.tradePlan.actualQuantity! : null;
    
    // 计算手续费和税费
    double? feeAndTax = isCompletedTrade ? 
        (widget.tradePlan.commission ?? 0) + (widget.tradePlan.tax ?? 0) : null;
    
    // 计算计划盈亏 - 基于原始交易计划的预期收益
    double? plannedProfit;
    double? plannedLoss;
    if (widget.tradePlan.planPrice != null && 
        widget.tradePlan.planQuantity != null &&
        widget.tradePlan.takeProfitPrice != null &&
        widget.tradePlan.stopLossPrice != null) {
      
      final planQuantity = widget.tradePlan.planQuantity!;
      final planPrice = widget.tradePlan.planPrice!;
      final takeProfitPrice = widget.tradePlan.takeProfitPrice!;
      final stopLossPrice = widget.tradePlan.stopLossPrice!;
      
      if (tradeType == TradeType.buy) {
        // 买入交易：计划盈利 = (止盈价 - 计划价) * 数量 - 手续费
        plannedProfit = (takeProfitPrice - planPrice) * planQuantity - (widget.tradePlan.commission ?? 0) - (widget.tradePlan.tax ?? 0);
        plannedLoss = (planPrice - stopLossPrice) * planQuantity + (widget.tradePlan.commission ?? 0) + (widget.tradePlan.tax ?? 0);
      } else {
        // 卖出交易：计划盈利 = (计划价 - 止盈价) * 数量 - 手续费
        plannedProfit = (planPrice - takeProfitPrice) * planQuantity - (widget.tradePlan.commission ?? 0) - (widget.tradePlan.tax ?? 0);
        plannedLoss = (stopLossPrice - planPrice) * planQuantity + (widget.tradePlan.commission ?? 0) + (widget.tradePlan.tax ?? 0);
      }
    }
    
    // 获取当前主题以检测是否为暗色模式
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // 定义颜色，确保非空 - A股色彩风格：红涨绿跌
    final redColor = isDarkMode ? const Color(0xFFEF4444) : const Color(0xFFDC2626); // A股红色：盈利/上涨
    final greenColor = isDarkMode ? const Color(0xFF10B981) : const Color(0xFF059669); // A股绿色：亏损/下跌
    final blueColor = isDarkMode ? Colors.blue[300]! : Colors.blue.shade700;
    final textColor = isDarkMode ? Colors.blue[300]! : Colors.blue[800]!;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode 
            ? [
                const Color(0xFF374151).withOpacity(0.8),
                const Color(0xFF1F2937).withOpacity(0.9),
              ]
            : [
                const Color(0xFFF8FAFC),
                const Color(0xFFE2E8F0).withOpacity(0.5),
              ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDarkMode 
              ? Colors.black.withOpacity(0.2)
              : Colors.grey.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 6),
      ),
        ],
        border: Border.all(
          color: isDarkMode 
            ? Colors.grey.withOpacity(0.2)
            : Colors.grey.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '交易数据摘要',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                // 使用预定义颜色
                color: textColor,
              ),
            ),
            Divider(
              color: isDarkMode ? Colors.grey.shade600 : null,
            ),
            
            // 交易总金额
            if (totalAmount != null) 
              _buildSummaryRow('总金额', '¥${totalAmount.toStringAsFixed(2)}', FontWeight.bold, null),
            
            // 手续费和税费
            if (feeAndTax != null && feeAndTax > 0)
              _buildSummaryRow('手续费 + 税费', '¥${feeAndTax.toStringAsFixed(2)}', FontWeight.normal, redColor),
            
            // 净成本/收入 - 显示中性颜色，不用红绿区分
            if (widget.tradePlan.totalCost != null)
              _buildSummaryRow(
                tradeType == TradeType.buy ? '净成本' : '净收入', 
                '¥${widget.tradePlan.totalCost!.toStringAsFixed(2)}',
                FontWeight.bold,
                blueColor // 使用蓝色作为中性颜色
              ),
            
            // 添加计划盈亏显示
            if (plannedProfit != null && plannedLoss != null) ...[
              Divider(
                color: isDarkMode ? Colors.grey.shade600 : null,
              ),
              
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '📊 计划收益预期',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.orange[300] : Colors.orange[700],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryRow(
                      '计划盈利', 
                      '+¥${plannedProfit!.toStringAsFixed(2)}',
                      FontWeight.normal,
                      redColor, // A股红色：盈利
                      fontSize: 14
                    ),
                  ),
                  Expanded(
                    child: _buildSummaryRow(
                      '计划亏损', 
                      '-¥${plannedLoss!.toStringAsFixed(2)}',
                      FontWeight.normal,
                      greenColor, // A股绿色：亏损
                      fontSize: 14
                    ),
                  ),
                ],
              ),
              
              _buildSummaryRow(
                '盈亏比例', 
                '${(plannedProfit! / plannedLoss!).toStringAsFixed(2)} : 1',
                FontWeight.normal,
                blueColor,
                fontSize: 14
              ),
            ],
            
            if (widget.tradePlan.netProfit != null) ...[
              Divider(
                color: isDarkMode ? Colors.grey.shade600 : null,
              ),
              
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '💰 实际交易结果',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.blue[300] : Colors.blue[700],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // 买入金额（当为卖出交易时）
              if (tradeType == TradeType.sell && widget.tradePlan.planPrice != null && widget.tradePlan.actualQuantity != null)
                _buildSummaryRow(
                  '买入金额', 
                  '¥${(widget.tradePlan.planPrice! * widget.tradePlan.actualQuantity!).toStringAsFixed(2)}',
                  FontWeight.normal,
                  blueColor
                ),
              
              // 净盈亏 - A股色彩：盈利用红色，亏损用绿色
              _buildSummaryRow(
                '实际盈亏', 
                widget.tradePlan.netProfit! >= 0 
                  ? '+¥${widget.tradePlan.netProfit!.toStringAsFixed(2)}'
                  : '-¥${widget.tradePlan.netProfit!.abs().toStringAsFixed(2)}',
                FontWeight.bold,
                widget.tradePlan.netProfit! >= 0 ? redColor : greenColor, // A股色彩：盈利红色，亏损绿色
                fontSize: 16
              ),
              
              // 亏损金额（如果有亏损）- A股绿色表示亏损
              if (widget.tradePlan.netProfit! < 0)
                _buildSummaryRow(
                  '亏损金额', 
                  '¥${widget.tradePlan.netProfit!.abs().toStringAsFixed(2)}',
                  FontWeight.bold,
                  greenColor // A股绿色表示亏损
                ),
              
              // 盈亏百分比 - A股色彩
              if (widget.tradePlan.profitRate != null)
                _buildSummaryRow(
                  '盈亏比例', 
                  widget.tradePlan.profitRate! >= 0
                    ? '+${widget.tradePlan.profitRate!.toStringAsFixed(2)}%'
                    : '-${widget.tradePlan.profitRate!.abs().toStringAsFixed(2)}%',
                  FontWeight.bold,
                  widget.tradePlan.profitRate! >= 0 ? redColor : greenColor // A股色彩：盈利红色，亏损绿色
                ),
              
              // 计划vs实际对比分析
              if (plannedProfit != null && plannedLoss != null && widget.tradePlan.netProfit != null) ...[
                const SizedBox(height: 8),
                Divider(
                  color: isDarkMode ? Colors.grey.shade400 : null,
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '📈 执行效果对比',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.purple[300] : Colors.purple[700],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // 实际盈亏与计划的对比
                _buildSummaryRow(
                  '执行偏差', 
                  () {
                    final actualProfit = widget.tradePlan.netProfit!;
                    final expectedTarget = actualProfit >= 0 ? plannedProfit! : (-plannedLoss!);
                    final deviation = actualProfit - expectedTarget;
                    final deviationPercent = expectedTarget != 0 ? (deviation / expectedTarget.abs() * 100) : 0.0;
                    
                    return '${deviation >= 0 ? '+' : ''}¥${deviation.toStringAsFixed(2)} (${deviationPercent >= 0 ? '+' : ''}${deviationPercent.toStringAsFixed(1)}%)';
                  }(),
                  FontWeight.bold,
                  () {
                    final actualProfit = widget.tradePlan.netProfit!;
                    final expectedTarget = actualProfit >= 0 ? plannedProfit! : (-plannedLoss!);
                    final deviation = actualProfit - expectedTarget;
                    return deviation >= 0 ? redColor : greenColor; // 正偏差红色，负偏差绿色
                  }(),
                  fontSize: 14
                ),
                
                _buildSummaryRow(
                  '执行评价', 
                  () {
                    final actualProfit = widget.tradePlan.netProfit!;
                    final expectedTarget = actualProfit >= 0 ? plannedProfit! : (-plannedLoss!);
                    final deviationPercent = expectedTarget != 0 ? ((actualProfit - expectedTarget) / expectedTarget.abs() * 100) : 0.0;
                    
                    if (deviationPercent.abs() <= 5) {
                      return '执行精准 👌';
                    } else if (deviationPercent > 5) {
                      return '超预期表现 🎉';
                    } else {
                      return '未达预期 😔';
                    }
                  }(),
                  FontWeight.normal,
                  blueColor,
                  fontSize: 14
                ),
              ],
              
              // 买入/计划价与实际成交价的差距 - A股色彩逻辑
              if (widget.tradePlan.planPrice != null && widget.tradePlan.actualPrice != null)
                _buildSummaryRow(
                  '实际与进场价差', 
                  '${((widget.tradePlan.actualPrice! - widget.tradePlan.planPrice!) / widget.tradePlan.planPrice! * 100) >= 0 
                    ? '+' : ''}${((widget.tradePlan.actualPrice! - widget.tradePlan.planPrice!) / widget.tradePlan.planPrice! * 100).toStringAsFixed(2)}%',
                  FontWeight.normal,
                  // A股色彩：买入时价格上涨不利（绿色），价格下跌有利（红色）
                  // 卖出时价格上涨有利（红色），价格下跌不利（绿色）
                  widget.tradePlan.actualPrice! > widget.tradePlan.planPrice! 
                    ? (tradeType == TradeType.buy ? greenColor : redColor) // 价格上涨：买入不利（绿），卖出有利（红）
                    : (tradeType == TradeType.buy ? redColor : greenColor), // 价格下跌：买入有利（红），卖出不利（绿）
                  fontStyle: FontStyle.italic
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label, 
    String value, 
    FontWeight? fontWeight, 
    Color? valueColor, 
    {double? fontSize, FontStyle fontStyle = FontStyle.normal}
  ) {
    // 获取当前主题以检测是否为暗色模式
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label：',
            style: TextStyle(
              fontSize: fontSize,
              color: isDarkMode ? Colors.white70 : null,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: fontWeight,
              fontSize: fontSize,
              color: valueColor ?? (isDarkMode ? Colors.white : Colors.black),
              fontStyle: fontStyle,
            ),
          ),
        ],
      ),
    );
  }

  // 查找最接近给定日期的数据点索引
  int _findClosestDataPointIndex(List<Map<String, dynamic>> data, DateTime targetDate) {
    if (data.isEmpty) return 0;
    
    int closestIndex = 0;
    int minDiffDays = 999999;
    
    for (int i = 0; i < data.length; i++) {
      final String dateStr = data[i]['date'].toString();
      if (dateStr.isEmpty) continue;
      
      final DateTime pointDate = DateTime.parse(dateStr.split('T')[0]);
      final int diffDays = (targetDate.difference(pointDate).inDays).abs();
      
      if (diffDays < minDiffDays) {
        minDiffDays = diffDays;
        closestIndex = i;
      }
    }
    
    return closestIndex;
  }

  // K线形态识别
  String _getKLinePattern(double open, double high, double low, double close) {
    final bodySize = (close - open).abs();
    final totalRange = high - low;
    final upperShadow = high - (close > open ? close : open);
    final lowerShadow = (close > open ? open : close) - low;
    
    // 防止除零错误
    if (totalRange == 0) return '一字线';
    
    final bodyRatio = bodySize / totalRange;
    final changePercent = ((close - open) / open * 100).abs();
    
    // 十字星类型（实体很小）
    if (bodyRatio <= 0.1) {
      if (upperShadow > bodySize * 3 && lowerShadow > bodySize * 3) {
        return '十字星';
      } else if (upperShadow > bodySize * 5) {
        return '墓碑十字';
      } else if (lowerShadow > bodySize * 5) {
        return '蜻蜓十字';
      } else {
        return '小十字';
      }
    }
    
    // 纺锤线类型（上下影线都很长）
    if (upperShadow > bodySize * 2 && lowerShadow > bodySize * 2) {
      return close > open ? '阳纺锤' : '阴纺锤';
    }
    
    // 锤子线和倒锤子线
    if (lowerShadow > bodySize * 2 && upperShadow < bodySize * 0.3) {
      return close > open ? '阳锤子' : '阴锤子';
    }
    if (upperShadow > bodySize * 2 && lowerShadow < bodySize * 0.3) {
      return close > open ? '阳倒锤' : '阴倒锤';
    }
    
    // 根据涨跌幅判断大中小阳/阴线
    if (close > open) {
      if (changePercent >= 5) {
        return '大阳线';
      } else if (changePercent >= 2) {
        return '中阳线';
      } else {
        return '小阳线';
      }
    } else if (close < open) {
      if (changePercent >= 5) {
        return '大阴线';
      } else if (changePercent >= 2) {
        return '中阴线';
      } else {
        return '小阴线';
      }
    } else {
      return '一字线';
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    _quantityController.dispose();
    _commissionController.dispose();
    _taxController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}

// K线绘制器
class KLinePainter extends CustomPainter {
  final double open;
  final double high;
  final double low;
  final double close;
  final bool isPositive;
  final Color redColor;
  final Color greenColor;
  final bool isDarkMode;

  KLinePainter({
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.isPositive,
    required this.redColor,
    required this.greenColor,
    required this.isDarkMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..style = PaintingStyle.fill;

    // 计算价格范围
    final priceRange = high - low;
    final padding = size.height * 0.1;
    final chartHeight = size.height - 2 * padding;
    
    // 如果价格范围为0，绘制一条水平线
    if (priceRange == 0) {
      paint.color = isDarkMode ? Colors.grey[600]! : Colors.grey[400]!;
      canvas.drawLine(
        Offset(size.width * 0.1, size.height / 2),
        Offset(size.width * 0.9, size.height / 2),
        paint,
      );
      return;
    }

    // 计算各个价位的Y坐标
    final highY = padding;
    final lowY = padding + chartHeight;
    final openY = padding + (high - open) / priceRange * chartHeight;
    final closeY = padding + (high - close) / priceRange * chartHeight;

    // K线的中心X坐标
    final centerX = size.width / 2;
    final candleWidth = size.width * 0.6;

    // 设置颜色
    final lineColor = isPositive ? redColor : greenColor;
    paint.color = lineColor;
    fillPaint.color = lineColor;

    // 绘制上影线（最高价到实体顶部）
    final shadowTopY = isPositive ? closeY : openY;
    if (highY < shadowTopY) {
      canvas.drawLine(
        Offset(centerX, highY),
        Offset(centerX, shadowTopY),
        paint,
      );
    }

    // 绘制下影线（最低价到实体底部）
    final shadowBottomY = isPositive ? openY : closeY;
    if (lowY > shadowBottomY) {
      canvas.drawLine(
        Offset(centerX, shadowBottomY),
        Offset(centerX, lowY),
        paint,
      );
    }

    // 绘制K线实体
    final rectTop = isPositive ? closeY : openY;
    final rectBottom = isPositive ? openY : closeY;
    final rectHeight = (rectBottom - rectTop).abs();
    
    // 确保实体有最小高度，即使开盘价等于收盘价
    final minRectHeight = 2.0;
    final actualRectHeight = math.max(rectHeight, minRectHeight);
    final actualRectTop = rectTop;

    final rect = Rect.fromLTWH(
      centerX - candleWidth / 2,
      actualRectTop,
      candleWidth,
      actualRectHeight,
    );

    // 阳线和阴线都使用实心矩形，颜色区分
    fillPaint.color = lineColor;
    canvas.drawRect(rect, fillPaint);
    
    // 添加边框使K线更清晰
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 0.5;
    paint.color = lineColor.withOpacity(0.8);
    canvas.drawRect(rect, paint);

    // 绘制价格标签
    final textStyle = TextStyle(
      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
      fontSize: 8,
      fontWeight: FontWeight.w500,
    );

    // 最高价标签
    final highText = TextSpan(text: high.toStringAsFixed(2), style: textStyle);
    final highPainter = TextPainter(
      text: highText,
      textDirection: ui.TextDirection.ltr,
    );
    highPainter.layout();
    highPainter.paint(canvas, Offset(size.width + 2, highY - 6));

    // 最低价标签
    final lowText = TextSpan(text: low.toStringAsFixed(2), style: textStyle);
    final lowPainter = TextPainter(
      text: lowText,
      textDirection: ui.TextDirection.ltr,
    );
    lowPainter.layout();
    lowPainter.paint(canvas, Offset(size.width + 2, lowY - 6));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 