import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class FloatingOrbsBackground extends StatefulWidget {
  final Widget child;

  const FloatingOrbsBackground({super.key, required this.child});

  @override
  State<FloatingOrbsBackground> createState() => _FloatingOrbsBackgroundState();
}

class _FloatingOrbsBackgroundState extends State<FloatingOrbsBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14), // スピードアップで躍動感をプラス
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final val = _controller.value * 2 * pi;
        
        // 複雑な8の字・浮遊軌道とサイズパルスの計算
        final orb1X = 0.25 + 0.25 * sin(val);
        final orb1Y = 0.3 + 0.2 * cos(val * 0.7);
        final orb1Size = 280.0 + 60.0 * sin(val * 2);

        final orb2X = 0.75 + 0.22 * cos(val * 0.8 + pi);
        final orb2Y = 0.7 + 0.25 * sin(val * 1.3 + pi);
        final orb2Size = 280.0 + 60.0 * cos(val * 1.5);

        // 第3のオーブ (ゴールド/アンバー) で色彩の重なりをリッチに
        final orb3X = 0.5 + 0.2 * sin(val * 1.6);
        final orb3Y = 0.45 + 0.18 * cos(val * 0.9);
        final orb3Size = 210.0 + 40.0 * sin(val * 2.2);

        return Stack(
          children: [
            // 基本背景 (深いダークブルー)
            Container(color: AppTheme.background),

            // オーブ1 (マゼンタ発光・左上浮遊)
            Positioned(
              left: MediaQuery.of(context).size.width * orb1X - (orb1Size / 2),
              top: MediaQuery.of(context).size.height * orb1Y - (orb1Size / 2),
              child: Container(
                width: orb1Size,
                height: orb1Size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.primary.withValues(alpha: 0.18),
                      AppTheme.primary.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),

            // オーブ2 (シアン発光・右下浮遊)
            Positioned(
              left: MediaQuery.of(context).size.width * orb2X - (orb2Size / 2),
              top: MediaQuery.of(context).size.height * orb2Y - (orb2Size / 2),
              child: Container(
                width: orb2Size,
                height: orb2Size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.secondary.withValues(alpha: 0.18),
                      AppTheme.secondary.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),

            // オーブ3 (アンバー発光・中央浮遊)
            Positioned(
              left: MediaQuery.of(context).size.width * orb3X - (orb3Size / 2),
              top: MediaQuery.of(context).size.height * orb3Y - (orb3Size / 2),
              child: Container(
                width: orb3Size,
                height: orb3Size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFF59E0B).withValues(alpha: 0.12),
                      const Color(0xFFF59E0B).withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),

            // 本文コンテンツ
            widget.child,
          ],
        );
      },
    );
  }
}
