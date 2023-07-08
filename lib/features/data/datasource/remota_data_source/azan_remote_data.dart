import 'dart:convert';

import 'package:azkroh_app/features/core/cacheHelper.dart';

import '../../models/azan_data_model.dart';
import 'package:http/http.dart' as http;

Map<String, dynamic>? jsonString;

abstract class AzanRemoteDataBaseRepo {
  Future<AzanModel> getAzanDetails(double lati, double longi);
}

class AzanRemoteDataImp extends AzanRemoteDataBaseRepo {
  @override
  Future<AzanModel> getAzanDetails(double lati, double longi) async {
    var date = DateTime.now().toIso8601String();
    var method = 5;
    String url =
        'http://api.aladhan.com/v1/timings/$date?latitude=$lati&longitude=$longi&method=$method';
    var response = await http.get(Uri.parse(url));
    Map<String, dynamic> jsonString = jsonDecode(response.body);
    CacheHelper.sharedPreferences!
        .setString('azan_data', jsonEncode(jsonString));

    return Future.value(AzanModel.fromJson(jsonString));
  }
}
