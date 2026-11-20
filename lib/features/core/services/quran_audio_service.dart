import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qcf_quran_plus/qcf_quran_plus.dart' as qcf;
import 'package:shared_preferences/shared_preferences.dart';

/// How a reciter's audio is organised on the server.
enum ReciterSource { perAyah, perSurah }

class Reciter {
  final String id;
  final String name;
  final String style; // مرتل / مجود
  final ReciterSource source;

  /// everyayah.com folder (per ayah) or mp3quran folder URL (per surah).
  final String base;

  /// mp3quran ayah-timing "read" id (per surah reciters only).
  final int? timingRead;

  /// Available surahs (null = all 114).
  final Set<int>? surahs;

  const Reciter(this.id, this.name, this.style, this.source, this.base,
      {this.timingRead, this.surahs});

  bool hasSurah(int s) => surahs == null || surahs!.contains(s);
}

/// Current playback position.
class RecitationState {
  final Reciter reciter;
  final int surah;
  final int? ayah; // null when the position inside the surah is unknown
  final bool playing;
  final bool loading;

  /// Playback reached the end; the bar stays so the user can replay.
  final bool finished;

  const RecitationState(this.reciter, this.surah, this.ayah,
      {this.playing = false, this.loading = false, this.finished = false});
}

/// Quran recitation player with an on-disk cache: every file is downloaded
/// once and then played from the device (works offline afterwards).
class QuranAudioService {
  static final QuranAudioService _instance = QuranAudioService._internal();
  factory QuranAudioService() => _instance;
  QuranAudioService._internal();

  static const reciters = <Reciter>[
    Reciter('alafasy', 'مشاري راشد العفاسي', 'مرتل', ReciterSource.perAyah,
        'Alafasy_128kbps'),
    Reciter('husary', 'محمود خليل الحصري', 'مرتل', ReciterSource.perAyah,
        'Husary_128kbps'),
    Reciter('husary_mj', 'محمود خليل الحصري', 'مجود', ReciterSource.perAyah,
        'Husary_128kbps_Mujawwad'),
    Reciter('minshawi', 'محمد صديق المنشاوي', 'مرتل', ReciterSource.perAyah,
        'Minshawy_Murattal_128kbps'),
    Reciter('minshawi_mj', 'محمد صديق المنشاوي', 'مجود',
        ReciterSource.perAyah, 'Minshawy_Mujawwad_192kbps'),
    Reciter('banna', 'محمود علي البنا', 'مرتل', ReciterSource.perAyah,
        'mahmoud_ali_al_banna_32kbps'),
    Reciter('banna_mj', 'محمود علي البنا', 'مجود', ReciterSource.perSurah,
        'https://cdn.mp3quran.net/audio/mahmoud-banna/r2/',
        timingRead: 122),
    Reciter('mustafa_ismail', 'مصطفى إسماعيل', 'مجود', ReciterSource.perSurah,
        'https://cdn.mp3quran.net/audio/mustafa-ismail/r2/',
        timingRead: 288),
    Reciter('abdulbasit', 'عبد الباسط عبد الصمد', 'مرتل',
        ReciterSource.perAyah, 'Abdul_Basit_Murattal_192kbps'),
    Reciter('abdulbasit_mj', 'عبد الباسط عبد الصمد', 'مجود',
        ReciterSource.perAyah, 'Abdul_Basit_Mujawwad_128kbps'),
    Reciter('rifaat', 'محمد رفعت', 'مرتل (٣١ سورة)', ReciterSource.perSurah,
        'https://cdn.mp3quran.net/audio/muhammad-refaat/r1/',
        surahs: {
          1, 10, 11, 12, 17, 18, 19, 20, 48, 54, 55, 56, 69, 72, 73, 75, //
          76, 77, 78, 79, 81, 82, 83, 85, 86, 87, 88, 89, 96, 98, 100,
        }),
  ];

  static const _prefReciter = 'quran_reciter';

  final AudioPlayer _player = AudioPlayer();
  final ValueNotifier<RecitationState?> state = ValueNotifier(null);

  /// When on, the current ayah is repeated until switched off.
  final ValueNotifier<bool> repeatAyah = ValueNotifier(false);

  int? _startSurah;
  int? _startAyah;

  /// Incremented on every new play/stop request to cancel stale loops.
  int _session = 0;
  StreamSubscription<Duration>? _posSub;
  Directory? _dir;

