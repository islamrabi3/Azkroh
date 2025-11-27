import 'package:azkroh_app/features/core/notification_service.dart';
import 'package:azkroh_app/features/domain/entity/azan_entity.dart';

class PrayerNotificationScheduler {
  static final PrayerNotificationScheduler _instance = PrayerNotificationScheduler._internal();
  factory PrayerNotificationScheduler() => _instance;
  PrayerNotificationScheduler._internal();

  final NotificationService _notificationService = NotificationService();

  /// Schedule all prayer notifications based on AzanEntity data
  Future<void> scheduleAllPrayerNotifications(AzanEntity azanEntity) async {
    try {
      // Cancel existing prayer notifications first
      await _cancelAllPrayerNotifications();

      final timings = azanEntity.data.timings;
      final today = DateTime.now();

      // Schedule Fajr notification
      final fajrTime = _parseTimeString(timings.fajr, today);
      if (fajrTime.isAfter(DateTime.now())) {
        await _notificationService.schedulePrayerNotification(
          id: NotificationService.fajrNotificationId,
          prayerName: 'الفجر',
          scheduledTime: fajrTime,
          customMessage: 'حان الآن وقت صلاة الفجر. استيقظ للصلاة وابدأ يومك بذكر الله',
        );
      }

      // Schedule Dhuhr notification
      final dhuhrTime = _parseTimeString(timings.dhuhr, today);
      if (dhuhrTime.isAfter(DateTime.now())) {
        await _notificationService.schedulePrayerNotification(
          id: NotificationService.dhuhrNotificationId,
          prayerName: 'الظهر',
          scheduledTime: dhuhrTime,
          customMessage: 'حان الآن وقت صلاة الظهر. توقف عن عملك وتوجه للصلاة',
        );
      }

      // Schedule Asr notification
      final asrTime = _parseTimeString(timings.asr, today);
      if (asrTime.isAfter(DateTime.now())) {
        await _notificationService.schedulePrayerNotification(
          id: NotificationService.asrNotificationId,
          prayerName: 'العصر',
          scheduledTime: asrTime,
          customMessage: 'حان الآن وقت صلاة العصر. لا تفوت هذه الصلاة المباركة',
        );
      }

      // Schedule Maghrib notification
      final maghribTime = _parseTimeString(timings.maghrib, today);
      if (maghribTime.isAfter(DateTime.now())) {
        await _notificationService.schedulePrayerNotification(
          id: NotificationService.maghribNotificationId,
          prayerName: 'المغرب',
          scheduledTime: maghribTime,
          customMessage: 'حان الآن وقت صلاة المغرب. اللهم بلغنا ليلة القدر',
        );
      }

      // Schedule Isha notification
      final ishaTime = _parseTimeString(timings.isha, today);
      if (ishaTime.isAfter(DateTime.now())) {
        await _notificationService.schedulePrayerNotification(
          id: NotificationService.ishaNotificationId,
          prayerName: 'العشاء',
          scheduledTime: ishaTime,
          customMessage: 'حان الآن وقت صلاة العشاء. اختتم يومك بالصلاة والدعاء',
        );
      }

      print('تم جدولة جميع إشعارات أوقات الصلاة بنجاح');
    } catch (e) {
      print('خطأ في جدولة إشعارات الصلاة: $e');
    }
  }

