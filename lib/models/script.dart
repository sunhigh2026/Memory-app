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
  late int currentLevel; // 0-8

  @HiveField(5)
  late int practiceCount;

  @HiveField(6)
  late double correctRate;

  @HiveField(7)
  late double bestVoiceScore;

  @HiveField(8)
  late DateTime createdAt;

  @HiveField(9)
  DateTime? lastPracticedAt;

  @HiveField(10)
  late List<ClozeWord> clozeWords;

  @HiveField(11)
  late List<String> tags;

  @HiveField(12)
  late String parenthesesMode; // 'keep' / 'stripContent' / 'stripSymbols'

  @HiveField(13)
  late String fullTextHiragana; // ひらがな化済みテキスト（キャッシュ）

  @HiveField(14)
  DateTime? nextReviewAt; // 次回復習日（null = 未スケジュール）

  @HiveField(15)
  late double intervalDays; // 復習間隔（日数）

  @HiveField(16)
  late double easeFactor; // SM-2 易しさ係数

  @HiveField(17)
  late String reviewPace; // 'relaxed' / 'normal' / 'intensive' / 'daily'

  @HiveField(18)
  DateTime? targetDate; // 本番日（null = 未設定、SM-2モード）

  @HiveField(19)
  late List<DateTime> generatedSchedule; // 本番日逆算スケジュール

  @HiveField(20)
  late int scheduleIndex; // generatedSchedule 内の現在位置

  @HiveField(21)
  Map<String, int>? mistakeWords; // よく間違える単語とその回数

  @HiveField(22, defaultValue: [])
  late List<String> pinnedClozeWords; // 手動指定の重要語（穴埋め必須）

  @HiveField(23, defaultValue: 0)
  late int sortOrder; // 通し番号（ソート用）

  @HiveField(24, defaultValue: 'B')
  late String rank; // 出題ランク ('特A', 'A', 'B', 'C')

  @HiveField(25, defaultValue: '')
  late String subjectId; // 所属する科目ID

  Script({
    required this.id,
    required this.title,
    required this.content,
    this.category = '',
    this.currentLevel = 0,
    this.practiceCount = 0,
    this.correctRate = 0.0,
    this.bestVoiceScore = 0.0,
    DateTime? createdAt,
    this.lastPracticedAt,
    List<ClozeWord>? clozeWords,
    List<String>? tags,
    this.parenthesesMode = 'stripContent',
    this.fullTextHiragana = '',
    this.nextReviewAt,
    this.intervalDays = 0.0,
    this.easeFactor = 2.5,
    this.reviewPace = 'normal',
    this.targetDate,
    List<DateTime>? generatedSchedule,
    this.scheduleIndex = 0,
    Map<String, int>? mistakeWords,
    List<String>? pinnedClozeWords,
    this.sortOrder = 0,
    this.rank = 'B',
    this.subjectId = '',
  })  : createdAt = createdAt ?? DateTime.now(),
        clozeWords = clozeWords ?? [],
        tags = tags ?? [],
        generatedSchedule = generatedSchedule ?? [],
        mistakeWords = mistakeWords ?? {},
        pinnedClozeWords = pinnedClozeWords ?? [];

  double get progressPercent {
    switch (currentLevel) {
      case 1:
        return (correctRate / 100) * 25;
      case 2:
        return 25 + (correctRate / 100) * 12.5;
      case 3:
        return 37.5 + (correctRate / 100) * 12.5;
      case 4:
        return 50 + (correctRate / 100) * 12.5;
      case 5:
        return 62.5 + (bestVoiceScore / 100) * 9;
      case 6:
        return 71.5 + (bestVoiceScore / 100) * 9;
      case 7:
        return 80.5 + (bestVoiceScore / 100) * 9;
      case 8:
        return 89.5 + (bestVoiceScore / 100) * 10.5;
      default:
        return 0; // Level 0 = 未練習
    }
  }

  bool get isMastered => currentLevel >= 8 && bestVoiceScore >= 85;

  bool get isReviewDue {
    if (nextReviewAt == null) return practiceCount > 0;
    return DateTime.now().isAfter(nextReviewAt!);
  }

  Duration get reviewOverdueDuration {
    if (nextReviewAt == null || DateTime.now().isBefore(nextReviewAt!)) {
      return Duration.zero;
    }
    return DateTime.now().difference(nextReviewAt!);
  }

  bool get hasTargetDate => targetDate != null;

  int get daysUntilTarget =>
      hasTargetDate ? targetDate!.difference(DateTime.now()).inDays : -1;

  bool get isTargetDateMode =>
      hasTargetDate && generatedSchedule.isNotEmpty;
}
