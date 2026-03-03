import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // 落ち着いたトーンのインディゴブルー
  static const Color primary = Color(0xFF3949AB); // Indigo 600
  static const Color secondary = Color(0xFF00897B); // Teal 600
  static const Color accent = Color(0xFFF59E0B);
  static const Color error = Color(0xFFE53935);
  static const Color background = Color(0xFFF4F6F8);
  static const Color textDark = Color(0xFF263238); // Blue Grey 900
  static const Color textLight = Color(0xFF78909C); // Blue Grey 400
  static const Color cardBackground = Colors.white;

  // スコア判定色
  static const Color scorePerfect = Color(0xFFD4AF37); // 金色
  static const Color scoreGreat = Color(0xFF10B981); // 緑
  static const Color scoreGood = Color(0xFFF59E0B); // 黄色
  static const Color scorePoor = Color(0xFFEF4444); // 赤

  // Diff表示色
  static const Color diffMatch = Color(0xFF6B7280); // グレー
  static const Color diffCorrect = Color(0xFF10B981); // 緑
  static const Color diffMissing = Color(0xFFEF4444); // 赤
  static const Color diffExtra = Color(0xFFF59E0B); // オレンジ

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: secondary,
        error: error,
        surface: background,
      ),
      scaffoldBackgroundColor: background,
      textTheme: GoogleFonts.notoSansJpTextTheme().copyWith(
        headlineLarge: GoogleFonts.notoSansJp(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textDark,
        ),
        headlineMedium: GoogleFonts.notoSansJp(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textDark,
        ),
        headlineSmall: GoogleFonts.notoSansJp(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: textDark,
        ),
        bodyLarge: GoogleFonts.notoSansJp(fontSize: 18, color: textDark),
        bodyMedium: GoogleFonts.notoSansJp(fontSize: 16, color: textDark),
        bodySmall: GoogleFonts.notoSansJp(fontSize: 14, color: textLight),
        labelSmall: GoogleFonts.notoSansJp(fontSize: 12, color: textLight),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: textDark,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.notoSansJp(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: textDark,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.notoSansJp(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: const BorderSide(color: primary),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  static Color scoreColor(double score) {
    if (score >= 95) return scorePerfect;
    if (score >= 85) return scoreGreat;
    if (score >= 70) return scoreGood;
    return scorePoor;
  }

  static String scoreLabel(double score) {
    if (score >= 95) return '完璧！';
    if (score >= 85) return 'ほぼ完璧！';
    if (score >= 70) return 'もう少し！';
    return '練習が必要';
  }
}