  /// Schedule notifications for the next day
  Future<void> scheduleNextDayPrayerNotifications(AzanEntity azanEntity) async {
    try {
      final timings = azanEntity.data.timings;
      final tomorrow = DateTime.now().add(const Duration(days: 1));

      // Schedule all prayers for tomorrow
      final fajrTime = _parseTimeString(timings.fajr, tomorrow);
      await _notificationService.schedulePrayerNotification(
        id: NotificationService.fajrNotificationId + 10, // Different ID for next day
        prayerName: 'الفجر',
        scheduledTime: fajrTime,
        customMessage: 'حان الآن وقت صلاة الفجر. استيقظ للصلاة وابدأ يومك بذكر الله',
      );

      final dhuhrTime = _parseTimeString(timings.dhuhr, tomorrow);
      await _notificationService.schedulePrayerNotification(
        id: NotificationService.dhuhrNotificationId + 10,
        prayerName: 'الظهر',
        scheduledTime: dhuhrTime,
        customMessage: 'حان الآن وقت صلاة الظهر. توقف عن عملك وتوجه للصلاة',
      );

      final asrTime = _parseTimeString(timings.asr, tomorrow);
      await _notificationService.schedulePrayerNotification(
        id: NotificationService.asrNotificationId + 10,
        prayerName: 'العصر',
        scheduledTime: asrTime,
        customMessage: 'حان الآن وقت صلاة العصر. لا تفوت هذه الصلاة المباركة',
      );

      final maghribTime = _parseTimeString(timings.maghrib, tomorrow);
      await _notificationService.schedulePrayerNotification(
        id: NotificationService.maghribNotificationId + 10,
        prayerName: 'المغرب',
        scheduledTime: maghribTime,
        customMessage: 'حان الآن وقت صلاة المغرب. اللهم بلغنا ليلة القدر',
      );

      final ishaTime = _parseTimeString(timings.isha, tomorrow);
      await _notificationService.schedulePrayerNotification(
        id: NotificationService.ishaNotificationId + 10,
        prayerName: 'العشاء',
        scheduledTime: ishaTime,
        customMessage: 'حان الآن وقت صلاة العشاء. اختتم يومك بالصلاة والدعاء',
      );

      print('تم جدولة إشعارات الصلاة لليوم التالي بنجاح');
    } catch (e) {
      print('خطأ في جدولة إشعارات الصلاة لليوم التالي: $e');
    }
  }

  /// Schedule pre-prayer reminders (15 minutes before each prayer)
  Future<void> schedulePrayerReminders(AzanEntity azanEntity) async {
    try {
      final timings = azanEntity.data.timings;
      final today = DateTime.now();
      const reminderMinutes = 15;

      // Schedule Fajr reminder
      final fajrTime = _parseTimeString(timings.fajr, today);
      final fajrReminder = fajrTime.subtract(const Duration(minutes: reminderMinutes));
      if (fajrReminder.isAfter(DateTime.now())) {
        await _notificationService.schedulePrayerNotification(
          id: NotificationService.fajrNotificationId + 50,
          prayerName: 'الفجر',
          scheduledTime: fajrReminder,
          customMessage: 'تذكير: صلاة الفجر خلال $reminderMinutes دقيقة. استعد للصلاة',
        );
      }

      // Schedule Dhuhr reminder
      final dhuhrTime = _parseTimeString(timings.dhuhr, today);
      final dhuhrReminder = dhuhrTime.subtract(const Duration(minutes: reminderMinutes));
      if (dhuhrReminder.isAfter(DateTime.now())) {
        await _notificationService.schedulePrayerNotification(
          id: NotificationService.dhuhrNotificationId + 50,
          prayerName: 'الظهر',
          scheduledTime: dhuhrReminder,
          customMessage: 'تذكير: صلاة الظهر خلال $reminderMinutes دقيقة. استعد للصلاة',
        );
      }

      // Schedule Asr reminder
      final asrTime = _parseTimeString(timings.asr, today);
      final asrReminder = asrTime.subtract(const Duration(minutes: reminderMinutes));
      if (asrReminder.isAfter(DateTime.now())) {
        await _notificationService.schedulePrayerNotification(
          id: NotificationService.asrNotificationId + 50,
          prayerName: 'العصر',
          scheduledTime: asrReminder,
          customMessage: 'تذكير: صلاة العصر خلال $reminderMinutes دقيقة. استعد للصلاة',
        );
      }

      // Schedule Maghrib reminder
      final maghribTime = _parseTimeString(timings.maghrib, today);
      final maghribReminder = maghribTime.subtract(const Duration(minutes: reminderMinutes));
      if (maghribReminder.isAfter(DateTime.now())) {
        await _notificationService.schedulePrayerNotification(
          id: NotificationService.maghribNotificationId + 50,
          prayerName: 'المغرب',
          scheduledTime: maghribReminder,
          customMessage: 'تذكير: صلاة المغرب خلال $reminderMinutes دقيقة. استعد للصلاة',
        );
      }

      // Schedule Isha reminder
      final ishaTime = _parseTimeString(timings.isha, today);
      final ishaReminder = ishaTime.subtract(const Duration(minutes: reminderMinutes));
      if (ishaReminder.isAfter(DateTime.now())) {
        await _notificationService.schedulePrayerNotification(
          id: NotificationService.ishaNotificationId + 50,
          prayerName: 'العشاء',
          scheduledTime: ishaReminder,
          customMessage: 'تذكير: صلاة العشاء خلال $reminderMinutes دقيقة. استعد للصلاة',
        );
      }

      print('تم جدولة تذكيرات الصلاة بنجاح');
    } catch (e) {
      print('خطأ في جدولة تذكيرات الصلاة: $e');
    }
  }

