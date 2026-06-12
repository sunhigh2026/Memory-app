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
      lastPracticedAt: fields[9] as DateTime?,
      clozeWords: (fields[10] as List).cast<ClozeWord>(),
      // 自動マイグレーション: tags がなければ category からフォールバック
      tags: fields[11] != null
          ? (fields[11] as List).cast<String>()
          : (fields[3] != null && (fields[3] as String).isNotEmpty
              ? [fields[3] as String]
              : []),
      parenthesesMode: fields[12] as String? ?? 'stripContent',
      fullTextHiragana: fields[13] as String? ?? '',
      nextReviewAt: fields[14] as DateTime?,
      intervalDays: (fields[15] as double?) ?? 0.0,
      easeFactor: (fields[16] as double?) ?? 2.5,
      reviewPace: fields[17] as String? ?? 'normal',
      targetDate: fields[18] as DateTime?,
      generatedSchedule: fields[19] != null
          ? (fields[19] as List).cast<DateTime>()
          : [],
      scheduleIndex: (fields[20] as int?) ?? 0,
      mistakeWords: fields[21] != null
          ? (fields[21] as Map).cast<String, int>()
          : {},
    );
  }

  @override
  void write(BinaryWriter writer, Script obj) {
    writer
      ..writeByte(22)
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
      ..write(obj.fullTextHiragana)
      ..writeByte(14)
      ..write(obj.nextReviewAt)
      ..writeByte(15)
      ..write(obj.intervalDays)
      ..writeByte(16)
      ..write(obj.easeFactor)
      ..writeByte(17)
      ..write(obj.reviewPace)
      ..writeByte(18)
      ..write(obj.targetDate)
      ..writeByte(19)
      ..write(obj.generatedSchedule)
      ..writeByte(20)
      ..write(obj.scheduleIndex)
      ..writeByte(21)
      ..write(obj.mistakeWords);
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
