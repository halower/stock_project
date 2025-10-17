import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'dart:async'; // 添加async包导入
import 'package:http/http.dart' as http;
import '../models/trade_record.dart';
import '../services/providers/trade_provider.dart';
import '../services/providers/strategy_provider.dart';
import '../services/providers/stock_provider.dart';
import '../models/strategy.dart';
import '../services/stock_service.dart';
import '../services/database_service.dart';
import '../services/ai_assistant_service.dart';
import '../models/ai_config.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_markdown/flutter_markdown.dart'; // 添加markdown包导入
import '../widgets/ai_trade_analysis_widget.dart';
import '../services/ai_config_service.dart';
import '../widgets/ai_config_required_dialog.dart';
import 'dart:ui' as ui;

// 添加仓位计算方式枚举
enum PositionCalculationMethod {
  percentage, // 按比例计算
  quantity,   // 按数量计算
  riskBased   // 以损定仓
}

class AddTradeScreen extends StatefulWidget {
  const AddTradeScreen({super.key});

  @override
  State<AddTradeScreen> createState() => _AddTradeScreenState();
}

class _AddTradeScreenState extends State<AddTradeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _stockCodeController = TextEditingController();
  final _stockNameController = TextEditingController();
  final _planPriceController = TextEditingController();
  final _planQuantityController = TextEditingController();
  final _stopLossPriceController = TextEditingController();
  final _takeProfitPriceController = TextEditingController();
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();
  final _atrValueController = TextEditingController();
  DateTime _createTime = DateTime.now();
  TradeType _tradeType = TradeType.buy;
  Strategy? _selectedStrategy;
  bool _isManualInput = false;
  List<Map<String, dynamic>> _stockSuggestions = [];
  bool _isLoading = false;
  late StockService _stockService;
  bool _isInitialized = false;
  double _profitRiskRatio = 0.0; // 盈亏比
  final _positionPercentageController = TextEditingController(text: '20.0');
  final _atrMultipleController = TextEditingController(text: '2.0'); // 默认ATR倍数
  final _riskPercentageController =
      TextEditingController(text: '2.0'); // 默认风险熔断百分比/以损定仓风险比例
  MarketPhase _selectedMarketPhase = MarketPhase.rising;
  TrendStrength _selectedTrendStrength = TrendStrength.medium;
  EntryDifficulty _selectedEntryDifficulty = EntryDifficulty.medium;
  final PositionBuildingMethod _selectedBuildingMethod =
      PositionBuildingMethod.oneTime;
  PriceTriggerType _selectedTriggerType = PriceTriggerType.breakout;

  // 添加仓位计算方式
  bool _usePositionPercentage = true; // true: 使用仓位比例, false: 使用股票数量
  final double _accountBalance = 100000.0; // 假设账户余额，实际应从配置或账户中获取
  final _accountBalanceController = TextEditingController(text: '100000.0');
  final _accountTotalController = TextEditingController();

  // 添加ATR相关
  bool _useAtrForStopLoss = true; // 是否使用ATR计算止损
  List<Map<String, dynamic>> _stockHistoryData = []; // 存储历史K线数据
  bool _isLoadingAtr = false;

  // 添加K线图相关变量
  bool _showKLineChart = false;
  double _minY = 0.0;
  double _maxY = 0.0;
  
  // 添加点击查看详细数据功能
  Map<String, dynamic>? _selectedPoint;
  bool _showDetailView = false;
  int _selectedIndex = -1;

  // 添加新变量：ATR容差比例
  double _atrToleranceRatio = 0.0;

  // 类变量部分添加
  double _positionAmount = 0.0; // 添加一个变量存储交易金额

  // 添加一个变量用于防抖动
  DateTime _lastSearchTime = DateTime.now();

  // 添加AI分析相关变量
  bool _isAnalyzing = false;
  String _aiAnalysisResult = '';
  String _aiThinkingProcess = ''; // 添加变量存储AI思考过程
  bool _showAiAnalysis = false;
  bool _hasAnalyzed = false; // 添加标记，记录是否已经分析过
  bool _isThinkingStreamActive = false; // 标记思考流是否激活
  StreamController<String>? _thinkingStreamController; // 思考过程流控制器

  // 在_AddTradeScreenState类中添加一个变量（找到其他状态变量的地方添加）
  bool _showThinkingProcess = false;

  // 添加仓位计算方式变量
  PositionCalculationMethod _positionCalculationMethod = PositionCalculationMethod.percentage;
  
  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final database = await context.read<DatabaseService>().database;
      _stockService = StockService(database);
      // 移除重复的监听器添加，已在 initState 中添加
      _isInitialized = true;
    }
  }

  @override
  void initState() {
    super.initState();
    _stockCodeController.addListener(_onStockCodeChanged);
    _loadAccountTotal().then((_) {
      // 加载完账户总额后立即计算默认数量
      if (_planPriceController.text.isNotEmpty && _usePositionPercentage) {
        _calculatePosition();
      }
    });
    _setupParameterListeners(); // 添加参数监听

    Future.microtask(() async {
      await context.read<StrategyProvider>().loadStrategies();
      // 检查StockProvider是否已初始化，如果已初始化则不强制刷新
      final stockProvider = context.read<StockProvider>();
      if (!stockProvider.isInitialized) {
        await stockProvider.loadStocks(forceRefresh: false);
      }
      // 初始化时计算一次盈亏比
      _calculateProfitRiskRatio();
    });
  }

  Future<void> _loadAccountTotal() async {
    final prefs = await SharedPreferences.getInstance();
    final total = prefs.getDouble('account_total') ?? 0.0;
    _accountTotalController.text = total > 0 ? total.toString() : '';
  }

  Future<void> _saveAccountTotal() async {
    final prefs = await SharedPreferences.getInstance();
    final total = double.tryParse(_accountTotalController.text) ?? 0.0;
    await prefs.setDouble('account_total', total);
  }

  @override
  void dispose() {
    _stockCodeController
        .removeListener(_onStockCodeChanged); // 添加这一行，移除股票代码变化监听器
    _stockCodeController.removeListener(_resetAnalysisState);
    _planPriceController.removeListener(_resetAnalysisState);
    _stopLossPriceController.removeListener(_resetAnalysisState);
    _takeProfitPriceController.removeListener(_resetAnalysisState);
    _planQuantityController.removeListener(_resetAnalysisState);

    // 关闭思考过程流控制器
    if (_thinkingStreamController != null) {
      _thinkingStreamController!.close();
      _thinkingStreamController = null;
    }

    _stockCodeController.dispose();
    _stockNameController.dispose();
    
    _planPriceController.dispose();
    _planQuantityController.dispose();
    _stopLossPriceController.dispose();
    _takeProfitPriceController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    _atrValueController.dispose();
    _accountBalanceController.dispose();
    _accountTotalController.dispose();
    super.dispose();
  }

  Future<void> _onStockCodeChanged() async {
    final query = _stockCodeController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _stockSuggestions = [];
      });
      return;
    }

    // 添加防抖动，避免频繁搜索
    final now = DateTime.now();
    if (now.difference(_lastSearchTime).inMilliseconds < 300) {
      // 如果距离上次搜索不到300毫秒，则延迟执行
      Future.delayed(const Duration(milliseconds: 300), () {
        // 检查文本是否变化，避免延迟后执行不必要的搜索
        if (_stockCodeController.text.trim() == query) {
          _performSearch(query);
        }
      });
      return;
    }

    _lastSearchTime = now;
    _performSearch(query);
  }

  // 将搜索逻辑提取到单独的方法
  Future<void> _performSearch(String query) async {
    print('执行股票搜索: "$query"');

    // 检查StockProvider是否已初始化并且有数据，如果是则使用缓存数据，无需显示加载
    final stockProvider = context.read<StockProvider>();
    final bool hasData = stockProvider.isInitialized && stockProvider.stocks.isNotEmpty;

    // 只有在没有数据时才显示加载状态
    if (!hasData) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final suggestions = await stockProvider.getStockSuggestions(query);
      print('获取到 ${suggestions.length} 条股票建议');

      if (mounted) {
        setState(() {
          _stockSuggestions = suggestions;
          // 只有在之前显示了加载状态时才隐藏它
          if (!hasData) {
            _isLoading = false;
          }
        });
      }
    } catch (e) {
      print('搜索股票时出错: $e');
      if (mounted) {
        setState(() {
          // 只有在之前显示了加载状态时才隐藏它
          if (!hasData) {
            _isLoading = false;
          }
        });
      }
    }
  }

  // 选择股票的方法
  void _selectStock(Map<String, dynamic> stock) async {
    final code = stock['code'];
    final name = stock['name'];

    setState(() {
      _stockCodeController.text = code;
      _stockNameController.text = name;
      _stockSuggestions = [];
      _isManualInput = false;
      _stockHistoryData = []; // 清空历史数据
      _isLoadingAtr = true; // 显示加载状态
    });

    // 重置分析状态
    _resetAnalysisState();

    try {
      // 显示加载指示器
      setState(() {
        _isLoading = true;
      });

      // 获取最新价格
      final stockService =
          StockService(await context.read<DatabaseService>().database);
      final currentPrice = await stockService.getCurrentPrice(code);

      if (mounted && currentPrice != null && currentPrice > 0) {
        _planPriceController.text = currentPrice.toStringAsFixed(2);
        print('设置计划价格为最新价格: $currentPrice');
        // 获取到价格后，立即计算仓位
        if (_usePositionPercentage && _accountTotalController.text.isNotEmpty) {
          _calculatePosition();
        }
      }

      // 获取历史数据以计算ATR
      await _getStockHistoryData(code);

      if (mounted) {
        setState(() {
          _isLoading = false;
          _showKLineChart = true; // 确保显示K线图
        });
      }
    } catch (e) {
      print('选择股票后获取数据出错: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingAtr = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('获取股票数据失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 获取股票历史数据的方法
  Future<void> _getStockHistoryData(String stockCode) async {
    if (stockCode.isEmpty) return;

    setState(() {
      _isLoadingAtr = true;
      _stockHistoryData = [];
    });

    try {
      print('获取股票 $stockCode 的历史数据...');

      // 使用StockService获取历史数据
      final stockService =
          StockService(await context.read<DatabaseService>().database);

      // 获取当前日期
      final currentDate = DateTime.now();
      final endDate =
          currentDate.toIso8601String().split('T')[0].replaceAll('-', '');

      // 获取90个交易日的数据，确保足够计算ATR和显示图表
      final startDate =
          DateTime(currentDate.year, currentDate.month, currentDate.day - 90)
              .toIso8601String()
              .split('T')[0]
              .replaceAll('-', '');

      final historyData = await stockService.getStockHistoryData(stockCode,
          startDate: startDate, endDate: endDate);

      if (mounted) {
        if (historyData.isNotEmpty) {
          // 确保历史数据按日期正确排序（从旧到新）
          historyData.sort((a, b) {
            // 优先使用trade_date字段，如果没有则使用date字段
            String dateA = '';
            String dateB = '';
            
            if (a.containsKey('trade_date') && a['trade_date'] != null) {
              dateA = a['trade_date'].toString();
            } else if (a.containsKey('date') && a['date'] != null) {
              dateA = a['date'].toString();
            }
            
            if (b.containsKey('trade_date') && b['trade_date'] != null) {
              dateB = b['trade_date'].toString();
            } else if (b.containsKey('date') && b['date'] != null) {
              dateB = b['date'].toString();
            }
            
            return dateA.compareTo(dateB);
          });
          
          setState(() {
            // 保存完整历史数据
            _stockHistoryData = List<Map<String, dynamic>>.from(historyData);

            // 确保数据中包含必要的字段
            _stockHistoryData = _stockHistoryData
                .where((item) =>
                    item.containsKey('high') &&
                    item['high'] != null &&
                    item.containsKey('low') &&
                    item['low'] != null &&
                    item.containsKey('close') &&
                    item['close'] != null)
                .toList();

            // 使用最新收盘价更新计划价格
            if (_stockHistoryData.isNotEmpty) {
              final latestData = _stockHistoryData.last;
              final latestPrice = latestData['close'] as double? ?? 0.0;
              
              // 获取日期信息用于日志
              String latestDate = '';
              if (latestData.containsKey('trade_date') && latestData['trade_date'] != null) {
                latestDate = latestData['trade_date'].toString();
              } else if (latestData.containsKey('date') && latestData['date'] != null) {
                latestDate = latestData['date'].toString();
              }
              
              if (latestPrice > 0) {
                // 检查当前计划价格与最新价格的差异
                final currentPrice = double.tryParse(_planPriceController.text) ?? 0.0;
                final priceDiff = (latestPrice - currentPrice).abs();
                final priceDiffPercent = currentPrice > 0 ? (priceDiff / currentPrice) * 100 : 100.0;
                
                // 如果价格差异超过5%或当前价格为0，则更新为最新价格
                if (currentPrice == 0 || priceDiffPercent > 5.0) {
                  _planPriceController.text = latestPrice.toStringAsFixed(2);
                  print('从历史数据设置计划价格为最新收盘价: $latestPrice (日期: $latestDate)');
                  print('价格差异: ${priceDiff.toStringAsFixed(2)} (${priceDiffPercent.toStringAsFixed(2)}%)');
                } else {
                  print('当前价格 $currentPrice 与最新价格 $latestPrice 差异较小，保持不变');
                }
              }
            }

            _isLoadingAtr = false;
            _calculateChartRange();
            _calculateATR();
            print('成功获取历史数据，共${_stockHistoryData.length}条');
          });
        } else {
          setState(() {
            _stockHistoryData = [];
            _isLoadingAtr = false;
          });
          print('未获取到股票历史数据或数据为空');
        }
      }
    } catch (e) {
      print('获取股票历史数据失败: $e');
      if (mounted) {
        setState(() {
          _isLoadingAtr = false;
          // 尝试使用备用方法计算ATR
          _useBackupAtrCalculation();
        });
      }
    }
  }

  Future<void> _fetchLatestPriceAndATR(String stockCode) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 1. 获取最新价格
      final currentPrice =
          await context.read<StockProvider>().getCurrentPrice(stockCode);

      if (currentPrice != null && mounted) {
        print('获取到股票 $stockCode 的最新价格: $currentPrice');
        setState(() {
          // 设置为计划价格
          _planPriceController.text = currentPrice.toStringAsFixed(2);
        });
      } else {
        print('无法获取股票 $stockCode 的最新价格');
      }

      // 2. 获取历史数据和计算ATR
      await _fetchStockATR(stockCode);

      // 3. 计算仓位
      if (_usePositionPercentage && mounted) {
        _calculatePosition();
      }
    } catch (e) {
      print('获取股票价格和ATR失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('获取股票数据失败: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchStockATR(String stockCode) async {
    try {
      setState(() {
        _isLoadingAtr = true;
      });

      // 优先使用服务端计算的ATR
      final atr = await context.read<StockProvider>().getStockATR(stockCode);

      if (atr != null && atr > 0 && mounted) {
        print('使用服务端计算的ATR值: $atr');
        setState(() {
          _atrValueController.text = atr.toStringAsFixed(4);
          _isLoadingAtr = false;
          if (_useAtrForStopLoss) {
            _calculateStopLossFromATR();
          }
        });
      }

      // 不论ATR计算成功与否，都尝试获取历史数据显示K线图
      print('开始获取股票 $stockCode 的K线数据');

      // 获取历史数据，使用修改后的API
      final historyData =
          await context.read<StockProvider>().getStockHistoryData(stockCode);

      print('获取到 ${historyData.length} 条K线数据');

      if (historyData.isNotEmpty && mounted) {
        // 确保历史数据按日期正确排序（从旧到新）
        historyData.sort((a, b) {
          final dateA = DateTime.parse(a['date'].toString());
          final dateB = DateTime.parse(b['date'].toString());
          return dateA.compareTo(dateB);
        });
        
        setState(() {
          _stockHistoryData = historyData;
          _showKLineChart = true; // 显示K线图

          // 始终使用最新收盘价作为计划价格
          if (historyData.isNotEmpty) {
            final latestData = historyData.last;
            final latestPrice = latestData['close'] as double? ?? 0.0;
            
            // 获取日期信息用于日志
            String latestDate = '';
            if (latestData.containsKey('trade_date') && latestData['trade_date'] != null) {
              latestDate = latestData['trade_date'].toString();
            } else if (latestData.containsKey('date') && latestData['date'] != null) {
              latestDate = latestData['date'].toString();
            }
            
            if (latestPrice > 0) {
              // 检查当前计划价格与最新价格的差异
              final currentPrice = double.tryParse(_planPriceController.text) ?? 0.0;
              final priceDiff = (latestPrice - currentPrice).abs();
              final priceDiffPercent = currentPrice > 0 ? (priceDiff / currentPrice) * 100 : 100.0;
              
              // 如果价格差异超过5%或当前价格为0，则更新为最新价格
              if (currentPrice == 0 || priceDiffPercent > 5.0) {
                _planPriceController.text = latestPrice.toStringAsFixed(2);
                print('设置计划价格为最新收盘价: $latestPrice (日期: $latestDate)');
                print('价格差异: ${priceDiff.toStringAsFixed(2)} (${priceDiffPercent.toStringAsFixed(2)}%)');
              } else {
                print('当前价格 $currentPrice 与最新价格 $latestPrice 差异较小，保持不变');
              }
            }
          }

          // 计算K线图的最大最小值范围
          _calculateChartRange();
        });

        // 如果ATR还没有获取到，通过历史数据计算
        if (atr == null || atr <= 0) {
          // 计算ATR
          if (historyData.length < 15) {
            print('历史数据不足以计算14日ATR，当前只有${historyData.length}条数据');
            _useBackupAtrCalculation();
            return;
          }

          // 有足够的数据，自己计算ATR
          // 按日期排序，确保数据是时间升序排列（从旧到新）
          historyData.sort((a, b) {
            final dateA = DateTime.parse(a['date'].toString());
            final dateB = DateTime.parse(b['date'].toString());
            return dateA.compareTo(dateB); // 升序排列，最早的日期在前
          });

          // 实现Wilder的ATR计算
          const period = 14;
          List<double> trValues = [];

          // 计算每日的TR值
          for (int i = 1; i < historyData.length; i++) {
            final current = historyData[i];
            final previous = historyData[i - 1];

            final double high = (current['high'] as double?) ?? 0.0;
            final double low = (current['low'] as double?) ?? 0.0;
            final double prevClose = (previous['close'] as double?) ?? 0.0;

            // 打印计算过程中的值
            if (i < 3) {
              print('计算TR[$i]: high=$high, low=$low, prevClose=$prevClose');
            }

            // 跳过无效数据
            if (high <= 0 || low <= 0 || prevClose <= 0) {
              print('跳过无效数据: high=$high, low=$low, prevClose=$prevClose');
              continue;
            }

            final double tr1 = high - low;
            final double tr2 = (high - prevClose).abs();
            final double tr3 = (low - prevClose).abs();

            final double tr = [tr1, tr2, tr3].reduce((a, b) => a > b ? a : b);
            trValues.add(tr);

            if (i < 3) {
              print('TR[$i] = max($tr1, $tr2, $tr3) = $tr');
            }
          }

          // 确保有足够的TR值
          if (trValues.isEmpty) {
            print('计算ATR失败: 没有有效的TR值');
            _useBackupAtrCalculation();
            return;
          }

          // 打印所有计算出的TR值
          print('计算出的TR值: ${trValues.take(5)}...(共${trValues.length}个)');

          // 计算第一个ATR为简单平均
          double atr = 0.0;
          if (trValues.length >= period) {
            // 首先计算初始ATR作为第一个周期的简单移动平均
            double sumFirstPeriod = 0.0;
            for (int i = 0; i < period; i++) {
              sumFirstPeriod += trValues[i];
            }
            atr = sumFirstPeriod / period;
            print('初始ATR (SMA-$period): $atr');

            // 如果数据足够，使用Wilder的平滑方法
            if (trValues.length > period) {
              for (int i = period; i < trValues.length; i++) {
                atr = ((period - 1) * atr + trValues[i]) / period;
                if (i == trValues.length - 1) {
                  print('第${i + 1}日最终ATR值: $atr');
                }
              }
            }
          } else {
            // 数据不够一个周期，使用简单平均
            double sum = trValues.fold(0.0, (sum, tr) => sum + tr);
            atr = sum / trValues.length;
            print('数据不足一个完整周期，使用简单平均计算ATR: $atr');
          }

          print('股票$stockCode的ATR计算结果: $atr');

          if (mounted && atr > 0) {
            setState(() {
              _atrValueController.text = atr.toStringAsFixed(4);
              _isLoadingAtr = false;
              if (_useAtrForStopLoss) {
                _calculateStopLossFromATR();
              }
            });
          } else {
            print('ATR计算结果为0或负值，使用备用方法');
            _useBackupAtrCalculation();
          }
        }
      } else {
        print('未获取到K线数据或组件已卸载');
        if (mounted) {
          setState(() {
            _isLoadingAtr = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('获取K线数据失败，请检查网络连接或尝试其他股票'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print('获取股票ATR值失败: $e');
      if (mounted) {
        setState(() {
          _isLoadingAtr = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('获取K线数据出错: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      _useBackupAtrCalculation();
    }
  }

  // 使用备用方法计算ATR（基于价格百分比）
  void _useBackupAtrCalculation() {
    final currentPrice = double.tryParse(_planPriceController.text) ?? 0.0;
    if (currentPrice > 0 && mounted) {
      final backupAtr = currentPrice * 0.02; // 使用当前价格的2%
      setState(() {
        _atrValueController.text = backupAtr.toStringAsFixed(4);
        _isLoadingAtr = false;
        if (_useAtrForStopLoss) {
          _calculateStopLossFromATR();
        }
      });
      print('使用当前价格($currentPrice)的2%作为ATR: $backupAtr');
    } else {
      setState(() {
        _isLoadingAtr = false;
      });
    }
  }

  // 获取中文星期名称
  String _getWeekdayName(int weekday) {
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    return '星期${weekdays[weekday - 1]}';
  }

  void _showDatePicker() async {
    try {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: _createTime.isAfter(now) ? now : _createTime, // 如果当前设置的时间是未来时间，则默认为今天
        firstDate: DateTime(2020), // 从2020年开始，更合理的股票交易起始时间
        lastDate: now, // 最晚只能选择到今天
        locale: const Locale('zh', 'CN'), // 设置中文
        helpText: '选择开仓日期', // 中文标题
        cancelText: '取消', // 中文取消按钮
        confirmText: '确定', // 中文确定按钮
        fieldLabelText: '输入日期', // 中文输入标签
        fieldHintText: 'yyyy/mm/dd', // 日期格式提示
        errorFormatText: '日期格式错误', // 中文错误提示
        errorInvalidText: '请输入有效日期', // 中文无效日期提示
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: const Color(0xFF6366F1),
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Colors.black87,
              ),
              // 添加中文字体支持
              textTheme: Theme.of(context).textTheme.copyWith(
                headlineSmall: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            child: child!,
          );
        },
      );
      if (picked != null && picked != _createTime) {
        setState(() {
          _createTime = picked;
        });
        // 显示确认消息
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('开仓时间已设置为：${picked.year}年${picked.month}月${picked.day}日 (${_getWeekdayName(picked.weekday)})'),
              backgroundColor: const Color(0xFF6366F1),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('日期选择器错误: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('日期选择器出现错误，请重试'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      // 检查是否选择了策略
      if (_selectedStrategy == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('请选择交易策略'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // 检查是否为周末
      if (_createTime.weekday >= 6) {  // 周六是6，周日是7
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A股市场周末不交易，请选择工作日'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      try {
        final tradeRecord = TradeRecord(
          id: null,
          stockCode: _stockCodeController.text,
          stockName: _stockNameController.text,
          tradeType: _tradeType,
          status: TradeStatus.pending,
          category: TradeCategory.plan,
          tradeDate: _createTime,
          planPrice: double.parse(_planPriceController.text),
          planQuantity: int.parse(_planQuantityController.text),
          stopLossPrice: double.parse(_stopLossPriceController.text),
          takeProfitPrice: double.parse(_takeProfitPriceController.text),
          strategy: _selectedStrategy?.name,
          reason: _reasonController.text,
          notes: _notesController.text,
          createTime: _createTime,
          updateTime: DateTime.now(),
          marketPhase: _selectedMarketPhase,
          trendStrength: _selectedTrendStrength,
          entryDifficulty: _selectedEntryDifficulty,
          positionPercentage:
              double.tryParse(_positionPercentageController.text),
          positionBuildingMethod: _selectedBuildingMethod,
          priceTriggerType: _selectedTriggerType,
          atrValue: double.tryParse(_atrValueController.text),
          atrMultiple: double.tryParse(_atrMultipleController.text),
          riskPercentage: double.tryParse(_riskPercentageController.text),
          // 不设置手续费和税费
          commission: null,
          tax: null,
        );

        // 显示交易计划概况
        final planPrice = double.parse(_planPriceController.text);
        final planQuantity = int.parse(_planQuantityController.text);
        final totalAmount = planPrice * planQuantity;
        final positionPct =
            double.tryParse(_positionPercentageController.text) ?? 0.0;

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('交易计划概览'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '股票: ${_stockCodeController.text} ${_stockNameController.text}'),
                Text('入场价格: ${_planPriceController.text}'),
                Text('计划数量: ${_planQuantityController.text}股'),
                Text('总金额: ${totalAmount.toStringAsFixed(2)}元'),
                Text('仓位比例: ${positionPct.toStringAsFixed(2)}%'),
                Text('止损价格: ${_stopLossPriceController.text}'),
                Text('止盈价格: ${_takeProfitPriceController.text}'),
                Text('盈亏比: ${_profitRiskRatio.toStringAsFixed(2)}'),
                if (_tradeType == TradeType.buy &&
                    _selectedMarketPhase == MarketPhase.falling)
                  const Text('⚠️ 警告：您正在下降趋势中开多单',
                      style: TextStyle(color: Colors.red)),
                if (_tradeType == TradeType.sell &&
                    _selectedMarketPhase == MarketPhase.rising)
                  const Text('⚠️ 警告：您正在上升趋势中开空单',
                      style: TextStyle(color: Colors.red)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('返回修改'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _saveTradePlanWithRecord(tradeRecord);
                },
                child: const Text('确认提交'),
              ),
            ],
          ),
        );
      } catch (e) {
        // 显示错误信息
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存交易计划失败: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        print('保存交易计划失败: $e');
      }
    }
  }

  // 添加单独的保存方法以便重用，用于处理已有TradeRecord对象
  void _saveTradePlanWithRecord(TradeRecord tradeRecord) {
    setState(() {
      _isLoading = true;
    });

    context.read<TradeProvider>().addTradePlan(tradeRecord).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('交易计划已保存'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.pop(context);
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('保存交易计划失败: $error'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }).whenComplete(() {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  // 计算K线图的价格范围
  void _calculateChartRange() {
    if (_stockHistoryData.isEmpty) return;

    try {
      // 过滤出有效的价格数据
      final validData = _stockHistoryData
          .where((data) =>
              data.containsKey('high') &&
              data['high'] != null &&
              data.containsKey('low') &&
              data['low'] != null)
          .toList();

      if (validData.isEmpty) {
        print('没有找到有效的价格数据，无法计算图表范围');
        return;
      }

      final prices = validData
          .expand((data) => [
                data['high'] as double,
                data['low'] as double,
              ])
          .toList();

      if (prices.isEmpty) {
        print('展开后的价格列表为空，无法计算图表范围');
        return;
      }

      _minY = (prices.reduce((a, b) => a < b ? a : b) * 0.95);
      _maxY = (prices.reduce((a, b) => a > b ? a : b) * 1.05);

      // 确保止损价和目标价在显示范围内
      final stopLoss = double.tryParse(_stopLossPriceController.text) ?? 0.0;
      final takeProfit =
          double.tryParse(_takeProfitPriceController.text) ?? 0.0;

      if (stopLoss > 0) {
        _minY = _minY < stopLoss * 0.95 ? _minY : stopLoss * 0.95;
      }

      if (takeProfit > 0) {
        _maxY = _maxY > takeProfit * 1.05 ? _maxY : takeProfit * 1.05;
      }
    } catch (e) {
      print('计算图表范围出错: $e');
      // 设置默认值
      final price = double.tryParse(_planPriceController.text) ?? 10.0;
      _minY = price * 0.9;
      _maxY = price * 1.1;
    }
  }

  void _calculateProfitRiskRatio() {
    print('=== 开始计算盈亏比 ===');
    print('入场价格输入框: "${_planPriceController.text}"');
    print('止损价格输入框: "${_stopLossPriceController.text}"');
    print('止盈价格输入框: "${_takeProfitPriceController.text}"');
    
    if (_planPriceController.text.isNotEmpty &&
        _stopLossPriceController.text.isNotEmpty &&
        _takeProfitPriceController.text.isNotEmpty) {
      
      final entryPrice = double.tryParse(_planPriceController.text) ?? 0; // 入场价格
      final stopLoss = double.tryParse(_stopLossPriceController.text) ?? 0;
      final takeProfit = double.tryParse(_takeProfitPriceController.text) ?? 0; // 止盈价格

      print('解析后的价格: 入场=$entryPrice, 止损=$stopLoss, 止盈=$takeProfit');

      if (entryPrice > 0 && stopLoss > 0 && takeProfit > 0) {
        // A股买入交易逻辑：
        // 风险 = 入场价格 - 止损价格 (必须为正数，止损价格应该低于入场价格)
        // 收益 = 止盈价格 - 入场价格 (必须为正数，止盈价格应该高于入场价格)
        final riskPerUnit = entryPrice - stopLoss;
        final rewardPerUnit = takeProfit - entryPrice;

        print('计算结果: 风险每单位=$riskPerUnit, 收益每单位=$rewardPerUnit');

        // 确保风险和收益都是正数
        if (riskPerUnit > 0 && rewardPerUnit > 0) {
          final newRatio = rewardPerUnit / riskPerUnit;
          setState(() {
            _profitRiskRatio = newRatio;
          });

          print('✅ 盈亏比计算成功: ${newRatio.toStringAsFixed(2)}');
          print('风险每单位=$riskPerUnit, 收益每单位=$rewardPerUnit');

          // 检查ATR风险
          if (_atrValueController.text.isNotEmpty) {
            final atr = double.tryParse(_atrValueController.text) ?? 0;
            final multiple = double.tryParse(_atrMultipleController.text) ?? 2.0;

            // 如果止损距离小于ATR设置的距离，可能止损太紧
            if (riskPerUnit < (atr * multiple * 0.8)) {
              print('警告：止损位置可能设置过紧，小于推荐的ATR距离');
            } else if (riskPerUnit > (atr * multiple * 1.5)) {
              print('警告：止损位置可能设置过松，大于推荐的ATR距离');
            }
          }
        } else {
          // 价格设置不合理，重置盈亏比
          setState(() {
            _profitRiskRatio = 0.0;
          });
          print('❌ 价格设置不合理: 风险=$riskPerUnit, 收益=$rewardPerUnit');
          if (riskPerUnit <= 0) {
            print('   - 止损价格($stopLoss)应该低于入场价格($entryPrice)');
          }
          if (rewardPerUnit <= 0) {
            print('   - 止盈价格($takeProfit)应该高于入场价格($entryPrice)');
          }
        }
      } else {
        print('❌ 价格解析失败或为0');
        setState(() {
          _profitRiskRatio = 0.0;
        });
      }
    } else {
      print('❌ 输入框为空');
      setState(() {
        _profitRiskRatio = 0.0;
      });
    }
    print('=== 盈亏比计算结束，当前值: ${_profitRiskRatio.toStringAsFixed(2)} ===');
  }

  void _calculateStopLossFromATR() {
    if (_atrValueController.text.isEmpty || _planPriceController.text.isEmpty) {
      return;
    }

    final atr = double.tryParse(_atrValueController.text) ?? 0.0;
    final atrMultiple = double.tryParse(_atrMultipleController.text) ?? 2.0;
    final planPrice = double.tryParse(_planPriceController.text) ?? 0.0;

    if (atr <= 0 || planPrice <= 0) return;

    // A股买入交易：计划价格 - (ATR * 倍数)
    double stopLossPrice = planPrice - (atr * atrMultiple);

    setState(() {
      _stopLossPriceController.text = stopLossPrice.toStringAsFixed(4);
      _calculateProfitRiskRatio();
      // 更新止损容差比例显示
      _updateATRToleranceRatio();
    });
  }

  // 添加新方法：计算ATR容差比例
  void _updateATRToleranceRatio() {
    if (_atrValueController.text.isEmpty ||
        _planPriceController.text.isEmpty ||
        _stopLossPriceController.text.isEmpty) {
      return;
    }

    final atr = double.tryParse(_atrValueController.text) ?? 0.0;
    final atrMultiple = double.tryParse(_atrMultipleController.text) ?? 2.0;
    final planPrice = double.tryParse(_planPriceController.text) ?? 0.0;
    final stopLossPrice = double.tryParse(_stopLossPriceController.text) ?? 0.0;

    if (atr <= 0 || planPrice <= 0 || stopLossPrice <= 0) return;

    // 实际止损距离
    final actualDistance = (planPrice - stopLossPrice).abs();
    // ATR理论距离
    final theoreticalDistance = atr * atrMultiple;

    // 容差比例 = 实际距离 / 理论距离
    final toleranceRatio = theoreticalDistance > 0
        ? (actualDistance / theoreticalDistance).toDouble()
        : 0.0;

    setState(() {
      // 这里可以更新UI中显示容差比例的控件
      _atrToleranceRatio = toleranceRatio;
    });

    print(
        'ATR容差比例更新: ATR=$atr, 倍数=$atrMultiple, 理论距离=$theoreticalDistance, 实际距离=$actualDistance, 比例=$toleranceRatio');
  }

  // 计算当前的ATR容差比例，返回实时的值而不依赖于_atrToleranceRatio
  double calculateToleranceRatio() {
    try {
      if (_atrValueController.text.isEmpty ||
          _planPriceController.text.isEmpty ||
          _stopLossPriceController.text.isEmpty) {
        print('calculateToleranceRatio: 输入框为空');
        return 0.0;
      }

      final atr = double.tryParse(_atrValueController.text) ?? 0.0;
      final atrMultiple = double.tryParse(_atrMultipleController.text) ?? 2.0;
      final planPrice = double.tryParse(_planPriceController.text) ?? 0.0;
      final stopLossPrice =
          double.tryParse(_stopLossPriceController.text) ?? 0.0;

      print(
          '计算容差比例的输入值: ATR=$atr, 倍数=$atrMultiple, 计划价=$planPrice, 止损价=$stopLossPrice');

      if (atr <= 0) {
        print('calculateToleranceRatio: ATR值无效: $atr');
        return 0.0;
      }

      if (planPrice <= 0) {
        print('calculateToleranceRatio: 入场价格无效: $planPrice');
        return 0.0;
      }

      if (stopLossPrice <= 0) {
        print('calculateToleranceRatio: 止损价格无效: $stopLossPrice');
        return 0.0;
      }

      // 实际止损距离
      final actualDistance = (planPrice - stopLossPrice).abs();
      // ATR理论距离
      final theoreticalDistance = atr * atrMultiple;

      print(
          'calculateToleranceRatio: 实际距离=$actualDistance, 理论距离=$theoreticalDistance');

      // 特殊情况处理：当ATR理论距离接近0时
      if (theoreticalDistance <= 0.000001) {
        print('calculateToleranceRatio: 理论距离近似为0，返回1.0作为默认值');
        return 1.0; // 当理论距离几乎为0时，返回1.0作为默认值
      }

      final ratio = (actualDistance / theoreticalDistance).toDouble();
      print(
          '实时计算ATR容差比例: ATR=$atr, 倍数=$atrMultiple, 理论距离=$theoreticalDistance, 实际距离=$actualDistance, 比例=$ratio');

      return ratio;
    } catch (e) {
      print('calculateToleranceRatio出错: $e');
      return 1.0; // 出错时返回默认值
    }
  }

  // 计算仓位
  void _calculatePosition() {
    if (_planPriceController.text.isEmpty) return;
    final planPrice = double.tryParse(_planPriceController.text) ?? 0.0;
    if (planPrice <= 0) return;

    if (_positionCalculationMethod == PositionCalculationMethod.percentage) {
      final positionPercentage =
          double.tryParse(_positionPercentageController.text) ?? 0.0;
      final accountTotal = double.tryParse(_accountTotalController.text) ?? 0.0;
      if (positionPercentage <= 0 || accountTotal <= 0) return;

      // 计算仓位金额
      final positionAmount = accountTotal * positionPercentage / 100;

      // 计算数量并确保是100的整数倍
      int quantity = (positionAmount / planPrice).floor();
      quantity = (quantity ~/ 100) * 100;

      // 如果计算出的数量小于100，则设置为100
      if (quantity <= 0) quantity = 100;

      // 计算实际交易金额
      final actualPositionAmount = quantity * planPrice;

      setState(() {
        _planQuantityController.text = quantity.toString();
        _positionAmount = actualPositionAmount;
      });

      _saveAccountTotal();
      print(
          '根据仓位比例计算：账户总额=$accountTotal, 仓位比例=$positionPercentage%, 金额=$positionAmount, 价格=$planPrice, 数量=$quantity, 实际金额=$actualPositionAmount');
    } else if (_positionCalculationMethod == PositionCalculationMethod.quantity) {
      // 股票数量模式：根据用户输入的数量计算仓位比例
      final quantityText = _planQuantityController.text.trim();
      if (quantityText.isEmpty) {
        // 如果数量输入框为空，则清空相关计算结果，但不强制设置为0
        setState(() {
          _positionPercentageController.text = '';
          _positionAmount = 0.0;
        });
        return;
      }
      
      final quantity = int.tryParse(quantityText) ?? 0;
      final accountTotal = double.tryParse(_accountTotalController.text) ?? 0.0;

      if (quantity > 0 && accountTotal > 0 && planPrice > 0) {
        // 确保数量是100的整数倍
        final adjustedQuantity = (quantity ~/ 100) * 100;
        if (adjustedQuantity != quantity && adjustedQuantity > 0) {
          setState(() {
            _planQuantityController.text = adjustedQuantity.toString();
          });
        }

        final positionAmount = (adjustedQuantity > 0 ? adjustedQuantity : quantity) * planPrice;
        final positionPercentage = (positionAmount / accountTotal) * 100;

        setState(() {
          _positionPercentageController.text =
              positionPercentage.toStringAsFixed(2);
          _positionAmount = positionAmount;
        });

        _saveAccountTotal();
        print(
            '根据数量反向计算：数量=${adjustedQuantity > 0 ? adjustedQuantity : quantity}, 价格=$planPrice, 金额=$positionAmount, 账户总额=$accountTotal, 仓位比例=$positionPercentage%');
      } else if (quantity > 0) {
        // 即使账户总额为0，也要计算交易金额
        final positionAmount = quantity * planPrice;
        setState(() {
          _positionAmount = positionAmount;
        });
      }
    } else if (_positionCalculationMethod == PositionCalculationMethod.riskBased) {
      // 以损定仓模式：根据账户总额、可承受风险比例和止损价格计算仓位
      final accountTotal = double.tryParse(_accountTotalController.text) ?? 0.0;
      final planPrice = double.tryParse(_planPriceController.text) ?? 0.0;
      final stopLossPrice = double.tryParse(_stopLossPriceController.text) ?? 0.0;
      final riskPercentage = double.tryParse(_riskPercentageController.text) ?? 2.0; // 默认风险比例2%
      
      // 如果风险比例为空或者小于等于0，使用默认值2.0%
      if (riskPercentage <= 0) {
        _riskPercentageController.text = '2.0';
      }
      
      if (accountTotal > 0 && planPrice > 0 && stopLossPrice > 0 && planPrice != stopLossPrice) {
        // 计算可承受的最大亏损金额
        final maxLossAmount = accountTotal * (riskPercentage / 100);
        
        // 计算每股的亏损金额
        double perShareLoss = 0.0;
        if (_tradeType == TradeType.buy) {
          // 买入时，止损价应低于入场价
          perShareLoss = planPrice - stopLossPrice;
          if (perShareLoss <= 0) {
            // 止损价高于入场价，无法计算
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('买入时止损价应低于入场价'),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }
        } else {
          // 卖出时，止损价应高于入场价
          perShareLoss = stopLossPrice - planPrice;
          if (perShareLoss <= 0) {
            // 止损价低于入场价，无法计算
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('卖出时止损价应高于入场价'),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }
        }
        
        // 计算可买入/卖出的最大股数
        int maxShares = (maxLossAmount / perShareLoss).floor();
        
        // 调整为100的整数倍
        int quantity = (maxShares ~/ 100) * 100;
        
        // 如果计算出的数量小于100，则设置为100
        if (quantity < 100) quantity = 100;
        
        // 计算实际交易金额和仓位比例
        final actualPositionAmount = quantity * planPrice;
        final positionPercentage = (actualPositionAmount / accountTotal) * 100;
        
        setState(() {
          _planQuantityController.text = quantity.toString();
          _positionPercentageController.text = positionPercentage.toStringAsFixed(2);
          _positionAmount = actualPositionAmount;
        });
        
        _saveAccountTotal();
        print(
            '根据以损定仓计算：账户总额=$accountTotal, 风险比例=$riskPercentage%, 最大亏损=$maxLossAmount, '
            '每股亏损=$perShareLoss, 价格=$planPrice, 数量=$quantity, 金额=$actualPositionAmount, 仓位比例=$positionPercentage%');
      }
    }
  }

  // 添加AI分析方法
  Future<void> _analyzeTradeWithAI() async {
    // 首先检查用户是否可以使用AI功能
    final aiPermission = await AIConfigService.canUseAI();
    if (!aiPermission['canUse']) {
      // 显示专业的配置提示对话框
      if (mounted) {
        await AIConfigRequiredDialog.show(
          context,
          feature: 'AI交易分析',
          description: '该功能可以基于您的交易计划和市场数据，为您提供专业的交易成功率评估、参数优化建议和交易决策建议。',
        );
      }
      return;
    }

    if (_hasAnalyzed) {
      // 如果已经分析过，直接显示结果
      _showAIAnalysisDialog();
      return;
    }

    if (_stockCodeController.text.isEmpty ||
        _selectedStrategy == null ||
        _reasonController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先选择股票、策略并填写交易理由'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 检查必要的交易参数是否已填写
    if (_planPriceController.text.isEmpty ||
        _planQuantityController.text.isEmpty ||
        _stopLossPriceController.text.isEmpty ||
        _takeProfitPriceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请完善交易计划的价格和数量信息'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _aiAnalysisResult = '';
      _aiThinkingProcess = '';

      // 创建思考过程流
      _thinkingStreamController = StreamController<String>();
      _isThinkingStreamActive = true;

      // 初始化思考过程，这样即使API没有返回思考过程，也有一些内容显示
      _generateInitialThinkingProcess();
    });

    // 使用覆盖层显示分析进度，不再使用Dialog

    try {
      // 1. 获取股票历史数据
      final stockCode = _stockCodeController.text;
      final historyData =
          await context.read<StockProvider>().getStockHistoryData(stockCode);

      if (historyData.isEmpty) {
        throw Exception('无法获取股票历史数据');
      }

      // 2. 获取策略详细信息 - 使用实际存在的字段
      final strategy = _selectedStrategy;
      String strategyDescription = '';
      List<String> entryConditions = [];
      List<String> exitConditions = [];
      List<String> riskControls = [];

      if (strategy != null) {
        strategyDescription = strategy.description ?? '';
        entryConditions = strategy.entryConditions;
        exitConditions = strategy.exitConditions;
        riskControls = strategy.riskControls;
      }

      // 3. 准备分析请求数据 - 直接在AI请求中构建，无需单独的analysisData变量

      // 格式化历史K线数据，便于大模型理解和技术指标计算
      const lastNDays = 120; // 增加到120天数据，确保AI有足够数据计算技术指标
      
      // 确保历史数据按日期正确排序（从旧到新）
      historyData.sort((a, b) {
        // 优先使用trade_date字段，如果没有则使用date字段
        String dateA = '';
        String dateB = '';
        
        if (a.containsKey('trade_date') && a['trade_date'] != null) {
          dateA = a['trade_date'].toString();
        } else if (a.containsKey('date') && a['date'] != null) {
          dateA = a['date'].toString();
        }
        
        if (b.containsKey('trade_date') && b['trade_date'] != null) {
          dateB = b['trade_date'].toString();
        } else if (b.containsKey('date') && b['date'] != null) {
          dateB = b['date'].toString();
        }
        
        return dateA.compareTo(dateB);
      });
      
      final recentHistory = historyData.length > lastNDays
          ? historyData.sublist(historyData.length - lastNDays)
          : historyData;

      String historyDataText = "股票历史K线数据（共${recentHistory.length}个交易日，按时间从旧到新排序，最新数据在最后）:\n";
      historyDataText += "格式：日期 开盘价 最高价 最低价 收盘价 成交量\n";
      historyDataText += "==========================================\n";
      
      for (var i = 0; i < recentHistory.length; i++) {
        final item = recentHistory[i];
        
        // 获取日期字段
        String dateStr = '';
        if (item.containsKey('trade_date') && item['trade_date'] != null) {
          dateStr = item['trade_date'].toString();
        } else if (item.containsKey('date') && item['date'] != null) {
          dateStr = item['date'].toString();
        }
        
        historyDataText +=
            "$dateStr ${item['open']} ${item['high']} ${item['low']} ${item['close']} ${item['volume']}\n";
      }
      
      // 添加最新价格信息
      if (recentHistory.isNotEmpty) {
        final latestData = recentHistory.last;
        final latestPrice = latestData['close'] as double? ?? 0.0;
        String latestDate = '';
        if (latestData.containsKey('trade_date') && latestData['trade_date'] != null) {
          latestDate = latestData['trade_date'].toString();
        } else if (latestData.containsKey('date') && latestData['date'] != null) {
          latestDate = latestData['date'].toString();
        }
        historyDataText += "\n当前最新价格: $latestPrice (日期: $latestDate)\n";
      }

      String actualTrend = _calculateActualTrend(recentHistory);

      // 构建策略规则文本
      String strategyDetailsText = "";
      if (entryConditions.isNotEmpty) {
        strategyDetailsText += "入场条件:\n";
        for (var condition in entryConditions) {
          strategyDetailsText += "- $condition\n";
        }
      }

      if (exitConditions.isNotEmpty) {
        strategyDetailsText += "出场条件:\n";
        for (var condition in exitConditions) {
          strategyDetailsText += "- $condition\n";
        }
      }

      if (riskControls.isNotEmpty) {
        strategyDetailsText += "风险控制:\n";
        for (var control in riskControls) {
          strategyDetailsText += "- $control\n";
        }
      }

      // 4. 调用AI API进行分析
      // 获取AI配置（已经通过权限检查，确保有有效配置）
      final effectiveUrl = await AIConfigService.getEffectiveUrl();
      final effectiveApiKey = await AIConfigService.getEffectiveApiKey();
      final effectiveModel = await AIConfigService.getEffectiveModel();

      // 确保有有效的配置参数（这里应该已经通过权限检查）
      if (effectiveApiKey == null || effectiveApiKey.isEmpty ||
          effectiveUrl == null || effectiveUrl.isEmpty) {
        throw Exception('AI配置无效，请在设置中配置完整的API服务地址和密钥');
      }

      print('正在调用DeepSeek API进行交易分析（非流式）...');

      // 构建请求体 - 包含更准确和完整的交易信息
      final requestBody = {
        'model': effectiveModel,
        'messages': [
          {
            'role': 'system',
            'content': '''
            你是一位专业的股票交易分析师，具有丰富的A股市场经验和量化分析能力。
            你能够基于K线数据自行计算和分析各种技术指标（如RSI、MACD、布林带、均线等）。
            
            请基于提供的完整交易信息和历史K线数据进行专业分析：
            
            分析要求：
            1. 基于历史K线数据计算关键技术指标（RSI、MACD、均线、布林带等）
            2. 分析当前价格位置（支撑阻力、趋势状态等）
            3. 评估交易方向与市场趋势的一致性
            4. 检查止损止盈设置的合理性（基于ATR、波动率等）
            5. 给出量化的成功率评估
            
                         回复格式要求：
             【分析结论】
             1. 交易成功率：XX%（基于技术分析和市场状态）
             2. 设置问题分析：指出具体的参数设置问题
             3. 交易建议：明确建议执行/暂停/修改
             
             重要说明：
             - 请直接返回分析结论，不要包含思考过程标签（如<think>等）
             - 请基于实际计算的技术指标进行分析，不要依赖用户提供的判断
             - 回复内容应该清晰简洁，便于用户理解
            '''
          },
          {
            'role': 'user',
            'content': '''
              请分析以下交易计划：
              
              === 基础信息 ===
              股票：${_stockCodeController.text} ${_stockNameController.text}
              交易方向：${_tradeType == TradeType.buy ? "买入" : "卖出"}
              开仓时间：${DateTime.now().toString()}
              
              === 价格设置（请重点分析这些实际价格）===
              计划入场价格：${_planPriceController.text}元
              止损价格：${_stopLossPriceController.text}元
              止盈价格：${_takeProfitPriceController.text}元
              
              计划数量：${_planQuantityController.text}股
              交易金额：${(double.tryParse(_planPriceController.text) ?? 0.0) * (int.tryParse(_planQuantityController.text) ?? 0)}元
              
              === 风险参数（基于实际价格计算）===
              实际止损幅度：${_tradeType == TradeType.buy 
                ? (((double.tryParse(_planPriceController.text) ?? 0.0) - (double.tryParse(_stopLossPriceController.text) ?? 0.0)) / (double.tryParse(_planPriceController.text) ?? 1.0) * 100).toStringAsFixed(2)
                : (((double.tryParse(_stopLossPriceController.text) ?? 0.0) - (double.tryParse(_planPriceController.text) ?? 0.0)) / (double.tryParse(_planPriceController.text) ?? 1.0) * 100).toStringAsFixed(2)}%
              实际止盈幅度：${_tradeType == TradeType.buy 
                ? (((double.tryParse(_takeProfitPriceController.text) ?? 0.0) - (double.tryParse(_planPriceController.text) ?? 0.0)) / (double.tryParse(_planPriceController.text) ?? 1.0) * 100).toStringAsFixed(2)
                : (((double.tryParse(_planPriceController.text) ?? 0.0) - (double.tryParse(_takeProfitPriceController.text) ?? 0.0)) / (double.tryParse(_planPriceController.text) ?? 1.0) * 100).toStringAsFixed(2)}%
              实际盈亏比：${_profitRiskRatio.toStringAsFixed(2)}
              
              === 仓位和风控 ===
              仓位比例：${_positionPercentageController.text}%
              风险熔断：${_riskPercentageController.text}%
              ATR参考值：${_atrValueController.text}
              ATR倍数：${_atrMultipleController.text}
              
              === 市场判断和交易逻辑 ===
              交易理由：${_reasonController.text}
              用户判断的市场阶段：${_getMarketPhaseText()}
              预期趋势强度：${_getTrendStrengthText()}
              预期入场难度：${_getDifficultyLabel(_selectedEntryDifficulty)}
              
              === 交易策略 ===
              策略名称：${_selectedStrategy?.name ?? '未指定'}
              策略描述：${_selectedStrategy?.description ?? '无'}
              $strategyDetailsText
              
              === 股票历史K线数据（请基于此数据计算技术指标）===
              $historyDataText
              
              请基于以上信息进行专业分析：
              
              1. 请根据K线数据计算主要技术指标（RSI、MACD、均线、布林带等）
              2. 分析当前入场价格是否合理（支撑阻力位、趋势位置等）
              3. 评估止损止盈设置是否符合市场波动特征
              4. 判断用户的市场阶段判断是否与技术分析一致
              5. 基于量化分析给出成功率评估
              
              特别注意：
              - 请重点分析实际的止损止盈价格和比例
              - 如果发现止损设置过紧或过松，请明确指出
              - 如果市场趋势与交易方向不符，请明确说明
              - 请提供具体的改进建议
            '''
          }
        ],
        'temperature': 0.3, // 降低温度以获得更准确的分析
        'max_tokens': 1024, // 增加token数以获得更详细分析
        'stream': false,
        'enable_thinking': true,
        'thinking_budget': 8192, // 增加思考预算让AI进行更深入分析
        'min_p': 0.05,
        'top_p': 0.7,
        'top_k': 50,
        'frequency_penalty': 0.5,
        'n': 1,
        'stop': [],
      };

      print('请求参数: ${jsonEncode(requestBody)}');

      // 发送HTTP请求
      final response = await http.post(
        Uri.parse(effectiveUrl!),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $effectiveApiKey',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        throw Exception('API调用失败: ${response.statusCode}');
      }

      // 打印完整响应以便分析
      print('=========完整API响应开始=========');
      print(response.body);
      print('=========完整API响应结束=========');

      // 解析响应
      final jsonResponse = jsonDecode(response.body);

      // 提取分析结果和思考过程
      final rawAnalysisResult =
          jsonResponse['choices'][0]['message']['content'] as String? ?? '';
      // 提取思考过程
      final thinkingProcess = jsonResponse['choices'][0]['message']
              ['reasoning_content'] as String? ??
          '';

      // 清理分析结果，移除思考标签和多余内容
      String cleanedAnalysisResult = _cleanAnalysisResult(rawAnalysisResult);

      // 更新状态，使用标志位触发结果对话框
      setState(() {
        _isAnalyzing = false;
        _aiAnalysisResult = cleanedAnalysisResult;
        _aiThinkingProcess = "## 模型思考过程\n\n$thinkingProcess"; // 保存思考过程
        _hasAnalyzed = true;
        _showAiAnalysis = true; // 设置标志位，让Builder触发显示结果对话框
      });
    } catch (e) {
      print('AI分析出错: $e');

      // 不再需要关闭Dialog，因为我们使用的是覆盖层

      // 显示错误提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI分析服务暂时不可用: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: '使用本地分析',
              onPressed: () {
                // 使用本地分析作为备用
                _useLocalAnalysis();
              },
            ),
          ),
        );

        setState(() {
          _isAnalyzing = false;
        });
      }

      // 关闭流控制器
      if (_thinkingStreamController != null) {
        await _thinkingStreamController!.close();
        _isThinkingStreamActive = false;
        _thinkingStreamController = null;
      }
    }
  }

  // 生成初始思考过程，确保不为空
  void _generateInitialThinkingProcess() {
    final stockCode = _stockCodeController.text;
    final stockName = _stockNameController.text;
    final isBuy = _tradeType == TradeType.buy;
    final planPrice = double.tryParse(_planPriceController.text) ?? 0.0;
    final stopLossPrice = double.tryParse(_stopLossPriceController.text) ?? 0.0;
    final takeProfitPrice =
        double.tryParse(_takeProfitPriceController.text) ?? 0.0;
    final profitRiskRatio = _profitRiskRatio;

    String initialThinking = """## 思考过程

正在分析$stockCode $stockName的交易计划...

### 市场趋势分析
* 正在评估当前市场阶段(${_getMarketPhaseText()})与进场类型的匹配度...
* 分析趋势强度(${_getTrendStrengthText()})对成功率的影响...

### 交易参数合理性
* 入场价格: ${planPrice.toStringAsFixed(2)}
* 止损价格: ${stopLossPrice.toStringAsFixed(2)}
* 止盈价格: ${takeProfitPrice.toStringAsFixed(2)}
* 分析价格设置的合理性...
* 分析ATR设置和止损位置...

### 风险收益分析
* 评估盈亏比(${profitRiskRatio.toStringAsFixed(2)})...
* 分析仓位比例...
* 评估风险熔断设置...

### 成功率计算中
* 基于市场阶段、价格设置、风险管理等因素计算成功率...
* 正在计算综合风险评分...
""";

    _aiThinkingProcess = initialThinking;

    // 如果流控制器已激活，发送初始思考过程
    if (_isThinkingStreamActive && _thinkingStreamController != null) {
      _thinkingStreamController!.add(initialThinking);
    }
  }

  // 已移除_showStreamingAnalysisDialog方法，改用_buildAnalyzingOverlay覆盖层

  // 清理AI分析结果，移除思考标签和多余内容
  String _cleanAnalysisResult(String rawResult) {
    if (rawResult.isEmpty) return rawResult;
    
    String cleaned = rawResult;
    
    // 移除思考过程标签（各种可能的格式）
    cleaned = cleaned.replaceAll(RegExp(r'</?think>?', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'</think>', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'<think>', caseSensitive: false), '');
    
    // 移除可能的思考过程内容
    cleaned = cleaned.replaceAll(RegExp(r'思考过程[:：].*?(?=【|$)', dotAll: true), '');
    
    // 移除多余的【分析结论】重复标题
    final conclusionPattern = RegExp(r'【分析结论】(\s*【分析结论】)+', multiLine: true);
    while (conclusionPattern.hasMatch(cleaned)) {
      cleaned = cleaned.replaceAll(conclusionPattern, '【分析结论】');
    }
    
    // 移除连续的空行
    cleaned = cleaned.replaceAll(RegExp(r'\n\s*\n\s*\n+'), '\n\n');
    
    // 移除开头和结尾的空白字符
    cleaned = cleaned.trim();
    
    // 如果内容为空或只有标题，提供默认内容
    if (cleaned.isEmpty || cleaned == '【分析结论】') {
      cleaned = '【分析结论】\n\n正在分析中，请稍候...';
    }
    
    return cleaned;
  }

  // 根据历史数据计算实际趋势
  String _calculateActualTrend(List<Map<String, dynamic>> historyData) {
    if (historyData.isEmpty || historyData.length < 5) {
      return "数据不足，无法判断";
    }

    try {
      // 计算最近5日和10日的收盘价平均值，判断短期趋势
      double sum5 = 0;
      double sum10 = 0;
      int count10 = 0;

      // 从最新数据开始计算
      for (int i = historyData.length - 1; i >= 0; i--) {
        final close = historyData[i]['close'] as double? ?? 0.0;
        if (close <= 0) continue;

        if (historyData.length - 1 - i < 5) {
          sum5 += close;
        }

        if (historyData.length - 1 - i < 10) {
          sum10 += close;
          count10++;
        }
      }

      // 确保有足够的数据
      if (count10 < 5) {
        return "数据不足，无法判断";
      }

      double avg5 = sum5 / 5;
      double avg10 = sum10 / count10;

      // 计算最近10个交易日的收盘价变化趋势
      int upDays = 0;
      int downDays = 0;

      for (int i = historyData.length - 10; i < historyData.length - 1; i++) {
        if (i < 0) continue;

        final currentClose = historyData[i]['close'] as double? ?? 0.0;
        final nextClose = historyData[i + 1]['close'] as double? ?? 0.0;

        if (nextClose > currentClose) {
          upDays++;
        } else if (nextClose < currentClose) {
          downDays++;
        }
      }

      // 判断趋势
      String trend;
      if (avg5 > avg10 && upDays >= 6) {
        trend = "上升阶段";
      } else if (avg5 < avg10 && downDays >= 6) {
        trend = "下降阶段";
      } else if (avg5 < avg10 && upDays >= 5) {
        trend = "筑底阶段";
      } else if (avg5 > avg10 && downDays >= 5) {
        trend = "顶部阶段";
      } else {
        // 横盘整理：上涨下跌天数相当，价格在一定区间内波动
        trend = "盘整阶段";
      }

      return trend;
    } catch (e) {
      print('计算趋势出错: $e');
      return "计算出错，无法判断";
    }
  }

  // 使用本地分析作为备用
  void _useLocalAnalysis() {
    final simulatedAnalysis = _generateSimulatedAnalysis();
    setState(() {
      _aiAnalysisResult = simulatedAnalysis;
      // _aiThinkingProcess 变量已经在_generateSimulatedAnalysis方法中设置
      _showAiAnalysis = true;
      _hasAnalyzed = true;
    });
  }

  // 辅助方法：获取市场阶段的文本描述
  String _getMarketPhaseText() {
    switch (_selectedMarketPhase) {
      case MarketPhase.rising:
        return '上升阶段';
      case MarketPhase.falling:
        return '下降阶段';
      case MarketPhase.buildingBottom:
        return '筑底阶段';
      case MarketPhase.topping:
        return '顶部阶段';
      case MarketPhase.consolidation:
        return '盘整阶段';
      default:
        return '未知阶段';
    }
  }

  // 辅助方法：获取趋势强度的文本描述
  String _getTrendStrengthText() {
    switch (_selectedTrendStrength) {
      case TrendStrength.strong:
        return '强';
      case TrendStrength.medium:
        return '中';
      case TrendStrength.weak:
        return '弱';
      default:
        return '中';
    }
  }

  // 重置分析状态
  void _resetAnalysisState() {
    if (mounted) {
      // 添加mounted检查
      setState(() {
        _hasAnalyzed = false;
        _aiAnalysisResult = '';
      });
    }
  }

  // 监听交易参数变化，当关键参数变化时重置分析状态
  void _setupParameterListeners() {
    _stockCodeController.addListener(_resetAnalysisState);
    _planPriceController.addListener(() {
      _resetAnalysisState();
      _calculateProfitRiskRatio(); // 添加盈亏比计算
      // 当价格变化且使用仓位比例时，自动计算数量
      if (_positionCalculationMethod == PositionCalculationMethod.percentage && _accountTotalController.text.isNotEmpty) {
        _calculatePosition();
      }
    });
    _stopLossPriceController.addListener(() {
      _resetAnalysisState();
      _calculateProfitRiskRatio(); // 添加盈亏比计算
      // 如果是以损定仓模式，当止损价格变化时重新计算仓位
      if (_positionCalculationMethod == PositionCalculationMethod.riskBased) {
        _calculatePosition();
      }
    });
    _takeProfitPriceController.addListener(() {
      _resetAnalysisState();
      _calculateProfitRiskRatio(); // 添加盈亏比计算
    });
    _planQuantityController.addListener(_resetAnalysisState);
  }

  // 完全重写_showAIAnalysisDialog方法，更加突出关键信息
  void _showAIAnalysisDialog() {
    if (_aiAnalysisResult.isEmpty) {
      return;
    }

    // 确保默认显示结论，不显示思考过程
    _showThinkingProcess = false;
    
    // 移除合规性提示横幅
    bool showDisclaimerBanner = false;

    // 预处理分析结果，移除思考过程部分
    String analysisResult = _aiAnalysisResult;
    String thinkingProcess = _aiThinkingProcess;
    String strategyAdvice = '';

    // 从分析结果中移除思考过程相关内容
    final thinkingRegex =
        RegExp(r'(思考过程[:：]?.*?(?=##|$)|##\s*思考过程.*?(?=##|$))', dotAll: true);
    analysisResult = analysisResult.replaceAll(thinkingRegex, '');

    // 尝试提取交易策略完善建议
    final strategyAdviceRegex =
        RegExp(r'###?\s*交易策略完善建议.*?(?=###?|$)', dotAll: true);
    final match = strategyAdviceRegex.firstMatch(_aiAnalysisResult);
    if (match != null) {
      strategyAdvice = match.group(0) ?? '';
      // 从原始结果中移除策略建议部分，避免重复显示
      analysisResult = analysisResult.replaceAll(strategyAdvice, '');
    }

    // 尝试提取成功率
    String successRateText = '';
    final successRateRegex = RegExp(
        r'成功率[评估估计]?[:：]?\s*(\d+[%％]|\d+\.\d+[%％]|[一二三四五六七八九十]+成|低|中|高)',
        caseSensitive: false);
    final successRateMatch = successRateRegex.firstMatch(_aiAnalysisResult);
    if (successRateMatch != null) {
      successRateText = successRateMatch.group(1) ?? '';
    }

    // 提取开单建议
    String tradingAdvice = '';
    final adviceRegex = RegExp(r'交易建议[:：](.*?)(?=##|\n\n|$)', dotAll: true);
    final adviceMatch = adviceRegex.firstMatch(_aiAnalysisResult);
    if (adviceMatch != null) {
      tradingAdvice = adviceMatch.group(1)?.trim() ?? '';
    }

    // 如果没有提取到建议，尝试其他可能的标题
    if (tradingAdvice.isEmpty) {
      final alternativeRegexes = [
        RegExp(r'建议[:：](.*?)(?=##|\n\n|$)', dotAll: true),
        RegExp(r'具体建议[:：](.*?)(?=##|\n\n|$)', dotAll: true),
        RegExp(r'开单建议[:：](.*?)(?=##|\n\n|$)', dotAll: true)
      ];

      for (var regex in alternativeRegexes) {
        final match = regex.firstMatch(_aiAnalysisResult);
        if (match != null) {
          tradingAdvice = match.group(1)?.trim() ?? '';
          if (tradingAdvice.isNotEmpty) break;
        }
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDarkMode = Theme.of(context).brightness == Brightness.dark;
          final primaryColor = Theme.of(context).primaryColor;
          final bgColor = isDarkMode ? const Color(0xFF2D2D2D) : Colors.white;
          final textColor = isDarkMode ? Colors.white : Colors.black87;

          // 添加内容切换状态
          bool showStrategyAdvice = false;

          // 解析成功率以确定颜色
          Color successRateColor = Colors.blue;
          if (successRateText.isNotEmpty) {
            // 尝试从文本中提取数字
            final percentageRegex = RegExp(r'(\d+)');
            final percentMatch = percentageRegex.firstMatch(successRateText);
            if (percentMatch != null) {
              final percentage = int.tryParse(percentMatch.group(1) ?? '') ?? 0;
              if (percentage >= 70) {
                successRateColor = Colors.green;
              } else if (percentage >= 40) {
                successRateColor = Colors.orange;
              } else {
                successRateColor = Colors.red;
              }
            }
          }

          // 免责声明文本
          const String disclaimerText = '风险提示：本分析结果仅供参考，不构成投资建议。投资有风险，入市需谨慎。过往表现不代表未来业绩，用户应自行承担投资决策产生的风险。';

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            elevation: 8,
            backgroundColor: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width > 600
                  ? 550
                  : MediaQuery.of(context).size.width * 0.92,
              height: MediaQuery.of(context).size.height * 0.85,
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
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: isDarkMode 
                        ? Colors.black.withOpacity(0.4)
                        : Colors.grey.withOpacity(0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 合规性免责声明横幅
                  if (showDisclaimerBanner)
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFFF6B35),
                            const Color(0xFFFF8E53),
                            const Color(0xFFFF6B35),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF6B35).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // 滚动文本
                          ShaderMask(
                            shaderCallback: (rect) {
                              return const LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Colors.transparent,
                                  Colors.white,
                                  Colors.white,
                                  Colors.white,
                                  Colors.transparent,
                                ],
                                stops: [0.0, 0.1, 0.5, 0.9, 1.0],
                              ).createShader(rect);
                            },
                            blendMode: BlendMode.dstIn,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                                width: MediaQuery.of(context).size.width * 1.5,
                                child: const Row(
                                  children: [
                                    Icon(Icons.shield_outlined, color: Colors.white, size: 20),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        disclaimerText,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.3,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.visible,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // 关闭按钮
                          Positioned(
                            right: 0,
                            top: 0,
                            bottom: 0,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  setDialogState(() {
                                    showDisclaimerBanner = false;
                                  });
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.close_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                  // 标题栏
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          primaryColor.withOpacity(0.15),
                          primaryColor.withOpacity(0.08),
                        ],
                      ),
                      borderRadius: showDisclaimerBanner 
                          ? BorderRadius.zero 
                          : const BorderRadius.only(
                              topLeft: Radius.circular(24),
                              topRight: Radius.circular(24),
                            ),
                      border: Border(
                        bottom: BorderSide(
                          color: primaryColor.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 标题行
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    primaryColor,
                                    primaryColor.withOpacity(0.8),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryColor.withOpacity(0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.psychology_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'AI开单分析',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  Text(
                                    '智能开单决策助手',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: primaryColor.withOpacity(0.7),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // 思考过程按钮移到标题右侧
                            GestureDetector(
                              onTap: () {
                                setDialogState(() {
                                  _showThinkingProcess = !_showThinkingProcess;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: _showThinkingProcess
                                      ? LinearGradient(
                                          colors: [
                                            primaryColor,
                                            primaryColor.withOpacity(0.8),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        )
                                      : null,
                                  color: _showThinkingProcess
                                      ? null
                                      : Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _showThinkingProcess
                                        ? Colors.transparent
                                        : Colors.grey.withOpacity(0.3),
                                    width: 1,
                                  ),
                                  boxShadow: _showThinkingProcess
                                      ? [
                                          BoxShadow(
                                            color: primaryColor.withOpacity(0.3),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.psychology_rounded,
                                      color: _showThinkingProcess
                                          ? Colors.white
                                          : Colors.grey[600],
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "思考过程",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _showThinkingProcess
                                            ? Colors.white
                                            : Colors.grey[600],
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                                                // 移除策略建议按钮
                      ],
                    ),
                  ),

                  // 移除内容区标记，简化界面

                  // 🎯 重点突出显示成功率
                  if (!_showThinkingProcess && successRateText.isNotEmpty)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            successRateColor.withOpacity(0.15),
                            successRateColor.withOpacity(0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: successRateColor.withOpacity(0.3),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: successRateColor.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                        ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                            // 🎯 重点突出的成功率显示
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    successRateColor,
                                    successRateColor.withOpacity(0.8),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: successRateColor.withOpacity(0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                    Icons.emoji_events_rounded,
                                    color: Colors.white,
                                    size: 24,
                              ),
                                  const SizedBox(width: 12),
                                  Column(
                                    children: [
                                      Text(
                                        "开仓成功率",
                                  style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white.withOpacity(0.9),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        successRateText,
                                        style: const TextStyle(
                                          fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          letterSpacing: 0.5,
                                  ),
                                ),
                                    ],
                              ),
                            ],
                              ),
                          ),

                          // 交易建议摘要
                          if (tradingAdvice.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: (isDarkMode ? Colors.grey[800] : Colors.white)!.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.amber.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                      Icons.lightbulb_rounded,
                                  color: Colors.amber[700],
                                      size: 20,
                                ),
                                    const SizedBox(width: 10),
                                Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "执行建议",
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.amber[700],
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            tradingAdvice,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: textColor,
                                              height: 1.3,
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                  ),
                                ),
                              ],
                                ),
                            ),
                          ],
                        ],
                        ),
                      ),
                    ),

                  // 内容区域 - 主体
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
                          child: _showThinkingProcess
                              ? MarkdownBody(
                                  data: thinkingProcess,
                                  selectable: true,
                                  styleSheet: MarkdownStyleSheet(
                                    h1: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                    h2: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                    h3: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber[800],
                                    ),
                                    strong: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _tradeType == TradeType.buy
                                          ? Colors.green[700]
                                          : Colors.red[700],
                                    ),
                                    p: TextStyle(
                                      fontSize: 15,
                                      height: 1.4,
                                      color: textColor,
                                    ),
                                    listBullet: TextStyle(
                                      fontSize: 15,
                                      color: isDarkMode
                                          ? Colors.grey[300]
                                          : Colors.grey[700],
                                    ),
                                    blockquote: TextStyle(
                                      fontSize: 15,
                                      fontStyle: FontStyle.italic,
                                      color: isDarkMode
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                    ),
                                  ),
                                )
                              : MarkdownBody(
                                  data: analysisResult,
                                  selectable: true,
                                  styleSheet: MarkdownStyleSheet(
                                    h1: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                    h2: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                    h3: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondary,
                                    ),
                                    strong: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _tradeType == TradeType.buy
                                          ? Colors.green[700]
                                          : Colors.red[700],
                                    ),
                                        p: TextStyle(
                                          fontSize: 15,
                                          height: 1.4,
                                          color: textColor,
                                        ),
                                        listBullet: TextStyle(
                                          fontSize: 15,
                                          color: isDarkMode
                                              ? Colors.grey[300]
                                              : Colors.grey[700],
                                        ),
                                        blockquote: TextStyle(
                                          fontSize: 15,
                                          fontStyle: FontStyle.italic,
                                          color: isDarkMode
                                              ? Colors.grey[400]
                                              : Colors.grey[600],
                                        ),
                                        horizontalRuleDecoration: BoxDecoration(
                                          border: Border(
                                            top: BorderSide(
                                              width: 1.0,
                                              color: isDarkMode
                                                  ? Colors.grey[700]!
                                                  : Colors.grey[300]!,
                                            ),
                                          ),
                                        ),
                                        tableHead: const TextStyle(fontWeight: FontWeight.w600),
                                        tableBody: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                        ),
                      ),
                    ),
                  ),

                  // 底部按钮区
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: isDarkMode 
                            ? [
                                const Color(0xFF2C2C2E).withOpacity(0.8),
                                const Color(0xFF1C1C1E),
                              ]
                            : [
                                Colors.grey[50]!.withOpacity(0.8),
                                Colors.white,
                              ],
                      ),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                      border: Border(
                        top: BorderSide(
                          color: isDarkMode 
                              ? Colors.grey[700]!.withOpacity(0.3)
                              : Colors.grey[300]!.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 关闭按钮美化
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                primaryColor,
                                primaryColor.withOpacity(0.8),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              setState(() {
                                _showThinkingProcess = false;
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 48, vertical: 16),
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.check_circle_rounded, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  '完成',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // 生成模拟的AI分析结果（仅用于演示或API不可用时的备用）
  String _generateSimulatedAnalysis() {
    final isBuy = _tradeType == TradeType.buy;
    final stockName = _stockNameController.text;
    final stockCode = _stockCodeController.text;
    final marketPhase = _selectedMarketPhase;
    final trendStrength = _selectedTrendStrength;
    final entryDifficulty = _selectedEntryDifficulty;
    final triggerType = _selectedTriggerType;

    // 获取所有价格相关参数
    final planPrice = double.tryParse(_planPriceController.text) ?? 0.0;
    final stopLossPrice = double.tryParse(_stopLossPriceController.text) ?? 0.0;
    final takeProfitPrice =
        double.tryParse(_takeProfitPriceController.text) ?? 0.0;
    final profitRiskRatio = _profitRiskRatio;

    // 获取仓位管理参数
    final positionPercentage =
        double.tryParse(_positionPercentageController.text) ?? 0.0;
    final accountTotal = double.tryParse(_accountTotalController.text) ?? 0.0;
    final quantity = int.tryParse(_planQuantityController.text) ?? 0;
    final positionAmount = planPrice * quantity;

    // 获取风险控制参数
    final atrValue = double.tryParse(_atrValueController.text) ?? 0.0;
    final atrMultiple = double.tryParse(_atrMultipleController.text) ?? 0.0;
    final riskPercentage =
        double.tryParse(_riskPercentageController.text) ?? 0.0;
    final atrToleranceRatio = calculateToleranceRatio();

    // 交易理由
    final reason = _reasonController.text;

    // 策略信息
    final strategyName = _selectedStrategy?.name ?? '未指定策略';

    // 计算成功率 - 使用真实参数动态计算
    int baseSuccessRate = 50; // 基础成功率
    String successRateColor = "orange"; // 默认颜色

    // 根据交易方向和市场阶段调整成功率
    if (isBuy) {
      if (marketPhase == MarketPhase.rising) {
        baseSuccessRate += 15;
        if (trendStrength == TrendStrength.strong) baseSuccessRate += 5;
      } else if (marketPhase == MarketPhase.buildingBottom) {
        baseSuccessRate += 5;
      } else if (marketPhase == MarketPhase.consolidation) {
        baseSuccessRate += 2; // 盘整阶段买入风险中性，略微加分
      } else if (marketPhase == MarketPhase.topping) {
        baseSuccessRate -= 10;
      } else {
        // falling
        baseSuccessRate -= 20;
      }
    } else {
      // 卖出
      if (marketPhase == MarketPhase.falling) {
        baseSuccessRate += 15;
        if (trendStrength == TrendStrength.strong) baseSuccessRate += 5;
      } else if (marketPhase == MarketPhase.topping) {
        baseSuccessRate += 5;
      } else if (marketPhase == MarketPhase.consolidation) {
        baseSuccessRate += 2; // 盘整阶段卖出风险中性，略微加分
      } else if (marketPhase == MarketPhase.buildingBottom) {
        baseSuccessRate -= 10;
      } else {
        // rising
        baseSuccessRate -= 20;
      }
    }

    // 根据盈亏比调整成功率
    if (profitRiskRatio >= 3) {
      baseSuccessRate += 10;
    } else if (profitRiskRatio >= 2) {
      baseSuccessRate += 5;
    } else if (profitRiskRatio < 1) {
      baseSuccessRate -= 10;
    }

    // 根据ATR设置调整
    if (atrValue > 0) {
      if (atrMultiple < 1.0 || atrMultiple > 2.5) {
        baseSuccessRate -= 5;
      } else {
        baseSuccessRate += 5;
      }
    }

    // 根据仓位比例调整
    if (positionPercentage > 20) {
      baseSuccessRate -= 10;
    } else if (positionPercentage <= 5) {
      baseSuccessRate += 5;
    }

    // 根据入场难度调整
    if (entryDifficulty == EntryDifficulty.veryHard) {
      baseSuccessRate -= 10;
    } else if (entryDifficulty == EntryDifficulty.veryEasy) {
      baseSuccessRate += 5;
    }

    // 检查价格设置合理性
    bool priceSettingReasonable = true;
    if (isBuy) {
      if (stopLossPrice >= planPrice || takeProfitPrice <= planPrice) {
        priceSettingReasonable = false;
      }
    } else {
      if (stopLossPrice <= planPrice || takeProfitPrice >= planPrice) {
        priceSettingReasonable = false;
      }
    }

    if (!priceSettingReasonable) {
      baseSuccessRate -= 15;
    }

    // 确保成功率在合理范围内
    baseSuccessRate = baseSuccessRate.clamp(15, 85);

    // 设置成功率颜色
    if (baseSuccessRate >= 60) {
      successRateColor = "green";
    } else if (baseSuccessRate >= 40) {
      successRateColor = "orange";
    } else {
      successRateColor = "red";
    }

    String successRate = "$baseSuccessRate%";
    List<String> suggestions = [];
    List<String> warnings = [];
    List<String> strengths = [];

    // 1. 根据交易方向和市场阶段评估
    if (isBuy) {
      if (marketPhase == MarketPhase.rising) {
        if (trendStrength == TrendStrength.strong) {
          strengths.add("强势上升趋势中买入，方向明确");
        } else {
          strengths.add("上升趋势中买入，方向正确");
        }
      } else if (marketPhase == MarketPhase.buildingBottom) {
        strengths.add("筑底阶段买入，有较好的风险收益比");
        suggestions.add("筑底阶段建议分批建仓降低风险");
      } else if (marketPhase == MarketPhase.consolidation) {
        suggestions.add("盘整阶段买入，建议等待突破确认信号");
        suggestions.add("盘整期间建议分批建仓，控制单次投入");
      } else if (marketPhase == MarketPhase.topping) {
        warnings.add("顶部区域买入风险较高，建议谨慎");
      } else {
        // falling
        warnings.add("下跌趋势中买入违背趋势，成功率低");
      }
    } else {
      // 卖出
      if (marketPhase == MarketPhase.falling) {
        if (trendStrength == TrendStrength.strong) {
          strengths.add("强势下跌趋势中卖出，方向明确");
        } else {
          strengths.add("下跌趋势中卖出，方向正确");
        }
      } else if (marketPhase == MarketPhase.topping) {
        strengths.add("顶部区域卖出，把握高位机会");
      } else if (marketPhase == MarketPhase.consolidation) {
        suggestions.add("盘整阶段卖出，建议等待跌破确认信号");
        suggestions.add("盘整期间可分批减仓，保留核心仓位");
      } else if (marketPhase == MarketPhase.buildingBottom) {
        warnings.add("筑底阶段卖出风险较高，可能错过反弹");
      } else {
        // rising
        warnings.add("上升趋势中卖出违背趋势，成功率低");
      }
    }

    // 2. 评估盈亏比
    if (profitRiskRatio >= 3) {
      strengths.add("盈亏比(${profitRiskRatio.toStringAsFixed(1)})优秀，风险回报率高");
    } else if (profitRiskRatio >= 2) {
      strengths.add("盈亏比(${profitRiskRatio.toStringAsFixed(1)})良好，符合交易标准");
    } else if (profitRiskRatio >= 1) {
      suggestions.add("盈亏比(${profitRiskRatio.toStringAsFixed(1)})偏低，建议调整止盈位置");
    } else {
      warnings.add("盈亏比(${profitRiskRatio.toStringAsFixed(1)})过低，不符合风险管理原则");
    }

    // 检查盈亏比是否不合理（过高）
    if (profitRiskRatio > 10) {
      warnings
          .add("盈亏比(${profitRiskRatio.toStringAsFixed(1)})异常高，请检查止盈止损设置是否合理");
    }

    // 3. 根据ATR评估止损设置
    if (atrValue > 0) {
      final stopLossDistance = (planPrice - stopLossPrice).abs();
      final theoreticalDistance = atrValue * atrMultiple;

      if (atrMultiple < 1.0) {
        warnings.add("ATR倍数(${atrMultiple.toStringAsFixed(1)})偏小，止损距离可能过紧");
      } else if (atrMultiple > 2.5) {
        warnings.add("ATR倍数(${atrMultiple.toStringAsFixed(1)})过大，单笔风险较高");
      } else {
        strengths.add("ATR倍数(${atrMultiple.toStringAsFixed(1)})合理，符合波动特性");
      }

      if (atrToleranceRatio < 0.8) {
        warnings.add("止损距离(${stopLossDistance.toStringAsFixed(2)})过紧，容易被震出局");
      } else if (atrToleranceRatio > 1.2) {
        suggestions.add("止损距离(${stopLossDistance.toStringAsFixed(2)})偏宽，可适当调整");
      } else {
        strengths.add("止损设置合理，与市场波动匹配");
      }
    }

    // 4. 评估仓位管理
    if (positionPercentage > 10) {
      warnings
          .add("仓位比例(${positionPercentage.toStringAsFixed(1)}%)偏大，建议控制在10%以内");
    } else if (positionPercentage <= 5) {
      strengths.add("仓位比例(${positionPercentage.toStringAsFixed(1)}%)保守，风险可控");
    } else {
      strengths.add("仓位比例(${positionPercentage.toStringAsFixed(1)}%)适中，符合风险管理");
    }

    // 检查仓位是否过大（超过20%）
    if (positionPercentage > 20) {
      warnings
          .add("仓位比例(${positionPercentage.toStringAsFixed(1)}%)过高，存在严重风险，建议降低");
    }

    // 5. 评估风险熔断设置
    if (riskPercentage > 2) {
      warnings.add("风险熔断比例(${riskPercentage.toStringAsFixed(1)}%)偏高，建议控制在2%以内");
    } else if (riskPercentage > 0) {
      strengths.add("风险熔断设置合理，有效控制单笔亏损");
    }

    // 6. 根据入场难度评估
    if (entryDifficulty == EntryDifficulty.veryHard ||
        entryDifficulty == EntryDifficulty.hard) {
      suggestions.add("入场难度较高，建议耐心等待更明确的信号");
    }

    // 7. 评估触发价类型
    if (triggerType == PriceTriggerType.breakout) {
      suggestions.add("突破入场策略，建议确认成交量配合");
    } else {
      suggestions.add("回调入场策略，注意确认支撑位有效性");
    }

    // 8. 检查价格设置的合理性
    if (isBuy) {
      if (stopLossPrice >= planPrice) {
        warnings.add(
            "买入止损价(${stopLossPrice.toStringAsFixed(2)})高于计划价(${planPrice.toStringAsFixed(2)})，设置不合理");
      }
      if (takeProfitPrice <= planPrice) {
        warnings.add(
            "买入目标价(${takeProfitPrice.toStringAsFixed(2)})低于计划价(${planPrice.toStringAsFixed(2)})，设置不合理");
      }
    } else {
      if (stopLossPrice <= planPrice) {
        warnings.add(
            "卖出止损价(${stopLossPrice.toStringAsFixed(2)})低于计划价(${planPrice.toStringAsFixed(2)})，设置不合理");
      }
      if (takeProfitPrice >= planPrice) {
        warnings.add(
            "卖出目标价(${takeProfitPrice.toStringAsFixed(2)})高于计划价(${planPrice.toStringAsFixed(2)})，设置不合理");
      }
    }

    // 10. 基于交易理由的分析
    if (reason.contains("突破") || reason.contains("阻力")) {
      suggestions.add("突破交易需确认成交量配合，防止假突破");
    }
    if (reason.contains("支撑") || reason.contains("反弹")) {
      suggestions.add("支撑位交易需确认企稳信号，设置紧止损");
    }
    if (reason.contains("趋势") || reason.contains("均线")) {
      strengths.add("趋势跟踪交易符合技术分析原则");
    }

    // 生成分析结果 - 标准化格式
    String analysisResult = "";

    // 【分析结论】- 标准化格式
    analysisResult += "# 【分析结论】\n\n";
    
    // 1. 交易成功率评估 - 突出显示
    analysisResult += "## 🎯 交易成功率评估\n\n";
    analysisResult += "**预估成功率：$successRate**\n\n";

    // 根据成功率给出明确建议
    if (baseSuccessRate >= 70) {
      analysisResult += "✅ **建议执行交易** - 成功率较高，交易计划合理\n\n";
    } else if (baseSuccessRate >= 50) {
      analysisResult += "⚠️ **谨慎执行交易** - 成功率中等，需要密切关注风险\n\n";
    } else {
      analysisResult += "❌ **不建议执行交易** - 成功率偏低，建议重新调整参数\n\n";
      }

    // 2. 参数优化建议 - 标准化格式
    analysisResult += "## 📊 参数优化建议\n\n";

    if (warnings.isNotEmpty) {
      analysisResult += "### ⚠️ 风险提示\n";
      for (var item in warnings) {
        analysisResult += "* $item\n";
      }
      analysisResult += "\n";
    }

    if (suggestions.isNotEmpty) {
      analysisResult += "### 💡 优化建议\n";
      for (var item in suggestions) {
        analysisResult += "* $item\n";
      }
      analysisResult += "\n";
    }

    if (strengths.isNotEmpty) {
      analysisResult += "### ✅ 计划优势\n";
      for (var item in strengths) {
        analysisResult += "* $item\n";
      }
      analysisResult += "\n";
    }

    // 3. 交易决策建议 - 标准化格式
    analysisResult += "## 🎯 交易决策建议\n\n";
    
    // 明确的执行建议
    if (baseSuccessRate >= 70) {
      analysisResult += "### 📈 建议执行\n";
      analysisResult += "* **执行建议：** 建议按计划执行交易\n";
      analysisResult += "* **关键优势：** 成功率较高，风险可控\n";
      analysisResult += "* **注意事项：** 严格执行止损止盈，密切关注市场变化\n\n";
    } else if (baseSuccessRate >= 50) {
      analysisResult += "### ⚖️ 谨慎执行\n";
      analysisResult += "* **执行建议：** 可以执行但需要谨慎操作\n";
      analysisResult += "* **风险控制：** 降低仓位，加强止损管理\n";
      analysisResult += "* **监控要点：** 密切关注市场趋势变化\n\n";
    } else {
      analysisResult += "### 🚫 不建议执行\n";
      analysisResult += "* **执行建议：** 不建议按当前参数执行交易\n";
      analysisResult += "* **主要问题：** 成功率过低，风险过高\n";
      analysisResult += "* **修改方案：** 建议重新调整交易参数后再考虑\n\n";
    }
    
    // 4. 交易策略改进建议 - 标准化格式
    analysisResult += "## 🔧 交易策略改进建议\n\n";
    analysisResult += "基于您当前的策略**$strategyName**，以下是具体改进建议：\n\n";

    // 根据成功率和其他参数生成策略建议
    if (baseSuccessRate < 40) {
      analysisResult += "#### 1. 核心问题\n";
      analysisResult += "您当前的交易计划成功率较低，主要原因是：\n";

      if (isBuy && marketPhase == MarketPhase.falling) {
        analysisResult += "* 在下跌趋势中逆势做多，违背了\"顺势而为\"原则\n";
      } else if (!isBuy && marketPhase == MarketPhase.rising) {
        analysisResult += "* 在上升趋势中逆势做空，违背了\"顺势而为\"原则\n";
      }

      if (profitRiskRatio < 1) {
        analysisResult += "* 盈亏比过低，不符合基本的风险管理原则\n";
      }

      if (!priceSettingReasonable) {
        analysisResult += "* 价格设置不合理，止损或目标价设置有误\n";
      }

      analysisResult += "\n#### 2. 改进建议\n";
      analysisResult += "* 严格遵循\"顺势而为\"原则，只在趋势方向交易\n";
      analysisResult += "* 确保盈亏比至少大于1.5，理想值为2.0以上\n";
      analysisResult += "* 使用技术指标确认趋势，例如均线组合、趋势线等\n";
      analysisResult += "* 考虑增加交易确认条件，比如成交量配合、关键价位突破等\n";
    } else {
      analysisResult += "#### 1. 优化方向\n";

      if (baseSuccessRate >= 60) {
        analysisResult += "您的交易计划整体评分较高，可以在以下方面进一步优化：\n";
      } else {
        analysisResult += "您的交易计划整体表现中等，可以在以下方面进行优化：\n";
      }

      // 根据入场条件给出建议
      analysisResult += "* **入场条件：** ";
      if (triggerType == PriceTriggerType.breakout) {
        analysisResult += "对于突破入场策略，建议增加成交量过滤条件，例如突破时成交量至少大于前5日平均的1.5倍\n";
      } else {
        analysisResult += "对于回调入场策略，建议增加支撑确认条件，例如价格在支撑位回调时出现阳包阴或十字星形态\n";
      }

      // 仓位管理建议
      analysisResult += "* **仓位管理：** ";
      if (positionPercentage > 10) {
        analysisResult += "当前仓位偏大，建议分批建仓，例如首次使用50%计划仓位，确认趋势后再加仓剩余部分\n";
      } else if (baseSuccessRate >= 70) {
        analysisResult += "在高成功率的情况下，可以适当增加仓位，但单笔交易总风险不应超过账户的2%\n";
      } else {
        analysisResult += "当前仓位设置合理，建议保持仓位纪律，无论交易结果如何都坚持执行\n";
      }

      // 止损策略建议
      analysisResult += "* **止损策略：** ";
      if (atrToleranceRatio < 0.8) {
        analysisResult += "当前止损距离过小，建议将ATR倍数调整到1.5-2.0范围内，避免被市场波动洗出\n";
      } else if (atrToleranceRatio > 1.5) {
        analysisResult += "当前止损距离较大，可考虑使用跟踪止损，例如价格每上涨10%，将止损上移5%\n";
      } else {
        analysisResult += "止损设置合理，建议增加时间止损规则，例如如果3-5个交易日内未出现预期走势，考虑退出交易\n";
      }
    }

    // 增加具体执行建议
    analysisResult += "\n### 📋 执行要点\n";
    analysisResult += "* 制定明确的交易计划并严格执行\n";
    analysisResult += "* 每笔交易前进行检查清单确认，确保符合策略要求\n";
    analysisResult += "* 建立交易日志，记录每笔交易的决策理由和结果\n";
    analysisResult += "* 定期回测和评估策略表现，根据市场变化调整参数\n\n";
    
    // 添加风险提示
    analysisResult += "---\n";
    analysisResult += "**⚠️ 风险提示：** 以上分析仅供参考，实际交易请结合市场情况和个人风险承受能力谨慎决策。\n";

    // 生成思考过程
    String thinkingProcess = """## 思考过程

我分析了$stockCode $stockName的交易计划，根据以下几个方面进行评估：

### 市场趋势分析
* 用户选择的市场阶段是${_getMarketPhaseText()}，趋势强度为${_getTrendStrengthText()}
* ${isBuy ? '买入' : '卖出'}方向与当前趋势${isBuy && marketPhase == MarketPhase.rising || !isBuy && marketPhase == MarketPhase.falling ? '一致' : '不一致'}
* 趋势一致性对成功率${isBuy && marketPhase == MarketPhase.rising || !isBuy && marketPhase == MarketPhase.falling ? '有正面贡献(+15%)' : '有负面影响(-15%)'}

### 交易参数合理性
* 入场价格: ${planPrice.toStringAsFixed(2)}
* 止损价格: ${stopLossPrice.toStringAsFixed(2)}
* 止盈价格: ${takeProfitPrice.toStringAsFixed(2)}
* 价格设置${priceSettingReasonable ? '合理' : '不合理，止损或止盈价方向错误'}
* ATR设置: ${atrValue.toStringAsFixed(4)} × ${atrMultiple.toStringAsFixed(1)}倍 = ${(atrValue * atrMultiple).toStringAsFixed(4)}
* ATR容差比例: ${(atrToleranceRatio * 100).toStringAsFixed(0)}%，${atrToleranceRatio >= 0.8 && atrToleranceRatio <= 1.2 ? '合理' : atrToleranceRatio < 0.8 ? '过紧' : '过松'}

### 风险收益分析
* 盈亏比: ${profitRiskRatio.toStringAsFixed(2)}，${profitRiskRatio >= 2 ? '良好(+5%)' : profitRiskRatio < 1 ? '过低(-10%)' : '一般'}
* 仓位比例: ${positionPercentage.toStringAsFixed(1)}%，${positionPercentage <= 5 ? '保守(+5%)' : positionPercentage > 20 ? '过高(-10%)' : '适中'}
* 风险熔断: ${riskPercentage.toStringAsFixed(1)}%，${riskPercentage <= 2 ? '合理' : '偏高(-5%)'}

### 交易策略评估
* 选择的策略: $strategyName
* 策略与市场环境匹配度: ${isBuy && marketPhase == MarketPhase.rising || !isBuy && marketPhase == MarketPhase.falling ? '高' : '低'}
* 入场条件: ${triggerType == PriceTriggerType.breakout ? '突破型' : '回调型'}，在当前市场阶段${triggerType == PriceTriggerType.breakout && (marketPhase == MarketPhase.rising || marketPhase == MarketPhase.topping || marketPhase == MarketPhase.consolidation) ? '较适合' : triggerType == PriceTriggerType.pullback && (marketPhase == MarketPhase.buildingBottom || marketPhase == MarketPhase.falling) ? '较适合' : '不够匹配'}

### 成功率计算过程
* 基础成功率: 50%
* 趋势一致性调整: ${isBuy && marketPhase == MarketPhase.rising || !isBuy && marketPhase == MarketPhase.falling ? '+15%' : '-15%'}
* 趋势强度调整: ${trendStrength == TrendStrength.strong ? '+5%' : '0%'}
* 盈亏比调整: ${profitRiskRatio >= 3 ? '+10%' : profitRiskRatio >= 2 ? '+5%' : profitRiskRatio < 1 ? '-10%' : '0%'}
* ATR设置调整: ${atrValue > 0 ? (atrMultiple >= 1.0 && atrMultiple <= 2.5 ? '+5%' : '-5%') : '0%'}
* 仓位比例调整: ${positionPercentage <= 5 ? '+5%' : positionPercentage > 20 ? '-10%' : '0%'}
* 入场难度调整: ${entryDifficulty == EntryDifficulty.veryHard ? '-10%' : entryDifficulty == EntryDifficulty.veryEasy ? '+5%' : '0%'}
* 价格设置合理性: ${priceSettingReasonable ? '0%' : '-15%'}
* 最终成功率: $successRate
""";

    // 同时更新分析结果和思考过程变量
    _aiThinkingProcess = thinkingProcess;

    return analysisResult;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF000000) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          '添加交易计划',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: Container(
          width: 40,
          height: 40,
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDarkMode 
                ? Colors.white.withOpacity(0.1) 
                : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _hasAnalyzed 
                    ? [const Color(0xFF4CAF50), const Color(0xFF45A049)]
                    : [const Color(0xFF667EEA), const Color(0xFF764BA2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: (_hasAnalyzed ? Colors.green : const Color(0xFF667EEA)).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    _hasAnalyzed ? Icons.check_circle : Icons.psychology,
                    color: Colors.white,
                    size: 24,
                  ),
                  tooltip: 'AI交易分析',
                  onPressed: _isAnalyzing ? null : _analyzeTradeWithAI,
                ),
                if (!_hasAnalyzed)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildModernStockSection(),
                const SizedBox(height: 20),
                if (_showKLineChart) _buildModernKLineChart(),
                if (_showKLineChart) const SizedBox(height: 20),
                _buildModernMarketPhaseSection(),
                const SizedBox(height: 20),
                _buildModernTradeDetailsSection(),
                const SizedBox(height: 20),
                _buildModernStrategySection(),
                const SizedBox(height: 20),
                _buildModernRiskControlSection(),
                const SizedBox(height: 20),
                _buildModernReasonSection(),
                const SizedBox(height: 20),
                _buildModernNotesSection(),
                const SizedBox(height: 32),
                _buildModernActionButtons(),
                const SizedBox(height: 20),
              ],
            ),
            // AI分析加载遮罩
            if (_isAnalyzing) _buildAnalyzingOverlay(),
            // AI分析结果对话框触发器
            if (_showAiAnalysis && !_isAnalyzing)
              Builder(builder: (context) {
                Future.microtask(() {
                  setState(() {
                    _showAiAnalysis = false;
                  });
                  _showAIAnalysisDialog();
                });
                return const SizedBox.shrink();
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildModernStockSection() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Consumer<StockProvider>(builder: (context, stockProvider, child) {
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.search,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      '股票选择',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDarkMode 
                            ? Colors.grey.shade800.withOpacity(0.3)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.grey.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                    child: TextFormField(
                      controller: _stockCodeController,
                      decoration: InputDecoration(
                        labelText: '股票代码',
                          hintText: '输入股票代码或名称搜索',
                          prefixIcon: const Icon(Icons.search, color: Colors.indigo, size: 20),
                        suffixIcon: stockProvider.isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                            : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入股票代码';
                        }
                        return null;
                      },
                    ),
                  ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF667EEA).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF667EEA).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.refresh, color: Color(0xFF667EEA)),
                    tooltip: '刷新股票数据库',
                    onPressed: _refreshStockDatabase,
                    ),
                  ),
                ],
              ),
              
              // 搜索结果
              if (_isLoading) ...[
                const SizedBox(height: 16),
                const Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 8),
                      Text('搜索中...', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ] else if (_stockSuggestions.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: isDarkMode 
                        ? Colors.grey.shade800.withOpacity(0.3)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.grey.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _stockSuggestions.length,
                    itemBuilder: (context, index) {
                      final stock = _stockSuggestions[index];
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                        onTap: () => _selectStock(stock),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF667EEA).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    stock['code'],
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF667EEA),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        stock['name'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (stock['market'] != null)
                                        Text(
                                          _getMarketDisplayName(stock['market']),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              
                            // 股票名称输入框已隐藏，因为在股票代码输入框中已经显示了股票名称
            ],
          ),
        ),
      );
    });
  }

  Widget _buildAnalyzingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          margin: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.white, Color(0xFFF8F9FA)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
        padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF667EEA).withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.psychology,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF667EEA)),
                strokeWidth: 3,
              ),
              const SizedBox(height: 20),
              const Text(
                'AI正在分析交易计划',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '正在分析市场趋势、技术指标和风险因素\n大概需要10-20秒,请耐心等待...',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          ),
        ),
      );
  }

  Widget _buildModernActionButtons() {
    return Column(
      children: [
        // AI分析和保存按钮
        Row(
          children: [
            Expanded(
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _hasAnalyzed 
                        ? [const Color(0xFF4CAF50), const Color(0xFF45A049)]
                        : [const Color(0xFF667EEA), const Color(0xFF764BA2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: (_hasAnalyzed ? Colors.green : const Color(0xFF667EEA)).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _isAnalyzing || _isLoading ? null : _analyzeTradeWithAI,
                  icon: Icon(
                    _hasAnalyzed ? Icons.check_circle : Icons.psychology,
                    color: Colors.white,
                    size: 20,
                  ),
                  label: Text(
                    _hasAnalyzed ? 'AI分析完成' : 'AI建仓分析',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _submitForm,
                    icon: _isLoading  
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.save, color: Colors.white, size: 20),
                  label: Text(
                    _isLoading ? '保存中...' : '保存计划',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModernTradeDetailsSection() {
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.tune,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    '交易细节',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 添加实时预览区域
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('实时预览',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildPreviewItem(
                          '交易方向',
                          _tradeType == TradeType.buy ? '买入' : '卖出',
                          _tradeType == TradeType.buy
                              ? const Color(0xFFDC2626) // A股红色：买入
                              : const Color(0xFF059669), // A股绿色：卖出
                        ),
                      ),
                      Expanded(
                        child: _buildPreviewItem(
                          '入场价格',
                          _planPriceController.text.isEmpty
                              ? '未设置'
                              : '¥${_planPriceController.text}',
                          const Color(0xFF667EEA),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildPreviewItem(
                          '计划数量',
                          _planQuantityController.text.isEmpty
                              ? '未设置'
                              : '${_planQuantityController.text}股',
                          const Color(0xFF667EEA),
                        ),
                      ),
                      Expanded(
                        child: _buildPreviewItem(
                          '预计金额',
                          _positionAmount > 0
                              ? '¥${_positionAmount.toStringAsFixed(2)}'
                              : '未计算',
                          const Color(0xFF667EEA),
                        ),
                      ),
                    ],
                  ),
                  if (_positionAmount > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildPreviewItem(
                            '仓位比例',
                            _positionPercentageController.text.isEmpty
                                ? '未设置'
                                : '${_positionPercentageController.text}%',
                            const Color(0xFF667EEA),
                          ),
                        ),
                        Expanded(
                          child: _buildPreviewItem(
                            '账户总额',
                            _accountTotalController.text.isEmpty
                                ? '未设置'
                                : '¥${_accountTotalController.text}',
                            const Color(0xFF667EEA),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_stopLossPriceController.text.isNotEmpty &&
                      _takeProfitPriceController.text.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildPreviewItem(
                            '止损价格',
                            '¥${_stopLossPriceController.text}',
                            const Color(0xFF059669), // A股绿色：止损
                          ),
                        ),
                        Expanded(
                          child: _buildPreviewItem(
                            '止盈价格',
                            '¥${_takeProfitPriceController.text}',
                            const Color(0xFFDC2626), // A股红色：止盈价
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildPreviewItem(
                            '盈亏比',
                            _profitRiskRatio > 0
                                ? _profitRiskRatio.toStringAsFixed(2)
                                : '未计算',
                            _profitRiskRatio >= 3
                                ? const Color(0xFFDC2626) // A股红色：好的盈亏比
                                : _profitRiskRatio > 0
                                    ? Colors.orange
                                    : Colors.grey,
                          ),
                        ),
                        if (_useAtrForStopLoss &&
                            _atrValueController.text.isNotEmpty)
                          Expanded(
                            child: _buildPreviewItem(
                              'ATR倍数',
                              '${_atrMultipleController.text}倍',
                              const Color(0xFF667EEA),
                            ),
                          ),
                      ],
                    ),
                    // 添加盈亏预测显示
                    if (_canCalculateProfitLoss()) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildPreviewItem(
                              '最大盈利',
                              '+¥${_calculateMaxProfit().toStringAsFixed(2)}',
                              const Color(0xFFDC2626), // A股红色：盈利
                              Icons.trending_up,
                            ),
                          ),
                          Expanded(
                            child: _buildPreviewItem(
                              '最大亏损',
                              '-¥${_calculateMaxLoss().toStringAsFixed(2)}',
                              const Color(0xFF059669), // A股绿色：亏损
                              Icons.trending_down,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 开仓时间选择
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: ListTile(
                leading: SizedBox(
                  width: 40,
                  height: 40,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.schedule,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                title: const Text(
                  '开仓时间',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  '${_createTime.year}年${_createTime.month}月${_createTime.day}日 (${_getWeekdayName(_createTime.weekday)})',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
                trailing: const Icon(
                  Icons.calendar_today,
                  color: Color(0xFF6366F1),
                  size: 20,
                ),
                onTap: _showDatePicker,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
            const SizedBox(height: 16),

            // 进场类型选择
            Row(
              children: [
                const Text(
                  '进场类型:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 16),
                ChoiceChip(
                  label: const Text('突破'),
                  selected: _selectedTriggerType == PriceTriggerType.breakout,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedTriggerType = PriceTriggerType.breakout;
                      });
                    }
                  },
                  selectedColor: const Color(0xFFEF4444).withOpacity(0.2),
                  backgroundColor: Colors.grey.shade100,
                  labelStyle: TextStyle(
                    color: _selectedTriggerType == PriceTriggerType.breakout 
                        ? const Color(0xFFEF4444) 
                        : Colors.grey.shade700,
                    fontWeight: _selectedTriggerType == PriceTriggerType.breakout 
                        ? FontWeight.w600 
                        : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: _selectedTriggerType == PriceTriggerType.breakout 
                        ? const Color(0xFFEF4444) 
                        : Colors.grey.shade300,
                    width: 1.5,
                  ),
                ),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text('回调'),
                  selected: _selectedTriggerType == PriceTriggerType.pullback,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedTriggerType = PriceTriggerType.pullback;
                      });
                    }
                  },
                  selectedColor: const Color(0xFF3B82F6).withOpacity(0.2),
                  backgroundColor: Colors.grey.shade100,
                  labelStyle: TextStyle(
                    color: _selectedTriggerType == PriceTriggerType.pullback 
                        ? const Color(0xFF3B82F6) 
                        : Colors.grey.shade700,
                    fontWeight: _selectedTriggerType == PriceTriggerType.pullback 
                        ? FontWeight.w600 
                        : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: _selectedTriggerType == PriceTriggerType.pullback 
                        ? const Color(0xFF3B82F6) 
                        : Colors.grey.shade300,
                    width: 1.5,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 现代化仓位计算方式选择
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '仓位计算:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF667EEA).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildToggleButton('仓位比例', _positionCalculationMethod == PositionCalculationMethod.percentage, () {
                          setState(() {
                            _positionCalculationMethod = PositionCalculationMethod.percentage;
                          });
                        }),
                      ),
                      Expanded(
                        child: _buildToggleButton('股票数量', _positionCalculationMethod == PositionCalculationMethod.quantity, () {
                          setState(() {
                            _positionCalculationMethod = PositionCalculationMethod.quantity;
                            // 切换到股票数量模式时，清空数量输入框，避免自动填入计算值
                            if (_planQuantityController.text == '0' || _planQuantityController.text.isEmpty) {
                              _planQuantityController.clear();
                            }
                          });
                        }),
                      ),
                      Expanded(
                        child: _buildToggleButton('以损定仓', _positionCalculationMethod == PositionCalculationMethod.riskBased, () {
                          setState(() {
                            _positionCalculationMethod = PositionCalculationMethod.riskBased;
                            // 切换到以损定仓模式时，清空数量输入框，避免自动填入计算值
                            if (_planQuantityController.text == '0' || _planQuantityController.text.isEmpty) {
                              _planQuantityController.clear();
                            }
                          });
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF667EEA).withOpacity(0.1),
                    const Color(0xFF667EEA).withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF667EEA).withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF667EEA).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.info_outline,
                      color: Color(0xFF667EEA),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _positionCalculationMethod == PositionCalculationMethod.percentage
                          ? '输入仓位比例后，系统将自动计算可买入的股票数量（A股最小单位为100股）'
                          : _positionCalculationMethod == PositionCalculationMethod.quantity
                              ? '输入股票数量后，系统将自动计算对应的仓位比例（A股最小单位为100股）'
                              : '根据账户总额、可自定义风险比例和止损价格，系统将自动计算仓位大小（以损定仓）',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF667EEA),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 现代化账户总额输入
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: TextFormField(
                controller: _accountTotalController,
                decoration: const InputDecoration(
                  labelText: '账户总额',
                  hintText: '输入账户总资金',
                  prefixIcon: Icon(Icons.account_balance_wallet, color: Colors.amber, size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) {
                  if (_positionCalculationMethod == PositionCalculationMethod.percentage) {
                    _calculatePosition();
                  } else {
                    _saveAccountTotal();
                  }
                },
                onEditingComplete: _saveAccountTotal,
              ),
            ),
                          const SizedBox(height: 16),

              // 风险比例输入框（以损定仓模式下显示）
              if (_positionCalculationMethod == PositionCalculationMethod.riskBased) ...[
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  child: TextFormField(
                    controller: _riskPercentageController,
                    decoration: const InputDecoration(
                      labelText: '风险比例(%)',
                      hintText: '输入可承受的风险比例（默认2%）',
                      prefixIcon: Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) {
                      _calculatePosition();
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (_positionCalculationMethod == PositionCalculationMethod.percentage) ...[
                Container(
                  decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.grey.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: TextFormField(
                  controller: _positionPercentageController,
                  decoration: const InputDecoration(
                    labelText: '仓位比例(%)',
                    hintText: '输入仓位比例',
                    prefixIcon: Icon(Icons.pie_chart, color: Colors.deepOrange, size: 20),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) {
                    _calculatePosition();
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            Container(
              decoration: BoxDecoration(
                color: _positionCalculationMethod == PositionCalculationMethod.quantity 
                    ? Colors.grey.shade100 
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: TextFormField(
                controller: _planQuantityController,
                decoration: const InputDecoration(
                  labelText: '计划数量',
                  hintText: '输入计划数量',
                  prefixIcon: Icon(Icons.format_list_numbered, color: Colors.purple, size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                keyboardType: TextInputType.number,
                enabled: _positionCalculationMethod == PositionCalculationMethod.quantity, // 使用仓位比例时禁用手动输入
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入计划数量';
                  }
                  if (int.tryParse(value) == null) {
                    return '请输入有效的数量';
                  }
                  final quantity = int.parse(value);
                  if (quantity % 100 != 0) {
                    return '数量必须是100的整数倍';
                  }
                  return null;
                },
                onEditingComplete: () {
                  // 输入完成时进行100股整数倍调整
                  if (_positionCalculationMethod == PositionCalculationMethod.quantity) {
                    final value = _planQuantityController.text.trim();
                    if (value.isNotEmpty) {
                      final quantity = int.tryParse(value) ?? 0;
                      if (quantity > 0) {
                        final adjustedQuantity = (quantity ~/ 100) * 100;
                        if (adjustedQuantity != quantity && adjustedQuantity > 0) {
                          setState(() {
                            _planQuantityController.text = adjustedQuantity.toString();
                          });
                          // 调整后重新计算
                          final planPrice = double.tryParse(_planPriceController.text) ?? 0.0;
                          final accountTotal = double.tryParse(_accountTotalController.text) ?? 0.0;
                          if (planPrice > 0) {
                            final positionAmount = adjustedQuantity * planPrice;
                            setState(() {
                              _positionAmount = positionAmount;
                              if (accountTotal > 0) {
                                final positionPercentage = (positionAmount / accountTotal) * 100;
                                _positionPercentageController.text = positionPercentage.toStringAsFixed(2);
                              }
                            });
                          }
                        }
                      }
                    }
                  }
                },
                onChanged: (value) {
                  if (_positionCalculationMethod == PositionCalculationMethod.quantity) {
                    // 股票数量模式：只计算交易金额和仓位比例，不调整数量
                    if (value.trim().isNotEmpty) {
                      final quantity = int.tryParse(value) ?? 0;
                      final planPrice = double.tryParse(_planPriceController.text) ?? 0.0;
                      final accountTotal = double.tryParse(_accountTotalController.text) ?? 0.0;
                      
                      if (quantity > 0 && planPrice > 0) {
                        final positionAmount = quantity * planPrice;
                        setState(() {
                          _positionAmount = positionAmount;
                          if (accountTotal > 0) {
                            final positionPercentage = (positionAmount / accountTotal) * 100;
                            _positionPercentageController.text = positionPercentage.toStringAsFixed(2);
                          }
                        });
                      }
                    } else {
                      // 输入为空时，清空相关计算结果
                      setState(() {
                        _positionPercentageController.text = '';
                        _positionAmount = 0.0;
                      });
                    }
                  } else if (_positionCalculationMethod == PositionCalculationMethod.percentage) {
                    // 仓位比例模式下，根据比例自动计算数量
                    _calculatePosition();
                  } else if (_positionCalculationMethod == PositionCalculationMethod.riskBased) {
                    // 以损定仓模式下，根据止损金额计算数量
                    _calculatePosition();
                  }
                  setState(() {}); // 触发界面更新
                },
              ),
            ),
            const SizedBox(height: 16),

            // 现代化预计交易金额显示
            if (_positionAmount > 0)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFF59E0B).withOpacity(0.12), // 金色渐变
                      const Color(0xFFD97706).withOpacity(0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFF59E0B),
                            const Color(0xFFD97706),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF59E0B).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '预计交易金额',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '¥${_positionAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                              color: Color(0xFFD97706),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 添加一个小的百分比指示器
                    if (_accountTotalController.text.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${(_positionAmount / (double.tryParse(_accountTotalController.text) ?? 1) * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFD97706),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // ATR设置部分
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('止损价设置:'),
                Row(
                  children: [
                    const Text('使用ATR'),
                    Switch(
                      value: _useAtrForStopLoss,
                      onChanged: (value) {
                        setState(() {
                          _useAtrForStopLoss = value;
                          if (value) {
                            _calculateStopLossFromATR();
                          }
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_useAtrForStopLoss) ...[
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _atrValueController,
                      decoration: InputDecoration(
                        labelText: 'ATR值',
                        hintText: 'ATR值（自动计算）',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.analytics, color: Colors.blue, size: 20),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.blue),
                          tooltip: '自动获取ATR值',
                          onPressed: _stockCodeController.text.isNotEmpty
                              ? () => _fetchStockATR(_stockCodeController.text)
                              : null,
                        ),
                      ),
                      readOnly: true, // ATR是自动计算的
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _atrMultipleController,
                      decoration: const InputDecoration(
                        labelText: 'ATR倍数',
                        hintText: '输入ATR倍数',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.tune, color: Colors.orange, size: 20),
                        helperText: '建议值: 0.8-2.0倍',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        // 检查是否输入了过大的值
                        final double? parsedValue = double.tryParse(value);
                        if (parsedValue != null) {
                          if (parsedValue > 2.0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('警告: A股日线级别ATR倍数超过2.0倍通常偏大，止损距离较宽'),
                                backgroundColor: Colors.orange,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                          if (parsedValue > 3.0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    '警告: A股日线级别ATR倍数超过3.0倍已经非常大，不推荐用于短线交易'),
                                backgroundColor: Colors.red,
                                duration: Duration(seconds: 3),
                              ),
                            );
                          }
                          if (parsedValue < 0.8) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('提示: ATR倍数低于0.8倍可能导致止损距离过小，容易被震出局'),
                                backgroundColor: Colors.blue,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        }

                        // 强制重新计算并更新UI
                        setState(() {
                          print('ATR倍数改变为: $value');
                          _calculateStopLossFromATR();
                          // 手动更新容差比例值用于调试
                          _atrToleranceRatio = calculateToleranceRatio();
                          // 触发风险熔断重新计算
                        });
                      },
                      // 限制输入长度，防止输入过大的值
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d{0,1}(\.\d{0,2})?$')),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // 入场价格字段
            TextFormField(
              controller: _planPriceController,
              decoration: const InputDecoration(
                labelText: '入场价格',
                hintText: '输入入场价格',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.login, color: Colors.green, size: 20),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入入场价格';
                }
                if (double.tryParse(value) == null) {
                  return '请输入有效的价格';
                }
                return null;
              },
              onChanged: (_) {
                _calculateProfitRiskRatio();
                if (_useAtrForStopLoss) {
                  _calculateStopLossFromATR();
                }
                if (_positionCalculationMethod == PositionCalculationMethod.percentage) {
                  _calculatePosition();
                }
                setState(() {}); // 触发风险熔断重新计算
              },
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _stopLossPriceController,
                    decoration: const InputDecoration(
                      labelText: '止损价格',
                      hintText: '输入止损价格',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.trending_down, color: Colors.red, size: 20),
                    ),
                    keyboardType: TextInputType.number,
                    enabled: !_useAtrForStopLoss, // 使用ATR时禁用手动输入
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入止损价格';
                      }
                      if (double.tryParse(value) == null) {
                        return '请输入有效的价格';
                      }
                      return null;
                    },
                    onChanged: (_) {
                      _calculateProfitRiskRatio();
                      _updateATRToleranceRatio();
                      setState(() {}); // 触发风险熔断重新计算
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _takeProfitPriceController,
                    decoration: const InputDecoration(
                      labelText: '止盈价格',
                      hintText: '输入止盈价格',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.trending_up, color: Color(0xFFDC2626), size: 20),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入止盈价格';
                      }
                      if (double.tryParse(value) == null) {
                        return '请输入有效的价格';
                      }
                      return null;
                    },
                    onChanged: (_) {
                      _calculateProfitRiskRatio();
                      setState(() {}); // 触发风险熔断重新计算
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 现代化盈亏比显示
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _getRiskRewardGradientColors(),
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
              ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _getRiskRewardBorderColor().withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                      color: _getRiskRewardBorderColor().withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _profitRiskRatio >= 3
                          ? Icons.check_circle
                          : _profitRiskRatio >= 2
                              ? Icons.trending_up
                              : _profitRiskRatio >= 1
                                  ? Icons.warning
                      : _profitRiskRatio > 0
                                      ? Icons.error_outline
                                      : Icons.calculate,
                      color: _getRiskRewardBorderColor(),
                      size: 24,
                ),
              ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                        const Text(
                          '盈亏比',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                  Text(
                    _profitRiskRatio > 0
                        ? _profitRiskRatio.toStringAsFixed(2)
                        : '未计算',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                                fontSize: 24,
                                color: _getRiskRewardBorderColor(),
                              ),
                            ),
                            const SizedBox(width: 8),
                                              if (_profitRiskRatio > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getRiskRewardBorderColor(),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _getRiskRewardLabel(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
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
          ],
        ),
      ),
    );
  }

  // 添加预览项构建方法
  Widget _buildPreviewItem(String label, String value, Color color, [IconData? icon]) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (icon != null) ...[
            const SizedBox(height: 4),
            Icon(icon, size: 16, color: color),
          ],
        ],
      ),
    );
  }

  Widget _buildModernStrategySection() {
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 移除Row和按钮，直接使用标题
            const Text('交易策略',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Consumer<StrategyProvider>(
              builder: (context, strategyProvider, child) {
                if (strategyProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final strategies = strategyProvider.strategies;
                if (strategies.isEmpty) {
                  return const Text('暂无策略');
                }

                return DropdownButtonFormField<Strategy>(
                  value: _selectedStrategy,
                  decoration: const InputDecoration(
                    labelText: '选择策略',
                    hintText: '选择交易策略',
                  ),
                  items: strategies.map((strategy) {
                    return DropdownMenuItem(
                      value: strategy,
                      child: Text(strategy.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedStrategy = value;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return '请选择交易策略';
                    }
                    return null;
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // 新增AI分析按钮构建方法
  Widget _buildAIAnalysisButton() {
    // 检查是否有足够的交易数据用于分析
    bool hasEnoughData = _stockCodeController.text.isNotEmpty &&
        _selectedStrategy != null &&
        _planPriceController.text.isNotEmpty &&
        _stopLossPriceController.text.isNotEmpty &&
        _takeProfitPriceController.text.isNotEmpty;

    // 如果没有足够数据，显示禁用状态的按钮
    if (!hasEnoughData) {
      return Tooltip(
        message: '请先填写股票、价格和策略信息',
        child: ElevatedButton.icon(
          icon: const Icon(Icons.psychology),
          label: const Text('AI交易分析'),
          onPressed: null, // 禁用按钮
          style: ElevatedButton.styleFrom(
            disabledBackgroundColor: Colors.grey[300],
            disabledForegroundColor: Colors.grey[600],
          ),
        ),
      );
    }

    // 否则，返回可导入的AI分析组件
    return GestureDetector(
      onTap: () {
        // 检查是否有实际值
        final planPrice = double.tryParse(_planPriceController.text) ?? 0.0;
        final planQuantity = int.tryParse(_planQuantityController.text) ?? 0;
        final stopLossPrice =
            double.tryParse(_stopLossPriceController.text) ?? 0.0;
        final takeProfitPrice =
            double.tryParse(_takeProfitPriceController.text) ?? 0.0;

        if (planPrice <= 0 ||
            planQuantity <= 0 ||
            stopLossPrice <= 0 ||
            takeProfitPrice <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('请填写有效的价格和数量信息'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        // 创建并显示AI分析组件对话框
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('AI交易分析', style: TextStyle(fontSize: 18)),
            contentPadding: const EdgeInsets.all(8),
            content: Container(
              constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
              width: double.maxFinite,
              child: _buildAIAnalysisWidget(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭'),
              ),
            ],
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.psychology, color: Colors.white, size: 20),
            SizedBox(width: 4),
            Text('AI分析', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  // 构建实际的AI分析组件
  Widget _buildAIAnalysisWidget() {
    // 获取最近的历史K线数据
    final recentHistory = _stockHistoryData.isEmpty
        ? <Map<String, dynamic>>[]
        : _stockHistoryData.length > 20
            ? _stockHistoryData.sublist(_stockHistoryData.length - 20)
            : _stockHistoryData;

    // 返回独立的AI分析组件
    return AITradeAnalysisWidget(
      stockCode: _stockCodeController.text,
      stockName: _stockNameController.text,
      tradeType: _tradeType,
      planPrice: double.tryParse(_planPriceController.text) ?? 0.0,
      planQuantity: int.tryParse(_planQuantityController.text) ?? 0,
      stopLossPrice: double.tryParse(_stopLossPriceController.text) ?? 0.0,
      takeProfitPrice: double.tryParse(_takeProfitPriceController.text) ?? 0.0,
      profitRiskRatio: _profitRiskRatio,
      marketPhase: _getMarketPhaseText(),
      trendStrength: _getTrendStrengthText(),
      entryDifficulty: _getDifficultyLabel(_selectedEntryDifficulty),
      positionPercentage:
          double.tryParse(_positionPercentageController.text) ?? 0.0,
      atrValue: double.tryParse(_atrValueController.text) ?? 0.0,
      atrMultiple: double.tryParse(_atrMultipleController.text) ?? 0.0,
      riskPercentage: double.tryParse(_riskPercentageController.text) ?? 0.0,
      reason: _reasonController.text,
      historyData: recentHistory,
      actualTrend: _calculateActualTrend(recentHistory),
      onAnalysisStateChanged: (isAnalyzing) {
        // 可以在此处理分析状态变化
        print('AI分析状态: ${isAnalyzing ? "分析中" : "完成"}');
      },
      onAnalysisComplete: (analysisResult, thinkingProcess) {
        // 可以在此处理分析完成的结果
        print('AI分析完成，结果长度: ${analysisResult.length}');
      },
    );
  }

  Widget _buildModernReasonSection() {
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.lightbulb_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  '开仓理由',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _reasonController,
              decoration: InputDecoration(
                hintText: '请详细说明您的开仓理由和分析依据...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2),
                ),
                filled: true,
                fillColor: isDarkMode 
                    ? Colors.grey[800]?.withOpacity(0.3)
                    : Colors.grey[50],
                contentPadding: const EdgeInsets.all(16),
              ),
              maxLines: 4,
              style: const TextStyle(fontSize: 16),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入开仓理由';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernNotesSection() {
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.note_alt_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  '备注信息',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                hintText: '添加其他重要信息或提醒事项...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
                ),
                filled: true,
                fillColor: isDarkMode 
                    ? Colors.grey[800]?.withOpacity(0.3)
                    : Colors.grey[50],
                contentPadding: const EdgeInsets.all(16),
              ),
              maxLines: 3,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernMarketPhaseSection() {
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.trending_up,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  '盘趋阶段与交易特征',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 盘趋阶段
            DropdownButtonFormField<MarketPhase>(
              decoration: InputDecoration(
                labelText: '盘趋阶段',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
                ),
                filled: true,
                fillColor: isDarkMode 
                    ? Colors.grey[800]?.withOpacity(0.3)
                    : Colors.grey[50],
              ),
              value: _selectedMarketPhase,
              items: MarketPhase.values.map((phase) {
                String phaseName = '';
                IconData phaseIcon;
                switch (phase) {
                  case MarketPhase.buildingBottom:
                    phaseName = '筑底阶段';
                    phaseIcon = Icons.trending_flat;
                    break;
                  case MarketPhase.rising:
                    phaseName = '上升阶段';
                    phaseIcon = Icons.trending_up;
                    break;
                  case MarketPhase.consolidation:
                    phaseName = '盘整阶段';
                    phaseIcon = Icons.horizontal_rule;
                    break;
                  case MarketPhase.topping:
                    phaseName = '做头阶段';
                    phaseIcon = Icons.show_chart;
                    break;
                  case MarketPhase.falling:
                    phaseName = '下降阶段';
                    phaseIcon = Icons.trending_down;
                    break;
                }
                return DropdownMenuItem<MarketPhase>(
                  value: phase,
                  child: Row(
                    children: [
                      Icon(phaseIcon, size: 18, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(phaseName),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedMarketPhase = value!;
                });
              },
            ),

            const SizedBox(height: 20),

            // 趋势强度
            const Text(
              '趋势强度',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTrendStrengthOption(
                    TrendStrength.strong,
                    '强',
                    const Color(0xFFDC2626), // A股红色
                    Icons.keyboard_double_arrow_up,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTrendStrengthOption(
                    TrendStrength.medium,
                    '中',
                    Colors.orange,
                    Icons.trending_up,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTrendStrengthOption(
                    TrendStrength.weak,
                    '弱',
                    const Color(0xFF10B981), // A股绿色
                    Icons.trending_flat,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 下单质量
            const Text(
              '下单质量',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: _getDifficultyColor(_selectedEntryDifficulty),
                      inactiveTrackColor: _getDifficultyColor(_selectedEntryDifficulty).withOpacity(0.3),
                      thumbColor: _getDifficultyColor(_selectedEntryDifficulty),
                      overlayColor: _getDifficultyColor(_selectedEntryDifficulty).withOpacity(0.2),
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
                    ),
                    child: Slider(
              value: _selectedEntryDifficulty.index.toDouble(),
              min: 0,
              max: EntryDifficulty.values.length - 1.0,
              divisions: EntryDifficulty.values.length - 1,
              label: _getDifficultyLabel(_selectedEntryDifficulty),
              onChanged: (value) {
                setState(() {
                  _selectedEntryDifficulty =
                      EntryDifficulty.values[value.toInt()];
                });
              },
            ),
                  ),
                  const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                      Text(
                        '高质量',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '低质量',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 当前选择的难度显示
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _getDifficultyColor(_selectedEntryDifficulty).withOpacity(0.2), 
                          _getDifficultyColor(_selectedEntryDifficulty).withOpacity(0.1)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _getDifficultyColor(_selectedEntryDifficulty).withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildAnimatedDifficultyStars(_selectedEntryDifficulty),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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

  Color _getDifficultyColor(EntryDifficulty difficulty) {
    switch (difficulty) {
      case EntryDifficulty.veryEasy:
        return const Color(0xFF10B981); // 深绿色 - 非常容易
      case EntryDifficulty.easy:
        return const Color(0xFF34D399); // 浅绿色 - 容易
      case EntryDifficulty.medium:
        return const Color(0xFFFBBF24); // 黄色 - 中等
      case EntryDifficulty.hard:
        return const Color(0xFFF59E0B); // 橙色 - 困难
      case EntryDifficulty.veryHard:
        return const Color(0xFFEF4444); // 红色 - 非常困难
    }
  }

  // 构建趋势强度选项
  Widget _buildTrendStrengthOption(TrendStrength strength, String label, Color color, IconData icon) {
    final isSelected = _selectedTrendStrength == strength;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTrendStrength = strength;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          border: Border.all(
            color: isSelected ? color : Colors.grey.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? color : Colors.grey,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 显示多个星星，根据难度级别增加星星数量
  Widget _buildAnimatedDifficultyStars(EntryDifficulty difficulty) {
    final int starCount = difficulty.index + 1; // 从1到5颗星
    final Color starColor = _getDifficultyColor(difficulty);

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
                      fontSize: 16,
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
        Text(
          _getDifficultyLabel(difficulty),
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildModernRiskControlSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('风险控制',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),



            // 风险熔断设置
            _buildRiskMeltdownSection(),
          ],
        ),
      ),
    );
  }

  // K线图显示方法
  Widget _buildModernKLineChart() {
    if (_isLoadingAtr) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'K线图加载中...',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 16),
            ],
          ),
        ),
      );
    }

    if (_stockHistoryData.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '暂无K线数据',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              const Text('无法获取该股票的历史K线数据'),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  if (_stockCodeController.text.isNotEmpty) {
                    _fetchStockATR(_stockCodeController.text);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('请先输入股票代码'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.refresh),
                label: const Text('重新加载'),
              ),
            ],
          ),
        ),
      );
    }

    final validKLineData = _stockHistoryData;
    if (validKLineData.isEmpty) return const SizedBox.shrink();

    // 计划价、止损价和目标价
    final planPrice = double.tryParse(_planPriceController.text) ?? 0.0;
    final stopLossPrice = double.tryParse(_stopLossPriceController.text) ?? 0.0;
    final takeProfitPrice =
        double.tryParse(_takeProfitPriceController.text) ?? 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'K线走势图',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.sync, size: 20),
                      tooltip: '刷新K线图',
                      onPressed: () {
                        if (_stockCodeController.text.isNotEmpty) {
                          // 刷新K线数据
                          setState(() {
                            _isLoadingAtr = true;
                          });

                          _stockService
                              .getStockHistoryData(
                            _stockCodeController.text,
                          )
                              .then((data) {
                            if (mounted) {
                              setState(() {
                                _stockHistoryData = data;
                                _isLoadingAtr = false;
                                _calculateChartRange();
                              });

                              // 确保使用最新价格
                              if (data.isNotEmpty) {
                                final latestPrice =
                                    data.last['close'] as double;
                                print('获取到最新价格: $latestPrice');

                                // 如果尚未填写计划价格，则自动填入最新价格
                                if (_planPriceController.text.isEmpty) {
                                  _planPriceController.text =
                                      latestPrice.toStringAsFixed(2);
                                }
                              }
                            }
                          }).catchError((error) {
                            if (mounted) {
                              setState(() {
                                _isLoadingAtr = false;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('获取K线数据失败: $error'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          });
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('请先输入股票代码'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      tooltip: '隐藏K线图',
                      onPressed: () {
                        setState(() {
                          _showKLineChart = false;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '基于真实历史数据，显示${validKLineData.length}天有效数据',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: LineChart(
                LineChartData(
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      tooltipBgColor: Colors.white.withOpacity(0.8),
                      getTooltipItems: (List<LineBarSpot> touchedSpots) {
                        return touchedSpots.map((spot) {
                          if (spot.barIndex == 0) {
                            final index = spot.x.toInt();
                            if (index >= 0 && index < validKLineData.length) {
                              try {
                                final data = validKLineData[index];
                                final dateStr = data['date'] != null
                                    ? data['date'].toString()
                                    : data['trade_date'] != null
                                        ? data['trade_date'].toString()
                                        : '';

                                if (dateStr.isEmpty) {
                                  return null;
                                }

                                final date =
                                    DateTime.parse(dateStr.split('T')[0]);
                                return LineTooltipItem(
                                  '${DateFormat('MM-dd').format(date)}\n最高价: ${data['high']?.toStringAsFixed(2)}\n最低价: ${data['low']?.toStringAsFixed(2)}\n收盘价: ${data['close']?.toStringAsFixed(2)}',
                                  const TextStyle(color: Colors.black),
                                );
                              } catch (e) {
                                print('提示框日期解析错误: $e');
                                return null;
                              }
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
                    drawHorizontalLine: true,
                    drawVerticalLine: true,
                    horizontalInterval: (_maxY - _minY) / 5,
                    verticalInterval: validKLineData.length > 10
                        ? validKLineData.length / 5
                        : 1,
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles:
                        const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles:
                        const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: validKLineData.length > 10
                            ? validKLineData.length / 5
                            : 1,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 &&
                              index < validKLineData.length &&
                              index % 5 == 0) {
                            try {
                              final data = validKLineData[index];
                              final dateStr = data['date'] != null
                                  ? data['date'].toString()
                                  : data['trade_date'] != null
                                      ? data['trade_date'].toString()
                                      : '';

                              if (dateStr.isEmpty) {
                                return const SizedBox();
                              }

                              final date =
                                  DateTime.parse(dateStr.split('T')[0]);

                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  DateFormat('MM-dd').format(date),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
                                  ),
                                ),
                              );
                            } catch (e) {
                              print('日期解析错误: $e');
                              return const SizedBox();
                            }
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toStringAsFixed(2),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                        interval: (_maxY - _minY) / 5,
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  minX: 0,
                  maxX: validKLineData.length.toDouble() - 1,
                  minY: _minY,
                  maxY: _maxY,
                  lineBarsData: [
                    // 收盘价线
                    LineChartBarData(
                      spots: List.generate(validKLineData.length, (index) {
                        final data = validKLineData[index]; // 直接使用索引，不再反转
                        return FlSpot(
                          index.toDouble(),
                          data['close'] as double,
                        );
                      }),
                      isCurved: false,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      color: Colors.blue,
                    ),

                    // 5日EMA线
                    LineChartBarData(
                      spots: List.generate(validKLineData.length, (index) {
                        final data = validKLineData[index]; // 直接使用索引，不再反转
                        // 可能前几天没有EMA值
                        final ema5 = data['ema5'];
                        if (ema5 == null) {
                          return FlSpot.nullSpot;
                        }
                        return FlSpot(
                          index.toDouble(),
                          ema5 as double,
                        );
                      }),
                      isCurved: true,
                      barWidth: 1.5,
                      dotData: const FlDotData(show: false),
                      color: Colors.amber,
                    ),

                    // 17日EMA线
                    LineChartBarData(
                      spots: List.generate(validKLineData.length, (index) {
                        final data = validKLineData[index]; // 直接使用索引，不再反转
                        // 可能前几天没有EMA值
                        final ema17 = data['ema17'];
                        if (ema17 == null) {
                          return FlSpot.nullSpot;
                        }
                        return FlSpot(
                          index.toDouble(),
                          ema17 as double,
                        );
                      }),
                      isCurved: true,
                      barWidth: 1.5,
                      dotData: const FlDotData(show: false),
                      color: Colors.purple,
                    ),

                    // 计划价格水平线
                    if (planPrice > 0)
                      LineChartBarData(
                        spots: [
                          FlSpot(0, planPrice),
                          FlSpot(
                              validKLineData.length.toDouble() - 1, planPrice),
                        ],
                        isCurved: false,
                        color: Colors.grey[700]!, // 深灰色：进场价格，更精细美观
                        barWidth: 1,
                        dotData: const FlDotData(show: false),
                        dashArray: [6, 3],
                      ),

                    // 止损价格水平线
                    if (stopLossPrice > 0)
                      LineChartBarData(
                        spots: [
                          FlSpot(0, stopLossPrice),
                          FlSpot(validKLineData.length.toDouble() - 1,
                              stopLossPrice),
                        ],
                        isCurved: false,
                        color: Colors.green, // A股绿色：止损（亏损）
                        barWidth: 1.5,
                        dotData: const FlDotData(show: false),
                        dashArray: [2, 2],
                      ),

                    // 目标价格水平线
                    if (takeProfitPrice > 0)
                      LineChartBarData(
                        spots: [
                          FlSpot(0, takeProfitPrice),
                          FlSpot(validKLineData.length.toDouble() - 1,
                              takeProfitPrice),
                        ],
                        isCurved: false,
                        color: Colors.red, // A股红色：止盈（盈利）
                        barWidth: 1.5,
                        dotData: const FlDotData(show: false),
                        dashArray: [2, 2],
                      ),
                  ],
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      // 计划价格横线
                      if (planPrice > 0)
                        HorizontalLine(
                          y: planPrice,
                          color: Colors.grey[700]!, // 深灰色：进场价格，更精细美观
                          strokeWidth: 1,
                          dashArray: [6, 3],
                          label: HorizontalLineLabel(
                            show: true,
                            alignment: Alignment.topRight,
                            padding:
                                const EdgeInsets.only(right: 10.0, bottom: 3.0),
                            style: TextStyle(
                              color: Colors.grey[700]!, // 深灰色：进场价格，更精细美观
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                            labelResolver: (line) =>
                                '进场价 ${planPrice.toStringAsFixed(2)}',
                          ),
                        ),

                      // 止损价格横线
                      if (stopLossPrice > 0)
                        HorizontalLine(
                          y: stopLossPrice,
                          color: Colors.green, // A股绿色：止损（亏损）
                          strokeWidth: 1,
                          dashArray: [2, 2],
                          label: HorizontalLineLabel(
                            show: true,
                            alignment: Alignment.topRight,
                            padding:
                                const EdgeInsets.only(right: 8.0, bottom: 2.0),
                            style: const TextStyle(
                              color: Colors.green, // A股绿色：止损（亏损）
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                            labelResolver: (line) =>
                                '止损价 ${stopLossPrice.toStringAsFixed(2)}',
                          ),
                        ),

                      // 目标价格横线
                      if (takeProfitPrice > 0)
                        HorizontalLine(
                          y: takeProfitPrice,
                          color: Colors.red, // A股红色：止盈（盈利）
                          strokeWidth: 1,
                          dashArray: [2, 2],
                          label: HorizontalLineLabel(
                            show: true,
                            alignment: Alignment.topRight,
                            padding:
                                const EdgeInsets.only(right: 8.0, bottom: 2.0),
                            style: const TextStyle(
                              color: Colors.red, // A股红色：止盈（盈利）
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                            labelResolver: (line) =>
                                '目标价 ${takeProfitPrice.toStringAsFixed(2)}',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
                        const SizedBox(height: 12),
            
            // 显示详细K线数据或提示信息
            if (_showDetailView && _selectedPoint != null)
              _buildDetailCard(),
            if (!_showDetailView || _selectedPoint == null)
              Center(
                child: Text(
                  '点击K线图上的点查看详细数据',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
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

  // 图例项构建
  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 3,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // 点击查看详细数据卡片
  Widget _buildDetailCard() {
    if (_selectedPoint == null) return const SizedBox.shrink();
    
    final currentIndex = _stockHistoryData.indexOf(_selectedPoint!);
    final dateStr = _selectedPoint!['date'].toString().split('T')[0];
    final open = double.parse(_selectedPoint!['open'].toString());
    final close = double.parse(_selectedPoint!['close'].toString());
    final high = double.parse(_selectedPoint!['high'].toString());
    final low = double.parse(_selectedPoint!['low'].toString());
    final volume = double.parse(_selectedPoint!['volume'].toString());
    
    // 获取前后日数据
    Map<String, dynamic>? prevData;
    Map<String, dynamic>? nextData;
    
    if (currentIndex > 0 && currentIndex < _stockHistoryData.length) {
      prevData = _stockHistoryData[currentIndex - 1];
    }
    if (currentIndex >= 0 && currentIndex < _stockHistoryData.length - 1) {
      nextData = _stockHistoryData[currentIndex + 1];
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

  // 显示数据库工具对话框
  void _showDatabaseTools(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('数据库工具', style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('警告: 这些操作可能导致数据丢失!',
                style: TextStyle(
                    color: Colors.red[700], fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('当前错误: 表中缺少字段，导致添加交易计划失败'),
            const SizedBox(height: 8),
            const Text('解决方案: 更新数据库结构或重置数据库'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('取消'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.orange,
            ),
            onPressed: () async {
              try {
                Navigator.pop(context);

                // 显示加载指示器
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const AlertDialog(
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('更新数据库结构...'),
                      ],
                    ),
                  ),
                );

                // 增加数据库版本号（已经在文件中修改了）
                // 等待数据库初始化并触发升级
                await context.read<DatabaseService>().database;

                // 关闭加载对话框
                Navigator.pop(context);

                // 显示成功消息
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('数据库结构已更新，请再次尝试添加交易计划'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                // 关闭加载对话框
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('更新失败: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('更新数据库'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            onPressed: () async {
              // 确认重置
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('确认重置数据库'),
                  content: const Text('这将删除所有数据，确定要继续吗？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('取消'),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('确定重置'),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                try {
                  Navigator.pop(context);

                  // 显示加载指示器
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const AlertDialog(
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('重置数据库...'),
                        ],
                      ),
                    ),
                  );

                  // 重置数据库
                  await context.read<DatabaseService>().resetDatabase();

                  // 关闭加载对话框
                  Navigator.pop(context);

                  // 显示成功消息
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('数据库已重置，请再次尝试添加交易计划'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  // 关闭加载对话框
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('重置失败: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('重置数据库'),
          ),
        ],
      ),
    );
  }



  // 智能风险熔断设置
  Widget _buildRiskMeltdownSection() {
    // 自动计算风险百分比
    double calculatedRiskPercentage = 0.0;
    String riskCalculationMessage = '';
    
         if (_planPriceController.text.isNotEmpty && 
         _stopLossPriceController.text.isNotEmpty &&
         _planQuantityController.text.isNotEmpty) {
       
       final entryPrice = double.tryParse(_planPriceController.text) ?? 0.0;
       final stopLossPrice = double.tryParse(_stopLossPriceController.text) ?? 0.0;
       final quantity = double.tryParse(_planQuantityController.text) ?? 0.0;
      final accountTotal = double.tryParse(_accountTotalController.text) ?? 0.0;
      
      if (entryPrice > 0 && stopLossPrice > 0 && quantity > 0) {
        double lossPerShare;
        if (_tradeType == TradeType.buy) {
          lossPerShare = entryPrice - stopLossPrice;
    } else {
          lossPerShare = stopLossPrice - entryPrice;
        }
        
        if (lossPerShare > 0) {
          final totalLoss = lossPerShare * quantity;
          
          if (accountTotal > 0) {
            // 使用用户设置的实际账户总资金
            calculatedRiskPercentage = (totalLoss / accountTotal) * 100;
            riskCalculationMessage = '基于当前设置的账户总资金${(accountTotal/10000).toStringAsFixed(1)}万元计算';
          } else {
            // 如果用户没有设置账户总资金，提示用户设置
            riskCalculationMessage = '请在账户设置中填写总资金以准确计算风险比例';
          }
        }
      }
    }

    // 自动更新风险百分比控制器
    if (calculatedRiskPercentage > 0) {
      _riskPercentageController.text = calculatedRiskPercentage.toStringAsFixed(2);
    }

    final riskPercentage = calculatedRiskPercentage;
    
    // 从绿到红的渐变颜色计算
    Color getRiskColor(double percentage) {
      if (percentage <= 0) return Colors.grey;
      if (percentage <= 1) return Colors.green;
      if (percentage <= 2) return Colors.lightGreen;
      if (percentage <= 3) return Colors.yellow;
      if (percentage <= 5) return Colors.orange;
      if (percentage <= 8) return Colors.deepOrange;
      return Colors.red;
    }
    
    String getRiskLevel(double percentage) {
      if (percentage <= 0) return '未设置';
      if (percentage <= 1) return '极安全';
      if (percentage <= 2) return '安全';
      if (percentage <= 3) return '稳健';
      if (percentage <= 5) return '适中';
      if (percentage <= 8) return '激进';
      return '危险';
    }

    final riskColor = getRiskColor(riskPercentage);
    final riskLevel = getRiskLevel(riskPercentage);
    final accountTotal = double.tryParse(_accountTotalController.text) ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            riskColor.withOpacity(0.08),
            riskColor.withOpacity(0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: riskColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          // 标题和实时风险等级
        Row(
          children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: riskColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.shield_outlined, color: riskColor, size: 20),
              ),
              const SizedBox(width: 12),
            Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '风险熔断',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: riskColor,
                      ),
                    ),
                    if (calculatedRiskPercentage > 0 && riskCalculationMessage.isNotEmpty)
                      Text(
                        riskCalculationMessage,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
              if (riskPercentage > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: riskColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    riskLevel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          
          // 风险百分比显示
          if (riskPercentage > 0) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: riskColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                ),
              child: Row(
                  children: [
                  Icon(Icons.analytics, color: riskColor, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '当前风险水平',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              '${riskPercentage.toStringAsFixed(2)}%',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: riskColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '总资金占比',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
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
            const SizedBox(height: 12),
          ],
          
          // 如果没有设置账户总资金，显示提示
          if (accountTotal <= 0) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_outlined, color: Colors.orange[700], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '请设置账户总资金',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '在上方"账户总额"字段填写您的实际总资金，系统将基于此计算准确的风险比例',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[600],
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          
          // 如果没有计算结果，显示提示信息
          if (riskPercentage <= 0 && accountTotal > 0) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '等待交易参数',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '请填写入场价、止损价和数量，系统将基于您的账户总资金自动计算风险比例',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          
          // 智能提示
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.blue.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.blue, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                    accountTotal > 0 
                      ? calculatedRiskPercentage > 0 
                        ? '风险比例基于您的实际账户总资金动态计算，确保风险控制的准确性'
                        : '风险熔断：当单笔亏损达到账户总资金的指定百分比时强制止损'
                      : '设置账户总资金后，系统将基于您的实际资金计算准确的风险比例，而非固定基准',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue[700],
                      height: 1.2,
                    ),
              ),
            ),
          ],
        ),
        ),
      ],
      ),
    );
  }





  // 添加刷新股票数据库的方法
  Future<void> _refreshStockDatabase() async {
    setState(() {
      _isLoading = true;
      // 清空当前的搜索结果
      _stockSuggestions = [];
    });

    try {
      // 显示刷新提示对话框
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return const AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在刷新股票数据库...\n这可能需要几分钟时间'),
                ],
              ),
            );
          },
        );
      }

      final result = await context.read<StockProvider>().refreshStockDatabase();

      // 关闭加载对话框
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (context.mounted) {
        if (result) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('股票数据库刷新成功！')));
        } else {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('股票数据库刷新失败，请检查网络连接')));
        }
      }
    } catch (e) {
      // 关闭加载对话框
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('刷新股票数据库出错: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 计算ATR
  void _calculateATR() {
    if (_stockHistoryData.isEmpty) {
      print('历史数据为空，无法计算ATR');
      _useBackupAtrCalculation();
      return;
    }

    try {
      print('开始计算ATR，历史数据: ${_stockHistoryData.length}条');

      // 确保数据长度足够
      if (_stockHistoryData.length < 2) {
        print('历史数据不足2条，无法计算ATR');
        _useBackupAtrCalculation();
        return;
      }

      // 计算TR (True Range)
      List<double> trValues = [];

      for (int i = 1; i < _stockHistoryData.length; i++) {
        final current = _stockHistoryData[i];
        final previous = _stockHistoryData[i - 1];

        if (current['high'] == null ||
            current['low'] == null ||
            current['close'] == null ||
            previous['close'] == null) {
          continue;
        }

        final high = current['high'] as double;
        final low = current['low'] as double;
        final previousClose = previous['close'] as double;

        // 计算三个差值
        final highLow = high - low;
        final highPrevClose = (high - previousClose).abs();
        final lowPrevClose = (low - previousClose).abs();

        // TR是三个差值中的最大值
        final tr = [highLow, highPrevClose, lowPrevClose]
            .reduce((max, value) => value > max ? value : max);
        trValues.add(tr);
      }

      if (trValues.isEmpty) {
        print('无法计算TR值，使用备用方法');
        _useBackupAtrCalculation();
        return;
      }

      print('成功计算${trValues.length}个TR值');

      // 计算ATR (Average True Range)
      double atr = 0.0;

      // 简单移动平均法计算ATR
      atr = trValues.reduce((sum, value) => sum + value) / trValues.length;
      print('ATR计算结果: $atr');

      if (mounted && atr > 0) {
        setState(() {
          _atrValueController.text = atr.toStringAsFixed(4);
          if (_useAtrForStopLoss) {
            _calculateStopLossFromATR();
          }
        });
      } else {
        print('ATR计算结果为0或负值，使用备用方法');
        _useBackupAtrCalculation();
      }
    } catch (e) {
      print('ATR计算出错: $e');
      _useBackupAtrCalculation();
    }
  }

  // 辅助方法：安全获取格式化日期
  String _getFormattedDate(Map<String, dynamic> dataPoint) {
    try {
      // 打印原始数据，便于调试
      print('原始数据点: $dataPoint');
      
      // 1. 尝试获取日期字符串，支持多种可能的字段名
      String? dateStr;
      
      if (dataPoint.containsKey('date') && dataPoint['date'] != null) {
        dateStr = dataPoint['date'].toString();
        print('从date字段获取到日期: $dateStr');
      } else if (dataPoint.containsKey('trade_date') && dataPoint['trade_date'] != null) {
        dateStr = dataPoint['trade_date'].toString();
        print('从trade_date字段获取到日期: $dateStr');
      } else if (dataPoint.containsKey('time') && dataPoint['time'] != null) {
        dateStr = dataPoint['time'].toString();
        print('从time字段获取到日期: $dateStr');
      } else {
        // 尝试查找其他可能的日期字段
        for (var key in dataPoint.keys) {
          if ((key.toLowerCase().contains('date') || key.toLowerCase().contains('time')) && 
              dataPoint[key] != null) {
            dateStr = dataPoint[key].toString();
            print('从字段$key获取到日期: $dateStr');
            break;
          }
        }
      }
      
      if (dateStr == null || dateStr.isEmpty) {
        print('未找到日期字段: $dataPoint');
        return '未知日期';
      }
      
      // 2. 处理各种可能的日期格式
      // 处理ISO格式 (2023-01-01T00:00:00.000Z)
      if (dateStr.contains('T')) {
        final dateParts = dateStr.split('T');
        if (dateParts.isNotEmpty) {
          return _formatDateString(dateParts[0]);
        }
      }
      
      // 处理纯数字格式 (20230101)
      if (dateStr.length == 8 && int.tryParse(dateStr) != null) {
        return '${dateStr.substring(0, 4)}-${dateStr.substring(4, 6)}-${dateStr.substring(6, 8)}';
      }
      
      // 处理已经格式化的日期 (2023-01-01)
      if (dateStr.length == 10 && dateStr.contains('-')) {
        return _formatDateString(dateStr);
      }
      
      // 尝试直接解析日期
      final date = DateTime.tryParse(dateStr);
      if (date != null) {
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      }
      
      // 尝试处理长整型时间戳（毫秒）
      if (dateStr.length >= 10 && int.tryParse(dateStr) != null) {
        final timestamp = int.parse(dateStr);
        // 判断是秒级还是毫秒级时间戳
        final date = timestamp > 10000000000 
            ? DateTime.fromMillisecondsSinceEpoch(timestamp) 
            : DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      }
      
      print('无法识别的日期格式: $dateStr');
      return dateStr; // 返回原始字符串作为后备
    } catch (e) {
      print('格式化日期出错: $e, 数据: $dataPoint');
      return '未知日期';
    }
  }
  
  // 辅助方法：格式化日期字符串，确保有连字符
  String _formatDateString(String dateStr) {
    // 如果已经是标准格式，直接返回
    if (dateStr.contains('-') && dateStr.length >= 10) {
      return dateStr.substring(0, 10); // 只取前10个字符 (YYYY-MM-DD)
    }
    
    try {
      // 尝试解析日期
      final date = DateTime.parse(dateStr);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      print('格式化日期字符串出错: $e, 输入: $dateStr');
      return dateStr; // 无法格式化，返回原始字符串
    }
  }

  // 添加这个辅助方法来确定是否可以计算盈亏预测
  bool _canCalculateProfitLoss() {
    final planPrice = double.tryParse(_planPriceController.text) ?? 0.0;
    final planQuantity = int.tryParse(_planQuantityController.text) ?? 0;
    final stopLossPrice = double.tryParse(_stopLossPriceController.text) ?? 0.0;
    final takeProfitPrice = double.tryParse(_takeProfitPriceController.text) ?? 0.0;

    return planPrice > 0 && planQuantity > 0 && stopLossPrice > 0 && takeProfitPrice > 0;
  }

  // 添加这个辅助方法来计算最大盈利
  double _calculateMaxProfit() {
    final planPrice = double.tryParse(_planPriceController.text) ?? 0.0;
    final planQuantity = int.tryParse(_planQuantityController.text) ?? 0;
    final takeProfitPrice = double.tryParse(_takeProfitPriceController.text) ?? 0.0;

    if (planPrice <= 0 || planQuantity <= 0 || takeProfitPrice <= 0) {
      return 0.0;
    }

    // 计算买入成本（含手续费）
    final buyAmount = planPrice * planQuantity;
    final buyCommission = buyAmount * 0.0003; // 0.03% 手续费
    final totalBuyCost = buyAmount + buyCommission;

    // 计算卖出收入（扣除手续费）
    final sellAmount = takeProfitPrice * planQuantity;
    final sellCommission = sellAmount * 0.0003; // 0.03% 手续费
    final netSellAmount = sellAmount - sellCommission;

    // 最大盈利 = 净卖出收入 - 总买入成本
    return netSellAmount - totalBuyCost;
  }

  // 添加这个辅助方法来计算最大亏损
  double _calculateMaxLoss() {
    final planPrice = double.tryParse(_planPriceController.text) ?? 0.0;
    final planQuantity = int.tryParse(_planQuantityController.text) ?? 0;
    final stopLossPrice = double.tryParse(_stopLossPriceController.text) ?? 0.0;

    if (planPrice <= 0 || planQuantity <= 0 || stopLossPrice <= 0) {
      return 0.0;
    }

    // 计算买入成本（含手续费）
    final buyAmount = planPrice * planQuantity;
    final buyCommission = buyAmount * 0.0003; // 0.03% 手续费
    final totalBuyCost = buyAmount + buyCommission;

    // 计算止损卖出收入（扣除手续费）
    final sellAmount = stopLossPrice * planQuantity;
    final sellCommission = sellAmount * 0.0003; // 0.03% 手续费
    final netSellAmount = sellAmount - sellCommission;

    // 最大亏损 = 总买入成本 - 净卖出收入
    return totalBuyCost - netSellAmount;
  }

  // 获取市场显示名称
  String _getMarketDisplayName(String? market) {
    if (market == null || market.isEmpty) {
      return '';
    }
    
    switch (market.toUpperCase()) {
      case 'SZ':
        return '深市';
      case 'SH':
        return '沪市';
      case 'BJ':
        return '北交所';
      default:
        // 如果是其他格式，尝试提取更有意义的信息
        if (market.contains('深圳')) return '深市';
        if (market.contains('上海')) return '沪市';
        if (market.contains('北京')) return '北交所';
        // 如果都不匹配，返回空字符串（不显示）
        return '';
    }
  }

  // 构建现代化切换按钮
  Widget _buildToggleButton(String text, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? const Color(0xFF667EEA) 
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF667EEA),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildModernCard({
    required String title,
    required IconData icon,
    required List<Color> gradientColors,
    required Widget child,
  }) {
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }

  // 获取盈亏比渐变颜色
  List<Color> _getRiskRewardGradientColors() {
    if (_profitRiskRatio <= 0) {
      return [
        Colors.grey.withOpacity(0.1),
        Colors.grey.withOpacity(0.05),
      ];
    }
    
    if (_profitRiskRatio >= 3.0) {
      // 优秀盈亏比：深绿色
      return [
        const Color(0xFF10B981).withOpacity(0.15),
        const Color(0xFF10B981).withOpacity(0.08),
      ];
    } else if (_profitRiskRatio >= 2.0) {
      // 良好盈亏比：浅绿色
      return [
        const Color(0xFF34D399).withOpacity(0.12),
        const Color(0xFF34D399).withOpacity(0.06),
      ];
    } else if (_profitRiskRatio >= 1.5) {
      // 一般盈亏比：黄色
      return [
        const Color(0xFFFBBF24).withOpacity(0.12),
        const Color(0xFFFBBF24).withOpacity(0.06),
      ];
    } else if (_profitRiskRatio >= 1.0) {
      // 偏低盈亏比：橙色
      return [
        const Color(0xFFF59E0B).withOpacity(0.12),
        const Color(0xFFF59E0B).withOpacity(0.06),
      ];
    } else {
      // 不合理盈亏比：红色
      return [
        const Color(0xFFEF4444).withOpacity(0.12),
        const Color(0xFFEF4444).withOpacity(0.06),
      ];
    }
  }

  // 获取盈亏比边框颜色
  Color _getRiskRewardBorderColor() {
    if (_profitRiskRatio <= 0) {
      return Colors.grey;
    }
    
    if (_profitRiskRatio >= 3.0) {
      return const Color(0xFF10B981); // 深绿色
    } else if (_profitRiskRatio >= 2.0) {
      return const Color(0xFF34D399); // 浅绿色
    } else if (_profitRiskRatio >= 1.5) {
      return const Color(0xFFFBBF24); // 黄色
    } else if (_profitRiskRatio >= 1.0) {
      return const Color(0xFFF59E0B); // 橙色
    } else {
      return const Color(0xFFEF4444); // 红色
    }
  }

  // 获取盈亏比标签文本
  String _getRiskRewardLabel() {
    if (_profitRiskRatio >= 3.0) {
      return '优秀';
    } else if (_profitRiskRatio >= 2.0) {
      return '良好';
    } else if (_profitRiskRatio >= 1.5) {
      return '一般';
    } else if (_profitRiskRatio >= 1.0) {
      return '偏低';
    } else {
      return '不合理';
    }
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