  /// Parse time string (HH:mm format) and combine with date
  DateTime _parseTimeString(String timeString, DateTime date) {
    try {
      // Remove any extra characters and parse time
      final cleanTime = timeString.trim().split(' ')[0]; // Remove timezone info if present
      final timeParts = cleanTime.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      
      return DateTime(
        date.year,
        date.month,
        date.day,
        hour,
        minute,
      );
    } catch (e) {
      print('خطأ في تحليل الوقت: $timeString - $e');
      return DateTime.now();
    }
  }

  /// Cancel all prayer notifications
  Future<void> _cancelAllPrayerNotifications() async {
    await _notificationService.cancelNotification(NotificationService.fajrNotificationId);
    await _notificationService.cancelNotification(NotificationService.dhuhrNotificationId);
    await _notificationService.cancelNotification(NotificationService.asrNotificationId);
    await _notificationService.cancelNotification(NotificationService.maghribNotificationId);
    await _notificationService.cancelNotification(NotificationService.ishaNotificationId);
    
    // Cancel reminders
    await _notificationService.cancelNotification(NotificationService.fajrNotificationId + 50);
    await _notificationService.cancelNotification(NotificationService.dhuhrNotificationId + 50);
    await _notificationService.cancelNotification(NotificationService.asrNotificationId + 50);
    await _notificationService.cancelNotification(NotificationService.maghribNotificationId + 50);
    await _notificationService.cancelNotification(NotificationService.ishaNotificationId + 50);
    
    // Cancel next day notifications
    await _notificationService.cancelNotification(NotificationService.fajrNotificationId + 10);
    await _notificationService.cancelNotification(NotificationService.dhuhrNotificationId + 10);
    await _notificationService.cancelNotification(NotificationService.asrNotificationId + 10);
    await _notificationService.cancelNotification(NotificationService.maghribNotificationId + 10);
    await _notificationService.cancelNotification(NotificationService.ishaNotificationId + 10);
  }

  /// Get next prayer time and name
  Map<String, dynamic>? getNextPrayerInfo(AzanEntity azanEntity) {
    try {
      final timings = azanEntity.data.timings;
      final now = DateTime.now();
      final today = DateTime.now();

      final prayers = [
        {'name': 'الفجر', 'time': _parseTimeString(timings.fajr, today)},
        {'name': 'الظهر', 'time': _parseTimeString(timings.dhuhr, today)},
        {'name': 'العصر', 'time': _parseTimeString(timings.asr, today)},
        {'name': 'المغرب', 'time': _parseTimeString(timings.maghrib, today)},
        {'name': 'العشاء', 'time': _parseTimeString(timings.isha, today)},
      ];

      // Find next prayer
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

      // If no prayer today, return Fajr of tomorrow
      final tomorrow = today.add(const Duration(days: 1));
      final fajrTomorrow = _parseTimeString(timings.fajr, tomorrow);
      return {
        'name': 'الفجر',
        'time': fajrTomorrow,
        'remaining': fajrTomorrow.difference(now),
      };
    } catch (e) {
      print('خطأ في الحصول على معلومات الصلاة التالية: $e');
      return null;
    }
  }

  /// Check if prayer notifications are enabled
  Future<bool> arePrayerNotificationsEnabled() async {
    final prefs = await _notificationService.loadNotificationPreferences();
    return prefs['prayer_notifications'] ?? true;
  }

  /// Enable or disable prayer notifications
  Future<void> setPrayerNotificationsEnabled(bool enabled, AzanEntity? azanEntity) async {
    final prefs = await _notificationService.loadNotificationPreferences();
    await _notificationService.saveNotificationPreferences(
      prayerNotifications: enabled,
      dhikrReminders: prefs['dhikr_reminders'] ?? true,
      qiblaReminders: prefs['qibla_reminders'] ?? false,
      dhikrInterval: prefs['dhikr_interval'] ?? 2,
    );

    if (enabled && azanEntity != null) {
      await scheduleAllPrayerNotifications(azanEntity);
      await schedulePrayerReminders(azanEntity);
    } else {
      await _cancelAllPrayerNotifications();
    }
  }
}