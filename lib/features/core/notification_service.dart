import 'dart:io';
import 'package:azkroh_app/features/core/notification_background_handler.dart';
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

    // Create notification channel for Android (required for Android 8.0+)
    if (Platform.isAndroid) {
      await _createNotificationChannel();
    }

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Request permissions
    await _requestPermissions();
  }

  /// Create notification channel for Android
  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidImplementation?.createNotificationChannel(channel);
    debugPrint('📱 Notification channel created for Android');
  }

  /// Handle notification tap (foreground)
  void _onNotificationTapped(NotificationResponse notificationResponse) {
    final String? payload = notificationResponse.payload;
    if (payload != null) {
      debugPrint('📱 Notification tapped: $payload');
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
      await azanService.initialize();
      final isEnabled = await azanService.isAzanEnabled();
      final isPrayerEnabled =
          await azanService.isAzanEnabledForPrayer(prayerName);

      if (isEnabled && isPrayerEnabled) {
        await azanService.playAzan(
          prayerName: prayerName,
          isFajr: prayerName == 'الفجر',
        );
        debugPrint('🔊 Azan played for $prayerName');
      }
    } catch (e) {
      debugPrint('🔊 Error playing Azan: $e');
    }
  }

  /// Play Azan immediately (for testing or manual trigger)
  Future<void> playAzanNow(
      {String prayerName = 'الظهر', bool isFajr = false}) async {
    try {
      final azanService = AzanAudioService();
      await azanService.initialize();
      await azanService.playAzan(prayerName: prayerName, isFajr: isFajr);
    } catch (e) {
      debugPrint('🔊 Error playing Azan: $e');
    }
  }

  /// Stop Azan if playing
  Future<void> stopAzan() async {
    try {
      final azanService = AzanAudioService();
      await azanService.stopAzan();
    } catch (e) {
      debugPrint('🔊 Error stopping Azan: $e');
    }
  }

  /// Request notification permissions
  Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>();

      // Create channel first
      await _createNotificationChannel();

      final bool? grantedNotificationPermission =
          await androidImplementation?.requestNotificationsPermission();

      // Request exact alarms permission for scheduled notifications
      await androidImplementation?.requestExactAlarmsPermission();

      debugPrint(
          '📱 Android notification permission: $grantedNotificationPermission');
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
      debugPrint('📱 iOS notification permission: $result');
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
    bool repeatDaily = true,
  }) async {
    final String title = 'وقت صلاة $prayerName';
    final String body =
        customMessage ?? 'حان الآن وقت صلاة $prayerName. بارك الله فيك';

    // Ensure channel exists for Android
    if (Platform.isAndroid) {
      await _createNotificationChannel();

      // Check and request exact alarms permission on Android
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>();

      // Request exact alarms permission if not granted
      await androidImplementation?.requestExactAlarmsPermission();
    }

    try {
      // Convert to TZDateTime with proper timezone
      final tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);

      // Ensure the scheduled time is in the future
      if (tzScheduledTime.isBefore(tz.TZDateTime.now(tz.local))) {
        debugPrint(
            '⚠️ Scheduled time is in the past, skipping: $scheduledTime');
        return;
      }

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzScheduledTime,
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
            sound: const RawResourceAndroidNotificationSound('adhan'),
            ongoing: false,
            autoCancel: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.timeSensitive,
            sound: 'adhan.wav',
          ),
        ),
        payload: 'prayer_$prayerName',
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: repeatDaily ? DateTimeComponents.time : null,
      );

      debugPrint(
          '✅ Scheduled prayer notification for $prayerName at $scheduledTime (repeatDaily: $repeatDaily)');

      // For iOS, schedule Azan to play when notification arrives
      if (playAzan && Platform.isIOS) {
        _scheduleAzanForIOS(prayerName, scheduledTime);
      }
    } catch (e) {
      debugPrint('❌ Error scheduling notification: $e');
      debugPrint('   Prayer: $prayerName, Time: $scheduledTime');
      rethrow;
    }
  }

  /// Schedule Azan for iOS (plays automatically when notification arrives)
  void _scheduleAzanForIOS(String prayerName, DateTime scheduledTime) async {
    try {
      final azanService = AzanAudioService();
      final isEnabled = await azanService.isAzanEnabled();
      final isPrayerEnabled =
          await azanService.isAzanEnabledForPrayer(prayerName);

      if (!isEnabled || !isPrayerEnabled) {
        debugPrint('🔊 Azan is disabled for $prayerName');
        return;
      }

      // On iOS, the Azan will play automatically when notification is received
      // via the background handler
      debugPrint('🔊 Azan will play automatically for $prayerName on iOS');
    } catch (e) {
      debugPrint('🔊 Error scheduling Azan for iOS: $e');
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

    // Ensure channel exists for Android
    if (Platform.isAndroid) {
      await _createNotificationChannel();

      // Check and request exact alarms permission on Android
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>();

      // Request exact alarms permission if not granted
      await androidImplementation?.requestExactAlarmsPermission();
    }

    try {
      // Convert to TZDateTime with proper timezone
      final tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);

      // Ensure the scheduled time is in the future
      if (tzScheduledTime.isBefore(tz.TZDateTime.now(tz.local))) {
        debugPrint(
            '⚠️ Scheduled time is in the past, skipping: $scheduledTime');
        return;
      }

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzScheduledTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            icon: '@mipmap/ic_launcher',
            enableVibration: true,
            playSound: true,
            autoCancel: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: 'dhikr_reminder',
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: isRepeating ? DateTimeComponents.time : null,
      );

      debugPrint(
          '✅ Scheduled dhikr reminder at $scheduledTime (repeating: $isRepeating)');
    } catch (e) {
      debugPrint('❌ Error scheduling dhikr reminder: $e');
      debugPrint(
          '   Time: $scheduledTime, Text: ${body.substring(0, body.length > 30 ? 30 : body.length)}...');
      rethrow;
    }
  }

  /// Schedule Qibla direction reminder
  Future<void> scheduleQiblaReminder({
    required DateTime scheduledTime,
  }) async {
    const String title = 'تذكير بالقبلة';
    const String body = 'تذكر أن تتحقق من اتجاه القبلة قبل الصلاة';

    // Ensure channel exists for Android
    if (Platform.isAndroid) {
      await _createNotificationChannel();
    }

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      qiblaReminderBaseId,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
          enableVibration: true,
        ),
        iOS: const DarwinNotificationDetails(
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

  /// Check if exact alarms are allowed (Android 12+)
  Future<bool> areExactAlarmsAllowed() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>();

      return await androidImplementation?.areNotificationsEnabled() ?? false;
    }
    return true; // iOS doesn't need this check
  }

  /// Log all pending notifications for debugging
  Future<void> logPendingNotifications() async {
    try {
      final pending = await getPendingNotifications();
      debugPrint('📱 Total pending notifications: ${pending.length}');
      for (final notification in pending) {
        debugPrint(
            '   - ID: ${notification.id}, Title: ${notification.title}, Body: ${notification.body}');
      }
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
    debugPrint('📱 Attempting to show notification: $title');

    try {
      // Ensure channel exists for Android
      if (Platform.isAndroid) {
        await _createNotificationChannel();
      }

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
          ),
          iOS: const DarwinNotificationDetails(
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
