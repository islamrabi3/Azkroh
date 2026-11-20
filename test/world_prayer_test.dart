import 'package:azkroh_app/features/core/services/prayer_times_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('valid, ordered prayer times all over the world', () async {
    SharedPreferences.setMockInitialValues({});
    final s = PrayerTimesService();
    final cities = {
      'Makkah': [21.42, 39.83],
      'Cairo': [30.04, 31.24],
      'London': [51.51, -0.13],
      'Oslo': [59.91, 10.75],
      'Reykjavik': [64.15, -21.94],
      'New York': [40.71, -74.0],
      'Jakarta': [-6.2, 106.85],
      'Sydney': [-33.87, 151.21],
      'Cape Town': [-33.92, 18.42],
      'Karachi': [24.86, 67.0],
    };
    for (final date in [DateTime(2026, 6, 21), DateTime(2026, 12, 21)]) {
      for (final e in cities.entries) {
        final slots = await s.slotsFor(e.value[0], e.value[1], date,
            includeSunrise: true);
        for (int i = 1; i < slots.length; i++) {
          expect(slots[i].time.isAfter(slots[i - 1].time), true,
              reason: '${e.key} $date ${slots[i - 1].key}->${slots[i].key}');
        }
      }
    }
  });
}
