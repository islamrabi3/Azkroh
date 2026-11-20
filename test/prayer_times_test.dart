import 'package:azkroh_app/features/core/services/prayer_times_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Cairo uses Egyptian method and times differ day to day', () async {
    SharedPreferences.setMockInitialValues({});
    final s = PrayerTimesService();
    expect(s.autoMethodFor(30.04, 31.24), 'egyptian');
    expect(s.autoMethodFor(21.42, 39.83), 'umm_al_qura');
    final d1 = await s.slotsFor(30.04, 31.24, DateTime(2026, 4, 20));
    final d2 = await s.slotsFor(30.04, 31.24, DateTime(2026, 6, 20));
    expect(d1.length, 5);
    expect(d1.first.key, 'fajr');
    expect(d1.first.time.isBefore(d1[1].time), true);
    expect(PrayerTimesService.hhmm(d1.first.time) != PrayerTimesService.hhmm(d2.first.time), true);
  });
}
