import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../widgets/strategy_assistant_dialog.dart';
import '../models/strategy.dart';

class AIAssistantFAB extends StatefulWidget {
  final Function(Strategy) onStrategyGenerated;

  const AIAssistantFAB({
    super.key,
    required this.onStrategyGenerated,
  });

  @override
  State<AIAssistantFAB> createState() => _AIAssistantFABState();
}

class _AIAssistantFABState extends State<AIAssistantFAB>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _animation = Tween<double>(begin: 0, end: 2 * math.pi).animate(_animationController);
    _colorAnimation = ColorTween(
      begin: const Color(0xFF2F80ED), // 现代蓝色
      end: const Color(0xFF56CCF2), // 淡蓝色
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _openAssistant() {
    showDialog(
      context: context,
      builder: (context) => StrategyAssistantDialog(
        onStrategyGenerated: widget.onStrategyGenerated,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.rotate(
          angle: _animation.value,
          child: child,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2F80ED).withOpacity(0.3), // 蓝色阴影
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: _openAssistant,
          backgroundColor: const Color(0xFF2F80ED), // 现代蓝色
          foregroundColor: Colors.white,
          elevation: 4,
          child: ShaderMask(
            shaderCallback: (rect) {
              return const LinearGradient(
                colors: [
                  Colors.white,
                  Colors.white,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(rect);
            },
            child: const Icon(Icons.auto_awesome),
          ),
        ),
      ),
    );
  }
} 