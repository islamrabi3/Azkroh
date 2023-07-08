// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'doaa_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DoaaModelAdapter extends TypeAdapter<DoaaModel> {
  @override
  final int typeId = 0;

  @override
  DoaaModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DoaaModel(
      content: fields[1] as String?,
      desc: fields[2] as String?,
      id: fields[3] as String?,
      repeatTime: fields[4] as int,
      isFavorite: fields[5] as bool?,
    );
  }

  @override
  void write(BinaryWriter writer, DoaaModel obj) {
    writer
      ..writeByte(5)
      ..writeByte(1)
      ..write(obj.content)
      ..writeByte(2)
      ..write(obj.desc)
      ..writeByte(3)
      ..write(obj.id)
      ..writeByte(4)
      ..write(obj.repeatTime)
      ..writeByte(5)
      ..write(obj.isFavorite);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DoaaModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
