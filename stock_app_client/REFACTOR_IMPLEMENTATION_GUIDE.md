# AddTradeScreen 重构实施指南

## ✅ 已完成的文件

### 1. 数据模型和服务
- ✅ `lib/models/trade/trade_form_data.dart` - 表单数据模型
- ✅ `lib/services/trade/trade_calculation_service.dart` - 计算服务
- ✅ `lib/services/trade/trade_validation.dart` - 验证服务

### 2. 基础UI组件
- ✅ `lib/widgets/trade/trade_notes_card.dart` - 备注卡片
- ✅ `lib/widgets/trade/trade_reason_card.dart` - 原因卡片

---

## 📋 待创建的组件清单

### 阶段1: 简单组件（每个约200行）

#### 1. 操作按钮组件
**文件**: `lib/widgets/trade/trade_action_buttons.dart`

**从原文件提取**: `_buildModernActionButtons()` 方法

**关键功能**:
- 预览按钮
- 保存按钮
- AI分析按钮

**Props**:
```dart
class TradeActionButtons extends StatelessWidget {
  final VoidCallback onPreview;
  final VoidCallback onSave;
  final VoidCallback onAIAnalysis;
  final bool isLoading;
  final bool isDarkMode;
  
  const TradeActionButtons({
    required this.onPreview,
    required this.onSave,
    required this.onAIAnalysis,
    this.isLoading = false,
    required this.isDarkMode,
  });
}
```

---

### 阶段2: 中等复杂度组件（每个约300-400行）

#### 2. 股票选择卡片
**文件**: `lib/widgets/trade/stock_selection_card.dart`

**从原文件提取**: `_buildModernStockSection()` 方法

**关键功能**:
- 股票代码输入
- 股票名称输入
- 搜索建议列表
- 手动输入开关

**Props**:
```dart
class StockSelectionCard extends StatefulWidget {
  final TextEditingController stockCodeController;
  final TextEditingController stockNameController;
  final bool isManualInput;
  final Function(bool) onManualInputChanged;
  final Function(String, String) onStockSelected;
  final bool isDarkMode;
  
  const StockSelectionCard({
    required this.stockCodeController,
    required this.stockNameController,
    required this.isManualInput,
    required this.onManualInputChanged,
    required this.onStockSelected,
    required this.isDarkMode,
  });
}
```

**实现要点**:
```dart
// 1. 搜索股票
Future<void> _searchStocks(String query) async {
  final stockService = StockService();
  final suggestions = await stockService.searchStocks(query);
  setState(() {
    _suggestions = suggestions;
  });
}

// 2. 选择股票
void _selectStock(Map<String, dynamic> stock) {
  widget.stockCodeController.text = stock['code'];
  widget.stockNameController.text = stock['name'];
  widget.onStockSelected(stock['code'], stock['name']);
  setState(() {
    _suggestions = [];
  });
}
```

---

#### 3. 市场阶段卡片
**文件**: `lib/widgets/trade/market_phase_card.dart`

**从原文件提取**: `_buildModernMarketPhaseSection()` 方法

**关键功能**:
- 市场阶段选择（上涨、下跌、震荡、筑底）
- 趋势强度选择（强、中、弱）
- 入场难度选择（容易、中等、困难）

**Props**:
```dart
class MarketPhaseCard extends StatelessWidget {
  final MarketPhase selectedPhase;
  final TrendStrength selectedStrength;
  final EntryDifficulty selectedDifficulty;
  final Function(MarketPhase) onPhaseChanged;
  final Function(TrendStrength) onStrengthChanged;
  final Function(EntryDifficulty) onDifficultyChanged;
  final bool isDarkMode;
  
  const MarketPhaseCard({
    required this.selectedPhase,
    required this.selectedStrength,
    required this.selectedDifficulty,
    required this.onPhaseChanged,
    required this.onStrengthChanged,
    required this.onDifficultyChanged,
    required this.isDarkMode,
  });
}
```

---

#### 4. 交易详情卡片
**文件**: `lib/widgets/trade/trade_details_card.dart`

**从原文件提取**: `_buildModernTradeDetailsSection()` 方法

