import 'package:flutter/material.dart';

class AppTheme {
  static const Color background = Color(0xFF0F172A); // 深いネイビーグレー
  static const Color cardBackground = Color(0xFF1E293B); // カード背景
  static const Color primary = Color(0xFF06B6D4); // シアン / ネオンブルー
  static const Color secondary = Color(0xFF10B981); // エメラルドグリーン
  static const Color accent = Color(0xFF8B5CF6); // バイオレット
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primary,
      scaffoldBackgroundColor: background,
      cardColor: cardBackground,
      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: textPrimary, fontSize: 28, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        bodyLarge: TextStyle(color: textPrimary, fontSize: 16),
        bodyMedium: TextStyle(color: textSecondary, fontSize: 14),
      ),
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: cardBackground,
      ),
    );
  }

  // グラスモフィズム風のカード装飾
  static BoxDecoration glassDecoration({Color? color, double borderRadius = 16}) {
    return BoxDecoration(
      color: color ?? cardBackground.withOpacity(0.6),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: Colors.white.withOpacity(0.08)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }
}
