import 'package:hive/hive.dart';

part 'practice_session.g.dart';

@HiveType(typeId: 2)
class PracticeSession extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String scriptId;

  @HiveField(2)
  late String mode; // cloze / voice

  @HiveField(3)
  late int level;

  @HiveField(4)
  late double score;

  @HiveField(5)
  late int durationSeconds;

  @HiveField(6)
  String? recognizedText;

  @HiveField(7)
  late DateTime createdAt;

  PracticeSession({
    required this.id,
    required this.scriptId,
    required this.mode,
    required this.level,
    required this.score,
    this.durationSeconds = 0,
    this.recognizedText,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}
