import 'dart:convert';
import 'dart:io';

import 'package:azkroh_app/features/core/services/hadith_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Offline hadith library bundled with the app (≈36k hadiths):
/// صحيح البخاري، صحيح مسلم، سنن أبي داود، جامع الترمذي، سنن النسائي،
/// سنن ابن ماجه، موطأ مالك، الأربعون النووية، الأحاديث القدسية.
/// Grades for the Sunan are Al-Albani's. Source: hadith-api (public domain).
class HadithLibrary {
  static final HadithLibrary _instance = HadithLibrary._internal();
  factory HadithLibrary() => _instance;
  HadithLibrary._internal();

  _LibraryData? _data;
  Future<_LibraryData>? _loading;

  bool get isLoaded => _data != null;

  Future<_LibraryData> _load() {
    if (_data != null) return Future.value(_data);
    return _loading ??= () async {
      final bytes = await rootBundle.load('assets/hadith/hadiths.json.gz');
      final data = await compute(
          _decode, bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
      _data = data;
      return data;
    }();
  }

  /// Start loading in the background (e.g. when the hadith screen opens).
  void warmUp() => _load();

  static _LibraryData _decode(Uint8List gz) {
    final raw = utf8.decode(GZipCodec().decode(gz));
    final m = jsonDecode(raw) as Map<String, dynamic>;
    final books = (m['books'] as List).cast<String>();
    final rows = m['h'] as List;
    final book = <int>[];
    final number = <int>[];
    final text = <String>[];
    final norm = <String>[];
    final grade = <String?>[];
    final gradeBy = <String?>[];
    for (final r in rows) {
      final l = r as List;
      book.add(l[0] as int);
      number.add((l[1] as num).toInt());
      final t = l[2] as String;
      text.add(t);
      norm.add(normalizeArabic(t));
      grade.add(l[3] as String?);
      gradeBy.add(l[4] as String?);
    }
    return _LibraryData(books, book, number, text, norm, grade, gradeBy);
  }

  /// Arabic normalisation for search: no diacritics/tatweel/punctuation,
  /// unified alef/ya/ta-marbuta/hamza forms.
  static String normalizeArabic(String s) {
    return s
        .replaceAll(RegExp('[ؐ-ًؚ-ٰٟۖ-ۭـ]'), '')
        .replaceAll(RegExp('[إأآٱ]'), 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .replaceAll(RegExp(r'[^ء-ي0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Full-text search: every word of [query] must appear in the hadith.
  /// Exact-phrase matches come first.
  Future<HadithSearchResult> search(String query,
      {bool onlySahih = false, int limit = 300}) async {
    final d = await _load();
    final q = normalizeArabic(query);
    if (q.isEmpty) return const HadithSearchResult([], 0);
    final words = q.split(' ').where((w) => w.isNotEmpty).toList();

    final exact = <int>[];
    final partial = <int>[];
    for (int i = 0; i < d.norm.length; i++) {
      final t = d.norm[i];
      if (!t.contains(words.first)) continue;
      bool all = true;
      for (int w = 1; w < words.length; w++) {
        if (!t.contains(words[w])) {
          all = false;
          break;
        }
      }
      if (!all) continue;
      if (onlySahih && !_isSahih(d.grade[i])) continue;
      (words.length > 1 && t.contains(q) ? exact : partial).add(i);
    }
    final ids = [...exact, ...partial];
    return HadithSearchResult(
      ids.take(limit).map((i) => _toHadith(d, i)).toList(),
      ids.length,
    );
  }

  /// A sahih hadith picked deterministically for [day].
  Future<Hadith> hadithOfDay(int day) async {
    final d = await _load();
    // Prefer the short, well-known collections: Nawawi, Qudsi, then Bukhari.
    final pool = <int>[];
    for (int i = 0; i < d.book.length; i++) {
      final b = d.books[d.book[i]];
      if ((b == 'الأربعون النووية' || b == 'الأحاديث القدسية') ||
          (b == 'صحيح البخاري' && d.text[i].length < 600)) {
        pool.add(i);
      }
    }
    return _toHadith(d, pool[day % pool.length]);
  }

  static bool _isSahih(String? g) =>
      g != null && g.contains('صحيح');

  Hadith _toHadith(_LibraryData d, int i) {
    final bookName = d.books[d.book[i]];
    return Hadith(
      id: 'lib_${d.book[i]}_${d.number[i]}',
      text: d.text[i],
      source: bookName,
      number: '${d.number[i]}',
      grade: d.grade[i],
      muhaddith: d.gradeBy[i],
      provider: 'المكتبة المدمجة',
    );
  }
}

class HadithSearchResult {
  final List<Hadith> items;
  final int total;

  const HadithSearchResult(this.items, this.total);
}

class _LibraryData {
  final List<String> books;
  final List<int> book;
  final List<int> number;
  final List<String> text;
  final List<String> norm;
  final List<String?> grade;
  final List<String?> gradeBy;

  _LibraryData(this.books, this.book, this.number, this.text, this.norm,
      this.grade, this.gradeBy);
}
