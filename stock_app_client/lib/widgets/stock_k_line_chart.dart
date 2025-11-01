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
  
  const StockKLineChart({
    super.key, 
    required this.data,
    this.showVolume = true,
    this.indicators,
    this.trades,
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
    
    return Column(
      children: [
        // 真正的K线蜡烛图 + 技术指标
        Expanded(
          flex: 3,
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

  // 构建成交量图表
  Widget _buildVolumeChart(List<CandleData> candleData) {
    // 计算最大成交量用于Y轴缩放
    final maxVolume = candleData.map((e) => e.volume).reduce((a, b) => a > b ? a : b) * 1.1;
    
    if (maxVolume <= 0) {
      return const SizedBox(height: 100, child: Center(child: Text('无成交量数据')));
    }
    
    return SizedBox(
      height: 100,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
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
                  getTitlesWidget: (value, meta) {
                    if (value >= 1000000) {
                      return Text(
                        '${(value / 1000000).toStringAsFixed(1)}M',
                        style: const TextStyle(fontSize: 10),
                      );
                    } else if (value >= 1000) {
                      return Text(
                        '${(value / 1000).toStringAsFixed(1)}K',
                        style: const TextStyle(fontSize: 10),
                      );
                    }
                    return Text(
                      value.toStringAsFixed(0),
                      style: const TextStyle(fontSize: 10),
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
                        ? Colors.red
                        : Colors.green,
                    width: 6,
                  ),
                ],
              ),
            ),
            gridData: const FlGridData(show: false),
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
        // 如果数据太多，只取最近60条
        final limitedList = historyList.length > 60 ? historyList.sublist(historyList.length - 60) : historyList;
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
      final limitedList = data.length > 60 ? data.sublist(data.length - 60) : data;
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
      return result;
    }
    
    final closes = candleData.map((c) => c.close).toList();
    // final highs = candleData.map((c) => c.high).toList();
    // final lows = candleData.map((c) => c.low).toList();
    
    for (var indicator in indicators!) {
      if (!indicator.enabled) continue;
      
      switch (indicator.type) {
        case 'MA':
          final period = indicator.params['period'] as int;
          final ma = TechnicalIndicatorCalculator.calculateMA(closes, period);
          result['MA$period'] = {
            'data': ma.values,
            'color': _getColorFromString(indicator.params['color'] as String),
            'name': indicator.name,
          };
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
      default:
        return Colors.white;
    }
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
    final double candleWidth = chartWidth / candleData.length * 0.7;
    final double candleSpacing = chartWidth / candleData.length;
    
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
    if (indicators.isEmpty) return;
    
    final chartWidth = size.width;
    // final chartHeight = size.height;
    final candleSpacing = chartWidth / candleData.length;
    
    // 绘制MA均线
    indicators.forEach((key, value) {
      if (key.startsWith('MA')) {
        final data = value['data'] as List<double>;
        final color = value['color'] as Color;
        _drawMALine(canvas, size, data, color, candleSpacing);
      } else if (key == 'BOLL') {
        // 绘制布林带
        final upper = value['upper'] as List<double>;
        final middle = value['middle'] as List<double>;
        final lower = value['lower'] as List<double>;
        _drawBOLL(canvas, size, upper, middle, lower, candleSpacing);
      }
    });
  }
  
  // 绘制MA均线
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
      ..color = color.withOpacity(0.8)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    
    canvas.drawPath(path, paint);
  }
  
  // 绘制布林带
  void _drawBOLL(Canvas canvas, Size size, List<double> upper, List<double> middle, List<double> lower, double candleSpacing) {
    // 绘制上轨
    _drawMALine(canvas, size, upper, Colors.pink.withOpacity(0.5), candleSpacing);
    // 绘制中轨
    _drawMALine(canvas, size, middle, Colors.yellow.withOpacity(0.5), candleSpacing);
    // 绘制下轨
    _drawMALine(canvas, size, lower, Colors.pink.withOpacity(0.5), candleSpacing);
    
    // 填充上下轨之间的区域
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
    
    final fillPaint = Paint()
      ..color = Colors.pink.withOpacity(0.1)
      ..style = PaintingStyle.fill;
    
    canvas.drawPath(path, fillPaint);
  }
  
  // 绘制交易标记
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
      
      // 根据交易类型选择颜色和图标
      final isBuy = trade.action == 'buy';
      final color = isBuy ? Colors.red : Colors.green;
      final iconSize = 24.0;
      
      // 绘制圆形背景
      final circlePaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(
        Offset(x, priceY),
        iconSize / 2,
        circlePaint,
      );
      
      // 绘制白色边框
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      
      canvas.drawCircle(
        Offset(x, priceY),
        iconSize / 2,
        borderPaint,
      );
      
      // 绘制文字标记（买、卖）
      final textPainter = TextPainter(
        text: TextSpan(
          text: isBuy ? '买' : '卖',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
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
          priceY - textPainter.height / 2,
        ),
      );
      
      // 绘制指向价格的小三角形
      final trianglePath = Path();
      if (isBuy) {
        // 买入：三角形在下方指向上
        trianglePath.moveTo(x, priceY + iconSize / 2);
        trianglePath.lineTo(x - 6, priceY + iconSize / 2 + 8);
        trianglePath.lineTo(x + 6, priceY + iconSize / 2 + 8);
      } else {
        // 卖出：三角形在上方指向下
        trianglePath.moveTo(x, priceY - iconSize / 2);
        trianglePath.lineTo(x - 6, priceY - iconSize / 2 - 8);
        trianglePath.lineTo(x + 6, priceY - iconSize / 2 - 8);
      }
      trianglePath.close();
      
      canvas.drawPath(trianglePath, circlePaint);
      canvas.drawPath(trianglePath, borderPaint);
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
