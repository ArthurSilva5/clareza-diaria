// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LocalEntryAdapter extends TypeAdapter<LocalEntry> {
  @override
  final int typeId = 0;

  @override
  LocalEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LocalEntry(
      id: fields[0] as String?,
      tipo: fields[1] as String,
      texto: fields[2] as String,
      tags: (fields[3] as List).cast<String>(),
      timestamp: fields[4] as DateTime,
      synced: fields[5] as bool,
      createdAt: fields[6] as DateTime,
      userId: fields[7] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, LocalEntry obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.tipo)
      ..writeByte(2)
      ..write(obj.texto)
      ..writeByte(3)
      ..write(obj.tags)
      ..writeByte(4)
      ..write(obj.timestamp)
      ..writeByte(5)
      ..write(obj.synced)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.userId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

