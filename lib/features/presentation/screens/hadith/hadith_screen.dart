import 'package:azkroh_app/l10n/app_locale.dart';
import 'dart:async';

import 'package:azkroh_app/features/core/appstyle.dart';
import 'package:azkroh_app/features/core/services/hadith_library.dart';
import 'package:azkroh_app/features/core/services/hadith_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';

String _ar(Object n) => AppLocale.digits(n);


/// Hadith encyclopedia: daily hadith, full-text search and saved hadiths.
class HadithScreen extends StatefulWidget {
  final String? initialQuery;
  final int initialTab;

  const HadithScreen({super.key, this.initialQuery, this.initialTab = 0});

  @override
  State<HadithScreen> createState() => _HadithScreenState();
}

class _HadithScreenState extends State<HadithScreen> {
  final HadithService _service = HadithService();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  late Future<Hadith> _daily;
  Future<HadithSearchOutcome>? _results;
  bool _onlySahih = false;
  String _lastQuery = '';
  Timer? _debounce;

  static List<String> get _suggestions => [
    tr('الصلاة'),
    tr('الصبر'),
    tr('بر الوالدين'),
    tr('الصدقة'),
    tr('حسن الخلق'),
    tr('الاستغفار'),
    tr('الصيام'),
    tr('الجنة'),
    tr('الجار'),
    tr('النية'),
  ];

