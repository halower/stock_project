import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:ui' as ui;
import '../models/replay_training_session.dart';
import '../utils/technical_indicator_calculator.dart';

class StockKLineChart extends StatelessWidget {
  final dynamic data;
  final bool showVolume;
  final List<TechnicalIndicator>? indicators; // 技术指标列表
  final List<ReplayTrade>? trades; // 交易记录列表
  final String? subChartIndicator; // 附图指标类型 (MACD/RSI/KDJ)
  
  const StockKLineChart({
    super.key, 
    required this.data,
    this.showVolume = true,
    this.indicators,
    this.trades,
    this.subChartIndicator,
  });

  @override
  Widget build(BuildContext context) {
    // 处理数据
    final List<CandleData> candleData = _processData();
    
    if (candleData.isEmpty) {
      return const Center(
        child: Text('暂无历史数据'),
      );
    }
    
    // 计算最大最小值用于Y轴
    final minY = candleData.map((e) => e.low).reduce((a, b) => a < b ? a : b) * 0.98;
    final maxY = candleData.map((e) => e.high).reduce((a, b) => a > b ? a : b) * 1.02;
    
    // 计算技术指标
    final indicatorData = _calculateIndicators(candleData);
    
    // 计算附图指标数据
    final subChartData = _calculateSubChartIndicator(candleData);
    
    return Column(
      children: [
        // 真正的K线蜡烛图 + 技术指标
        Expanded(
          flex: 4, // 增加K线图的比例
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: CandlestickChartPainter(
                    candleData: candleData,
                    minY: minY,
                    maxY: maxY,
                    isDark: Theme.of(context).brightness == Brightness.dark,
                    indicators: indicatorData,
                    trades: trades, // 传递交易记录
                          ),
                        );
                      },
                    ),
                  ),
        ),
        
        // 日期轴
        if (candleData.isNotEmpty)
          Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDate(candleData.first.date),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                if (candleData.length > 2)
                  Text(
                    _formatDate(candleData[candleData.length ~/ 2].date),
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                Text(
                  _formatDate(candleData.last.date),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
        
        // 成交量图表
        if (showVolume && candleData.any((data) => data.volume > 0)) 
          _buildVolumeChart(candleData),
        
        // 附图指标（MACD/RSI/KDJ）
        if (subChartData != null)
          _buildSubChart(candleData, subChartData, context),
      ],
    );
  }

  // 格式化日期
  String _formatDate(String date) {
    if (date.length >= 8) {
      return '${date.substring(4, 6)}-${date.substring(6, 8)}';
    }
    return date;
  }

  // 构建成交量图表 - 优化版
  Widget _buildVolumeChart(List<CandleData> candleData) {
    // 计算最大成交量用于Y轴缩放
    final maxVolume = candleData.map((e) => e.volume).reduce((a, b) => a > b ? a : b) * 1.1;
    
    if (maxVolume <= 0) {
      return const SizedBox(height: 80, child: Center(child: Text('无成交量数据', style: TextStyle(fontSize: 10, color: Colors.grey))));
    }
    
    // 根据数据量动态计算柱状图宽度
    final dataCount = candleData.length;
    double barWidth;
    if (dataCount <= 30) {
      barWidth = 8.0;
    } else if (dataCount <= 60) {
      barWidth = 5.0;
    } else if (dataCount <= 90) {
      barWidth = 3.5;
    } else {
      barWidth = 2.5;
    }
    
    return SizedBox(
      height: 80, // 减小高度，让K线图更大
      child: Padding(
        padding: const EdgeInsets.only(left: 8.0, right: 8.0, top: 4.0),
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceEvenly,
            maxY: maxVolume,
            minY: 0,
            barTouchData: BarTouchData(enabled: false),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  interval: maxVolume / 2, // 只显示2个刻度
                  getTitlesWidget: (value, meta) {
                    // 只在最大值和中间值显示
                    if (value == 0) return const SizedBox.shrink();
                    
                    if (value >= 100000000) {
                      return Text(
                        '${(value / 100000000).toStringAsFixed(1)}亿',
                        style: const TextStyle(fontSize: 9, color: Colors.grey),
                      );
                    } else if (value >= 10000) {
                      return Text(
                        '${(value / 10000).toStringAsFixed(0)}万',
                        style: const TextStyle(fontSize: 9, color: Colors.grey),
                      );
                    }
                    return Text(
                      value.toStringAsFixed(0),
                      style: const TextStyle(fontSize: 9, color: Colors.grey),
                    );
                  },
                ),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            borderData: FlBorderData(show: false),
            barGroups: List.generate(
              candleData.length,
              (i) => BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: candleData[i].volume,
                    color: candleData[i].close >= candleData[i].open
                        ? Colors.red.withOpacity(0.7)
                        : Colors.green.withOpacity(0.7),
                    width: barWidth,
                    borderRadius: BorderRadius.circular(barWidth / 4),
                  ),
                ],
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: maxVolume / 2,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: Colors.grey.withOpacity(0.1),
                  strokeWidth: 1,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // 处理原始数据为图表所需格式
  List<CandleData> _processData() {
    final List<CandleData> result = [];
    
    // 获取历史数据
    List<Map<String, dynamic>> historyData = [];
    
    if (data == null) {
      debugPrint('K线图数据为空');
      return result;
    }
    
    debugPrint('原始数据类型: ${data.runtimeType}');
    if (data is Map<String, dynamic>) {
      debugPrint('数据包含的键: ${data.keys.join(", ")}');
    }
    
    // 处理新API格式，数据在data字段中（不是history字段）
    if (data is Map<String, dynamic> && data.containsKey('data')) {
      debugPrint('检测到data字段，包含历史数据');
      var historyList = data['data'];
      if (historyList is List) {
        debugPrint('历史数据条数: ${historyList.length}');
        // 根据数据量动态调整显示条数，让K线更紧凑
        final int displayCount;
        if (historyList.length > 120) {
          displayCount = 120; // 最多显示120条，让K线更密集
        } else if (historyList.length > 90) {
          displayCount = 90;
        } else if (historyList.length > 60) {
          displayCount = 60;
        } else {
          displayCount = historyList.length;
        }
        final limitedList = historyList.length > displayCount 
            ? historyList.sublist(historyList.length - displayCount) 
            : historyList;
        debugPrint('使用的历史数据条数: ${limitedList.length}');
        
        for (var item in limitedList) {
          if (item is Map<String, dynamic>) {
            historyData.add(item);
          }
        }
      }
    } 
    // 处理直接传入历史数据数组的情况
    else if (data is List) {
      debugPrint('直接传入历史数据数组');
      // 根据数据量动态调整显示条数
      final int displayCount;
      if (data.length > 120) {
        displayCount = 120;
      } else if (data.length > 90) {
        displayCount = 90;
      } else if (data.length > 60) {
        displayCount = 60;
      } else {
        displayCount = data.length;
      }
      final limitedList = data.length > displayCount ? data.sublist(data.length - displayCount) : data;
      for (var item in limitedList) {
        if (item is Map<String, dynamic>) {
          historyData.add(item);
        }
      }
    }
    
    // 如果历史数据为空，直接返回
    if (historyData.isEmpty) {
      debugPrint('处理后历史数据为空');
      return result;
    }
    
    // 打印第一条和最后一条数据用于调试
    if (historyData.isNotEmpty) {
      debugPrint('第一条历史数据: ${historyData.first}');
      debugPrint('最后一条历史数据: ${historyData.last}');
    }
    
    // 按日期排序（从旧到新）
    historyData.sort((a, b) {
      var dateA = a['trade_date']?.toString() ?? '';
      var dateB = b['trade_date']?.toString() ?? '';
      return dateA.compareTo(dateB);
    });
    
    // 转换为蜡烛图数据
    for (var item in historyData) {
      try {
        String? date;
        double? open;
        double? close;
        double? high;
        double? low;
        double? volume;
        
        // 检查新API格式
        if (item.containsKey('trade_date')) {
          date = item['trade_date'].toString();
          open = _parseDouble(item['open']);
          close = _parseDouble(item['close']);
          high = _parseDouble(item['high']);
          low = _parseDouble(item['low']);
          // 尝试多个可能的成交量字段名
          volume = _parseDouble(item['vol']) ?? 
                   _parseDouble(item['volume']) ?? 
                   _parseDouble(item['成交量']) ?? 
                   0.0;
        } 
        // 检查旧API格式
        else if (item.containsKey('日期')) {
          date = item['日期'].toString();
          open = _parseDouble(item['开盘']);
          close = _parseDouble(item['收盘']);
          high = _parseDouble(item['最高']);
          low = _parseDouble(item['最低']);
          volume = _parseDouble(item['成交量']);
        }
        
        // 确保所有必要数据都存在
        if (date != null && open != null && close != null && high != null && low != null) {
          final volumeValue = volume ?? 0.0;
          result.add(CandleData(
            date: date,
            open: open,
            high: high,
            low: low,
            close: close,
            volume: volumeValue,
          ));
          // 调试：打印前几条数据的成交量
          if (result.length <= 3) {
            debugPrint('K线数据 ${result.length}: date=$date, volume=$volumeValue');
          }
        } else {
          debugPrint('数据不完整，跳过: date=$date, open=$open, close=$close, high=$high, low=$low');
        }
      } catch (e) {
        debugPrint('处理K线数据出错: $e');
      }
    }
    
    // 最终处理结果
    debugPrint('处理后的数据条数: ${result.length}');
    if (result.length >= 2) {
      debugPrint('最终日期范围: ${result.first.date} 到 ${result.last.date}');
    }
    
    return result;
  }
  
  // 解析数值，处理各种可能的数值格式
  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
  
  // 计算技术指标
  Map<String, dynamic> _calculateIndicators(List<CandleData> candleData) {
    Map<String, dynamic> result = {};
    
    if (indicators == null || indicators!.isEmpty) {
      debugPrint('📊 指标列表为空');
      return result;
    }
    
    debugPrint('📊 开始计算指标，共 ${indicators!.length} 个');
    
    final closes = candleData.map((c) => c.close).toList();
    // final highs = candleData.map((c) => c.high).toList();
    // final lows = candleData.map((c) => c.low).toList();
    
    for (var indicator in indicators!) {
      debugPrint('📊 指标: ${indicator.name}, 类型: ${indicator.type}, 启用: ${indicator.enabled}');
      if (!indicator.enabled) continue;
      
      switch (indicator.type) {
        case 'MA':
          final period = indicator.params['period'] as int;
          final ma = TechnicalIndicatorCalculator.calculateMA(closes, period);
          final key = 'MA$period';
          result[key] = {
            'data': ma.values,
            'color': _getColorFromString(indicator.params['color'] as String),
            'name': indicator.name,
          };
          debugPrint('✅ 添加MA指标: $key, 数据点数: ${ma.values.length}');
          break;
          
        case 'EMA':
          final period = indicator.params['period'] as int;
          final ema = TechnicalIndicatorCalculator.calculateEMA(closes, period);
          final key = 'EMA$period';
          result[key] = {
            'data': ema,
            'color': _getColorFromString(indicator.params['color'] as String),
            'name': indicator.name,
          };
          debugPrint('✅ 添加EMA指标: $key, 数据点数: ${ema.length}');
          break;
          
        case 'MACD':
          // MACD在副图显示，暂不处理
          break;
          
        case 'RSI':
          // RSI在副图显示，暂不处理
          break;
          
        case 'BOLL':
          final period = indicator.params['period'] as int;
          final std = (indicator.params['std'] as int).toDouble();
          final boll = TechnicalIndicatorCalculator.calculateBOLL(
            closes,
            period: period,
            stdDev: std,
          );
          result['BOLL'] = {
            'upper': boll.upper,
            'middle': boll.middle,
            'lower': boll.lower,
          };
          break;
          
        case 'KDJ':
          // KDJ在副图显示，暂不处理
          break;
      }
    }
    
    return result;
  }
  
  // 从字符串获取颜色
  Color _getColorFromString(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'white':
        return Colors.white;
      case 'yellow':
        return Colors.yellow;
      case 'purple':
        return Colors.purple;
      case 'green':
        return Colors.green;
      case 'blue':
        return Colors.blue;
      case 'orange':
        return Colors.orange;
      case 'cyan':
        return Colors.cyan;
      case 'red':
        return Colors.red;
      default:
        return Colors.white;
    }
  }
  
  // 计算附图指标数据
  Map<String, dynamic>? _calculateSubChartIndicator(List<CandleData> candleData) {
    if (subChartIndicator == null || indicators == null) return null;
    
    final closes = candleData.map((c) => c.close).toList();
    final highs = candleData.map((c) => c.high).toList();
    final lows = candleData.map((c) => c.low).toList();
    
    // 通过指标名称查找对应的指标配置（更安全的方式）
    TechnicalIndicator? indicator;
    for (var i in indicators!) {
      if (i.type == subChartIndicator) {
        indicator = i;
        break;
      }
    }
    
    // 如果没找到对应的指标配置，使用默认参数
    if (indicator == null) {
      // 为MACD、RSI、KDJ提供默认参数
      switch (subChartIndicator) {
        case 'MACD':
          indicator = TechnicalIndicator(
            name: 'MACD',
            type: 'MACD',
            params: {'fast': 12, 'slow': 26, 'signal': 9},
            enabled: true,
          );
          break;
        case 'RSI':
          indicator = TechnicalIndicator(
            name: 'RSI',
            type: 'RSI',
            params: {'period': 14},
            enabled: true,
          );
          break;
        case 'KDJ':
          indicator = TechnicalIndicator(
            name: 'KDJ',
            type: 'KDJ',
            params: {'n': 9, 'k': 3, 'd': 3},
            enabled: true,
          );
          break;
        default:
          return null;
      }
    }
    
    if (!indicator.enabled) return null;
    
    switch (subChartIndicator) {
      case 'MACD':
        final macdResult = TechnicalIndicatorCalculator.calculateMACD(closes);
        return {
          'type': 'MACD',
          'dif': macdResult.dif,
          'dea': macdResult.dea,
          'macd': macdResult.macd,
        };
        
      case 'RSI':
        final period = indicator.params['period'] as int? ?? 14;
        final rsi = TechnicalIndicatorCalculator.calculateRSI(closes, period: period);
        return {
          'type': 'RSI',
          'values': rsi,
          'period': period,
        };
        
      case 'KDJ':
        final kdjResult = TechnicalIndicatorCalculator.calculateKDJ(closes, highs, lows);
        return {
          'type': 'KDJ',
          'k': kdjResult.k,
          'd': kdjResult.d,
          'j': kdjResult.j,
        };
        
      default:
        return null;
    }
  }
  
  // 构建附图
  Widget _buildSubChart(List<CandleData> candleData, Map<String, dynamic> data, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      height: 100,
      padding: const EdgeInsets.all(8.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: SubChartPainter(
              candleData: candleData,
              indicatorData: data,
              isDark: isDark,
            ),
          );
        },
      ),
    );
  }
}

