import 'dart:async';
import 'dart:convert';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../l10n/app_locale.dart';
import 'media_handler.dart';

class RadioStation {
  final String name;
  final List<String> urls; // primary first, then backups
  final bool featured;

  const RadioStation(this.name, this.urls, {this.featured = false});
}

/// Live Quran radio on the shared media player: keeps playing in the
/// background and is controllable from the lock screen / notification.
/// Reconnects automatically with backoff and server rotation.
class RadioService {
  static final RadioService _instance = RadioService._();
  factory RadioService() => _instance;

  RadioService._() {
    _player.playerStateStream.listen((s) {
      if (!_owns) return;
      final b = s.processingState == ProcessingState.loading ||
          s.processingState == ProcessingState.buffering;
      if (b != buffering.value) buffering.value = b;
      // A live stream should never "complete": reconnect if it does.
      if (_wantPlaying && s.processingState == ProcessingState.completed) {
        _reconnect();
      }
      if (s.playing && s.processingState == ProcessingState.ready) {
        _retries = 0;
      }
      playing.value = s.playing;
    });
    _player.playbackEventStream.listen((_) {},
        onError: (Object e, StackTrace st) {
      if (_owns) _reconnect();
    });
  }

  static const featured = <RadioStation>[
    RadioStation('إذاعة القرآن الكريم من القاهرة', [
      'https://stream.radiojar.com/8s5u5tpdtwzuv',
      'https://n0e.radiojar.com/8s5u5tpdtwzuv',
    ], featured: true),
    RadioStation('إذاعة القرآن الكريم - السعودية', [
      'https://stream.radiojar.com/0tpy1h0kxtzuv',
    ], featured: true),
    RadioStation('تلاوات متنوعة لمختلف القراء', [
      'https://backup.qurango.net/radio/mix',
      'https://qurango.net/radio/mix',
    ], featured: true),
    RadioStation('تراتيل قصيرة متميزة', [
      'https://backup.qurango.net/radio/tarateel',
      'https://qurango.net/radio/tarateel',
    ], featured: true),
    RadioStation('تفسير القرآن الكريم', [
      'https://backup.qurango.net/radio/tafseer',
      'https://qurango.net/radio/tafseer',
    ], featured: true),
    RadioStation('الرقية الشرعية', [
      'https://backup.qurango.net/radio/roqiah',
      'https://qurango.net/radio/roqiah',
    ], featured: true),
  ];

  MediaHandler get _media => MediaHandler.instance;
  AudioPlayer get _player => _media.player;
  bool get _owns => _media.mode == MediaMode.radio;

  final ValueNotifier<RadioStation?> current = ValueNotifier(null);
  final ValueNotifier<bool> buffering = ValueNotifier(false);
  final ValueNotifier<bool> playing = ValueNotifier(false);
  final ValueNotifier<List<RadioStation>> reciterStations = ValueNotifier([]);

  /// Station names the user starred.
  final ValueNotifier<Set<String>> favorites = ValueNotifier(<String>{});

  int _urlIndex = 0;
  int _retries = 0;
  bool _wantPlaying = false;
  Timer? _retryTimer;
  bool _loaded = false;

  late final MediaControls _controls = MediaControls(
    play: resume,
    pause: pause,
    stop: stop,
    next: () => _step(1),
    previous: () => _step(-1),
    onYield: _yield,
  );

