import 'package:azkroh_app/features/core/services/books_service.dart';
import 'package:azkroh_app/features/core/widgets/app_loader.dart';
import 'package:azkroh_app/l10n/app_locale.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class _ReaderTheme {
  final String name;
  final Color bg;
  final Color text;
  final Color muted;
  final Color accent;
  final Color bar;
  const _ReaderTheme(
      this.name, this.bg, this.text, this.muted, this.accent, this.bar);
}

const _themes = [
  _ReaderTheme('فاتح', Color(0xFFFBF8F1), Color(0xFF1F2A26), Color(0xFF7A837F),
      Color(0xFF0F5C4A), Color(0xFFFFFFFF)),
  _ReaderTheme('ورقي', Color(0xFFF3E6CC), Color(0xFF3E2C1C), Color(0xFF8A7458),
      Color(0xFF8C5A2B), Color(0xFFF8EEDB)),
  _ReaderTheme('ليلي', Color(0xFF111715), Color(0xFFE3DED2), Color(0xFF8C948F),
      Color(0xFFD4AF37), Color(0xFF1A2220)),
];

/// Reads a Turath book page by page. Pages are cached on disk, so a page
/// read once opens offline.
class BookReaderScreen extends StatefulWidget {
  final LibBook book;
  const BookReaderScreen({super.key, required this.book});

  @override
  State<BookReaderScreen> createState() => _BookReaderScreenState();
}

class _BookReaderScreenState extends State<BookReaderScreen> {
  final _svc = BooksService.instance;
  late final int _id = widget.book.turathId!;
  PageController? _pc;
  int _pages = 0;
  int _page = 1;
  List<BookHeading> _headings = const [];
  double _font = 20;
  int _theme = 0;
  bool _bars = true;
  BookPage? _current;
  String? _error;

  _ReaderTheme get _t => _themes[_theme];

  @override
  void initState() {
    super.initState();
    _svc.markOpened(widget.book);
    _init();
  }

  Future<void> _init() async {
    _font = await _svc.fontSize();
    _theme = (await _svc.readerTheme()).clamp(0, _themes.length - 1);
    final last = await _svc.lastPage(_id);
    var pages = widget.book.pages ?? 0;
    try {
      final idx = await _svc.index(_id);
      _headings = idx.headings;
      if (idx.pages > 0) pages = idx.pages;
    } catch (_) {
      // Offline and never opened: the page count from the list still works.
    }
    if (!mounted) return;
    if (pages <= 0) {
      setState(() => _error = tr('تعذر تحميل الكتاب، تحقق من الاتصال'));
      return;
    }
    _page = last.clamp(1, pages);
    setState(() {
      _pages = pages;
      _pc = PageController(initialPage: _page - 1);
    });
    _prefetch(_page);
  }

  void _prefetch(int pg) {
    for (final p in [pg + 1, pg + 2]) {
      if (p <= _pages) _svc.page(_id, p).catchError((_) => null);
    }
  }

  void _onPage(int i) {
    _page = i + 1;
    _svc.saveLastPage(_id, _page);
    _prefetch(_page);
    setState(() {});
  }

  void _jump(int pg) {
    final p = pg.clamp(1, _pages);
    _pc?.jumpToPage(p - 1);
  }

