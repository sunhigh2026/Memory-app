import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// レベルに応じたテーマカラーを取得します
Color levelColor(int level) {
  switch (level) {
    case 0:
      return const Color(0xFF9E9E9E); // グレー
    case 1:
      return const Color(0xFFF59E0B); // アンバー
    case 2:
      return const Color(0xFF9C27B0); // パープル
    case 3:
      return const Color(0xFF3949AB); // インディゴ
    case 4:
      return const Color(0xFF00897B); // ティール
    case 5:
    case 6:
    case 7:
    case 8:
    default:
      return const Color(0xFFD4AF37); // ゴールド
  }
}

/// レベルを表示するための共通チップコンポーネントです
class LevelChip extends StatelessWidget {
  final int level;

  const LevelChip({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    final color = levelColor(level);
    return Semantics(
      label: 'レベル $level',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              'Level $level',
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
