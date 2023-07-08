import 'package:azkroh_app/features/domain/entity/quran_entity.dart';

class QuranModel extends QuranEntity {
  const QuranModel({
    required super.code,
    required super.status,
    required super.data,
  });

  factory QuranModel.fromJson(Map<String, dynamic> json) => QuranModel(
        code: json['code'],
        status: json['status'],
        data: QuranDataModel.fromJson(json['data']),
      );
}

class QuranDataModel extends QuranDataEntity {
  const QuranDataModel({required super.listOfSurahs});
  factory QuranDataModel.fromJson(Map<String, dynamic> json) => QuranDataModel(
      listOfSurahs: List<SuraModel>.from(
          json['surahs'].map((e) => SuraModel.fromJson(e))));
}

class SuraModel extends SuraEntity {
  const SuraModel({
    required super.number,
    required super.name,
    required super.englishName,
    required super.englishNameTranslation,
    required super.revelationType,
    required super.listOfAyahEntity,
  });

  factory SuraModel.fromJson(Map<String, dynamic> json) => SuraModel(
        number: json['number'],
        name: json['name'],
        englishName: json['englishName'],
        englishNameTranslation: json['englishNameTranslation'],
        revelationType: json['revelationType'],
        listOfAyahEntity: List<AyahModel>.from(
            (json['ayahs'].map((e) => AyahModel.fromJson(e)))),
      );
}

class AyahModel extends AyahEntity {
  AyahModel(
      {required super.ayahNumber,
      required super.ayahText,
      required super.numberInSurah,
      required super.juz,
      required super.manzil,
      required super.page,
      required super.ruku,
      required super.hizbQuarter,
      required super.sajda,
      super.isfavorite});

  factory AyahModel.fromJson(Map<String, dynamic> json) => AyahModel(
        ayahNumber: json['number'],
        ayahText: json['text'],
        numberInSurah: json['numberInSurah'],
        juz: json['juz'],
        manzil: json['manzil'],
        page: json['page'],
        ruku: json['ruku'],
        hizbQuarter: json['hizbQuarter'],
        sajda: json['sajda'],
      );
}
