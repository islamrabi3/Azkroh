import 'package:azkroh_app/features/core/services/remote_content_service.dart';
import 'package:azkroh_app/features/core/widgets/now_playing_bubble.dart';
import 'package:azkroh_app/features/core/appstyle.dart';
import 'package:azkroh_app/features/core/services/listen_service.dart';
import 'package:azkroh_app/features/core/widgets/app_loader.dart';
import 'package:azkroh_app/features/core/widgets/paged_list.dart';
import 'package:azkroh_app/l10n/app_locale.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:qcf_quran_plus/qcf_quran_plus.dart' as qcf;

String _surahTitle(int s) =>
    AppLocale.isRtl ? 'سورة ${surahName(s)}' : surahName(s);

String _surahMeta(int s) {
  final place = qcf.getPlaceOfRevelation(s) == 'Makkah' ? 'مكية' : 'مدنية';
  return '${AppLocale.digits(qcf.getVerseCount(s))} ${tr('آية')} • ${tr(place)}';
}

/// First letter used for the alphabet filter (ignores a leading «ال»).
String _initial(String name) {
  final k = searchKey(name);
  if (k.isEmpty) return '#';
  return k.characters.first;
}

/// Avatar with the reciter's initial on a tone picked from the name.
class _ReciterAvatar extends StatelessWidget {
  final String name;
  final double size;

  const _ReciterAvatar(this.name, {this.size = 44});

  static const _tones = <List<Color>>[
    [Color(0xFF13705A), Color(0xFF0B3D33)],
    [Color(0xFF8A6D2B), Color(0xFF5E4A1B)],
    [Color(0xFF2D5F7A), Color(0xFF1C3E52)],
    [Color(0xFF6B4E7A), Color(0xFF44304F)],
    [Color(0xFF7A4B3A), Color(0xFF4F2F24)],
  ];

  @override
  Widget build(BuildContext context) {
    final tone = _tones[name.hashCode.abs() % _tones.length];
    final letter = name.isEmpty ? '' : name.characters.first;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: tone,
        ),
      ),
      child: Text(letter,
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: size * 0.42)),
    );
  }
}

/// Quran listening: reciters library + downloads.
class ListenScreen extends StatefulWidget {
  const ListenScreen({super.key});

  @override
  State<ListenScreen> createState() => _ListenScreenState();
}

