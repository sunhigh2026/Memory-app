import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/text_matcher.dart';

/// コールバック型: 原文側の語と認識側の語を受け取る
typedef OnMarkCorrect = void Function(String originalWord, String recognizedWord);

class DiffResultWidget extends StatelessWidget {
  final List<DiffSegment> segments;
  final OnMarkCorrect? onMarkCorrect;
  final Set<String>? alreadyAllowed; // "original→recognized" の Set

  const DiffResultWidget({
    super.key,
    required this.segments,
    this.onMarkCorrect,
    this.alreadyAllowed,
  });

  @override
  Widget build(BuildContext context) {
    // replace セグメントを抽出
    final replaceSegments = segments
        .where((s) => s.type == DiffType.replace && s.replacement != null)
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '差分表示:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textLight,
            ),
          ),
          const SizedBox(height: 12),
          Text.rich(
            TextSpan(
              children: segments.map((segment) {
                switch (segment.type) {
                  case DiffType.match:
                    return TextSpan(
                      text: segment.text,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.8,
                        color: AppTheme.secondary,
                      ),
                    );
                  case DiffType.missing:
                    return TextSpan(
                      text: segment.text,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.8,
                        color: AppTheme.diffMissing,
                        decoration: TextDecoration.lineThrough,
                        backgroundColor: Color(0x20EF4444),
                      ),
                    );
                  case DiffType.extra:
                    return TextSpan(
                      text: segment.text,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.8,
                        color: AppTheme.diffExtra,
                        backgroundColor: Color(0x20F59E0B),
                      ),
                    );
                  case DiffType.replace:
                    return TextSpan(
                      children: [
                        TextSpan(
                          text: segment.text,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.8,
                            color: AppTheme.diffMissing,
                            decoration: TextDecoration.lineThrough,
                            backgroundColor: Color(0x20EF4444),
                          ),
                        ),
                        TextSpan(
                          text: segment.replacement,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.8,
                            color: AppTheme.diffExtra,
                            backgroundColor: Color(0x20F59E0B),
                          ),
                        ),
                      ],
                    );
                  case DiffType.allowed:
                    final reading = segment.hiraganaReading ?? '';
                    final display = reading.isNotEmpty
                        ? '$reading（${segment.text}→${segment.replacement} ✓）'
                        : '${segment.text}→${segment.replacement} ✓';
                    return TextSpan(
                      text: display,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.8,
                        color: AppTheme.diffCorrect,
                        fontWeight: FontWeight.w500,
                        backgroundColor: Color(0x1510B981),
                      ),
                    );
                }
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          // 凡例
          Row(
            children: [
              _Legend(color: AppTheme.secondary, label: '一致'),
              const SizedBox(width: 12),
              _Legend(color: AppTheme.diffMissing, label: '欠落'),
              const SizedBox(width: 12),
              _Legend(color: AppTheme.diffExtra, label: '余分'),
              const SizedBox(width: 12),
              _Legend(color: AppTheme.diffCorrect, label: '許容'),
            ],
          ),
          // 「正しいとしてマーク」ボタン一覧
          if (onMarkCorrect != null && replaceSegments.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              '同音異義語の許容登録:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            ...replaceSegments.map((seg) {
              final key = '${seg.text}→${seg.replacement}';
              final isAllowed = alreadyAllowed?.contains(key) ?? false;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: seg.replacement,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.diffExtra,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const TextSpan(
                              text: ' → ',
                              style: TextStyle(fontSize: 14, color: AppTheme.textLight),
                            ),
                            TextSpan(
                              text: seg.text,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isAllowed)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.secondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '許容済み',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.secondary,
                          ),
                        ),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: () =>
                            onMarkCorrect!(seg.text, seg.replacement!),
                        icon: const Icon(Icons.check_circle_outline, size: 16),
                        label: const Text('許容する'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.secondary,
                          side: BorderSide(
                            color: AppTheme.secondary.withValues(alpha: 0.5),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: color, width: 1),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }
}