// 蜡烛图数据模型
class CandleData {
  final String date;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;
  
  CandleData({
    required this.date,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });
} 

// 蜡烛图绘制器
class CandlestickChartPainter extends CustomPainter {
  final List<CandleData> candleData;
  final double minY;
  final double maxY;
  final bool isDark;
  final Map<String, dynamic> indicators; // 技术指标数据
  final List<ReplayTrade>? trades; // 交易记录
  
  CandlestickChartPainter({
    required this.candleData,
    required this.minY,
    required this.maxY,
    this.isDark = false,
    this.indicators = const {},
    this.trades,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (candleData.isEmpty) return;
    
    final double chartWidth = size.width;
    final double chartHeight = size.height;
    // 优化K线宽度：根据数据量动态调整，让K线更紧凑
    final double candleSpacing = chartWidth / candleData.length;
    final double candleWidth = (candleSpacing * 0.8).clamp(1.5, 12.0); // 限制最小1.5px，最大12px
    
    // 绘制网格线
    _drawGrid(canvas, size);
    
    // 绘制价格标签
    _drawPriceLabels(canvas, size);
    
    // 绘制技术指标线（在蜡烛之前绘制，作为背景）
    _drawIndicators(canvas, size);
    
    // 绘制每根蜡烛
    for (int i = 0; i < candleData.length; i++) {
      final candle = candleData[i];
      final x = i * candleSpacing + candleSpacing / 2;
      
      // 计算Y坐标（价格映射到画布高度）
      final openY = _priceToY(candle.open, chartHeight);
      final closeY = _priceToY(candle.close, chartHeight);
      final highY = _priceToY(candle.high, chartHeight);
      final lowY = _priceToY(candle.low, chartHeight);
      
      // 判断涨跌
      final bool isRising = candle.close >= candle.open;
      final color = isRising ? Colors.red : Colors.green;
      
      // 绘制上下影线
      final linePaint = Paint()
        ..color = color
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;
      
      canvas.drawLine(
        Offset(x, highY),
        Offset(x, lowY),
        linePaint,
      );
      
      // 绘制实体
      final bodyPaint = Paint()
        ..color = color
        ..style = isRising ? PaintingStyle.stroke : PaintingStyle.fill
        ..strokeWidth = 1;
      
      final bodyTop = openY < closeY ? openY : closeY;
      final bodyBottom = openY > closeY ? openY : closeY;
      final bodyHeight = (bodyBottom - bodyTop).abs();
      
      // 如果开盘价等于收盘价，画一条横线
      if (bodyHeight < 1) {
        canvas.drawLine(
          Offset(x - candleWidth / 2, openY),
          Offset(x + candleWidth / 2, openY),
          linePaint,
        );
      } else {
        canvas.drawRect(
          Rect.fromLTWH(
            x - candleWidth / 2,
            bodyTop,
            candleWidth,
            bodyHeight,
          ),
          bodyPaint,
        );
      }
    }
    
    // 绘制交易标记（在蜡烛之后绘制，覆盖在上层）
    _drawTradeMarkers(canvas, size);
  }
  
  // 绘制网格线
  void _drawGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.1)
      ..strokeWidth = 0.5;
    