  @override
  void dispose() {
    _pc?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _theme == 2 ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: t.bg,
          body: Stack(
            children: [
              Positioned.fill(child: _body()),
              Positioned(top: 0, left: 0, right: 0, child: _topBar()),
              Positioned(bottom: 0, left: 0, right: 0, child: _bottomBar()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, size: 48, color: _t.muted),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'AppSans', color: _t.text)),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  setState(() => _error = null);
                  _init();
                },
                child: Text(tr('إعادة المحاولة'),
                    style: TextStyle(color: _t.accent)),
              ),
            ],
          ),
        ),
      );
    }
    final pc = _pc;
    if (pc == null) return Center(child: AppLoader(color: _t.accent));
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => setState(() => _bars = !_bars),
      child: PageView.builder(
        controller: pc,
        itemCount: _pages,
        onPageChanged: _onPage,
        itemBuilder: (_, i) => _PageView(
          key: ValueKey('$_id:${i + 1}'),
          bookId: _id,
          page: i + 1,
          font: _font,
          theme: _t,
          onLoaded: (p) {
            if (i + 1 == _page && _current != p) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _current = p);
              });
            }
          },
        ),
      ),
    );
  }

  Widget _topBar() {
    final t = _t;
    return AnimatedSlide(
      duration: const Duration(milliseconds: 220),
      offset: _bars ? Offset.zero : const Offset(0, -1.3),
      child: Container(
        decoration: BoxDecoration(
          color: t.bar.withOpacity(0.97),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(_theme == 2 ? 0.4 : 0.06),
                blurRadius: 12,
                offset: const Offset(0, 2)),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 54,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded,
                      size: 20, color: t.text),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.book.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontFamily: 'AppSans',
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: t.text)),
                      if (widget.book.author != null)
                        Text(widget.book.author!,
                            maxLines: 1,
                            style: TextStyle(
                                fontFamily: 'AppSans',
                                fontSize: 11.5,
                                color: t.muted)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: tr('الفهرس'),
                  icon: Icon(Icons.format_list_bulleted_rounded,
                      color: t.accent),
                  onPressed: _pages == 0 ? null : _showIndex,
                ),
                IconButton(
                  tooltip: tr('إعدادات القراءة'),
                  icon: Icon(Icons.text_fields_rounded, color: t.accent),
                  onPressed: _showSettings,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomBar() {
    final t = _t;
    if (_pages == 0) return const SizedBox.shrink();
    final c = _current;
    final where = c == null
        ? ''
        : [
            if (c.volume != null && (c.volume != '1' || _isMultiVolume))
              '${tr('الجزء')} ${c.volume}',
            if (c.printedPage != null) '${tr('ص')} ${c.printedPage}',
          ].join(' · ');
    return AnimatedSlide(
      duration: const Duration(milliseconds: 220),
      offset: _bars ? Offset.zero : const Offset(0, 1.3),
      child: Container(
        decoration: BoxDecoration(
          color: t.bar.withOpacity(0.97),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(_theme == 2 ? 0.4 : 0.06),
                blurRadius: 12,
                offset: const Offset(0, -2)),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(where,
                        style: TextStyle(
                            fontFamily: 'AppSans',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: t.accent)),
                    const Spacer(),
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: _askPage,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: t.muted.withOpacity(0.4)),
                        ),
                        child: Text('$_page / $_pages',
                            style: TextStyle(
                                fontFamily: 'AppSans',
                                fontSize: 12.5,
                                color: t.text)),
                      ),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2.5,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 7),
                    overlayShape: SliderComponentShape.noOverlay,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Slider(
                      min: 1,
                      max: _pages.toDouble(),
                      value: _page.toDouble().clamp(1, _pages.toDouble()),
                      activeColor: t.accent,
                      inactiveColor: t.muted.withOpacity(0.25),
                      onChanged: (v) => setState(() => _page = v.round()),
                      onChangeEnd: (v) => _jump(v.round()),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool get _isMultiVolume => (widget.book.pages ?? _pages) > 1200;

  Future<void> _askPage() async {
    final c = TextEditingController();
    final pg = await showDialog<int>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(tr('انتقل إلى صفحة'),
              style: const TextStyle(fontFamily: 'AppSans')),
          content: TextField(
            controller: c,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(hintText: '1 - $_pages'),
            onSubmitted: (v) => Navigator.pop(ctx, int.tryParse(v)),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(tr('إلغاء'))),
            TextButton(
                onPressed: () => Navigator.pop(ctx, int.tryParse(c.text)),
                child: Text(tr('انتقال'))),
          ],
        ),
      ),
    );
    if (pg != null) _jump(pg);
  }

  void _showIndex() {
    final t = _t;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.bar,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          builder: (_, sc) => Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: t.muted.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(4)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                child: Row(
                  children: [
                    Text(tr('الفهرس'),
                        style: TextStyle(
                            fontFamily: 'AppSans',
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: t.text)),
                    const Spacer(),
                    Text(tr('المصدر: تراث turath.io'),
                        style: TextStyle(
                            fontFamily: 'AppSans',
                            fontSize: 11,
                            color: t.muted)),
                  ],
                ),
              ),
              Expanded(
                child: _headings.isEmpty
                    ? Center(
                        child: Text(tr('لا يوجد فهرس لهذا الكتاب'),
                            style: TextStyle(
                                fontFamily: 'AppSans', color: t.muted)))
                    : ListView.builder(
                        controller: sc,
                        itemCount: _headings.length,
                        itemBuilder: (_, i) {
                          final h = _headings[i];
                          final active = h.page <= _page &&
                              (i + 1 >= _headings.length ||
                                  _headings[i + 1].page > _page);
                          return InkWell(
                            onTap: () {
                              Navigator.pop(ctx);
                              _jump(h.page);
                            },
                            child: Container(
                              color: active
                                  ? t.accent.withOpacity(0.10)
                                  : null,
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  20.0 + (h.level - 1).clamp(0, 4) * 16,
                                  12,
                                  20,
                                  12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(h.title,
                                        style: TextStyle(
                                            fontFamily: 'AppSans',
                                            fontSize: h.level <= 1 ? 15 : 14,
                                            fontWeight: h.level <= 1
                                                ? FontWeight.w800
                                                : FontWeight.w500,
                                            color: active ? t.accent : t.text)),
                                  ),
                                  Text('${h.page}',
                                      style: TextStyle(
                                          fontFamily: 'AppSans',
                                          fontSize: 12,
                                          color: t.muted)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _t.bar,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final t = _t;
          return Directionality(
            textDirection: TextDirection.rtl,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('حجم الخط'),
                        style: TextStyle(
                            fontFamily: 'AppSans',
                            fontWeight: FontWeight.w700,
                            color: t.text)),
                    Row(
                      children: [
                        Text('أ',
                            style: TextStyle(fontSize: 14, color: t.muted)),
                        Expanded(
                          child: Slider(
                            min: 14,
                            max: 34,
                            divisions: 10,
                            value: _font,
                            activeColor: t.accent,
                            onChanged: (v) {
                              setState(() => _font = v);
                              setSheet(() {});
                            },
                            onChangeEnd: _svc.setFontSize,
                          ),
                        ),
                        Text('أ',
                            style: TextStyle(fontSize: 26, color: t.muted)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(tr('لون الصفحة'),
                        style: TextStyle(
                            fontFamily: 'AppSans',
                            fontWeight: FontWeight.w700,
                            color: t.text)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        for (var i = 0; i < _themes.length; i++) ...[
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _theme = i);
                                setSheet(() {});
                                _svc.setReaderTheme(i);
                              },
                              child: Container(
                                height: 52,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _themes[i].bg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    width: _theme == i ? 2 : 1,
                                    color: _theme == i
                                        ? _themes[i].accent
                                        : t.muted.withOpacity(0.3),
                                  ),
                                ),
                                child: Text(tr(_themes[i].name),
                                    style: TextStyle(
                                        fontFamily: 'AppSans',
                                        fontWeight: FontWeight.w700,
                                        color: _themes[i].text)),
                              ),
                            ),
                          ),
                          if (i < _themes.length - 1) const SizedBox(width: 10),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// One page: loads (or reads from cache) and renders Turath markup.
class _PageView extends StatefulWidget {
  final int bookId;
  final int page;
  final double font;
  final _ReaderTheme theme;
  final ValueChanged<BookPage> onLoaded;

  const _PageView({
    super.key,
    required this.bookId,
    required this.page,
    required this.font,
    required this.theme,
    required this.onLoaded,
  });

  @override
  State<_PageView> createState() => _PageViewState();
}

class _PageViewState extends State<_PageView> {
  BookPage? _p;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final p = await BooksService.instance.page(widget.bookId, widget.page);
      if (!mounted) return;
      if (p == null) {
        setState(() => _failed = true);
        return;
      }
      setState(() => _p = p);
      widget.onLoaded(p);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void didUpdateWidget(covariant _PageView old) {
    super.didUpdateWidget(old);
    final p = _p;
    if (p != null) widget.onLoaded(p);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final p = _p;
    if (_failed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, color: t.muted, size: 40),
            const SizedBox(height: 10),
            Text(tr('تعذر تحميل الصفحة'),
                style: TextStyle(fontFamily: 'AppSans', color: t.text)),
            TextButton(
              onPressed: _load,
              child: Text(tr('إعادة المحاولة'),
                  style: TextStyle(color: t.accent)),
            ),
          ],
        ),
      );
    }
    if (p == null) return Center(child: AppLoader(color: t.accent));
    final top = MediaQuery.of(context).padding.top + 70;
    final bottom = MediaQuery.of(context).padding.bottom + 96;
    return ListView(
      padding: EdgeInsets.fromLTRB(22, top, 22, bottom),
      children: _render(p.text, t),
    );
  }

  List<Widget> _render(String raw, _ReaderTheme t) {
    final text = _decode(raw);
    final out = <Widget>[];
    final lines = text.split('\n');
    var footnotes = false;
    final body = TextStyle(
      fontFamily: 'AppSans',
      fontSize: widget.font,
      height: 1.95,
      color: t.text,
    );
    for (final line in lines) {
      if (RegExp(r'^\s*_{4,}\s*$').hasMatch(line)) {
        footnotes = true;
        out.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(
                width: 110, height: 1, color: t.muted.withOpacity(0.5)),
          ),
        ));
        continue;
      }
      if (line.trim().isEmpty) continue;
      final style = footnotes
          ? body.copyWith(fontSize: widget.font * 0.72, color: t.muted, height: 1.7)
          : body;
      out.add(Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text.rich(
          TextSpan(children: _spans(line, style, t)),
          textAlign: TextAlign.justify,
        ),
      ));
    }
    return out;
  }

  /// Turath marks headings with <span data-type="title">; other tags are
  /// dropped.
  List<InlineSpan> _spans(String line, TextStyle style, _ReaderTheme t) {
    final re = RegExp(r'<span[^>]*data-type="title"[^>]*>(.*?)</span>');
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in re.allMatches(line)) {
      if (m.start > last) {
        spans.add(TextSpan(text: _strip(line.substring(last, m.start)), style: style));
      }
      spans.add(TextSpan(
        text: _strip(m.group(1)!),
        style: style.copyWith(
            fontWeight: FontWeight.w800,
            color: t.accent,
            fontSize: style.fontSize! * 1.08),
      ));
      last = m.end;
    }
    if (last < line.length) {
      spans.add(TextSpan(text: _strip(line.substring(last)), style: style));
    }
    return spans;
  }

  static String _strip(String s) => s.replaceAll(RegExp(r'<[^>]*>'), '');

  static String _decode(String s) => s
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&');
}
