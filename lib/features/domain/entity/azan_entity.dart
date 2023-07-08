import 'package:equatable/equatable.dart';

class AzanEntity extends Equatable {
  final dynamic code;
  final String status;
  final Data data;

  const AzanEntity({
    required this.code,
    required this.status,
    required this.data,
  });

  @override
  List<Object?> get props => [code, status, data];
}

class Data extends Equatable {
  final Timings timings;

  // final MetaEntity meta;

  const Data({
    required this.timings,
    // required this.meta,
  });

  @override
  List<Object?> get props => [timings];
}

class Timings extends Equatable {
  final String fajr;
  final String sunrise;
  final String dhuhr;
  final String asr;
  final String sunset;
  final String maghrib;
  final String isha;
  final String imsak;
  final String midnight;
  final String firstthird;
  final String lastthird;

  const Timings({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.sunset,
    required this.maghrib,
    required this.isha,
    required this.imsak,
    required this.midnight,
    required this.firstthird,
    required this.lastthird,
  });

  @override
  List<Object?> get props => [
        fajr,
        sunrise,
        dhuhr,
        asr,
        sunrise,
        maghrib,
        isha,
        imsak,
        midnight,
        firstthird,
        lastthird
      ];
}
