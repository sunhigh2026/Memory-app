// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tts_dictionary_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TtsDictionaryEntryAdapter extends TypeAdapter<TtsDictionaryEntry> {
  @override
  final int typeId = 3;

  @override
  TtsDictionaryEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TtsDictionaryEntry(
      original: fields[0] as String,
      reading: fields[1] as String,
    );
  }

  @override
  void write(BinaryWriter writer, TtsDictionaryEntry obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.original)
      ..writeByte(1)
      ..write(obj.reading);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TtsDictionaryEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
