import 'remote_content_service.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../l10n/app_locale.dart';
import 'media_handler.dart';

/// One recitation (moshaf) of a reciter on mp3quran.net.
class Moshaf {
  final int id;
  final String name; // e.g. حفص عن عاصم - مرتل
  final String server; // base URL ending with /
  final List<int> surahs;

  const Moshaf(this.id, this.name, this.server, this.surahs);

  String urlFor(int surah) => '$server${surah.toString().padLeft(3, '0')}.mp3';
}

class ListenReciter {
  final int id;
  final String name;
  final List<Moshaf> moshafs;

  const ListenReciter(this.id, this.name, this.moshafs);
}

/// A downloaded surah.
class ListenDownload {
  final String key; // "<moshafId>_<surah>"
  final String reciter;
  final String moshaf;
  final int moshafId;
  final int surah;
  final String path;
  final int bytes;

  ListenDownload(this.key, this.reciter, this.moshaf, this.moshafId,
      this.surah, this.path, this.bytes);

  Map<String, dynamic> toJson() => {
        'reciter': reciter,
        'moshaf': moshaf,
        'moshafId': moshafId,
        'surah': surah,
        'path': path,
        'bytes': bytes,
      };

  factory ListenDownload.fromJson(String key, Map j) => ListenDownload(
        key,
        j['reciter'] as String,
        j['moshaf'] as String,
        (j['moshafId'] as num).toInt(),
        (j['surah'] as num).toInt(),
        j['path'] as String,
        (j['bytes'] as num).toInt(),
      );
}

/// What is playing in the Listen section.
class ListenNowPlaying {
  final String reciter;
  final Moshaf moshaf;
  final int surah;

  const ListenNowPlaying(this.reciter, this.moshaf, this.surah);
}

/// Quran listening library (mp3quran.net): reciters, streaming with
/// continuous playback, and offline downloads.
class ListenService {
  static final ListenService _instance = ListenService._internal();
  factory ListenService() => _instance;
  ListenService._internal() {
    _player.processingStateStream.listen((s) {
      if (!_owns) return;
      if (s == ProcessingState.completed) next();
    });
    _player.durationStream.listen((d) {
      if (_owns) _media.updateDuration(d);
    });
  }

  MediaHandler get _media => MediaHandler.instance;
  AudioPlayer get _player => _media.player;
  AudioPlayer get player => _player;
  bool get _owns => _media.mode == MediaMode.listen;

  late final MediaControls _controls = MediaControls(
    play: () => _player.play(),
    pause: () => _player.pause(),
    stop: stop,
    next: next,
    previous: previous,
    seekable: true,
    onYield: yieldPlayer,
  );

  final ValueNotifier<ListenNowPlaying?> nowPlaying = ValueNotifier(null);

  /// Progress of running downloads: key -> 0..1
  final ValueNotifier<Map<String, double>> downloading = ValueNotifier({});

  /// Bumped whenever the downloads list changes.
  final ValueNotifier<int> downloadsVersion = ValueNotifier(0);

  List<ListenReciter>? _reciters;

  /// Reciters from Al-Hawamdiya not on mp3quran.net, served from other
  /// sources. Shown first in their own section.
  static final List<ListenReciter> hawamdiya = [
    ListenReciter(-1001, 'محمد حسني عمر', [
      Moshaf(-1001, 'حفص عن عاصم - مرتل (الحوامدية)',
          'https://media.way2quran.com/mohamed-hosni-omar/hafs-an-asim/',
          List<int>.generate(114, (i) => i + 1)),
    ]),
  ];

  // ---------------------------------------------------------------------------
  // Catalogue
  // ---------------------------------------------------------------------------
  Future<List<ListenReciter>> reciters({bool refresh = false}) async {
    if (_reciters != null && !refresh) return _reciters!;
    final prefs = await SharedPreferences.getInstance();
    const key = 'listen_reciters_ar';
    String? body = prefs.getString(key);
    if (body == null || refresh) {
      try {
        final res = await http.get(
            Uri.parse('https://www.mp3quran.net/api/v3/reciters?language=ar'),
            headers: {
              'User-Agent': 'Mozilla/5.0'
            }).timeout(const Duration(seconds: 20));
        if (res.statusCode == 200) {
          body = utf8.decode(res.bodyBytes);
          await prefs.setString(key, body);
        }
      } catch (_) {}
    }
    if (body == null) throw Exception('offline');
    _reciters = [
      ...hawamdiya,
      ...RemoteContentService.instance.reciters.value,
      ...await compute(_parse, body),
    ];
    return _reciters!;
  }

  static List<ListenReciter> _parse(String body) {
    final list = (jsonDecode(body) as Map)['reciters'] as List;
    final out = <ListenReciter>[];
    for (final r in list) {
      final moshafs = <Moshaf>[];
      for (final m in (r['moshaf'] as List)) {
        final surahs = (m['surah_list'] as String)
            .split(',')
            .where((e) => e.trim().isNotEmpty)
            .map((e) => int.parse(e.trim()))
            .toList();
        if (surahs.isEmpty) continue;
        moshafs.add(Moshaf((m['id'] as num).toInt(), m['name'] as String,
            m['server'] as String, surahs));
      }
      if (moshafs.isEmpty) continue;
      out.add(ListenReciter((r['id'] as num).toInt(),
          (r['name'] as String).trim(), moshafs));
    }
    out.sort((a, b) => a.name.compareTo(b.name));
    return out;
  }

