import 'dart:async';
import 'dart:convert';

import 'package:azkroh_app/features/core/cacheHelper.dart';
import 'package:azkroh_app/features/core/services/global_location_service.dart';
import 'package:flutter/foundation.dart';

import '../../models/azan_data_model.dart';
import 'package:http/http.dart' as http;

Map<String, dynamic>? jsonString;

abstract class AzanRemoteDataBaseRepo {
  Future<AzanModel> getAzanDetails(double lati, double longi);
}

class AzanRemoteDataImp extends AzanRemoteDataBaseRepo {
  final GlobalLocationService _locationService = GlobalLocationService();

  // Shared HTTP client for connection reuse (improves performance on Android)
  static http.Client? _sharedClient;

  http.Client get _client {
    _sharedClient ??= http.Client();
    return _sharedClient!;
  }

  @override
  Future<AzanModel> getAzanDetails(double lati, double longi) async {
    var now = DateTime.now();

    // Use ISO format (YYYY-MM-DD) - works correctly
    var dateISO =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    var method = _locationService.getCalculationMethod();

    String url =
        'https://api.aladhan.com/v1/timings/$dateISO?latitude=$lati&longitude=$longi&method=$method';

    // Fast-fail strategy: Short timeout for first attempt, longer for retries
    const firstAttemptTimeout =
        Duration(seconds: 8); // Quick timeout to detect slow connection
    const retryTimeout = Duration(seconds: 15); // Longer timeout for retries
    const maxRetries = 2; // Reduced to 2 total attempts

    // First attempt with short timeout
    try {
      debugPrint('📍 Fetching prayer times from: $url (Fast attempt)');

      var response = await _client.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'User-Agent': 'AzkrohApp/1.0',
          'Connection': 'keep-alive',
        },
      ).timeout(
        firstAttemptTimeout,
        onTimeout: () {
          debugPrint(
              '⏰ Fast attempt timeout (${firstAttemptTimeout.inSeconds}s) - connection establishing, retrying immediately...');
          throw TimeoutException('Fast attempt timeout');
        },
      );

      debugPrint('📍 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return _handleSuccessResponse(response, method);
      } else {
        debugPrint('❌ API error: ${response.statusCode}');
        return _loadFromCache();
      }
    } on TimeoutException catch (e) {
      // Fast attempt timed out - connection is being established
      // Immediately retry with longer timeout (no delay)
      debugPrint('🔄 Retrying immediately with longer timeout...');
    } catch (e) {
      debugPrint('❌ Error on fast attempt: $e');
      // Continue to retry
    }

    // Retry with longer timeout (connection should be established now)
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint(
            '📍 Fetching prayer times from: $url (Retry attempt $attempt/$maxRetries)');

        var response = await _client.get(
          Uri.parse(url),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'User-Agent': 'AzkrohApp/1.0',
            'Connection': 'keep-alive',
          },
        ).timeout(
          retryTimeout,
          onTimeout: () {
            debugPrint('⏰ Retry timeout on attempt $attempt');
            throw TimeoutException('Retry timeout');
          },
        );

        debugPrint('📍 Response status: ${response.statusCode}');

        if (response.statusCode == 200) {
          return _handleSuccessResponse(response, method);
        } else {
          debugPrint('❌ API error: ${response.statusCode}');
          if (attempt == maxRetries) {
            return _loadFromCache();
          }
          await Future.delayed(const Duration(milliseconds: 500));
          continue;
        }
      } on TimeoutException catch (e) {
        debugPrint('⏰ Retry timeout error (attempt $attempt): $e');

        if (attempt == maxRetries) {
          return _loadFromCache();
        }

        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        debugPrint('❌ Error on retry attempt $attempt: $e');

        if (attempt == maxRetries) {
          return _loadFromCache();
        }

        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    // Fallback to cache
    return _loadFromCache();
  }

  AzanModel _handleSuccessResponse(http.Response response, int method) {
    Map<String, dynamic> jsonString = jsonDecode(response.body);
    CacheHelper.sharedPreferences!
        .setString('azan_data', jsonEncode(jsonString));
    CacheHelper.sharedPreferences!.setInt('prayer_method', method);
    debugPrint('✅ Prayer times fetched successfully');
    return AzanModel.fromJson(jsonString);
  }

  /// Load prayer times from cache
  AzanModel _loadFromCache() {
    final cachedData = CacheHelper.sharedPreferences?.getString('azan_data');
    if (cachedData != null && cachedData.isNotEmpty) {
      debugPrint('📦 Loading prayer times from cache');
      try {
        return AzanModel.fromJson(jsonDecode(cachedData));
      } catch (e) {
        debugPrint('❌ Error parsing cached data: $e');
        throw Exception('Cached data is corrupted');
      }
    }
    throw Exception('No cached prayer times available');
  }

  // Optional: Close the shared client when done
  static void closeClient() {
    _sharedClient?.close();
    _sharedClient = null;
  }
}
