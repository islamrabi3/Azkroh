import 'dart:math' as math;

import 'package:azkroh_app/features/core/appstyle.dart';
import 'package:azkroh_app/features/core/services/radio_service.dart';
import 'package:azkroh_app/features/core/widgets/app_loader.dart';
import 'package:azkroh_app/features/core/widgets/paged_list.dart';
import 'package:azkroh_app/l10n/app_locale.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Live Quran radio. Playback lives in [RadioService] so it keeps going in
/// the background and can be controlled from the lock screen.
class RadioScreen extends StatefulWidget {
  const RadioScreen({super.key});

  @override
  State<RadioScreen> createState() => _RadioScreenState();
}

class _RadioScreenState extends State<RadioScreen> {
  final RadioService _radio = RadioService();
  final ScrollController _scroll = ScrollController();
  String _query = '';
  bool _heroHidden = false;

  // Cache of the filtered list so paging only resets when the query or the
  // station list really changes.
  List<RadioStation>? _filtered;
  String? _filteredFor;
  List<RadioStation>? _filteredSource;

  static const _heroExtent = 230.0;

  late final Listenable _listen = Listenable.merge([
    _radio.current,
    _radio.buffering,
    _radio.playing,
    _radio.reciterStations,
    _radio.favorites,
  ]);

  @override
  void initState() {
    super.initState();
    _listen.addListener(_changed);
    _scroll.addListener(_onScroll);
    _radio.loadStations();
  }

  @override
  void dispose() {
    _listen.removeListener(_changed);
    _scroll.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    final hidden = _scroll.offset > _heroExtent;
    if (hidden != _heroHidden) setState(() => _heroHidden = hidden);
  }

  bool _isActive(RadioStation s) => _radio.current.value?.name == s.name;

  Future<void> _tap(RadioStation s) async {
    HapticFeedback.selectionClick();
    if (_isActive(s)) {
      await _radio.toggle();
    } else {
      await _radio.play(s);
    }
  }

  List<RadioStation> get _reciterList {
    final src = _radio.reciterStations.value;
    final q = searchKey(_query.trim());
    if (_filtered != null &&
        _filteredFor == q &&
        identical(_filteredSource, src)) {
      return _filtered!;
    }
    _filteredFor = q;
    _filteredSource = src;
    _filtered = q.isEmpty
        ? src
        : src.where((s) => searchKey(s.name).contains(q)).toList();
    return _filtered!;
  }

