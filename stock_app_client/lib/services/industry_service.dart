import 'package:flutter/material.dart';

/// 行业数据增强服务
/// 用于完善股票行业分类，解决板块显示为"其它"的问题
class IndustryService {
  
  // 行业分类数据字典 - 根据股票代码前缀和名称特征推断行业
  static const Map<String, List<String>> _industryKeywords = {
    '银行': ['银行', '中国银行', '工商银行', '建设银行', '农业银行', '招商银行', '兴业银行', '民生银行', '浦发银行', '中信银行', '光大银行', '华夏银行', '平安银行', '交通银行'],
    '保险': ['保险', '人寿', '太保', '平安', '新华保险', '中国人保'],
    '证券': ['证券', '中信证券', '海通证券', '广发证券', '华泰证券', '国泰君安', '招商证券', '中金公司'],
    '房地产': ['地产', '万科', '保利', '融创', '恒大', '碧桂园', '金地', '招商蛇口', '华侨城', '万达', '绿地'],
    '白酒': ['茅台', '五粮液', '剑南春', '泸州老窖', '山西汾酒', '酒鬼酒', '舍得酒业', '今世缘', '水井坊'],
    '医药生物': ['医药', '药业', '生物', '医疗', '康美', '恒瑞医药', '复星医药', '同仁堂', '云南白药', '片仔癀', '东阿阿胶'],
    '食品饮料': ['食品', '饮料', '乳业', '伊利', '蒙牛', '双汇', '海天味业', '中炬高新', '贵州茅台'],
    '家用电器': ['电器', '格力', '美的', '海尔', '老板电器', '九阳', '苏泊尔', '小天鹅'],
    '汽车': ['汽车', '比亚迪', '长城汽车', '吉利汽车', '上汽集团', '一汽', '东风汽车', '广汽集团'],
    '新能源汽车': ['新能源', '蔚来', '小鹏', '理想', '比亚迪'],
    '电子': ['电子', '电路', '芯片', '半导体', '京东方', '海康威视', '大华股份', '立讯精密'],
    '计算机': ['软件', '计算机', '科技', '网络', '数据', '腾讯', '阿里巴巴', '百度', '网易', '用友网络'],
    '通信': ['通信', '电信', '移动', '联通', '华为', '中兴通讯', '烽火通信'],
    '传媒': ['传媒', '影视', '游戏', '广告', '出版', '分众传媒', '华谊兄弟', '光线传媒'],
    '公用事业': ['电力', '水务', '燃气', '供电', '华能', '大唐', '华电', '国电'],
    '交通运输': ['航空', '铁路', '港口', '物流', '快递', '南方航空', '国航', '东方航空', '顺丰控股'],
    '建筑材料': ['水泥', '钢铁', '建材', '玻璃', '海螺水泥', '华新水泥', '宝钢股份', '河钢股份'],
    '化工': ['化工', '石化', '农药', '化肥', '中国石化', '中国石油', '万华化学', '恒力石化'],
    '有色金属': ['有色', '金属', '铜业', '铝业', '黄金', '紫金矿业', '中国铝业', '山东黄金'],
    '煤炭': ['煤炭', '煤业', '中国神华', '兖州煤业', '陕西煤业'],
    '钢铁': ['钢铁', '宝钢', '河钢', '沙钢', '首钢'],
    '机械设备': ['机械', '设备', '重工', '装备', '中联重科', '三一重工', '徐工机械'],
    '国防军工': ['军工', '航天', '航空', '兵器', '中航', '航发'],
    '农林牧渔': ['农业', '林业', '牧业', '渔业', '种业', '温氏股份', '牧原股份', '新希望'],
    '轻工制造': ['轻工', '制造', '家具', '造纸', '包装', '索菲亚', '太阳纸业'],
    '纺织服装': ['纺织', '服装', '服饰', '申洲国际', '海澜之家', '森马服饰'],
    '商业贸易': ['商业', '贸易', '零售', '百货', '超市', '永辉超市', '大商股份'],
    '休闲服务': ['旅游', '酒店', '餐饮', '景区', '中国国旅', '宋城演艺'],
    '综合': ['控股', '集团', '综合', '投资'],
  };

  // 特殊股票代码的行业映射
  static const Map<String, String> _codeIndustryMap = {
    // 银行
    '000001': '银行', '600000': '银行', '600036': '银行', '601988': '银行', 
    '601398': '银行', '600016': '银行', '000002': '房地产',
    
    // 白酒
    '600519': '白酒', '000858': '白酒', '000596': '白酒',
    
    // 科技
    '000063': '计算机', '300750': '新能源汽车',
    '688036': '电子',
    
    // 医药
    '000568': '医药生物', '300760': '医药生物', '600276': '医药生物',
    
    // 汽车与新能源
    '002594': '新能源汽车', '601633': '汽车',
  };