  // ---------------------------------------------------------------------------
  // Downloads
  // ---------------------------------------------------------------------------
  Future<Box> _box() async => Hive.isBoxOpen('listen_downloads')
      ? Hive.box('listen_downloads')
      : await Hive.openBox('listen_downloads');

  String keyFor(Moshaf m, int surah) => '${m.id}_$surah';

  Future<ListenDownload?> download(String key) async {
    final b = await _box();
    final v = b.get(key);
    if (v == null) return null;
    final d = ListenDownload.fromJson(key, jsonDecode(v as String) as Map);
    if (!File(d.path).existsSync()) {
      await b.delete(key);
      return null;
    }
    return d;
  }

  Future<List<ListenDownload>> downloads() async {
    final b = await _box();
    final out = <ListenDownload>[];
    for (final k in b.keys) {
      final d = await download(k as String);
      if (d != null) out.add(d);
    }
    out.sort((a, b) {
      final c = a.reciter.compareTo(b.reciter);
      return c != 0 ? c : a.surah.compareTo(b.surah);
    });
    return out;
  }

  Future<void> downloadSurah(String reciter, Moshaf m, int surah) async {
    final key = keyFor(m, surah);
    if (downloading.value.containsKey(key)) return;
    if (await download(key) != null) return;
    _setProgress(key, 0);
    final client = http.Client();
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/listen/${m.id}/$surah.mp3');
      await file.parent.create(recursive: true);
      final req = http.Request('GET', Uri.parse(m.urlFor(surah)))
        ..headers['User-Agent'] = 'Mozilla/5.0';
      final res = await client.send(req);
      if (res.statusCode != 200) throw HttpException('${res.statusCode}');
      final total = res.contentLength ?? 0;
      final tmp = File('${file.path}.part');
      final sink = tmp.openWrite();
      int got = 0;
      await for (final chunk in res.stream) {
        sink.add(chunk);
        got += chunk.length;
        if (total > 0) _setProgress(key, got / total);
      }
      await sink.close();
      await tmp.rename(file.path);
      final b = await _box();
      await b.put(
          key,
          jsonEncode(ListenDownload(key, reciter, m.name, m.id, surah,
                  file.path, got)
              .toJson()));
      downloadsVersion.value++;
    } finally {
      client.close();
      final map = Map<String, double>.from(downloading.value)..remove(key);
      downloading.value = map;
    }
  }

  void _setProgress(String key, double v) {
    downloading.value = Map<String, double>.from(downloading.value)
      ..[key] = v;
  }

  Future<void> deleteDownload(String key) async {
    final d = await download(key);
    if (d != null) {
      try {
        await File(d.path).delete();
      } catch (_) {}
    }
    await (await _box()).delete(key);
    downloadsVersion.value++;
  }

  // ---------------------------------------------------------------------------
  // Playback
  // ---------------------------------------------------------------------------
  Future<void> play(String reciter, Moshaf m, int surah) async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    nowPlaying.value = ListenNowPlaying(reciter, m, surah);
    _media.claim(MediaMode.listen, _controls);
    _media.setNowPlaying(
      id: 'listen_${m.id}_$surah',
      title: AppLocale.isRtl ? 'سورة ${surahName(surah)}' : surahName(surah),
      artist: reciter,
      album: m.name,
    );
    final local = await download(keyFor(m, surah));
    try {
      if (local != null) {
        await _player.setFilePath(local.path);
      } else {
        await _player.setUrl(m.urlFor(surah));
      }
      unawaited(_player.play());
    } catch (e) {
      debugPrint('listen play error: $e');
      rethrow;
    }
  }

  /// Continuous playback: the next available surah of the same recitation.
  Future<void> next() async {
    final np = nowPlaying.value;
    if (np == null) return;
    final i = np.moshaf.surahs.indexOf(np.surah);
    if (i >= 0 && i + 1 < np.moshaf.surahs.length) {
      await play(np.reciter, np.moshaf, np.moshaf.surahs[i + 1]);
    }
  }

  Future<void> previous() async {
    final np = nowPlaying.value;
    if (np == null) return;
    if (_player.position > const Duration(seconds: 5)) {
      await _player.seek(Duration.zero);
      return;
    }
    final i = np.moshaf.surahs.indexOf(np.surah);
    if (i > 0) await play(np.reciter, np.moshaf, np.moshaf.surahs[i - 1]);
  }

  Future<void> toggle() async =>
      _player.playing ? _player.pause() : _player.play();

  Future<void> stop() async {
    if (_owns) {
      await _player.stop();
      _media.release(MediaMode.listen);
    }
    nowPlaying.value = null;
  }

  /// Called when another feature (radio) takes the shared player.
  void yieldPlayer() => nowPlaying.value = null;
}