    // 绘制水平网格线（5条）
    for (int i = 0; i <= 5; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }
    
    // 绘制垂直网格线
    final verticalLines = 5;
    for (int i = 0; i <= verticalLines; i++) {
      final x = size.width * i / verticalLines;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        gridPaint,
      );
    }
  }
  
  // 绘制价格标签
  void _drawPriceLabels(Canvas canvas, Size size) {
    final textStyle = TextStyle(
      color: isDark ? Colors.white70 : Colors.black54,
      fontSize: 10,
    );
    
    // 绘制5个价格标签
    for (int i = 0; i <= 5; i++) {
      final price = minY + (maxY - minY) * i / 5;
      final y = size.height * (1 - i / 5);
      
      final textSpan = TextSpan(
        text: price.toStringAsFixed(2),
        style: textStyle,
      );
      
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: ui.TextDirection.ltr,
      );
      
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(size.width - textPainter.width - 4, y - textPainter.height / 2),
      );
    }
  }
  
  // 将价格转换为Y坐标
  double _priceToY(double price, double chartHeight) {
    final ratio = (price - minY) / (maxY - minY);
    return chartHeight * (1 - ratio);
  }
  
  // 绘制技术指标
  void _drawIndicators(Canvas canvas, Size size) {
    if (indicators.isEmpty) {
      debugPrint('📊 绘制指标: 指标数据为空');
      return;
    }
    
    debugPrint('📊 开始绘制指标，共 ${indicators.length} 个: ${indicators.keys.join(", ")}');
    
    final chartWidth = size.width;
    // final chartHeight = size.height;
    final candleSpacing = chartWidth / candleData.length;
    
    // 绘制均线指标
    indicators.forEach((key, value) {
      if (key.startsWith('MA') || key.startsWith('EMA')) {
        final data = value['data'] as List<double>;
        final color = value['color'] as Color;
        debugPrint('📊 绘制均线: $key, 颜色: $color, 数据点: ${data.length}');
        _drawMALine(canvas, size, data, color, candleSpacing);
      } else if (key == 'BOLL') {
        // 绘制布林带
        final upper = value['upper'] as List<double>;
        final middle = value['middle'] as List<double>;
        final lower = value['lower'] as List<double>;
        debugPrint('📊 绘制BOLL带');
        _drawBOLL(canvas, size, upper, middle, lower, candleSpacing);
      }
    });
  }
  
  // 绘制均线（MA/EMA）
  void _drawMALine(Canvas canvas, Size size, List<double> data, Color color, double candleSpacing) {
    final path = Path();
    bool isFirst = true;
    
    for (int i = 0; i < data.length && i < candleData.length; i++) {
      if (data[i].isNaN) continue;
      
      final x = i * candleSpacing + candleSpacing / 2;
      final y = _priceToY(data[i], size.height);
      
      if (isFirst) {
        path.moveTo(x, y);
        isFirst = false;
      } else {
        path.lineTo(x, y);
      }
    }
    
    final paint = Paint()
      ..color = color.withOpacity(0.7)
      ..strokeWidth = 0.8  // 从1.5改为0.8，更细腻
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round  // 添加圆角端点
      ..isAntiAlias = true;  // 启用抗锯齿
    
    canvas.drawPath(path, paint);
  }
  
  // 绘制布林带
  void _drawBOLL(Canvas canvas, Size size, List<double> upper, List<double> middle, List<double> lower, double candleSpacing) {
    // 先绘制填充区域（作为背景）
    final path = Path();
    bool isFirst = true;
    
    // 绘制上轨路径
    for (int i = 0; i < upper.length && i < candleData.length; i++) {
      if (upper[i].isNaN) continue;
      
      final x = i * candleSpacing + candleSpacing / 2;
      final y = _priceToY(upper[i], size.height);
      
      if (isFirst) {
        path.moveTo(x, y);
        isFirst = false;
      } else {
        path.lineTo(x, y);
      }
    }
    
    // 绘制下轨路径（反向）
    for (int i = lower.length - 1; i >= 0; i--) {
      if (lower[i].isNaN || i >= candleData.length) continue;
      
      final x = i * candleSpacing + candleSpacing / 2;
      final y = _priceToY(lower[i], size.height);
      path.lineTo(x, y);
    }
    
    path.close();
    
    // 填充区域使用更淡的颜色
    final fillPaint = Paint()
      ..color = Colors.purple.withOpacity(0.05)
      ..style = PaintingStyle.fill;
    
    canvas.drawPath(path, fillPaint);
    
    // 然后绘制线条（更细腻）
    _drawBOLLLine(canvas, size, upper, Colors.purple.withOpacity(0.4), candleSpacing);
    _drawBOLLLine(canvas, size, middle, Colors.orange.withOpacity(0.5), candleSpacing);
    _drawBOLLLine(canvas, size, lower, Colors.purple.withOpacity(0.4), candleSpacing);
  }
  
  // 绘制布林带线条（专用方法，更细）
  void _drawBOLLLine(Canvas canvas, Size size, List<double> data, Color color, double candleSpacing) {
    final path = Path();
    bool isFirst = true;
    
    for (int i = 0; i < data.length && i < candleData.length; i++) {
      if (data[i].isNaN) continue;
      
      final x = i * candleSpacing + candleSpacing / 2;
      final y = _priceToY(data[i], size.height);
      
      if (isFirst) {
        path.moveTo(x, y);
        isFirst = false;
      } else {
        path.lineTo(x, y);
      }
    }
    
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.6  // 布林带线条更细
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    
    canvas.drawPath(path, paint);
  }
  
  // 绘制交易标记（优化版：无背景填充，三角形在外侧）
  void _drawTradeMarkers(Canvas canvas, Size size) {
    if (trades == null || trades!.isEmpty) return;
    
    final double chartHeight = size.height;
    final double candleSpacing = size.width / candleData.length;
    
    for (final trade in trades!) {
      // 查找交易对应的K线索引（使用date字段）
      int tradeIndex = -1;
      for (int i = 0; i < candleData.length; i++) {
        if (candleData[i].date == trade.date) {
          tradeIndex = i;
          break;
        }
      }
      
      if (tradeIndex == -1) continue;
      
      final x = tradeIndex * candleSpacing + candleSpacing / 2;
      final priceY = _priceToY(trade.price, chartHeight);
      
      // 根据交易类型选择颜色和位置
      final isBuy = trade.action == 'buy';
      final color = isBuy ? Colors.red : Colors.green;
      final triangleSize = 10.0;
      final textOffset = 18.0; // 文字距离K线的偏移
      
      // 先绘制三角形（在外侧，不遮挡K线）
      final trianglePath = Path();
      final trianglePaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      
      final triangleBorderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      
      if (isBuy) {
        // 买入：三角形在下方指向上，文字在三角形下方
        final triangleY = priceY + textOffset;
        trianglePath.moveTo(x, triangleY);
        trianglePath.lineTo(x - triangleSize, triangleY + triangleSize);
        trianglePath.lineTo(x + triangleSize, triangleY + triangleSize);
        trianglePath.close();
        
        canvas.drawPath(trianglePath, trianglePaint);
        canvas.drawPath(trianglePath, triangleBorderPaint);
        
        // 绘制文字（在三角形下方）
        final textPainter = TextPainter(
          text: TextSpan(
            text: '买',
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: ui.TextDirection.ltr,
        );
        
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            x - textPainter.width / 2,
            triangleY + triangleSize + 2,
          ),
        );
      } else {
        // 卖出：三角形在上方指向下，文字在三角形上方
        final triangleY = priceY - textOffset;
        trianglePath.moveTo(x, triangleY);
        trianglePath.lineTo(x - triangleSize, triangleY - triangleSize);
        trianglePath.lineTo(x + triangleSize, triangleY - triangleSize);
        trianglePath.close();
        
        canvas.drawPath(trianglePath, trianglePaint);
        canvas.drawPath(trianglePath, triangleBorderPaint);
        
        // 绘制文字（在三角形上方）
        final textPainter = TextPainter(
          text: TextSpan(
            text: '卖',
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: ui.TextDirection.ltr,
        );
        
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            x - textPainter.width / 2,
            triangleY - triangleSize - textPainter.height - 2,
          ),
        );
      }
    }
  }
  
  @override
  bool shouldRepaint(CandlestickChartPainter oldDelegate) {
    return oldDelegate.candleData != candleData ||
        oldDelegate.minY != minY ||
        oldDelegate.maxY != maxY ||
        oldDelegate.isDark != isDark ||
        oldDelegate.indicators != indicators ||
        oldDelegate.trades != trades;
  }
}

