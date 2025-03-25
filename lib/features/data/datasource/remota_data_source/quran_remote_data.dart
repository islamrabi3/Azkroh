import 'dart:convert';

import 'package:azkroh_app/features/core/cacheHelper.dart';
import 'package:azkroh_app/features/data/models/quran_model.dart';
import 'package:http/http.dart' as http;

abstract class QuranRemoteDataBaseRepo {
  Future<QuranModel> getRemoteQuranDataFromApi();
}

class QuranRemotaData extends QuranRemoteDataBaseRepo {
  @override
  Future<QuranModel> getRemoteQuranDataFromApi() async {
    String url = 'http://api.alquran.cloud/v1/quran/quran-uthmani';
    http.Response response = await http.get(Uri.parse(url));
    Map<String, dynamic> jsonString = jsonDecode(response.body);
    CacheHelper.sharedPreferences!
        .setString('quran_data', jsonEncode(jsonString));
    return Future.value(QuranModel.fromJson(jsonString));
  }
}
