import 'package:azkroh_app/features/core/notification_router.dart';
import 'package:azkroh_app/l10n/app_locale.dart';
import 'package:flutter/foundation.dart';
import 'package:azkroh_app/features/core/services/prayer_times_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'package:azkroh_app/features/core/notification_service.dart';

class DhikrNotificationScheduler {
  static final DhikrNotificationScheduler _instance =
      DhikrNotificationScheduler._internal();
  factory DhikrNotificationScheduler() => _instance;
  DhikrNotificationScheduler._internal();

  final NotificationService _notificationService = NotificationService();
  final Random _random = Random();

  // Collection of Islamic dhikr and reminders
  static const List<String> dhikrList = [
    'سبحان الله وبحمده، سبحان الله العظيم',
    'لا إله إلا الله وحده لا شريك له، له الملك وله الحمد وهو على كل شيء قدير',
    'اللهم صل وسلم وبارك على نبينا محمد',
    'استغفر الله العظيم الذي لا إله إلا هو الحي القيوم وأتوب إليه',
    'لا حول ولا قوة إلا بالله العلي العظيم',
    'حسبنا الله ونعم الوكيل',
    'رب اغفر لي ذنبي وخطئي وجهلي',
    'اللهم أعني على ذكرك وشكرك وحسن عبادتك',
    'ربنا آتنا في الدنيا حسنة وفي الآخرة حسنة وقنا عذاب النار',
    'اللهم إنك عفو تحب العفو فاعف عني',
    'سبحان الله والحمد لله ولا إله إلا الله والله أكبر',
    'اللهم بارك لنا فيما رزقتنا وقنا عذاب النار',
    'ربي اشرح لي صدري ويسر لي أمري',
    'اللهم إني أسألك من فضلك ورحمتك فإنه لا يملكها إلا أنت',
    'اللهم أصلح لي ديني الذي هو عصمة أمري',
    'يا حي يا قيوم برحمتك أستغيث',
    'اللهم إني أعوذ بك من الهم والحزن',
    'ربنا لا تزغ قلوبنا بعد إذ هديتنا وهب لنا من لدنك رحمة',
    'اللهم اهدني فيمن هديت وعافني فيمن عافيت',
    'سبحان ربي العظيم وبحمده',
  ];

  static const List<String> islamicReminders = [
    'تذكر أن تقرأ القرآن اليوم',
    'لا تنس أذكار الصباح والمساء',
    'تذكر الدعاء لوالديك',
    'استغفر الله في هذه اللحظة المباركة',
    'تذكر أن تصلي على النبي محمد ﷺ',
    'اقرأ سورة الفاتحة واحتسب الأجر',
    'تذكر أن تتصدق ولو بالقليل',
    'ادع الله أن يغفر لك ولوالديك',
    'تذكر أن تبر والديك',
    'اقرأ آية الكرسي للحفظ والبركة',
    'تذكر أن تدعو للمسلمين في العالم',
    'استعذ بالله من الشيطان الرجيم',
    'تذكر أن تشكر الله على نعمه',
    'ادع الله أن يهديك ويرزقك',
    'تذكر أن تتوب إلى الله',
  ];

  static const List<String> morningDhikr = [
    'أصبحنا وأصبح الملك لله، والحمد لله',
    'اللهم بك أصبحنا وبك أمسينا وبك نحيا وبك نموت وإليك النشور',
    'أصبحنا على فطرة الإسلام وعلى كلمة الإخلاص',
    'رضيت بالله ربا وبالإسلام دينا وبمحمد ﷺ رسولا',
    'اللهم أصبحت منك في نعمة وعافية وستر',
  ];

  static const List<String> eveningDhikr = [
    'أمسينا وأمسى الملك لله، والحمد لله',
    'اللهم بك أمسينا وبك أصبحنا وبك نحيا وبك نموت وإليك المصير',
    'أمسينا على فطرة الإسلام وعلى كلمة الإخلاص',
    'اللهم ما أمسى بي من نعمة أو بأحد من خلقك فمنك وحدك',
    'اللهم أمسيت منك في نعمة وعافية وستر',
  ];

