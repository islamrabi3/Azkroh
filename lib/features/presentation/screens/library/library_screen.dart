import 'package:azkroh_app/features/core/appstyle.dart';
import 'package:azkroh_app/features/core/services/books_service.dart';
import 'package:azkroh_app/features/core/widgets/app_loader.dart';
import 'package:azkroh_app/features/core/widgets/paged_list.dart';
import 'package:azkroh_app/l10n/app_locale.dart';
import 'package:flutter/material.dart';
import 'pdf_book_screen.dart';

/// «المكتبة»: classical books from Turath (read in-app) and IslamHouse PDFs.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _svc = BooksService.instance;
  String _query = '';
  List<LibBook>? _results;
  bool _searching = false;
  int _tab = 0; // 0: featured, 1: sections, 2: IslamHouse
  Future<Map<String, List<LibBook>>>? _sections;

  // IslamHouse paging
  final List<LibBook> _ih = [];
  int _ihPage = 0;
  bool _ihLoading = false;
  bool _ihDone = false;
  bool _ihError = false;

  @override
  void initState() {
    super.initState();
    _svc.load();
    _svc.catalog(); // warm up search in the background
  }

  Future<void> _search(String q) async {
    setState(() {
      _query = q.trim();
      _searching = _query.isNotEmpty;
      if (_query.isEmpty) _results = null;
    });
    if (_query.isEmpty) return;
    final r = await _svc.search(_query);
    if (!mounted || q.trim() != _query) return;
    setState(() {
      _results = r;
      _searching = false;
    });
  }

  Future<void> _moreIslamHouse() async {
    if (_ihLoading || _ihDone) return;
    setState(() {
      _ihLoading = true;
      _ihError = false;
    });
    try {
      final list = await _svc.islamHouse(_ihPage + 1);
      _ihPage++;
      _ih.addAll(list.where((b) => !_svc.isHiddenPdf(b.pdfUrl!)));
      if (list.isEmpty) _ihDone = true;
    } catch (_) {
      _ihError = true;
    }
    if (mounted) setState(() => _ihLoading = false);
  }

  Future<void> _open(LibBook b) async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => PdfBookScreen(book: b)));
    if (mounted) setState(() => _storageTick++);
  }

  Future<void> _openSection(String name, List<LibBook> books) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => _SectionScreen(name: name, books: books, onOpen: _open)));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLocale.direction,
      child: Scaffold(
        backgroundColor: AppStyle.background,
        body: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (_tab == 2 &&
                _query.isEmpty &&
                n.metrics.pixels > n.metrics.maxScrollExtent - 600) {
              _moreIslamHouse();
            }
            return false;
          },
          child: CustomScrollView(
            slivers: [
              _header(),
              if (_query.isNotEmpty)
                ..._resultSlivers()
              else ...[
                _tabs(),
                if (_tab == 0)
                  ..._turathSlivers()
                else if (_tab == 1)
                  ..._sectionSlivers()
                else
                  ..._ihSlivers(),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return SliverToBoxAdapter(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppStyle.darkGreen, AppStyle.primaryGreen],
          ),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 20),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    Text(tr('المكتبة'),
                        style: const TextStyle(
                            fontFamily: 'AppSans',
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800)),
                    const Spacer(),
                    const Icon(Icons.local_library_rounded,
                        color: AppStyle.goldColor, size: 26),
                  ],
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 14),
                  child: Text(
                    tr('أمهات الكتب في التفسير والحديث والسيرة والتراجم والرقائق'),
                    style: TextStyle(
                        fontFamily: 'AppSans',
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 8),
                  child: DebouncedSearchField(
                    hint: tr('ابحث باسم الكتاب أو المؤلف'),
                    onChanged: _search,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabs() {
    Widget chip(int i, String label, IconData icon) {
      final on = _tab == i;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            setState(() => _tab = i);
            if (i == 1) _sections ??= _svc.sections();
            if (i == 2 && _ih.isEmpty) _moreIslamHouse();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: BoxDecoration(
              color: on ? AppStyle.primaryGreen : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: on ? AppStyle.primaryGreen : AppStyle.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 18, color: on ? Colors.white : AppStyle.textLight),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: 'AppSans',
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: on ? Colors.white : AppStyle.textDark)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Row(
          children: [
            chip(0, tr('مختارات'), Icons.auto_awesome_rounded),
            const SizedBox(width: 8),
            chip(1, tr('الأقسام'), Icons.grid_view_rounded),
            const SizedBox(width: 8),
            chip(2, tr('إسلام هاوس'), Icons.picture_as_pdf_rounded),
          ],
        ),
      ),
    );
  }

  Widget _title(String t, {String? sub}) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                  color: AppStyle.goldColor,
                  borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(width: 8),
            Text(t,
                style: const TextStyle(
                    fontFamily: 'AppSans',
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppStyle.textDark)),
            if (sub != null) ...[
              const SizedBox(width: 8),
              Text(sub,
                  style: const TextStyle(
                      fontFamily: 'AppSans',
                      fontSize: 12,
                      color: AppStyle.textLight)),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _turathSlivers() {
    return [
      SliverToBoxAdapter(
        child: ValueListenableBuilder<List<LibBook>>(
          valueListenable: _svc.recent,
          builder: (_, list, __) {
            if (list.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                  child: Text(tr('تابع القراءة'),
                      style: const TextStyle(
                          fontFamily: 'AppSans',
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppStyle.textDark)),
                ),
                SizedBox(
                  height: 170,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, i) => SizedBox(
                      width: 112,
                      child: BookCover(
                          book: list[i], onTap: () => _open(list[i])),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      ValueListenableBuilder<List<LibBook>>(
        valueListenable: _svc.featured,
        builder: (_, list, __) => SliverMainAxisGroup(slivers: [
          _title(tr('كتب مختارة'),
              sub: list.isEmpty ? null : '${list.length} ${tr('كتاباً')}'),
          if (list.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: AppLoader()),
              ),
            )
          else
            _grid(list),
        ]),
      ),
      SliverToBoxAdapter(child: _storageRow()),
    ];
  }

  int _storageTick = 0;

  /// Space used by downloaded books, with a way to free it.
  Widget _storageRow() {
    return FutureBuilder<int>(
      key: ValueKey(_storageTick),
      future: _svc.cacheSize(),
      builder: (_, snap) {
        final bytes = snap.data ?? 0;
        if (bytes == 0) return const SizedBox.shrink();
        final mb = (bytes / (1024 * 1024)).toStringAsFixed(0);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppStyle.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.sd_storage_rounded,
                    color: AppStyle.textLight, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${tr('الكتب المحمّلة')}: $mb MB · ${tr('الحد الأقصى')} ${BooksService.cacheLimitBytes ~/ (1024 * 1024)} MB',
                    style: const TextStyle(
                        fontFamily: 'AppSans',
                        fontSize: 12.5,
                        color: AppStyle.textLight),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    await _svc.clearCache();
                    if (mounted) setState(() => _storageTick++);
                  },
                  child: Text(tr('حذف الكل'),
                      style: const TextStyle(color: Color(0xFFB3423A))),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static const _sectionIcons = <String, IconData>{
    'التفسير': Icons.menu_book_rounded,
    'كتب السنة': Icons.auto_stories_rounded,
    'شروح الحديث': Icons.chrome_reader_mode_rounded,
    'السيرة النبوية': Icons.mosque_rounded,
    'التاريخ': Icons.history_edu_rounded,
    'التراجم والطبقات': Icons.groups_rounded,
    'العقيدة': Icons.verified_rounded,
    'الرقائق والآداب والأذكار': Icons.favorite_rounded,
    'الفتاوى': Icons.question_answer_rounded,
    'كتب اللغة': Icons.translate_rounded,
    'الأدب': Icons.edit_note_rounded,
    'الطب': Icons.healing_rounded,
  };

  List<Widget> _sectionSlivers() {
    _sections ??= _svc.sections();
    return [
      SliverToBoxAdapter(
        child: FutureBuilder<Map<String, List<LibBook>>>(
          future: _sections,
          builder: (_, snap) {
            final m = snap.data;
            if (m == null) {
              return Padding(
                padding: const EdgeInsets.all(48),
                child: Center(
                  child: snap.connectionState == ConnectionState.done
                      ? TextButton(
                          onPressed: () => setState(
                              () => _sections = _svc.sections()),
                          child: Text(tr('إعادة المحاولة')))
                      : const AppLoader(),
                ),
              );
            }
            final names = m.keys.toList()
              ..sort((a, b) => m[b]!.length.compareTo(m[a]!.length));
            final total = m.values.fold<int>(0, (a, l) => a + l.length);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                  child: Text('$total ${tr('كتاباً في')} ${names.length} ${tr('قسماً')}',
                      style: const TextStyle(
                          fontFamily: 'AppSans',
                          fontSize: 13,
                          color: AppStyle.textLight)),
                ),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: names.length,
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.3,
                  ),
                  itemBuilder: (_, i) {
                    final n = names[i];
                    return Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _openSection(n, m[n]!),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppStyle.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE7F2EE),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                    _sectionIcons[n] ?? Icons.book_rounded,
                                    color: AppStyle.primaryGreen,
                                    size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(n,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontFamily: 'AppSans',
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13.5,
                                            color: AppStyle.textDark)),
                                    Text('${m[n]!.length} ${tr('كتاب')}',
                                        style: const TextStyle(
                                            fontFamily: 'AppSans',
                                            fontSize: 11.5,
                                            color: AppStyle.textLight)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    ];
  }

  List<Widget> _ihSlivers() {
    return [
      _title(tr('كتب إسلام هاوس'), sub: tr('أكثر من 5 آلاف كتاب')),
      _grid(_ih),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: _ihLoading
                ? const AppLoader()
                : _ihError
                    ? TextButton.icon(
                        onPressed: _moreIslamHouse,
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(tr('إعادة المحاولة')),
                      )
                    : const SizedBox.shrink(),
          ),
        ),
      ),
    ];
  }

  List<Widget> _resultSlivers() {
    final r = _results;
    if (_searching || r == null) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: AppLoader())),
        ),
      ];
    }
    if (r.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              children: [
                const Icon(Icons.search_off_rounded,
                    size: 56, color: AppStyle.textLight),
                const SizedBox(height: 12),
                Text(tr('لا توجد كتب بهذا الاسم'),
                    style: const TextStyle(
                        fontFamily: 'AppSans', color: AppStyle.textLight)),
              ],
            ),
          ),
        ),
      ];
    }
    return [
      _title(tr('نتائج البحث'), sub: '${r.length}'),
      _grid(r),
    ];
  }

  Widget _grid(List<LibBook> list) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 140,
          mainAxisSpacing: 14,
          crossAxisSpacing: 12,
          childAspectRatio: 0.66,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, i) => BookCover(book: list[i], onTap: () => _open(list[i])),
          childCount: list.length,
        ),
      ),
    );
  }
}

