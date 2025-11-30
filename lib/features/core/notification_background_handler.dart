import 'package:azkroh_app/features/core/services/azan_audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Background notification handler (must be top-level function)
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  final String? payload = notificationResponse.payload;
  if (payload != null && payload.startsWith('prayer_')) {
    final prayerName = payload.replaceFirst('prayer_', '');
    _playAzanInBackground(prayerName);
  }
}

// Play Azan in background (must be top-level function)
@pragma('vm:entry-point')
Future<void> _playAzanInBackground(String prayerName) async {
  try {
    final azanService = AzanAudioService();
    await azanService.initialize();
    final isEnabled = await azanService.isAzanEnabled();
    final isPrayerEnabled = await azanService.isAzanEnabledForPrayer(prayerName);
    
    if (isEnabled && isPrayerEnabled) {
      await azanService.playAzan(
        prayerName: prayerName,
        isFajr: prayerName == 'الفجر',
      );
      debugPrint('🔊 Azan played in background for $prayerName');
    }
  } catch (e) {
    debugPrint('🔊 Error playing Azan in background: $e');
  }
}

