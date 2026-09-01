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
      category: fields[3] as String,
      currentLevel: fields[4] as int,
      practiceCount: fields[5] as int,
      correctRate: fields[6] as double,
      bestVoiceScore: fields[7] as double,
      createdAt: fields[8] as DateTime?,
      lastPracticedAt: fields[9] as DateTime?,
      clozeWords: (fields[10] as List?)?.cast<ClozeWord>(),
      tags: (fields[11] as List?)?.cast<String>(),
      parenthesesMode: fields[12] as String,
      fullTextHiragana: fields[13] as String,
      nextReviewAt: fields[14] as DateTime?,
      intervalDays: fields[15] as double,
      easeFactor: fields[16] as double,
      reviewPace: fields[17] as String,
      targetDate: fields[18] as DateTime?,
      generatedSchedule: (fields[19] as List?)?.cast<DateTime>(),
      scheduleIndex: fields[20] as int,
      mistakeWords: (fields[21] as Map?)?.cast<String, int>(),
      pinnedClozeWords:
          fields[22] == null ? [] : (fields[22] as List?)?.cast<String>(),
      sortOrder: fields[23] == null ? 0 : fields[23] as int,
      rank: fields[24] == null ? 'B' : fields[24] as String,
      subjectId: fields[25] == null ? '' : fields[25] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Script obj) {
    writer
      ..writeByte(26)
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
      ..write(obj.mistakeWords)
      ..writeByte(22)
      ..write(obj.pinnedClozeWords)
      ..writeByte(23)
      ..write(obj.sortOrder)
      ..writeByte(24)
      ..write(obj.rank)
      ..writeByte(25)
      ..write(obj.subjectId);
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
