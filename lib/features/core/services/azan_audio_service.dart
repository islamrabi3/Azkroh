import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Plays the Azan inside the app (preview / iOS full Azan after the 30s
/// notification sound). The audio is bundled with the app, so it works
/// offline. Notification sounds use the same recordings natively
/// (android/app/src/main/res/raw and ios/Runner/*.caf).
class AzanAudioService {
  static final AzanAudioService _instance = AzanAudioService._internal();
  factory AzanAudioService() => _instance;
  AzanAudioService._internal();

  AudioPlayer? _audioPlayer;
  bool _isInitialized = false;


  /// Available Adhan voices. All are bundled (offline) and are also used as
  /// the native notification sound (res/raw on Android, .caf on iOS).
  /// `sound` is the resource base name; `_fajr` / `_regular` are appended.
  static const Map<String, Map<String, String>> azanReciters = {
    'mishary': {
      'name': 'مشاري راشد العفاسي',
      'desc': 'صوت ندي هادئ',
      'sound': 'azan',
    },
    'makkah': {
      'name': 'الحرم المكي',
      'desc': 'أذان المسجد الحرام',
      'sound': 'azan_makkah',
    },
    'madinah': {
      'name': 'المسجد النبوي',
      'desc': 'أذان المسجد النبوي الشريف',
      'sound': 'azan_madinah',
    },
  };

  /// Resource base name for [reciter] + prayer type, e.g. azan_makkah_fajr.
  static String soundName(String reciter, bool isFajr) {
    final base = azanReciters[reciter]?['sound'] ?? 'azan';
    return '${base}_${isFajr ? 'fajr' : 'regular'}';
  }

  static String assetFor(String reciter, bool isFajr) =>
      'assets/audio/${soundName(reciter, isFajr)}.mp3';

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _audioPlayer = AudioPlayer();

      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.duckOthers,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.alarm,
        ),
        androidAudioFocusGainType:
            AndroidAudioFocusGainType.gainTransientMayDuck,
        androidWillPauseWhenDucked: false,
      ));

      _isInitialized = true;
    } catch (e) {
      debugPrint('🔊 Error initializing AzanAudioService: $e');
    }
  }

  /// Play Azan for a specific prayer. [force] ignores the enabled setting
  /// (used by the "test" button).
  Future<void> playAzan({
    required String prayerName,
    bool isFajr = false,
    bool force = false,
    String? reciter,
  }) async {
    try {
      await initialize();
      final player = _audioPlayer;
      if (player == null) return;

      if (!force && !await isAzanEnabled()) return;

      final fajr = isFajr || prayerName == 'الفجر';
      final asset = assetFor(reciter ?? await getSelectedReciter(), fajr);

      await player.stop();
      await player.setAsset(asset);
      await player.setVolume(await getAzanVolume());
      await player.play();
    } catch (e) {
      debugPrint('🔊 Error playing Azan: $e');
    }
  }

  Future<void> stopAzan() async {
    try {
      await _audioPlayer?.stop();
    } catch (e) {
      debugPrint('🔊 Error stopping Azan: $e');
    }
  }

  Future<void> pauseAzan() async => _audioPlayer?.pause();

  Future<void> resumeAzan() async => _audioPlayer?.play();

  bool get isPlaying => _audioPlayer?.playing ?? false;

  Stream<PlayerState>? get playerStateStream => _audioPlayer?.playerStateStream;

  Future<bool> isAzanEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('azan_enabled') ?? true;
  }

  Future<void> setAzanEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('azan_enabled', enabled);
  }

  Future<String> getSelectedReciter() async {
    final prefs = await SharedPreferences.getInstance();
    final r = prefs.getString('azan_reciter') ?? 'mishary';
    return azanReciters.containsKey(r) ? r : 'mishary';
  }

  Future<void> setSelectedReciter(String reciter) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('azan_reciter', reciter);
  }

  Future<double> getAzanVolume() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('azan_volume') ?? 1.0;
  }

  Future<void> setAzanVolume(double volume) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('azan_volume', volume.clamp(0.0, 1.0));
    await _audioPlayer?.setVolume(volume);
  }

  Future<bool> isAzanEnabledForPrayer(String prayerName) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('azan_${prayerName}_enabled') ?? true;
  }

  Future<void> setAzanEnabledForPrayer(String prayerName, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('azan_${prayerName}_enabled', enabled);
  }

  /// Preview an Azan sound (auto-stops after 15 seconds).
  Future<void> previewAzan(String reciter, {bool isFajr = false}) async {
    await playAzan(
      prayerName: isFajr ? 'الفجر' : 'الظهر',
      isFajr: isFajr,
      force: true,
      reciter: reciter,
    );
    Future.delayed(const Duration(seconds: 15), () {
      if (_audioPlayer?.playing ?? false) _audioPlayer?.stop();
    });
  }

  Future<void> dispose() async {
    await _audioPlayer?.dispose();
    _audioPlayer = null;
    _isInitialized = false;
  }
}
