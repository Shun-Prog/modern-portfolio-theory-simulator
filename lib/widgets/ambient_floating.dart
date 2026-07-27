import 'package:flutter/material.dart';

class AmbientFloating extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double dy;

  const AmbientFloating({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 3200), // ゆったりとした周期
    this.dy = 4.0, // 上下の移動幅
  });

  @override
  State<AmbientFloating> createState() => _AmbientFloatingState();
}

class _AmbientFloatingState extends State<AmbientFloating> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutSine, // 滑らかなサイン波
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0.0, -widget.dy * _animation.value),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
