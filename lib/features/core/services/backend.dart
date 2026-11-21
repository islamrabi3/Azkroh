import 'package:supabase_flutter/supabase_flutter.dart';

/// Azkroh backend (Supabase). The publishable key is safe to ship in the app:
/// row level security only lets the app read approved / published content.
class Backend {
  Backend._();

  static const url = 'https://ubdcbknyloaupoozfhnx.supabase.co';
  static const publishableKey =
      'sb_publishable_8uoh_b0RHwQrVZlFbuRYKA_s3-Wdk80';

  static bool _ready = false;
  static bool get isReady => _ready;

  static Future<void> init() async {
    if (_ready) return;
    try {
      await Supabase.initialize(url: url, publishableKey: publishableKey);
      _ready = true;
    } catch (_) {
      // Offline-first app: everything else keeps working without it.
    }
  }

  static SupabaseClient get client => Supabase.instance.client;
}