/// All books of one section, biggest works first, with a local filter.
class _SectionScreen extends StatefulWidget {
  final String name;
  final List<LibBook> books;
  final Future<void> Function(LibBook) onOpen;
  const _SectionScreen(
      {required this.name, required this.books, required this.onOpen});

  @override
  State<_SectionScreen> createState() => _SectionScreenState();
}

class _SectionScreenState extends State<_SectionScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = searchKey(_q);
    final list = q.isEmpty
        ? widget.books
        : widget.books
            .where((b) => searchKey('${b.title} ${b.author ?? ''}').contains(q))
            .toList();
    return Directionality(
      textDirection: AppLocale.direction,
      child: Scaffold(
        backgroundColor: AppStyle.background,
        appBar: AppBar(
          backgroundColor: AppStyle.primaryGreen,
          foregroundColor: Colors.white,
          title: Text(widget.name,
              style: const TextStyle(
                  fontFamily: 'AppSans', fontWeight: FontWeight.w800)),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(64),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: DebouncedSearchField(
                hint: '${tr('ابحث في')} ${widget.books.length} ${tr('كتاب')}',
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
          ),
        ),
        body: GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: list.length,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 140,
            mainAxisSpacing: 14,
            crossAxisSpacing: 12,
            childAspectRatio: 0.66,
          ),
          itemBuilder: (_, i) =>
              BookCover(book: list[i], onTap: () => widget.onOpen(list[i])),
        ),
      ),
    );
  }
}

