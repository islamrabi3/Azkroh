import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backend.dart';
import 'listen_service.dart';

/// A video / link / learning item published from the dashboard.
class RemoteItem {
  final String kind;
  final String section;
  final String title;
  final String? description;
  final String url;
  final String? thumbnail;

  const RemoteItem(this.kind, this.section, this.title, this.description,
      this.url, this.thumbnail);

  factory RemoteItem.fromJson(Map j) => RemoteItem(
        j['kind'] as String,
        j['section'] as String,
        j['title'] as String,
        j['description'] as String?,
        j['url'] as String,
        j['thumbnail_url'] as String?,
      );

  bool get isYoutube =>
      url.contains('youtube.com') || url.contains('youtu.be');
}

/// Content managed from the dashboard (Supabase). Cached for offline use.
class RemoteContentService {
  RemoteContentService._();
  static final RemoteContentService instance = RemoteContentService._();

  final ValueNotifier<List<RemoteItem>> items = ValueNotifier(const []);
  final ValueNotifier<List<ListenReciter>> reciters =
      ValueNotifier(const []);

  /// Dashboard overrides for built-in reciters: key -> hidden / featured.
  /// Keys: 'mp3quran:<id>' or 'builtin:<slug>'.
  Set<String> hiddenKeys = {};
  List<String> featuredKeys = const [];

  /// Local id of a dashboard reciter -> 'reciter:<uuid>'.
  static final Map<int, String> _remoteKeys = {};

  static String keyFor(ListenReciter r) => r.id == -1001
      ? 'builtin:hosni_omar'
      : r.id > 0
          ? 'mp3quran:${r.id}'
          : (_remoteKeys[r.id] ?? 'remote:${r.id}');

  bool isHidden(ListenReciter r) => hiddenKeys.contains(keyFor(r));

  static const _kItems = 'remote_content_items';
  static const _kReciters = 'remote_reciters';
  static const _kOverrides = 'remote_reciter_overrides';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _apply(prefs.getString(_kItems), prefs.getString(_kReciters),
        prefs.getString(_kOverrides));
    if (!Backend.isReady) return;
    try {
      final c = Backend.client;
      final rows = await c
          .from('content_items')
          .select('kind,section,title,description,url,thumbnail_url,sort')
          .eq('is_published', true)
          .order('sort');
      final rec = await c
          .from('reciters')
          .select(
              'id,name,riwaya,group_name,sort,server_url,surahs,recitations(surah,url)')
          .eq('is_published', true)
          .order('sort');
      final ov = await c
          .from('reciter_overrides')
          .select('key,hidden,featured,sort')
          .order('sort');
      final a = jsonEncode(rows);
      final b = jsonEncode(rec);
      final o = jsonEncode(ov);
      await prefs.setString(_kItems, a);
      await prefs.setString(_kReciters, b);
      await prefs.setString(_kOverrides, o);
      _apply(a, b, o);
    } catch (e) {
      debugPrint('remote content: $e');
    }
  }

  void _apply(String? itemsJson, String? recitersJson, String? overridesJson) {
    if (overridesJson != null) {
      final list = (jsonDecode(overridesJson) as List).cast<Map>();
      hiddenKeys = {
        for (final o in list)
          if (o['hidden'] == true) o['key'] as String
      };
      featuredKeys = [
        for (final o in list)
          if (o['featured'] == true && o['hidden'] != true) o['key'] as String
      ];
    }
    if (itemsJson != null) {
      items.value = (jsonDecode(itemsJson) as List)
          .map((e) => RemoteItem.fromJson(e as Map))
          .toList();
    }
    if (recitersJson != null) {
      final out = <ListenReciter>[];
      for (final r in jsonDecode(recitersJson) as List) {
        final id = -(2000 + out.length);
        _remoteKeys[id] = 'reciter:${r['id']}';
        final label =
            '${r['riwaya'] ?? 'حفص عن عاصم'}${r['group_name'] != null ? ' (${r['group_name']})' : ''}';
        // Added by link: a folder with 001.mp3 ... 114.mp3.
        final link = (r['server_url'] as String?)?.trim();
        if (link != null && link.isNotEmpty) {
          final surahs = ((r['surahs'] as List?) ?? const [])
              .map((e) => (e as num).toInt())
              .toList();
          out.add(ListenReciter(id, (r['name'] as String).trim(), [
            Moshaf(id, label, link.endsWith('/') ? link : '$link/',
                surahs.isEmpty ? List<int>.generate(114, (i) => i + 1) : surahs),
          ]));
          continue;
        }
        final recs = ((r['recitations'] as List?) ?? const [])
            .map((e) => e as Map)
            .toList()
          ..sort((a, b) => (a['surah'] as num).compareTo(b['surah'] as num));
        if (recs.isEmpty) continue;
        // Files are stored as .../reciters/<id>/NNN.mp3, so the folder works
        // as the Moshaf "server".
        final first = recs.first['url'] as String;
        final server = first.substring(0, first.lastIndexOf('/') + 1);
        out.add(ListenReciter(id, (r['name'] as String).trim(), [
          Moshaf(id, label, server,
              recs.map((e) => (e['surah'] as num).toInt()).toList()),
        ]));
      }
      reciters.value = out;
    }
  }
}
