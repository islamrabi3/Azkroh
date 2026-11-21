import 'dart:async';

import 'package:azkroh_app/features/presentation/screens/quran_screen_locally/mushaf_screen.dart'
    show MushafPalette;
import 'package:shared_preferences/shared_preferences.dart';
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
/// `Navigator.pop`, so the Mushaf can jump to it. Follows the Mushaf's
/// day / night palette.
class QuranSearchScreen extends StatefulWidget {
  final MushafPalette palette;

  const QuranSearchScreen({super.key, this.palette = MushafPalette.light});

  /// Opens the search as a light overlay (fade + slight rise).
  static Route<List<int>> route(MushafPalette palette) => PageRouteBuilder(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, __, ___) => QuranSearchScreen(palette: palette),
        transitionsBuilder: (_, a, __, child) => FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.03), end: Offset.zero)
                .animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
            child: child,
          ),
        ),
      );

  @override
  State<QuranSearchScreen> createState() => _QuranSearchScreenState();
}

class _QuranSearchScreenState extends State<QuranSearchScreen> {
  static const _prefRecent = 'quran_search_recent';

  final _ctrl = TextEditingController();
  Timer? _debounce;
  String _q = '';
  List<AyahHit> _results = const [];
  List<String> _recent = const [];

  /// Suggestion label -> query.
  static const _suggestions = <String, String>{
    'آية الكرسي': 'الله لا اله الا هو الحي القيوم',
    'الصبر': 'الصابرين',
    'الرحمة': 'رحمة',
    'الجنة': 'جنات',
    'التوبة': 'توبوا',
    'الوالدين': 'بالوالدين احسانا',
    'الدعاء': 'ربنا',
    'الصلاة': 'اقيموا الصلاة',
  };

  MushafPalette get p => widget.palette;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((s) {
      if (mounted) setState(() => _recent = s.getStringList(_prefRecent) ?? []);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () => _run(v));
  }

  void _run(String v) {
    if (!mounted) return;
    setState(() {
      _q = v.trim();
      _results = QuranSearchIndex.instance.search(_q);
    });
  }

  void _use(String query) {
    _ctrl.text = query;
    _ctrl.selection = TextSelection.collapsed(offset: query.length);
    _run(query);
  }

  Future<void> _remember(String q) async {
    if (q.length < 2) return;
    final list = [q, ..._recent.where((e) => e != q)].take(8).toList();
    final s = await SharedPreferences.getInstance();
    await s.setStringList(_prefRecent, list);
  }

  Future<void> _clearRecent() async {
    final s = await SharedPreferences.getInstance();
    await s.remove(_prefRecent);
    setState(() => _recent = const []);
  }

  void _open(AyahHit h) {
    HapticFeedback.selectionClick();
    _remember(_q);
    Navigator.pop(context, [h.surah, h.ayah]);
  }

  @override
  Widget build(BuildContext context) {
    final dark = p.background.computeLuminance() < 0.2;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Directionality(
        textDirection: AppLocale.direction,
        child: Scaffold(
          backgroundColor: p.background,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _bar(),
                Expanded(
                  child: _q.length < 2
                      ? _idle()
                      : _results.isEmpty
                          ? _empty()
                          : _list(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bar() {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: p.pill,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(Icons.search_rounded, color: p.muted, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      autofocus: true,
                      onChanged: _onChanged,
                      onSubmitted: _run,
                      textInputAction: TextInputAction.search,
                      cursorColor: p.accent,
                      style: TextStyle(
                          fontFamily: 'AppSans', color: p.text, fontSize: 16),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: tr('ابحث عن آية أو كلمة'),
                        hintStyle: TextStyle(
                            fontFamily: 'AppSans', color: p.muted, fontSize: 15),
                      ),
                    ),
                  ),
                  if (_ctrl.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _ctrl.clear();
                        _run('');
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Icon(Icons.cancel_rounded,
                            color: p.muted.withOpacity(0.7), size: 20),
                      ),
                    )
                  else
                    const SizedBox(width: 12),
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: p.accent),
            child: Text(tr('إلغاء'),
                style: const TextStyle(
                    fontFamily: 'AppSans',
                    fontWeight: FontWeight.w600,
                    fontSize: 15)),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, VoidCallback onTap, {IconData? icon}) {
    return Material(
      color: p.pill,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: p.muted),
                const SizedBox(width: 6),
              ],
              Text(label,
                  style: TextStyle(
                      fontFamily: 'AppSans', color: p.text, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String t, {Widget? trailing}) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
        child: Row(
          children: [
            Text(t,
                style: TextStyle(
                    fontFamily: 'AppSans',
                    color: p.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            if (trailing != null) trailing,
          ],
        ),
      );

  Widget _idle() {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (_recent.isNotEmpty) ...[
          _label(tr('عمليات البحث الأخيرة'),
              trailing: GestureDetector(
                onTap: _clearRecent,
                child: Text(tr('مسح'),
                    style: TextStyle(
                        fontFamily: 'AppSans', color: p.accent, fontSize: 13)),
              )),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _recent
                  .map((r) => _chip(r, () => _use(r),
                      icon: Icons.history_rounded))
                  .toList(),
            ),
          ),
        ],
        _label(tr('اقتراحات')),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestions.entries
                .map((e) => _chip(tr(e.key), () => _use(e.value)))
                .toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
          child: Text(
              tr('اكتب أي كلمة أو جزءاً من آية بدون تشكيل، وستظهر النتائج فوراً'),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'AppSans',
                  color: p.muted,
                  fontSize: 13.5,
                  height: 1.7)),
        ),
      ],
    );
  }

  Widget _empty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded, size: 44, color: p.muted),
              const SizedBox(height: 10),
              Text(tr('لا توجد نتائج'),
                  style: TextStyle(
                      fontFamily: 'AppSans', color: p.text, fontSize: 16)),
              const SizedBox(height: 4),
              Text(tr('جرّب كلمة أخرى أو جزءاً أقصر من الآية'),
                  style: TextStyle(
                      fontFamily: 'AppSans', color: p.muted, fontSize: 13)),
            ],
          ),
        ),
      );

  Widget _list() {
    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverToBoxAdapter(
          child: _label(
              '${AppLocale.digits(_results.length)} ${tr('نتيجة')}'),
        ),
        PagedSliverList<AyahHit>(
          items: _results,
          pageSize: 25,
          padding: const EdgeInsets.only(bottom: 24),
          itemBuilder: (_, h, i) => _row(h, i),
        ),
      ],
    );
  }

  Widget _row(AyahHit h, int i) {
    return InkWell(
      onTap: () => _open(h),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        decoration: BoxDecoration(
          border: Border(
            top: i == 0
                ? BorderSide.none
                : BorderSide(color: p.pill, width: 1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                    '${AppLocale.isRtl ? 'سورة ' : ''}${surahName(h.surah)} • ${AppLocale.digits(h.ayah)}',
                    style: TextStyle(
                        fontFamily: 'AppSans',
                        color: p.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('${tr('صفحة')} ${AppLocale.digits(h.page)}',
                    style: TextStyle(
                        fontFamily: 'AppSans', color: p.muted, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 6),
            Text(h.text,
                textDirection: TextDirection.rtl,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                // Uthmani Hafs text needs the KFGQPC Hafs font bundled
                // with qcf_quran_plus.
                style: TextStyle(
                    fontFamily: 'hafs',
                    package: 'qcf_quran_plus',
                    fontSize: 21,
                    height: 1.85,
                    color: p.text)),
          ],
        ),
      ),
    );
  }
}
