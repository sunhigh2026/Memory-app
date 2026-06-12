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

  // グレースケール（Colors.grey[xxx] の置き換え用）
  static const Color grey200 = Color(0xFFEEEEEE);
  static const Color grey300 = Color(0xFFE0E0E0);
  static const Color grey400 = Color(0xFFBDBDBD);
  static const Color grey500 = Color(0xFF9E9E9E);
  static const Color grey600 = Color(0xFF757575);
  static const Color levelGold = Color(0xFFD4AF37); // scorePerfect と同値、level4 用

  // Radius トークン
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;

  // 共通カードデコレーション
  static BoxDecoration get cardDecoration => const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(radiusMd)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      );

  // ボーダーのみのコンテナ用
  static BoxDecoration get outlineDecoration => const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(radiusMd)),
        border: Border.fromBorderSide(BorderSide(color: grey300)),
      );

  // TextStyle 定数
  static const TextStyle sectionHeader = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: grey600,
  );
  static const TextStyle statNumber = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
  );

  // タグカラーパレット（8-A）
  static const tagColorPairs = [
    (background: Color(0xFFEDE9FE), text: Color(0xFF5B21B6)), // Violet
    (background: Color(0xFFDCFCE7), text: Color(0xFF14532D)), // Green
    (background: Color(0xFFFEF3C7), text: Color(0xFF78350F)), // Amber
    (background: Color(0xFFFFEDD5), text: Color(0xFF7C2D12)), // Orange
    (background: Color(0xFFE0F2FE), text: Color(0xFF0C4A6E)), // Sky
    (background: Color(0xFFFCE7F3), text: Color(0xFF831843)), // Pink
    (background: Color(0xFFF1F5F9), text: Color(0xFF334155)), // Slate
  ];

  /// タグ名から色ペアをハッシュで自動割り当て。同じ名前は常に同じ色。
  static ({Color background, Color text}) tagColor(String tagName) =>
      tagColorPairs[tagName.hashCode.abs() % tagColorPairs.length];

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
