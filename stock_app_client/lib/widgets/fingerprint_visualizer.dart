import 'package:flutter/material.dart';
import 'dart:math' as math;

class FingerprintVisualizer extends StatefulWidget {
  final String fingerprint;
  final Color? color;
  final double size;

  const FingerprintVisualizer({
    super.key,
    required this.fingerprint,
    this.color,
    this.size = 60,
  });

  @override
  State<FingerprintVisualizer> createState() => _FingerprintVisualizerState();
}

class _FingerprintVisualizerState extends State<FingerprintVisualizer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  final List<_FingerprintLine> _lines = [];
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
    
    _generateLines();
  }
  
  @override
  void didUpdateWidget(FingerprintVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fingerprint != widget.fingerprint) {
      _generateLines();
    }
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  void _generateLines() {
    _lines.clear();
    
    // 使用指纹字符串生成随机但确定的图案
    final seed = widget.fingerprint.codeUnits.fold<int>(0, (a, b) => a + b);
    final random = math.Random(seed);
    
    // 生成6-10条线
    final lineCount = 6 + random.nextInt(5);
    
    for (int i = 0; i < lineCount; i++) {
      final startAngle = random.nextDouble() * 2 * math.pi;
      final endAngle = startAngle + (random.nextDouble() * math.pi / 2);
      
      final radius = (0.3 + random.nextDouble() * 0.3) * widget.size / 2;
      final thickness = 1.0 + random.nextDouble() * 2.0;
      
      _lines.add(_FingerprintLine(
        startAngle: startAngle,
        endAngle: endAngle,
        radius: radius,
        thickness: thickness,
      ));
    }
    
    // 添加一些圆弧
    final arcCount = 3 + random.nextInt(3);
    for (int i = 0; i < arcCount; i++) {
      final startAngle = random.nextDouble() * 2 * math.pi;
      final sweepAngle = math.pi / 2 + random.nextDouble() * math.pi;
      
      final radius = (0.5 + random.nextDouble() * 0.3) * widget.size / 2;
      final thickness = 1.0 + random.nextDouble() * 1.5;
      
      _lines.add(_FingerprintLine(
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle,
        radius: radius,
        thickness: thickness,
        isArc: true,
      ));
    }
    
    // 添加中心点
    _lines.add(_FingerprintLine(
      startAngle: 0,
      endAngle: 2 * math.pi,
      radius: 2.0 + random.nextDouble() * 3.0,
      thickness: 3.0,
      isCenter: true,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor = widget.color ?? Theme.of(context).primaryColor;
    
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _FingerprintPainter(
              lines: _lines,
              color: effectiveColor,
              scale: _animation.value,
            ),
          ),
        );
      },
    );
  }
}

class _FingerprintLine {
  final double startAngle;
  final double endAngle;
  final double radius;
  final double thickness;
  final bool isArc;
  final bool isCenter;
  
  _FingerprintLine({
    required this.startAngle,
    required this.endAngle,
    required this.radius,
    required this.thickness,
    this.isArc = false,
    this.isCenter = false,
  });
}

class _FingerprintPainter extends CustomPainter {
  final List<_FingerprintLine> lines;
  final Color color;
  final double scale;
  
  _FingerprintPainter({
    required this.lines,
    required this.color,
    required this.scale,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // 应用缩放动画
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale, scale);
    canvas.translate(-center.dx, -center.dy);
    
    for (final line in lines) {
      final paint = Paint()
        ..color = color.withOpacity(line.isCenter ? 0.7 : 0.5)
        ..style = line.isCenter ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeWidth = line.thickness
        ..strokeCap = StrokeCap.round;
      
      if (line.isCenter) {
        // 绘制中心点
        canvas.drawCircle(center, line.radius, paint);
      } else if (line.isArc) {
        // 绘制圆弧
        final rect = Rect.fromCircle(center: center, radius: line.radius);
        canvas.drawArc(rect, line.startAngle, line.endAngle - line.startAngle, false, paint);
      } else {
        // 绘制线条
        final dx1 = math.cos(line.startAngle) * line.radius;
        final dy1 = math.sin(line.startAngle) * line.radius;
        final dx2 = math.cos(line.endAngle) * line.radius;
        final dy2 = math.sin(line.endAngle) * line.radius;
        
        final start = center + Offset(dx1, dy1);
        final end = center + Offset(dx2, dy2);
        
        canvas.drawLine(start, end, paint);
      }
    }
    
    canvas.restore();
  }
  
  @override
  bool shouldRepaint(_FingerprintPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.scale != scale;
  }
} 