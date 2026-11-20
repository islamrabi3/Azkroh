import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class TafsirBook {
  final int id; // quran.com resource id
  final String name;
  final bool offline;

  const TafsirBook(this.id, this.name, {this.offline = false});
}

class TafsirResult {
  final String text;
  final TafsirBook book;

  /// Verse key whose tafsir is shown (may differ when several verses are
  /// explained together).
  final String sourceVerseKey;

  const TafsirResult(this.text, this.book, this.sourceVerseKey);
}

/// Tafsir provider.
/// - التفسير الميسر is bundled with the app (works offline).
/// - Other books are fetched from api.quran.com and cached on the device.
class TafsirService {
  static final TafsirService _instance = TafsirService._internal();
  factory TafsirService() => _instance;
  TafsirService._internal();

  static const List<TafsirBook> books = [
    TafsirBook(16, 'التفسير الميسر', offline: true),
    TafsirBook(91, 'تفسير السعدي'),
    TafsirBook(14, 'تفسير ابن كثير'),
    TafsirBook(15, 'تفسير الطبري'),
    TafsirBook(90, 'تفسير القرطبي'),
    TafsirBook(94, 'تفسير البغوي'),
    TafsirBook(93, 'التفسير الوسيط'),
  ];

  static const String _prefBook = 'tafsir_book_id';

  /// Pseudo book id for "translation of the meanings".
  static const int translationId = -1;

  /// quran.com translation per UI language.
  static const Map<String, int> translationByLang = {
    'en': 20, // Saheeh International
    'fr': 31, // Muhammad Hamidullah
    'es': 83, // Sheikh Isa Garcia
    'de': 27, // Frank Bubenheim & Nadeem
    'tr': 77, // Diyanet
    'ru': 79, // Abu Adel
    'id': 33, // Indonesian Ministry of Religious Affairs
    'ms': 39, // Abdullah Muhammad Basmeih
    'ur': 54, // Muhammad Junagarhi
    'fa': 135, // IslamHouse.com
    'zh': 56, // Ma Jian
  };

  /// Translation of the meanings of [surah]:[ayah] in [lang] (cached).
  Future<String> getTranslation(int surah, int ayah, String lang) async {
    final id = translationByLang[lang] ?? 20;
    final box = Hive.isBoxOpen('tafsir_cache')
        ? Hive.lazyBox('tafsir_cache')
        : await Hive.openLazyBox('tafsir_cache');
    final key = 't${id}_$surah:$ayah';
    final cached = await box.get(key) as String?;
    if (cached != null) return cached;
    final res = await http
        .get(Uri.parse(
            'https://api.quran.com/api/v4/quran/translations/$id?verse_key=$surah:$ayah'))
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}');
    }
    final list = (jsonDecode(utf8.decode(res.bodyBytes)) as Map)['translations']
        as List;
    final text = list.isEmpty
        ? ''
        : _clean((list.first['text'] ?? '').toString()
            .replaceAll(RegExp(r'<sup[^>]*>.*?</sup>'), ''));
    if (text.isNotEmpty) await box.put(key, text);
    return text;
  }

  Map<String, String>? _muyassar;

  Future<int> getPreferredBookId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefBook) ?? 16;
  }

  Future<void> setPreferredBookId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefBook, id);
  }

  Future<Map<String, String>> _loadMuyassar() async {
    if (_muyassar != null) return _muyassar!;
    final raw = await rootBundle.loadString('assets/tafsir/muyassar.json');
    _muyassar = await compute(_decode, raw);
    return _muyassar!;
  }

  static Map<String, String> _decode(String raw) =>
      Map<String, String>.from(jsonDecode(raw) as Map);

  static String _clean(String html) => html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&quot;', '"')
      .replaceAll('&amp;', '&')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();

  Future<TafsirResult> getTafsir(int surah, int ayah, {int? bookId}) async {
    final id = bookId ?? await getPreferredBookId();
    final book = books.firstWhere((b) => b.id == id, orElse: () => books[0]);

    if (book.offline) {
      final data = await _loadMuyassar();
      // Some verses are explained together with the verses before them.
      for (int a = ayah; a >= 1; a--) {
        final t = data['$surah:$a'];
        if (t != null && t.isNotEmpty) {
          return TafsirResult(t, book, '$surah:$a');
        }
      }
      throw Exception('لا يوجد تفسير لهذه الآية');
    }

    final box = Hive.isBoxOpen('tafsir_cache')
        ? Hive.lazyBox('tafsir_cache')
        : await Hive.openLazyBox('tafsir_cache');
    final cacheKey = '${book.id}_$surah:$ayah';
    final cached = await box.get(cacheKey) as String?;
    if (cached != null) {
      final m = jsonDecode(cached) as Map;
      return TafsirResult(m['t'] as String, book, m['k'] as String);
    }

    final uri = Uri.parse(
        'https://api.quran.com/api/v4/tafsirs/${book.id}/by_ayah/$surah:$ayah');
    final res = await http.get(uri).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('تعذر تحميل التفسير (${res.statusCode})');
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map;
    final tafsir = body['tafsir'] as Map;
    final text = _clean((tafsir['text'] ?? '').toString());
    String sourceKey = '$surah:$ayah';
    final verses = tafsir['verses'];
    if (verses is Map && verses.isNotEmpty) {
      sourceKey = verses.keys.first.toString();
    }
    if (text.isEmpty) {
      // Explained with a previous verse: walk back once.
      if (ayah > 1) return getTafsir(surah, ayah - 1, bookId: book.id);
      throw Exception('لا يوجد تفسير لهذه الآية');
    }
    await box.put(cacheKey, jsonEncode({'t': text, 'k': sourceKey}));
    return TafsirResult(text, book, sourceKey);
  }
}