  @override
  Widget build(BuildContext context) {
    final favs = _radio.favoriteStations;
    final reciters = _reciterList;
    final current = _radio.current.value;
    return Directionality(
      textDirection: AppLocale.direction,
      child: Scaffold(
        backgroundColor: AppStyle.background,
        appBar: AppBar(
          backgroundColor: AppStyle.primaryGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: Text(tr('الإذاعة'),
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        body: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                controller: _scroll,
                physics: const ClampingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _hero()),
                  _title(tr('الإذاعات الرئيسية')),
                  SliverToBoxAdapter(child: _featuredRow()),
                  if (favs.isNotEmpty) ...[
                    _title(tr('المفضلة'), icon: Icons.star_rounded),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _stationTile(favs[i]),
                          ),
                          childCount: favs.length,
                        ),
                      ),
                    ),
                  ],
                  _title(
                    tr('إذاعات القراء'),
                    trailing: _radio.reciterStations.value.isEmpty
                        ? null
                        : AppLocale.digits(_radio.reciterStations.value.length),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: DebouncedSearchField(
                        hint: tr('ابحث عن قارئ'),
                        onChanged: (v) => setState(() => _query = v),
                      ),
                    ),
                  ),
                  if (_radio.reciterStations.value.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                          padding: EdgeInsets.all(24), child: AppLoader()),
                    )
                  else if (reciters.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(tr('لا توجد نتائج'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppStyle.textLight)),
                      ),
                    )
                  else
                    PagedSliverList<RadioStation>(
                      items: reciters,
                      pageSize: 30,
                      spacing: 8,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      itemBuilder: (_, s, __) => _stationTile(s),
                    ),
                ],
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              child: current != null && _heroHidden
                  ? _miniBar(current)
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Hero: one big, obvious play button.
  // ---------------------------------------------------------------------------
  Widget _hero() {
    final current = _radio.current.value;
    final station = current ?? RadioService.featured.first;
    final buffering = current != null && _radio.buffering.value;
    final playing = current != null && _radio.playing.value && !buffering;
    final fav = _radio.favorites.value.contains(station.name);

    String status;
    if (current == null) {
      status = tr('اضغط للاستماع');
    } else if (buffering) {
      status = tr('جاري الاتصال...');
    } else if (playing) {
      status = tr('بث مباشر');
    } else {
      status = tr('متوقف مؤقتاً');
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [Color(0xFF13705A), Color(0xFF0B3D33)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B3D33).withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _livePill(playing, buffering),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: tr('المفضلة'),
                icon: Icon(fav ? Icons.star_rounded : Icons.star_border_rounded,
                    color: AppStyle.goldColor),
                onPressed: () => _radio.toggleFavorite(station),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _bigPlay(station, playing, buffering),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr(station.name),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            height: 1.35,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(status,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          if (current != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _LiveBars(active: playing)),
                ...[
                  const SizedBox(width: 12),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.white.withOpacity(0.12),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    onPressed: _radio.stop,
                    icon: const Icon(Icons.stop_rounded, size: 20),
                    label: Text(tr('إيقاف')),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _livePill(bool playing, bool buffering) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: playing
                  ? Colors.redAccent
                  : buffering
                      ? AppStyle.goldColor
                      : Colors.white38,
            ),
          ),
          const SizedBox(width: 6),
          Text(tr('مباشر'),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _bigPlay(RadioStation station, bool playing, bool buffering) {
    return Material(
      color: AppStyle.goldColor,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => _tap(station),
        child: SizedBox.square(
          dimension: 68,
          child: buffering
              ? const Padding(
                  padding: EdgeInsets.all(18),
                  child: AppLoader(size: 32, color: Color(0xFF0B3D33)),
                )
              : Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 40, color: const Color(0xFF0B3D33)),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Featured stations: horizontal cards.
  // ---------------------------------------------------------------------------
  static const _featuredIcons = <IconData>[
    Icons.cell_tower_rounded,
    Icons.mosque_rounded,
    Icons.library_music_rounded,
    Icons.auto_awesome_rounded,
    Icons.menu_book_rounded,
    Icons.health_and_safety_rounded,
  ];

  Widget _featuredRow() {
    const list = RadioService.featured;
    return SizedBox(
      height: 128,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final s = list[i];
          final active = _isActive(s);
          final playing = active && _radio.playing.value;
          return SizedBox(
            width: 150,
            child: Material(
              color: active ? AppStyle.primaryGreen : Colors.white,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _tap(s),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: active
                                  ? Colors.white.withOpacity(0.14)
                                  : const Color(0xFFE7F2EE),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                                playing
                                    ? Icons.graphic_eq_rounded
                                    : _featuredIcons[i % _featuredIcons.length],
                                size: 22,
                                color: active
                                    ? AppStyle.goldColor
                                    : AppStyle.primaryGreen),
                          ),
                          const Spacer(),
                          Icon(
                              playing
                                  ? Icons.pause_circle_filled_rounded
                                  : Icons.play_circle_fill_rounded,
                              size: 26,
                              color: active
                                  ? AppStyle.goldColor
                                  : AppStyle.primaryGreen.withOpacity(0.8)),
                        ],
                      ),
                      const Spacer(),
                      Text(tr(s.name),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              height: 1.35,
                              color:
                                  active ? Colors.white : AppStyle.textDark)),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Station row
  // ---------------------------------------------------------------------------
  Widget _stationTile(RadioStation s) {
    final active = _isActive(s);
    final buffering = active && _radio.buffering.value;
    final playing = active && _radio.playing.value && !buffering;
    final fav = _radio.favorites.value.contains(s.name);
    return Material(
      color: active ? const Color(0xFFE7F2EE) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _tap(s),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 4, 8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor:
                    active ? AppStyle.primaryGreen : const Color(0xFFF1EEE5),
                child: Icon(
                    active ? Icons.graphic_eq_rounded : Icons.radio_rounded,
                    size: 20,
                    color: active ? AppStyle.goldColor : AppStyle.primaryGreen),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(tr(s.name),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                        color: AppStyle.textDark)),
              ),
              IconButton(
                tooltip: tr('المفضلة'),
                icon: Icon(fav ? Icons.star_rounded : Icons.star_border_rounded,
                    color: fav ? AppStyle.goldColor : AppStyle.textLight),
                onPressed: () => _radio.toggleFavorite(s),
              ),
              if (buffering)
                const Padding(
                  padding: EdgeInsets.all(10),
                  child: AppLoader(size: 24),
                )
              else
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                      playing
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_fill_rounded,
                      size: 34,
                      color: AppStyle.primaryGreen),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _title(String t, {IconData? icon, String? trailing}) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: AppStyle.goldColor),
              const SizedBox(width: 6),
            ],
            Text(t,
                style: const TextStyle(
                    fontSize: 17,
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

  // Compact bar shown only when the hero has scrolled away.
  Widget _miniBar(RadioStation current) {
    final buffering = _radio.buffering.value;
    final playing = _radio.playing.value && !buffering;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 6, 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF0F5C4A), Color(0xFF0B3D33)]),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            SizedBox(width: 34, child: _LiveBars(active: playing)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(tr(current.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
            if (buffering)
              const Padding(
                padding: EdgeInsets.all(10),
                child: AppLoader(size: 26, color: AppStyle.goldColor),
              )
            else
              IconButton(
                icon: Icon(
                    playing
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_fill_rounded,
                    color: AppStyle.goldColor,
                    size: 38),
                onPressed: _radio.toggle,
              ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white70),
              onPressed: _radio.stop,
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated "live" equalizer bars; flat when not playing.
class _LiveBars extends StatefulWidget {
  final bool active;

  const _LiveBars({required this.active});

  @override
  State<_LiveBars> createState() => _LiveBarsState();
}

class _LiveBarsState extends State<_LiveBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant _LiveBars old) {
    super.didUpdateWidget(old);
    if (widget.active && !_c.isAnimating) _c.repeat();
    if (!widget.active && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(
          painter: _BarsPainter(_c.value, widget.active),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  final double t;
  final bool active;

  _BarsPainter(this.t, this.active);

  @override
  void paint(Canvas canvas, Size size) {
    const barW = 3.0;
    const gap = 3.0;
    final n = ((size.width + gap) / (barW + gap)).floor().clamp(1, 60);
    final paint = Paint()
      ..color = active ? AppStyle.goldColor : Colors.white24
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barW;
    for (int i = 0; i < n; i++) {
      final phase = i * 0.7;
      final wave = (math.sin(t * 4 * math.pi + phase) *
              math.cos(t * 2 * math.pi + phase * 0.5))
          .abs();
      final h = active ? size.height * (0.2 + 0.8 * wave) : size.height * 0.2;
      final x = i * (barW + gap) + barW / 2;
      final y0 = (size.height - h) / 2;
      canvas.drawLine(Offset(x, y0), Offset(x, y0 + h), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BarsPainter old) =>
      old.t != t || old.active != active;
}
