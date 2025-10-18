/// 结算验证服务
/// 
/// 提供表单输入验证功能
class SettlementValidation {
  /// 验证价格
  /// 
  /// 规则：
  /// - 不能为空
  /// - 必须是有效数字
  /// - 必须大于0
  /// - 最多保留2位小数
  static String? validatePrice(String? value, {String fieldName = '价格'}) {
    if (value == null || value.isEmpty) {
      return '请输入$fieldName';
    }

    final price = double.tryParse(value);
    if (price == null) {
      return '请输入有效的$fieldName';
    }

    if (price <= 0) {
      return '$fieldName必须大于0';
    }

    // 检查小数位数
    if (value.contains('.')) {
      final decimalPart = value.split('.')[1];
      if (decimalPart.length > 2) {
        return '$fieldName最多保留2位小数';
      }
    }

    return null;
  }

  /// 验证数量
  /// 
  /// 规则：
  /// - 不能为空
  /// - 必须是有效整数
  /// - 必须大于0
  /// - 必须是100的整数倍（A股规则）
  static String? validateQuantity(String? value, {bool requireMultipleOf100 = true}) {
    if (value == null || value.isEmpty) {
      return '请输入数量';
    }

    final quantity = int.tryParse(value);
    if (quantity == null) {
      return '请输入有效的数量';
    }

    if (quantity <= 0) {
      return '数量必须大于0';
    }

    if (requireMultipleOf100 && quantity % 100 != 0) {
      return '数量必须是100的整数倍';
    }

    return null;
  }

  /// 验证佣金
  /// 
  /// 规则：
  /// - 可以为空（默认0）
  /// - 如果不为空，必须是有效数字
  /// - 必须大于等于0
  /// - 最多保留2位小数
  static String? validateCommission(String? value) {
    if (value == null || value.isEmpty || value == '0' || value == '0.0') {
      return null; // 允许为空或0
    }

    final commission = double.tryParse(value);
    if (commission == null) {
      return '请输入有效的佣金';
    }

    if (commission < 0) {
      return '佣金不能为负数';
    }

    // 检查小数位数
    if (value.contains('.')) {
      final decimalPart = value.split('.')[1];
      if (decimalPart.length > 2) {
        return '佣金最多保留2位小数';
      }
    }

    return null;
  }

  /// 验证税费
  /// 
  /// 规则：
  /// - 可以为空（默认0）
  /// - 如果不为空，必须是有效数字
  /// - 必须大于等于0
  /// - 最多保留2位小数
  static String? validateTax(String? value) {
    if (value == null || value.isEmpty || value == '0' || value == '0.0') {
      return null; // 允许为空或0
    }

    final tax = double.tryParse(value);
    if (tax == null) {
      return '请输入有效的税费';
    }

    if (tax < 0) {
      return '税费不能为负数';
    }

    // 检查小数位数
    if (value.contains('.')) {
      final decimalPart = value.split('.')[1];
      if (decimalPart.length > 2) {
        return '税费最多保留2位小数';
      }
    }

    return null;
  }

  /// 验证备注
  /// 
  /// 规则：
  /// - 可以为空
  /// - 最大长度500字符
  static String? validateNotes(String? value, {int maxLength = 500}) {
    if (value == null || value.isEmpty) {
      return null; // 允许为空
    }

    if (value.length > maxLength) {
      return '备注最多$maxLength个字符';
    }

    return null;
  }

  /// 验证价格合理性（与计划价格对比）
  /// 
  /// 规则：
  /// - 实际价格不应偏离计划价格太多（警告，不阻止提交）
  /// - 偏离超过20%给出警告
  static String? validatePriceReasonableness(
    double actualPrice,
    double planPrice, {
    double maxDeviationPercent = 20.0,
  }) {
    if (planPrice == 0) return null;

    final deviation = ((actualPrice - planPrice).abs() / planPrice) * 100;
    if (deviation > maxDeviationPercent) {
      return '实际价格与计划价格偏离${deviation.toStringAsFixed(1)}%，请确认是否正确';
    }

    return null;
  }

  /// 验证数量合理性（与计划数量对比）
  /// 
  /// 规则：
  /// - 实际数量不应偏离计划数量太多（警告，不阻止提交）
  /// - 偏离超过50%给出警告
  static String? validateQuantityReasonableness(
    int actualQuantity,
    int planQuantity, {
    double maxDeviationPercent = 50.0,
  }) {
    if (planQuantity == 0) return null;

    final deviation = ((actualQuantity - planQuantity).abs() / planQuantity) * 100;
    if (deviation > maxDeviationPercent) {
      return '实际数量与计划数量偏离${deviation.toStringAsFixed(1)}%，请确认是否正确';
    }

    return null;
  }
}

