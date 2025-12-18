import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ai_config.dart';
import '../models/trade_record.dart';
import '../services/ai_config_service.dart';

/// AI交易分析组件
/// 提供独立的AI分析功能，支持思考过程显示
class AITradeAnalysisWidget extends StatefulWidget {
  // 交易参数
  final String stockCode;
  final String stockName; 
  final TradeType tradeType;
  final double planPrice;
  final int planQuantity;
  final double stopLossPrice;
  final double takeProfitPrice;
  final double profitRiskRatio;
  final String marketPhase;
  final String trendStrength;
  final String entryDifficulty;
  final double positionPercentage;
  final double atrValue;
  final double atrMultiple;
  final double riskPercentage;
  final String reason;
  final List<Map<String, dynamic>> historyData;
  final String? actualTrend;
  
  // 回调函数
  final Function(bool isAnalyzing)? onAnalysisStateChanged;
  final Function(String analysisResult, String thinkingProcess)? onAnalysisComplete;
  
  const AITradeAnalysisWidget({
    Key? key,
    required this.stockCode,
    required this.stockName,
    required this.tradeType,
    required this.planPrice,
    required this.planQuantity,
    required this.stopLossPrice,
    required this.takeProfitPrice,
    required this.profitRiskRatio,
    required this.marketPhase,
    required this.trendStrength,
    required this.entryDifficulty,
    required this.positionPercentage,
    required this.atrValue,
    required this.atrMultiple,
    required this.riskPercentage,
    required this.reason,
    required this.historyData,
    this.actualTrend,
    this.onAnalysisStateChanged,
    this.onAnalysisComplete,
  }) : super(key: key);

  @override
  State<AITradeAnalysisWidget> createState() => _AITradeAnalysisWidgetState();
}

class _AITradeAnalysisWidgetState extends State<AITradeAnalysisWidget> {
  bool _isAnalyzing = false;
  String _analysisResult = '';
  
  @override
  void initState() {
    super.initState();
  }
  
  @override
  void dispose() {
    super.dispose();
  }
  
  /// 开始分析
  Future<void> startAnalysis() async {
    if (_isAnalyzing) return;
    
    setState(() {
      _isAnalyzing = true;
      _analysisResult = '';
    });
    
    if (widget.onAnalysisStateChanged != null) {
      widget.onAnalysisStateChanged!(true);
    }
    
    // 显示加载对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildLoadingDialog(context),
    );
    
