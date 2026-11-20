import 'package:azkroh_app/features/core/widgets/app_loader.dart';
import 'package:azkroh_app/features/core/utils/share_helper.dart';
import 'package:azkroh_app/l10n/app_locale.dart';
import 'package:azkroh_app/features/core/services/tafsir_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qcf_quran_plus/qcf_quran_plus.dart' as qcf;

/// Removes the trailing ayah number / line break from the Hafs text.
String cleanVerseText(String text) =>
    text
        .replaceAll(RegExp(r'[\s\u0660-\u0669\u06f0-\u06f90-9]+$'), '')
        .replaceAll(RegExp(r'\s*\n\s*'), ' ')
        .trim();

/// Opens the tafsir bottom sheet for [surah]:[verse].
Future<void> showTafsirSheet(
  BuildContext context, {
  required int surah,
  required int verse,
  bool dark = false,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: dark ? Color(0xFF121212) : Color(0xFFFFFBF1),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => TafsirSheet(surah: surah, verse: verse, dark: dark),
  );
}

class TafsirSheet extends StatefulWidget {
  final int surah;
  final int verse;
  final bool dark;

  const TafsirSheet({
    super.key,
    required this.surah,
    required this.verse,
    this.dark = false,
  });

  @override
  State<TafsirSheet> createState() => _TafsirSheetState();
}

class _TafsirSheetState extends State<TafsirSheet> {
  final TafsirService _service = TafsirService();
  late int _surah;
  late int _verse;
  int? _bookId;
  Future<TafsirResult>? _future;
  double _fontSize = 19;

  Color get _bg => widget.dark ? Color(0xFF121212) : Color(0xFFFFFBF1);
  Color get _text => widget.dark ? Color(0xFFEDEDED) : Color(0xFF1F1F1F);
  Color get _muted => widget.dark ? Colors.white54 : Color(0xFF7A6A4F);
  Color get _accent => widget.dark ? Color(0xFFD4AF37) : Color(0xFF0F5C4A);
  Color get _card => widget.dark ? Color(0xFF1E1E1E) : Color(0xFFF3EAD6);

  @override
  void initState() {
    super.initState();
    _surah = widget.surah;
    _verse = widget.verse;
    _service.getPreferredBookId().then((id) {
      if (!mounted) return;
      setState(() {
        _bookId = AppLocale.isArabic ? id : TafsirService.translationId;
        _load();
      });
    });
  }

  void _load() {
    if (_bookId == TafsirService.translationId) {
      final lang = AppLocale.code.value;
      final book = TafsirBook(TafsirService.translationId, tr('ترجمة المعاني'));
      _future = _service
          .getTranslation(_surah, _verse, lang)
          .then((t) => TafsirResult(t, book, '$_surah:$_verse'));
    } else {
      _future = _service.getTafsir(_surah, _verse, bookId: _bookId);
    }
  }

  List<TafsirBook> get _books => [
        if (!AppLocale.isArabic)
          TafsirBook(TafsirService.translationId, tr('ترجمة المعاني')),
        ...TafsirService.books,
      ];

