import 'package:azkroh_app/features/core/appstyle.dart';
import 'package:azkroh_app/features/core/services/books_service.dart';
import 'package:azkroh_app/features/core/widgets/app_loader.dart';
import 'package:azkroh_app/features/core/widgets/paged_list.dart';
import 'package:azkroh_app/l10n/app_locale.dart';
import 'package:flutter/material.dart';

/// The book's table of contents and its volumes, in one sheet.
class BookTocSheet extends StatefulWidget {
  final LibBook book;
  final List<BookVolume> volumes;
  final Future<List<TocEntry>> toc;
  final BookDownload? download;
  final int volume;
  final int page;
  final void Function(int volume, int page) onGo;
  final int initialTab;

  const BookTocSheet({
    super.key,
    required this.book,
    required this.volumes,
    required this.toc,
    required this.download,
    required this.volume,
    required this.page,
    required this.onGo,
    this.initialTab = 0,
  });

  static Future<void> show(
    BuildContext context, {
    required LibBook book,
    required List<BookVolume> volumes,
    required Future<List<TocEntry>> toc,
    required BookDownload? download,
    required int volume,
    required int page,
    required void Function(int volume, int page) onGo,
    bool volumesFirst = false,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.86,
        minChildSize: 0.5,
        maxChildSize: 0.96,
        builder: (ctx, sc) => BookTocSheet(
          book: book,
          volumes: volumes,
          toc: toc,
          download: download,
          volume: volume,
          page: page,
          onGo: onGo,
          initialTab: volumesFirst ? 1 : 0,
        ),
      ),
    );
  }

  @override
  State<BookTocSheet> createState() => _BookTocSheetState();
}

class _BookTocSheetState extends State<BookTocSheet> {
  static const _row = 58.0;

  late int _tab = _multi ? widget.initialTab : 0;
  String _q = '';
  ScrollController? _sc;
  List<TocEntry>? _toc;
  int _current = -1;

  bool get _multi => widget.volumes.length > 1;

