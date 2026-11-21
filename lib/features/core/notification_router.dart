import 'package:azkroh_app/features/presentation/screens/adhan_screen.dart';
import 'package:azkroh_app/features/presentation/cubit/cubit.dart';
import 'package:azkroh_app/features/presentation/screens/all_screen/enhanced_hijri_screen.dart';
import 'package:azkroh_app/features/presentation/screens/all_screen/paryer_time_screen.dart';
import 'package:azkroh_app/features/presentation/screens/all_screen/qibla_screen.dart';
import 'package:azkroh_app/features/presentation/screens/all_screen/sebha.dart';
import 'package:azkroh_app/features/presentation/screens/enhanced_azkar_screen.dart';
import 'package:azkroh_app/features/presentation/screens/hadith/hadith_screen.dart';
import 'package:azkroh_app/features/presentation/screens/quran_screen_locally/mushaf_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Notification payloads understood by [NotificationRouter].
class NotificationPayload {
  static const azkarMorning = 'azkar_morning';
  static const azkarEvening = 'azkar_evening';
  static const sebha = 'sebha';
  static const mushafLastRead = 'mushaf_last';
  static const prayer = 'prayer';
  static const qibla = 'qibla_reminder';
  static const hijri = 'hijri';
  static const hadith = 'hadith';

  /// Opens the Mushaf at [surah]:[verse], e.g. `mushaf:18:1` for Al-Kahf.
  static String mushaf(int surah, [int verse = 1]) => 'mushaf:$surah:$verse';
}

/// Opens the screen a tapped notification is about. Works when the app is
/// in the foreground, in the background, or launched by the tap (the payload
/// is kept until the home screen is ready).
class NotificationRouter {
  NotificationRouter._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static String? _pending;
  static bool _homeReady = false;

  /// Called for every tapped notification.
  static void handle(String? payload) {
    if (payload == null || payload.isEmpty) return;
    if (_homeReady && navigatorKey.currentState != null) {
      _open(payload);
    } else {
      _pending = payload;
    }
  }

  /// Called by the home screen once it is shown.
  static void homeReady() {
    _homeReady = true;
    final p = _pending;
    _pending = null;
    if (p != null) {
      Future.delayed(const Duration(milliseconds: 350), () => _open(p));
    }
  }

  static void _push(Widget page) {
    navigatorKey.currentState
        ?.push(MaterialPageRoute(builder: (_) => page));
  }

  static void _open(String payload) {
    final nav = navigatorKey.currentState;
    final ctx = navigatorKey.currentContext;
    if (nav == null || ctx == null) return;

    if (payload.startsWith('mushaf:')) {
      final parts = payload.split(':');
      final s = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 1;
      final v = int.tryParse(parts.length > 2 ? parts[2] : '') ?? 1;
      nav.push(MushafScreen.routeTo(s.clamp(1, 114), verse: v < 1 ? 1 : v));
      return;
    }

    switch (payload) {
      case NotificationPayload.azkarMorning:
        _openAzkar(ctx, 'أذكار الصباح', 'morning');
        return;
      case NotificationPayload.azkarEvening:
        _openAzkar(ctx, 'أذكار المساء', 'evening');
        return;
      case NotificationPayload.mushafLastRead:
      case 'quran_reminder':
        MushafScreen.openLastRead(ctx);
        return;
      case NotificationPayload.sebha:
      case 'dhikr_reminder':
        _push(const Sebha());
        return;
      case NotificationPayload.qibla:
        _push(QibalScreen());
        return;
      case NotificationPayload.hijri:
        _push(EnhancedHijriScreen());
        return;
      case NotificationPayload.hadith:
        _push(HadithScreen());
        return;
    }

    // The adhan itself: full-screen adhan page (stop / mute).
    if (payload.startsWith('prayer_') && payload != 'prayer_reminder') {
      final name = payload.substring('prayer_'.length);
      _push(AdhanScreen(prayerName: name == 'test' ? '' : name));
      return;
    }

    // Pre-prayer reminder, refresh reminder, Jumu'ah.
    if (payload.startsWith('prayer') || payload == 'refresh') {
      _push(PrayerScreen());
    }
  }

  static void _openAzkar(BuildContext ctx, String title, String type) {
    try {
      final cubit = BlocProvider.of<AppCubit>(ctx);
      final entry = cubit.azkarMap.firstWhere(
          (e) => (e['title'] as String).trim() == title);
      _push(EnhancedAzkarScreen(
        pageTitle: title,
        listOfDoaaModel: entry['zekr_contetnt'],
        azkarType: type,
      ));
    } catch (e) {
      debugPrint('azkar route failed: $e');
    }
  }
}