/// A generated book cover: the colour comes from the category, the title is
/// set inside a gold frame like a bound volume.
class BookCover extends StatelessWidget {
  final LibBook book;
  final VoidCallback onTap;

  const BookCover({super.key, required this.book, required this.onTap});

  static const _palettes = [
    [Color(0xFF0F5C4A), Color(0xFF0B3D33)],
    [Color(0xFF7A3E1D), Color(0xFF4E2511)],
    [Color(0xFF1B4E6B), Color(0xFF0F3047)],
    [Color(0xFF5B2A4E), Color(0xFF3A1832)],
    [Color(0xFF2F4F2F), Color(0xFF1C301C)],
    [Color(0xFF6B1E1E), Color(0xFF431111)],
    [Color(0xFF3B3F7A), Color(0xFF24274F)],
  ];

  @override
  Widget build(BuildContext context) {
    final seed = (book.category ?? book.title).codeUnits.fold<int>(0, (a, b) => a + b);
    final c = _palettes[seed % _palettes.length];
    // Drop the edition suffix ("- ط ...") from the big title.
    final parts = book.title.split(' - ');
    final main = parts.first;
    final edition = parts.length > 1 ? parts.sublist(1).join(' - ') : null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: c,
            ),
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(4),
              right: Radius.circular(10),
            ),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Stack(
            children: [
              // Spine
              PositionedDirectional(
                top: 0,
                bottom: 0,
                end: 0,
                child: Container(
                  width: 7,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.18),
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(4)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 13, 8),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: AppStyle.goldColor.withOpacity(0.55),
                        width: 1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  padding: const EdgeInsets.fromLTRB(6, 10, 6, 8),
                  child: Column(
                    children: [
                      Icon(
                          book.isText
                              ? Icons.auto_awesome_rounded
                              : Icons.picture_as_pdf_rounded,
                          size: 14,
                          color: AppStyle.goldColor.withOpacity(0.85)),
                      const Spacer(),
                      Text(
                        main,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'AppSans',
                          color: Colors.white,
                          fontSize: 13.5,
                          height: 1.35,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (edition != null) ...[
                        const SizedBox(height: 4),
                        Text(edition,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontFamily: 'AppSans',
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 9.5)),
                      ],
                      const Spacer(),
                      Container(
                          width: 26,
                          height: 1,
                          color: AppStyle.goldColor.withOpacity(0.7)),
                      const SizedBox(height: 5),
                      Text(
                        book.author ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontFamily: 'AppSans',
                            color: AppStyle.goldColor,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
