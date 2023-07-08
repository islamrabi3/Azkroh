import 'dart:convert';

import 'package:azkroh_app/features/core/cacheHelper.dart';
import 'package:azkroh_app/features/data/datasource/remota_data_source/azan_remote_data.dart';
import 'package:azkroh_app/features/data/models/azan_data_model.dart';
import 'package:azkroh_app/features/domain/repo/azan_base_repo.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import '../../domain/entity/azan_entity.dart';

class AzanRepoImp extends AzanBaseRepo {
  final AzanRemoteDataImp azanRemoteDataImp;

  AzanRepoImp(this.azanRemoteDataImp);

  @override
  Future<AzanEntity> getAzanData(double lati, double longi) async {
    try {
      if (await InternetConnectionChecker().hasConnection) {
        print(await InternetConnectionChecker().hasConnection);
        final result = await azanRemoteDataImp.getAzanDetails(lati, longi);
        return result;
      } else {
        print('data comes from LocalDatabase');
        return AzanModel.fromJson(
            jsonDecode(CacheHelper.sharedPreferences!.getString('azan_data')!));
      }
    } on Exception catch (e) {
      throw e.toString();
    }
  }
}
