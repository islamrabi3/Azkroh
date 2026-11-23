import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/paged_list.dart';
import 'backend.dart';

/// A book in the library: either a Turath text book (read in-app page by
/// page) or a PDF link (opened outside the app).
class LibBook {
  final String title;
  final String? author;
  final String? category;
  final int? turathId;
  final String? pdfUrl;
  final int? pages;

  /// Catalog size in bytes (Turath only); used to rank big works first.
  final int size;

  const LibBook({
    required this.title,
    this.author,
    this.category,
    this.turathId,
    this.pdfUrl,
    this.pages,
    this.size = 0,
  });

  bool get isText => turathId != null;
  String get key => turathId != null ? 't$turathId' : 'p${pdfUrl.hashCode}';

  Map<String, dynamic> toJson() => {
        'title': title,
        'author': author,
        'category': category,
        'turath_id': turathId,
        'pdf_url': pdfUrl,
        'pages': pages,
      };

  factory LibBook.fromJson(Map j) => LibBook(
        title: (j['title'] as String).trim(),
        author: (j['author'] as String?)?.trim(),
        category: j['category'] as String?,
        turathId: (j['turath_id'] as num?)?.toInt(),
        pdfUrl: j['pdf_url'] as String?,
        pages: (j['pages'] as num?)?.toInt(),
      );
}

/// One heading in a book's table of contents.
class BookHeading {
  final String title;
  final int level;
  final int page;
  const BookHeading(this.title, this.level, this.page);
}

class BookIndex {
  final List<BookHeading> headings;
  final int pages;
  const BookIndex(this.headings, this.pages);
}

/// One page of a Turath book.
class BookPage {
  final String text;
  final String? volume;
  final int? printedPage;
  const BookPage(this.text, this.volume, this.printedPage);
}

/// The library: books picked in the dashboard, the full Turath catalog for
/// search, Turath pages (cached on disk for offline reading) and IslamHouse.
class BooksService {
  BooksService._();
  static final BooksService instance = BooksService._();

  static const _api = 'https://api.turath.io';
  static const _catalogUrl = 'https://files.turath.io/data-v3.json';
  static const _islamHouse =
      'https://api3.islamhouse.com/v3/paV29H2gm56kvLPy/main/books/ar/ar';

  static const _kFeatured = 'library_featured';
  static const _kRecent = 'library_recent';
  static String _kLast(int id) => 'library_last_$id';
  static const _kFont = 'library_font_size';
  static const _kTheme = 'library_theme';

  final ValueNotifier<List<LibBook>> featured = ValueNotifier(const []);
  final ValueNotifier<List<LibBook>> recent = ValueNotifier(const []);
  Set<int> _hiddenTurath = {};
  Set<String> _hiddenPdf = {};

  List<String>? _catalogKeys;
  Future<List<LibBook>>? _catalogLoading;

  bool _loaded = false;

