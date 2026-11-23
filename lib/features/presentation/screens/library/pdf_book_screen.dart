import 'package:azkroh_app/features/core/appstyle.dart';
import 'package:azkroh_app/features/core/services/books_service.dart';
import 'package:azkroh_app/features/core/widgets/app_loader.dart';
import 'package:azkroh_app/l10n/app_locale.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';

/// Reads the scanned printed edition of a book. Each volume is downloaded
/// once and then opens offline, on the page where the reader stopped.
class PdfBookScreen extends StatefulWidget {
  final LibBook book;
  const PdfBookScreen({super.key, required this.book});

  @override
  State<PdfBookScreen> createState() => _PdfBookScreenState();
}

class _PdfBookScreenState extends State<PdfBookScreen> {
  final _svc = BooksService.instance;
  final _controller = PdfViewerController();

  List<BookVolume> _volumes = const [];
  int _vol = 0;
  int _startPage = 1;
  int _page = 1;
  int _pageCount = 0;
  String? _path;
  double? _progress;
  bool _downloading = false;
  String? _error;
  bool _bars = true;
  int _turns = 0;
  List<BookMark> _marks = [];

  static const _bg = Color(0xFF2A2F2D);

  @override
  void initState() {
    super.initState();
    _svc.markOpened(widget.book);
    _init();
  }

  Future<void> _init() async {
    setState(() => _error = null);
    final pos = await _svc.position(widget.book);
    _marks = await _svc.bookmarks(widget.book);
    try {
      _volumes = await _svc.volumes(widget.book);
    } catch (_) {
      if (mounted) {
        setState(() => _error = tr('تعذر تحميل الكتاب، تحقق من الاتصال'));
      }
      return;
    }
    if (!mounted) return;
    if (_volumes.isEmpty) {
      setState(() => _error = tr('لا توجد نسخة مصورة لهذا الكتاب'));
      return;
    }
    await _openVolume(pos[0].clamp(0, _volumes.length - 1), pos[1]);
  }

