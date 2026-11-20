import 'dart:convert';

import 'package:azkroh_app/features/core/services/hadith_library.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// One hadith with its takhrij (narrator, scholar, source, grade).
class Hadith {
  final String? _id;
  final String text;
  final String? narrator; // الراوي
  final String? muhaddith; // المحدث
  final String? source; // المصدر
  final String? number; // الصفحة أو الرقم
  final String? grade; // خلاصة حكم المحدث
  final String? explanation; // الشرح
  final String provider; // الدرر السنية / موسوعة الأحاديث النبوية
  final String? url;

  const Hadith({
    String? id,
    required this.text,
    this.narrator,
    this.muhaddith,
    this.source,
    this.number,
    this.grade,
    this.explanation,
    required this.provider,
    this.url,
  }) : _id = id;

  /// Stable id used for saving/bookmarking.
  String get id => _id ?? 'h_${text.hashCode}_${source ?? ''}_${number ?? ''}';

  bool get isSahih {
    final g = grade ?? '';
    return g.contains('صحيح') && !g.contains('غير صحيح') ||
        g.contains('متفق عليه');
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'narrator': narrator,
        'muhaddith': muhaddith,
        'source': source,
        'number': number,
        'grade': grade,
        'explanation': explanation,
        'provider': provider,
        'url': url,
      };

  factory Hadith.fromJson(Map<String, dynamic> j) => Hadith(
        id: j['id'] as String?,
        text: j['text'] as String,
        narrator: j['narrator'] as String?,
        muhaddith: j['muhaddith'] as String?,
        source: j['source'] as String?,
        number: j['number'] as String?,
        grade: j['grade'] as String?,
        explanation: j['explanation'] as String?,
        provider: j['provider'] as String? ?? 'الدرر السنية',
        url: j['url'] as String?,
      );

  String shareText() {
    final b = StringBuffer(text);
    if (narrator != null) b.write('\n\nالراوي: $narrator');
    if (muhaddith != null) b.write('\nالمحدث: $muhaddith');
    if (source != null) b.write('\nالمصدر: $source');
    if (number != null) b.write('\nالصفحة أو الرقم: $number');
    if (grade != null) b.write('\nخلاصة حكم المحدث: $grade');
    b.write('\n\n— من تطبيق أذكروه');
    return b.toString();
  }
}

class HadithSearchOutcome {
  final List<Hadith> items;
  final int total;
  final String source;

  const HadithSearchOutcome(this.items, this.total, this.source);
}

class HadithSearchException implements Exception {
  final String message;
  HadithSearchException(this.message);
  @override
  String toString() => message;
}

/// Hadith data from the official Dorar API (dorar.net/dorar_api.json),
/// with the Encyclopedia of Translated Prophetic Hadiths (hadeethenc.com) as a
/// fallback for the daily hadith when Dorar is unreachable.
class HadithService {
  static final HadithService _instance = HadithService._internal();
  factory HadithService() => _instance;
  HadithService._internal();

  static const _headers = {
    'Accept': 'application/json, text/javascript, */*; q=0.01',
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36',
  };

  static String dorarWebSearchUrl(String q) =>
      'https://dorar.net/hadith/search?q=${Uri.encodeQueryComponent(q)}';

  /// Dorar refuses non-browser clients (Cloudflare 403). After one refusal
  /// we stop asking for this session and use the offline library.
  bool _dorarBlocked = false;

