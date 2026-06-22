import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

Color rankColor(String rank) {
  switch (rank) {
    case 'S':
      return const Color(0xFFD4AF37); // ゴールド
    case 'A':
      return const Color(0xFF3949AB); // インディゴ（primary）
    case 'B':
      return const Color(0xFF00897B); // ティール（secondary）
    case 'C':
    default:
      return const Color(0xFF9E9E9E); // グレー
  }
}

class RankChip extends StatelessWidget {
  final String rank;

  const RankChip({super.key, required this.rank});

  @override
  Widget build(BuildContext context) {
    final color = rankColor(rank);
    return Semantics(
      label: 'ランク: $rank',
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
            Icon(Icons.star_border, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              'ランク: $rank',
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
