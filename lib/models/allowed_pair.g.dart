// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'allowed_pair.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AllowedPairAdapter extends TypeAdapter<AllowedPair> {
  @override
  final int typeId = 4;

  @override
  AllowedPair read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AllowedPair(
      id: fields[0] as String,
      scriptId: fields[1] as String,
      originalWord: fields[2] as String,
      recognizedWord: fields[3] as String,
      originalHira: fields[4] as String,
      recognizedHira: fields[5] as String,
      createdAt: fields[6] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, AllowedPair obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.scriptId)
      ..writeByte(2)
      ..write(obj.originalWord)
      ..writeByte(3)
      ..write(obj.recognizedWord)
      ..writeByte(4)
      ..write(obj.originalHira)
      ..writeByte(5)
      ..write(obj.recognizedHira)
      ..writeByte(6)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AllowedPairAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