  /// Unified search: Dorar when reachable, otherwise the bundled library.
  /// Results are cached on the device.
  Future<HadithSearchOutcome> searchAll(String query,
      {bool onlySahih = false}) async {
    final q = query.trim();
    if (q.isEmpty) return const HadithSearchOutcome([], 0, '');

    final box = await _box('hadith_search_cache');
    final cacheKey = '${onlySahih ? 's' : 'a'}|$q';

    if (!_dorarBlocked) {
      final cached = box.get('dorar|$cacheKey') as String?;
      if (cached != null) {
        final list = (jsonDecode(cached) as List)
            .map((e) => Hadith.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        return HadithSearchOutcome(list, list.length, 'الدرر السنية');
      }
      try {
        final list = await search(q, onlySahih: onlySahih)
            .timeout(const Duration(seconds: 10));
        if (list.isNotEmpty) {
          await box.put('dorar|$cacheKey',
              jsonEncode(list.map((h) => h.toJson()).toList()));
          return HadithSearchOutcome(list, list.length, 'الدرر السنية');
        }
      } catch (e) {
        _dorarBlocked = true;
        debugPrint('Dorar unavailable, using offline library: $e');
      }
    }

    final r = await HadithLibrary().search(q, onlySahih: onlySahih);
    return HadithSearchOutcome(r.items, r.total, 'المكتبة المدمجة');
  }

  // ---------------------------------------------------------------------------
  // Saved hadiths
  // ---------------------------------------------------------------------------
  static const savedBox = 'saved_hadiths';

  Future<Box> _box(String name) async =>
      Hive.isBoxOpen(name) ? Hive.box(name) : await Hive.openBox(name);

  Future<Box> savedHadithsBox() => _box(savedBox);

  Future<bool> toggleSaved(Hadith h) async {
    final box = await _box(savedBox);
    if (box.containsKey(h.id)) {
      await box.delete(h.id);
      return false;
    }
    final j = h.toJson()..['saved_at'] = DateTime.now().millisecondsSinceEpoch;
    await box.put(h.id, jsonEncode(j));
    return true;
  }

  Future<List<Hadith>> savedHadiths() async {
    final box = await _box(savedBox);
    final entries = box.values
        .map((v) => jsonDecode(v as String) as Map<String, dynamic>)
        .toList()
      ..sort((a, b) =>
          ((b['saved_at'] ?? 0) as int).compareTo((a['saved_at'] ?? 0) as int));
    return entries.map(Hadith.fromJson).toList();
  }

  /// Search Dorar only. [onlySahih] keeps only hadiths graded sahih.
  Future<List<Hadith>> search(String query, {bool onlySahih = false}) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final uri = Uri.parse(
        'https://dorar.net/dorar_api.json?skey=${Uri.encodeQueryComponent(q)}');
    http.Response res;
    try {
      res = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      throw HadithSearchException(
          'تعذر الاتصال بالدرر السنية. تأكد من الاتصال بالإنترنت.');
    }

    if (res.statusCode != 200) {
      throw HadithSearchException(
          'خدمة الدرر السنية غير متاحة حالياً (${res.statusCode}).');
    }

    String body = utf8.decode(res.bodyBytes);
    // Some responses are wrapped as JSONP: callback({...})
    final start = body.indexOf('{');
    final end = body.lastIndexOf('}');
    if (start < 0 || end < 0) {
      throw HadithSearchException('استجابة غير متوقعة من الدرر السنية.');
    }
    body = body.substring(start, end + 1);

    final decoded = jsonDecode(body) as Map;
    final resultHtml = (decoded['ahadith']?['result'] ?? '').toString();
    final list = compute(parseDorarHtml, resultHtml);
    final parsed = await list;
    return onlySahih ? parsed.where((h) => h.isSahih).toList() : parsed;
  }