class _ListenScreenState extends State<ListenScreen>
    with SuppressNowPlayingBubble {
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLocale.direction,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: AppStyle.background,
          appBar: AppBar(
            backgroundColor: AppStyle.primaryGreen,
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            title: Text(tr('الاستماع'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TabBar(
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  indicatorPadding: const EdgeInsets.all(4),
                  labelColor: AppStyle.primaryGreen,
                  unselectedLabelColor: Colors.white,
                  labelStyle: const TextStyle(
                      fontFamily: 'AppSans', fontWeight: FontWeight.w700),
                  tabs: [
                    Tab(text: tr('القراء')),
                    Tab(text: tr('التحميلات')),
                  ],
                ),
              ),
            ),
          ),
          body: const Column(
            children: [
              Expanded(
                child: TabBarView(
                  children: [_RecitersTab(), _DownloadsTab()],
                ),
              ),
              ListenMiniPlayer(),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Reciters tab
// =============================================================================
class _RecitersTab extends StatefulWidget {
  const _RecitersTab();

  @override
  State<_RecitersTab> createState() => _RecitersTabState();
}

class _RecitersTabState extends State<_RecitersTab>
    with AutomaticKeepAliveClientMixin {
  final _service = ListenService();
  late Future<List<ListenReciter>> _future = _service.reciters();
  String _q = '';
  String? _letter;

  // Filter cache: paging resets only when the result really changes.
  List<ListenReciter>? _cache;
  String _cacheKey = '';
  List<ListenReciter>? _featured;

  /// Well-known reciters shown first (matched by name).
  static const _famous = [
    'عبدالباسط',
    'المنشاوي',
    'الحصري',
    'محمودعليالبنا',
    'مصطفياسماعيل',
    'العفاسي',
    'السديس',
    'الشريم',
    'المعيقلي',
    'الدوسري',
    'الغامدي',
    'العجمي',
    'فارسعباد',
    'القطامي',
    'الطبلاوي',
  ];

  @override
  bool get wantKeepAlive => true;

  List<ListenReciter> _filter(List<ListenReciter> all) {
    final q = searchKey(_q.trim());
    final key = '$q|$_letter|${all.length}';
    if (_cache != null && key == _cacheKey) return _cache!;
    _cacheKey = key;
    _cache = all.where((r) {
      final k = searchKey(r.name);
      if (q.isNotEmpty && !k.contains(q)) return false;
      if (_letter != null && _initial(r.name) != _letter) return false;
      return true;
    }).toList();
    return _cache!;
  }

  List<ListenReciter> _famousOf(List<ListenReciter> all) {
    if (_featured != null) return _featured!;
    final out = <ListenReciter>[];
    for (final f in _famous) {
      for (final r in all) {
        if (searchKey(r.name).contains(f) && !out.contains(r)) {
          out.add(r);
          break;
        }
      }
    }
    return _featured = out;
  }

  void _open(ListenReciter r) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReciterSurahsScreen(reciter: r)),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<ListenReciter>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const AppLoader();
        }
        if (snap.hasError || snap.data == null) {
          return _ErrorView(
            onRetry: () => setState(() {
              _featured = null;
              _cache = null;
              _future = _service.reciters(refresh: true);
            }),
          );
        }
        final all = snap.data!;
        final list = _filter(all);
        final famous = _famousOf(all);
        final letters = <String>{for (final r in all) _initial(r.name)}
            .toList()
          ..sort();
        final browsing = _q.trim().isEmpty && _letter == null;
        // Hawamdiya reciters: built-in + uploaded from the dashboard.
        final local = [
          ...ListenService.hawamdiya,
          ...RemoteContentService.instance.reciters.value,
        ];

        return CustomScrollView(
          physics: const ClampingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: DebouncedSearchField(
                  hint:
                      '${tr('ابحث عن قارئ')} (${AppLocale.digits(all.length)})',
                  onChanged: (v) => setState(() => _q = v),
                ),
              ),
            ),
            if (browsing) ...[
              _sectionTitle(tr('قراء الحوامدية')),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ReciterTile(
                        reciter: local[i],
                        onTap: () => _open(local[i]),
                      ),
                    ),
                    childCount: local.length,
                  ),
                ),
              ),
            ],
            if (browsing && famous.isNotEmpty) ...[
              _sectionTitle(tr('قراء مشهورون')),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 118,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: famous.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, i) {
                      final r = famous[i];
                      return SizedBox(
                        width: 82,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _open(r),
                          child: Column(
                            children: [
                              _ReciterAvatar(r.name, size: 62),
                              const SizedBox(height: 6),
                              Text(r.name,
                                  maxLines: 2,
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 11.5,
                                      height: 1.3,
                                      fontWeight: FontWeight.w600,
                                      color: AppStyle.textDark)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
            // Alphabet filter
            SliverToBoxAdapter(
              child: SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  itemCount: letters.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final l = i == 0 ? null : letters[i - 1];
                    final sel = _letter == l;
                    return ChoiceChip(
                      label: Text(l ?? tr('الكل')),
                      selected: sel,
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      selectedColor: AppStyle.primaryGreen,
                      backgroundColor: Colors.white,
                      side: BorderSide(
                          color: sel
                              ? AppStyle.primaryGreen
                              : const Color(0xFFE3DED2)),
                      labelStyle: TextStyle(
                          color: sel ? Colors.white : AppStyle.textDark,
                          fontWeight: FontWeight.w700),
                      onSelected: (_) => setState(() => _letter = l),
                    );
                  },
                ),
              ),
            ),
            _sectionTitle(
              browsing ? tr('كل القراء') : tr('النتائج'),
              trailing: AppLocale.digits(list.length),
            ),
            if (list.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(tr('لا توجد نتائج'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppStyle.textLight)),
                ),
              )
            else
              PagedSliverList<ListenReciter>(
                items: list,
                pageSize: 30,
                spacing: 8,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemBuilder: (_, r, __) => _ReciterTile(
                  reciter: r,
                  onTap: () => _open(r),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ReciterTile extends StatelessWidget {
  final ListenReciter reciter;
  final VoidCallback onTap;

  const _ReciterTile({required this.reciter, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = reciter;
    final surahs = r.moshafs.fold<int>(
        0, (a, m) => m.surahs.length > a ? m.surahs.length : a);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _ReciterAvatar(r.name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppStyle.textDark)),
                    const SizedBox(height: 3),
                    Text(
                        r.moshafs.length == 1
                            ? r.moshafs.first.name
                            : '${AppLocale.digits(r.moshafs.length)} ${tr('روايات')}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppStyle.textLight, fontSize: 12.5)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F2EE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${AppLocale.digits(surahs)} ${tr('سورة')}',
                    style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppStyle.primaryGreen)),
              ),
              const SizedBox(width: 4),
              // chevron_right mirrors automatically in RTL.
              const Icon(Icons.chevron_right_rounded,
                  color: AppStyle.textLight),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Surahs of one reciter
// =============================================================================
class ReciterSurahsScreen extends StatefulWidget {
  final ListenReciter reciter;

  const ReciterSurahsScreen({super.key, required this.reciter});

  @override
  State<ReciterSurahsScreen> createState() => _ReciterSurahsScreenState();
}

class _ReciterSurahsScreenState extends State<ReciterSurahsScreen>
    with SuppressNowPlayingBubble {
  final _service = ListenService();
  int _moshaf = 0;
  final Set<String> _downloaded = {};
  String _q = '';
  List<int>? _cache;
  String _cacheKey = '';

  Moshaf get _m => widget.reciter.moshafs[_moshaf];

  @override
  void initState() {
    super.initState();
    _service.downloadsVersion.addListener(_refresh);
    _refresh();
  }

  @override
  void dispose() {
    _service.downloadsVersion.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _refresh() async {
    final d = await _service.downloads();
    if (!mounted) return;
    setState(() {
      _downloaded
        ..clear()
        ..addAll(d.map((e) => e.key));
    });
  }

  List<int> get _surahs {
    final q = searchKey(_q.trim());
    final key = '${_m.id}|$q';
    if (_cache != null && key == _cacheKey) return _cache!;
    _cacheKey = key;
    _cache = q.isEmpty
        ? _m.surahs
        : _m.surahs
            .where((s) =>
                searchKey(surahName(s)).contains(q) ||
                searchKey(qcf.getSurahNameArabic(s)).contains(q) ||
                '$s' == q)
            .toList();
    return _cache!;
  }

  Future<void> _play(int s) async {
    HapticFeedback.selectionClick();
    try {
      await _service.play(widget.reciter.name, _m, s);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(tr('تعذر تشغيل التلاوة، تأكد من الاتصال بالإنترنت'))));
    }
  }

  Future<void> _downloadAll() async {
    final remaining = _m.surahs
        .where((s) => !_downloaded.contains(_service.keyFor(_m, s)))
        .toList();
    if (remaining.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('كل السور محملة بالفعل'))));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: AppLocale.direction,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(tr('تحميل الكل')),
          content: Text(
              '${tr('سيتم تحميل')} ${AppLocale.digits(remaining.length)} ${tr('سورة')}. '
              '${tr('قد يستهلك ذلك مساحة كبيرة وباقة إنترنت، يُفضّل استخدام شبكة Wi-Fi.')}',
              style: const TextStyle(height: 1.6)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(tr('إلغاء'))),
            FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: AppStyle.primaryGreen),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(tr('تحميل'))),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('جاري تحميل كل السور في الخلفية'))));
    final m = _m;
    for (final s in remaining) {
      if (!mounted) return;
      try {
        await _service.downloadSurah(widget.reciter.name, m, s);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reciter;
    final surahs = _surahs;
    return Directionality(
      textDirection: AppLocale.direction,
      child: Scaffold(
        backgroundColor: AppStyle.background,
        body: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                physics: const ClampingScrollPhysics(),
                slivers: [
                  SliverAppBar(
                    pinned: true,
                    expandedHeight: 210,
                    backgroundColor: AppStyle.primaryGreen,
                    foregroundColor: Colors.white,
                    title: Text(r.name,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    flexibleSpace: FlexibleSpaceBar(
                      collapseMode: CollapseMode.pin,
                      background: _header(),
                    ),
                  ),
                  if (r.moshafs.length > 1)
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 56,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          itemCount: r.moshafs.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            final sel = i == _moshaf;
                            return ChoiceChip(
                              label: Text(r.moshafs[i].name),
                              selected: sel,
                              showCheckmark: false,
                              selectedColor: AppStyle.primaryGreen,
                              backgroundColor: Colors.white,
                              side: BorderSide(
                                  color: sel
                                      ? AppStyle.primaryGreen
                                      : const Color(0xFFE3DED2)),
                              labelStyle: TextStyle(
                                  color:
                                      sel ? Colors.white : AppStyle.textDark,
                                  fontWeight: FontWeight.w600),
                              onSelected: (_) => setState(() => _moshaf = i),
                            );
                          },
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: DebouncedSearchField(
                        hint: tr('ابحث عن سورة'),
                        onChanged: (v) => setState(() => _q = v),
                      ),
                    ),
                  ),
                  if (surahs.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(tr('لا توجد نتائج'),
                            textAlign: TextAlign.center,
                            style:
                                const TextStyle(color: AppStyle.textLight)),
                      ),
                    )
                  else
                    ValueListenableBuilder<Map<String, double>>(
                      valueListenable: _service.downloading,
                      builder: (_, progress, __) =>
                          ValueListenableBuilder<ListenNowPlaying?>(
                        valueListenable: _service.nowPlaying,
                        builder: (_, np, __) => PagedSliverList<int>(
                          items: surahs,
                          pageSize: 30,
                          spacing: 8,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemBuilder: (_, s, __) {
                            final key = _service.keyFor(_m, s);
                            return _SurahTile(
                              surah: s,
                              playing:
                                  np?.moshaf.id == _m.id && np?.surah == s,
                              progress: progress[key],
                              downloaded: _downloaded.contains(key),
                              onPlay: () => _play(s),
                              onDownload: () => _service
                                  .downloadSurah(r.name, _m, s)
                                  .catchError((_) {}),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const ListenMiniPlayer(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    final r = widget.reciter;
    final done = _m.surahs
        .where((s) => _downloaded.contains(_service.keyFor(_m, s)))
        .length;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0F5C4A), Color(0xFF0B3D33)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppStyle.goldColor,
                    ),
                    child: _ReciterAvatar(r.name, size: 58),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_m.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(
                            '${AppLocale.digits(_m.surahs.length)} ${tr('سورة')}'
                            '${done > 0 ? ' • ${AppLocale.digits(done)} ${tr('محملة')}' : ''}',
                            style: const TextStyle(
                                color: AppStyle.goldColor,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppStyle.goldColor,
                        foregroundColor: const Color(0xFF0B3D33),
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => _play(_m.surahs.first),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(tr('تشغيل الكل'),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _downloadAll,
                      icon: const Icon(Icons.download_rounded),
                      label: Text(tr('تحميل الكل'),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SurahTile extends StatelessWidget {
  final int surah;
  final bool playing;
  final double? progress;
  final bool downloaded;
  final VoidCallback onPlay;
  final VoidCallback onDownload;

  const _SurahTile({
    required this.surah,
    required this.playing,
    required this.progress,
    required this.downloaded,
    required this.onPlay,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final p = progress;
    Widget trailing;
    if (p != null) {
      trailing = SizedBox.square(
        dimension: 44,
        child: p <= 0
            ? const AppLoader(size: 24)
            : Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.square(
                    dimension: 28,
                    child: CircularProgressIndicator(
                      value: p,
                      strokeWidth: 3,
                      backgroundColor: const Color(0xFFE7F2EE),
                      color: AppStyle.primaryGreen,
                    ),
                  ),
                  Text(AppLocale.digits((p * 100).round()),
                      style: const TextStyle(
                          fontSize: 9, fontWeight: FontWeight.w700)),
                ],
              ),
      );
    } else if (downloaded) {
      trailing = Tooltip(
        message: tr('محفوظة على جهازك بالفعل'),
        child: const SizedBox.square(
          dimension: 44,
          child: Icon(Icons.offline_pin_rounded,
              color: AppStyle.primaryGreen),
        ),
      );
    } else {
      trailing = IconButton(
        tooltip: tr('تحميل السورة'),
        icon: const Icon(Icons.download_rounded, color: AppStyle.textLight),
        onPressed: onDownload,
      );
    }

    return Material(
      color: playing ? const Color(0xFFE7F2EE) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onPlay,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 4, 10),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 40,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.rotate(
                      angle: 0.785398,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: playing
                              ? AppStyle.primaryGreen
                              : const Color(0xFFF1EEE5),
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                    ),
                    playing
                        ? const Icon(Icons.graphic_eq_rounded,
                            size: 18, color: AppStyle.goldColor)
                        : Text(AppLocale.digits(surah),
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppStyle.textDark)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_surahTitle(surah),
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: playing
                                ? AppStyle.primaryGreen
                                : AppStyle.textDark)),
                    const SizedBox(height: 2),
                    Text(_surahMeta(surah),
                        style: const TextStyle(
                            fontSize: 12, color: AppStyle.textLight)),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Downloads tab
// =============================================================================
/// A row of the downloads list: either a reciter header or a download.
class _DlRow {
  final String? header;
  final int count;
  final ListenDownload? item;

  const _DlRow.header(this.header, this.count) : item = null;
  const _DlRow.item(this.item)
      : header = null,
        count = 0;
}

class _DownloadsTab extends StatefulWidget {
  const _DownloadsTab();

  @override
  State<_DownloadsTab> createState() => _DownloadsTabState();
}

class _DownloadsTabState extends State<_DownloadsTab>
    with AutomaticKeepAliveClientMixin {
  final _service = ListenService();
  late Future<List<ListenDownload>> _future = _service.downloads();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _service.downloadsVersion.addListener(_reload);
  }

  @override
  void dispose() {
    _service.downloadsVersion.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (mounted) setState(() => _future = _service.downloads());
  }

  List<ListenDownload>? _rowsFor;
  List<_DlRow> _rowsCache = const [];

  List<_DlRow> _rows(List<ListenDownload> list) {
    if (identical(list, _rowsFor)) return _rowsCache;
    _rowsFor = list;
    final rows = <_DlRow>[];
    String? group;
    for (int i = 0; i < list.length; i++) {
      final d = list[i];
      final g = '${d.reciter} • ${d.moshaf}';
      if (g != group) {
        group = g;
        final n = list
            .where((x) => x.reciter == d.reciter && x.moshaf == d.moshaf)
            .length;
        rows.add(_DlRow.header(g, n));
      }
      rows.add(_DlRow.item(d));
    }
    return _rowsCache = rows;
  }

  void _play(ListenDownload d, List<ListenDownload> all) {
    HapticFeedback.selectionClick();
    final m = Moshaf(
        d.moshafId,
        d.moshaf,
        '',
        all
            .where((x) => x.moshafId == d.moshafId)
            .map((x) => x.surah)
            .toList());
    _service.play(d.reciter, m, d.surah);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<ListenDownload>>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) return const AppLoader();
        final list = snap.data!;
        if (list.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE7F2EE),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.library_music_outlined,
                        size: 44, color: AppStyle.primaryGreen),
                  ),
                  const SizedBox(height: 14),
                  Text(
                      tr('لا توجد سور محملة بعد.\nاختر قارئاً واضغط على أيقونة التحميل بجانب السورة.'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(height: 1.7)),
                ],
              ),
            ),
          );
        }
        final total = list.fold<int>(0, (a, d) => a + d.bytes);
        final rows = _rows(list);
        return CustomScrollView(
          physics: const ClampingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sd_storage_rounded,
                        color: AppStyle.primaryGreen),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                          '${AppLocale.digits(list.length)} ${tr('سورة')} • ${AppLocale.digits((total / (1024 * 1024)).toStringAsFixed(0))} MB',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppStyle.textDark)),
                    ),
                    Text(tr('اسحب للحذف'),
                        style: const TextStyle(
                            color: AppStyle.textLight, fontSize: 12)),
                  ],
                ),
              ),
            ),
            PagedSliverList<_DlRow>(
              items: rows,
              pageSize: 30,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemBuilder: (_, row, __) {
                if (row.header != null) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
                    child: Row(
                      children: [
                        _ReciterAvatar(row.header!, size: 28),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(row.header!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppStyle.textDark)),
                        ),
                        Text(AppLocale.digits(row.count),
                            style:
                                const TextStyle(color: AppStyle.textLight)),
                      ],
                    ),
                  );
                }
                final d = row.item!;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ValueListenableBuilder<ListenNowPlaying?>(
                    valueListenable: _service.nowPlaying,
                    builder: (_, np, __) {
                      final playing =
                          np?.moshaf.id == d.moshafId && np?.surah == d.surah;
                      return Dismissible(
                        key: ValueKey(d.key),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: AlignmentDirectional.centerEnd,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.delete_outline,
                              color: Colors.red),
                        ),
                        onDismissed: (_) => _service.deleteDownload(d.key),
                        child: _SurahTile(
                          surah: d.surah,
                          playing: playing,
                          progress: null,
                          downloaded: true,
                          onPlay: () => _play(d, list),
                          onDownload: () {},
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 48, color: AppStyle.textLight),
            const SizedBox(height: 8),
            Text(tr('تعذر تحميل قائمة القراء، تأكد من الاتصال بالإنترنت'),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            FilledButton(
              style:
                  FilledButton.styleFrom(backgroundColor: AppStyle.primaryGreen),
              onPressed: onRetry,
              child: Text(tr('إعادة المحاولة')),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _sectionTitle(String t, {String? trailing}) {
  return SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Row(
        children: [
          Text(t,
              style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  color: AppStyle.textDark)),
          const Spacer(),
          if (trailing != null)
            Text(trailing, style: const TextStyle(color: AppStyle.textLight)),
        ],
      ),
    ),
  );
}

