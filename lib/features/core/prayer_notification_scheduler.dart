import 'package:azkroh_app/l10n/app_locale.dart';
import 'dart:io';

import 'package:azkroh_app/features/core/notification_service.dart';
import 'package:azkroh_app/features/core/services/global_location_service.dart';
import 'package:azkroh_app/features/core/services/prayer_times_service.dart';
import 'package:azkroh_app/features/domain/entity/azan_entity.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Schedules Adhan notifications.
///
/// Prayer times shift every day (and jump when daylight saving starts/ends),
/// so instead of one notification that repeats daily at a fixed clock time,
/// every prayer of the next few days is booked individually with its own,
/// freshly calculated time. Scheduling is refreshed every time the app opens.
class PrayerNotificationScheduler {
  static final PrayerNotificationScheduler _instance =
      PrayerNotificationScheduler._internal();
  factory PrayerNotificationScheduler() => _instance;
  PrayerNotificationScheduler._internal();

  final NotificationService _notificationService = NotificationService();
  final PrayerTimesService _timesService = PrayerTimesService();

  static const String prefPreReminderMinutes = 'prayer_pre_reminder_minutes';

  static const int _refreshReminderId = NotificationService.prayerBaseId + 999;

  static const Map<String, String> _messages = {
    'fajr': 'حان الآن وقت صلاة الفجر. الصلاة خير من النوم',
    'dhuhr': 'حان الآن وقت صلاة الظهر. أرحنا بها يا بلال',
    'asr': 'حان الآن وقت صلاة العصر. حافظوا على الصلوات والصلاة الوسطى',
    'maghrib': 'حان الآن وقت صلاة المغرب. تقبل الله منا ومنكم',
    'isha': 'حان الآن وقت صلاة العشاء. اختم يومك بالصلاة والذكر',
  };

  bool _busy = false;

