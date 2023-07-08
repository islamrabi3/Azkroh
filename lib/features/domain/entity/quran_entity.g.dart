// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quran_entity.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class QuranEntityAdapter extends TypeAdapter<QuranEntity> {
  @override
  final int typeId = 5;

  @override
  QuranEntity read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return QuranEntity(
      code: fields[1] as dynamic,
      status: fields[2] as String,
      data: fields[3] as QuranDataEntity,
    );
  }

  @override
  void write(BinaryWriter writer, QuranEntity obj) {
    writer
      ..writeByte(3)
      ..writeByte(1)
      ..write(obj.code)
      ..writeByte(2)
      ..write(obj.status)
      ..writeByte(3)
      ..write(obj.data);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuranEntityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class QuranDataEntityAdapter extends TypeAdapter<QuranDataEntity> {
  @override
  final int typeId = 6;

  @override
  QuranDataEntity read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return QuranDataEntity(
      listOfSurahs: (fields[1] as List).cast<SuraEntity>(),
    );
  }

  @override
  void write(BinaryWriter writer, QuranDataEntity obj) {
    writer
      ..writeByte(1)
      ..writeByte(1)
      ..write(obj.listOfSurahs);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuranDataEntityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SuraEntityAdapter extends TypeAdapter<SuraEntity> {
  @override
  final int typeId = 7;

  @override
  SuraEntity read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SuraEntity(
      number: fields[1] as dynamic,
      name: fields[2] as String,
      englishName: fields[3] as String,
      englishNameTranslation: fields[4] as String,
      revelationType: fields[5] as String,
      listOfAyahEntity: (fields[6] as List).cast<AyahEntity>(),
    );
  }

  @override
  void write(BinaryWriter writer, SuraEntity obj) {
    writer
      ..writeByte(6)
      ..writeByte(1)
      ..write(obj.number)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.englishName)
      ..writeByte(4)
      ..write(obj.englishNameTranslation)
      ..writeByte(5)
      ..write(obj.revelationType)
      ..writeByte(6)
      ..write(obj.listOfAyahEntity);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SuraEntityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AyahEntityAdapter extends TypeAdapter<AyahEntity> {
  @override
  final int typeId = 8;

  @override
  AyahEntity read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AyahEntity(
      ayahNumber: fields[1] as dynamic,
      ayahText: fields[2] as String,
      numberInSurah: fields[3] as dynamic,
      juz: fields[4] as dynamic,
      manzil: fields[5] as dynamic,
      page: fields[6] as dynamic,
      ruku: fields[7] as dynamic,
      hizbQuarter: fields[8] as dynamic,
      sajda: fields[9] as dynamic,
    );
  }

  @override
  void write(BinaryWriter writer, AyahEntity obj) {
    writer
      ..writeByte(9)
      ..writeByte(1)
      ..write(obj.ayahNumber)
      ..writeByte(2)
      ..write(obj.ayahText)
      ..writeByte(3)
      ..write(obj.numberInSurah)
      ..writeByte(4)
      ..write(obj.juz)
      ..writeByte(5)
      ..write(obj.manzil)
      ..writeByte(6)
      ..write(obj.page)
      ..writeByte(7)
      ..write(obj.ruku)
      ..writeByte(8)
      ..write(obj.hizbQuarter)
      ..writeByte(9)
      ..write(obj.sajda);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AyahEntityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
