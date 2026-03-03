// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'script.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ScriptAdapter extends TypeAdapter<Script> {
  @override
  final int typeId = 0;

  @override
  Script read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Script(
      id: fields[0] as String,
      title: fields[1] as String,
      content: fields[2] as String,
      category: fields[3] as String? ?? '',
      currentLevel: fields[4] as int,
      practiceCount: fields[5] as int,
      correctRate: fields[6] as double,
      bestVoiceScore: fields[7] as double,
      createdAt: fields[8] as DateTime,
      lastPracticedAt: fields[9] as DateTime,
      clozeWords: (fields[10] as List).cast<ClozeWord>(),
      // 自動マイグレーション: tags がなければ category からフォールバック
      tags: fields[11] != null
          ? (fields[11] as List).cast<String>()
          : (fields[3] != null && (fields[3] as String).isNotEmpty
              ? [fields[3] as String]
              : []),
      parenthesesMode: fields[12] as String? ?? 'stripContent',
      fullTextHiragana: fields[13] as String? ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, Script obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.content)
      ..writeByte(3)
      ..write(obj.category)
      ..writeByte(4)
      ..write(obj.currentLevel)
      ..writeByte(5)
      ..write(obj.practiceCount)
      ..writeByte(6)
      ..write(obj.correctRate)
      ..writeByte(7)
      ..write(obj.bestVoiceScore)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.lastPracticedAt)
      ..writeByte(10)
      ..write(obj.clozeWords)
      ..writeByte(11)
      ..write(obj.tags)
      ..writeByte(12)
      ..write(obj.parenthesesMode)
      ..writeByte(13)
      ..write(obj.fullTextHiragana);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScriptAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
