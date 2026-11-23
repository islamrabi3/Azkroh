import 'package:azkroh_app/features/core/appstyle.dart';
import 'package:azkroh_app/features/core/services/books_service.dart';
import 'package:azkroh_app/features/core/widgets/app_loader.dart';
import 'package:azkroh_app/features/core/widgets/paged_list.dart';
import 'package:azkroh_app/l10n/app_locale.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'book_reader_screen.dart';

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
  int _tab = 0; // 0: Turath, 1: IslamHouse

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
    if (b.isText) {
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => BookReaderScreen(book: b)));
      return;
    }
    _svc.markOpened(b);
    final ok = await launchUrl(Uri.parse(b.pdfUrl!),
        mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('تعذر فتح الكتاب'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLocale.direction,
      child: Scaffold(
        backgroundColor: AppStyle.background,
        body: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (_tab == 1 &&
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
                if (_tab == 0) ..._turathSlivers() else ..._ihSlivers(),
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
            if (i == 1 && _ih.isEmpty) _moreIslamHouse();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 10),
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
                Text(label,
                    style: TextStyle(
                        fontFamily: 'AppSans',
                        fontWeight: FontWeight.w700,
                        color: on ? Colors.white : AppStyle.textDark)),
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
            chip(0, tr('كتب التراث'), Icons.auto_stories_rounded),
            const SizedBox(width: 10),
            chip(1, tr('مكتبة إسلام هاوس'), Icons.picture_as_pdf_rounded),
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
    ];
  }

  List<Widget> _ihSlivers() {
    return [
      _title(tr('كتب إسلام هاوس'), sub: tr('تفتح بصيغة PDF')),
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
