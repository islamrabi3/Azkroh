import 'dart:convert';

import 'package:azkroh_app/features/core/cacheHelper.dart';
import 'package:azkroh_app/features/core/services/global_location_service.dart';

import '../../models/azan_data_model.dart';
import 'package:http/http.dart' as http;

Map<String, dynamic>? jsonString;

abstract class AzanRemoteDataBaseRepo {
  Future<AzanModel> getAzanDetails(double lati, double longi);
}

class AzanRemoteDataImp extends AzanRemoteDataBaseRepo {
  final GlobalLocationService _locationService = GlobalLocationService();

  @override
  Future<AzanModel> getAzanDetails(double lati, double longi) async {
    // Format date as DD-MM-YYYY (required by Aladhan API)
    var now = DateTime.now();
    var date =
        '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';

    // Get the appropriate calculation method based on location
    var method = _locationService.getCalculationMethod();

    String url =
        'https://api.aladhan.com/v1/timings/$date?latitude=$lati&longitude=$longi&method=$method';

    try {
      print('📍 Fetching prayer times from: $url');

      var response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('⏰ Request timeout');
          throw Exception('Connection timeout');
        },
      );

      print('📍 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        Map<String, dynamic> jsonString = jsonDecode(response.body);
        CacheHelper.sharedPreferences!
            .setString('azan_data', jsonEncode(jsonString));

        // Also cache the method used
        CacheHelper.sharedPreferences!.setInt('prayer_method', method);

        print('✅ Prayer times fetched successfully');
        return Future.value(AzanModel.fromJson(jsonString));
      } else {
        print('❌ API error: ${response.statusCode}');
        // Try to load from cache if API fails
        return _loadFromCache();
      }
    } catch (e) {
      print('❌ Error fetching prayer times: $e');
      return _loadFromCache();
    }
  }

  /// Load prayer times from cache
  AzanModel _loadFromCache() {
    final cachedData = CacheHelper.sharedPreferences!.getString('azan_data');
    if (cachedData != null) {
      return AzanModel.fromJson(jsonDecode(cachedData));
    }
    throw Exception('No cached prayer times available');
  }
}
