import 'package:flutter_test/flutter_test.dart';

void main() {
  group('盈亏预测计算测试', () {
    test('最大盈利计算测试', () {
      // 测试数据
      const double planPrice = 10.0;
      const int planQuantity = 1000;
      const double takeProfitPrice = 12.0;
      
      // 计算买入成本（含手续费）
      final buyAmount = planPrice * planQuantity;
      final buyCommission = buyAmount * 0.0003; // 0.03% 手续费
      final totalBuyCost = buyAmount + buyCommission;
      
      // 计算卖出收入（扣除手续费）
      final sellAmount = takeProfitPrice * planQuantity;
      final sellCommission = sellAmount * 0.0003; // 0.03% 手续费
      final netSellAmount = sellAmount - sellCommission;
      
      // 最大盈利 = 净卖出收入 - 总买入成本
      final maxProfit = netSellAmount - totalBuyCost;
      
      // 验证计算结果
      expect(buyAmount, equals(10000.0));
      expect(buyCommission, closeTo(3.0, 0.001));
      expect(totalBuyCost, closeTo(10003.0, 0.001));
      expect(sellAmount, equals(12000.0));
      expect(sellCommission, closeTo(3.6, 0.001));
      expect(netSellAmount, closeTo(11996.4, 0.001));
      expect(maxProfit, closeTo(1993.4, 0.001));
    });
    
    test('最大亏损计算测试', () {
      // 测试数据
      const double planPrice = 10.0;
      const int planQuantity = 1000;
      const double stopLossPrice = 8.0;
      
      // 计算买入成本（含手续费）
      final buyAmount = planPrice * planQuantity;
      final buyCommission = buyAmount * 0.0003; // 0.03% 手续费
      final totalBuyCost = buyAmount + buyCommission;
      
      // 计算止损卖出收入（扣除手续费）
      final sellAmount = stopLossPrice * planQuantity;
      final sellCommission = sellAmount * 0.0003; // 0.03% 手续费
      final netSellAmount = sellAmount - sellCommission;
      
      // 最大亏损 = 总买入成本 - 净卖出收入
      final maxLoss = totalBuyCost - netSellAmount;
      
      // 验证计算结果
      expect(buyAmount, equals(10000.0));
      expect(buyCommission, closeTo(3.0, 0.001));
      expect(totalBuyCost, closeTo(10003.0, 0.001));
      expect(sellAmount, equals(8000.0));
      expect(sellCommission, closeTo(2.4, 0.001));
      expect(netSellAmount, closeTo(7997.6, 0.001));
      expect(maxLoss, closeTo(2005.4, 0.001));
    });
    
    test('盈亏比计算测试', () {
      // 测试数据
      const double planPrice = 10.0;
      const double stopLossPrice = 8.0;
      const double takeProfitPrice = 14.0;
      
      // 计算盈亏比
      final riskPerUnit = (planPrice - stopLossPrice).abs();
      final rewardPerUnit = (takeProfitPrice - planPrice).abs();
      final profitRiskRatio = rewardPerUnit / riskPerUnit;
      
      // 验证计算结果
      expect(riskPerUnit, equals(2.0));
      expect(rewardPerUnit, equals(4.0));
      expect(profitRiskRatio, equals(2.0));
    });
    
    test('边界条件测试', () {
      // 测试零值情况
      expect(_calculateMaxProfit(0.0, 1000, 12.0), equals(0.0));
      expect(_calculateMaxProfit(10.0, 0, 12.0), equals(0.0));
      expect(_calculateMaxProfit(10.0, 1000, 0.0), equals(0.0));
      
      expect(_calculateMaxLoss(0.0, 1000, 8.0), equals(0.0));
      expect(_calculateMaxLoss(10.0, 0, 8.0), equals(0.0));
      expect(_calculateMaxLoss(10.0, 1000, 0.0), equals(0.0));
    });
  });
}

// 辅助函数，模拟实际应用中的计算逻辑
double _calculateMaxProfit(double planPrice, int planQuantity, double takeProfitPrice) {
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

double _calculateMaxLoss(double planPrice, int planQuantity, double stopLossPrice) {
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