// 附图绘制器（用于MACD/RSI/KDJ）
class SubChartPainter extends CustomPainter {
  final List<CandleData> candleData;
  final Map<String, dynamic> indicatorData;
  final bool isDark;
  
  SubChartPainter({
    required this.candleData,
    required this.indicatorData,
    required this.isDark,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (candleData.isEmpty) return;
    
    final type = indicatorData['type'] as String;
    
    switch (type) {
      case 'MACD':
        _drawMACD(canvas, size);
        break;
      case 'RSI':
        _drawRSI(canvas, size);
        break;
      case 'KDJ':
        _drawKDJ(canvas, size);
        break;
    }
  }
  
  // 绘制MACD
  void _drawMACD(Canvas canvas, Size size) {
    final dif = indicatorData['dif'] as List<double>;
    final dea = indicatorData['dea'] as List<double>;
    final macd = indicatorData['macd'] as List<double>;
    
    // 确保数据长度一致
    final dataLength = [dif.length, dea.length, macd.length, candleData.length].reduce((a, b) => a < b ? a : b);
    
    if (dataLength == 0) return;
    
    // 计算最大最小值
    double minVal = double.infinity;
    double maxVal = double.negativeInfinity;
    
    for (int i = 0; i < dataLength; i++) {
      if (i < dif.length && !dif[i].isNaN) {
        minVal = minVal < dif[i] ? minVal : dif[i];
        maxVal = maxVal > dif[i] ? maxVal : dif[i];
      }
      if (i < dea.length && !dea[i].isNaN) {
        minVal = minVal < dea[i] ? minVal : dea[i];
        maxVal = maxVal > dea[i] ? maxVal : dea[i];
      }
      if (i < macd.length && !macd[i].isNaN) {
        minVal = minVal < macd[i] ? minVal : macd[i];
        maxVal = maxVal > macd[i] ? maxVal : macd[i];
      }
    }
    
    if (minVal == double.infinity) return;
    
    final range = maxVal - minVal;
    if (range == 0) return;
    
    final candleSpacing = size.width / candleData.length;
    
    // 绘制零轴
    final zeroY = size.height * (1 - (0 - minVal) / range);
    final zeroPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.2)
      ..strokeWidth = 0.5;
    canvas.drawLine(Offset(0, zeroY), Offset(size.width, zeroY), zeroPaint);
    
    // 绘制MACD柱状图
    for (int i = 0; i < dataLength; i++) {
      if (i >= macd.length || macd[i].isNaN) continue;
      
      final x = i * candleSpacing + candleSpacing / 2;
      final y = size.height * (1 - (macd[i] - minVal) / range);
      final color = macd[i] >= 0 ? Colors.red : Colors.green;
      
      final barPaint = Paint()
        ..color = color.withOpacity(0.6)
        ..strokeWidth = candleSpacing * 0.6
        ..strokeCap = StrokeCap.round;
      
      canvas.drawLine(Offset(x, zeroY), Offset(x, y), barPaint);
    }
    
    // 绘制DIF线
    _drawLine(canvas, size, dif, minVal, range, Colors.yellow, candleSpacing);
    
    // 绘制DEA线
    _drawLine(canvas, size, dea, minVal, range, Colors.purple, candleSpacing);
  }
  