  // ---------------------------------------------------------------------------
  // Stations
  // ---------------------------------------------------------------------------
  Future<void> loadStations() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    favorites.value = (prefs.getStringList('radio_favorites') ?? []).toSet();
    final cached = prefs.getString('radio_stations_cache');
    if (cached != null) _parse(cached);
    try {
      final res = await http.get(
          Uri.parse('https://www.mp3quran.net/api/v3/radios?language=ar'),
          headers: {'User-Agent': 'Mozilla/5.0'}).timeout(
          const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final body = utf8.decode(res.bodyBytes);
        await prefs.setString('radio_stations_cache', body);
        _parse(body);
      }
    } catch (_) {
      if (cached == null) _loaded = false;
    }
  }

  void _parse(String body) {
    try {
      final list = (jsonDecode(body) as Map)['radios'] as List;
      // mp3quran gives every station of a reciter the same name (murattal,
      // mujawwad, other riwayat), so tell them apart by the stream slug.
      final counts = <String, int>{};
      for (final r in list) {
        final n = (r['name'] as String).trim();
        counts[n] = (counts[n] ?? 0) + 1;
      }
      final stations = <RadioStation>[];
      for (final r in list) {
        final url = (r['url'] as String).trim();
        var name = (r['name'] as String).trim();
        if (url.isEmpty) continue;
        if ((counts[name] ?? 0) > 1) {
          name = '$name - ${_variantLabel(url.split('/').last)}';
        }
        final alt = url.contains('backup.qurango.net')
            ? url.replaceFirst('backup.qurango.net', 'qurango.net')
            : url.replaceFirst('qurango.net', 'backup.qurango.net');
        stations.add(RadioStation(name, [url, alt]));
      }
      reciterStations.value = stations;
    } catch (_) {}
  }

  /// Riwaya / style of a station, from its stream slug. Checked against the
  /// riwayat mp3quran lists for each of these reciters.
  static String _variantLabel(String slug) {
    const labels = [
      ['aldori_an_abi_amr', 'الدوري عن أبي عمرو'],
      ['aldorai', 'الدوري عن الكسائي'],
      ['albizi', 'البزي وقنبل عن ابن كثير'],
      ['ibn_thakwan', 'ابن ذكوان عن ابن عامر'],
      ['alasbahani', 'ورش عن نافع'],
      ['warsh', 'ورش عن نافع'],
      ['khalaf', 'خلف عن حمزة'],
      ['assosi', 'السوسي عن أبي عمرو'],
      ['mojawwad', 'مجوّد'],
      ['english_bsfr', 'عبدالله بصفر'],
      ['_basit', 'عبدالباسط عبدالصمد'],
      ['urdu_minsh', 'محمد صديق المنشاوي'],
      ['urdu_sds_shur', 'السديس والشريم'],
    ];
    for (final l in labels) {
      if (slug.contains(l[0])) return l[1];
    }
    return 'مرتّل';
  }

  Future<void> toggleFavorite(RadioStation s) async {
    final f = Set<String>.from(favorites.value);
    f.contains(s.name) ? f.remove(s.name) : f.add(s.name);
    favorites.value = f;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('radio_favorites', f.toList());
  }

  List<RadioStation> get favoriteStations {
    final f = favorites.value;
    return [...featured, ...reciterStations.value]
        .where((s) => f.contains(s.name))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Playback
  // ---------------------------------------------------------------------------
  Future<void> play(RadioStation s) async {
    _retryTimer?.cancel();
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    current.value = s;
    _urlIndex = 0;
    _retries = 0;
    _wantPlaying = true;
    _media.claim(MediaMode.radio, _controls);
    _media.setNowPlaying(
      id: 'radio_${s.name}',
      title: tr(s.name),
      artist: tr('بث مباشر'),
      album: tr('الإذاعة'),
    );
    await _start();
  }

  Future<void> _start() async {
    final s = current.value;
    if (s == null || !_owns) return;
    try {
      await _player.stop();
      await _player.setAudioSource(
          AudioSource.uri(Uri.parse(s.urls[_urlIndex % s.urls.length])));
      unawaited(_player.play());
    } catch (_) {
      _reconnect();
    }
  }

  /// Retry with backoff, rotating through the station's servers.
  void _reconnect() {
    if (!_wantPlaying || current.value == null || !_owns) return;
    _retryTimer?.cancel();
    _retries++;
    _urlIndex++;
    final delay = Duration(seconds: (_retries * 2).clamp(1, 15));
    buffering.value = true;
    _retryTimer = Timer(delay, _start);
  }

  /// Re-opens the live edge instead of resuming old buffered audio.
  Future<void> resume() async {
    if (current.value == null) return;
    if (!_owns) {
      await play(current.value!);
      return;
    }
    _wantPlaying = true;
    await _start();
  }

  Future<void> pause() async {
    _wantPlaying = false;
    _retryTimer?.cancel();
    await _player.pause();
  }

  Future<void> toggle() async =>
      _player.playing && _owns ? pause() : resume();

  Future<void> stop() async {
    _wantPlaying = false;
    _retryTimer?.cancel();
    if (_owns) {
      await _player.stop();
      _media.release(MediaMode.radio);
    }
    current.value = null;
    buffering.value = false;
    playing.value = false;
  }

  /// Next / previous station from the lock screen.
  Future<void> _step(int dir) async {
    final all = [...featured, ...reciterStations.value];
    final cur = current.value;
    if (all.isEmpty) return;
    var i = cur == null ? -1 : all.indexWhere((s) => s.name == cur.name);
    i = (i + dir) % all.length;
    if (i < 0) i += all.length;
    await play(all[i]);
  }

  void _yield() {
    _wantPlaying = false;
    _retryTimer?.cancel();
    current.value = null;
    buffering.value = false;
    playing.value = false;
  }
}
