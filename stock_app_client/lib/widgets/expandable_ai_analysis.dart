/// 可展开的AI分析Widget
/// 支持固定高度显示和点击展开查看完整内容
library;

import 'package:flutter/material.dart';
import '../models/ai_analysis_result.dart';

class ExpandableAIAnalysis extends StatefulWidget {
  final AIAnalysisResult analysis;
  final double collapsedHeight;
  
  const ExpandableAIAnalysis({
    Key? key,
    required this.analysis,
    this.collapsedHeight = 80,
  }) : super(key: key);
  
  @override
  State<ExpandableAIAnalysis> createState() => _ExpandableAIAnalysisState();
}

class _ExpandableAIAnalysisState extends State<ExpandableAIAnalysis>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _controller;
  late Animation<double> _animation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }
  
  Color _getSignalColor() {
    if (widget.analysis.isBuySignal) {
      return Colors.red;
    } else if (widget.analysis.isSellSignal) {
      return Colors.green;
    } else {
      return Colors.orange;
    }
  }
  
  IconData _getSignalIcon() {
    if (widget.analysis.isBuySignal) {
      return Icons.trending_up;
    } else if (widget.analysis.isSellSignal) {
      return Icons.trending_down;
    } else {
      return Icons.trending_flat;
    }
  }
  
  Color _getConfidenceColor() {
    switch (widget.analysis.confidenceLevel) {
      case 3:
        return Colors.green;
      case 2:
        return Colors.orange;
      case 1:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C3E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getSignalColor().withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          _buildHeader(),
          
          // 内容区域
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: _isExpanded ? double.infinity : widget.collapsedHeight,
              ),
              child: SingleChildScrollView(
                physics: _isExpanded
                    ? const AlwaysScrollableScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                child: _buildContent(),
              ),
            ),
          ),
          
          // 展开/收起按钮
          _buildExpandButton(),
        ],
      ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getSignalColor().withOpacity(0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          // AI图标
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.psychology,
              color: Colors.purple,
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
          
          // AI分析标题
          const Text(
            'AI分析',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const Spacer(),
          
          // 信号标签
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _getSignalColor(),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getSignalIcon(),
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  widget.analysis.signal,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 8),
          
          // 置信度
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getConfidenceColor().withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _getConfidenceColor(),
                width: 1,
              ),
            ),
            child: Text(
              widget.analysis.confidence,
              style: TextStyle(
                color: _getConfidenceColor(),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 分析理由
          Text(
            widget.analysis.reason,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          
          if (_isExpanded) ...[
            const SizedBox(height: 16),
            
            // 关键价位
            _buildPriceInfo(),
            
            // 技术分析详情
            if (widget.analysis.technicalAnalysis != null) ...[
              const SizedBox(height: 16),
              _buildTechnicalDetails(),
            ],
            
            // 风险提示
            if (widget.analysis.riskWarning != null) ...[
              const SizedBox(height: 16),
              _buildRiskWarning(),
            ],
          ],
        ],
      ),
    );
  }
  
  Widget _buildPriceInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '关键价位',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          
          Row(
            children: [
              Expanded(
                child: _buildPriceItem(
                  '目标价',
                  widget.analysis.takeProfit,
                  Colors.red,
                  Icons.flag,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPriceItem(
                  '止损价',
                  widget.analysis.stopLoss,
                  Colors.green,
                  Icons.shield,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildPriceItem(String label, double? price, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color.withOpacity(0.7),
                  fontSize: 11,
                ),
              ),
              Text(
                price != null ? '¥${price.toStringAsFixed(2)}' : '--',
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildTechnicalDetails() {
    final tech = widget.analysis.technicalAnalysis!;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '技术分析',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          
          _buildTechItem('整体趋势', tech.overallTrend),
          _buildTechItem('短期趋势', tech.shortTermTrend),
          _buildTechItem('RSI状态', '${tech.rsiStatus} (${tech.rsiValue?.toStringAsFixed(1) ?? '--'})'),
          _buildTechItem('MACD方向', tech.macdDirection),
          
          if (tech.support != null && tech.resistance != null) ...[
            const Divider(color: Colors.white24, height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTechItem('支撑位', '¥${tech.support!.toStringAsFixed(2)}'),
                ),
                Expanded(
                  child: _buildTechItem('阻力位', '¥${tech.resistance!.toStringAsFixed(2)}'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildTechItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRiskWarning() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.orange.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '风险提示',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.analysis.riskWarning!,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildExpandButton() {
    return InkWell(
      onTap: _toggleExpanded,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _isExpanded ? '收起' : '展开查看详情',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 4),
            RotationTransition(
              turns: Tween(begin: 0.0, end: 0.5).animate(_animation),
              child: const Icon(
                Icons.keyboard_arrow_down,
                color: Colors.white54,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

