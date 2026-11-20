import 'package:azkroh_app/l10n/app_locale.dart';
// ignore_for_file: implementation_imports
import 'package:azkroh_app/features/presentation/screens/professional_splash_screen.dart';
import 'package:azkroh_app/features/presentation/screens/quran_screen_locally/tafsir_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:azkroh_app/features/core/services/quran_audio_service.dart';
import 'package:qcf_quran_plus/qcf_quran_plus.dart' as qcf;
import 'package:qcf_quran_plus/src/widgets/quran_page/quran_repository.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mushaf reader: the 604 pages of the Madinah Mushaf (Hafs) rendered with the
/// King Fahd Complex QCF fonts, so every line, word and symbol matches the
/// printed Uthmani script.
class MushafScreen extends StatefulWidget {
  final int initialPage;
  final int? highlightSurah;
  final int? highlightVerse;

  /// Shade the ayah without opening the action bar.
  final bool markOnly;

  const MushafScreen({
    super.key,
    this.initialPage = 1,
    this.highlightSurah,
    this.highlightVerse,
    this.markOnly = false,
  });

  /// Opens the Mushaf at the page containing [surah]:[verse].
  static Route<void> routeTo(int surah, {int verse = 1}) {
    return MaterialPageRoute(
      builder: (_) => MushafScreen(
        initialPage: qcf.getPageNumber(surah, verse),
        highlightSurah: surah,
        highlightVerse: verse,
        markOnly: true,
      ),
    );
  }

  /// Opens the Mushaf directly at the last page the user read.
  static Future<void> openLastRead(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final page = (prefs.getInt('mushaf_last_page') ?? 1).clamp(1, 604);
    // Exact ayah the user last tapped/listened to on that page (if any).
    final s = prefs.getInt('last_ayah_surah');
    final v = prefs.getInt('last_ayah_verse');
    final exact = s != null && v != null && qcf.getPageNumber(s, v) == page;
    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MushafScreen(
        initialPage: page,
        highlightSurah: exact ? s : null,
        highlightVerse: exact ? v : null,
        markOnly: true,
      ),
    ));
  }

  @override
  State<MushafScreen> createState() => _MushafScreenState();
}

/// Mushaf colors for light / dark mode.
class MushafPalette {
  final Color background;
  final Color text;
  final Color muted;
  final Color accent;
  final Color pill;
  final Color selection;
  final Color bookmark;

  const MushafPalette._(this.background, this.text, this.muted, this.accent,
      this.pill, this.selection, this.bookmark);

  static const light = MushafPalette._(
    Color(0xFFFFFBF1),
    Color(0xFF1B1B1B),
    Color(0xFF7A6A4F),
    Color(0xFF0F5C4A),
    Color(0xFFF3EAD6),
    Color(0x4DD4AF37), // gold 30%
    Color(0x260F5C4A), // emerald 15%
  );

  static const dark = MushafPalette._(
    Color(0xFF000000),
    Color(0xFFF2F2F2),
    Color(0xFF9E9E9E),
    Color(0xFFD4AF37),
    Color(0xFF1C1C1E),
    Color(0x4D3E8E7E), // emerald 30%
    Color(0x33D4AF37), // gold 20%
  );
}

class _MushafScreenState extends State<MushafScreen> {
  static const _prefDark = 'mushaf_dark_mode';
  static const _prefTajweed = 'mushaf_tajweed';

  late final PageController _controller;
  late int _page;
  bool _ready = false;
  bool _dark = false;
  bool _tajweed = false;
  bool _showChrome = true;
  int? _bookmarkPage;

  int? _selSurah;
  int? _selVerse;

  /// Bookmarked ayah (always shaded) and "where I stopped" ayah.
  int? _bmSurah;
  int? _bmVerse;
  int? _markSurah;
  int? _markVerse;

