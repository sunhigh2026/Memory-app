import 'dart:math';
import '../../../core/utils/text_normalizer.dart';

/// リアルタイムマッチング結果
class RealtimeMatchState {
  /// 正規化テキストでの一致文字数
  final int matchedLength;

  /// 正規化テキストの原文全体長
  final int totalOriginalLength;

  /// 現在ミスマッチがあるか
  final bool hasMismatch;

  /// 新しいミスマッチが検出されたか（バズ用）
  final bool newMismatchDetected;

  /// 生テキスト上での一致部分の末尾位置
  final int rawMatchedUpTo;

  RealtimeMatchState({
    required this.matchedLength,
    required this.totalOriginalLength,
    required this.hasMismatch,
    required this.newMismatchDetected,
    required this.rawMatchedUpTo,
  });

  double get progress =>
      totalOriginalLength == 0 ? 0 : matchedLength / totalOriginalLength;
}

/// リアルタイム音声認識フィードバック用の軽量マッチャー
///
/// TextNormalizer.normalize()（同期・漢字ベース）でプレフィックス比較。
/// ひらがな変換は使わない（コスト高）。最終スコアは matchAsync() で別途計算。
class RealtimeMatcher {
  final String _normalizedOriginal;
  final ParenthesesMode _parentheses;
  int _lastBuzzPosition = -1;
  DateTime _lastBuzzTime = DateTime(2000);
  static const Duration _buzzCooldown = Duration(seconds: 1);

  RealtimeMatcher(
    String originalText, {
    ParenthesesMode parentheses = ParenthesesMode.keep,
  })  : _normalizedOriginal = TextNormalizer.normalize(
          originalText,
          parentheses: parentheses,
        ),
        _parentheses = parentheses;

  /// 部分認識テキストを原文とプレフィックス比較
  RealtimeMatchState processPartial(String partialText) {
    final (normPartial, posMap) = _normalizeWithMap(partialText);

    // プレフィックス一致長を算出
    int matchLen = 0;
    final minLen = min(normPartial.length, _normalizedOriginal.length);
    for (int i = 0; i < minLen; i++) {
      if (normPartial[i] == _normalizedOriginal[i]) {
        matchLen++;
      } else {
        break;
      }
    }

    // 認識テキストが一致長を超えている → ミスマッチ
    final hasMismatch = normPartial.length > matchLen;

    // 生テキスト上の切断位置
    int rawCutoff;
    if (matchLen >= normPartial.length) {
      rawCutoff = partialText.length;
    } else if (matchLen < posMap.length) {
      rawCutoff = posMap[matchLen];
    } else {
      rawCutoff = partialText.length;
    }

    // バズ判定（スロットリング: 同じ位置での再バズ防止 + 1秒クールダウン）
    bool newMismatch = false;
    if (hasMismatch) {
      final now = DateTime.now();
      if (matchLen != _lastBuzzPosition &&
          now.difference(_lastBuzzTime) >= _buzzCooldown) {
        newMismatch = true;
        _lastBuzzPosition = matchLen;
        _lastBuzzTime = now;
      }
    }

    return RealtimeMatchState(
      matchedLength: matchLen,
      totalOriginalLength: _normalizedOriginal.length,
      hasMismatch: hasMismatch,
      newMismatchDetected: newMismatch,
      rawMatchedUpTo: rawCutoff,
    );
  }

  /// テキストを正規化しつつ、正規化後の各文字の元テキスト位置を記録
  (String, List<int>) _normalizeWithMap(String text) {
    final processed =
        TextNormalizer.handleParentheses(text, _parentheses);

    final buffer = StringBuffer();
    final posMap = <int>[];

    for (int i = 0; i < processed.length; i++) {
      final char = processed[i];
      if (RegExp(r'[。、！？!?,.\s\n\r　・①-⑳㉑-㊿\d０-９\-‐―—]').hasMatch(char)) continue;

      final rune = char.runes.first;
      int normalizedRune = rune;

      // 全角英数→半角
      if (rune >= 0xFF10 && rune <= 0xFF19) {
        normalizedRune = rune - 0xFEE0;
      } else if (rune >= 0xFF21 && rune <= 0xFF3A) {
        normalizedRune = rune - 0xFEE0;
      } else if (rune >= 0xFF41 && rune <= 0xFF5A) {
        normalizedRune = rune - 0xFEE0;
      }

      // カタカナ→ひらがな
      if (normalizedRune >= 0x30A1 && normalizedRune <= 0x30F6) {
        normalizedRune = normalizedRune - 0x60;
      }

      posMap.add(i);
      buffer.writeCharCode(normalizedRune);
    }

    return (buffer.toString(), posMap);
  }

  void reset() {
    _lastBuzzPosition = -1;
    _lastBuzzTime = DateTime(2000);
  }
}