  /// Schedule regular dhikr reminders
  Future<void> scheduleDhikrReminders() async {
    try {
      final prefs = await _notificationService.loadNotificationPreferences();
      final bool dhikrEnabled = prefs['dhikr_reminders'] ?? true;
      final int intervalHours = prefs['dhikr_interval'] ?? 2;

      // Cancel only the periodic reminders (ids 101..112)
      for (int k = 1; k <= 12; k++) {
        await _notificationService
            .cancelNotification(NotificationService.dhikrReminderBaseId + k);
      }

      if (!dhikrEnabled) {
        return;
      }

      final now = DateTime.now();
      final step = intervalHours < 1 ? 1 : intervalHours;

      // Fixed clock slots during waking hours (08:00 - 22:00), repeating
      // daily. Fixed slots keep the same times on every app launch.
      int i = 1;
      for (int hour = 8; hour <= 22 && i <= 12; hour += step, i++) {
        var scheduledTime = DateTime(now.year, now.month, now.day, hour, 30);
        if (!scheduledTime.isAfter(now)) {
          scheduledTime = scheduledTime.add(const Duration(days: 1));
        }

        final text = _getRandomDhikr();
        await _notificationService.scheduleDhikrReminder(
          id: NotificationService.dhikrReminderBaseId + i,
          dhikrText: text,
          scheduledTime: scheduledTime,
          isRepeating: true,
          payload: payloadFor(text, scheduledTime),
        );
      }

      print('تم جدولة تذكيرات الذكر بنجاح');
    } catch (e) {
      print('خطأ في جدولة تذكيرات الذكر: $e');
    }
  }

