import 'dart:io';

import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App rating prompt + in-app updates.
class AppStoreService {
  static final AppStoreService _instance = AppStoreService._internal();
  factory AppStoreService() => _instance;
  AppStoreService._internal();

  /// Numeric App Store id (from App Store Connect → App Information → Apple ID).
  /// Needed only to open the store page from "قيّم التطبيق" on iOS.
  static const String appStoreId = '6755852829';

  final InAppReview _review = InAppReview.instance;

  // ---------------------------------------------------------------------------
  // Review
  // ---------------------------------------------------------------------------

  /// Call once per app start. Shows the native review sheet after the 5th
  /// launch and 3+ days of use, then at most every 60 days. The OS itself may
  /// decide not to show it (Apple/Google quotas).
  Future<void> registerLaunchAndMaybeAskReview() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final launches = (prefs.getInt('app_launches') ?? 0) + 1;
      await prefs.setInt('app_launches', launches);
      final now = DateTime.now().millisecondsSinceEpoch;
      final first = prefs.getInt('first_launch_at') ?? now;
      await prefs.setInt('first_launch_at', first);
      final lastAsk = prefs.getInt('review_asked_at') ?? 0;

      const day = 24 * 60 * 60 * 1000;
      final usedDays = (now - first) / day;
      final sinceAsk = (now - lastAsk) / day;
      if (launches >= 3 && usedDays >= 1 && sinceAsk >= 30) {
        if (await _review.isAvailable()) {
          await prefs.setInt('review_asked_at', now);
          await Future.delayed(const Duration(seconds: 3));
          await _review.requestReview();
        }
      }
    } catch (e) {
      debugPrint('review: $e');
    }
  }

  /// Whether the home "rate the app" card should show: from the 2nd launch,
  /// until the user rates, reappearing a few days after "later".
  final ValueNotifier<bool> showRatingCard = ValueNotifier(false);

  Future<void> refreshRatingCard() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rated = prefs.getBool('user_rated') ?? false;
      final launches = prefs.getInt('app_launches') ?? 0;
      final snooze = prefs.getInt('rating_snooze_until') ?? 0;
      showRatingCard.value = !rated &&
          launches >= 2 &&
          DateTime.now().millisecondsSinceEpoch >= snooze;
    } catch (_) {}
  }

  /// "Later": hide the card for 3 days.
  Future<void> snoozeRatingCard() async {
    showRatingCard.value = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        'rating_snooze_until',
        DateTime.now()
            .add(const Duration(days: 3))
            .millisecondsSinceEpoch);
  }

  /// "Rate now" from the card: open the store and stop asking.
  Future<void> rateFromCard() async {
    showRatingCard.value = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('user_rated', true);
    await openRating();
  }

  /// "قيّم التطبيق" from settings.
  Future<void> openRating() async {
    try {
      if (Platform.isIOS && appStoreId.isEmpty) {
        if (await _review.isAvailable()) await _review.requestReview();
        return;
      }
      await _review.openStoreListing(appStoreId: appStoreId);
    } catch (e) {
      debugPrint('rating: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Updates (Android: Google Play in-app updates; iOS: see UpgradeAlert)
  // ---------------------------------------------------------------------------
  Future<void> checkAndroidUpdate(BuildContext context) async {
    if (!Platform.isAndroid) return;
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        return;
      }
      final stale = info.clientVersionStalenessDays ?? 0;
      // Important / old updates: full-screen Google Play update flow.
      if (info.immediateUpdateAllowed &&
          (info.updatePriority >= 4 || stale >= 14)) {
        await InAppUpdate.performImmediateUpdate();
        return;
      }
      if (info.flexibleUpdateAllowed) {
        await InAppUpdate.startFlexibleUpdate();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          duration: const Duration(seconds: 30),
          content: const Text('تم تحميل تحديث جديد للتطبيق'),
          action: SnackBarAction(
            label: 'تثبيت الآن',
            onPressed: InAppUpdate.completeFlexibleUpdate,
          ),
        ));
      }
    } catch (e) {
      // Not installed from Google Play (debug / sideloaded) → ignore.
      debugPrint('in-app update: $e');
    }
  }
}
