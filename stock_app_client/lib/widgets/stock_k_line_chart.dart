import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class StockKLineChart extends StatelessWidget {
  final dynamic data;
  final bool showVolume;
  
  const StockKLineChart({
    super.key, 
    required this.data,
    this.showVolume = true,
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
    
    return Column(
      children: [
        SizedBox(
          height: 300,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: true),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toStringAsFixed(2),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < candleData.length) {
                          final date = candleData[value.toInt()].date;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              date.length > 5 ? date.substring(5, 10) : date,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          );
                        }
                        return const SizedBox();
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
                borderData: FlBorderData(show: true),
                minX: 0,
                maxX: candleData.length.toDouble() - 1,
                minY: minY,
                maxY: maxY,
                lineBarsData: [
                  // 收盘价线
                  LineChartBarData(
                    spots: List.generate(
                      candleData.length,
                      (i) => FlSpot(i.toDouble(), candleData[i].close),
                    ),
                    isCurved: false,
                    color: Theme.of(context).primaryColor,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((touchedSpot) {
                        final index = touchedSpot.x.toInt();
                        if (index >= 0 && index < candleData.length) {
                          final item = candleData[index];
                          return LineTooltipItem(
                            '日期: ${item.date}\n'
                            '开盘: ${item.open.toStringAsFixed(2)}\n'
                            '最高: ${item.high.toStringAsFixed(2)}\n'
                            '最低: ${item.low.toStringAsFixed(2)}\n'
                            '收盘: ${item.close.toStringAsFixed(2)}',
                            const TextStyle(color: Colors.white),
                          );
                        }
                        return null;
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        if (showVolume && candleData.any((data) => data.volume > 0)) 
          _buildVolumeChart(candleData),
      ],
    );
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
        padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
        child: BarChart(
          BarChartData(
            gridData: const FlGridData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) {
                    // 将成交量转为万或亿显示
                    String volumeText;
                    if (value >= 100000000) {
                      volumeText = '${(value / 100000000).toStringAsFixed(1)}亿';
                    } else if (value >= 10000) {
                      volumeText = '${(value / 10000).toStringAsFixed(0)}万';
                    } else {
                      volumeText = value.toStringAsFixed(0);
                    }
                    
                    return Text(
                      volumeText,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    );
                  },
                ),
              ),
              bottomTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            borderData: FlBorderData(show: true),
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
            minY: 0,
            maxY: maxVolume,
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
    
    // 处理后再次打印日期范围
    if (historyData.length >= 2) {
      debugPrint('排序后日期范围: ${historyData.first['trade_date']} 到 ${historyData.last['trade_date']}');
    }
    
    for (final item in historyData) {
      try {
        // 为每个必要字段添加调试信息
        debugPrint('正在处理数据: ${item['trade_date']}');
        
        // 检查并打印必要字段值
        var openValue = item['open'];
        var closeValue = item['close'];
        var highValue = item['high'];
        var lowValue = item['low'];
        var volumeValue = item['volume'];
        
        debugPrint('字段值: open=$openValue, close=$closeValue, high=$highValue, low=$lowValue, volume=$volumeValue');
        
        // 尝试提取数据，适配不同的API数据格式
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
          volume = _parseDouble(item['volume']);
          
          // 转换后的值
          debugPrint('转换后: date=$date, open=$open, close=$close, high=$high, low=$low, volume=$volume');
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
          result.add(CandleData(
            date: date,
            open: open,
            high: high,
            low: low,
            close: close,
            volume: volume ?? 0.0,
          ));
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