  @visibleForTesting
  static List<Hadith> parseDorarHtml(String resultHtml) {
    final doc = html_parser.parseFragment(resultHtml);
    final texts = doc.querySelectorAll('.hadith');
    final infos = doc.querySelectorAll('.hadith-info');
    final out = <Hadith>[];

    for (int i = 0; i < texts.length; i++) {
      var text = texts[i].text.trim();
      text = text.replaceFirst(RegExp(r'^\d+\s*-\s*'), '');
      String? narrator, muhaddith, source, number, grade;

      if (i < infos.length) {
        final subtitles = infos[i].querySelectorAll('.info-subtitle');
        for (final sub in subtitles) {
          final label = sub.text.trim();
          // Value = every node between this subtitle and the next one.
          final buffer = StringBuffer();
          final siblings = sub.parentNode?.nodes;
          if (siblings != null) {
            final idx = siblings.indexOf(sub);
            for (int k = idx + 1; k < siblings.length; k++) {
              final s = siblings[k];
              if (s.attributes['class'] == 'info-subtitle') break;
              buffer.write(s.text);
            }
          }
          final value = buffer
              .toString()
              .replaceAll(RegExp(r'\s+'), ' ')
              .replaceAll('|', '')
              .trim();
          if (value.isEmpty) continue;
          if (label.contains('خلاصة')) {
            grade = value;
          } else if (label.contains('الراوي')) {
            narrator = value;
          } else if (label.contains('المحدث')) {
            muhaddith = value;
          } else if (label.contains('المصدر')) {
            source = value;
          } else if (label.contains('الصفحة')) {
            number = value;
          }
        }
      }

      if (text.isEmpty) continue;
      out.add(Hadith(
        text: text,
        narrator: narrator,
        muhaddith: muhaddith,
        source: source,
        number: number,
        grade: grade,
        provider: 'الدرر السنية',
      ));
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Daily hadith
  // ---------------------------------------------------------------------------
  static const List<String> _dailyTopics = [
    'إنما الأعمال بالنيات',
    'الكلمة الطيبة صدقة',
    'من حسن إسلام المرء',
    'لا يؤمن أحدكم حتى يحب لأخيه',
    'الدين النصيحة',
    'أحب الأعمال إلى الله',
    'اتق الله حيثما كنت',
    'من كان يؤمن بالله واليوم الآخر فليقل خيرا',
    'تبسمك في وجه أخيك',
    'المسلم من سلم المسلمون',
    'الطهور شطر الإيمان',
    'من سلك طريقا يلتمس فيه علما',
    'خيركم من تعلم القرآن وعلمه',
    'كلمتان خفيفتان على اللسان',
    'أقرب ما يكون العبد من ربه وهو ساجد',
    'من صام رمضان إيمانا واحتسابا',
    'الحياء من الإيمان',
    'ارحموا من في الأرض',
    'لا تغضب',
    'إن الله رفيق يحب الرفق',
    'من دل على خير',
    'خير الناس أنفعهم للناس',
    'ما نقصت صدقة من مال',
    'إن الله لا ينظر إلى صوركم',
    'المؤمن القوي خير',
    'احفظ الله يحفظك',
    'يسروا ولا تعسروا',
    'أكمل المؤمنين إيمانا أحسنهم خلقا',
    'الدعاء هو العبادة',
    'من قال سبحان الله وبحمده',
    'البر حسن الخلق',
  ];

  int _dayIndex(DateTime d) =>
      DateTime(d.year, d.month, d.day).difference(DateTime(2024)).inDays;

  /// Hadith of the day. Cached per calendar day.
  Future<Hadith> dailyHadith() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final key = 'daily_hadith_${now.year}-${now.month}-${now.day}';
    final cached = prefs.getString(key);
    if (cached != null) {
      return Hadith.fromJson(jsonDecode(cached) as Map<String, dynamic>);
    }

    final day = _dayIndex(now);
    Hadith? h;

    try {
      final topic = _dailyTopics[day % _dailyTopics.length];
      final results = await search(topic, onlySahih: true)
          .timeout(const Duration(seconds: 8));
      if (results.isNotEmpty) h = results.first;
    } catch (e) {
      debugPrint('Dorar daily hadith failed: $e');
    }

    h ??= await _hadeethEncDaily(day);
    if (h == null) {
      try {
        h = await HadithLibrary().hadithOfDay(day);
      } catch (_) {}
    }

    if (h != null) {
      // Keep only the latest cached day
      for (final k in prefs.getKeys().where((k) => k.startsWith('daily_hadith_'))) {
        await prefs.remove(k);
      }
      await prefs.setString(key, jsonEncode(h.toJson()));
      await prefs.setString('daily_hadith_last', jsonEncode(h.toJson()));
      return h;
    }

    final last = prefs.getString('daily_hadith_last');
    if (last != null) {
      return Hadith.fromJson(jsonDecode(last) as Map<String, dynamic>);
    }
    return _offlineFallback[day % _offlineFallback.length];
  }

  Future<Hadith?> _hadeethEncDaily(int day) async {
    try {
      const categories = ['1', '2', '3', '4', '5'];
      final cat = categories[day % categories.length];
      final listUri = Uri.parse(
          'https://hadeethenc.com/api/v1/hadeeths/list/?language=ar&category_id=$cat&page=1&per_page=1');
      final meta = jsonDecode((await http
              .get(listUri)
              .timeout(const Duration(seconds: 15)))
          .body) as Map;
      final total = int.tryParse('${meta['meta']['total_items']}') ?? 1;
      final page = (day ~/ categories.length) % total + 1;
      final pageUri = Uri.parse(
          'https://hadeethenc.com/api/v1/hadeeths/list/?language=ar&category_id=$cat&page=$page&per_page=1');
      final list = jsonDecode(
          (await http.get(pageUri).timeout(const Duration(seconds: 15)))
              .body) as Map;
      final id = (list['data'] as List).first['id'];
      final one = jsonDecode(utf8.decode((await http
              .get(Uri.parse(
                  'https://hadeethenc.com/api/v1/hadeeths/one/?language=ar&id=$id'))
              .timeout(const Duration(seconds: 15)))
          .bodyBytes)) as Map;
      return Hadith(
        text: (one['hadeeth'] ?? '').toString().trim(),
        source: (one['attribution'] ?? '').toString(),
        grade: (one['grade'] ?? '').toString(),
        explanation: (one['explanation'] ?? '').toString(),
        provider: 'موسوعة الأحاديث النبوية',
        url: 'https://hadeethenc.com/ar/browse/hadith/$id',
      );
    } catch (e) {
      debugPrint('HadeethEnc daily hadith failed: $e');
      return null;
    }
  }

  static const List<Hadith> _offlineFallback = [
    Hadith(
      text:
          'إنما الأعمال بالنيات، وإنما لكل امرئ ما نوى، فمن كانت هجرته إلى دنيا يصيبها، أو إلى امرأة ينكحها، فهجرته إلى ما هاجر إليه',
      narrator: 'عمر بن الخطاب',
      source: 'صحيح البخاري',
      number: '1',
      grade: 'صحيح',
      provider: 'الدرر السنية',
    ),
    Hadith(
      text:
          'كلمتان خفيفتان على اللسان، ثقيلتان في الميزان، حبيبتان إلى الرحمن: سبحان الله وبحمده، سبحان الله العظيم',
      narrator: 'أبو هريرة',
      source: 'صحيح البخاري',
      number: '6406',
      grade: 'صحيح',
      provider: 'الدرر السنية',
    ),
    Hadith(
      text: 'المسلم من سلم المسلمون من لسانه ويده، والمهاجر من هجر ما نهى الله عنه',
      narrator: 'عبدالله بن عمرو',
      source: 'صحيح البخاري',
      number: '10',
      grade: 'صحيح',
      provider: 'الدرر السنية',
    ),
  ];
}