**关键功能**:
- 交易类型选择（买入/卖出）
- 开仓时间选择
- 计划价格输入
- 计划数量输入
- 触发类型选择
- 建仓方式选择

**Props**:
```dart
class TradeDetailsCard extends StatelessWidget {
  final TradeType tradeType;
  final DateTime createTime;
  final TextEditingController planPriceController;
  final TextEditingController planQuantityController;
  final PriceTriggerType triggerType;
  final PositionBuildingMethod buildingMethod;
  final Function(TradeType) onTradeTypeChanged;
  final Function(DateTime) onCreateTimeChanged;
  final Function(PriceTriggerType) onTriggerTypeChanged;
  final Function(PositionBuildingMethod) onBuildingMethodChanged;
  final bool isDarkMode;
  
  const TradeDetailsCard({...});
}
```

---

#### 5. 策略选择卡片
**文件**: `lib/widgets/trade/strategy_selection_card.dart`

**从原文件提取**: `_buildModernStrategySection()` 方法

**关键功能**:
- 策略列表展示
- 策略选择
- 跳转到添加策略页面

**Props**:
```dart
class StrategySelectionCard extends StatelessWidget {
  final Strategy? selectedStrategy;
  final Function(Strategy?) onStrategyChanged;
  final bool isDarkMode;
  
  const StrategySelectionCard({
    required this.selectedStrategy,
    required this.onStrategyChanged,
    required this.isDarkMode,
  });
}
```

---

### 阶段3: 复杂组件（每个约500-600行）

#### 6. 风险控制卡片
**文件**: `lib/widgets/trade/risk_control_card.dart`

**从原文件提取**: `_buildModernRiskControlSection()` 方法

**关键功能**:
- 止损价输入
- 止盈价输入
- ATR止损计算
- 仓位计算
- 风险熔断
- 盈亏比展示

**Props**:
```dart
class RiskControlCard extends StatefulWidget {
  final TextEditingController stopLossPriceController;
  final TextEditingController takeProfitPriceController;
  final TextEditingController atrValueController;
  final TextEditingController atrMultipleController;
  final TextEditingController positionPercentageController;
  final TextEditingController riskPercentageController;
  final TextEditingController accountBalanceController;
  final bool useAtrForStopLoss;
  final PositionCalculationMethod positionMethod;
  final double planPrice;
  final int planQuantity;
  final TradeType tradeType;
  final Function(bool) onUseAtrChanged;
  final Function(PositionCalculationMethod) onPositionMethodChanged;
  final Function(int) onQuantityChanged;
  final bool isDarkMode;
  
  const RiskControlCard({...});
}
```

**子组件**:
- `PositionCalculator` - 仓位计算器
- `AtrStopLossCalculator` - ATR止损计算器
- `RiskMeltdownSection` - 风险熔断区域
- `ProfitRiskRatioDisplay` - 盈亏比展示

---

#### 7. K线图表卡片
**文件**: `lib/widgets/trade/kline_chart_card.dart`

**从原文件提取**: `_buildModernKLineChart()` 方法

**关键功能**:
- 显示K线图表
- 图表交互
- 图例展示

**Props**:
```dart
class KLineChartCard extends StatelessWidget {
  final String stockCode;
  final String stockName;
  final bool isDarkMode;
  
  const KLineChartCard({
    required this.stockCode,
    required this.stockName,
    required this.isDarkMode,
  });
}
```

---

### 阶段4: 子组件（每个约200-300行）

#### 8. 仓位计算器
**文件**: `lib/widgets/trade/components/position_calculator.dart`

**从原文件提取**: 仓位计算相关逻辑

**关键功能**:
- 按比例计算
- 按数量计算
- 以损定仓计算

**Props**:
```dart
class PositionCalculator extends StatelessWidget {
  final PositionCalculationMethod method;
  final TextEditingController percentageController;
  final TextEditingController quantityController;
  final TextEditingController riskPercentageController;
  final TextEditingController accountBalanceController;
  final double planPrice;
  final double? stopLossPrice;
  final TradeType tradeType;
  final Function(PositionCalculationMethod) onMethodChanged;
  final Function(int) onQuantityCalculated;
  final bool isDarkMode;
  
  const PositionCalculator({...});
}
```

