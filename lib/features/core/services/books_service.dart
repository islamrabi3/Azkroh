import 'dart:async';
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

/// One PDF file of a book (multi-volume works have one per volume).
class BookVolume {
  final String label;
  final String url;

  /// File name on Turath, e.g. "san03.pdf".
  final String file;
  const BookVolume(this.label, this.url, [this.file = '']);
}

/// One heading of a book's table of contents, pointing at a PDF page.
class TocEntry {
  final String title;
  final int level;
  final int volume;
  final int page;
  const TocEntry(this.title, this.level, this.volume, this.page);
}

/// A saved place in a book.
class BookMark {
  final int volume;
  final int page;
  final String note;
  final DateTime at;
  const BookMark(this.volume, this.page, this.note, this.at);

  Map<String, dynamic> toJson() =>
      {'v': volume, 'p': page, 'n': note, 't': at.millisecondsSinceEpoch};
  factory BookMark.fromJson(Map j) => BookMark(
        (j['v'] as num).toInt(),
        (j['p'] as num).toInt(),
        j['n'] as String? ?? '',
        DateTime.fromMillisecondsSinceEpoch((j['t'] as num).toInt()),
      );
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
    _featuredAll = [
      for (final r in rows)
        if (r['featured'] == true && r['hidden'] != true) LibBook.fromJson(r)
    ];
    _publishFeatured();
  }

  List<LibBook> _featuredAll = const [];
  Set<int>? _pdfIds;

  /// Turath books without a scanned edition can't be opened, so they are
  /// left out once the catalog says which ones have a PDF.
  void _publishFeatured() {
    final ids = _pdfIds;
    featured.value = ids == null
        ? _featuredAll
        : _featuredAll
            .where((b) => !b.isText || ids.contains(b.turathId))
            .toList();
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
      _pdfIds = {for (final b in list) b.turathId!};
      _publishFeatured();
      return list;
    } catch (e) {
      debugPrint('library catalog: $e');
      _catalogLoading = null;
      return const [];
    }
  }

  /// Sections of the catalog with their books, biggest works first.
  Future<Map<String, List<LibBook>>> sections() async {
    final all = await catalog();
    final out = <String, List<LibBook>>{};
    for (final b in all) {
      if (_hiddenTurath.contains(b.turathId)) continue;
      out.putIfAbsent(b.category ?? 'كتب عامة', () => []).add(b);
    }
    for (final l in out.values) {
      l.sort((a, b) => b.size.compareTo(a.size));
    }
    return out;
  }

  /// Web page for a shared book: shows it, opens the app, or sends to the
  /// store when the app is missing.
  static const shareBase = 'https://azkroh-dashboard.onrender.com/book/';

  static Uri shareLink(LibBook b) => Uri.parse(shareBase).replace(
        queryParameters: {
          if (b.turathId != null) 'id': '${b.turathId}',
          if (b.turathId == null && b.pdfUrl != null) 'pdf': b.pdfUrl!,
          't': b.title,
        },
      );

  /// The book a shared link points at (see [shareLink]).
  Future<LibBook?> bookFromLink(Map<String, String> q) async {
    final title = q['t'] ?? '';
    final id = int.tryParse(q['id'] ?? '');
    if (id != null) {
      final all = await catalog();
      for (final b in all) {
        if (b.turathId == id) return b;
      }
      return LibBook(title: title.isEmpty ? 'كتاب' : title, turathId: id);
    }
    final pdf = q['pdf'];
    if (pdf != null && pdf.startsWith('http')) {
      return LibBook(title: title.isEmpty ? 'كتاب' : title, pdfUrl: pdf);
    }
    return null;
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
  // Reading (PDF of the printed edition, downloaded once per volume)
  // ---------------------------------------------------------------------------
  Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    final d = Directory('${base.path}/library');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  Future<Directory> _bookDir(LibBook b) async {
    final d = Directory('${(await _dir()).path}/${b.key}');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  /// The PDF files of [b]. Turath lists them in the book's metadata; the
  /// list is cached so downloaded books open offline.
  Future<List<BookVolume>> volumes(LibBook b) async {
    if (!b.isText) return [BookVolume('', b.pdfUrl!)];
    final f = File('${(await _bookDir(b)).path}/meta.json');
    String? body;
    try {
      final res = await http
          .get(Uri.parse('$_api/book?id=${b.turathId}&ver=3'))
          .timeout(const Duration(seconds: 25));
      if (res.statusCode == 200) {
        body = utf8.decode(res.bodyBytes);
        await f.writeAsString(body);
      }
    } catch (_) {}
    body ??= f.existsSync() ? await f.readAsString() : null;
    if (body == null) throw const SocketException('offline');
    final meta = (jsonDecode(body) as Map)['meta'] as Map? ?? const {};
    final links = meta['pdf_links'] as Map?;
    final root = (links?['root'] as String?) ?? '';
    final files = ((links?['files'] as List?) ?? const []).cast<String>();
    final base = 'https://files.turath.io/pdf/'
        '${root.split('/').map(Uri.encodeComponent).join('/')}';
    final out = <BookVolume>[];
    final names = [for (final e in files) e.split('|').first];
    final named = [
      for (final e in files)
        e.split('|').length > 1 && e.split('|')[1].trim().isNotEmpty
    ];
    final auto =
        names.length > 1 ? _volumeLabels(names, named) : const <String>[];
    for (final entry in files) {
      final parts = entry.split('|');
      out.add(BookVolume(
          parts.length > 1 && parts[1].trim().isNotEmpty
              ? parts[1].trim()
              : files.length > 1
                  ? auto[out.length]
                  : '',
          '$base/${Uri.encodeComponent(parts[0])}',
          parts[0]));
    }
    return out;
  }

  /// Labels files like "san00.pdf" (cover), "san03.pdf" (volume 3) and
  /// "sansera1.pdf" (an appendix) using the prefix all files share.
  static List<String> _volumeLabels(List<String> names, List<bool> named) {
    var prefix = names.first;
    for (final n in names) {
      while (!n.startsWith(prefix)) {
        prefix = prefix.substring(0, prefix.length - 1);
      }
    }
    var extra = 0;
    return [
      for (var i = 0; i < names.length; i++)
        () {
          final rest = names[i]
              .substring(prefix.length)
              .replaceFirst(RegExp(r'\.pdf$', caseSensitive: false), '');
          final n = int.tryParse(rest);
          if (n == 0) return 'الغلاف';
          if (n != null && n < 1000) return 'الجزء $n';
          if (RegExp(r'^\d+$').hasMatch(rest) || rest.isEmpty) {
            return 'الجزء ${i + 1}';
          }
          if (named[i]) return '';
          extra++;
          return 'ملحق $extra';
        }()
    ];
  }

  /// Table of contents from Turath. Each heading's printed page is taken as
  /// the PDF page (Turath's scans keep the printed numbering), and Turath's
  /// volume names are matched to the PDF files.
  Future<List<TocEntry>> toc(LibBook b, List<BookVolume> vols) async {
    if (!b.isText || vols.isEmpty) return const [];
    final body = await _indexJson(b);
    if (body == null) return const [];
    return compute(_parseToc, [body, vols.map((v) => v.label).toList()]);
  }

  Future<String?> _indexJson(LibBook b) async {
    final f = File('${(await _bookDir(b)).path}/index.json');
    if (f.existsSync()) return f.readAsString();
    final res = await http
        .get(Uri.parse('$_api/book?id=${b.turathId}&include=indexes&ver=3'))
        .timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) return null;
    final body = utf8.decode(res.bodyBytes);
    await f.writeAsString(body);
    return body;
  }

  Future<File> volumeFile(LibBook b, int index) async =>
      File('${(await _bookDir(b)).path}/v$index.pdf');

  Future<bool> isDownloaded(LibBook b, int index) async =>
      (await volumeFile(b, index)).existsSync();

  /// Downloads volume [index] of [b]; [onProgress] gets 0..1 (or null when
  /// the size is unknown).
  Future<File> download(LibBook b, int index, BookVolume v,
      {void Function(double? p)? onProgress, http.Client? client}) async {
    final dest = await volumeFile(b, index);
    if (dest.existsSync()) {
      // Mark as recently used so the cache keeps it.
      dest.setLastModifiedSync(DateTime.now());
      return dest;
    }
    final tmp = File('${dest.path}.part');
    final own = client == null;
    final c = client ?? http.Client();
    try {
      final res = await c.send(http.Request('GET', Uri.parse(v.url)));
      if (res.statusCode != 200) {
        throw HttpException('HTTP ${res.statusCode}');
      }
      final total = res.contentLength;
      var got = 0;
      final sink = tmp.openWrite();
      await for (final chunk in res.stream) {
        sink.add(chunk);
        got += chunk.length;
        onProgress?.call(total == null || total == 0 ? null : got / total);
      }
      await sink.close();
      await tmp.rename(dest.path);
      await _trimCache(keep: b.key);
      return dest;
    } catch (e) {
      if (tmp.existsSync()) tmp.deleteSync();
      rethrow;
    } finally {
      if (own) c.close();
    }
  }

  final Map<String, BookDownload> _downloads = {};

  /// Downloads every volume of [b], one after the other, in the background.
  /// Shared per book, so it keeps going when the reader is closed.
  BookDownload downloadBook(LibBook b, List<BookVolume> vols) {
    final d =
        _downloads.putIfAbsent(b.key, () => BookDownload._(this, b, vols));
    d._start();
    return d;
  }

  /// Downloaded books are a cache: past this size the least recently read
  /// volumes are removed (never the book being read), so the app does not
  /// keep growing on the phone.
  static const cacheLimitBytes = 400 * 1024 * 1024;

  Future<void> _trimCache({required String keep}) async {
    final root = await _dir();
    final files = <File>[];
    for (final d in root.listSync().whereType<Directory>()) {
      if (d.path.endsWith('/$keep')) continue;
      files.addAll(
          d.listSync().whereType<File>().where((f) => f.path.endsWith('.pdf')));
    }
    var total = await cacheSize();
    if (total <= cacheLimitBytes) return;
    files.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
    for (final f in files) {
      if (total <= cacheLimitBytes) break;
      total -= f.lengthSync();
      f.deleteSync();
    }
  }

  /// Bytes used by downloaded books.
  Future<int> cacheSize() async {
    var total = 0;
    for (final e in (await _dir()).listSync(recursive: true)) {
      if (e is File && e.path.endsWith('.pdf')) total += e.lengthSync();
    }
    return total;
  }

  /// Removes every downloaded book.
  Future<void> clearCache() async {
    for (final e in (await _dir()).listSync(recursive: true)) {
      if (e is File && e.path.endsWith('.pdf')) e.deleteSync();
    }
  }

  /// Removes the downloaded files of [b].
  Future<void> deleteDownloads(LibBook b) async {
    final d = await _bookDir(b);
    for (final f in d.listSync()) {
      if (f is File && f.path.endsWith('.pdf')) f.deleteSync();
    }
  }

  static String _kPos(LibBook b) => 'library_pos_${b.key}';
  static String _kMarks(LibBook b) => 'library_marks_${b.key}';

  /// Last [volume, page] read in [b].
  Future<List<int>> position(LibBook b) async {
    final s = (await SharedPreferences.getInstance()).getString(_kPos(b));
    final p = s?.split(':').map(int.tryParse).toList();
    if (p == null || p.length != 2 || p.contains(null)) return const [0, 1];
    return [p[0]!, p[1]!];
  }

  Future<void> savePosition(LibBook b, int volume, int page) async =>
      (await SharedPreferences.getInstance())
          .setString(_kPos(b), '$volume:$page');

  Future<List<BookMark>> bookmarks(LibBook b) async {
    final s = (await SharedPreferences.getInstance()).getString(_kMarks(b));
    if (s == null) return [];
    try {
      return (jsonDecode(s) as List)
          .map((e) => BookMark.fromJson(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveBookmarks(LibBook b, List<BookMark> marks) async =>
      (await SharedPreferences.getInstance()).setString(
          _kMarks(b), jsonEncode(marks.map((m) => m.toJson()).toList()));

  /// Remembers [b] at the front of "continue reading".
  Future<void> markOpened(LibBook b) async {
    final list =
        [b, ...recent.value.where((e) => e.key != b.key)].take(12).toList();
    recent.value = list;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kRecent, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

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
    // Only books with a scanned printed edition can be opened.
    if (b['has_pdf'] != true) continue;
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

/// Background download of all the volumes of one book.
class BookDownload {
  BookDownload._(this._svc, this.book, this.volumes)
      : have = ValueNotifier(List<bool>.filled(volumes.length, false));

  final BooksService _svc;
  final LibBook book;
  final List<BookVolume> volumes;

  /// Which volumes are on the phone.
  final ValueNotifier<List<bool>> have;

  /// Volume being downloaded now, and its progress (0..1 or null).
  final ValueNotifier<int?> active = ValueNotifier(null);
  final ValueNotifier<double?> progress = ValueNotifier(null);
  final ValueNotifier<bool> failed = ValueNotifier(false);

  /// True after the reader stopped the download.
  final ValueNotifier<bool> paused = ValueNotifier(false);
  bool _cancelled = false;
  http.Client? _client;

  final List<int> _queue = [];
  final Map<int, List<Completer<void>>> _waiters = {};
  bool _running = false;

  int get done => have.value.where((h) => h).length;
  bool get complete => done == volumes.length;

  Future<void> _start() async {
    if (_running || _cancelled) return;
    _running = true;
    failed.value = false;
    paused.value = false;
    final h = [
      for (var i = 0; i < volumes.length; i++) await _svc.isDownloaded(book, i)
    ];
    have.value = h;
    for (var i = 0; i < volumes.length; i++) {
      if (!h[i] && !_queue.contains(i)) _queue.add(i);
    }
    _flushWaiters();
    while (_queue.isNotEmpty) {
      final i = _queue.removeAt(0);
      if (have.value[i]) continue;
      active.value = i;
      progress.value = null;
      final client = _client = http.Client();
      try {
        await _svc.download(book, i, volumes[i],
            onProgress: (p) => progress.value = p, client: client);
        have.value = [...have.value]..[i] = true;
        _flushWaiters();
      } catch (e) {
        if (_cancelled) {
          paused.value = true;
        } else {
          failed.value = true;
        }
        _queue.insert(0, i);
        for (final l in _waiters.values) {
          for (final c in l) {
            if (!c.isCompleted) c.completeError(e);
          }
        }
        _waiters.clear();
        break;
      } finally {
        client.close();
        _client = null;
      }
    }
    active.value = null;
    progress.value = null;
    _running = false;
  }

  /// Stops the download now; the part being downloaded is discarded.
  void cancel() {
    if (complete) return;
    _cancelled = true;
    paused.value = true;
    _client?.close();
    for (final l in _waiters.values) {
      for (final c in l) {
        if (!c.isCompleted) c.completeError(const DownloadCancelled());
      }
    }
    _waiters.clear();
  }

  /// Continues after [cancel] or a failure.
  void resume() {
    _cancelled = false;
    paused.value = false;
    _start();
  }

  void _flushWaiters() {
    for (final i in _waiters.keys.toList()) {
      if (have.value.length > i && have.value[i]) {
        for (final c in _waiters.remove(i)!) {
          if (!c.isCompleted) c.complete();
        }
      }
    }
  }

  /// Moves volume [i] to the front of the queue and waits until it is on
  /// the phone.
  Future<void> waitFor(int i) {
    prioritizeFrom(i);
    if (have.value.length > i && have.value[i]) return Future.value();
    if (_cancelled) resume();
    final c = Completer<void>();
    _waiters.putIfAbsent(i, () => []).add(c);
    if (!_running) _start();
    return c.future;
  }

  /// Download order for reading from volume [i]: [i], the volumes after it,
  /// then the ones before it.
  void prioritizeFrom(int i) {
    final missing = <int>[
      for (var k = i; k < volumes.length; k++) k,
      for (var k = 0; k < i; k++) k,
    ].where((k) => have.value.length <= k || !have.value[k]);
    _queue
      ..clear()
      ..addAll(missing);
    if (!_running && missing.isNotEmpty) _start();
  }

  /// Starts again after a failure.
  void retry() => resume();
}

List<TocEntry> _parseToc(List<Object> args) {
  final body = args[0] as String;
  final labels = (args[1] as List).cast<String>();
  final d = jsonDecode(body) as Map;
  final idx = (d['indexes'] as Map?) ?? const {};
  final pageMap = ((idx['page_map'] as List?) ?? const []).cast<String>();
  final textVols = ((idx['volumes'] as List?) ?? const []).cast<String>();

  final map = _volumeMap(textVols, labels);

  final out = <TocEntry>[];
  for (final h in (idx['headings'] as List?) ?? const []) {
    final id = (h['page'] as num?)?.toInt();
    if (id == null || id < 1 || id > pageMap.length) continue;
    final at = pageMap[id - 1];
    final comma = at.lastIndexOf(',');
    if (comma < 0) continue;
    final vol = map[at.substring(0, comma)];
    final page = int.tryParse(at.substring(comma + 1));
    if (vol == null || page == null) continue;
    out.add(TocEntry(
      (h['title'] as String).replaceAll(RegExp(r'<[^>]*>'), '').trim(),
      (h['level'] as num?)?.toInt() ?? 1,
      vol,
      page,
    ));
  }
  return out;
}

class DownloadCancelled implements Exception {
  const DownloadCancelled();
}

/// Turath volume name -> PDF file index ("1" -> «الجزء 1», «المقدمة» ->
/// «المقدمة»; the rest take the remaining appendix files in order).
Map<String, int> _volumeMap(List<String> textVols, List<String> labels) {
  final map = <String, int>{};
  if (labels.length == 1) {
    for (final v in textVols) {
      map[v] = 0;
    }
    return map;
  }
  final used = <int>{};
  final rest = <String>[];
  for (final v in textVols) {
    final n = int.tryParse(v.trim());
    var i = labels.indexOf(n != null ? 'الجزء $n' : v.trim());
    if (i < 0 && n == null) i = labels.indexOf(v.trim());
    if (i >= 0 && !used.contains(i)) {
      map[v] = i;
      used.add(i);
    } else {
      rest.add(v);
    }
  }
  final free = [
    for (var i = 0; i < labels.length; i++)
      if (!used.contains(i) &&
          labels[i] != 'الغلاف' &&
          !labels[i].startsWith('الجزء '))
        i
  ];
  for (var k = 0; k < rest.length && k < free.length; k++) {
    map[rest[k]] = free[k];
  }
  return map;
}