  /// 增强行业分类信息
  static String enhanceIndustry(String? originalIndustry, String stockCode, String stockName) {
    // 如果原始行业信息有效且不是"其它"，直接返回
    if (originalIndustry != null && 
        originalIndustry.trim().isNotEmpty && 
        originalIndustry != '其它' && 
        originalIndustry != '其他' &&
        originalIndustry != 'null') {
      return originalIndustry.trim();
    }

    // 1. 首先检查代码映射
    if (_codeIndustryMap.containsKey(stockCode)) {
      return _codeIndustryMap[stockCode]!;
    }

    // 2. 根据股票名称关键词匹配行业
    for (final entry in _industryKeywords.entries) {
      final industry = entry.key;
      final keywords = entry.value;
      
      for (final keyword in keywords) {
        if (stockName.contains(keyword)) {
          return industry;
        }
      }
    }

    // 3. 根据股票代码前缀推断行业（主要用于银行等金融股）
    return _inferIndustryFromCode(stockCode, stockName);
  }

  /// 根据股票代码推断行业
  static String _inferIndustryFromCode(String stockCode, String stockName) {
    if (stockCode.length >= 6) {
      final prefix = stockCode.substring(0, 3);
      
      // 银行股票多以60开头
      if (prefix == '600' && (stockName.contains('银行') || stockName.contains('Bank'))) {
        return '银行';
      }
      
      // 科创板多为科技类
      if (prefix == '688') {
        if (stockName.contains('科技') || stockName.contains('软件') || stockName.contains('电子')) {
          return '计算机';
        }
        if (stockName.contains('医药') || stockName.contains('生物')) {
          return '医药生物';
        }
        return '电子'; // 科创板默认为电子行业
      }
      
      // 创业板多为成长性行业
      if (prefix == '300' || prefix == '301') {
        if (stockName.contains('科技') || stockName.contains('软件')) {
          return '计算机';
        }
        if (stockName.contains('医药') || stockName.contains('生物')) {
          return '医药生物';
        }
        if (stockName.contains('新能源') || stockName.contains('电池')) {
          return '新能源汽车';
        }
        return '电子'; // 创业板默认为电子行业
      }
      
      // 主板股票根据名称特征进一步推断
      if (prefix == '000' || prefix == '002' || prefix == '600' || prefix == '601' || prefix == '603') {
        // 通用的行业特征词匹配
        if (stockName.contains('科技') || stockName.contains('软件') || stockName.contains('网络') || stockName.contains('数据') || stockName.contains('信息')) {
          return '计算机';
        }
        if (stockName.contains('电子') || stockName.contains('芯片') || stockName.contains('半导体') || stockName.contains('显示')) {
          return '电子';
        }
        if (stockName.contains('机械') || stockName.contains('设备') || stockName.contains('制造') || stockName.contains('工业')) {
          return '机械设备';
        }
        if (stockName.contains('化工') || stockName.contains('材料') || stockName.contains('新材')) {
          return '化工';
        }
        if (stockName.contains('能源') || stockName.contains('电力') || stockName.contains('新能源')) {
          return '公用事业';
        }
        if (stockName.contains('汽车') || stockName.contains('零部件')) {
          return '汽车';
        }
      }
    }

    // 如果都无法推断，根据常见词汇做最后尝试
    final nameChecks = [
      {'keywords': ['集团', '控股', '投资'], 'industry': '综合'},
      {'keywords': ['贸易', '商业', '零售'], 'industry': '商业贸易'},
      {'keywords': ['建筑', '建设', '工程'], 'industry': '建筑材料'},
      {'keywords': ['传媒', '文化', '影视'], 'industry': '传媒'},
      {'keywords': ['农业', '种业', '养殖'], 'industry': '农林牧渔'},
    ];
    
    for (final check in nameChecks) {
      final keywords = check['keywords'] as List<String>;
      final industry = check['industry'] as String;
      
             for (final keyword in keywords) {
         if (stockName.contains(keyword)) {
           return industry;
         }
       }
     }
 
     return '综合';
  }

