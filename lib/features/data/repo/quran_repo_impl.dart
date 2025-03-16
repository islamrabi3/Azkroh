// import 'dart:convert';
//
// import 'package:azkroh_app/features/core/cacheHelper.dart';
// import 'package:azkroh_app/features/data/datasource/remota_data_source/quran_remote_data.dart';
// import 'package:azkroh_app/features/data/models/quran_model.dart';
// import 'package:azkroh_app/features/domain/entity/quran_entity.dart';
// import 'package:azkroh_app/features/domain/repo/quran_base_repo.dart';
// import 'package:internet_connection_checker/internet_connection_checker.dart';
//
// class QuranRepoImplementaion extends QuranBaseRepo {
//   final QuranRemotaData quranRemotaData;
//
//   QuranRepoImplementaion({required this.quranRemotaData});
//
//   @override
//   Future<QuranEntity> getQuranDataFromApi() async {
//     try {
//       if (await InternetConnectionChecker().hasConnection) {
//         return await quranRemotaData.getRemoteQuranDataFromApi();
//       } else {
//         return QuranModel.fromJson(jsonDecode(
//             CacheHelper.sharedPreferences!.getString('quran_data')!));
//       }
//       // return await quranRemotaData.getRemoteQuranDataFromApi();
//
//       // CacheHelper.sharedPreferences!.getString('quran_data')!));
//     } on Exception catch (e) {
//        throw e.toString();
//     }
//   }
// }