  void _go(int delta) {
    int s = _surah;
    int v = _verse + delta;
    if (v < 1) {
      if (s == 1) return;
      s -= 1;
      v = qcf.getVerseCount(s);
    } else if (v > qcf.getVerseCount(s)) {
      if (s == 114) return;
      s += 1;
      v = 1;
    }
    setState(() {
      _surah = s;
      _verse = v;
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final verseText = cleanVerseText(qcf.getVerse(_surah, _verse));
    return Directionality(
      textDirection: AppLocale.direction,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scroll) => Container(
          color: _bg,
          child: Column(
            children: [
              SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _muted.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: tr('الآية السابقة'),
                      icon: Icon(Icons.chevron_left_rounded, color: _accent),
                      onPressed: () => _go(-1),
                    ),
                    Expanded(
                      child: Text(
                        '${tr('سورة')} ${surahName(_surah)} • ${tr('الآية')} $_verse',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: tr('الآية التالية'),
                      icon: Icon(Icons.chevron_right_rounded, color: _accent),
                      onPressed: () => _go(1),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  children: _books.map((b) {
                    final selected = b.id == _bookId;
                    return Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(tr(b.name)),
                        selected: selected,
                        selectedColor: _accent,
                        backgroundColor: _card,
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : _text,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        onSelected: (_) {
                          if (b.id != TafsirService.translationId) {
                            _service.setPreferredBookId(b.id);
                          }
                          setState(() {
                            _bookId = b.id;
                            _load();
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: EdgeInsets.fromLTRB(18, 12, 18, 32),
                  children: [
                    Container(
                      padding: EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('\uFD3E',
                                style: TextStyle(
                                    fontFamily: 'Amiri-Quran',
                                    fontSize: 24,
                                    color: _accent)),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                verseText,
                                textAlign: TextAlign.center,
                                textDirection: TextDirection.rtl,
                                style: qcf.QuranTextStyles.hafsStyle(
                                  color: _text,
                                  fontSize: 24,
                                  height: 1.9,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text('\uFD3F',
                                style: TextStyle(
                                    fontFamily: 'Amiri-Quran',
                                    fontSize: 24,
                                    color: _accent)),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 14),
                    if (_future == null)
                      _loading()
                    else
                      FutureBuilder<TafsirResult>(
                        future: _future,
                        builder: (context, snap) {
                          if (snap.connectionState != ConnectionState.done) {
                            return _loading();
                          }
                          if (snap.hasError) {
                            return _error(snap.error.toString());
                          }
                          final r = snap.data!;
                          final grouped =
                              r.sourceVerseKey != '$_surah:$_verse';
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.menu_book_rounded,
                                      color: _accent, size: 18),
                                  SizedBox(width: 6),
                                  Text(r.book.name,
                                      style: TextStyle(
                                          color: _accent,
                                          fontWeight: FontWeight.bold)),
                                  Spacer(),
                                  IconButton(
                                    tooltip: tr('تصغير الخط'),
                                    icon: Icon(Icons.text_decrease,
                                        color: _muted, size: 20),
                                    onPressed: () => setState(() => _fontSize =
                                        (_fontSize - 1).clamp(14, 30)),
                                  ),
                                  IconButton(
                                    tooltip: tr('تكبير الخط'),
                                    icon: Icon(Icons.text_increase,
                                        color: _muted, size: 20),
                                    onPressed: () => setState(() => _fontSize =
                                        (_fontSize + 1).clamp(14, 30)),
                                  ),
                                  IconButton(
                                    tooltip: tr('نسخ'),
                                    icon: Icon(Icons.copy_rounded,
                                        color: _muted, size: 20),
                                    onPressed: () {
                                      Clipboard.setData(
                                          ClipboardData(text: r.text));
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                              content: Text(tr('تم نسخ التفسير'))));
                                    },
                                  ),
                                  IconButton(
                                    tooltip: tr('مشاركة'),
                                    icon: Icon(Icons.share_rounded,
                                        color: _muted, size: 20),
                                    onPressed: () => shareText(context, 
                                        '﴿$verseText﴾\n\n${r.book.name}:\n${r.text}'),
                                  ),
                                ],
                              ),
                              if (grouped)
                                Padding(
                                  padding: EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    '${tr('فُسّرت هذه الآية مع ما قبلها')} (${tr('من الآية')} ${AppLocale.digits(r.sourceVerseKey.split(':').last)})',
                                    style:
                                        TextStyle(color: _muted, fontSize: 13),
                                  ),
                                ),
                              SelectableText(
                                r.text,
                                textAlign: TextAlign.justify,
                                // Arabic tafsir is RTL; translations follow
                                // the language direction.
                                textDirection:
                                    r.book.id == TafsirService.translationId
                                        ? AppLocale.direction
                                        : TextDirection.rtl,
                                style: TextStyle(
                                  fontFamily:
                                      r.book.id == TafsirService.translationId
                                          ? 'AppSans'
                                          : 'Amiri',
                                  fontSize: _fontSize,
                                  height: 1.9,
                                  color: _text,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _loading() => Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: AppLoader(color: _accent)),
      );

  Widget _error(String msg) => Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.wifi_off_rounded, color: _muted, size: 40),
            SizedBox(height: 12),
            Text(
              tr('تعذر تحميل هذا التفسير. تأكد من الاتصال بالإنترنت، أو اختر «التفسير الميسر» المتاح بدون إنترنت.'),
              textAlign: TextAlign.center,
              style: TextStyle(color: _text),
            ),
            SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => setState(_load),
              child: Text(tr('إعادة المحاولة'), style: TextStyle(color: _accent)),
            ),
          ],
        ),
      );
}