  /// 获取行业颜色 - 与现有组件保持一致的配色方案
  static Color getIndustryColor(String industry) {
    // 专业的金融类配色方案
    final industryColors = <String, Color>{
      '银行': const Color(0xFF2196F3),        // 蓝色 - 稳重可靠
      '保险': const Color(0xFF1976D2),        // 深蓝 - 保障安全
      '证券': const Color(0xFF3F51B5),        // 靛蓝 - 专业权威
      '房地产': const Color(0xFF795548),      // 棕色 - 稳固建筑
      '白酒': const Color(0xFFD32F2F),        // 红色 - 中国红
      '医药生物': const Color(0xFF4CAF50),    // 绿色 - 健康生命
      '食品饮料': const Color(0xFF8BC34A),    // 浅绿 - 天然食品
      '家用电器': const Color(0xFF9C27B0),    // 紫色 - 智能科技
      '汽车': const Color(0xFF607D8B),        // 蓝灰 - 工业制造
      '新能源汽车': const Color(0xFF4CAF50),  // 绿色 - 环保科技
      '新能源': const Color(0xFF8BC34A),      // 浅绿 - 清洁能源
      '电子': const Color(0xFF2196F3),        // 蓝色 - 电子科技
      '计算机': const Color(0xFF673AB7),      // 深紫 - 数字科技
      '通信': const Color(0xFF3F51B5),        // 靛蓝 - 网络连接
      '传媒': const Color(0xFFE91E63),        // 粉红 - 创意文化
      '公用事业': const Color(0xFF795548),    // 棕色 - 基础设施
      '交通运输': const Color(0xFF607D8B),    // 蓝灰 - 物流运输
      '建筑材料': const Color(0xFF5D4037),    // 深棕 - 建筑材料
      '化工': const Color(0xFF424242),        // 深灰 - 化学工业
      '有色金属': const Color(0xFFBF6000),    // 橙棕 - 金属材料
      '煤炭': const Color(0xFF212121),        // 黑色 - 煤炭能源
      '钢铁': const Color(0xFF455A64),        // 钢铁灰
      '机械设备': const Color(0xFF546E7A),    // 机械灰
      '国防军工': const Color(0xFF1B5E20),    // 军绿色
      '农林牧渔': const Color(0xFF689F38),    // 农业绿
      '轻工制造': const Color(0xFF7B1FA2),    // 制造紫
      '纺织服装': const Color(0xFFAD1457),    // 时尚粉
      '商业贸易': const Color(0xFFE65100),    // 商业橙
      '休闲服务': const Color(0xFFFF8F00),    // 服务黄
      '综合': const Color(0xFF6B7280),        // 灰色 - 综合类
    };

    // 如果有精确匹配，返回对应颜色
    if (industryColors.containsKey(industry)) {
      return industryColors[industry]!;
    }

    // 模糊匹配
    for (final entry in industryColors.entries) {
      if (industry.contains(entry.key) || entry.key.contains(industry)) {
        return entry.value;
      }
    }

    // 如果都没有匹配，使用哈希值生成颜色（保持一致性）
    final hash = industry.hashCode.abs();
    final colorPalette = [
      const Color(0xFF1E40AF), // 深蓝色 - 专业稳重
      const Color(0xFF059669), // 深绿色 - 成长稳健  
      const Color(0xFF7C2D12), // 深棕色 - 传统行业
      const Color(0xFF4338CA), // 深靛蓝 - 科技行业
      const Color(0xFF0891B2), // 深青色 - 新兴产业
      const Color(0xFFB45309), // 深橙色 - 制造业
      const Color(0xFF9333EA), // 深紫色 - 创新行业
      const Color(0xFF16A34A), // 深墨绿 - 环保能源
      const Color(0xFFDC2626), // 深红色 - 金融地产
      const Color(0xFF6B7280), // 深灰色 - 其他行业
    ];
    
    return colorPalette[hash % colorPalette.length];
  }

  /// 获取行业图标
  static IconData getIndustryIcon(String industry) {
    final industryIcons = <String, IconData>{
      '银行': Icons.account_balance,
      '保险': Icons.security,
      '证券': Icons.trending_up,
      '房地产': Icons.home_work,
      '白酒': Icons.wine_bar,
      '医药生物': Icons.medical_services,
      '食品饮料': Icons.restaurant,
      '家用电器': Icons.electrical_services,
      '汽车': Icons.directions_car,
      '新能源汽车': Icons.electric_car,
      '新能源': Icons.bolt,
      '电子': Icons.memory,
      '计算机': Icons.computer,
      '通信': Icons.wifi,
      '传媒': Icons.tv,
      '公用事业': Icons.power,
      '交通运输': Icons.local_shipping,
      '建筑材料': Icons.construction,
      '化工': Icons.science,
      '有色金属': Icons.layers,
      '煤炭': Icons.eco,
      '钢铁': Icons.precision_manufacturing,
      '机械设备': Icons.precision_manufacturing,
      '国防军工': Icons.shield,
      '农林牧渔': Icons.agriculture,
      '轻工制造': Icons.handyman,
      '纺织服装': Icons.checkroom,
      '商业贸易': Icons.store,
      '休闲服务': Icons.beach_access,
      '综合': Icons.business_center,
    };

    return industryIcons[industry] ?? Icons.business_center;
  }
} 