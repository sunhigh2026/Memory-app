import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/text_matcher.dart';

class DiffResultWidget extends StatelessWidget {
  final List<DiffSegment> segments;

  const DiffResultWidget({super.key, required this.segments});

  @override
  Widget build(BuildContext context) {
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
          RichText(
            text: TextSpan(
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
            ],
          ),
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
