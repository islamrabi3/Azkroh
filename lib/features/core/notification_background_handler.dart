import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Background notification action handler (must be a top-level function).
///
/// The Adhan itself is played natively by the notification channel sound
/// (Android) / bundled .caf (iOS), so nothing heavy is done here.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {}
