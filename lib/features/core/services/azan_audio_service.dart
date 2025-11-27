import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Azan Audio Service for playing Azan sounds in the background
class AzanAudioService {
  static final AzanAudioService _instance = AzanAudioService._internal();
  factory AzanAudioService() => _instance;
  AzanAudioService._internal();

  AudioPlayer? _audioPlayer;
  bool _isInitialized = false;

  // Available Azan reciters with their audio URLs
  static const Map<String, Map<String, String>> azanReciters = {
    'mishary': {
      'name': 'مشاري العفاسي',
      'fajr': 'https://download.tvquran.com/download/selections/315/Azan-Al-Fajr-Meshary-Rashid-Alafasy.mp3',
      'regular': 'https://download.tvquran.com/download/selections/315/Azan-Meshary-Rashid-Alafasy.mp3',
    },
    'makkah': {
      'name': 'أذان الحرم المكي',
      'fajr': 'https://www.islamcan.com/audio/adhan/azan1.mp3',
      'regular': 'https://www.islamcan.com/audio/adhan/azan2.mp3',
    },
    'madinah': {
      'name': 'أذان المسجد النبوي',
      'fajr': 'https://www.islamcan.com/audio/adhan/azan3.mp3',
      'regular': 'https://www.islamcan.com/audio/adhan/azan4.mp3',
    },
  };

  // Default Azan URLs (fallback)
  static const String _defaultFajrAzan = 'https://cdn.aladhan.com/audio/adhans/fajr/mishary.mp3';
  static const String _defaultRegularAzan = 'https://cdn.aladhan.com/audio/adhans/mishary.mp3';

  /// Initialize the audio service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _audioPlayer = AudioPlayer();

      // Configure audio session for background playback
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.notification,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
        androidWillPauseWhenDucked: false,
      ));

      // Handle audio interruptions
      session.interruptionEventStream.listen((event) {
        if (event.begin) {
          // Audio interrupted
          _audioPlayer?.pause();
        } else {
          // Interruption ended
          switch (event.type) {
            case AudioInterruptionType.duck:
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              _audioPlayer?.play();
              break;
          }
        }
      });

      _isInitialized = true;
      debugPrint('🔊 AzanAudioService initialized successfully');
    } catch (e) {
      debugPrint('🔊 Error initializing AzanAudioService: $e');
    }
  }

  /// Play Azan for a specific prayer
  Future<void> playAzan({
    required String prayerName,
    bool isFajr = false,
  }) async {
    try {
      await initialize();

      if (_audioPlayer == null) {
        debugPrint('🔊 AudioPlayer not initialized');
        return;
      }

      // Check if Azan is enabled
      final isEnabled = await isAzanEnabled();
      if (!isEnabled) {
        debugPrint('🔊 Azan is disabled in settings');
        return;
      }

      // Get selected reciter
      final reciter = await getSelectedReciter();
      final reciterData = azanReciters[reciter] ?? azanReciters['mishary']!;

      // Get the appropriate Azan URL
      String azanUrl;
      if (isFajr || prayerName == 'الفجر') {
        azanUrl = reciterData['fajr'] ?? _defaultFajrAzan;
      } else {
        azanUrl = reciterData['regular'] ?? _defaultRegularAzan;
      }

      debugPrint('🔊 Playing Azan for $prayerName from: $azanUrl');

      // Stop any currently playing audio
      await _audioPlayer!.stop();

      // Set the audio source
      await _audioPlayer!.setUrl(azanUrl);

      // Set volume
      final volume = await getAzanVolume();
      await _audioPlayer!.setVolume(volume);

      // Play the Azan
      await _audioPlayer!.play();

      debugPrint('🔊 Azan started playing for $prayerName');
    } catch (e) {
      debugPrint('🔊 Error playing Azan: $e');
    }
  }

  /// Stop the currently playing Azan
  Future<void> stopAzan() async {
    try {
      await _audioPlayer?.stop();
      debugPrint('🔊 Azan stopped');
    } catch (e) {
      debugPrint('🔊 Error stopping Azan: $e');
    }
  }

  /// Pause the currently playing Azan
  Future<void> pauseAzan() async {
    try {
      await _audioPlayer?.pause();
      debugPrint('🔊 Azan paused');
    } catch (e) {
      debugPrint('🔊 Error pausing Azan: $e');
    }
  }

  /// Resume the paused Azan
  Future<void> resumeAzan() async {
    try {
      await _audioPlayer?.play();
      debugPrint('🔊 Azan resumed');
    } catch (e) {
      debugPrint('🔊 Error resuming Azan: $e');
    }
  }

  /// Check if Azan is currently playing
  bool get isPlaying => _audioPlayer?.playing ?? false;

  /// Get the playback state stream
  Stream<PlayerState>? get playerStateStream => _audioPlayer?.playerStateStream;

  /// Check if Azan sound is enabled
  Future<bool> isAzanEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('azan_enabled') ?? true;
  }

  /// Enable or disable Azan sound
  Future<void> setAzanEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('azan_enabled', enabled);
    debugPrint('🔊 Azan enabled: $enabled');
  }

  /// Get the selected Azan reciter
  Future<String> getSelectedReciter() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('azan_reciter') ?? 'mishary';
  }

  /// Set the Azan reciter
  Future<void> setSelectedReciter(String reciter) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('azan_reciter', reciter);
    debugPrint('🔊 Azan reciter set to: $reciter');
  }

  /// Get Azan volume (0.0 to 1.0)
  Future<double> getAzanVolume() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('azan_volume') ?? 1.0;
  }

  /// Set Azan volume
  Future<void> setAzanVolume(double volume) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('azan_volume', volume.clamp(0.0, 1.0));
    await _audioPlayer?.setVolume(volume);
    debugPrint('🔊 Azan volume set to: $volume');
  }

  /// Check if Azan is enabled for a specific prayer
  Future<bool> isAzanEnabledForPrayer(String prayerName) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('azan_${prayerName}_enabled') ?? true;
  }

  /// Enable or disable Azan for a specific prayer
  Future<void> setAzanEnabledForPrayer(String prayerName, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('azan_${prayerName}_enabled', enabled);
    debugPrint('🔊 Azan for $prayerName: $enabled');
  }

  /// Preview an Azan sound
  Future<void> previewAzan(String reciter, {bool isFajr = false}) async {
    try {
      await initialize();

      if (_audioPlayer == null) return;

      final reciterData = azanReciters[reciter] ?? azanReciters['mishary']!;
      final azanUrl = isFajr
          ? reciterData['fajr'] ?? _defaultFajrAzan
          : reciterData['regular'] ?? _defaultRegularAzan;

      await _audioPlayer!.stop();
      await _audioPlayer!.setUrl(azanUrl);
      await _audioPlayer!.setVolume(await getAzanVolume());
      await _audioPlayer!.play();

      // Auto stop after 15 seconds for preview
      Future.delayed(const Duration(seconds: 15), () {
        if (_audioPlayer?.playing ?? false) {
          _audioPlayer?.stop();
        }
      });

      debugPrint('🔊 Previewing Azan: $reciter');
    } catch (e) {
      debugPrint('🔊 Error previewing Azan: $e');
    }
  }

  /// Dispose the audio player
  Future<void> dispose() async {
    await _audioPlayer?.dispose();
    _audioPlayer = null;
    _isInitialized = false;
    debugPrint('🔊 AzanAudioService disposed');
  }
}