**使用TradeCalculationService**:
```dart
int _calculatePosition() {
  switch (method) {
    case PositionCalculationMethod.percentage:
      return TradeCalculationService.calculatePositionByPercentage(
        planPrice: planPrice,
        percentage: double.parse(percentageController.text),
        accountBalance: double.parse(accountBalanceController.text),
      );
    case PositionCalculationMethod.riskBased:
      if (stopLossPrice == null) return 0;
      return TradeCalculationService.calculatePositionByRisk(
        planPrice: planPrice,
        stopLoss: stopLossPrice!,
        riskPercentage: double.parse(riskPercentageController.text),
        accountBalance: double.parse(accountBalanceController.text),
        tradeType: tradeType,
      );
    default:
      return int.tryParse(quantityController.text) ?? 0;
  }
}
```

---

#### 9. ATR止损计算器
**文件**: `lib/widgets/trade/components/atr_stop_loss_calculator.dart`

**关键功能**:
- ATR值输入
- ATR倍数输入
- 自动计算止损价

---

#### 10. 风险熔断区域
**文件**: `lib/widgets/trade/components/risk_meltdown_section.dart`

**从原文件提取**: `_buildRiskMeltdownSection()` 方法

**关键功能**:
- 风险百分比输入
- 熔断价格计算展示

---

#### 11. 盈亏比展示
**文件**: `lib/widgets/trade/components/profit_risk_ratio_display.dart`

**关键功能**:
- 盈亏比数值展示
- 可视化展示（进度条或图表）
- 颜色指示（好/中/差）

---

#### 12. 预览对话框
**文件**: `lib/widgets/trade/trade_preview_dialog.dart`

**从原文件提取**: `_buildDetailCard()` 方法

**关键功能**:
- 显示所有交易计划详情
- 确认按钮
- 取消按钮

---

## 🔧 重构主屏幕

### 最终的 add_trade_screen.dart（约250行）

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/trade/trade_form_data.dart';
import '../models/trade_record.dart';
import '../services/providers/trade_provider.dart';
import '../services/providers/strategy_provider.dart';
import '../services/providers/stock_provider.dart';
import '../services/trade/trade_calculation_service.dart';
import '../widgets/trade/stock_selection_card.dart';
import '../widgets/trade/kline_chart_card.dart';
import '../widgets/trade/market_phase_card.dart';
import '../widgets/trade/trade_details_card.dart';
import '../widgets/trade/strategy_selection_card.dart';
import '../widgets/trade/risk_control_card.dart';
import '../widgets/trade/trade_reason_card.dart';
import '../widgets/trade/trade_notes_card.dart';
import '../widgets/trade/trade_action_buttons.dart';
import '../widgets/trade/trade_preview_dialog.dart';

class AddTradeScreen extends StatefulWidget {
  const AddTradeScreen({super.key});

  @override
  State<AddTradeScreen> createState() => _AddTradeScreenState();
}

