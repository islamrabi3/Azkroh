import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

/// Global Location Service for handling location and timezone globally
class GlobalLocationService {
  static final GlobalLocationService _instance =
      GlobalLocationService._internal();
  factory GlobalLocationService() => _instance;
  GlobalLocationService._internal();

  Position? _currentPosition;
  String? _timezoneName;
  bool _isInitialized = false;

  Position? get currentPosition => _currentPosition;
  String? get timezoneName => _timezoneName;
  bool get isInitialized => _isInitialized;

  /// Initialize the location service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize timezone database
    tz_data.initializeTimeZones();

    // Try to get cached location first
    await _loadCachedLocation();

    // Get current location
    await getCurrentLocation();

    // Set local timezone
    await _setLocalTimezone();

    _isInitialized = true;
  }

  /// Get current location with permission handling
  Future<Position?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return _currentPosition;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return _currentPosition;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return _currentPosition;
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Cache the location
      await _cacheLocation();

      return _currentPosition;
    } catch (e) {
      debugPrint('Error getting location: $e');
      return _currentPosition;
    }
  }

  /// Get the calculation method based on location
  /// Returns the appropriate method for the Aladhan API
  int getCalculationMethod() {
    if (_currentPosition == null) return 4; // Default to Umm Al-Qura

    double lat = _currentPosition!.latitude;
    double lon = _currentPosition!.longitude;

    // Determine calculation method based on location
    // 1 = University of Islamic Sciences, Karachi
    // 2 = Islamic Society of North America (ISNA)
    // 3 = Muslim World League
    // 4 = Umm Al-Qura University, Makkah
    // 5 = Egyptian General Authority of Survey
    // 7 = Institute of Geophysics, University of Tehran
    // 8 = Gulf Region
    // 9 = Kuwait
    // 10 = Qatar
    // 11 = Majlis Ugama Islam Singapura, Singapore
    // 12 = Union Organization islamic de France
    // 13 = Diyanet İşleri Başkanlığı, Turkey
    // 14 = Spiritual Administration of Muslims of Russia
    // 15 = Moonsighting Committee Worldwide
    // 16 = Dubai

    // Middle East & Gulf Region
    if (lat >= 12 && lat <= 42 && lon >= 25 && lon <= 63) {
      // Saudi Arabia
      if (lat >= 16 && lat <= 32 && lon >= 34 && lon <= 56) {
        return 4; // Umm Al-Qura
      }
      // Egypt
      if (lat >= 22 && lat <= 32 && lon >= 25 && lon <= 35) {
        return 5; // Egyptian
      }
      // Gulf countries
      if (lat >= 22 && lat <= 30 && lon >= 45 && lon <= 60) {
        return 8; // Gulf Region
      }
      // Kuwait
      if (lat >= 28 && lat <= 31 && lon >= 46 && lon <= 49) {
        return 9; // Kuwait
      }
      // Qatar
      if (lat >= 24 && lat <= 27 && lon >= 50 && lon <= 52) {
        return 10; // Qatar
      }
      // Turkey
      if (lat >= 36 && lat <= 42 && lon >= 26 && lon <= 45) {
        return 13; // Turkey
      }
      // Iran
      if (lat >= 25 && lat <= 40 && lon >= 44 && lon <= 63) {
        return 7; // Tehran
      }
    }

    // North America
    if (lat >= 15 && lat <= 72 && lon >= -170 && lon <= -50) {
      return 2; // ISNA
    }

    // Europe
    if (lat >= 35 && lat <= 72 && lon >= -25 && lon <= 45) {
      // France
      if (lat >= 41 && lat <= 51 && lon >= -5 && lon <= 10) {
        return 12; // France
      }
      // Russia
      if (lat >= 41 && lat <= 72 && lon >= 20 && lon <= 45) {
        return 14; // Russia
      }
      return 3; // Muslim World League
    }

    // South Asia (Pakistan, India, Bangladesh)
    if (lat >= 5 && lat <= 38 && lon >= 60 && lon <= 100) {
      return 1; // Karachi
    }

    // Southeast Asia
    if (lat >= -10 && lat <= 20 && lon >= 95 && lon <= 145) {
      return 11; // Singapore
    }

    // Default: Muslim World League (works globally)
    return 3;
  }

  /// Get timezone offset in hours
  double getTimezoneOffset() {
    return DateTime.now().timeZoneOffset.inMinutes / 60.0;
  }

  /// Get the local TZDateTime
  tz.TZDateTime getTZDateTime(DateTime dateTime) {
    return tz.TZDateTime.from(dateTime, tz.local);
  }

  /// Set the local timezone
  Future<void> _setLocalTimezone() async {
    try {
      final now = DateTime.now();
      final offset = now.timeZoneOffset;

      // Find matching timezone
      final locations = tz.timeZoneDatabase.locations;
      for (var entry in locations.entries) {
        final location = entry.value;
        final locTime = tz.TZDateTime.now(location);
        if (locTime.timeZoneOffset == offset) {
          _timezoneName = entry.key;
          tz.setLocalLocation(location);
          break;
        }
      }

      _timezoneName ??= 'UTC';
    } catch (e) {
      debugPrint('Error setting timezone: $e');
      _timezoneName = 'UTC';
    }
  }

  /// Cache location to SharedPreferences
  Future<void> _cacheLocation() async {
    if (_currentPosition == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('cached_latitude', _currentPosition!.latitude);
      await prefs.setDouble('cached_longitude', _currentPosition!.longitude);
      await prefs.setInt(
          'location_timestamp', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Error caching location: $e');
    }
  }

  /// Load cached location from SharedPreferences
  Future<void> _loadCachedLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble('cached_latitude');
      final lon = prefs.getDouble('cached_longitude');
      final timestamp = prefs.getInt('location_timestamp');

      if (lat != null && lon != null) {
        // Check if cache is less than 24 hours old
        if (timestamp != null) {
          final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
          final now = DateTime.now();
          if (now.difference(cacheTime).inHours < 24) {
            _currentPosition = Position(
              latitude: lat,
              longitude: lon,
              timestamp: cacheTime,
              accuracy: 0,
              altitude: 0,
              heading: 0,
              speed: 0,
              speedAccuracy: 0,
              altitudeAccuracy: 0,
              headingAccuracy: 0,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading cached location: $e');
    }
  }

  /// Get location name (city/country) - simplified
  String getLocationDescription() {
    if (_currentPosition == null) return 'غير محدد';
    return 'موقعك الحالي';
  }

  /// Check if location permission is granted
  Future<bool> hasLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Request location permission
  Future<bool> requestLocationPermission() async {
    LocationPermission permission = await Geolocator.requestPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }
}
