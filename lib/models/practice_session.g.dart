// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'practice_session.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PracticeSessionAdapter extends TypeAdapter<PracticeSession> {
  @override
  final int typeId = 2;

  @override
  PracticeSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PracticeSession(
      id: fields[0] as String,
      scriptId: fields[1] as String,
      mode: fields[2] as String,
      level: fields[3] as int,
      score: fields[4] as double,
      durationSeconds: fields[5] as int,
      recognizedText: fields[6] as String?,
      createdAt: fields[7] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, PracticeSession obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.scriptId)
      ..writeByte(2)
      ..write(obj.mode)
      ..writeByte(3)
      ..write(obj.level)
      ..writeByte(4)
      ..write(obj.score)
      ..writeByte(5)
      ..write(obj.durationSeconds)
      ..writeByte(6)
      ..write(obj.recognizedText)
      ..writeByte(7)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PracticeSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
