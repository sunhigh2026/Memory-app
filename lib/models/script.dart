import 'package:hive/hive.dart';
import 'cloze_word.dart';

part 'script.g.dart';

@HiveType(typeId: 0)
class Script extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String title;

  @HiveField(2)
  late String content;

  @HiveField(3)
  late String category; // 後方互換性のため残す

  @HiveField(4)
  late int currentLevel; // 1-4

  @HiveField(5)
  late int practiceCount;

  @HiveField(6)
  late double correctRate;

  @HiveField(7)
  late double bestVoiceScore;

  @HiveField(8)
  late DateTime createdAt;

  @HiveField(9)
  late DateTime lastPracticedAt;

  @HiveField(10)
  late List<ClozeWord> clozeWords;

  @HiveField(11)
  late List<String> tags;

  @HiveField(12)
  late String parenthesesMode; // 'keep' / 'stripContent' / 'stripSymbols'

  @HiveField(13)
  late String fullTextHiragana; // ひらがな化済みテキスト（キャッシュ）

  Script({
    required this.id,
    required this.title,
    required this.content,
    this.category = '',
    this.currentLevel = 1,
    this.practiceCount = 0,
    this.correctRate = 0.0,
    this.bestVoiceScore = 0.0,
    DateTime? createdAt,
    DateTime? lastPracticedAt,
    List<ClozeWord>? clozeWords,
    List<String>? tags,
    this.parenthesesMode = 'stripContent',
    this.fullTextHiragana = '',
  })  : createdAt = createdAt ?? DateTime.now(),
        lastPracticedAt = lastPracticedAt ?? DateTime.now(),
        clozeWords = clozeWords ?? [],
        tags = tags ?? [];

  double get progressPercent {
    switch (currentLevel) {
      case 1:
        return correctRate * 0.25;
      case 2:
        return 25 + correctRate * 0.25;
      case 3:
        return 50 + correctRate * 0.25;
      case 4:
        return 75 + (bestVoiceScore / 100) * 25;
      default:
        return 0;
    }
  }

  bool get isMastered => currentLevel == 4 && bestVoiceScore >= 85;
}
