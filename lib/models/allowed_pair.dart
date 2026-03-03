import 'package:hive/hive.dart';

part 'allowed_pair.g.dart';

@HiveType(typeId: 4)
class AllowedPair extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String scriptId;

  @HiveField(2)
  late String originalWord;

  @HiveField(3)
  late String recognizedWord;

  @HiveField(4)
  late String originalHira;

  @HiveField(5)
  late String recognizedHira;

  @HiveField(6)
  late DateTime createdAt;

  AllowedPair({
    required this.id,
    required this.scriptId,
    required this.originalWord,
    required this.recognizedWord,
    required this.originalHira,
    required this.recognizedHira,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}
