import 'package:azkroh_app/features/core/notification_router.dart';
import 'package:azkroh_app/l10n/app_locale.dart';
import 'dart:io';
import 'package:azkroh_app/features/core/notification_background_handler.dart';
import 'package:azkroh_app/features/core/services/azan_audio_service.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // ---------------------------------------------------------------------------
  // Channels
  // On Android 8+ the sound belongs to the channel and can never be changed
  // after creation, so every sound has its own channel.
  // ---------------------------------------------------------------------------
  static const String _legacyChannelId = 'azkroh_notifications';

  static const String prayerSilentChannelId = 'prayer_plain_v2';
  static const String remindersChannelId = 'reminders_v2';

  /// One channel per Adhan voice and type (Fajr / other prayers).
  static String azanChannelId(String sound) => '${sound}_v3';

  // Notification IDs
  static const int fajrNotificationId = 1;
  static const int dhuhrNotificationId = 2;
  static const int asrNotificationId = 3;
  static const int maghribNotificationId = 4;
  static const int ishaNotificationId = 5;
  static const int dhikrReminderBaseId = 100;
  static const int qiblaReminderBaseId = 200;

  /// Multi-day prayer notifications live in [prayerBaseId, prayerBaseId+999].
  static const int prayerBaseId = 1000;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@drawable/ic_stat_media');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      // Permission is requested later from the home screen (not at launch).
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    if (Platform.isAndroid) {
      await _createNotificationChannels();
    }

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    _initialized = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  /// Create all Android notification channels.
  Future<void> _createNotificationChannels() async {
    final android = _android;
    if (android == null) return;

    // Old channel had the default sound baked in; remove it.
    try {
      await android.deleteNotificationChannel(_legacyChannelId);
    } catch (_) {}

    for (final old in ['azan_fajr_v2', 'azan_regular_v2']) {
      try {
        await android.deleteNotificationChannel(old);
      } catch (_) {}
    }
    for (final entry in AzanAudioService.azanReciters.entries) {
      for (final fajr in [true, false]) {
        final sound = AzanAudioService.soundName(entry.key, fajr);
        await android.createNotificationChannel(AndroidNotificationChannel(
          azanChannelId(sound),
          '${fajr ? 'أذان الفجر' : 'الأذان'} - ${entry.value['name']}',
          description: 'تشغيل الأذان كاملاً عند دخول وقت الصلاة',
          importance: Importance.max,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(sound),
          audioAttributesUsage: AudioAttributesUsage.alarm,
          enableVibration: true,
        ));
      }
    }

    await android.createNotificationChannel(const AndroidNotificationChannel(
      prayerSilentChannelId,
      'تنبيه الصلاة (بدون أذان)',
      description: 'تنبيه بصوت الإشعار العادي عند دخول وقت الصلاة',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    ));

    await android.createNotificationChannel(const AndroidNotificationChannel(
      remindersChannelId,
      'الأذكار والتذكيرات',
      description: 'تذكيرات الأذكار وقبل الصلاة',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    ));
  }

  void _onNotificationTapped(NotificationResponse notificationResponse) {
    if (notificationResponse.actionId == 'stop_azan') {
      stopAzan();
      return;
    }
    final String? payload = notificationResponse.payload;
    if (payload != null) {
      _handleNotificationNavigation(payload);
    }
  }

  /// Payload of the notification that launched the app, if any.
  Future<String?> launchPayload() async {
    try {
      final d = await _flutterLocalNotificationsPlugin
          .getNotificationAppLaunchDetails();
      if (d?.didNotificationLaunchApp ?? false) {
        final p = d!.notificationResponse?.payload;
        if (p != null && p.startsWith('prayer_') && Platform.isIOS) {
          _playAzanForPrayer(p.replaceFirst('prayer_', ''));
        }
        return p;
      }
    } catch (_) {}
    return null;
  }

  void _handleNotificationNavigation(String payload) {
    NotificationRouter.handle(payload);
    // On iOS a notification sound is limited to 30 seconds, so when the user
    // opens a prayer notification we continue with the full Azan in-app.
    if (payload.startsWith('prayer_') && Platform.isIOS) {
      final prayerName = payload.replaceFirst('prayer_', '');
      _playAzanForPrayer(prayerName);
    }
  }

  Future<void> _playAzanForPrayer(String prayerName) async {
    try {
      final azanService = AzanAudioService();
      final isEnabled = await azanService.isAzanEnabled();
      final isPrayerEnabled =
          await azanService.isAzanEnabledForPrayer(prayerName);

      if (isEnabled && isPrayerEnabled) {
        await azanService.playAzan(
          prayerName: prayerName,
          isFajr: prayerName == 'الفجر',
        );
      }
    } catch (e) {
      debugPrint('🔊 Error playing Azan: $e');
    }
  }

  /// Play Azan immediately (for testing or manual trigger)
  Future<void> playAzanNow(
      {String prayerName = 'الظهر', bool isFajr = false}) async {
    try {
      await AzanAudioService()
          .playAzan(prayerName: prayerName, isFajr: isFajr, force: true);
    } catch (e) {
      debugPrint('🔊 Error playing Azan: $e');
    }
  }

  /// Stop Azan if playing
  Future<void> stopAzan() async {
    try {
      // Android: the adhan is the notification sound -> cancel it.
      if (Platform.isAndroid) {
        final active = await _flutterLocalNotificationsPlugin
                .resolvePlatformSpecificImplementation<
                    AndroidFlutterLocalNotificationsPlugin>()
                ?.getActiveNotifications() ??
            const <ActiveNotification>[];
        for (final n in active) {
          if ((n.payload ?? '').startsWith('prayer_') && n.id != null) {
            await _flutterLocalNotificationsPlugin.cancel(n.id!);
          }
        }
      }
      await AzanAudioService().stopAzan();
    } catch (e) {
      debugPrint('🔊 Error stopping Azan: $e');
    }
  }

  /// Ask for notification (and exact alarm) permission. Call once the UI is
  /// visible so the system dialog doesn't appear over a blank screen.
  Future<bool> requestPermissions() => _requestPermissions();

  Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      final android = _android;
      final bool? granted = await android?.requestNotificationsPermission();
      await android?.requestExactAlarmsPermission();
      return granted ?? false;
    } else if (Platform.isIOS) {
      final bool? result = await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return result ?? false;
    }
    return false;
  }

  /// Notification details for an Adhan notification.
  NotificationDetails _prayerDetails({
    required String title,
    required String body,
    required bool withAzan,
    required bool isFajr,
    String reciter = 'mishary',
  }) {
    final sound = AzanAudioService.soundName(reciter, isFajr);
    final String channelId =
        withAzan ? azanChannelId(sound) : prayerSilentChannelId;
    final String channelName = withAzan
        ? '${isFajr ? 'أذان الفجر' : 'الأذان'} - ${AzanAudioService.azanReciters[reciter]?['name'] ?? ''}'
        : 'تنبيه الصلاة (بدون أذان)';

    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        importance: withAzan ? Importance.max : Importance.high,
        priority: Priority.max,
        icon: '@drawable/ic_stat_media',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
        color: const Color(0xFF0F5C4A),
        playSound: true,
        sound: withAzan ? RawResourceAndroidNotificationSound(sound) : null,
        audioAttributesUsage: withAzan
            ? AudioAttributesUsage.alarm
            : AudioAttributesUsage.notification,
        enableVibration: true,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
        ),
        ticker: title,
        autoCancel: true,
        // Wake the locked screen with the full-screen adhan page.
        fullScreenIntent: withAzan,
        actions: withAzan
            ? <AndroidNotificationAction>[
                AndroidNotificationAction(
                  'stop_azan',
                  tr('إيقاف الأذان'),
                  cancelNotification: true,
                  showsUserInterface: false,
                ),
              ]
            : null,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        presentBanner: true,
        presentList: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
        sound: withAzan ? '$sound.caf' : null,
      ),
    );
  }

  /// Schedule a single (non repeating) prayer notification.
  ///
  /// Prayer times change every day, so they must never repeat daily; the
  /// scheduler books several days ahead instead.
  Future<void> schedulePrayerNotification({
    required int id,
    required String prayerName,
    required DateTime scheduledTime,
    String? customMessage,
    bool playAzan = true,
    bool repeatDaily = false,
    String? title,
  }) async {
    final String notifTitle =
        title ?? '${tr('حان الآن وقت صلاة')} ${tr(prayerName)}';
    final String body = customMessage ?? notifTitle;

    final tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);
    if (tzScheduledTime.isBefore(tz.TZDateTime.now(tz.local))) {
      return;
    }

    bool withAzan = playAzan;
    final azan = AzanAudioService();
    final reciter = await azan.getSelectedReciter();
    if (playAzan) {
      withAzan = await azan.isAzanEnabled() &&
          await azan.isAzanEnabledForPrayer(prayerName);
    }

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      notifTitle,
      body,
      tzScheduledTime,
      _prayerDetails(
        title: notifTitle,
        body: body,
        withAzan: withAzan,
        isFajr: prayerName == 'الفجر',
        reciter: reciter,
      ),
      payload: 'prayer_$prayerName',
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: repeatDaily ? DateTimeComponents.time : null,
    );
  }

  /// Generic reminder (dhikr / pre-prayer). The full text is always shown.
  NotificationDetails _reminderDetails(String title, String body) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        remindersChannelId,
        'الأذكار والتذكيرات',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@drawable/ic_stat_media',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
        color: const Color(0xFF0F5C4A),
        enableVibration: true,
        playSound: true,
        autoCancel: true,
        visibility: NotificationVisibility.public,
        // Shows the whole text when the notification is expanded.
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
        ),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        presentBanner: true,
        presentList: true,
      ),
    );
  }

  /// Schedule dhikr reminder notification (full text, never truncated).
  Future<void> scheduleDhikrReminder({
    required int id,
    required String dhikrText,
    required DateTime scheduledTime,
    bool isRepeating = true,
    String? title,
    String payload = 'dhikr_reminder',
  }) async {
    final tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);
    if (tzScheduledTime.isBefore(tz.TZDateTime.now(tz.local))) {
      return;
    }

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title ?? tr('تذكير بالذكر'),
      dhikrText,
      tzScheduledTime,
      _reminderDetails(title ?? tr('تذكير بالذكر'), dhikrText),
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: isRepeating ? DateTimeComponents.time : null,
    );
  }

  /// Schedule Qibla direction reminder
  Future<void> scheduleQiblaReminder({
    required DateTime scheduledTime,
  }) async {
    const String title = 'تذكير بالقبلة';
    const String body = 'تذكر أن تتحقق من اتجاه القبلة قبل الصلاة';

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      qiblaReminderBaseId,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      _reminderDetails(title, body),
      payload: 'qibla_reminder',
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
  }

  /// Check if exact alarms are allowed (Android 12+)
  Future<bool> areExactAlarmsAllowed() async {
    if (Platform.isAndroid) {
      return await _android?.canScheduleExactNotifications() ?? false;
    }
    return true;
  }

  Future<void> logPendingNotifications() async {
    try {
      final pending = await getPendingNotifications();
      debugPrint('📱 Total pending notifications: ${pending.length}');
    } catch (e) {
      debugPrint('❌ Error logging pending notifications: $e');
    }
  }

  /// Show immediate notification
  Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await _flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      _reminderDetails(title, body),
      payload: payload,
    );
  }

  /// Show an Adhan notification right now (used by the test button).
  Future<void> showTestAzanNotification({bool isFajr = false}) async {
    final name = isFajr ? 'الفجر' : 'الظهر';
    final reciter = await AzanAudioService().getSelectedReciter();
    const body = 'هذا اختبار لصوت الأذان في الإشعارات';
    await _flutterLocalNotificationsPlugin.show(
      9998,
      'اختبار أذان $name',
      body,
      _prayerDetails(
        title: 'اختبار أذان $name',
        body: body,
        withAzan: true,
        isFajr: isFajr,
        reciter: reciter,
      ),
      payload: 'prayer_test',
    );
  }

  Future<bool> areNotificationsEnabled() async {
    if (Platform.isAndroid) {
      return await _android?.areNotificationsEnabled() ?? false;
    } else if (Platform.isIOS) {
      final IOSFlutterLocalNotificationsPlugin? ios =
          _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      final bool? result =
          await ios?.requestPermissions(alert: true, badge: true, sound: true);
      return result ?? false;
    }
    return false;
  }

  Future<void> saveNotificationPreferences({
    required bool prayerNotifications,
    required bool dhikrReminders,
    required bool qiblaReminders,
    required int dhikrInterval, // in hours
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('prayer_notifications', prayerNotifications);
    await prefs.setBool('dhikr_reminders', dhikrReminders);
    await prefs.setBool('qibla_reminders', qiblaReminders);
    await prefs.setInt('dhikr_interval', dhikrInterval);
  }

  Future<Map<String, dynamic>> loadNotificationPreferences() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return {
      'prayer_notifications': prefs.getBool('prayer_notifications') ?? true,
      'dhikr_reminders': prefs.getBool('dhikr_reminders') ?? true,
      'qibla_reminders': prefs.getBool('qibla_reminders') ?? false,
      'dhikr_interval': prefs.getInt('dhikr_interval') ?? 2,
      'morning_azkar': prefs.getBool('morning_azkar') ?? true,
      'evening_azkar': prefs.getBool('evening_azkar') ?? true,
    };
  }
}