    try {
      // 获取有效的AI配置
      final effectiveUrl = await AIConfigService.getEffectiveUrl();
      final effectiveApiKey = await AIConfigService.getEffectiveApiKey();
      final effectiveModel = await AIConfigService.getEffectiveModel();
      
      // 检查配置是否有效
      if (effectiveUrl == null || effectiveUrl.isEmpty ||
          effectiveApiKey == null || effectiveApiKey.isEmpty) {
        throw Exception('AI配置无效，请在设置中配置API服务地址和密钥');
      }
      
      // 准备历史数据文本
      final historyDataText = _formatHistoryData();
      
      // 系统提示和用户消息
      const systemPrompt = '''
      你是一位专业的股票交易分析师，擅长基于系统化交易策略和技术分析方法评估交易计划的成功率。
            
      请将回复分为两个独立部分:
      1. 分析结论：面向交易者的关键结果，必须包含三个要点：
         - 交易成功率评估：必须给出准确的百分比估计，并根据以下因素综合评判:
           * 交易方向与市场趋势的一致性
           * 入场价格在支撑/阻力位的位置
           * 盈亏比的合理性(应≥1.5)
           * 止损位是否符合市场波动性(ATR倍数)
           * 市场阶段与趋势强度的匹配度
         - 参数优化建议：精确指出用户设置中需要调整的参数，如:
           * 止损位过紧或过松
           * 仓位比例不合理
           * ATR倍数设置不当
           * 风险比例超标
         - 交易决策建议：明确告知交易者是否应该执行交易，包括:
           * 建议执行/不执行的明确意见
           * 如建议执行，说明关键优势和注意事项
           * 如不建议执行，提供具体的修改方案
      专业要求：
      - 成功率评估必须基于量化交易原则，而非主观猜测
      - 如果成功率低于40%，必须明确建议不要入场
      - 如果市场趋势与用户判断不符，必须指出并根据历史数据给出正确判断
      - 使用专业术语评估交易设置(如：趋势确认度、价格结构、支撑阻力、波动率适应性等)
      - 总是以简洁的要点清单和明确的交易建议结束分析
      ''';
      
      final userPrompt = '''
      请分析以下交易计划:
      
      股票: ${widget.stockCode} ${widget.stockName}
      交易方向: ${widget.tradeType == TradeType.buy ? "买入" : "卖出"}
      计划价格: ${widget.planPrice}
      计划数量: ${widget.planQuantity}股
      止损价格: ${widget.stopLossPrice}
      目标价格: ${widget.takeProfitPrice}
      盈亏比: ${widget.profitRiskRatio.toStringAsFixed(2)}
      用户选择的市场阶段: ${widget.marketPhase}
      历史数据显示的实际趋势: ${widget.actualTrend ?? '未知'}
      趋势强度: ${widget.trendStrength}
      入场难度: ${widget.entryDifficulty}
      仓位比例: ${widget.positionPercentage}%
      ATR值: ${widget.atrValue}
      ATR倍数: ${widget.atrMultiple}
      风险熔断: ${widget.riskPercentage}%
      交易理由: ${widget.reason}
      
      $historyDataText
      
      请提供：
              
      【分析结论】
      1. 交易成功率评估：准确百分比表示，基于交易方向、市场阶段、盈亏比、历史数据等综合分析
      2. 参数优化建议：指出交易参数中不合理的设置，并提供调整方案
      3. 交易决策建议：明确告知是否执行交易，如建议执行需说明优势，如不建议则提供具体修改方案
      4. 交易策略改进建议：如何完善当前策略，提高胜率和稳定性
      格式要求：
      - 必须严格按照以下格式返回结果：
      
      # 【分析结论】
      
      ## 🎯 交易成功率评估
      **预估成功率：XX%**
      
      ## 📊 参数优化建议
      ### ⚠️ 风险提示
      ### 💡 优化建议
      ### ✅ 计划优势
      
      ## 🎯 交易决策建议
      ### 📈 建议执行/⚖️ 谨慎执行/🚫 不建议执行
      
      ## 🔧 交易策略改进建议
      
      - 分析结论部分必须简洁明了，突出关键信息
      - 交易建议部分必须明确，交易者能一眼看出是否应该执行交易
      - 使用简单的Markdown格式提高可读性
      - 如有不良的参数设置，务必指出并提供明确的修正建议
      ''';
      
      print('正在调用AI API进行交易分析（非流式）...');
      
      // 使用HTTP调用非流式API
      final apiUrl = effectiveUrl;
      
      // 构建请求
      final requestBody = {
        'model': effectiveModel,
        'messages': [
          {
            'role': 'system',
            'content': systemPrompt,
          },
          {
            'role': 'user',
            'content': userPrompt,
          }
        ],
        'stream': false,
        'max_tokens': AIConfig.maxTokens,
        'enable_thinking': false, // 禁用思考过程，直接输出结论
        'min_p': AIConfig.minP,
        'temperature': AIConfig.temperature,
        'top_p': AIConfig.topP,
        'top_k': AIConfig.topK,
        'frequency_penalty': AIConfig.frequencyPenalty,
        'n': 1,
        'stop': [],
      };
      
      // 记录请求内容
      print('API请求参数: ${jsonEncode(requestBody)}');
      
      // 发送请求
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $effectiveApiKey',
        },
        body: jsonEncode(requestBody),
      );
      
      // 检查响应状态
      if (response.statusCode != 200) {
        print('API调用失败，状态码: ${response.statusCode}');
        print('错误信息: ${response.body}');
        throw Exception('AI服务调用失败: ${response.statusCode}');
      }
      
      print('API调用成功，解析响应...');
      
      // 打印完整的API响应供调试
      print('=========完整API响应开始=========');
      print(response.body);
      print('=========完整API响应结束=========');
      
      // 解析响应
      final jsonResponse = jsonDecode(response.body);
      
      // 提取分析结果，不再使用思考过程
      final analysisResult = jsonResponse['choices'][0]['message']['content'] as String? ?? '';
      
      // 将分析结果转换为Markdown格式
      var markdown = analysisResult.trim();
      
      // 处理重复的分析结论问题
      // 检查是否包含重复的【分析结论】标记
      const analysisMarker = "【分析结论】";
      if (markdown.indexOf(analysisMarker) != markdown.lastIndexOf(analysisMarker)) {
        print('检测到重复的分析结论部分，进行处理...');
        // 只保留第一个【分析结论】部分
        final firstMarkerIndex = markdown.indexOf(analysisMarker);
        final secondMarkerIndex = markdown.indexOf(analysisMarker, firstMarkerIndex + 1);
        markdown = markdown.substring(0, secondMarkerIndex).trim();
      }
      
      // 替换为Markdown格式
      markdown = markdown.replaceAllMapped(
        RegExp(r'(\d+)\.\s+'), 
        (match) => "\n${match.group(0)}"
      );
      
      markdown = markdown.replaceAll("优势：", "### 优势");
      markdown = markdown.replaceAll("风险提示：", "### 风险提示");
      markdown = markdown.replaceAll("建议：", "### 建议");
      markdown = markdown.replaceAll("【分析结论】", ""); // 移除分析结论标记
      
      // 更新状态和结果
      setState(() {
        _analysisResult = markdown;
        _isAnalyzing = false;
      });
      
      // 关闭加载对话框
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      // 调用回调
      if (widget.onAnalysisComplete != null) {
        widget.onAnalysisComplete!(_analysisResult, "");
      }
      
      if (widget.onAnalysisStateChanged != null) {
        widget.onAnalysisStateChanged!(false);
      }
      
      // 显示结果对话框
      showAnalysisResult();
      
    } catch (e, stackTrace) {
      print('AI分析出错: $e');
      print('堆栈信息: $stackTrace');
      
      // 错误处理
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI分析服务暂时不可用: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      
      // 更新状态
      setState(() {
        _isAnalyzing = false;
      });
      
      // 关闭加载对话框
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      // 回调通知分析状态变化
      if (widget.onAnalysisStateChanged != null) {
        widget.onAnalysisStateChanged!(false);
      }
    }
  }
  
  /// 构建加载对话框
  Widget _buildLoadingDialog(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.blue.shade50,
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // AI 图标容器
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.blue.shade400,
                    Colors.blue.shade600,
                  ],
                ),
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.psychology,
                size: 40,
                color: Colors.white,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 现代化加载动画
            Stack(
              alignment: Alignment.center,
              children: [
                // 外圈渐变光圈
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Colors.blue.shade300.withOpacity(0.15),
                        Colors.purple.shade300.withOpacity(0.15),
                      ],
                    ),
                  ),
                ),
                // 中圈
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue.shade50,
                  ),
                ),
                // 旋转的进度环
                SizedBox(
                  width: 70,
                  height: 70,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.blue.shade600,
                    ),
                    strokeWidth: 4,
                    backgroundColor: Colors.blue.shade200.withOpacity(0.2),
                  ),
                ),
                // 中心AI图标
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Colors.blue.shade500,
                        Colors.blue.shade700,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.psychology,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // 标题
            Text(
              'AI 正在深度分析',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
                letterSpacing: 0.5,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 分析步骤卡片
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.blue.shade200,
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  _buildLoadingStep(Icons.assessment, '评估交易可行性'),
                  const SizedBox(height: 12),
                  _buildLoadingStep(Icons.analytics, '分析技术指标'),
                  const SizedBox(height: 12),
                  _buildLoadingStep(Icons.security, '计算风险收益'),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // 时间提示
            Text(
              '预计需要 10-20 秒',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
            ),
            
            const SizedBox(height: 32),
            
            // 取消按钮
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _isAnalyzing = false;
                  });
                  Navigator.pop(context);
                  
                  if (widget.onAnalysisStateChanged != null) {
                    widget.onAnalysisStateChanged!(false);
                  }
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(
                    color: Colors.grey.shade400,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  '取消分析',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// 构建加载步骤指示器
  Widget _buildLoadingStep(IconData icon, String text) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.blue.shade100,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 18,
            color: Colors.blue.shade700,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(
              Colors.blue.shade600,
            ),
          ),
        ),
      ],
    );
  }
  
  /// 格式化历史数据
  String _formatHistoryData() {
    if (widget.historyData.isEmpty) return "无历史数据";
    
    // 最多取20条数据
    const lastNDays = 20;
    final recentHistory = widget.historyData.length > lastNDays 
        ? widget.historyData.sublist(widget.historyData.length - lastNDays) 
        : widget.historyData;
    
    // 反转顺序，让最新的在最前面
    final reversedHistory = recentHistory.reversed.toList();
    
    String historyDataText = "最近${reversedHistory.length}天K线数据（第一行是最新日期）:\n";
    historyDataText += "**重要提示**: 下面的数据第一行是最新的，越往下越旧。请重点分析最近几天的走势！\n\n";
    
    for (var i = 0; i < reversedHistory.length; i++) {
      final item = reversedHistory[i];
      
      // 标注最近的几天
      String prefix = '';
      if (i == 0) prefix = '【最新】';
      else if (i == 1) prefix = '【前一天】';
      else if (i == 2) prefix = '【前两天】';
      
      historyDataText += "$prefix${item['date']} 开:${item['open']} 高:${item['high']} 低:${item['low']} 收:${item['close']} 量:${item['volume']}\n";
    }
    
    return historyDataText;
  }
  
  /// 显示分析结果对话框
  void showAnalysisResult() {
    if (_analysisResult.isEmpty) {
      startAnalysis();
      return;
    }
    
    // 转换为Markdown格式
    final String markdownContent = """
## ${widget.stockCode} ${widget.stockName}

**交易方向**: ${widget.tradeType == TradeType.buy ? "买入" : "卖出"} | **计划价格**: ${widget.planPrice}

---

$_analysisResult

---

*分析仅供参考，实际交易请结合市场情况自行判断*
    """;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
            maxWidth: MediaQuery.of(context).size.width - 40,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题栏
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF2F80ED),
                      Color(0xFF56CCF2),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.psychology,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'AI交易分析',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
              
              // 内容区域 - 修复溢出问题
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Markdown(
                    data: markdownContent,
                    selectable: true,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                      styleSheet: MarkdownStyleSheet(
                        h2: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3748),
                          height: 1.4,
                        ),
                        h3: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4A5568),
                          height: 1.3,
                        ),
                        strong: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: widget.tradeType == TradeType.buy 
                              ? const Color(0xFF38A169) 
                              : const Color(0xFFE53E3E),
                        ),
                        p: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF4A5568),
                          height: 1.5,
                        ),
                        em: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                        horizontalRuleDecoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              width: 1.0,
                              color: Colors.grey.shade200,
                            ),
                          ),
                        ),
                        blockquote: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF718096),
                          fontStyle: FontStyle.italic,
                        ),
                        blockquoteDecoration: BoxDecoration(
                          color: const Color(0xFFF7FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: const Border(
                            left: BorderSide(
                              color: Color(0xFF2F80ED),
                              width: 4,
                            ),
                          ),
                        ),
                        blockquotePadding: const EdgeInsets.all(12),
                      ),
                    ),
                  ),
              ),
              
              // 底部操作栏
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFFF7FAFC),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // 重新分析
                          Navigator.pop(context);
                          startAnalysis();
                        },
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('重新分析'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: const BorderSide(color: Color(0xFF2F80ED)),
                          foregroundColor: const Color(0xFF2F80ED),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('确定'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: const Color(0xFF2F80ED),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // 添加测试函数
  Future<void> _testApiCall() async {
    try {
      print('测试API调用...');
      
      // 获取有效的AI配置
      final effectiveUrl = await AIConfigService.getEffectiveUrl();
      final effectiveApiKey = await AIConfigService.getEffectiveApiKey();
      final effectiveModel = await AIConfigService.getEffectiveModel();
      
      // 检查配置是否有效
      if (effectiveUrl == null || effectiveUrl.isEmpty ||
          effectiveApiKey == null || effectiveApiKey.isEmpty) {
        throw Exception('AI配置无效，请在设置中配置API服务地址和密钥');
      }
      
      final apiUrl = effectiveUrl;
      
      // 使用与示例完全相同的结构，但是非流式
      final requestBody = {
        'model': effectiveModel,
        'messages': [
          {
            'role': 'user',
            'content': '乌龟为啥跑的快',
          }
        ],
        'stream': false,
        'max_tokens': AIConfig.maxTokens,
        'enable_thinking': false, // 禁用思考过程，直接输出结论
        'min_p': AIConfig.minP,
        'temperature': AIConfig.temperature,
        'top_p': AIConfig.topP,
        'top_k': AIConfig.topK,
        'frequency_penalty': AIConfig.frequencyPenalty,
        'n': 1,
        'stop': [],
      };
      
      print('测试请求参数: ${jsonEncode(requestBody)}');
      
      // 发送请求
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $effectiveApiKey',
        },
        body: jsonEncode(requestBody),
      );
      
      if (response.statusCode != 200) {
        print('测试API调用失败，状态码: ${response.statusCode}');
        print('错误信息: ${response.body}');
        throw Exception('API调用失败: ${response.statusCode}');
      }
      
      print('测试API调用成功，状态码: ${response.statusCode}');
      
      // 打印完整响应内容，不省略任何内容
      print('=========测试API完整响应开始=========');
      print(response.body);
      print('=========测试API完整响应结束=========');
      
    } catch (e, stackTrace) {
      print('测试API调用出错: $e');
      print('堆栈信息: $stackTrace');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton.icon(
          icon: ShaderMask(
            shaderCallback: (rect) {
              return const LinearGradient(
                colors: [
                  Color(0xFF2F80ED), // 更现代的蓝色
                  Color(0xFF56CCF2), // 淡蓝色
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(rect);
            },
            child: const Icon(Icons.psychology),
          ),
          label: const Text('AI交易分析'),
          onPressed: _isAnalyzing ? null : startAnalysis,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
          ),
        ),
        
        // 仅在调试模式下显示测试按钮
        if (const bool.fromEnvironment('dart.vm.product') == false)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: TextButton(
              onPressed: _testApiCall,
              child: const Text('测试API调用', style: TextStyle(fontSize: 12)),
            ),
          ),
      ],
    );
  }
} 