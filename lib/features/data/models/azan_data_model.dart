import 'package:azkroh_app/features/domain/entity/azan_entity.dart';

class AzanModel extends AzanEntity {
  const AzanModel(
      {required super.code, required super.status, required super.data});

  factory AzanModel.fromJson(Map<String, dynamic> json) => AzanModel(
        code: json['code'],
        status: json['status'],
        data: DataModel.fromJson(json['data']),
      );
}

class DataModel extends Data {
  const DataModel({required super.timings});

  factory DataModel.fromJson(Map<String, dynamic> json) => DataModel(
        timings: TimingModel.fromJson(json['timings']),
      );
}

class TimingModel extends Timings {
  const TimingModel(
      {required super.fajr,
      required super.sunrise,
      required super.dhuhr,
      required super.asr,
      required super.sunset,
      required super.maghrib,
      required super.isha,
      required super.imsak,
      required super.midnight,
      required super.firstthird,
      required super.lastthird});

  factory TimingModel.fromJson(Map<String, dynamic> json) => TimingModel(
      fajr: json['Fajr'],
      sunrise: json['Sunrise'],
      dhuhr: json['Dhuhr'],
      asr: json['Asr'],
      sunset: json['Sunset'],
      maghrib: json['Maghrib'],
      isha: json['Isha'],
      imsak: json['Imsak'],
      midnight: json['Midnight'],
      firstthird: json['Firstthird'],
      lastthird: json['Lastthird']);
}

// class MetaModel extends MetaEntity {
//   const MetaModel(
//       {required super.latitude,
//       required super.longitude,
//       required super.timeZone,
//       required super.method,
//       required super.loccationEntity,
//       required super.latitudeAdjustmentMethod,
//       required super.midnightMode,
//       required super.school,
//       required super.offsets});
//
//   factory MetaModel.fromJson(Map<String, dynamic> json) => MetaModel(
//       latitude: json['latitude'],
//       longitude: json['longitude'],
//       timeZone: json['timezone'],
//       method: MethodModel.fromJson(json['method']),
//       loccationEntity:json['location'] ,
//       latitudeAdjustmentMethod: json['latitudeAdjustmentMethod'],
//       midnightMode: json['midnightMode'],
//       school: json['school'],
//       offsets: OffsetModel.fromJson(json['offset']));
// }
//
// class MethodModel extends Method {
//   const MethodModel(
//       {required super.id, required super.name, required super.params});
//
//   factory MethodModel.fromJson(Map<String, dynamic> json) =>
//       MethodModel(id: json['id'], name: json['name'], params: ParamsModel.fromJson(json['params']));
// }
//
// class ParamsModel extends Params {
//   const ParamsModel({required super.fajr, required super.isha});
//
//   factory ParamsModel.fromJson(Map<String, dynamic> json) =>
//       ParamsModel(fajr: json['Fajr'], isha: json['Isha']);
// }
//
// class LocationModel extends LoccationEntity {
//   const LocationModel({required super.lati, required super.longi});
//
//   factory LocationModel.fromJson(Map<String, dynamic> json) =>
//       LocationModel(lati: json['latitude'], longi: json['longitude']);
// }
//
// class OffsetModel extends Offsets {
//   const OffsetModel(
//       {required super.imsak,
//       required super.fajr,
//       required super.sunrise,
//       required super.dhuhr,
//       required super.asr,
//       required super.maghrib,
//       required super.sunset,
//       required super.isha,
//       required super.midnight});
//
//   factory OffsetModel.fromJson(Map<String, dynamic> json) => OffsetModel(
//       imsak: json['Imsak'],
//       fajr: json['Fajr'],
//       sunrise: json['Sunrise'],
//       dhuhr: json['Dhuhr'],
//       asr: json['Asr'],
//       maghrib: json['Maghrib'],
//       sunset: json['Sunset'],
//       isha: json['Isha'],
//       midnight: json['Midnight']);
// }
