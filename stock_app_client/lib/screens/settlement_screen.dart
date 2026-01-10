import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/trade_record.dart';
import '../services/providers/trade_provider.dart';
import '../services/stock_service.dart';
import '../services/database_service.dart';
import '../widgets/settlement/stock_info_card.dart';
import '../widgets/settlement/transaction_summary.dart';
import '../widgets/settlement/trade_analysis_card.dart';
import '../widgets/celebration_overlay.dart';

/// 重构后的交易结算页面
/// 
/// 从 3744行 简化到 600行，使用组件化架构
/// - 使用 StockInfoCard 替换原有的 _buildTradePlanInfo()
/// - 使用 TransactionSummary 显示结算摘要
/// - 保留 K线图表和表单代码（待后续提取）
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
  final _commissionController = TextEditingController(text: '0.0');
  final _taxController = TextEditingController(text: '0.0');
  final _notesController = TextEditingController();

  List<Map<String, dynamic>> _kLineData = [];
  bool _isLoading = true;

  late DatabaseService _databaseService;

  @override
  void initState() {
    super.initState();
    _databaseService = Provider.of<DatabaseService>(context, listen: false);
    _loadKLineData();
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

  Future<void> _loadKLineData() async {
    setState(() {
      _isLoading = true;
      _kLineData = [];
    });
    
    try {
      final stockCode = widget.tradePlan.stockCode;
      final currentDate = DateTime.now();
      final endDate = currentDate.toIso8601String().split('T')[0].replaceAll('-', '');
      final startDate = DateTime(currentDate.year, currentDate.month, currentDate.day - 90)
          .toIso8601String().split('T')[0].replaceAll('-', '');
      
      final stockService = StockService(await _databaseService.database);
      final historyData = await stockService.getStockHistoryData(
        stockCode,
        startDate: startDate,
        endDate: endDate,
      );
      
      if (historyData.isNotEmpty) {
        final validData = historyData.where((data) {
          final high = data['high'] as double?;
          final low = data['low'] as double?;
          final close = data['close'] as double?;
          return high != null && high > 0 && 
                 low != null && low > 0 && 
                 close != null && close > 0;
        }).toList();
        
        if (mounted) {
          setState(() {
            _kLineData = List<Map<String, dynamic>>.from(validData);
            
            if (validData.isNotEmpty) {
                final lastPrice = validData.last['close'] as double? ?? 0.0;
                if (lastPrice > 0) {
                  _priceController.text = lastPrice.toStringAsFixed(2);
                } else {
                  _priceController.text = (widget.tradePlan.planPrice ?? 0.0).toStringAsFixed(2);
                }
                
                _quantityController.text = (widget.tradePlan.planQuantity ?? 0).toString();
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _priceController.text = (widget.tradePlan.planPrice ?? 0.0).toStringAsFixed(2);
          _quantityController.text = (widget.tradePlan.planQuantity ?? 0).toString();
        });
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
      backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('交易结算'),
        elevation: isDarkMode ? 0 : 0,
        backgroundColor: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ 使用组件：股票信息卡片
            StockInfoCard(tradePlan: widget.tradePlan),
            const SizedBox(height: 24),
            
            // ✅ 交易复盘分析卡片
            TradeAnalysisCard(tradePlan: widget.tradePlan),
            const SizedBox(height: 24),
            
            // K线图表（保留原有代码）
            _buildKLineChart(),
            const SizedBox(height: 24),
            
            // 结算表单（保留原有代码）
            _buildSettlementForm(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // K线图表构建方法（保留原有代码，待后续提取为组件）
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
                  const Color(0xFF2C2C2E),
                  const Color(0xFF1C1C1E),
                ]
              : [
                  Colors.white,
                  const Color(0xFFFAFAFA),
                ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isDarkMode 
                  ? Colors.black.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF3B82F6),
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
                  const Color(0xFF2C2C2E),
                  const Color(0xFF1C1C1E),
                ]
              : [
                  Colors.white,
                  const Color(0xFFFAFAFA),
                ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isDarkMode 
                  ? Colors.black.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: 0,
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
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
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
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _loadKLineData,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.refresh, size: 18, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            '重新加载',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // 简化的K线图表显示 - 现代化设计
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode 
            ? [
                const Color(0xFF2C2C2E),
                const Color(0xFF1C1C1E),
              ]
            : [
                Colors.white,
                const Color(0xFFFAFAFA),
              ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDarkMode 
                ? Colors.black.withOpacity(0.3)
                : Colors.grey.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 图表标题 - 现代化
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3B82F6).withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.candlestick_chart,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'K线走势图',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const Text(
                        'Price Chart',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF3B82F6).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${_kLineData.length}天',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3B82F6),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // K线图表（带价格标记线）
            SizedBox(
              height: 300,
              child: _buildPriceChart(isDarkMode),
            ),
            const SizedBox(height: 12),
            
            // 图例说明
            _buildChartLegend(isDarkMode),
          ],
        ),
      ),
    );
  }
  
  // 结算表单构建方法（现代化设计）
  Widget _buildSettlementForm() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode 
            ? [
                const Color(0xFF2C2C2E),
                const Color(0xFF1C1C1E),
              ]
            : [
                Colors.white,
                const Color(0xFFFAFAFA),
              ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDarkMode 
                ? Colors.black.withOpacity(0.3)
                : Colors.grey.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
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
              // 标题部分 - 现代化
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.receipt_long,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '交易结算',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                        const Text(
                          'Settlement Information',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // ✅ 如果已结算，显示交易摘要组件
              if (widget.tradePlan.actualPrice != null && widget.tradePlan.actualQuantity != null)
                Column(
                  children: [
                    TransactionSummary(tradePlan: widget.tradePlan),
                    const SizedBox(height: 24),
                  ],
                ),
              
              // 出场价格和数量 - 双列布局
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildModernTextField(
                      controller: _priceController,
                      label: '出场价格',
                      hint: '输入价格',
                      icon: Icons.monetization_on,
                      iconColor: const Color(0xFF3B82F6),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) return '请输入价格';
                        if (double.tryParse(value) == null) return '价格无效';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildModernTextField(
                      controller: _quantityController,
                      label: '出场数量',
                      hint: '输入数量',
                      icon: Icons.layers,
                      iconColor: const Color(0xFF3B82F6),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) return '请输入数量';
                        if (int.tryParse(value) == null) return '数量无效';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // 佣金和税费 - 双列布局
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildModernTextField(
                      controller: _commissionController,
                      label: '佣金',
                      hint: '输入佣金',
                      icon: Icons.account_balance_wallet,
                      iconColor: const Color(0xFF64748B),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildModernTextField(
                      controller: _taxController,
                      label: '税费',
                      hint: '输入税费',
                      icon: Icons.receipt,
                      iconColor: const Color(0xFF64748B),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // 备注
              _buildModernTextField(
                controller: _notesController,
                label: '备注',
                hint: '请输入备注信息',
                icon: Icons.note_alt,
                iconColor: const Color(0xFF64748B),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              
              // 提交按钮 - 现代化设计
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _handleSubmit,
                    child: const Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            color: Colors.white,
                            size: 24,
                          ),
                          SizedBox(width: 8),
                          Text(
                            '确认结算',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 现代化输入框
  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color iconColor,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                icon,
                size: 16,
                color: iconColor,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
              fontSize: 14,
            ),
            filled: true,
            fillColor: isDarkMode 
                ? Colors.grey[850]?.withOpacity(0.3)
                : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDarkMode ? Colors.grey[700]! : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDarkMode ? Colors.grey[700]! : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: iconColor,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFEF4444),
                width: 1,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFEF4444),
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            errorStyle: const TextStyle(
              fontSize: 11,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }

  // 构建带价格标记的图表
  Widget _buildPriceChart(bool isDarkMode) {
    // 计算价格范围
    final prices = _kLineData.map((data) => data['close'] as double).toList();
    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);
    
    // 扩展Y轴范围以容纳所有价格线
    var minY = minPrice * 0.95;
    var maxY = maxPrice * 1.05;
    
    final planPrice = widget.tradePlan.planPrice ?? 0.0;
    final stopLossPrice = widget.tradePlan.stopLossPrice ?? 0.0;
    final takeProfitPrice = widget.tradePlan.takeProfitPrice ?? 0.0;
    final actualPrice = widget.tradePlan.actualPrice;
    
    // 调整Y轴范围以包含所有价格线
    if (planPrice > 0) {
      if (planPrice < minY) minY = planPrice * 0.95;
      if (planPrice > maxY) maxY = planPrice * 1.05;
    }
    if (stopLossPrice > 0) {
      if (stopLossPrice < minY) minY = stopLossPrice * 0.95;
      if (stopLossPrice > maxY) maxY = stopLossPrice * 1.05;
    }
    if (takeProfitPrice > 0) {
      if (takeProfitPrice < minY) minY = takeProfitPrice * 0.95;
      if (takeProfitPrice > maxY) maxY = takeProfitPrice * 1.05;
    }
    if (actualPrice != null && actualPrice > 0) {
      if (actualPrice < minY) minY = actualPrice * 0.95;
      if (actualPrice > maxY) maxY = actualPrice * 1.05;
    }
    
    // A股配色
    final redColor = isDarkMode ? const Color(0xFFEF4444) : const Color(0xFFDC2626);
    final greenColor = isDarkMode ? const Color(0xFF10B981) : const Color(0xFF059669);
    
    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        minX: 0,
        maxX: (_kLineData.length - 1).toDouble(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
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
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    value.toStringAsFixed(2),
                    style: TextStyle(
                      fontSize: 10,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(
          show: true,
        border: Border.all(
            color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
          width: 1,
        ),
      ),
        lineBarsData: [
          // 收盘价折线
          LineChartBarData(
            spots: _kLineData.asMap().entries.map((entry) {
              final close = entry.value['close'] as double? ?? 0.0;
              return FlSpot(entry.key.toDouble(), close);
            }).toList(),
            isCurved: true,
            color: isDarkMode ? Colors.blue[400] : Colors.blue[600],
            barWidth: 2.5,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  (isDarkMode ? Colors.blue[400]! : Colors.blue[600]!).withOpacity(0.2),
                  (isDarkMode ? Colors.blue[400]! : Colors.blue[600]!).withOpacity(0.05),
                ],
              ),
            ),
          ),
        ],
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            // 进场价格线（计划价格）
            if (planPrice > 0)
              HorizontalLine(
                y: planPrice,
                color: isDarkMode ? Colors.grey[500]! : Colors.grey[700]!,
                strokeWidth: 2,
                dashArray: [8, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  padding: const EdgeInsets.only(right: 8, bottom: 4),
              style: TextStyle(
                    color: isDarkMode ? Colors.grey[300] : Colors.grey[800],
                fontWeight: FontWeight.bold,
                    fontSize: 11,
                    backgroundColor: isDarkMode 
                      ? Colors.grey[800]!.withOpacity(0.8)
                      : Colors.white.withOpacity(0.8),
                  ),
                  labelResolver: (line) => ' 进场 ${planPrice.toStringAsFixed(2)} ',
                ),
              ),
            
            // 止损价格线
            if (stopLossPrice > 0)
              HorizontalLine(
                y: stopLossPrice,
                color: greenColor,
                strokeWidth: 2,
                dashArray: [4, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  padding: const EdgeInsets.only(right: 8, bottom: 4),
                  style: TextStyle(
                    color: greenColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    backgroundColor: isDarkMode 
                      ? Colors.black.withOpacity(0.6)
                      : Colors.white.withOpacity(0.8),
                  ),
                  labelResolver: (line) => ' 止损 ${stopLossPrice.toStringAsFixed(2)} ',
                ),
              ),
            
            // 止盈价格线
            if (takeProfitPrice > 0)
              HorizontalLine(
                y: takeProfitPrice,
                color: redColor,
                strokeWidth: 2,
                dashArray: [4, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  padding: const EdgeInsets.only(right: 8, bottom: 4),
                      style: TextStyle(
                    color: redColor,
                        fontWeight: FontWeight.bold,
                    fontSize: 11,
                    backgroundColor: isDarkMode 
                      ? Colors.black.withOpacity(0.6)
                      : Colors.white.withOpacity(0.8),
                  ),
                  labelResolver: (line) => ' 止盈 ${takeProfitPrice.toStringAsFixed(2)} ',
                ),
              ),
            
            // 实际成交价格线
            if (actualPrice != null && actualPrice > 0)
              HorizontalLine(
                y: actualPrice,
                color: isDarkMode ? Colors.orange[400]! : Colors.orange[600]!,
                strokeWidth: 2.5,
                dashArray: [6, 3],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topLeft,
                  padding: const EdgeInsets.only(left: 8, bottom: 4),
                  style: TextStyle(
                    color: isDarkMode ? Colors.orange[300] : Colors.orange[800],
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    backgroundColor: isDarkMode 
                      ? Colors.black.withOpacity(0.6)
                      : Colors.white.withOpacity(0.8),
                  ),
                  labelResolver: (line) => ' 实际 ${actualPrice.toStringAsFixed(2)} ',
                    ),
                  ),
                ],
              ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: isDarkMode 
              ? Colors.grey[800]!.withOpacity(0.9) 
              : Colors.blueGrey.withOpacity(0.9),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.spotIndex;
                if (index >= 0 && index < _kLineData.length) {
                  final data = _kLineData[index];
                  final dateStr = data['date']?.toString().split('T')[0] ?? '';
                  final close = data['close'] as double? ?? 0.0;
                  
                  return LineTooltipItem(
                    '$dateStr\n收盘: ${close.toStringAsFixed(2)}',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                }
                return null;
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  // 构建图例说明
  Widget _buildChartLegend(bool isDarkMode) {
    final redColor = isDarkMode ? const Color(0xFFEF4444) : const Color(0xFFDC2626);
    final greenColor = isDarkMode ? const Color(0xFF10B981) : const Color(0xFF059669);
    
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      alignment: WrapAlignment.center,
                children: [
        _buildLegendItem(
          '收盘价',
          isDarkMode ? Colors.blue[400]! : Colors.blue[600]!,
          isDarkMode,
          isSolid: true,
        ),
        if (widget.tradePlan.planPrice != null && widget.tradePlan.planPrice! > 0)
          _buildLegendItem(
            '进场价 ${widget.tradePlan.planPrice!.toStringAsFixed(2)}',
            isDarkMode ? Colors.grey[500]! : Colors.grey[700]!,
            isDarkMode,
          ),
        if (widget.tradePlan.stopLossPrice != null && widget.tradePlan.stopLossPrice! > 0)
          _buildLegendItem(
            '止损 ${widget.tradePlan.stopLossPrice!.toStringAsFixed(2)}',
            greenColor,
            isDarkMode,
          ),
        if (widget.tradePlan.takeProfitPrice != null && widget.tradePlan.takeProfitPrice! > 0)
          _buildLegendItem(
            '止盈 ${widget.tradePlan.takeProfitPrice!.toStringAsFixed(2)}',
            redColor,
            isDarkMode,
          ),
        if (widget.tradePlan.actualPrice != null && widget.tradePlan.actualPrice! > 0)
          _buildLegendItem(
            '实际 ${widget.tradePlan.actualPrice!.toStringAsFixed(2)}',
            isDarkMode ? Colors.orange[400]! : Colors.orange[600]!,
            isDarkMode,
          ),
      ],
    );
  }

  // 构建单个图例项
  Widget _buildLegendItem(String label, Color color, bool isDarkMode, {bool isSolid = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: isSolid ? 3 : 2,
          decoration: BoxDecoration(
            color: isSolid ? color : null,
            border: isSolid ? null : Border(
              top: BorderSide(
                color: color,
                width: 2,
                style: BorderStyle.solid,
              ),
            ),
          ),
          child: isSolid ? null : CustomPaint(
            painter: DashedLinePainter(color: color),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
                        style: TextStyle(
            fontSize: 11,
            color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
            fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      final actualPrice = double.parse(_priceController.text);
      final actualQuantity = int.parse(_quantityController.text);
      final commission = double.tryParse(_commissionController.text) ?? 0.0;
      final tax = double.tryParse(_taxController.text) ?? 0.0;
      final notes = _notesController.text;

      // 计算净盈亏
      // A股交易逻辑：买入后卖出
      // 进场金额 = 计划价格（买入价）× 数量
      // 出场金额 = 实际价格（卖出价）× 数量
      // 净盈亏 = 出场金额 - 进场金额 - 手续费
      final planAmount = (widget.tradePlan.planPrice ?? 0.0) * (widget.tradePlan.planQuantity ?? actualQuantity);  // 进场金额（买入成本）
      final actualAmount = actualPrice * actualQuantity;  // 出场金额（卖出收入）
      final totalFees = commission + tax;
      
      // A股只能做多：买入→持有→卖出
      // 盈亏 = 卖出收入 - 买入成本 - 手续费
      final netProfit = actualAmount - planAmount - totalFees;

      // 更新交易记录
      final updatedRecord = TradeRecord(
        id: widget.tradePlan.id,
        stockCode: widget.tradePlan.stockCode,
        stockName: widget.tradePlan.stockName,
        tradeType: widget.tradePlan.tradeType,
        category: TradeCategory.settlement, // 结算后改为交割单分类
        status: TradeStatus.completed,
        tradeDate: widget.tradePlan.tradeDate,
        planPrice: widget.tradePlan.planPrice,
        planQuantity: widget.tradePlan.planQuantity,
        actualPrice: actualPrice,
        actualQuantity: actualQuantity,
        stopLossPrice: widget.tradePlan.stopLossPrice,
        takeProfitPrice: widget.tradePlan.takeProfitPrice,
        commission: commission,
        tax: tax,
        netProfit: netProfit,
        marketPhase: widget.tradePlan.marketPhase,
        strategy: widget.tradePlan.strategy,
        reason: widget.tradePlan.reason,
        notes: notes,
        entryDifficulty: widget.tradePlan.entryDifficulty,
        positionBuildingMethod: widget.tradePlan.positionBuildingMethod,
        priceTriggerType: widget.tradePlan.priceTriggerType,
        createTime: widget.tradePlan.createTime,
        updateTime: DateTime.now(),
      );

      final tradeProvider = Provider.of<TradeProvider>(context, listen: false);
      await tradeProvider.updateTradeRecord(updatedRecord);

      if (mounted) {
        Navigator.pop(context);
        
        // 🎉 盈利时触发庆祝动画
        if (netProfit > 0) {
          // 计算收益率
          final profitPercent = planAmount > 0 ? (netProfit / planAmount) * 100 : 0.0;
          
          // 延迟一小会让页面切换完成
          Future.delayed(const Duration(milliseconds: 300), () {
            CelebrationService.checkAndCelebrate(
              profitAmount: netProfit,
              profitPercent: profitPercent,
            );
          });
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
        children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '结算成功',
            style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
            ),
          ),
          Text(
                        netProfit >= 0 
                          ? '盈利 ¥${netProfit.toStringAsFixed(2)}，已移至交割单'
                          : '亏损 ¥${netProfit.abs().toStringAsFixed(2)}，已移至交割单',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
            ),
          ),
        ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
      ),
    );
  }
      } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('结算失败: $e'),
            backgroundColor: Colors.red,
      ),
    );
  }
    }
  }
}

// 虚线绘制器
class DashedLinePainter extends CustomPainter {
  final Color color;

  DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const dashWidth = 4.0;
    const dashSpace = 3.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX + dashWidth, 0),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
} 
