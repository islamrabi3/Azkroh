import 'dart:convert';

import 'package:azkroh_app/features/core/cacheHelper.dart';
import 'package:azkroh_app/features/data/datasource/remota_data_source/azan_remote_data.dart';
import 'package:azkroh_app/features/data/models/azan_data_model.dart';
import 'package:azkroh_app/features/domain/repo/azan_base_repo.dart';
import 'package:flutter/foundation.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import '../../domain/entity/azan_entity.dart';

class AzanRepoImp extends AzanBaseRepo {
  final AzanRemoteDataImp azanRemoteDataImp;

  AzanRepoImp(this.azanRemoteDataImp);

  @override
  Future<AzanEntity> getAzanData(double lati, double longi) async {
    try {
      // Check internet connection with timeout
      bool hasConnection = false;
      try {
        hasConnection = await InternetConnectionChecker()
            .hasConnection
            .timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('⚠️ Internet check timeout or error: $e');
        // If we can't check, try to fetch anyway (might be network issue with checker)
        hasConnection = true;
      }

      if (hasConnection) {
        debugPrint('🌐 Internet connection available, fetching from API');
        try {
          final result = await azanRemoteDataImp.getAzanDetails(lati, longi);
          return result;
        } catch (e) {
          debugPrint('❌ API fetch failed: $e');
          // Fall back to cache if API fails
          return _loadFromCache();
        }
      } else {
        debugPrint('📦 No internet connection, loading from cache');
        return _loadFromCache();
      }
    } catch (e) {
      debugPrint('❌ Error in getAzanData: $e');
      // Try to load from cache as last resort
      return _loadFromCache();
    }
  }

  AzanEntity _loadFromCache() {
    final cachedData = CacheHelper.sharedPreferences?.getString('azan_data');
    if (cachedData != null && cachedData.isNotEmpty) {
      debugPrint('✅ Loading prayer times from cache');
      return AzanModel.fromJson(jsonDecode(cachedData));
    }
    throw Exception('No cached prayer times available');
  }
}