  // 绘制RSI
  void _drawRSI(Canvas canvas, Size size) {
    final values = indicatorData['values'] as List<double>;
    
    // RSI范围固定为0-100
    final minVal = 0.0;
    final maxVal = 100.0;
    final range = maxVal - minVal;
    final candleSpacing = size.width / candleData.length;
    
    // 绘制参考线（30, 50, 70）
    final linePaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.1)
      ..strokeWidth = 0.5;
    
    for (final level in [30.0, 50.0, 70.0]) {
      final y = size.height * (1 - (level - minVal) / range);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
    
    // 绘制RSI线
    _drawLine(canvas, size, values, minVal, range, Colors.purple, candleSpacing);
  }
  
  // 绘制KDJ
  void _drawKDJ(Canvas canvas, Size size) {
    final k = indicatorData['k'] as List<double>;
    final d = indicatorData['d'] as List<double>;
    final j = indicatorData['j'] as List<double>;
    
    // 确保数据长度一致
    final dataLength = [k.length, d.length, j.length, candleData.length].reduce((a, b) => a < b ? a : b);
    
    if (dataLength == 0) return;
    
    // 计算最大最小值
    double minVal = 0.0;
    double maxVal = 100.0;
    
    for (int i = 0; i < dataLength; i++) {
      if (i < k.length && !k[i].isNaN) {
        minVal = minVal < k[i] ? minVal : k[i];
        maxVal = maxVal > k[i] ? maxVal : k[i];
      }
      if (i < d.length && !d[i].isNaN) {
        minVal = minVal < d[i] ? minVal : d[i];
        maxVal = maxVal > d[i] ? maxVal : d[i];
      }
      if (i < j.length && !j[i].isNaN) {
        minVal = minVal < j[i] ? minVal : j[i];
        maxVal = maxVal > j[i] ? maxVal : j[i];
      }
    }
    
    final range = maxVal - minVal;
    if (range == 0) return;
    
    final candleSpacing = size.width / candleData.length;
    
    // 绘制参考线
    final linePaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.1)
      ..strokeWidth = 0.5;
    
