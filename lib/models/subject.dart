import 'package:hive/hive.dart';

part 'subject.g.dart';

@HiveType(typeId: 5)
class Subject extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String name;

  @HiveField(2)
  late DateTime createdAt;

  @HiveField(3, defaultValue: 0)
  late int sortOrder;

  Subject({
    required this.id,
    required this.name,
    DateTime? createdAt,
    this.sortOrder = 0,
  }) : createdAt = createdAt ?? DateTime.now();
}