class _AddTradeScreenState extends State<AddTradeScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _stockCodeController = TextEditingController();
  final _stockNameController = TextEditingController();
  final _planPriceController = TextEditingController();
  final _planQuantityController = TextEditingController();
  final _stopLossPriceController = TextEditingController();
  final _takeProfitPriceController = TextEditingController();
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();
  final _atrValueController = TextEditingController();
  final _atrMultipleController = TextEditingController(text: '2.0');
  final _positionPercentageController = TextEditingController(text: '20.0');
  final _riskPercentageController = TextEditingController(text: '2.0');
  final _accountBalanceController = TextEditingController(text: '100000.0');
  final _accountTotalController = TextEditingController(text: '100000.0');
  
  // State
  late TradeFormData _formData;
  bool _showKLineChart = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _formData = TradeFormData.initial();
    _initializeControllers();
  }

  void _initializeControllers() {
    // 初始化所有controller的值
    _planPriceController.text = _formData.planPrice.toString();
    _planQuantityController.text = _formData.planQuantity.toString();
    // ... 其他controller
  }

  @override
  void dispose() {
    // 释放所有controller
    _stockCodeController.dispose();
    _stockNameController.dispose();
    // ... 其他controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: _buildAppBar(),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 股票选择
            StockSelectionCard(
              stockCodeController: _stockCodeController,
              stockNameController: _stockNameController,
              isManualInput: _formData.isManualInput,
              onManualInputChanged: (value) {
                setState(() {
                  _formData = _formData.copyWith(isManualInput: value);
                });
              },
              onStockSelected: (code, name) {
                setState(() {
                  _formData = _formData.copyWith(
                    stockCode: code,
                    stockName: name,
                  );
                  _showKLineChart = true;
                });
              },
              isDarkMode: isDarkMode,
            ),
            const SizedBox(height: 20),
            
            // K线图表
            if (_showKLineChart)
              KLineChartCard(
                stockCode: _formData.stockCode,
                stockName: _formData.stockName,
                isDarkMode: isDarkMode,
              ),
            if (_showKLineChart) const SizedBox(height: 20),
            
            // 市场阶段
            MarketPhaseCard(
              selectedPhase: _formData.marketPhase,
              selectedStrength: _formData.trendStrength,
              selectedDifficulty: _formData.entryDifficulty,
              onPhaseChanged: (phase) {
                setState(() {
                  _formData = _formData.copyWith(marketPhase: phase);
                });
              },
              onStrengthChanged: (strength) {
                setState(() {
                  _formData = _formData.copyWith(trendStrength: strength);
                });
              },
              onDifficultyChanged: (difficulty) {
                setState(() {
                  _formData = _formData.copyWith(entryDifficulty: difficulty);
                });
              },
              isDarkMode: isDarkMode,
            ),
            const SizedBox(height: 20),
            
            // 交易详情
            TradeDetailsCard(
              tradeType: _formData.tradeType,
              createTime: _formData.createTime,
              planPriceController: _planPriceController,
              planQuantityController: _planQuantityController,
              triggerType: _formData.triggerType,
              buildingMethod: _formData.buildingMethod,
              onTradeTypeChanged: (type) {
                setState(() {
                  _formData = _formData.copyWith(tradeType: type);
                });
              },
              onCreateTimeChanged: (time) {
                setState(() {
                  _formData = _formData.copyWith(createTime: time);
                });
              },
              onTriggerTypeChanged: (type) {
                setState(() {
                  _formData = _formData.copyWith(triggerType: type);
                });
              },
              onBuildingMethodChanged: (method) {
                setState(() {
                  _formData = _formData.copyWith(buildingMethod: method);
                });
              },
              isDarkMode: isDarkMode,
            ),
            const SizedBox(height: 20),
            
            // 策略选择
            StrategySelectionCard(
              selectedStrategy: _formData.selectedStrategy,
              onStrategyChanged: (strategy) {
                setState(() {
                  _formData = _formData.copyWith(selectedStrategy: strategy);
                });
              },
              isDarkMode: isDarkMode,
            ),
            const SizedBox(height: 20),
            
            // 风险控制
            RiskControlCard(
              stopLossPriceController: _stopLossPriceController,
              takeProfitPriceController: _takeProfitPriceController,
              atrValueController: _atrValueController,
              atrMultipleController: _atrMultipleController,
              positionPercentageController: _positionPercentageController,
              riskPercentageController: _riskPercentageController,
              accountBalanceController: _accountBalanceController,
              useAtrForStopLoss: _formData.useAtrForStopLoss,
              positionMethod: _formData.positionMethod,
              planPrice: double.tryParse(_planPriceController.text) ?? 0.0,
              planQuantity: int.tryParse(_planQuantityController.text) ?? 0,
              tradeType: _formData.tradeType,
              onUseAtrChanged: (value) {
                setState(() {
                  _formData = _formData.copyWith(useAtrForStopLoss: value);
                });
              },
              onPositionMethodChanged: (method) {
                setState(() {
                  _formData = _formData.copyWith(positionMethod: method);
                });
              },
              onQuantityChanged: (quantity) {
                _planQuantityController.text = quantity.toString();
                setState(() {
                  _formData = _formData.copyWith(planQuantity: quantity);
                });
              },
              isDarkMode: isDarkMode,
            ),
            const SizedBox(height: 20),
            
            // 交易原因
            TradeReasonCard(
              reasonController: _reasonController,
              isDarkMode: isDarkMode,
            ),
            const SizedBox(height: 20),
            
            // 备注
            TradeNotesCard(
              notesController: _notesController,
              isDarkMode: isDarkMode,
            ),
            const SizedBox(height: 32),
            
            // 操作按钮
            TradeActionButtons(
              onPreview: _showPreview,
              onSave: _saveTradeRecord,
              onAIAnalysis: _analyzeWithAI,
              isLoading: _isLoading,
              isDarkMode: isDarkMode,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text('添加交易计划'),
      actions: [
        IconButton(
          icon: Icon(_showKLineChart ? Icons.show_chart : Icons.show_chart_outlined),
          onPressed: () {
            setState(() {
              _showKLineChart = !_showKLineChart;
            });
          },
          tooltip: _showKLineChart ? '隐藏K线图' : '显示K线图',
        ),
      ],
    );
  }

  void _showPreview() {
    _updateFormDataFromControllers();
    showDialog(
      context: context,
      builder: (context) => TradePreviewDialog(formData: _formData),
    );
  }

  Future<void> _saveTradeRecord() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      _updateFormDataFromControllers();
      final tradeRecord = _formData.toTradeRecord();
      
      final tradeProvider = Provider.of<TradeProvider>(context, listen: false);
      await tradeProvider.addTrade(tradeRecord);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('交易计划已保存')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _analyzeWithAI() async {
    // AI分析逻辑
    // 保持原有的AI分析功能
  }

  void _updateFormDataFromControllers() {
    _formData = _formData.copyWith(
      stockCode: _stockCodeController.text,
      stockName: _stockNameController.text,
      planPrice: double.tryParse(_planPriceController.text) ?? 0.0,
      planQuantity: int.tryParse(_planQuantityController.text) ?? 0,
      stopLossPrice: double.tryParse(_stopLossPriceController.text),
      takeProfitPrice: double.tryParse(_takeProfitPriceController.text),
      atrValue: double.tryParse(_atrValueController.text),
      atrMultiple: double.tryParse(_atrMultipleController.text) ?? 2.0,
      positionPercentage: double.tryParse(_positionPercentageController.text) ?? 20.0,
      riskPercentage: double.tryParse(_riskPercentageController.text) ?? 2.0,
      accountBalance: double.tryParse(_accountBalanceController.text) ?? 100000.0,
      accountTotal: double.tryParse(_accountTotalController.text) ?? 100000.0,
      reason: _reasonController.text,
      notes: _notesController.text,
    );
  }
}
```

---

## 🚀 实施步骤

### 第1步：创建所有组件文件
按照上面的清单，逐个创建组件文件。每个组件都是独立的，可以并行开发。

### 第2步：从原文件复制代码
对于每个组件，从 `add_trade_screen.dart` 中找到对应的 `_build` 方法，复制到新组件中。

### 第3步：调整Props和回调
将原来的 `setState` 改为通过回调函数通知父组件。

### 第4步：测试每个组件
创建一个组件后，立即在主屏幕中使用并测试。

### 第5步：逐步替换
一个一个地替换原来的 `_build` 方法，确保功能正常。

---

## ✅ 验证清单

完成重构后，验证以下功能：

- [ ] 股票搜索和选择
- [ ] K线图显示
- [ ] 市场阶段选择
- [ ] 交易详情输入
- [ ] 策略选择
- [ ] 止损止盈设置
- [ ] ATR止损计算
- [ ] 仓位计算（三种方式）
- [ ] 风险熔断计算
- [ ] 盈亏比展示
- [ ] 交易原因输入
- [ ] 备注输入
- [ ] 预览功能
- [ ] 保存功能
- [ ] AI分析功能
- [ ] 表单验证
- [ ] 深色模式适配

---

## 📊 预期效果

### 重构前
- 单文件：7709行
- 难以维护
- 难以测试
- 难以复用

### 重构后
- 主文件：~250行（↓ 96.8%）
- 20+个独立组件
- 易于维护
- 易于测试
- 组件可复用

---

**按照这个指南，你可以系统地完成整个重构！** 🚀