    for (final level in [20.0, 50.0, 80.0]) {
      if (level >= minVal && level <= maxVal) {
        final y = size.height * (1 - (level - minVal) / range);
        canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
      }
    }
    
    // 绘制K线
    _drawLine(canvas, size, k, minVal, range, Colors.yellow, candleSpacing);
    
    // 绘制D线
    _drawLine(canvas, size, d, minVal, range, Colors.purple, candleSpacing);
    
    // 绘制J线
    _drawLine(canvas, size, j, minVal, range, Colors.cyan, candleSpacing);
  }
  
  // 通用线条绘制方法
  void _drawLine(Canvas canvas, Size size, List<double> data, double minVal, double range, Color color, double candleSpacing) {
    if (data.isEmpty || candleData.isEmpty) return;
    
    final path = Path();
    bool isFirst = true;
    
    // 使用较小的长度来避免越界
    final maxLength = data.length < candleData.length ? data.length : candleData.length;
    
    for (int i = 0; i < maxLength; i++) {
      if (i >= data.length || data[i].isNaN) continue;
      
      final x = i * candleSpacing + candleSpacing / 2;
      final y = size.height * (1 - (data[i] - minVal) / range);
      
      if (isFirst) {
        path.moveTo(x, y);
        isFirst = false;
      } else {
        path.lineTo(x, y);
      }
    }
    
    final paint = Paint()
      ..color = color.withOpacity(0.8)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(SubChartPainter oldDelegate) {
    return oldDelegate.candleData != candleData ||
        oldDelegate.indicatorData != indicatorData ||
        oldDelegate.isDark != isDark;
  }
}
