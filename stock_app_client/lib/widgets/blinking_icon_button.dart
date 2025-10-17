import 'package:flutter/material.dart';

class BlinkingIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;
  final double size;
  final Duration blinkDuration;

  const BlinkingIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
    this.size = 24.0,
    this.blinkDuration = const Duration(milliseconds: 1000),
  });

  @override
  State<BlinkingIconButton> createState() => _BlinkingIconButtonState();
}

class _BlinkingIconButtonState extends State<BlinkingIconButton> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: widget.blinkDuration,
    );
    
    // 创建一个循环的不透明度动画，从1.0到0.3再回到1.0
    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.3),
        weight: 1.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.3, end: 1.0),
        weight: 1.0,
      ),
    ]).animate(_animationController);
    
    // 循环播放动画
    _animationController.repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacityAnimation,
      builder: (context, child) {
        return IconButton(
          icon: Icon(
            widget.icon,
            color: widget.color?.withOpacity(_opacityAnimation.value) ?? 
                   Theme.of(context).colorScheme.primary.withOpacity(_opacityAnimation.value),
            size: widget.size,
          ),
          tooltip: widget.tooltip,
          onPressed: widget.onPressed,
        );
      },
    );
  }
} 