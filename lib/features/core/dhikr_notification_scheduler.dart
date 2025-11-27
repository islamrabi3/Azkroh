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

      if (!dhikrEnabled) {
        print('إشعارات الذكر معطلة');
        return;
      }

      // Cancel existing dhikr notifications
      await _cancelAllDhikrNotifications();

      final now = DateTime.now();

      // Schedule dhikr reminders throughout the day
      for (int i = 1; i <= 12; i++) {
        // 12 reminders per day
        final scheduledTime = now.add(Duration(hours: i * intervalHours));
        final dhikrText = _getRandomDhikr();

        await _notificationService.scheduleDhikrReminder(
          id: NotificationService.dhikrReminderBaseId + i,
          dhikrText: dhikrText,
          scheduledTime: scheduledTime,
          isRepeating: true,
        );
      }

      print('تم جدولة تذكيرات الذكر بنجاح');
    } catch (e) {
      print('خطأ في جدولة تذكيرات الذكر: $e');
    }
  }

  /// Schedule morning dhikr reminder
  Future<void> scheduleMorningDhikr() async {
    try {
      final now = DateTime.now();
      final morningTime = DateTime(
        now.year,
        now.month,
        now.day + (now.hour >= 6 ? 1 : 0), // Next day if after 6 AM
        6, // 6 AM
        0,
      );

      final dhikrText = morningDhikr[_random.nextInt(morningDhikr.length)];

      await _notificationService.scheduleDhikrReminder(
        id: NotificationService.dhikrReminderBaseId + 50,
        dhikrText: 'أذكار الصباح: $dhikrText',
        scheduledTime: morningTime,
        isRepeating: true,
      );

      print('تم جدولة تذكير أذكار الصباح');
    } catch (e) {
      print('خطأ في جدولة أذكار الصباح: $e');
    }
  }

  /// Schedule evening dhikr reminder
  Future<void> scheduleEveningDhikr() async {
    try {
      final now = DateTime.now();
      final eveningTime = DateTime(
        now.year,
        now.month,
        now.day + (now.hour >= 18 ? 1 : 0), // Next day if after 6 PM
        18, // 6 PM
        0,
      );

      final dhikrText = eveningDhikr[_random.nextInt(eveningDhikr.length)];

      await _notificationService.scheduleDhikrReminder(
        id: NotificationService.dhikrReminderBaseId + 51,
        dhikrText: 'أذكار المساء: $dhikrText',
        scheduledTime: eveningTime,
        isRepeating: true,
      );

      print('تم جدولة تذكير أذكار المساء');
    } catch (e) {
      print('خطأ في جدولة أذكار المساء: $e');
    }
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
        dhikrText:
            'تذكير: اقرأ شيئاً من القرآن الكريم اليوم واحتسب الأجر عند الله',
        scheduledTime: quranTime,
        isRepeating: true,
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
      final nextFriday =
          now.add(Duration(days: daysUntilFriday == 0 ? 7 : daysUntilFriday));

      // Reminder to read Surah Al-Kahf
      final kahfReminderTime = DateTime(
        nextFriday.year,
        nextFriday.month,
        nextFriday.day,
        9, // 9 AM
        0,
      );

      await _notificationService.scheduleDhikrReminder(
        id: NotificationService.dhikrReminderBaseId + 60,
        dhikrText:
            'يوم الجمعة المبارك: تذكر قراءة سورة الكهف والإكثار من الصلاة على النبي ﷺ',
        scheduledTime: kahfReminderTime,
        isRepeating: false,
      );

      // Reminder for Jummah prayer
      final jummahReminderTime = DateTime(
        nextFriday.year,
        nextFriday.month,
        nextFriday.day,
        11, // 11 AM
        30,
      );

      await _notificationService.scheduleDhikrReminder(
        id: NotificationService.dhikrReminderBaseId + 61,
        dhikrText: 'تذكير: صلاة الجمعة قريباً. استعد للذهاب إلى المسجد',
        scheduledTime: jummahReminderTime,
        isRepeating: false,
      );

      print('تم جدولة تذكيرات يوم الجمعة');
    } catch (e) {
      print('خطأ في جدولة تذكيرات الجمعة: $e');
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
        dhikrText: 'تذكير: صيام يوم الاثنين سنة مستحبة. هل تريد أن تصوم اليوم؟',
        scheduledTime:
            DateTime(nextMonday.year, nextMonday.month, nextMonday.day, 5, 0),
        isRepeating: false,
      );

      print('تم جدولة تذكيرات المناسبات الإسلامية');
    } catch (e) {
      print('خطأ في جدولة المناسبات الإسلامية: $e');
    }
  }

  /// Get random dhikr from the collection
  String _getRandomDhikr() {
    final allDhikr = [...dhikrList, ...islamicReminders];
    return allDhikr[_random.nextInt(allDhikr.length)];
  }

  /// Cancel all dhikr notifications
  Future<void> _cancelAllDhikrNotifications() async {
    // Cancel regular dhikr reminders
    for (int i = 1; i <= 12; i++) {
      await _notificationService
          .cancelNotification(NotificationService.dhikrReminderBaseId + i);
    }

    // Cancel special dhikr notifications
    await _notificationService.cancelNotification(
        NotificationService.dhikrReminderBaseId + 50); // Morning
    await _notificationService.cancelNotification(
        NotificationService.dhikrReminderBaseId + 51); // Evening
    await _notificationService.cancelNotification(
        NotificationService.dhikrReminderBaseId + 52); // Quran
    await _notificationService.cancelNotification(
        NotificationService.dhikrReminderBaseId + 60); // Jummah Kahf
    await _notificationService.cancelNotification(
        NotificationService.dhikrReminderBaseId + 61); // Jummah Prayer
    await _notificationService.cancelNotification(
        NotificationService.dhikrReminderBaseId + 70); // Islamic occasions
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

    if (enabled) {
      await initializeAllDhikrReminders();
    } else {
      await _cancelAllDhikrNotifications();
    }
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
      payload: 'dhikr_reminder',
    );
  }
}