  Future<int> getPreReminderMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(prefPreReminderMinutes) ?? 0;
  }

  Future<void> setPreReminderMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(prefPreReminderMinutes, minutes);
    await scheduleUpcoming();
  }

  Future<List<double>?> _coordinates() async {
    final pos = GlobalLocationService().currentPosition;
    if (pos != null) return [pos.latitude, pos.longitude];
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('cached_latitude');
    final lon = prefs.getDouble('cached_longitude');
    if (lat == null || lon == null) return null;
    return [lat, lon];
  }

  /// (Re)schedules every prayer notification for the coming days.
  Future<void> scheduleUpcoming() async {
    if (_busy) return;
    _busy = true;
    try {
      await _cancelAllPrayerNotifications();

      if (!await arePrayerNotificationsEnabled()) return;

      final coords = await _coordinates();
      if (coords == null) {
        debugPrint('⚠️ No location yet, prayer notifications not scheduled');
        return;
      }

      final preMinutes = await getPreReminderMinutes();
      // iOS keeps at most 64 pending notifications per app (dhikr reminders
      // use ~20 of them), Android has no such small limit.
      final int days = Platform.isIOS ? (preMinutes > 0 ? 3 : 6) : 10;

      final now = DateTime.now();
      DateTime? lastScheduled;

      for (int d = 0; d < days; d++) {
        final date = DateTime(now.year, now.month, now.day + d);
        final slots = await _timesService.slotsFor(coords[0], coords[1], date);

        for (int p = 0; p < slots.length; p++) {
          final slot = slots[p];
          if (!slot.time.isAfter(now)) continue;

          await _notificationService.schedulePrayerNotification(
            id: NotificationService.prayerBaseId + d * 20 + p,
            prayerName: slot.arabicName,
            scheduledTime: slot.time,
            customMessage: tr(_messages[slot.key]!),
            title: '${tr('حان الآن وقت صلاة')} ${tr(slot.arabicName)}',
          );
          lastScheduled = slot.time;

          if (preMinutes > 0) {
            final pre = slot.time.subtract(Duration(minutes: preMinutes));
            if (pre.isAfter(now)) {
              await _notificationService.scheduleDhikrReminder(
                id: NotificationService.prayerBaseId + d * 20 + 10 + p,
                title: '${tr('اقتربت صلاة')} ${tr(slot.arabicName)}',
                dhikrText:
                    '${tr('دقائق متبقية على الأذان:')} ${AppLocale.digits(preMinutes)} • ${tr('استعد للصلاة وتوضأ')}',
                scheduledTime: pre,
                isRepeating: false,
                payload: 'prayer_reminder',
              );
            }
          }
        }
      }

      // If the app is not opened for a long time, ask the user to open it so
      // the next days get scheduled.
      if (lastScheduled != null) {
        await _notificationService.scheduleDhikrReminder(
          id: _refreshReminderId,
          title: tr('تحديث مواقيت الصلاة'),
          dhikrText:
              tr('افتح تطبيق اذكروه لتحديث مواقيت الصلاة واستمرار تنبيهات الأذان'),
          scheduledTime: lastScheduled.add(const Duration(minutes: 30)),
          isRepeating: false,
          payload: 'refresh',
        );
      }

      debugPrint('✅ Prayer notifications scheduled for $days days');
    } catch (e) {
      debugPrint('❌ Error scheduling prayer notifications: $e');
    } finally {
      _busy = false;
    }
  }

  /// Kept for backward compatibility with older call sites.
  Future<void> scheduleAllPrayerNotifications(AzanEntity azanEntity) =>
      scheduleUpcoming();

  /// Pre-prayer reminders are now part of [scheduleUpcoming].
  Future<void> schedulePrayerReminders(AzanEntity azanEntity) async {}

  Future<void> _cancelAllPrayerNotifications() async {
    final pending = await _notificationService.getPendingNotifications();
    for (final n in pending) {
      final id = n.id;
      final isLegacy = (id >= 1 && id <= 5) ||
          (id >= 11 && id <= 15) ||
          (id >= 51 && id <= 55);
      final isNew = id >= NotificationService.prayerBaseId &&
          id <= NotificationService.prayerBaseId + 999;
      if (isLegacy || isNew) {
        await _notificationService.cancelNotification(id);
      }
    }
  }

  DateTime _parseTimeString(String timeString, DateTime date) {
    try {
      final cleanTime = timeString.trim().split(' ')[0];
      final timeParts = cleanTime.split(':');
      return DateTime(date.year, date.month, date.day,
          int.parse(timeParts[0]), int.parse(timeParts[1]));
    } catch (e) {
      return DateTime.now();
    }
  }

  /// Get next prayer time and name
  Map<String, dynamic>? getNextPrayerInfo(AzanEntity azanEntity) {
    try {
      final timings = azanEntity.data.timings;
      final now = DateTime.now();

      final prayers = [
        {'name': 'الفجر', 'time': _parseTimeString(timings.fajr, now)},
        {'name': 'الظهر', 'time': _parseTimeString(timings.dhuhr, now)},
        {'name': 'العصر', 'time': _parseTimeString(timings.asr, now)},
        {'name': 'المغرب', 'time': _parseTimeString(timings.maghrib, now)},
        {'name': 'العشاء', 'time': _parseTimeString(timings.isha, now)},
      ];

      for (final prayer in prayers) {
        final prayerTime = prayer['time'] as DateTime;
        if (prayerTime.isAfter(now)) {
          return {
            'name': prayer['name'],
            'time': prayerTime,
            'remaining': prayerTime.difference(now),
          };
        }
      }

      final fajrTomorrow =
          _parseTimeString(timings.fajr, now.add(const Duration(days: 1)));
      return {
        'name': 'الفجر',
        'time': fajrTomorrow,
        'remaining': fajrTomorrow.difference(now),
      };
    } catch (e) {
      return null;
    }
  }

  Future<bool> arePrayerNotificationsEnabled() async {
    final prefs = await _notificationService.loadNotificationPreferences();
    return prefs['prayer_notifications'] ?? true;
  }

  Future<void> setPrayerNotificationsEnabled(
      bool enabled, AzanEntity? azanEntity) async {
    final prefs = await _notificationService.loadNotificationPreferences();
    await _notificationService.saveNotificationPreferences(
      prayerNotifications: enabled,
      dhikrReminders: prefs['dhikr_reminders'] ?? true,
      qiblaReminders: prefs['qibla_reminders'] ?? false,
      dhikrInterval: prefs['dhikr_interval'] ?? 2,
    );
    await scheduleUpcoming();
  }
}
