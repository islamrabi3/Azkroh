import 'package:azkroh_app/features/core/appstyle.dart';
import 'package:azkroh_app/features/core/widgets/paged_list.dart';
import 'package:azkroh_app/l10n/app_locale.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// ignore: implementation_imports
import 'package:qcf_quran_plus/src/data/quran_data.dart' as qdata;

/// One searchable ayah.
class AyahHit {
  final int surah;
  final int ayah;
  final int page;
  final int juz;
  final String text; // Uthmani text for display

  const AyahHit(this.surah, this.ayah, this.page, this.juz, this.text);
}

class _Entry {
  final AyahHit hit;
  final String words; // normalized, single spaces
  final String compact; // normalized, no spaces

  _Entry(this.hit, this.words, this.compact);
}

/// Offline full-text search over all 6236 ayat (simple-spelling text, so
/// users can type without diacritics or Uthmani spelling).
class QuranSearchIndex {
  QuranSearchIndex._();
  static final QuranSearchIndex instance = QuranSearchIndex._();

  List<_Entry>? _entries;

  static String normalize(String s) => s
      .replaceAll(RegExp('[ؐ-ًؚ-ٰٟۖ-ۭـ]'), '')
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي')
      .replaceAll(RegExp(r'[^ء-ي0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  List<_Entry> get _all {
    if (_entries != null) return _entries!;
    final out = <_Entry>[];
    for (final a in qdata.quran) {
      final m = a as Map;
      final simple = (m['aya_text_emlaey'] ?? '').toString();
      final text = (m['aya_text'] ?? '')
          .toString()
          // Line breaks mark Mushaf lines and sit between words.
          .replaceAll('\n', ' ')
          .replaceAll('۩', '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .replaceAll(RegExp(r'\s*[٠-٩]+\s*$'), '')
          .trim();
      final words = normalize(simple);
      out.add(_Entry(
        AyahHit((m['sora'] as num).toInt(), (m['aya_no'] as num).toInt(),
            (m['page'] as num).toInt(), (m['jozz'] as num).toInt(), text),
        words,
        words.replaceAll(' ', ''),
      ));
    }
    return _entries = out;
  }

  /// Exact phrase matches first, then ayat containing every word.
  List<AyahHit> search(String query) {
    final q = normalize(query);
    if (q.length < 2) return const [];
    final words = q.split(' ').where((w) => w.isNotEmpty).toList();
    final compact = q.replaceAll(' ', '');
    final exact = <AyahHit>[];
    final partial = <AyahHit>[];
    for (final e in _all) {
      if (e.words.contains(q) || e.compact.contains(compact)) {
        exact.add(e.hit);
      } else if (words.length > 1 && words.every(e.words.contains)) {
        partial.add(e.hit);
      }
    }
    return [...exact, ...partial];
  }
}

/// Search screen. Returns the tapped ayah as `[surah, ayah]` via
/// `Navigator.pop`, so the caller can open the Mushaf on it.
class QuranSearchScreen extends StatefulWidget {
  const QuranSearchScreen({super.key});

  @override
  State<QuranSearchScreen> createState() => _QuranSearchScreenState();
}

class _QuranSearchScreenState extends State<QuranSearchScreen> {
  String _q = '';
  List<AyahHit> _results = const [];


  void _search(String v) {
    setState(() {
      _q = v.trim();
      _results = QuranSearchIndex.instance.search(_q);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLocale.direction,
      child: Scaffold(
        backgroundColor: AppStyle.background,
        appBar: AppBar(
          backgroundColor: AppStyle.primaryGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: Text(tr('البحث في القرآن'),
              style: const TextStyle(fontWeight: FontWeight.w700)),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(64),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: DebouncedSearchField(
                hint: tr('اكتب كلمة أو جزءاً من الآية'),
                onChanged: _search,
              ),
            ),
          ),
        ),
        body: CustomScrollView(
          physics: const ClampingScrollPhysics(),
          slivers: [
            if (_q.length < 2)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _hint(Icons.manage_search_rounded,
                    tr('ابحث بأي كلمة أو جزء من آية بدون تشكيل، مثل: «الحمد لله رب العالمين»')),
              )
            else if (_results.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _hint(Icons.search_off_rounded, tr('لا توجد نتائج')),
              )
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(
                      '${AppLocale.digits(_results.length)} ${tr('نتيجة')}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppStyle.textDark)),
                ),
              ),
              PagedSliverList<AyahHit>(
                items: _results,
                pageSize: 20,
                spacing: 10,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemBuilder: (_, h, __) => _tile(h),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _hint(IconData icon, String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppStyle.textLight),
            const SizedBox(height: 12),
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppStyle.textLight, height: 1.7)),
          ],
        ),
      ),
    );
  }

  Widget _tile(AyahHit h) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.pop(context, [h.surah, h.ayah]);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7F2EE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                        '${AppLocale.isRtl ? 'سورة ' : ''}${surahName(h.surah)} • ${tr('الآية')} ${AppLocale.digits(h.ayah)}',
                        style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppStyle.primaryGreen)),
                  ),
                  const Spacer(),
                  Text(
                      '${tr('صفحة')} ${AppLocale.digits(h.page)} • ${tr('الجزء')} ${AppLocale.digits(h.juz)}',
                      style: const TextStyle(
                          fontSize: 12, color: AppStyle.textLight)),
                ],
              ),
              const SizedBox(height: 10),
              Text(h.text,
                  textAlign: TextAlign.start,
                  textDirection: TextDirection.rtl,
                  // Uthmani Hafs text needs the KFGQPC Hafs font bundled
                  // with qcf_quran_plus.
                  style: const TextStyle(
                      fontFamily: 'hafs',
                      package: 'qcf_quran_plus',
                      fontSize: 22,
                      height: 1.9,
                      color: AppStyle.textDark)),
            ],
          ),
        ),
      ),
    );
  }
}
