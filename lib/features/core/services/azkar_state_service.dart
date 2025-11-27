import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage Azkar counts with daily reset logic
class AzkarStateService {
  static final AzkarStateService _instance = AzkarStateService._internal();
  factory AzkarStateService() => _instance;
  AzkarStateService._internal();

  static const String _morningAzkarKey = 'morning_azkar_counts';
  static const String _eveningAzkarKey = 'evening_azkar_counts';
  static const String _morningDateKey = 'morning_azkar_date';
  static const String _eveningDateKey = 'evening_azkar_date';
  static const String _morningCompletedKey = 'morning_azkar_completed';
  static const String _eveningCompletedKey = 'evening_azkar_completed';

  // Morning Azkar time: After Fajr until sunrise (approx 6 AM to 7:30 AM)
  // Evening Azkar time: After Asr until Maghrib (approx 3 PM to sunset)
  
  /// Check if it's morning Azkar time (after Fajr, before Dhuhr)
  bool isMorningAzkarTime() {
    final now = DateTime.now();
    final hour = now.hour;
    // Morning Azkar: 4 AM to 12 PM
    return hour >= 4 && hour < 12;
  }

  /// Check if it's evening Azkar time (after Asr, before Isha)
  bool isEveningAzkarTime() {
    final now = DateTime.now();
    final hour = now.hour;
    // Evening Azkar: 3 PM to 10 PM
    return hour >= 15 && hour < 22;
  }

  /// Get the current Azkar period type
  AzkarPeriod getCurrentPeriod() {
    if (isMorningAzkarTime()) {
      return AzkarPeriod.morning;
    } else if (isEveningAzkarTime()) {
      return AzkarPeriod.evening;
    }
    return AzkarPeriod.none;
  }

  /// Save Azkar counts for the current period
  Future<void> saveAzkarCounts({
    required String azkarType, // 'morning' or 'evening'
    required Map<String, int> counts, // id -> remaining count
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String key = azkarType == 'morning' ? _morningAzkarKey : _eveningAzkarKey;
      final String dateKey = azkarType == 'morning' ? _morningDateKey : _eveningDateKey;
      
      await prefs.setString(key, jsonEncode(counts));
      await prefs.setString(dateKey, _getTodayDateString());
    } catch (e) {
      print('Error saving Azkar counts: $e');
    }
  }

  /// Load Azkar counts for the current period
  /// Returns null if should reset (new day or past the time period)
  Future<Map<String, int>?> loadAzkarCounts({required String azkarType}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String key = azkarType == 'morning' ? _morningAzkarKey : _eveningAzkarKey;
      final String dateKey = azkarType == 'morning' ? _morningDateKey : _eveningDateKey;
      
      final String? savedDate = prefs.getString(dateKey);
      final String todayDate = _getTodayDateString();
      
      // Check if it's a new day
      if (savedDate != todayDate) {
        // Reset counts for new day
        await _clearAzkarCounts(azkarType);
        return null;
      }
      
      // Check if we're in the correct time period
      if (azkarType == 'morning' && !isMorningAzkarTime()) {
        // Morning time has passed, reset
        return null;
      }
      if (azkarType == 'evening' && !isEveningAzkarTime()) {
        // Evening time has passed, reset
        return null;
      }
      
      // Load saved counts
      final String? countsJson = prefs.getString(key);
      if (countsJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(countsJson);
        return decoded.map((key, value) => MapEntry(key, value as int));
      }
      
      return null;
    } catch (e) {
      print('Error loading Azkar counts: $e');
      return null;
    }
  }

  /// Mark Azkar as completed for today
  Future<void> markAzkarCompleted({required String azkarType}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String key = azkarType == 'morning' ? _morningCompletedKey : _eveningCompletedKey;
      await prefs.setString(key, _getTodayDateString());
    } catch (e) {
      print('Error marking Azkar completed: $e');
    }
  }

  /// Check if Azkar is completed for today
  Future<bool> isAzkarCompletedToday({required String azkarType}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String key = azkarType == 'morning' ? _morningCompletedKey : _eveningCompletedKey;
      final String? completedDate = prefs.getString(key);
      return completedDate == _getTodayDateString();
    } catch (e) {
      print('Error checking Azkar completion: $e');
      return false;
    }
  }

  /// Get progress for Azkar (percentage completed)
  Future<double> getAzkarProgress({
    required String azkarType,
    required int totalItems,
    required int totalRepeatCount,
  }) async {
    try {
      final counts = await loadAzkarCounts(azkarType: azkarType);
      if (counts == null) return 0.0;
      
      int remainingCount = counts.values.fold(0, (sum, count) => sum + count);
      int completedCount = totalRepeatCount - remainingCount;
      
      return (completedCount / totalRepeatCount).clamp(0.0, 1.0);
    } catch (e) {
      print('Error getting Azkar progress: $e');
      return 0.0;
    }
  }

  /// Clear Azkar counts
  Future<void> _clearAzkarCounts(String azkarType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String key = azkarType == 'morning' ? _morningAzkarKey : _eveningAzkarKey;
      await prefs.remove(key);
    } catch (e) {
      print('Error clearing Azkar counts: $e');
    }
  }

  /// Get today's date as string (YYYY-MM-DD)
  String _getTodayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Get remaining time for current Azkar period
  Duration? getRemainingTimeForPeriod() {
    final now = DateTime.now();
    
    if (isMorningAzkarTime()) {
      // End of morning period is 12 PM
      final endTime = DateTime(now.year, now.month, now.day, 12, 0);
      return endTime.difference(now);
    } else if (isEveningAzkarTime()) {
      // End of evening period is 10 PM
      final endTime = DateTime(now.year, now.month, now.day, 22, 0);
      return endTime.difference(now);
    }
    
    return null;
  }

  /// Get next Azkar period start time
  DateTime getNextAzkarPeriodStart() {
    final now = DateTime.now();
    final hour = now.hour;
    
    if (hour < 4) {
      // Before morning - next is morning today
      return DateTime(now.year, now.month, now.day, 4, 0);
    } else if (hour >= 4 && hour < 12) {
      // During morning - next is evening today
      return DateTime(now.year, now.month, now.day, 15, 0);
    } else if (hour >= 12 && hour < 15) {
      // Between morning and evening - next is evening today
      return DateTime(now.year, now.month, now.day, 15, 0);
    } else if (hour >= 15 && hour < 22) {
      // During evening - next is morning tomorrow
      return DateTime(now.year, now.month, now.day + 1, 4, 0);
    } else {
      // After evening - next is morning tomorrow
      return DateTime(now.year, now.month, now.day + 1, 4, 0);
    }
  }
}

enum AzkarPeriod {
  morning,
  evening,
  none,
}