  // ---------------------------------------------------------------------------
  // Reciter preference
  // ---------------------------------------------------------------------------
  Future<Reciter> selectedReciter() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_prefReciter) ?? 'alafasy';
    return reciters.firstWhere((r) => r.id == id, orElse: () => reciters[0]);
  }

  Future<void> setReciter(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefReciter, id);
  }

  // ---------------------------------------------------------------------------
  // Cache
  // ---------------------------------------------------------------------------
  Future<Directory> _cacheDir() async {
    if (_dir != null) return _dir!;
    final base = await getApplicationSupportDirectory();
    _dir = Directory('${base.path}/quran_audio');
    await _dir!.create(recursive: true);
    return _dir!;
  }

  static String _p3(int n) => n.toString().padLeft(3, '0');

  Future<File> _ayahFile(Reciter r, int s, int a) async {
    final d = await _cacheDir();
    return File('${d.path}/${r.id}/${_p3(s)}${_p3(a)}.mp3');
  }

  Future<File> _surahFile(Reciter r, int s) async {
    final d = await _cacheDir();
    return File('${d.path}/${r.id}/${_p3(s)}.mp3');
  }

  String _ayahUrl(Reciter r, int s, int a) =>
      'https://everyayah.com/data/${r.base}/${_p3(s)}${_p3(a)}.mp3';

  String _surahUrl(Reciter r, int s) => '${r.base}${_p3(s)}.mp3';

  final Map<String, Future<File>> _downloads = {};

  /// Downloads [url] into [file] once (concurrent calls share the work).
  Future<File> _download(String url, File file) {
    return _downloads[file.path] ??= () async {
      try {
        if (await file.exists() && await file.length() > 0) return file;
        await file.parent.create(recursive: true);
        final res = await http
            .get(Uri.parse(url), headers: {'User-Agent': 'Mozilla/5.0'})
            .timeout(const Duration(seconds: 60));
        if (res.statusCode != 200) {
          throw HttpException('HTTP ${res.statusCode}', uri: Uri.parse(url));
        }
        final tmp = File('${file.path}.part');
        await tmp.writeAsBytes(res.bodyBytes, flush: true);
        await tmp.rename(file.path);
        return file;
      } finally {
        _downloads.remove(file.path);
      }
    }();
  }

  /// Total size of downloaded recitations in bytes.
  Future<int> cacheSize() async {
    final d = await _cacheDir();
    int total = 0;
    await for (final e in d.list(recursive: true)) {
      if (e is File) total += await e.length();
    }
    return total;
  }

  Future<void> clearCache() async {
    await stop();
    final d = await _cacheDir();
    if (await d.exists()) await d.delete(recursive: true);
    _dir = null;
  }

  /// Is the whole surah available offline for [r]?
  Future<bool> isSurahDownloaded(Reciter r, int s) async {
    if (r.source == ReciterSource.perSurah) {
      return (await _surahFile(r, s)).exists();
    }
    for (int a = 1; a <= qcf.getVerseCount(s); a++) {
      if (!await (await _ayahFile(r, s, a)).exists()) return false;
    }
    return true;
  }

  /// Download a full surah for offline listening. [onProgress] gets 0..1.
  Future<void> downloadSurah(Reciter r, int s,
      {void Function(double)? onProgress}) async {
    if (r.source == ReciterSource.perSurah) {
      onProgress?.call(0.05);
      await _download(_surahUrl(r, s), await _surahFile(r, s));
      await _timings(r, s);
      onProgress?.call(1);
      return;
    }
    final count = qcf.getVerseCount(s);
    int done = 0;
    // 4 parallel downloads
    final queue = List.generate(count, (i) => i + 1);
    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final a = queue.removeAt(0);
        await _download(_ayahUrl(r, s, a), await _ayahFile(r, s, a));
        done++;
        onProgress?.call(done / count);
      }
    }

    await Future.wait(List.generate(4, (_) => worker()));
  }

  // ---------------------------------------------------------------------------
  // Timings (per-surah reciters)
  // ---------------------------------------------------------------------------
  Future<List<int>?> _timings(Reciter r, int s) async {
    if (r.timingRead == null) return null;
    final box = Hive.isBoxOpen('audio_timings')
        ? Hive.box('audio_timings')
        : await Hive.openBox('audio_timings');
    final key = '${r.timingRead}_$s';
    final cached = box.get(key) as String?;
    if (cached != null) return (jsonDecode(cached) as List).cast<int>();
    try {
      final res = await http.get(
          Uri.parse(
              'https://www.mp3quran.net/api/v3/ayat_timing?surah=$s&read=${r.timingRead}'),
          headers: {
            'User-Agent': 'Mozilla/5.0'
          }).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return null;
      final list = jsonDecode(res.body) as List;
      // index = ayah number, value = start time in ms
      final starts = List<int>.filled(qcf.getVerseCount(s) + 1, 0);
      for (final e in list) {
        final a = (e['ayah'] as num).toInt();
        if (a >= 1 && a < starts.length) {
          starts[a] = (e['start_time'] as num).toInt();
        }
      }
      await box.put(key, jsonEncode(starts));
      return starts;
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Playback
  // ---------------------------------------------------------------------------
  Future<void> playFrom(int surah, int ayah, {Reciter? reciter}) async {
    final r = reciter ?? await selectedReciter();
    final session = ++_session;
    await _posSub?.cancel();
    _posSub = null;
    await _player.stop();

    if (!r.hasSurah(surah)) {
      state.value = null;
      throw Exception(
          'تلاوة الشيخ ${r.name} غير متوفرة لسورة ${qcf.getSurahNameArabic(surah)}');
    }

    _startSurah = surah;
    _startAyah = ayah;
    state.value = RecitationState(r, surah, ayah, loading: true);
    if (r.source == ReciterSource.perAyah) {
      await _playAyahLoop(r, surah, ayah, session);
    } else {
      await _playSurah(r, surah, ayah, session);
    }
  }

  Future<void> _playAyahLoop(Reciter r, int s, int a, int session) async {
    final count = qcf.getVerseCount(s);
    // Basmala before the first ayah (except Al-Fatiha and At-Tawbah).
    if (a == 1 && s != 1 && s != 9) {
      final f = await _download(_ayahUrl(r, 1, 1), await _ayahFile(r, 1, 1));
      if (session != _session) return;
      state.value = RecitationState(r, s, null, playing: true);
      await _player.setFilePath(f.path);
      if (!await _playToEnd(session)) return;
    }
    for (int i = a; i <= count; i++) {
      if (session != _session) return;
      state.value = RecitationState(r, s, i, loading: true);
      final file = await _download(_ayahUrl(r, s, i), await _ayahFile(r, s, i));
      // Prefetch the next two ayat while this one plays.
      for (int k = 1; k <= 2 && i + k <= count; k++) {
        unawaited(_download(_ayahUrl(r, s, i + k),
                await _ayahFile(r, s, i + k))
            .then((_) {}, onError: (_) {}));
      }
      if (session != _session) return;
      state.value = RecitationState(r, s, i, playing: true);
      await _player.setFilePath(file.path);
      if (!await _playToEnd(session)) return;
      if (repeatAyah.value) i--; // play the same ayah again
    }
    if (session == _session) {
      state.value = RecitationState(r, s, count, finished: true);
    }
  }

  Future<void> _playSurah(Reciter r, int s, int a, int session) async {
    final file = await _surahFile(r, s);
    final timings = await _timings(r, s);
    if (session != _session) return;

    if (await file.exists()) {
      await _player.setFilePath(file.path);
    } else {
      // Stream now and save a copy for offline use.
      await _player.setUrl(_surahUrl(r, s));
      unawaited(_download(_surahUrl(r, s), file).then((_) {}, onError: (_) {}));
    }
    if (session != _session) return;

    if (timings != null && a > 1 && timings[a] > 0) {
      await _player.seek(Duration(milliseconds: timings[a]));
    }
    state.value = RecitationState(r, s, timings == null ? null : a,
        playing: true);

    if (timings != null) {
      _posSub = _player.positionStream.listen((pos) {
        final ms = pos.inMilliseconds;
        int current = 1;
        for (int i = 1; i < timings.length; i++) {
          if (timings[i] > 0 && timings[i] <= ms) current = i;
        }
        final st = state.value;
        if (st == null) return;
        // Repeat: jump back to the start of the ayah being repeated.
        if (repeatAyah.value &&
            st.ayah != null &&
            current > st.ayah! &&
            timings[st.ayah!] > 0) {
          _player.seek(Duration(milliseconds: timings[st.ayah!]));
          return;
        }
        if (st.ayah != current) {
          state.value = RecitationState(r, s, current, playing: true);
        }
      });
    }
    while (true) {
      final completed = await _playToEnd(session);
      if (!completed || session != _session) return;
      // Repeat at the very end of the surah (last ayah / no timings).
      if (repeatAyah.value) {
        final st = state.value;
        final from = (timings != null && st?.ayah != null)
            ? timings[st!.ayah!]
            : 0;
        await _player.seek(Duration(milliseconds: from));
        continue;
      }
      break;
    }
    if (session == _session) {
      await _posSub?.cancel();
      _posSub = null;
      final st = state.value;
      state.value = RecitationState(r, s, st?.ayah, finished: true);
    }
  }

  /// Plays the loaded source until it completes. Pauses are waited through.
  /// Returns false if playback was stopped or replaced.
  Future<bool> _playToEnd(int session) async {
    unawaited(_player.play());
    await for (final ps in _player.playerStateStream) {
      if (session != _session) return false;
      if (ps.processingState == ProcessingState.completed) return true;
      if (ps.processingState == ProcessingState.idle && !ps.playing) {
        return false;
      }
    }
    return false;
  }

  Future<void> pauseOrResume() async {
    final st = state.value;
    if (st == null) return;
    if (st.finished) {
      // Replay from where the user started listening.
      await playFrom(_startSurah ?? st.surah, _startAyah ?? st.ayah ?? 1,
          reciter: st.reciter);
      return;
    }
    if (_player.playing) {
      await _player.pause();
      state.value = RecitationState(st.reciter, st.surah, st.ayah);
    } else {
      state.value =
          RecitationState(st.reciter, st.surah, st.ayah, playing: true);
      unawaited(_player.play());
    }
  }

  Future<void> stop() async {
    _session++;
    await _posSub?.cancel();
    _posSub = null;
    await _player.stop();
    state.value = null;
  }
}