  /// Today's prayer slots from cached coordinates (null if unknown).
  Future<List<PrayerSlot>?> _todaySlots() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('cached_latitude');
    final lon = prefs.getDouble('cached_longitude');
    if (lat == null || lon == null) return null;
    return PrayerTimesService().slotsFor(lat, lon, DateTime.now());
  }

  DateTime _nextOccurrence(DateTime t) {
    final now = DateTime.now();
    var d = DateTime(now.year, now.month, now.day, t.hour, t.minute);
    if (!d.isAfter(now)) d = d.add(const Duration(days: 1));
    return d;
  }

  /// Morning azkar reminder: 20 minutes after Fajr (06:00 if unknown).
  Future<void> scheduleMorningDhikr() async {
    try {
      await _notificationService
          .cancelNotification(NotificationService.dhikrReminderBaseId + 50);
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool('morning_azkar') ?? true)) return;

      final slots = await _todaySlots();
      final base = slots != null
          ? slots.first.time.add(const Duration(minutes: 20))
          : DateTime(2000, 1, 1, 6, 0);
      final dhikrText = morningDhikr[_random.nextInt(morningDhikr.length)];

      await _notificationService.scheduleDhikrReminder(
        id: NotificationService.dhikrReminderBaseId + 50,
        title: '☀️ ${tr('أذكار الصباح')}',
        dhikrText: '$dhikrText\n${tr('افتح التطبيق لقراءة أذكار الصباح كاملة')}',
        scheduledTime: _nextOccurrence(base),
        isRepeating: true,
        payload: 'azkar_morning',
      );
    } catch (e) {
      debugPrint('❌ morning azkar: $e');
    }
  }

  /// Evening azkar reminder: 15 minutes after Asr (16:30 if unknown).
  Future<void> scheduleEveningDhikr() async {
    try {
      await _notificationService
          .cancelNotification(NotificationService.dhikrReminderBaseId + 51);
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool('evening_azkar') ?? true)) return;

      final slots = await _todaySlots();
      final base = slots != null
          ? slots.firstWhere((e) => e.key == 'asr').time
              .add(const Duration(minutes: 15))
          : DateTime(2000, 1, 1, 16, 30);
      final dhikrText = eveningDhikr[_random.nextInt(eveningDhikr.length)];

      await _notificationService.scheduleDhikrReminder(
        id: NotificationService.dhikrReminderBaseId + 51,
        title: '🌙 ${tr('أذكار المساء')}',
        dhikrText: '$dhikrText\n${tr('افتح التطبيق لقراءة أذكار المساء كاملة')}',
        scheduledTime: _nextOccurrence(base),
        isRepeating: true,
        payload: 'azkar_evening',
      );
    } catch (e) {
      debugPrint('❌ evening azkar: $e');
    }
  }

  Future<void> setMorningEveningEnabled(
      {required bool morning, required bool evening}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('morning_azkar', morning);
    await prefs.setBool('evening_azkar', evening);
    await scheduleMorningDhikr();
    await scheduleEveningDhikr();
  }

  /// Schedule Quran reading reminder
  Future<void> scheduleQuranReminder() async {
    try {
      final now = DateTime.now();
      final quranTime = DateTime(
        now.year,
        now.month,
        now.day + (now.hour >= 20 ? 1 : 0), // Next day if after 8 PM
        20, // 8 PM
        0,
      );

      await _notificationService.scheduleDhikrReminder(
        id: NotificationService.dhikrReminderBaseId + 52,
        title: '📖 ${tr('وردك من القرآن')}',
        dhikrText: tr('أكمل وردك اليومي من القرآن الكريم من حيث توقفت، واحتسب الأجر عند الله'),
        scheduledTime: quranTime,
        isRepeating: true,
        payload: NotificationPayload.mushafLastRead,
      );

      print('تم جدولة تذكير قراءة القرآن');
    } catch (e) {
      print('خطأ في جدولة تذكير القرآن: $e');
    }
  }

  /// Schedule Friday (Jummah) reminders
  Future<void> scheduleJummahReminders() async {
    try {
      final now = DateTime.now();
      final daysUntilFriday = (DateTime.friday - now.weekday) % 7;
      // The next 4 Fridays (today included), so the reminders keep coming
      // even if the app is not opened for a few weeks. Past times are skipped.
      for (int k = 0; k < 4; k++) {
        final d = DateTime(now.year, now.month, now.day)
            .add(Duration(days: daysUntilFriday + 7 * k));

        // Surah Al-Kahf: tapping opens the Mushaf at Al-Kahf.
        await _notificationService.scheduleDhikrReminder(
          id: NotificationService.dhikrReminderBaseId + 80 + k,
          title: '🕌 ${tr('سورة الكهف')}',
          dhikrText: tr(
              'يوم الجمعة المبارك: تذكر قراءة سورة الكهف والإكثار من الصلاة على النبي ﷺ'),
          scheduledTime: DateTime(d.year, d.month, d.day, 9, 0),
          isRepeating: false,
          payload: NotificationPayload.mushaf(18),
        );

        // Jumu'ah prayer: tapping opens prayer times.
        await _notificationService.scheduleDhikrReminder(
          id: NotificationService.dhikrReminderBaseId + 90 + k,
          dhikrText: tr('تذكير: صلاة الجمعة قريباً. استعد للذهاب إلى المسجد'),
          scheduledTime: DateTime(d.year, d.month, d.day, 11, 30),
          isRepeating: false,
          payload: NotificationPayload.prayer,
        );
      }
      // Old single-Friday ids from earlier versions.
      await _notificationService
          .cancelNotification(NotificationService.dhikrReminderBaseId + 60);
      await _notificationService
          .cancelNotification(NotificationService.dhikrReminderBaseId + 61);
    } catch (e) {
      debugPrint('Jumuah reminders: $e');
    }
  }

  /// Schedule Islamic occasions reminders
  Future<void> scheduleIslamicOccasions() async {
    try {
      // This would typically integrate with a Hijri calendar
      // For now, we'll schedule general Islamic reminders

      final now = DateTime.now();

      // Monthly reminder for fasting (Mondays and Thursdays)
      final nextMonday =
          now.add(Duration(days: (DateTime.monday - now.weekday) % 7));

      await _notificationService.scheduleDhikrReminder(
        id: NotificationService.dhikrReminderBaseId + 70,
        dhikrText: tr('تذكير: صيام يوم الاثنين سنة مستحبة. هل تريد أن تصوم اليوم؟'),
        scheduledTime:
            DateTime(nextMonday.year, nextMonday.month, nextMonday.day, 5, 0),
        isRepeating: false,
        payload: NotificationPayload.hijri,
      );

      print('تم جدولة تذكيرات المناسبات الإسلامية');
    } catch (e) {
      print('خطأ في جدولة المناسبات الإسلامية: $e');
    }
  }

  /// Where tapping a reminder with [text] should take the user.
  static String payloadFor(String text, [DateTime? at]) {
    if (text.contains('آية الكرسي')) return NotificationPayload.mushaf(2, 255);
    if (text.contains('الفاتحة')) return NotificationPayload.mushaf(1);
    if (text.contains('القرآن')) return NotificationPayload.mushafLastRead;
    if (text.contains('أذكار الصباح والمساء')) {
      final h = (at ?? DateTime.now()).hour;
      return h < 12 ? NotificationPayload.azkarMorning : NotificationPayload.azkarEvening;
    }
    return NotificationPayload.sebha;
  }

  /// Get random dhikr from the collection
  String _getRandomDhikr() {
    final allDhikr = [...dhikrList, ...islamicReminders];
    return allDhikr[_random.nextInt(allDhikr.length)];
  }

  /// Initialize all dhikr reminders
  Future<void> initializeAllDhikrReminders() async {
    try {
      await scheduleDhikrReminders();
      await scheduleMorningDhikr();
      await scheduleEveningDhikr();
      await scheduleQuranReminder();
      await scheduleJummahReminders();
      await scheduleIslamicOccasions();

      print('تم تهيئة جميع تذكيرات الذكر بنجاح');
    } catch (e) {
      print('خطأ في تهيئة تذكيرات الذكر: $e');
    }
  }

  /// Check if dhikr reminders are enabled
  Future<bool> areDhikrRemindersEnabled() async {
    final prefs = await _notificationService.loadNotificationPreferences();
    return prefs['dhikr_reminders'] ?? true;
  }

  /// Enable or disable dhikr reminders
  Future<void> setDhikrRemindersEnabled(bool enabled) async {
    final prefs = await _notificationService.loadNotificationPreferences();
    await _notificationService.saveNotificationPreferences(
      prayerNotifications: prefs['prayer_notifications'] ?? true,
      dhikrReminders: enabled,
      qiblaReminders: prefs['qibla_reminders'] ?? false,
      dhikrInterval: prefs['dhikr_interval'] ?? 2,
    );

    await scheduleDhikrReminders();
  }

  /// Update dhikr reminder interval
  Future<void> updateDhikrInterval(int hours) async {
    final prefs = await _notificationService.loadNotificationPreferences();
    await _notificationService.saveNotificationPreferences(
      prayerNotifications: prefs['prayer_notifications'] ?? true,
      dhikrReminders: prefs['dhikr_reminders'] ?? true,
      qiblaReminders: prefs['qibla_reminders'] ?? false,
      dhikrInterval: hours,
    );

    // Reschedule with new interval
    if (prefs['dhikr_reminders'] ?? true) {
      await scheduleDhikrReminders();
    }
  }

  /// Send immediate dhikr notification
  Future<void> sendImmediateDhikrNotification() async {
    final dhikrText = _getRandomDhikr();
    await _notificationService.showImmediateNotification(
      id: 999,
      title: 'ذكر الله',
      body: dhikrText,
      payload: payloadFor(dhikrText),
    );
  }
}