  @override
  void initState() {
    super.initState();
    HadithLibrary().warmUp();
    _daily = _service.dailyHadith();
    _service.savedHadithsBox(); // open the box for the saved tab
    if (widget.initialQuery != null) {
      _controller.text = widget.initialQuery!;
      _search(widget.initialQuery!);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _search(String q, {bool unfocus = true}) {
    final query = q.trim();
    if (query.length < 2) {
      setState(() {
        _results = null;
        _lastQuery = '';
      });
      return;
    }
    if (unfocus) _focus.unfocus();
    setState(() {
      _lastQuery = query;
      _results = _service.searchAll(query, onlySahih: _onlySahih);
    });
  }

  void _onChanged(String v) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(Duration(milliseconds: 450),
        () => _search(v, unfocus: false));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLocale.direction,
      child: DefaultTabController(
        length: 2,
        initialIndex: widget.initialTab,
        child: Scaffold(
          backgroundColor: AppStyle.background,
          appBar: AppBar(
            backgroundColor: AppStyle.primaryGreen,
            foregroundColor: Colors.white,
            centerTitle: true,
            title: Text(tr('موسوعة الأحاديث'),
                style: TextStyle(fontWeight: FontWeight.w700)),
            bottom: TabBar(
              indicatorColor: AppStyle.goldColor,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle:
                  TextStyle(fontFamily: 'AppSans', fontWeight: FontWeight.w700),
              tabs: [
                Tab(text: tr('البحث'), icon: Icon(Icons.search_rounded, size: 20)),
                Tab(
                    text: tr('المحفوظات'),
                    icon: Icon(Icons.bookmark_rounded, size: 20)),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _searchTab(),
              _savedTab(),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Search tab
  // ---------------------------------------------------------------------------
  Widget _searchTab() {
    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverToBoxAdapter(child: _searchBox()),
        if (_results == null) ...[
          SliverToBoxAdapter(child: _sectionTitle(tr('حديث اليوم'))),
          SliverToBoxAdapter(
            child: FutureBuilder<Hadith>(
              future: _daily,
              builder: (context, snap) {
                if (!snap.hasData) return _loading();
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: HadithCard(hadith: snap.data!, highlight: true),
                );
              },
            ),
          ),
          SliverToBoxAdapter(child: _sectionTitle(tr('ابحث في موضوع'))),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _suggestions
                    .map((s) => ActionChip(
                          label: Text(s),
                          backgroundColor: Color(0xFFE7F2EE),
                          side: BorderSide.none,
                          labelStyle: TextStyle(
                              color: AppStyle.darkGreen,
                              fontWeight: FontWeight.w600),
                          onPressed: () {
                            _controller.text = s;
                            _search(s);
                          },
                        ))
                    .toList(),
              ),
            ),
          ),
          SliverToBoxAdapter(child: _aboutSources()),
        ] else
          _resultsSliver(),
        SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  Widget _searchBox() {
    return Container(
      color: AppStyle.primaryGreen,
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          TextField(
            controller: _controller,
            focusNode: _focus,
            textInputAction: TextInputAction.search,
            onSubmitted: _search,
            onChanged: _onChanged,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              hintText: tr('اكتب كلمة أو جزءاً من نص الحديث...'),
              prefixIcon:
                  Icon(Icons.search, color: AppStyle.primaryGreen),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => setState(() {
                        _controller.clear();
                        _results = null;
                        _lastQuery = '';
                      }),
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          SizedBox(height: 6),
          Row(
            children: [
              Switch(
                value: _onlySahih,
                activeColor: AppStyle.goldColor,
                onChanged: (v) {
                  setState(() => _onlySahih = v);
                  if (_lastQuery.isNotEmpty) _search(_lastQuery);
                },
              ),
              Text(tr('الأحاديث الصحيحة فقط'),
                  style: TextStyle(color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _resultsSliver() {
    return FutureBuilder<HadithSearchOutcome>(
      future: _results,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return SliverToBoxAdapter(
            child: Column(
              children: [
                _loading(),
                if (!HadithLibrary().isLoaded)
                  Text(tr('جاري تجهيز مكتبة الأحاديث...'),
                      style: const TextStyle(color: AppStyle.textLight)),
              ],
            ),
          );
        }
        if (snap.hasError) {
          return SliverToBoxAdapter(child: _empty(snap.error.toString()));
        }
        final r = snap.data!;
        if (r.items.isEmpty) {
          return SliverToBoxAdapter(
            child: _empty('${tr('لا توجد أحاديث تحتوي على «')}$_lastQuery».\n'
                '${tr('جرّب كلمة أخرى أو جزءاً أقصر من النص.')}'),
          );
        }
        return SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) {
                if (i == 0) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Text(
                          r.total > r.items.length
                              ? '${tr('أول')} ${_ar(r.items.length)} ${tr('من')} ${_ar(r.total)} ${tr('حديثاً')}'
                              : '${_ar(r.total)} ${tr('حديثاً')}',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppStyle.textDark),
                        ),
                        Spacer(),
                        Text('${tr('المصدر')}: ${r.source}',
                            style: TextStyle(
                                color: AppStyle.textLight, fontSize: 12)),
                      ],
                    ),
                  );
                }
                return Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: HadithCard(
                    hadith: r.items[i - 1],
                    collapsible: true,
                  ),
                );
              },
              childCount: r.items.length + 1,
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Saved tab
  // ---------------------------------------------------------------------------
  Widget _savedTab() {
    return FutureBuilder<Box>(
      future: _service.savedHadithsBox(),
      builder: (context, snap) {
        if (!snap.hasData) return _loading();
        return ValueListenableBuilder<Box>(
          valueListenable: snap.data!.listenable(),
          builder: (context, box, _) {
            return FutureBuilder<List<Hadith>>(
              future: _service.savedHadiths(),
              builder: (context, s) {
                final list = s.data ?? <Hadith>[];
                if (s.connectionState != ConnectionState.done &&
                    list.isEmpty) {
                  return _loading();
                }
                if (list.isEmpty) {
                  return _empty(
                      tr('لا توجد أحاديث محفوظة بعد.\nاضغط على أيقونة الحفظ 🔖 في أي حديث لتجده هنا.'),
                      icon: Icons.bookmark_border_rounded);
                }
                return ListView.separated(
                  padding: EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => SizedBox(height: 12),
                  itemBuilder: (_, i) =>
                      HadithCard(hadith: list[i], collapsible: true),
                );
              },
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  Widget _sectionTitle(String t) => Padding(
        padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
        child: Text(t,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppStyle.textDark)),
      );

  Widget _aboutSources() => Padding(
        padding: EdgeInsets.fromLTRB(16, 24, 16, 0),
        child: Container(
          padding: EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppStyle.border),
          ),
          child: Text(
            '${tr('البحث يشمل أكثر من ٣٦ ألف حديث من: صحيح البخاري، صحيح مسلم، سنن أبي داود،')} '
            '${tr('جامع الترمذي، سنن النسائي، سنن ابن ماجه، موطأ مالك، الأربعين النووية والأحاديث القدسية')} '
            '${tr('(أحكام السنن للعلامة الألباني) ويعمل بدون إنترنت، مع نتائج الدرر السنية عند توفرها.')}',
            style: TextStyle(color: AppStyle.textLight, height: 1.7, fontSize: 13),
          ),
        ),
      );

  Widget _loading() => Padding(
        padding: EdgeInsets.all(32),
        child: Center(
            child: CircularProgressIndicator(color: AppStyle.primaryGreen)),
      );

  Widget _empty(String msg, {IconData icon = Icons.search_off_rounded}) {
    return Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(icon, size: 52, color: AppStyle.textLight),
          SizedBox(height: 12),
          Text(msg,
              textAlign: TextAlign.center,
              style: TextStyle(height: 1.7, color: AppStyle.textDark)),
        ],
      ),
    );
  }
}

/// Card used by the hadith screen and the home page.
class HadithCard extends StatefulWidget {
  final Hadith hadith;
  final bool highlight;
  final int? maxLines;
  final bool collapsible;
  final VoidCallback? onTap;

  const HadithCard({
    super.key,
    required this.hadith,
    this.highlight = false,
    this.maxLines,
    this.collapsible = false,
    this.onTap,
  });

  @override
  State<HadithCard> createState() => _HadithCardState();
}

class _HadithCardState extends State<HadithCard> {
  bool _expanded = false;
  bool? _saved;

  @override
  void initState() {
    super.initState();
    _checkSaved();
  }

  Future<void> _checkSaved() async {
    final box = await HadithService().savedHadithsBox();
    if (mounted) setState(() => _saved = box.containsKey(widget.hadith.id));
  }

  Color _gradeColor() {
    final g = widget.hadith.grade ?? '';
    if (widget.hadith.isSahih) return Color(0xFF0F5C4A);
    if (g.contains(tr('حسن'))) return Color(0xFF1B6E8C);
    if (g.contains(tr('ضعيف')) ||
        g.contains(tr('موضوع')) ||
        g.contains(tr('منكر')) ||
        g.contains(tr('باطل'))) {
      return Color(0xFFB3423A);
    }
    return Color(0xFF6B7772);
  }

  static const _textStyle = TextStyle(
    fontFamily: 'Amiri',
    fontSize: 18,
    height: 1.95,
    color: AppStyle.textDark,
  );

  Future<void> _toggleSave() async {
    HapticFeedback.selectionClick();
    final saved = await HadithService().toggleSaved(widget.hadith);
    if (!mounted) return;
    setState(() => _saved = saved);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text(saved ? tr('تم حفظ الحديث في المحفوظات') : tr('تم الحذف من المحفوظات'))));
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.hadith;
    final long = h.text.length > 420;
    final int? lines = widget.maxLines ??
        (widget.collapsible && long && !_expanded ? 7 : null);
    final details = <MapEntry<String, String>>[
      if (h.narrator != null) MapEntry(tr('الراوي'), h.narrator!),
      if (h.muhaddith != null) MapEntry(tr('المحدث'), tr(h.muhaddith!)),
      if (h.source != null && h.source!.isNotEmpty)
        MapEntry(tr('المصدر'), tr(h.source!)),
      if (h.number != null) MapEntry(tr('الرقم'), _ar(h.number!)),
    ];

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: widget.onTap ??
            (widget.collapsible && long
                ? () => setState(() => _expanded = !_expanded)
                : null),
        child: Container(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: widget.highlight
                    ? AppStyle.goldColor.withOpacity(0.5)
                    : AppStyle.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (lines != null)
                Text(
                  h.text,
                  textDirection: TextDirection.rtl,
                  maxLines: lines,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.justify,
                  style: _textStyle,
                )
              else
                SelectableText(h.text,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.justify,
                    style: _textStyle),
              if (widget.collapsible && long)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    child: Text(_expanded ? tr('عرض أقل') : tr('عرض الحديث كاملاً')),
                  ),
                ),
              if (widget.maxLines == null) ...[
                SizedBox(height: 6),
                Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: details
                      .map((e) => Text.rich(
                            TextSpan(children: [
                              TextSpan(
                                  text: '${e.key}: ',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppStyle.primaryGreen)),
                              TextSpan(text: e.value),
                            ]),
                            style: TextStyle(
                                fontSize: 13, color: AppStyle.textLight),
                          ))
                      .toList(),
                ),
                if (h.explanation != null && h.explanation!.isNotEmpty)
                  Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(tr('شرح الحديث'),
                          style: TextStyle(
                              color: AppStyle.primaryGreen,
                              fontWeight: FontWeight.w700)),
                      children: [
                        Text(h.explanation!,
                            textAlign: TextAlign.justify,
                            style: TextStyle(height: 1.8)),
                      ],
                    ),
                  ),
              ],
              SizedBox(height: 4),
              Row(
                children: [
                  if (h.grade != null && h.grade!.isNotEmpty)
                    Flexible(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _gradeColor().withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          tr(h.grade!),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: _gradeColor(),
                              fontSize: 12,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  Spacer(),
                  IconButton(
                    tooltip: _saved == true ? tr('إزالة من المحفوظات') : tr('حفظ'),
                    icon: Icon(
                      _saved == true
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      color: _saved == true
                          ? AppStyle.goldColor
                          : AppStyle.textLight,
                    ),
                    onPressed: _toggleSave,
                  ),
                  IconButton(
                    tooltip: tr('نسخ'),
                    icon: Icon(Icons.copy_rounded,
                        color: AppStyle.textLight, size: 21),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: h.shareText()));
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(tr('تم نسخ الحديث'))));
                    },
                  ),
                  IconButton(
                    tooltip: tr('مشاركة'),
                    icon: Icon(Icons.ios_share_rounded,
                        color: AppStyle.textLight, size: 21),
                    onPressed: () => Share.share(h.shareText()),
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