  Future<void> _openVolume(int index, int page) async {
    setState(() {
      _vol = index;
      _startPage = page < 1 ? 1 : page;
      _page = _startPage;
      _path = null;
      _error = null;
      _progress = null;
      _downloading = true;
      _pageCount = 0;
    });
    try {
      final f = await _svc.download(widget.book, index, _volumes[index],
          onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      });
      if (!mounted) return;
      setState(() {
        _path = f.path;
        _downloading = false;
      });
      _svc.savePosition(widget.book, index, _startPage);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _error = tr('تعذر تحميل الكتاب، تحقق من الاتصال');
      });
    }
  }

  void _onPage(int? p) {
    if (p == null || p == _page) return;
    setState(() => _page = p);
    _svc.savePosition(widget.book, _vol, p);
  }

  Future<void> _goTo(int vol, int page) async {
    if (vol != _vol) {
      await _openVolume(vol, page);
      return;
    }
    if (_controller.isReady) {
      await _controller.goToPage(
          pageNumber: page.clamp(1, _controller.pageCount));
    }
  }

  bool get _markedHere =>
      _marks.any((m) => m.volume == _vol && m.page == _page);

  Future<void> _toggleMark() async {
    HapticFeedback.selectionClick();
    if (_markedHere) {
      setState(() =>
          _marks.removeWhere((m) => m.volume == _vol && m.page == _page));
      await _svc.saveBookmarks(widget.book, _marks);
      _toast(tr('أزيلت العلامة'));
      return;
    }
    final c = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(tr('علامة على هذه الصفحة'),
              style: const TextStyle(fontFamily: 'AppSans')),
          content: TextField(
            controller: c,
            autofocus: true,
            decoration: InputDecoration(
                hintText: tr('ملاحظة (اختياري): توقفت عند…')),
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(tr('إلغاء'))),
            TextButton(
                onPressed: () => Navigator.pop(ctx, c.text),
                child: Text(tr('حفظ'))),
          ],
        ),
      ),
    );
    if (note == null) return;
    setState(() => _marks
      ..add(BookMark(_vol, _page, note.trim(), DateTime.now()))
      ..sort((a, b) => a.volume != b.volume
          ? a.volume - b.volume
          : a.page - b.page));
    await _svc.saveBookmarks(widget.book, _marks);
    _toast(tr('تم حفظ العلامة'));
  }

  void _toast(String s) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text(s, style: const TextStyle(fontFamily: 'AppSans')),
          duration: const Duration(seconds: 2)));
  }

  String _volLabel(int i) =>
      _volumes.length > 1 ? _volumes[i].label : '';

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: _bg,
          body: Stack(
            children: [
              Positioned.fill(child: _body()),
              Positioned(top: 0, left: 0, right: 0, child: _topBar()),
              if (_path != null)
                Positioned(bottom: 0, left: 0, right: 0, child: _bottomBar()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_error != null) {
      return _message(Icons.wifi_off_rounded, _error!, retry: true);
    }
    if (_downloading || _path == null) return _downloadView();
    final path = _path!;
    return RotatedBox(
      quarterTurns: _turns,
      child: PdfViewer.file(
        path,
        key: ValueKey(path),
        controller: _controller,
        initialPageNumber: _startPage,
        params: PdfViewerParams(
          backgroundColor: _bg,
          margin: 6,
          maxScale: 8,
          textSelectionParams:
              const PdfTextSelectionParams(enabled: false),
          pageDropShadow: const BoxShadow(
              color: Colors.black38, blurRadius: 6, offset: Offset(0, 2)),
          onViewerReady: (doc, c) {
            if (mounted) setState(() => _pageCount = c.pageCount);
          },
          onPageChanged: _onPage,
          onGeneralTap: (ctx, c, d) {
            if (d.type == PdfViewerGeneralTapType.tap) {
              setState(() => _bars = !_bars);
              return true;
            }
            return false;
          },
          pageOverlaysBuilder: (ctx, rect, page) => [
            if (_marks.any(
                (m) => m.volume == _vol && m.page == page.pageNumber))
              Positioned(
                top: 0,
                right: rect.width * 0.06,
                child: Icon(Icons.bookmark_rounded,
                    color: AppStyle.goldColor,
                    size: (rect.width * 0.09).clamp(18, 64)),
              ),
          ],
          loadingBannerBuilder: (ctx, got, total) =>
              const Center(child: AppLoader(color: AppStyle.goldColor)),
        ),
      ),
    );
  }

  Widget _downloadView() {
    final p = _progress;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.menu_book_rounded,
                color: AppStyle.goldColor, size: 54),
            const SizedBox(height: 16),
            Text(widget.book.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: 'AppSans',
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            if (_volumes.length > 1) ...[
              const SizedBox(height: 4),
              Text(_volLabel(_vol),
                  style: const TextStyle(
                      fontFamily: 'AppSans', color: AppStyle.goldColor)),
            ],
            const SizedBox(height: 22),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: p,
                minHeight: 6,
                color: AppStyle.goldColor,
                backgroundColor: Colors.white12,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              p == null
                  ? tr('جارٍ فتح الكتاب…')
                  : '${tr('جارٍ التحميل')} ${(p * 100).round()}%',
              style: const TextStyle(
                  fontFamily: 'AppSans', color: Colors.white70),
            ),
            const SizedBox(height: 6),
            Text(tr('يُحمَّل مرة واحدة ثم يفتح بدون إنترنت'),
                style: const TextStyle(
                    fontFamily: 'AppSans',
                    color: Colors.white38,
                    fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _message(IconData icon, String text, {bool retry = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white54, size: 48),
            const SizedBox(height: 12),
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: 'AppSans', color: Colors.white)),
            if (retry)
              TextButton(
                onPressed: _volumes.isEmpty
                    ? _init
                    : () => _openVolume(_vol, _page),
                child: Text(tr('إعادة المحاولة'),
                    style: const TextStyle(color: AppStyle.goldColor)),
              ),
          ],
        ),
      ),
    );
  }

  BoxDecoration get _barDecoration => BoxDecoration(
        color: const Color(0xFF111614).withOpacity(0.94),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 10),
        ],
      );

  Widget _topBar() {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 220),
      offset: _bars ? Offset.zero : const Offset(0, -1.3),
      child: Container(
        decoration: _barDecoration,
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 20),
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
                          style: const TextStyle(
                              fontFamily: 'AppSans',
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15)),
                      Text(
                        [
                          if (widget.book.author != null) widget.book.author!,
                          if (_volumes.length > 1) _volLabel(_vol),
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: 'AppSans',
                            color: Colors.white60,
                            fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                if (_volumes.length > 1)
                  IconButton(
                    tooltip: tr('الأجزاء'),
                    icon: const Icon(Icons.library_books_rounded,
                        color: AppStyle.goldColor),
                    onPressed: _showVolumes,
                  ),
                IconButton(
                  tooltip: tr('العلامات'),
                  icon: Badge(
                    isLabelVisible: _marks.isNotEmpty,
                    label: Text('${_marks.length}'),
                    backgroundColor: AppStyle.goldColor,
                    textColor: AppStyle.darkGreen,
                    child: const Icon(Icons.bookmarks_outlined,
                        color: Colors.white),
                  ),
                  onPressed: _showMarks,
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded,
                      color: Colors.white),
                  onSelected: (v) async {
                    if (v == 'delete') {
                      await _svc.deleteDownloads(widget.book);
                      if (mounted) Navigator.of(context).maybePop();
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(tr('حذف الكتاب من الجهاز'),
                          style: const TextStyle(fontFamily: 'AppSans')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomBar() {
    final count = _pageCount;
    return AnimatedSlide(
      duration: const Duration(milliseconds: 220),
      offset: _bars ? Offset.zero : const Offset(0, 1.3),
      child: Container(
        decoration: _barDecoration,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (count > 1)
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2.5,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 7),
                      overlayShape: SliderComponentShape.noOverlay,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      child: Slider(
                        min: 1,
                        max: count.toDouble(),
                        value: _page.clamp(1, count).toDouble(),
                        activeColor: AppStyle.goldColor,
                        inactiveColor: Colors.white24,
                        onChanged: (v) => setState(() => _page = v.round()),
                        onChangeEnd: (v) => _controller.goToPage(
                            pageNumber: v.round(),
                            duration: Duration.zero),
                      ),
                    ),
                  ),
                Row(
                  children: [
                    _barButton(
                      _markedHere
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_add_outlined,
                      _markedHere ? tr('إزالة العلامة') : tr('علامة'),
                      _toggleMark,
                      active: _markedHere,
                    ),
                    _barButton(Icons.zoom_out_rounded, tr('تصغير'),
                        () => _controller.zoomDown()),
                    _barButton(Icons.zoom_in_rounded, tr('تكبير'),
                        () => _controller.zoomUp()),
                    _barButton(Icons.screen_rotation_alt_rounded, tr('تدوير'),
                        () => setState(() => _turns = (_turns + 1) % 4)),
                    const Spacer(),
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: _askPage,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          count == 0 ? '$_page' : '$_page / $count',
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(
                              fontFamily: 'AppSans',
                              color: Colors.white,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _barButton(IconData icon, String tip, VoidCallback onTap,
      {bool active = false}) {
    return IconButton(
      tooltip: tip,
      onPressed: onTap,
      icon: Icon(icon,
          color: active ? AppStyle.goldColor : Colors.white, size: 24),
    );
  }

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
            decoration: InputDecoration(
                hintText: _pageCount > 0 ? '1 - $_pageCount' : null),
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
    if (pg != null) _goTo(_vol, pg);
  }

  Widget _sheet(String title, Widget child) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (_, sc) => Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(4)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Row(
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontFamily: 'AppSans',
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppStyle.textDark)),
                  const Spacer(),
                  const Text('المصدر: تراث',
                      style: TextStyle(
                          fontFamily: 'AppSans',
                          fontSize: 11,
                          color: AppStyle.textLight)),
                ],
              ),
            ),
            Expanded(
              child: PrimaryScrollController(controller: sc, child: child),
            ),
          ],
        ),
      ),
    );
  }

  void _showVolumes() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppStyle.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => _sheet(
        tr('الأجزاء'),
        FutureBuilder<List<bool>>(
          future: Future.wait([
            for (var i = 0; i < _volumes.length; i++)
              _svc.isDownloaded(widget.book, i)
          ]),
          builder: (_, snap) => ListView.builder(
            primary: true,
            itemCount: _volumes.length,
            itemBuilder: (_, i) {
              final have = snap.data != null && snap.data![i];
              final on = i == _vol;
              return ListTile(
                selected: on,
                selectedTileColor: AppStyle.primaryGreen.withOpacity(0.08),
                leading: CircleAvatar(
                  backgroundColor:
                      on ? AppStyle.primaryGreen : const Color(0xFFE7F2EE),
                  child: Text('${i + 1}',
                      style: TextStyle(
                          color: on ? Colors.white : AppStyle.primaryGreen,
                          fontWeight: FontWeight.w700)),
                ),
                title: Text(_volumes[i].label,
                    style: const TextStyle(
                        fontFamily: 'AppSans', fontWeight: FontWeight.w700)),
                trailing: Icon(
                    have
                        ? Icons.offline_pin_rounded
                        : Icons.cloud_download_outlined,
                    color: have ? AppStyle.primaryGreen : AppStyle.textLight),
                onTap: () {
                  Navigator.pop(ctx);
                  if (i != _vol) _openVolume(i, 1);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showMarks() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppStyle.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => _sheet(
          tr('العلامات'),
          _marks.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      tr('اضغط زر العلامة أسفل الشاشة لتحفظ موضع توقفك'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontFamily: 'AppSans', color: AppStyle.textLight),
                    ),
                  ),
                )
              : ListView.builder(
                  primary: true,
                  itemCount: _marks.length,
                  itemBuilder: (_, i) {
                    final m = _marks[i];
                    final where = [
                      if (_volumes.length > 1 && m.volume < _volumes.length)
                        _volumes[m.volume].label,
                      '${tr('صفحة')} ${m.page}',
                    ].join(' · ');
                    return ListTile(
                      leading: const Icon(Icons.bookmark_rounded,
                          color: AppStyle.goldColor),
                      title: Text(m.note.isEmpty ? where : m.note,
                          style: const TextStyle(
                              fontFamily: 'AppSans',
                              fontWeight: FontWeight.w700)),
                      subtitle: m.note.isEmpty
                          ? null
                          : Text(where,
                              style: const TextStyle(fontFamily: 'AppSans')),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: AppStyle.textLight),
                        onPressed: () async {
                          setState(() => _marks.removeAt(i));
                          setSheet(() {});
                          await _svc.saveBookmarks(widget.book, _marks);
                        },
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        _goTo(m.volume, m.page);
                      },
                    );
                  },
                ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Keep the exact spot even if the last page change was not reported.
    final p = _controller.isReady ? _controller.pageNumber : null;
    if (p != null && _path != null) {
      _svc.savePosition(widget.book, _vol, p);
    }
    super.dispose();
  }
}