  @override
  void initState() {
    super.initState();
    widget.toc.then((list) {
      if (!mounted) return;
      // The heading the reader is in: the last one at or before the page.
      var cur = -1;
      for (var i = 0; i < list.length; i++) {
        final e = list[i];
        if (e.volume < widget.volume ||
            (e.volume == widget.volume && e.page <= widget.page)) {
          cur = i;
        }
      }
      setState(() {
        _toc = list;
        _current = cur;
      });
      if (cur > 2) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final sc = _sc;
          if (sc != null && sc.hasClients) {
            sc.jumpTo(((cur - 2) * _row)
                .clamp(0, sc.position.maxScrollExtent)
                .toDouble());
          }
        });
      }
    }).catchError((_) {
      if (mounted) setState(() => _toc = const []);
    });
  }

  @override
  void dispose() {
    _sc?.dispose();
    super.dispose();
  }

  void _go(int v, int p) {
    Navigator.of(context).pop();
    widget.onGo(v, p);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLocale.direction,
      child: Container(
        decoration: const BoxDecoration(
          color: AppStyle.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          children: [
            _header(),
            if (_multi) _tabs(),
            Expanded(child: _tab == 0 ? _tocView() : _volumesView()),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppStyle.darkGreen, AppStyle.primaryGreen],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.white30, borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppStyle.goldColor.withOpacity(0.5)),
                ),
                child: const Icon(Icons.menu_book_rounded,
                    color: AppStyle.goldColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.book.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: 'AppSans',
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (widget.book.author != null) widget.book.author!,
                        if (_multi) '${widget.volumes.length} ${tr('ملفاً')}',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'AppSans',
                          color: Colors.white70,
                          fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
              ),
            ],
          ),
          if (_tab == 0) ...[
            const SizedBox(height: 12),
            DebouncedSearchField(
              hint: tr('ابحث في عناوين الكتاب'),
              onChanged: (v) => setState(() => _q = v),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tabs() {
    Widget tab(int i, String label, IconData icon) {
      final on = _tab == i;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _tab = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: on ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: on ? AppStyle.softShadow : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 18,
                    color: on ? AppStyle.primaryGreen : AppStyle.textLight),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        fontFamily: 'AppSans',
                        fontWeight: FontWeight.w800,
                        color: on ? AppStyle.textDark : AppStyle.textLight)),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEAE6DA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          tab(0, tr('الفهرس'), Icons.format_list_bulleted_rounded),
          tab(1, '${tr('الأجزاء')} (${widget.volumes.length})',
              Icons.library_books_rounded),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Table of contents
  // ---------------------------------------------------------------------------
  Widget _tocView() {
    final all = _toc;
    if (all == null) return const Center(child: AppLoader());
    if (all.isEmpty) {
      return _empty(Icons.toc_rounded, tr('لا يوجد فهرس لهذا الكتاب'),
          tr('تنقّل بالأجزاء أو برقم الصفحة'));
    }
    final q = searchKey(_q);
    final idx = <int>[
      for (var i = 0; i < all.length; i++)
        if (q.isEmpty || searchKey(all[i].title).contains(q)) i
    ];
    if (idx.isEmpty) {
      return _empty(Icons.search_off_rounded, tr('لا توجد نتائج'), null);
    }
    _sc ??= ScrollController();
    return Scrollbar(
      controller: _sc,
      child: ListView.builder(
        controller: _sc,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
        itemExtent: _row,
        itemCount: idx.length,
        itemBuilder: (_, k) {
          final i = idx[k];
          final e = all[i];
          final on = i == _current;
          final top = e.level <= 1;
          final indent = ((e.level - 1).clamp(0, 3)) * 18.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Material(
              color: on ? const Color(0xFFE3F0EB) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _go(e.volume, e.page),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: on
                            ? AppStyle.primaryGreen
                            : top
                                ? AppStyle.goldColor
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    SizedBox(width: 10 + indent),
                    if (!top)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                              color: AppStyle.textLight.withOpacity(0.5),
                              shape: BoxShape.circle),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        e.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'AppSans',
                          fontSize: top ? 15 : 14,
                          fontWeight: top || on
                              ? FontWeight.w800
                              : FontWeight.w500,
                          color: on ? AppStyle.primaryGreen : AppStyle.textDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      margin: const EdgeInsetsDirectional.only(end: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: on
                            ? AppStyle.primaryGreen
                            : const Color(0xFFF3F1EA),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _multi
                            ? '${_shortVol(e.volume)} · ${e.page}'
                            : '${e.page}',
                        style: TextStyle(
                          fontFamily: 'AppSans',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: on ? Colors.white : AppStyle.textLight,
                        ),
                      ),
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

  String _shortVol(int v) {
    final l = widget.volumes[v].label;
    return l.startsWith('الجزء ')
        ? tr('ج{n}').replaceAll('{n}', l.substring(6))
        : volumeLabelUi(l);
  }

  // ---------------------------------------------------------------------------
  // Volumes
  // ---------------------------------------------------------------------------
  Widget _volumesView() {
    final dl = widget.download;
    return AnimatedBuilder(
      animation: dl == null
          ? const AlwaysStoppedAnimation(0)
          : Listenable.merge([dl.have, dl.active, dl.progress]),
      builder: (_, __) => GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 130,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.92,
        ),
        itemCount: widget.volumes.length,
        itemBuilder: (_, i) {
          final have = dl != null &&
              dl.have.value.length > i &&
              dl.have.value[i];
          final loading = dl != null && dl.active.value == i;
          final on = i == widget.volume;
          final label = widget.volumes[i].label;
          final num = label.startsWith('الجزء ') ? label.substring(6) : null;
          return Material(
            color: on ? AppStyle.primaryGreen : Colors.white,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _go(i, 1),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: on ? AppStyle.primaryGreen : AppStyle.border),
                ),
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      num ?? '',
                      style: TextStyle(
                        fontFamily: 'AppSans',
                        fontSize: num == null ? 0 : 28,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                        color: on ? Colors.white : AppStyle.primaryGreen,
                      ),
                    ),
                    if (num == null)
                      Icon(Icons.bookmark_border_rounded,
                          color: on ? AppStyle.goldColor : AppStyle.darkGold),
                    const SizedBox(height: 4),
                    Text(
                      num != null ? tr('جزء الكتاب') : volumeLabelUi(label),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'AppSans',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: on ? Colors.white70 : AppStyle.textLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (loading)
                      SizedBox(
                        width: 44,
                        child: LinearProgressIndicator(
                          value: dl.progress.value,
                          minHeight: 3,
                          color: AppStyle.goldColor,
                          backgroundColor:
                              on ? Colors.white24 : const Color(0xFFEDEAE0),
                        ),
                      )
                    else
                      Icon(
                        have
                            ? Icons.check_circle_rounded
                            : Icons.cloud_download_outlined,
                        size: 17,
                        color: have
                            ? (on ? AppStyle.goldColor : AppStyle.lightGreen)
                            : (on ? Colors.white54 : AppStyle.textLight),
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

  Widget _empty(IconData icon, String title, String? sub) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: AppStyle.textLight.withOpacity(0.6)),
            const SizedBox(height: 10),
            Text(title,
                style: const TextStyle(
                    fontFamily: 'AppSans',
                    fontWeight: FontWeight.w700,
                    color: AppStyle.textDark)),
            if (sub != null)
              Text(sub,
                  style: const TextStyle(
                      fontFamily: 'AppSans', color: AppStyle.textLight)),
          ],
        ),
      ),
    );
  }
}