  /// Featured books from the dashboard (cached for offline use).
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    _applyRows(prefs.getString(_kFeatured));
    recent.value = _decodeList(prefs.getString(_kRecent));
    if (!Backend.isReady) return;
    try {
      final rows = await Backend.client
          .from('books')
          .select('source,turath_id,title,author,category,pdf_url,pages,'
              'featured,hidden,sort')
          .order('sort', ascending: true);
      final s = jsonEncode(rows);
      await prefs.setString(_kFeatured, s);
      _applyRows(s);
    } catch (e) {
      _loaded = false;
      debugPrint('library: $e');
    }
  }

  void _applyRows(String? json) {
    if (json == null) return;
    final rows = (jsonDecode(json) as List).cast<Map>();
    _hiddenTurath = {
      for (final r in rows)
        if (r['hidden'] == true && r['turath_id'] != null)
          (r['turath_id'] as num).toInt()
    };
    _hiddenPdf = {
      for (final r in rows)
        if (r['hidden'] == true && r['pdf_url'] != null) r['pdf_url'] as String
    };
    featured.value = [
      for (final r in rows)
        if (r['featured'] == true && r['hidden'] != true) LibBook.fromJson(r)
    ];
  }

  List<LibBook> _decodeList(String? s) {
    if (s == null) return const [];
    try {
      return (jsonDecode(s) as List)
          .map((e) => LibBook.fromJson(e as Map))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  // ---------------------------------------------------------------------------
  // Catalog search (all Turath titles, downloaded once and refreshed weekly)
  // ---------------------------------------------------------------------------
  Future<List<LibBook>> catalog() => _catalogLoading ??= _loadCatalog();

  Future<List<LibBook>> _loadCatalog() async {
    try {
      final dir = await _dir();
      final f = File('${dir.path}/catalog.json');
      String? body;
      final fresh = f.existsSync() &&
          DateTime.now().difference(f.lastModifiedSync()).inDays < 7;
      if (!fresh) {
        try {
          final res = await http
              .get(Uri.parse(_catalogUrl))
              .timeout(const Duration(seconds: 40));
          if (res.statusCode == 200) {
            body = utf8.decode(res.bodyBytes);
            await f.writeAsString(body);
          }
        } catch (_) {}
      }
      body ??= f.existsSync() ? await f.readAsString() : null;
      if (body == null) {
        _catalogLoading = null;
        return const [];
      }
      final list = await compute(_parseCatalog, body);
      _catalogKeys = [
        for (final b in list) searchKey('${b.title} ${b.author ?? ''}')
      ];
      return list;
    } catch (e) {
      debugPrint('library catalog: $e');
      _catalogLoading = null;
      return const [];
    }
  }

  /// Titles and authors matching [query]; big works first.
  Future<List<LibBook>> search(String query) async {
    final words = query
        .split(RegExp(r'\s+'))
        .map(searchKey)
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return const [];
    final all = await catalog();
    final keys = _catalogKeys ?? const [];
    final out = <LibBook>[];
    for (var i = 0; i < all.length && i < keys.length; i++) {
      final b = all[i];
      if (_hiddenTurath.contains(b.turathId)) continue;
      if (words.every(keys[i].contains)) out.add(b);
    }
    final q = searchKey(query);
    out.sort((a, b) {
      // Titles that start with the query first, then the bigger book.
      final sa = searchKey(a.title).startsWith(q) ? 0 : 1;
      final sb = searchKey(b.title).startsWith(q) ? 0 : 1;
      if (sa != sb) return sa - sb;
      return b.size.compareTo(a.size);
    });
    // Dashboard PDF books match too.
    final pdfs = featured.value.where((b) =>
        !b.isText &&
        words.every(searchKey('${b.title} ${b.author ?? ''}').contains));
    return [...pdfs, ...out.take(300)];
  }

  bool isHiddenPdf(String url) => _hiddenPdf.contains(url);

  // ---------------------------------------------------------------------------
  // Reading
  // ---------------------------------------------------------------------------
  Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    final d = Directory('${base.path}/library');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  Future<Directory> _bookDir(int id) async {
    final d = Directory('${(await _dir()).path}/$id');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  /// Table of contents and page count of a Turath book.
  Future<BookIndex> index(int id) async {
    final f = File('${(await _bookDir(id)).path}/index.json');
    String? body;
    if (f.existsSync()) {
      body = await f.readAsString();
    } else {
      final res = await http
          .get(Uri.parse('$_api/book?id=$id&include=indexes&ver=3'))
          .timeout(const Duration(seconds: 25));
      if (res.statusCode != 200) return const BookIndex([], 0);
      body = utf8.decode(res.bodyBytes);
      await f.writeAsString(body);
    }
    final d = jsonDecode(body) as Map;
    final idx = (d['indexes'] as Map?) ?? const {};
    final list = (idx['headings'] as List?) ?? const [];
    return BookIndex([
      for (final h in list)
        BookHeading(_stripTags((h['title'] as String).trim()),
            (h['level'] as num?)?.toInt() ?? 1, (h['page'] as num).toInt())
    ], (idx['page_map'] as List?)?.length ?? 0);
  }

  final Map<String, Future<BookPage?>> _inflight = {};

  /// One page (1-based). Read from disk when cached.
  Future<BookPage?> page(int id, int pg) =>
      _inflight.putIfAbsent('$id:$pg', () => _page(id, pg)).whenComplete(() {
        _inflight.remove('$id:$pg');
      });

  Future<BookPage?> _page(int id, int pg) async {
    final f = File('${(await _bookDir(id)).path}/$pg.json');
    String? body;
    if (f.existsSync()) {
      body = await f.readAsString();
    } else {
      final res = await http
          .get(Uri.parse('$_api/page?book_id=$id&pg=$pg&ver=3'))
          .timeout(const Duration(seconds: 25));
      if (res.statusCode != 200) return null;
      body = utf8.decode(res.bodyBytes);
      await f.writeAsString(body);
    }
    final d = jsonDecode(body) as Map;
    Map meta = const {};
    final m = d['meta'];
    if (m is String) {
      meta = jsonDecode(m) as Map;
    } else if (m is Map) {
      meta = m;
    }
    return BookPage(
      d['text'] as String? ?? '',
      meta['vol']?.toString(),
      (meta['page'] as num?)?.toInt(),
    );
  }

  Future<int> lastPage(int id) async =>
      (await SharedPreferences.getInstance()).getInt(_kLast(id)) ?? 1;

  Future<void> saveLastPage(int id, int pg) async =>
      (await SharedPreferences.getInstance()).setInt(_kLast(id), pg);

  /// Remembers [b] at the front of "continue reading".
  Future<void> markOpened(LibBook b) async {
    final list = [b, ...recent.value.where((e) => e.key != b.key)]
        .take(12)
        .toList();
    recent.value = list;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kRecent, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  Future<double> fontSize() async =>
      (await SharedPreferences.getInstance()).getDouble(_kFont) ?? 20;
  Future<void> setFontSize(double v) async =>
      (await SharedPreferences.getInstance()).setDouble(_kFont, v);
  Future<int> readerTheme() async =>
      (await SharedPreferences.getInstance()).getInt(_kTheme) ?? 0;
  Future<void> setReaderTheme(int v) async =>
      (await SharedPreferences.getInstance()).setInt(_kTheme, v);

  // ---------------------------------------------------------------------------
  // IslamHouse (PDF books, opened outside the app)
  // ---------------------------------------------------------------------------
  Future<List<LibBook>> islamHouse(int page) async {
    final res = await http
        .get(Uri.parse('$_islamHouse/$page/24/json'))
        .timeout(const Duration(seconds: 25));
    if (res.statusCode != 200) return const [];
    final d = jsonDecode(utf8.decode(res.bodyBytes)) as Map;
    final out = <LibBook>[];
    for (final x in (d['data'] as List? ?? const [])) {
      final atts = (x['attachments'] as List?) ?? const [];
      final pdf = atts
          .cast<Map>()
          .where((a) => '${a['extension_type']}'.toUpperCase() == 'PDF')
          .map((a) => a['url'] as String?)
          .firstWhere((u) => u != null && u.isNotEmpty, orElse: () => null);
      if (pdf == null) continue;
      final by = (x['prepared_by'] as List?) ?? const [];
      out.add(LibBook(
        title: (x['title'] as String).trim(),
        author: by.isEmpty ? null : (by.first['title'] as String?)?.trim(),
        category: 'IslamHouse',
        pdfUrl: pdf,
      ));
    }
    return out;
  }
}

List<LibBook> _parseCatalog(String body) {
  final d = jsonDecode(body) as Map;
  final authors = (d['authors'] as Map?) ?? const {};
  final cats = (d['cats'] as Map?) ?? const {};
  final out = <LibBook>[];
  for (final b in ((d['books'] as Map?) ?? const {}).values) {
    final a = authors['${b['author_id']}'];
    final c = cats['${b['cat_id']}'];
    out.add(LibBook(
      title: (b['name'] as String).trim(),
      author: a == null ? null : (a['name'] as String?)?.trim(),
      category: c == null ? null : c['name'] as String?,
      turathId: (b['id'] as num).toInt(),
      pages: (b['page_count'] as num?)?.toInt(),
      size: (b['size'] as num?)?.toInt() ?? 0,
    ));
  }
  return out;
}

String _stripTags(String s) => s.replaceAll(RegExp(r'<[^>]*>'), '');
