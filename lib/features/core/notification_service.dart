import 'dart:io';
import 'package:azkroh_app/features/core/services/azan_audio_service.dart';
import 'package:flutter/foundation.dart';
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

  static const String _channelId = 'azkroh_notifications';
  static const String _channelName = 'Azkroh Notifications';
  static const String _channelDescription =
      'Notifications for prayer times and dhikr reminders';

  // Notification IDs
  static const int fajrNotificationId = 1;
  static const int dhuhrNotificationId = 2;
  static const int asrNotificationId = 3;
  static const int maghribNotificationId = 4;
  static const int ishaNotificationId = 5;
  static const int dhikrReminderBaseId = 100;
  static const int qiblaReminderBaseId = 200;

  /// Initialize the notification service
  Future<void> initialize() async {
    // Initialize timezone
    tz.initializeTimeZones();

    // Android initialization settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions
    await _requestPermissions();
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse notificationResponse) {
    final String? payload = notificationResponse.payload;
    if (payload != null) {
      debugPrint('Notification payload: $payload');
      // Handle navigation based on payload
      _handleNotificationNavigation(payload);
    }
  }

  /// Handle navigation based on notification payload
  void _handleNotificationNavigation(String payload) {
    // Handle Azan playback for prayer notifications
    if (payload.startsWith('prayer_')) {
      final prayerName = payload.replaceFirst('prayer_', '');
      _playAzanForPrayer(prayerName);
    }

    // This can be extended to navigate to specific screens
    switch (payload) {
      case 'prayer_time':
        // Navigate to prayer times screen
        break;
      case 'dhikr_reminder':
        // Navigate to dhikr screen
        break;
      case 'qibla_reminder':
        // Navigate to qibla screen
        break;
      default:
        break;
    }
  }

  /// Play Azan for a specific prayer
  Future<void> _playAzanForPrayer(String prayerName) async {
    try {
      final azanService = AzanAudioService();
      final isEnabled = await azanService.isAzanEnabledForPrayer(prayerName);
      if (isEnabled) {
        await azanService.playAzan(
          prayerName: prayerName,
          isFajr: prayerName == 'الفجر',
        );
      }
    } catch (e) {
      debugPrint('Error playing Azan: $e');
    }
  }

  /// Play Azan immediately (for testing or manual trigger)
  Future<void> playAzanNow(
      {String prayerName = 'الظهر', bool isFajr = false}) async {
    try {
      final azanService = AzanAudioService();
      await azanService.playAzan(prayerName: prayerName, isFajr: isFajr);
    } catch (e) {
      debugPrint('Error playing Azan: $e');
    }
  }

  /// Stop Azan if playing
  Future<void> stopAzan() async {
    try {
      final azanService = AzanAudioService();
      await azanService.stopAzan();
    } catch (e) {
      debugPrint('Error stopping Azan: $e');
    }
  }

  /// Request notification permissions
  Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>();

      final bool? grantedNotificationPermission =
          await androidImplementation?.requestNotificationsPermission();

      // Request exact alarms permission for scheduled notifications
      await androidImplementation?.requestExactAlarmsPermission();

      return grantedNotificationPermission ?? false;
    } else if (Platform.isIOS) {
      final bool? result = await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      return result ?? false;
    }
    return false;
  }

  /// Schedule prayer time notification
  Future<void> schedulePrayerNotification({
    required int id,
    required String prayerName,
    required DateTime scheduledTime,
    String? customMessage,
    bool playAzan = true,
  }) async {
    final String title = 'وقت صلاة $prayerName';
    final String body =
        customMessage ?? 'حان الآن وقت صلاة $prayerName. بارك الله فيك';

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      payload: 'prayer_$prayerName', // Include prayer name for Azan playback
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    // Schedule Azan playback if enabled
    if (playAzan) {
      _scheduleAzanPlayback(prayerName, scheduledTime);
    }
  }

  /// Schedule Azan audio playback
  Future<void> _scheduleAzanPlayback(
      String prayerName, DateTime scheduledTime) async {
    try {
      final azanService = AzanAudioService();
      final isEnabled = await azanService.isAzanEnabled();
      final isPrayerEnabled =
          await azanService.isAzanEnabledForPrayer(prayerName);

      if (!isEnabled || !isPrayerEnabled) {
        debugPrint('🔊 Azan is disabled for $prayerName');
        return;
      }

      // Calculate delay until prayer time
      final now = DateTime.now();
      final delay = scheduledTime.difference(now);

      if (delay.isNegative) {
        debugPrint('🔊 Prayer time has already passed');
        return;
      }

      debugPrint(
          '🔊 Scheduled Azan for $prayerName in ${delay.inMinutes} minutes');

      // Note: For true background scheduling, you would need to use
      // WorkManager (Android) or BGTaskScheduler (iOS)
      // For now, the Azan will play when the notification is tapped
    } catch (e) {
      debugPrint('🔊 Error scheduling Azan: $e');
    }
  }

  /// Schedule dhikr reminder notification
  Future<void> scheduleDhikrReminder({
    required int id,
    required String dhikrText,
    required DateTime scheduledTime,
    bool isRepeating = true,
  }) async {
    const String title = 'تذكير بالذكر';
    final String body =
        dhikrText.length > 50 ? '${dhikrText.substring(0, 50)}...' : dhikrText;

    if (isRepeating) {
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            icon: '@mipmap/ic_launcher',
            enableVibration: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: 'dhikr_reminder',
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } else {
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            icon: '@mipmap/ic_launcher',
            enableVibration: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: 'dhikr_reminder',
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
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
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: 'qibla_reminder',
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  /// Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
  }

  /// Show immediate notification
  Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    debugPrint('📱 Attempting to show notification: $title');

    try {
      // Request permission again just to be safe on iOS
      if (Platform.isIOS) {
        final IOSFlutterLocalNotificationsPlugin? iosPlugin =
            _flutterLocalNotificationsPlugin
                .resolvePlatformSpecificImplementation<
                    IOSFlutterLocalNotificationsPlugin>();

        final bool? granted = await iosPlugin?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        debugPrint('📱 iOS permission granted: $granted');
      }

      await _flutterLocalNotificationsPlugin.show(
        id,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.active,
          ),
        ),
        payload: payload,
      );
      debugPrint('📱 Notification sent successfully!');
    } catch (e) {
      debugPrint('📱 Error sending notification: $e');
      rethrow;
    }
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>();
      return await androidImplementation?.areNotificationsEnabled() ?? false;
    } else if (Platform.isIOS) {
      final IOSFlutterLocalNotificationsPlugin? iosImplementation =
          _flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>();
      final bool? result = await iosImplementation?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return result ?? false;
    }
    return false;
  }

  /// Save notification preferences
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

  /// Load notification preferences
  Future<Map<String, dynamic>> loadNotificationPreferences() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return {
      'prayer_notifications': prefs.getBool('prayer_notifications') ?? true,
      'dhikr_reminders': prefs.getBool('dhikr_reminders') ?? true,
      'qibla_reminders': prefs.getBool('qibla_reminders') ?? false,
      'dhikr_interval': prefs.getInt('dhikr_interval') ?? 2, // Default 2 hours
    };
  }
}
