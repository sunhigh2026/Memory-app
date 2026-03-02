import 'package:hive/hive.dart';

part 'tts_dictionary_entry.g.dart';

/// TTS読み上げ辞書エントリ
/// 例: original = "行った", reading = "おこなった"
@HiveType(typeId: 3)
class TtsDictionaryEntry extends HiveObject {
  @HiveField(0)
  late String original;

  @HiveField(1)
  late String reading;

  TtsDictionaryEntry({required this.original, required this.reading});
}
