/// 交易表单验证服务
/// 
/// 提供所有表单字段的验证逻辑
class TradeValidation {
  /// 验证股票代码
  static String? validateStockCode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '请输入股票代码';
    }
    
    final code = value.trim();
    
    // 检查是否为6位数字
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      return '股票代码必须是6位数字';
    }
    
    return null;
  }

  /// 验证股票名称
  static String? validateStockName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '请输入股票名称';
    }
    return null;
  }

  /// 验证价格
  static String? validatePrice(String? value, {String fieldName = '价格'}) {
    if (value == null || value.trim().isEmpty) {
      return '请输入$fieldName';
    }

    final price = double.tryParse(value);
    if (price == null) {
      return '$fieldName必须是有效的数字';
    }

    if (price <= 0) {
      return '$fieldName必须大于0';
    }

    return null;
  }

  /// 验证数量
  static String? validateQuantity(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '请输入数量';
    }

    final quantity = int.tryParse(value);
    if (quantity == null) {
      return '数量必须是整数';
    }

    if (quantity <= 0) {
      return '数量必须大于0';
    }

    if (quantity % 100 != 0) {
      return '数量必须是100的整数倍';
    }

    return null;
  }

  /// 验证止损价（相对于计划价）
  static String? validateStopLoss({
    required double? stopLoss,
    required double planPrice,
    required bool isBuy,
  }) {
    if (stopLoss == null) {
      return null; // 止损价可以为空
    }

    if (stopLoss <= 0) {
      return '止损价必须大于0';
    }

    if (isBuy) {
      // 买入时，止损价应该小于计划价
      if (stopLoss >= planPrice) {
        return '买入时止损价应小于计划价';
      }
    } else {
      // 卖出时，止损价应该大于计划价
      if (stopLoss <= planPrice) {
        return '卖出时止损价应大于计划价';
      }
    }

    return null;
  }

  /// 验证止盈价（相对于计划价）
  static String? validateTakeProfit({
    required double? takeProfit,
    required double planPrice,
    required bool isBuy,
  }) {
    if (takeProfit == null) {
      return null; // 止盈价可以为空
    }

    if (takeProfit <= 0) {
      return '止盈价必须大于0';
    }

    if (isBuy) {
      // 买入时，止盈价应该大于计划价
      if (takeProfit <= planPrice) {
        return '买入时止盈价应大于计划价';
      }
    } else {
      // 卖出时，止盈价应该小于计划价
      if (takeProfit >= planPrice) {
        return '卖出时止盈价应小于计划价';
      }
    }

    return null;
  }

  /// 验证ATR值
  static String? validateAtr(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '请输入ATR值';
    }

    final atr = double.tryParse(value);
    if (atr == null) {
      return 'ATR值必须是有效的数字';
    }

    if (atr <= 0) {
      return 'ATR值必须大于0';
    }

    return null;
  }

  /// 验证百分比
  static String? validatePercentage(String? value, {
    String fieldName = '百分比',
    double? min,
    double? max,
  }) {
    if (value == null || value.trim().isEmpty) {
      return '请输入$fieldName';
    }

    final percentage = double.tryParse(value);
    if (percentage == null) {
      return '$fieldName必须是有效的数字';
    }

    if (min != null && percentage < min) {
      return '$fieldName不能小于$min';
    }

    if (max != null && percentage > max) {
      return '$fieldName不能大于$max';
    }

    return null;
  }

  /// 验证交易原因
  static String? validateReason(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '请输入交易原因';
    }

    if (value.trim().length < 10) {
      return '交易原因至少需要10个字符';
    }

    return null;
  }
}