  final QuranAudioService _audio = QuranAudioService();
  int? _playingSurah;
  int? _playingVerse;
  RecitationState? _rec;

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage.clamp(1, 604);
    _controller = PageController(initialPage: _page - 1);
    if (widget.markOnly) {
      _markSurah = widget.highlightSurah;
      _markVerse = widget.highlightVerse;
    } else {
      _selSurah = widget.highlightSurah;
      _selVerse = widget.highlightVerse;
    }
    // Fast path: data and fonts were preloaded by the splash screen.
    _ready = QuranRepository.instance.isReady &&
        qcf.QcfFontLoader.isFontLoaded(_page);
    _audio.state.addListener(_onAudio);
    _rec = _audio.state.value;
    _playingSurah = _rec?.surah;
    _playingVerse = _rec?.ayah;
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final systemDark =
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
    _dark = prefs.getBool(_prefDark) ?? systemDark;
    _tajweed = prefs.getBool(_prefTajweed) ?? false;
    _bookmarkPage = prefs.getInt('mushaf_bookmark_page');
    if (_bookmarkPage != null) {
      _bmSurah = prefs.getInt('bookmarkedSurah');
      _bmVerse = prefs.getInt('bookmarkedVerse');
    }
    if (mounted) setState(() {});

    if (!_ready) {
      await Future.wait([
        QuranRepository.instance.ensureLoaded(qcf.totalPagesCount),
        qcf.QcfFontLoader.ensureFontLoaded(_page),
      ]);
      if (!mounted) return;
      setState(() => _ready = true);
    }
    qcf.QcfFontLoader.preloadPages(_page, radius: 3);
    _saveLastRead(_page);
  }

  void _onAudio() {
    final st = _audio.state.value;
    if (!mounted) return;
    setState(() {
      _rec = st;
      _playingSurah = st?.surah;
      _playingVerse = st?.ayah;
    });
    // Follow the recitation across pages.
    if (st?.ayah != null && _ready) {
      final page = qcf.getPageNumber(st!.surah, st.ayah!);
      if (page != _page && _controller.hasClients) {
        _controller.animateToPage(page - 1,
            duration: Duration(milliseconds: 400),
            curve: Curves.easeInOut);
      }
    }
  }

  @override
  void dispose() {
    _audio.state.removeListener(_onAudio);
    _audio.stop();
    _controller.dispose();
    super.dispose();
  }

  MushafPalette get _palette =>
      _dark ? MushafPalette.dark : MushafPalette.light;

  List<qcf.HighlightVerse> get _highlights {
    final list = <qcf.HighlightVerse>[];
    void add(int? s, int? v, Color c) {
      if (s == null || v == null) return;
      list.removeWhere((h) => h.surah == s && h.verseNumber == v);
      list.add(qcf.HighlightVerse(
          surah: s, verseNumber: v, page: qcf.getPageNumber(s, v), color: c));
    }

    add(_bmSurah, _bmVerse, _palette.bookmark);
    add(_markSurah, _markVerse, _palette.selection);
    add(_selSurah, _selVerse, _palette.selection);
    add(_playingSurah, _playingVerse, _palette.selection);
    return list;
  }

  // ---------------------------------------------------------------------------
  // Page metadata
  // ---------------------------------------------------------------------------
  Map _firstEntry(int page) => qcf.getPageData(page).first as Map;

  int _firstSurah(int page) => _firstEntry(page)['surah'] as int;

  int _firstVerse(int page) => _firstEntry(page)['start'] as int;

  int _juz(int page) => qcf.getJuzNumber(_firstSurah(page), _firstVerse(page));

  String _surahLabel(int page, {bool arabic = false}) {
    final entries = qcf.getPageData(page);
    final last = entries.last as Map;
    final n = last['surah'] as int;
    return arabic ? qcf.getSurahNameArabic(n) : surahName(n);
  }

  static String ar(int n) => AppLocale.digits(n);

  static String _arabicDigits(int n) {
    const d = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return n.toString().split('').map((c) => d[int.parse(c)]).join();
  }

  Future<void> _saveLastRead(int page) async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getInt('last_ayah_surah');
    final v = prefs.getInt('last_ayah_verse');
    if (s != null && v != null && qcf.getPageNumber(s, v) == page) {
      await prefs.setInt('mushaf_last_page', page);
      return; // keep the exact ayah
    }
    await prefs.setInt('mushaf_last_page', page);
    await prefs.setInt('lastReadSurah', _firstSurah(page));
    await prefs.setInt('lastReadVerse', _firstVerse(page));
  }

  void _onPageChanged(int pageNumber) {
    _page = pageNumber;
    qcf.QcfFontLoader.preloadPages(pageNumber, radius: 3);
    _saveLastRead(pageNumber);
    setState(() {
      // Selection belongs to a page; drop it when leaving that page.
      if (_selSurah != null &&
          qcf.getPageNumber(_selSurah!, _selVerse!) != pageNumber) {
        _selSurah = null;
        _selVerse = null;
      }
    });
  }

  void _jumpToPage(int page) => _controller.jumpToPage(page - 1);

  // ---------------------------------------------------------------------------
  // Selection & actions
  // ---------------------------------------------------------------------------
  void _select(int surah, int verse) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selSurah == surah && _selVerse == verse) {
        _selSurah = null;
        _selVerse = null;
      } else {
        _selSurah = surah;
        _selVerse = verse;
        _markSurah = null;
        _markVerse = null;
        _showChrome = true;
      }
    });
    _rememberAyah(surah, verse);
  }

  Future<void> _rememberAyah(int surah, int verse) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_ayah_surah', surah);
    await prefs.setInt('last_ayah_verse', verse);
    await prefs.setInt('mushaf_last_page', qcf.getPageNumber(surah, verse));
    await prefs.setInt('lastReadSurah', surah);
    await prefs.setInt('lastReadVerse', verse);
  }

  void _clearSelection() => setState(() {
        _selSurah = null;
        _selVerse = null;
      });

  void _onBackgroundTap() {
    if (_selSurah != null) {
      _clearSelection();
    } else {
      setState(() => _showChrome = !_showChrome);
    }
  }

  String _verseRef(int surah, int verse) {
    final text = cleanVerseText(qcf.getVerse(surah, verse));
    return '﴿$text﴾ [${surahName(surah)}: ${ar(verse)}]';
  }

  Future<void> _bookmarkVerse(int surah, int verse) async {
    final prefs = await SharedPreferences.getInstance();
    final page = qcf.getPageNumber(surah, verse);
    await prefs.setInt('mushaf_bookmark_page', page);
    await prefs.setInt('bookmarkedSurah', surah);
    await prefs.setInt('bookmarkedVerse', verse);
    setState(() {
      _bookmarkPage = page;
      _bmSurah = surah;
      _bmVerse = verse;
    });
    _toast('${tr('تم حفظ العلامة عند الآية')} ${ar(verse)}');
  }

  Future<void> _toggleBookmark() async {
    HapticFeedback.mediumImpact();
    if (_bookmarkPage == _page) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('mushaf_bookmark_page');
      await prefs.remove('bookmarkedSurah');
      await prefs.remove('bookmarkedVerse');
      setState(() {
        _bookmarkPage = null;
        _bmSurah = null;
        _bmVerse = null;
      });
      _toast(tr('تم حذف العلامة'));
    } else {
      await _bookmarkVerse(_firstSurah(_page), _firstVerse(_page));
    }
  }

  Future<void> _toggleDark() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _dark = !_dark);
    await prefs.setBool(_prefDark, _dark);
  }

  Future<void> _toggleTajweed() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _tajweed = !_tajweed);
    await prefs.setBool(_prefTajweed, _tajweed);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg, textAlign: TextAlign.center),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(24, 0, 24, 90),
        duration: Duration(seconds: 2),
      ));
  }

  // ---------------------------------------------------------------------------
  // Audio
  // ---------------------------------------------------------------------------
  Future<void> _playFrom(int surah, int verse) async {
    setState(() {
      _selSurah = null;
      _selVerse = null;
    });
    _rememberAyah(surah, verse);
    try {
      await _audio.playFrom(surah, verse);
    } catch (e) {
      if (mounted) {
        _toast(e.toString().replaceFirst('Exception: ', '').contains(tr('غير متوفرة'))
            ? e.toString().replaceFirst('Exception: ', '')
            : tr('تعذر تشغيل التلاوة، تأكد من الاتصال بالإنترنت'));
      }
    }
  }

  void _stopPlayback() => _audio.stop();

  Future<void> _pickReciter({int? thenPlaySurah, int? thenPlayVerse}) async {
    final current = await _audio.selectedReciter();
    if (!mounted) return;
    final picked = await showModalBottomSheet<Reciter>(
      context: context,
      backgroundColor: _palette.background,
      isScrollControlled: true,
      useSafeArea: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Directionality(
        textDirection: AppLocale.direction,
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.92,
          builder: (ctx, scroll) => ListView(
            controller: scroll,
            padding: EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _palette.muted.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 14),
              Text(tr('اختر القارئ'),
                  style: TextStyle(
                      fontFamily: 'AppSans',
                      color: _palette.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              SizedBox(height: 4),
              Text(tr('تُحفظ التلاوة على جهازك بعد أول استماع وتعمل بدون إنترنت'),
                  style: TextStyle(
                      fontFamily: 'AppSans', color: _palette.muted, fontSize: 12.5)),
              SizedBox(height: 10),
              ...QuranAudioService.reciters.map((r) {
                final sel = r.id == current.id;
                return Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: sel ? _palette.accent.withOpacity(0.12) : _palette.pill,
                    borderRadius: BorderRadius.circular(16),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      onTap: () => Navigator.pop(ctx, r),
                      leading: CircleAvatar(
                        backgroundColor: _palette.accent.withOpacity(0.15),
                        child: Icon(Icons.mic_none_rounded, color: _palette.accent),
                      ),
                      title: Text(tr(r.name),
                          style: TextStyle(
                              fontFamily: 'AppSans',
                              color: _palette.text,
                              fontWeight: FontWeight.w700)),
                      subtitle: Text(tr(r.style),
                          style: TextStyle(
                              fontFamily: 'AppSans', color: _palette.muted)),
                      trailing: sel
                          ? Icon(Icons.check_circle_rounded, color: _palette.accent)
                          : null,
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
    if (picked == null) return;
    await _audio.setReciter(picked.id);
    final st = _audio.state.value;
    final s = thenPlaySurah ?? st?.surah;
    final v = thenPlayVerse ?? st?.ayah ?? 1;
    if (s != null) _playFrom(s, v);
  }

  Future<void> _downloadSurah(int surah) async {
    final r = await _audio.selectedReciter();
    if (!r.hasSurah(surah)) {
      _toast('${tr('هذه السورة غير متوفرة بصوت')} ${r.name}');
      return;
    }
    if (await _audio.isSurahDownloaded(r, surah)) {
      _toast('${tr('سورة')} ${surahName(surah)} ${tr('محفوظة على جهازك بالفعل')}');
      return;
    }
    final progress = ValueNotifier<double>(0);
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final bar = ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: Duration(minutes: 10),
      margin: EdgeInsets.fromLTRB(24, 0, 24, 90),
      content: ValueListenableBuilder<double>(
        valueListenable: progress,
        builder: (_, v, __) => Row(
          children: [
            Expanded(
                child: Text(
                    '${tr('تحميل سورة')} ${surahName(surah)} • ${(v * 100).round()}%')),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  value: v == 0 ? null : v, strokeWidth: 2.5, color: Colors.white),
            ),
          ],
        ),
      ),
    ));
    try {
      await _audio.downloadSurah(r, surah, onProgress: (v) => progress.value = v);
      bar.close();
      _toast('${tr('تم حفظ سورة')} ${surahName(surah)} ${tr('للاستماع بدون إنترنت')}');
    } catch (_) {
      bar.close();
      _toast(tr('تعذر التحميل، تأكد من الاتصال بالإنترنت'));
    }
  }

  // ---------------------------------------------------------------------------
  // Index (surah / juz / page)
  // ---------------------------------------------------------------------------
  void _openIndex() {
    _clearSelection();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _palette.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => _MushafIndexSheet(
        palette: _palette,
        currentPage: _page,
        onSelectPage: (p) {
          Navigator.pop(ctx);
          _jumpToPage(p);
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------
  Widget _pageHeader(BuildContext context, int page) {
    final style = TextStyle(
      color: _palette.muted,
      fontSize: 15,
      fontFamily: 'Amiri',
      fontWeight: FontWeight.w600,
    );
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          // Printed-page header stays Arabic like the paper Mushaf.
          Text('الجزء ${_arabicDigits(_juz(page))}', style: style),
          Spacer(),
          Text(_surahLabel(page, arabic: true), style: style),
        ],
      ),
    );
  }

  Widget _topBar() {
    final p = _palette;
    final bookmarked = _bookmarkPage == _page;
    return AnimatedSize(
      duration: Duration(milliseconds: 220),
      curve: Curves.easeOut,
      child: !_showChrome
          ? SizedBox(width: double.infinity)
          : SafeArea(
              bottom: false,
              child: SizedBox(
                height: 52,
                child: Row(
                  children: [
                    _iconBtn(Icons.arrow_back_ios_new_rounded, tr('رجوع'),
                        () => Navigator.maybePop(context)),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: _openIndex,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${tr('سورة')} ${_surahLabel(_page)}',
                                    style: TextStyle(
                                        fontFamily: 'AppSans',
                                        color: p.text,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16)),
                                Icon(Icons.expand_more_rounded,
                                    color: p.muted, size: 20),
                              ],
                            ),
                            Text(
                                '${tr('الجزء')} ${ar(_juz(_page))} • ${tr('صفحة')} ${ar(_page)}',
                                style: TextStyle(
                                    fontFamily: 'AppSans',
                                    color: p.muted,
                                    fontSize: 11.5)),
                          ],
                        ),
                      ),
                    ),
                    _iconBtn(
                        bookmarked
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        tr('العلامة'),
                        _toggleBookmark,
                        color: bookmarked ? p.accent : null),
                    _iconBtn(
                        _dark
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined,
                        _dark ? tr('الوضع النهاري') : tr('الوضع الليلي'),
                        _toggleDark),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert_rounded, color: p.text),
                      color: p.pill,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      onSelected: (v) {
                        if (v == 'tajweed') _toggleTajweed();
                        if (v == 'index') _openIndex();
                        if (v == 'reciter') _pickReciter();
                        if (v == 'listen') {
                          _playFrom(_firstSurah(_page), _firstVerse(_page));
                        }
                        if (v == 'tafsir') {
                          showTafsirSheet(context,
                              surah: _firstSurah(_page),
                              verse: _firstVerse(_page),
                              dark: _dark);
                        }
                      },
                      itemBuilder: (_) => [
                        _menuItem('index', Icons.list_alt_rounded,
                            tr('فهرس السور والأجزاء')),
                        _menuItem('listen', Icons.play_circle_outline_rounded,
                            tr('استماع من أول الصفحة')),
                        _menuItem('reciter', Icons.record_voice_over_outlined,
                            tr('اختيار القارئ')),
                        _menuItem('tajweed', Icons.palette_outlined,
                            _tajweed ? tr('إخفاء ألوان التجويد') : tr('مصحف التجويد')),
                        _menuItem('tafsir', Icons.menu_book_rounded,
                            tr('تفسير أول الصفحة')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _iconBtn(IconData icon, String tip, VoidCallback onTap,
      {Color? color}) {
    return IconButton(
      tooltip: tip,
      icon: Icon(icon, color: color ?? _palette.text, size: 22),
      onPressed: onTap,
    );
  }

  PopupMenuItem<String> _menuItem(String v, IconData icon, String label) {
    return PopupMenuItem(
      value: v,
      child: Directionality(
        textDirection: AppLocale.direction,
        child: Row(
          children: [
            Icon(icon, color: _palette.accent, size: 20),
            SizedBox(width: 10),
            Text(label,
                style: TextStyle(fontFamily: 'AppSans', color: _palette.text)),
          ],
        ),
      ),
    );
  }

  Widget _bottomArea() {
    final Widget child;
    if (_rec != null) {
      child = _playerBar();
    } else if (_selVerse != null) {
      child = _actionBar(_selSurah!, _selVerse!);
    } else if (_showChrome) {
      child = _pagePill();
    } else {
      child = SizedBox(height: 8, width: double.infinity);
    }
    return SafeArea(
      top: false,
      child: AnimatedSwitcher(
        duration: Duration(milliseconds: 180),
        transitionBuilder: (c, a) => FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween(begin: Offset(0, 0.2), end: Offset.zero)
                .animate(a),
            child: c,
          ),
        ),
        child: KeyedSubtree(
          key: ValueKey(_rec != null
              ? 'play'
              : _selVerse != null
                  ? 'sel$_selSurah:$_selVerse'
                  : 'pill$_showChrome'),
          child: child,
        ),
      ),
    );
  }

  Widget _pagePill() {
    final hizb = qcf.getCurrentHizbTextForPage(_page, isArabic: AppLocale.isRtl);
    final p = _palette;
    return Padding(
      padding: EdgeInsets.only(bottom: 6, top: 4),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 22, vertical: 6),
          decoration: BoxDecoration(
            color: p.pill,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: p.muted.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(ar(_page),
                  style: TextStyle(
                      color: p.text,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Amiri')),
              if (hizb.isNotEmpty) ...[
                Container(
                  width: 4,
                  height: 4,
                  margin: EdgeInsets.symmetric(horizontal: 12),
                  decoration:
                      BoxDecoration(color: p.muted, shape: BoxShape.circle),
                ),
                Text(hizb,
                    style: TextStyle(
                        color: p.text, fontSize: 15, fontFamily: 'Amiri')),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionBar(int surah, int verse) {
    final p = _palette;
    Widget action(IconData icon, String label, VoidCallback onTap) {
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: p.accent, size: 22),
                SizedBox(height: 4),
                Text(label,
                    maxLines: 1,
                    style: TextStyle(
                        fontFamily: 'AppSans',
                        color: p.text,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      margin: EdgeInsets.fromLTRB(12, 4, 12, 8),
      padding: EdgeInsets.fromLTRB(6, 8, 6, 4),
      decoration: BoxDecoration(
        color: p.pill,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(_dark ? 0.5 : 0.08),
              blurRadius: 16,
              offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SizedBox(width: 10),
              Text(
                '${tr('سورة')} ${surahName(surah)} • ${tr('الآية')} ${ar(verse)}',
                style: TextStyle(
                    fontFamily: 'AppSans',
                    color: p.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5),
              ),
              Spacer(),
              InkWell(
                customBorder: CircleBorder(),
                onTap: _clearSelection,
                child: Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded, color: p.muted, size: 20),
                ),
              ),
              SizedBox(width: 6),
            ],
          ),
          Row(
            children: [
              action(Icons.menu_book_rounded, tr('التفسير'), () {
                showTafsirSheet(context,
                    surah: surah, verse: verse, dark: _dark);
              }),
              action(Icons.play_arrow_rounded, tr('استماع'),
                  () => _playFrom(surah, verse)),
              action(Icons.copy_rounded, tr('نسخ'), () {
                Clipboard.setData(ClipboardData(text: _verseRef(surah, verse)));
                _toast(tr('تم نسخ الآية'));
              }),
              action(Icons.ios_share_rounded, tr('مشاركة'),
                  () => Share.share(_verseRef(surah, verse))),
              action(Icons.bookmark_add_outlined, tr('علامة'),
                  () => _bookmarkVerse(surah, verse)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _playerBar() {
    final p = _palette;
    final st = _rec!;
    return Theme(
      data: Theme.of(context).copyWith(visualDensity: VisualDensity.compact),
      child: _playerBarBody(p, st),
    );
  }

  Widget _playerBarBody(MushafPalette p, RecitationState st) {
    return Container(
      margin: EdgeInsets.fromLTRB(12, 4, 12, 8),
      padding: EdgeInsets.fromLTRB(8, 6, 14, 6),
      decoration: BoxDecoration(
        color: p.pill,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(_dark ? 0.5 : 0.08),
              blurRadius: 16,
              offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: () => _pickReciter(),
            child: Padding(
              padding: EdgeInsets.all(6),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: p.accent.withOpacity(0.15),
                child: st.loading
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: p.accent))
                    : Icon(Icons.graphic_eq_rounded, color: p.accent, size: 20),
              ),
            ),
          ),
          SizedBox(width: 6),
          Expanded(
            child: InkWell(
              onTap: () => _pickReciter(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text('${tr(st.reciter.name)} • ${tr(st.reciter.style)}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontFamily: 'AppSans',
                                color: p.muted,
                                fontSize: 11.5)),
                      ),
                      Icon(Icons.expand_more_rounded, size: 16, color: p.muted),
                    ],
                  ),
                  Text(
                      st.ayah == null
                          ? '${tr('سورة')} ${surahName(st.surah)}'
                          : '${tr('سورة')} ${surahName(st.surah)} • ${tr('الآية')} ${ar(st.ayah!)}',
                      style: TextStyle(
                          fontFamily: 'AppSans',
                          color: p.text,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: tr('تحميل السورة'),
            icon: Icon(Icons.download_for_offline_outlined, color: p.muted),
            onPressed: () => _downloadSurah(st.surah),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _audio.repeatAyah,
            builder: (_, rep, __) => IconButton(
              tooltip: rep ? tr('إيقاف التكرار') : tr('تكرار الآية'),
              icon: Icon(
                  rep ? Icons.repeat_one_on_rounded : Icons.repeat_one_rounded,
                  color: rep ? p.accent : p.muted),
              onPressed: () {
                HapticFeedback.selectionClick();
                _audio.repeatAyah.value = !rep;
                _toast(rep ? tr('تم إيقاف التكرار') : tr('سيتم تكرار الآية الحالية'));
              },
            ),
          ),
          IconButton(
            tooltip: st.finished
                ? tr('إعادة الاستماع')
                : st.playing
                    ? tr('إيقاف مؤقت')
                    : tr('تشغيل'),
            icon: Icon(
                st.finished
                    ? Icons.replay_circle_filled_rounded
                    : st.playing
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_fill_rounded,
                color: p.accent,
                size: 36),
            onPressed: _audio.pauseOrResume,
          ),
          IconButton(
            tooltip: tr('إيقاف'),
            icon: Icon(Icons.close_rounded, color: p.muted),
            onPressed: _stopPlayback,
          ),
        ],
      ),
    );
  }

  Widget _loading() {
    final p = _palette;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.9, end: 1),
            duration: Duration(milliseconds: 900),
            curve: Curves.easeInOut,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: AppEmblem(size: 96, background: p.background),
          ),
          SizedBox(height: 22),
          Text(tr('المصحف الشريف'),
              style: TextStyle(
                  fontFamily: 'AppSans',
                  color: p.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          SizedBox(height: 6),
          Text(tr('رواية حفص عن عاصم • مصحف المدينة'),
              style:
                  TextStyle(fontFamily: 'AppSans', color: p.muted, fontSize: 13)),
          SizedBox(height: 22),
          SizedBox(
            width: 90,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                minHeight: 3,
                color: p.accent,
                backgroundColor: p.pill,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _palette;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Directionality(
        textDirection: AppLocale.direction,
        child: Scaffold(
          backgroundColor: p.background,
          body: AnimatedSwitcher(
            duration: Duration(milliseconds: 300),
            child: !_ready
                ? SafeArea(key: ValueKey('l'), child: _loading())
                : Column(
                    key: ValueKey('m'),
                    children: [
                      _topBar(),
                      Expanded(
                        child: GestureDetector(
                          // Single tap only (no double-tap) so verse taps
                          // inside the page react instantly.
                          behavior: HitTestBehavior.translucent,
                          onTap: _onBackgroundTap,
                          child: qcf.QuranPageView(
                            pageController: _controller,
                            highlights: _highlights,
                            isDarkMode: _dark,
                            isTajweed: _tajweed,
                            pageBackgroundColor: p.background,
                            enableTwoPageLayout: true,
                            deferNewPages: false,
                            onPageChanged: _onPageChanged,
                            pageHeaderBuilder: _pageHeader,
                            onVerseTap: _select,
                            onLongPress: (s, v, _) => _select(s, v),
                          ),
                        ),
                      ),
                      _bottomArea(),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Searchable index of surahs, ajzaa and pages.
class _MushafIndexSheet extends StatefulWidget {
  final MushafPalette palette;
  final int currentPage;
  final ValueChanged<int> onSelectPage;

  const _MushafIndexSheet({
    required this.palette,
    required this.currentPage,
    required this.onSelectPage,
  });

  @override
  State<_MushafIndexSheet> createState() => _MushafIndexSheetState();
}

class _MushafIndexSheetState extends State<_MushafIndexSheet> {
  String _q = '';

  static const _juzStarts = [
    1, 22, 42, 62, 82, 102, 121, 142, 162, 182, 201, 222, 242, 262, 282, //
    302, 322, 342, 362, 382, 402, 422, 442, 462, 482, 502, 522, 542, 562,
    582,
  ];

  String _norm(String s) => s
      .replaceAll(RegExp('[ً-ٰٟۖ-ۭ]'), '')
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي');

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final ar = _MushafScreenState.ar;
    final surahs = List.generate(114, (i) => i + 1).where((s) {
      if (_q.isEmpty) return true;
      return _norm(qcf.getSurahNameArabic(s)).contains(_norm(_q)) ||
          qcf.getSurahNameEnglish(s).toLowerCase().contains(_q.toLowerCase()) ||
          qcf.getSurahName(s).toLowerCase().contains(_q.toLowerCase()) ||
          s.toString() == _q;
    }).toList();

    return Directionality(
      textDirection: AppLocale.direction,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (ctx, scroll) => DefaultTabController(
          length: 2,
          child: Column(
            children: [
              SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: p.muted.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  onChanged: (v) => setState(() => _q = v.trim()),
                  style: TextStyle(fontFamily: 'AppSans', color: p.text),
                  decoration: InputDecoration(
                    hintText: tr('ابحث عن سورة أو اكتب رقم الصفحة'),
                    hintStyle:
                        TextStyle(fontFamily: 'AppSans', color: p.muted),
                    prefixIcon: Icon(Icons.search_rounded, color: p.muted),
                    filled: true,
                    fillColor: p.pill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                  keyboardType: TextInputType.text,
                  onSubmitted: (v) {
                    final n = int.tryParse(v.trim());
                    if (n != null && n >= 1 && n <= 604) widget.onSelectPage(n);
                  },
                ),
              ),
              TabBar(
                labelColor: p.accent,
                unselectedLabelColor: p.muted,
                indicatorColor: p.accent,
                labelStyle: TextStyle(
                    fontFamily: 'AppSans', fontWeight: FontWeight.w700),
                tabs: [Tab(text: tr('السور')), Tab(text: tr('الأجزاء'))],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    ListView.separated(
                      controller: scroll,
                      itemCount: surahs.length,
                      separatorBuilder: (_, __) => Divider(
                          height: 1,
                          indent: 72,
                          color: p.muted.withOpacity(0.15)),
                      itemBuilder: (_, i) {
                        final s = surahs[i];
                        final page = qcf.getPageNumber(s, 1);
                        final makki = qcf
                            .getPlaceOfRevelation(s)
                            .toLowerCase()
                            .startsWith('mak');
                        return ListTile(
                          onTap: () => widget.onSelectPage(page),
                          leading: SizedBox(
                            width: 40,
                            height: 40,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Transform.rotate(
                                  angle: 0.785,
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: p.accent.withOpacity(0.6)),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ),
                                Text(ar(s),
                                    style: TextStyle(
                                        fontFamily: 'AppSans',
                                        color: p.text,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                          title: Text('${tr('سورة')} ${surahName(s)}',
                              style: TextStyle(
                                  fontFamily: 'AppSans',
                                  color: p.text,
                                  fontWeight: FontWeight.w700)),
                          subtitle: Text(
                              '${makki ? 'مكية' : 'مدنية'} • ${ar(qcf.getVerseCount(s))} ${tr('آية')}',
                              style: TextStyle(
                                  fontFamily: 'AppSans',
                                  color: p.muted,
                                  fontSize: 12)),
                          trailing: Text('${tr('صفحة')} ${ar(page)}',
                              style: TextStyle(
                                  fontFamily: 'AppSans',
                                  color: page <= widget.currentPage &&
                                          (s == 114 ||
                                              qcf.getPageNumber(s + 1, 1) >
                                                  widget.currentPage)
                                      ? p.accent
                                      : p.muted)),
                        );
                      },
                    ),
                    GridView.builder(
                      padding: EdgeInsets.all(16),
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.5,
                      ),
                      itemCount: 30,
                      itemBuilder: (_, i) {
                        final page = _juzStarts[i];
                        final next = i < 29 ? _juzStarts[i + 1] : 605;
                        final current = widget.currentPage >= page &&
                            widget.currentPage < next;
                        return InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => widget.onSelectPage(page),
                          child: Container(
                            decoration: BoxDecoration(
                              color: current ? p.accent : p.pill,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${tr('الجزء')} ${ar(i + 1)}',
                                    style: TextStyle(
                                        fontFamily: 'AppSans',
                                        fontWeight: FontWeight.w700,
                                        color: current
                                            ? Colors.white
                                            : p.text)),
                                Text('${tr('صفحة')} ${ar(page)}',
                                    style: TextStyle(
                                        fontFamily: 'AppSans',
                                        fontSize: 12,
                                        color: current
                                            ? Colors.white70
                                            : p.muted)),
                              ],
                            ),
                          ),
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
}
