import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
part 'quran_entity.g.dart';

@HiveType(typeId: 5)
class QuranEntity extends Equatable {
  @HiveField(1)
  final dynamic code;
  @HiveField(2)
  final String status;
  @HiveField(3)
  final QuranDataEntity data;

  const QuranEntity({
    required this.code,
    required this.status,
    required this.data,
  });

  @override
  List<Object?> get props => [code, status, data];
}

@HiveType(typeId: 6)
class QuranDataEntity extends Equatable {
  @HiveField(1)
  final List<SuraEntity> listOfSurahs;

  const QuranDataEntity({required this.listOfSurahs});

  @override
  List<Object?> get props => [listOfSurahs];
}

@HiveType(typeId: 7)
class SuraEntity extends Equatable {
  @HiveField(1)
  final dynamic number;
  @HiveField(2)
  final String name;
  @HiveField(3)
  final String englishName;
  @HiveField(4)
  final String englishNameTranslation;
  @HiveField(5)
  final String revelationType;
  @HiveField(6)
  final List<AyahEntity> listOfAyahEntity;

  const SuraEntity({
    required this.number,
    required this.name,
    required this.englishName,
    required this.englishNameTranslation,
    required this.revelationType,
    required this.listOfAyahEntity,
  });

  @override
  List<Object?> get props => [
        number,
        name,
        englishName,
        englishNameTranslation,
        revelationType,
        listOfAyahEntity
      ];
}

@HiveType(typeId: 8)
class AyahEntity extends Equatable {
  @HiveField(1)
  final dynamic ayahNumber;
  @HiveField(2)
  final String ayahText;
  @HiveField(3)
  final dynamic numberInSurah;
  @HiveField(4)
  final dynamic juz;
  @HiveField(5)
  final dynamic manzil;
  @HiveField(6)
  final dynamic page;
  @HiveField(7)
  final dynamic ruku;
  @HiveField(8)
  final dynamic hizbQuarter;
  @HiveField(9)
  final dynamic sajda;
  bool? isfavorite = false;

  AyahEntity(
      {required this.ayahNumber,
      required this.ayahText,
      required this.numberInSurah,
      required this.juz,
      required this.manzil,
      required this.page,
      required this.ruku,
      required this.hizbQuarter,
      required this.sajda,
      this.isfavorite});

  @override
  List<Object?> get props => [
        ayahNumber,
        ayahText,
        numberInSurah,
        juz,
        manzil,
        page,
        ruku,
        hizbQuarter,
        sajda
      ];
}