/// Persistent mini player for the Listen section.
class ListenMiniPlayer extends StatelessWidget {
  const ListenMiniPlayer({super.key});

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return AppLocale.digits(h > 0 ? '$h:$m:$s' : '$m:$s');
  }

  @override
  Widget build(BuildContext context) {
    final service = ListenService();
    final player = service.player;
    return ValueListenableBuilder<ListenNowPlaying?>(
      valueListenable: service.nowPlaying,
      builder: (_, np, __) {
        if (np == null) return const SizedBox.shrink();
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 6, 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF0F5C4A), Color(0xFF0B3D33)]),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0B3D33).withOpacity(0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _ReciterAvatar(np.reciter, size: 40),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_surahTitle(np.surah),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15)),
                          Text(np.reciter,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                          AppLocale.isRtl
                              ? Icons.skip_next_rounded
                              : Icons.skip_previous_rounded,
                          color: Colors.white),
                      onPressed: service.previous,
                    ),
                    StreamBuilder<PlayerState>(
                      stream: player.playerStateStream,
                      builder: (_, snap) {
                        final st = snap.data;
                        final loading = st?.processingState ==
                                ProcessingState.loading ||
                            st?.processingState == ProcessingState.buffering;
                        if (loading) {
                          return const Padding(
                            padding: EdgeInsets.all(8),
                            child: AppLoader(
                                size: 30, color: AppStyle.goldColor),
                          );
                        }
                        return IconButton(
                          iconSize: 40,
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                              (st?.playing ?? false)
                                  ? Icons.pause_circle_filled_rounded
                                  : Icons.play_circle_fill_rounded,
                              color: AppStyle.goldColor),
                          onPressed: service.toggle,
                        );
                      },
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                          AppLocale.isRtl
                              ? Icons.skip_previous_rounded
                              : Icons.skip_next_rounded,
                          color: Colors.white),
                      onPressed: service.next,
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white70, size: 20),
                      onPressed: service.stop,
                    ),
                  ],
                ),
                StreamBuilder<Duration>(
                  stream: player.positionStream,
                  builder: (_, snap) {
                    final pos = snap.data ?? Duration.zero;
                    final dur = player.duration ?? Duration.zero;
                    final max = dur.inMilliseconds.toDouble();
                    return Row(
                      children: [
                        Text(_fmt(pos),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 11)),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6),
                              overlayShape: SliderComponentShape.noOverlay,
                            ),
                            child: Slider(
                              value: max <= 0
                                  ? 0
                                  : pos.inMilliseconds
                                      .clamp(0, max.toInt())
                                      .toDouble(),
                              max: max <= 0 ? 1 : max,
                              activeColor: AppStyle.goldColor,
                              inactiveColor: Colors.white24,
                              onChanged: max <= 0
                                  ? null
                                  : (v) => player.seek(
                                      Duration(milliseconds: v.toInt())),
                            ),
                          ),
                        ),
                        Text(_fmt(dur),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 11)),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
