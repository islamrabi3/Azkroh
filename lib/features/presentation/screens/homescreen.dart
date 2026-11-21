import 'package:azkroh_app/features/presentation/screens/game/quiz_screens.dart';
import 'package:azkroh_app/features/presentation/screens/home_extras.dart';
import 'package:azkroh_app/features/core/notification_router.dart';
import 'package:azkroh_app/features/presentation/screens/listen/listen_screen.dart';
import 'package:azkroh_app/features/core/widgets/app_loader.dart';
import 'package:azkroh_app/features/presentation/screens/support_sheet.dart';
import 'package:azkroh_app/features/core/notification_service.dart';
import 'package:azkroh_app/l10n/app_locale.dart';
import 'dart:async';
import 'dart:io';

import 'package:azkroh_app/features/core/appstyle.dart';
import 'package:azkroh_app/features/core/methods/methods.dart';
import 'package:azkroh_app/features/core/services/app_store_service.dart';
import 'package:azkroh_app/features/core/services/azkar_state_service.dart';
import 'package:upgrader/upgrader.dart';
import 'package:azkroh_app/features/core/services/hadith_service.dart';
import 'package:azkroh_app/features/presentation/cubit/cubit.dart';
import 'package:azkroh_app/features/presentation/cubit/states.dart';
import 'package:azkroh_app/features/presentation/screens/all_screen/enhanced_hijri_screen.dart';
import 'package:azkroh_app/features/presentation/screens/all_screen/paryer_time_screen.dart';
import 'package:azkroh_app/features/presentation/screens/all_screen/qibla_screen.dart';
import 'package:azkroh_app/features/presentation/screens/all_screen/radio_screen.dart';
import 'package:azkroh_app/features/presentation/screens/all_screen/sebha.dart';
import 'package:azkroh_app/features/presentation/screens/enhanced_azkar_screen.dart';
import 'package:azkroh_app/features/presentation/screens/hadith/hadith_screen.dart';
import 'package:azkroh_app/features/presentation/screens/notification_settings_screen.dart';
import 'package:azkroh_app/features/presentation/screens/professional_splash_screen.dart';
import 'package:azkroh_app/features/presentation/screens/quran_screen_locally/mushaf_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:qcf_quran_plus/qcf_quran_plus.dart' as qcf;
import 'package:shared_preferences/shared_preferences.dart';

class HomePageScreen extends StatefulWidget {
  const HomePageScreen({super.key});

  @override
  State<HomePageScreen> createState() => _HomePageScreenState();
}

/// Arabic-Indic digits.
String arNum(Object n) {
  const d = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  return AppLocale.digits(n);
  // ignore: dead_code
  return n
      .toString()
      .split('')
      .map((c) => (c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57)
          ? d[c.codeUnitAt(0) - 48]
          : c)
      .join();
}

class _HomePageScreenState extends State<HomePageScreen> {
  final AzkarStateService _azkarService = AzkarStateService();
  final Future<Hadith> _dailyHadith = HadithService().dailyHadith();
  Timer? _ticker;
  DateTime _now = DateTime.now();
  int _hijriAdjust = 0;
  int? _lastPage;
  int? _lastSurah;
  int? _lastVerse;
  int? _bmSurah;
  int? _bmVerse;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _ticker = Timer.periodic(Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _loadPrefs();
    AppStoreService()
        .registerLaunchAndMaybeAskReview()
        .then((_) => AppStoreService().refreshRatingCard());
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      NotificationRouter.homeReady();
      final granted = await NotificationService().requestPermissions();
      if (granted && mounted) {
        // Schedule now that we're allowed to.
        context.read<AppCubit>().getPrayerTimeFromApi();
      }
      if (mounted) AppStoreService().checkAndroidUpdate(context);
    });
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _hijriAdjust = prefs.getInt('hijri_adjust') ?? 0;
      _lastPage = prefs.getInt('mushaf_last_page');
      _lastSurah = prefs.getInt('last_ayah_surah');
      _lastVerse = prefs.getInt('last_ayah_verse');
      _bmSurah = prefs.getInt('mushaf_bookmark_page') == null
          ? null
          : prefs.getInt('bookmarkedSurah');
      _bmVerse = prefs.getInt('bookmarkedVerse');
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data helpers
  // ---------------------------------------------------------------------------
  String _greeting() {
    final h = _now.hour;
    if (h < 4) return tr('طابت ليلتك');
    if (h < 12) return tr('صباح الخير');
    if (h < 18) return tr('مساء الخير');
    return tr('مساء النور');
  }

  DateTime? _parse(String? hhmm, DateTime day) {
    if (hhmm == null) return null;
    try {
      final p = hhmm.split(' ').first.split(':');
      return DateTime(
          day.year, day.month, day.day, int.parse(p[0]), int.parse(p[1]));
    } catch (_) {
      return null;
    }
  }

  String _fmt(DateTime t) => formatTime(t).split(' ').first;

  // ignore: unused_element
  String _fmtOld(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '${arNum(h)}:${arNum(t.minute.toString().padLeft(2, '0'))}';
  }

  

  List<_PrayerItem> _prayers(AppCubit cubit) {
    final t = cubit.azanEntityData?.data.timings;
    if (t == null) return [];
    final day = DateTime(_now.year, _now.month, _now.day);
    final list = <_PrayerItem>[
      _PrayerItem(tr('الفجر'), Icons.nights_stay_outlined, _parse(t.fajr, day)),
      _PrayerItem(tr('الشروق'), Icons.wb_twilight_rounded, _parse(t.sunrise, day),
          isPrayer: false),
      _PrayerItem(tr('الظهر'), Icons.wb_sunny_outlined, _parse(t.dhuhr, day)),
      _PrayerItem(tr('العصر'), Icons.sunny_snowing, _parse(t.asr, day)),
      _PrayerItem(
          tr('المغرب'), Icons.brightness_4_outlined, _parse(t.maghrib, day)),
      _PrayerItem(tr('العشاء'), Icons.dark_mode_outlined, _parse(t.isha, day)),
    ];
    return list.where((e) => e.time != null).toList();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppCubit, Appstates>(
      builder: (context, state) {
        final cubit = context.read<AppCubit>();
        final scaffold = Scaffold(
          backgroundColor: AppStyle.background,
          body: RefreshIndicator(
            color: AppStyle.primaryGreen,
            onRefresh: () async {
              await cubit.getPrayerTimeFromApi();
              await _loadPrefs();
            },
            child: CustomScrollView(
              // Clamped: no overscroll bounce revealing the background.
              physics: const ClampingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                SliverToBoxAdapter(child: _header(cubit, state)),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 18, 16, 32),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _quickActions(),
                      SizedBox(height: 22),
                      _continueReading(),
                      SizedBox(height: 12),
                      const RuqyahLiveCard(),
                      const RatingCard(),
                      const RemoteContentStrip(),
                      if (_bmSurah != null && _bmVerse != null) ...[
                        SizedBox(height: 10),
                        _bookmarkTile(),
                      ],
                      SizedBox(height: 26),
                      _sectionTitle(tr('الأذكار'), Icons.auto_awesome_rounded,
                          trailing: _azkarHint()),
                      SizedBox(height: 12),
                      _azkarStrip(cubit),
                      SizedBox(height: 26),
                      _sectionTitle(tr('حديث اليوم'), Icons.format_quote_rounded,
                          onMore: () =>
                              navigateTo(context, HadithScreen())),
                      SizedBox(height: 12),
                      _hadithCard(),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        );
        return Directionality(
          textDirection: AppLocale.direction,
          // iOS: App Store update dialog (Android uses Google Play in-app update).
          child: Platform.isIOS
              ? UpgradeAlert(
                  upgrader: Upgrader(languageCode: 'ar'),
                  showIgnore: false,
                  dialogStyle: UpgradeDialogStyle.cupertino,
                  child: scaffold,
                )
              : scaffold,
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Header: greeting, Hijri date, next prayer, prayer row
  // ---------------------------------------------------------------------------
  Widget _header(AppCubit cubit, Appstates state) {
    final hijri =
        HijriCalendar.fromDate(_now.add(Duration(days: _hijriAdjust)));
    final greg = DateFormat('EEEE، d MMMM y', dateLocale).format(_now);
    final prayers = _prayers(cubit);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF0F5C4A), Color(0xFF0B3D33)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Stack(
        children: [
          Positioned(
            left: -70,
            top: -40,
            child: Opacity(
              opacity: 0.08,
              child: CustomPaint(
                size: Size.square(260),
                painter:
                    IslamicStarPainter(color: Colors.white, stroke: true),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_greeting(),
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.75),
                                    fontSize: 14)),
                            Text(tr('أذكروه'),
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      _glassIcon(Icons.settings_outlined, () async {
                        await navigateTo(
                            context, NotificationSettingsScreen());
                        _loadPrefs();
                      }),
                    ],
                  ),
                  SizedBox(height: 16),
                  // Hijri date
                  InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () =>
                        navigateTo(context, EnhancedHijriScreen()),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(18),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.12)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: AppStyle.goldColor,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            alignment: Alignment.center,
                            child: Text(arNum(hijri.hDay),
                                style: TextStyle(
                                    color: Color(0xFF0B3D33),
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700)),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    '${hijri.longMonthName} ${arNum(hijri.hYear)} ${tr('هـ')}',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700)),
                                SizedBox(height: 2),
                                Text(greg,
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 12.5)),
                              ],
                            ),
                          ),
                          Icon(Icons.calendar_month_outlined,
                              color: Colors.white.withOpacity(0.7)),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 14),
                  _prayerPanel(prayers, state),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassIcon(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white.withOpacity(0.12),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  Widget _prayerPanel(List<_PrayerItem> prayers, Appstates state) {
    if (prayers.isEmpty) {
      final loading =
          state is GetPrayerTimeLoadingState || state is AppInitState;
      return Container(
        height: 150,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        alignment: Alignment.center,
        child: loading
            ? AppLoader(color: AppStyle.primaryGreen)
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_off_outlined,
                      color: AppStyle.textLight),
                  SizedBox(height: 6),
                  Text(tr('فعّل الموقع لعرض مواقيت الصلاة')),
                  TextButton(
                    onPressed: () =>
                        context.read<AppCubit>().getPrayerTimeFromApi(),
                    child: Text(tr('إعادة المحاولة')),
                  ),
                ],
              ),
      );
    }

    // Next prayer (only real prayers, not sunrise)
    _PrayerItem? next;
    for (final p in prayers) {
      if (p.isPrayer && p.time!.isAfter(_now)) {
        next = p;
        break;
      }
    }
    final nextTime = next?.time ??
        prayers.first.time!.add(Duration(days: 1)); // Fajr tomorrow
    final nextName = next?.name ?? tr('الفجر');
    final remaining = nextTime.difference(_now);
    String two(int n) => arNum(n.toString().padLeft(2, '0'));
    final countdown =
        '${two(remaining.inHours)}:${two(remaining.inMinutes % 60)}:${two(remaining.inSeconds % 60)}';

    // Current period = last prayer whose time has passed.
    String? current;
    for (final p in prayers) {
      if (p.isPrayer && !p.time!.isAfter(_now)) current = p.name;
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => navigateTo(context, PrayerScreen()),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr('الصلاة القادمة'),
                            style: TextStyle(
                                color: AppStyle.textLight, fontSize: 12.5)),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(nextName,
                                style: TextStyle(
                                    color: AppStyle.darkGreen,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700)),
                            SizedBox(width: 8),
                            Text('${formatTime(nextTime)}',
                                style: TextStyle(
                                    color: AppStyle.textLight,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Color(0xFFE7F2EE),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Text(tr('متبقي'),
                            style: TextStyle(
                                color: AppStyle.primaryGreen, fontSize: 11)),
                        Text(countdown,
                            style: TextStyle(
                                color: AppStyle.primaryGreen,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                fontFeatures: [FontFeature.tabularFigures()])),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Divider(height: 1, color: AppStyle.border),
              SizedBox(height: 10),
              Row(
                children: prayers.map((p) {
                  final isNext = p.name == nextName;
                  final isCurrent = p.name == current;
                  return Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      margin: EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color:
                            isNext ? AppStyle.primaryGreen : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(p.icon,
                              size: 18,
                              color: isNext
                                  ? AppStyle.goldColor
                                  : isCurrent
                                      ? AppStyle.primaryGreen
                                      : AppStyle.textLight),
                          SizedBox(height: 3),
                          Text(p.name,
                              style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: isNext
                                      ? Colors.white
                                      : p.isPrayer
                                          ? AppStyle.textDark
                                          : AppStyle.textLight)),
                          Text(_fmt(p.time!),
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isNext
                                      ? Colors.white
                                      : AppStyle.textDark)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Quick actions grid
  // ---------------------------------------------------------------------------
  Widget _quickActions() {
    final items = <_Action>[
      _Action(tr('المصحف'), Icons.menu_book_rounded, Color(0xFF0F5C4A),
          () async {
        await MushafScreen.openLastRead(context);
        _loadPrefs();
      }),
      _Action(tr('الأحاديث'), Icons.auto_stories_outlined, Color(0xFF8C5A2B),
          () => navigateTo(context, HadithScreen())),
      _Action(tr('الصلاة'), Icons.access_time_rounded, Color(0xFF1B6E8C),
          () => navigateTo(context, PrayerScreen())),
      _Action(tr('القبلة'), Icons.explore_outlined, Color(0xFF6A4C93),
          () => navigateTo(context, QibalScreen())),
      _Action(tr('السبحة'), Icons.fingerprint_rounded, Color(0xFFA8842C),
          () => navigateTo(context, const Sebha())),
      _Action(tr('الإذاعة'), Icons.radio_outlined, Color(0xFFB3423A),
          () => navigateTo(context, RadioScreen())),
      _Action(tr('الاستماع'), Icons.headphones_rounded, Color(0xFF2E7D6B),
          () => navigateTo(context, const ListenScreen())),
      _Action(tr('المسابقة'), Icons.emoji_events_rounded, Color(0xFFC9A227),
          () => navigateTo(context, const QuizHomeScreen())),
      _Action(tr('التقويم'), Icons.calendar_month_rounded, Color(0xFF3B4C8C),
          () => navigateTo(context, EnhancedHijriScreen())),
      if (showSupportCard)
        _Action(tr('ادعمنا'), Icons.volunteer_activism_rounded,
            Color(0xFFC2185B), () => showSupportSheet(context)),
      _Action(tr('الإعدادات'), Icons.tune_rounded, Color(0xFF55606B),
          () async {
        await navigateTo(context, NotificationSettingsScreen());
        _loadPrefs();
      }),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 10,
        childAspectRatio: 0.86,
      ),
      itemBuilder: (_, i) {
        final a = items[i];
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              HapticFeedback.selectionClick();
              a.onTap();
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: a.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(a.icon, color: a.color, size: 24),
                ),
                SizedBox(height: 8),
                Text(a.title,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppStyle.textDark)),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Continue reading
  // ---------------------------------------------------------------------------
  Widget _continueReading() {
    final page = (_lastPage ?? 1).clamp(1, 604);
    String surah = tr('الفاتحة');
    int juz = 1;
    String? ayahLabel;
    try {
      int s = (qcf.getPageData(page).first as Map)['surah'] as int;
      int v = (qcf.getPageData(page).first as Map)['start'] as int;
      // Prefer the exact ayah the user stopped at, when it is on this page
      // (a page can hold the end of one surah and the start of the next).
      if (_lastSurah != null &&
          _lastVerse != null &&
          qcf.getPageNumber(_lastSurah!, _lastVerse!) == page) {
        s = _lastSurah!;
        v = _lastVerse!;
        ayahLabel = '${tr('الآية')} ${arNum(v)}';
      }
      surah = surahName(s);
      juz = qcf.getJuzNumber(s, v);
    } catch (_) {}
    final progress = page / 604;

    return Material(
      color: Color(0xFFFFFBF1),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () async {
          await MushafScreen.openLastRead(context);
          _loadPrefs();
        },
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppStyle.goldColor.withOpacity(0.35)),
          ),
          child: Row(
            children: [
              AppEmblem(size: 58, background: Color(0xFFFFFBF1)),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_lastPage == null ? tr('ابدأ القراءة') : tr('تابع القراءة'),
                        style: TextStyle(
                            color: AppStyle.textLight, fontSize: 12.5)),
                    Text('${tr('سورة')} $surah',
                        style: TextStyle(
                            color: AppStyle.darkGreen,
                            fontSize: 19,
                            fontWeight: FontWeight.w700)),
                    Text(
                        ayahLabel != null
                            ? '$ayahLabel • ${tr('الجزء')} ${arNum(juz)} • ${tr('صفحة')} ${arNum(page)}'
                            : '${tr('الجزء')} ${arNum(juz)} • ${tr('صفحة')} ${arNum(page)}',
                        style: TextStyle(
                            color: AppStyle.textLight, fontSize: 12.5)),
                    SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 5,
                        color: AppStyle.goldColor,
                        backgroundColor: AppStyle.border,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppStyle.primaryGreen,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.arrow_forward_rounded,
                    color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bookmarkTile() {
    final s = _bmSurah!, v = _bmVerse!;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        leading: Icon(Icons.bookmark_rounded, color: AppStyle.goldColor),
        title: Text(tr('العلامة المحفوظة'),
            style: TextStyle(fontSize: 12.5, color: AppStyle.textLight)),
        subtitle: Text('${tr('سورة')} ${surahName(s)} • ${tr('الآية')} ${arNum(v)}',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppStyle.textDark)),
        trailing: Icon(Icons.chevron_right_rounded),
        onTap: () async {
          await Navigator.of(context).push(MushafScreen.routeTo(s, verse: v));
          _loadPrefs();
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Azkar
  // ---------------------------------------------------------------------------
  Widget _azkarHint() {
    final period = _azkarService.getCurrentPeriod();
    if (period == AzkarPeriod.none) return SizedBox.shrink();
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppStyle.goldColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        period == AzkarPeriod.morning
            ? tr('حان وقت أذكار الصباح')
            : tr('حان وقت أذكار المساء'),
        style: TextStyle(
            color: AppStyle.darkGold,
            fontSize: 11.5,
            fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _azkarStrip(AppCubit cubit) {
    const icons = [
      Icons.wb_sunny_rounded,
      Icons.nights_stay_rounded,
      Icons.mosque_outlined,
      Icons.spa_outlined,
      Icons.shield_moon_outlined,
    ];
    const colors = [
      [Color(0xFFF2B33D), Color(0xFFE07A2F)],
      [Color(0xFF3B4C8C), Color(0xFF1E2A55)],
      [Color(0xFF0F5C4A), Color(0xFF0B3D33)],
      [Color(0xFF6B7772), Color(0xFF3F4A46)],
      [Color(0xFF8C5A2B), Color(0xFF5E3A1A)],
    ];
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: BouncingScrollPhysics(),
        itemCount: cubit.azkarMap.length,
        separatorBuilder: (_, __) => SizedBox(width: 10),
        itemBuilder: (_, i) {
          final azkar = cubit.azkarMap[i];
          final title = (azkar['title'] as String).trim();
          String type = 'other';
          if (title == 'أذكار الصباح') type = 'morning';
          if (title == 'أذكار المساء') type = 'evening';
          final active =
              (type == 'morning' && _azkarService.isMorningAzkarTime()) ||
                  (type == 'evening' && _azkarService.isEveningAzkarTime());
          final c = colors[i % colors.length];
          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => navigateTo(
              context,
              EnhancedAzkarScreen(
                pageTitle: title,
                listOfDoaaModel: azkar['zekr_contetnt'],
                azkarType: type,
              ),
            ),
            child: Container(
              width: 128,
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: c,
                ),
                border: active
                    ? Border.all(color: AppStyle.goldColor, width: 2)
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icons[i % icons.length],
                          color: Colors.white, size: 26),
                      Spacer(),
                      if (active)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: AppStyle.goldColor,
                              shape: BoxShape.circle),
                        ),
                    ],
                  ),
                  Spacer(),
                  Text(tr(title),
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _hadithCard() {
    return FutureBuilder<Hadith>(
      future: _dailyHadith,
      builder: (context, snap) {
        if (!snap.hasData) {
          return Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.center,
            child:
                AppLoader(color: AppStyle.primaryGreen),
          );
        }
        return HadithCard(
          hadith: snap.data!,
          highlight: true,
          maxLines: 5,
          onTap: () => navigateTo(context, HadithScreen()),
        );
      },
    );
  }

  Widget _sectionTitle(String title, IconData icon,
      {VoidCallback? onMore, Widget? trailing}) {
    return Row(
      children: [
        Icon(icon, color: AppStyle.goldColor, size: 20),
        SizedBox(width: 8),
        Text(tr(title),
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppStyle.textDark)),
        Spacer(),
        if (trailing != null) trailing,
        if (onMore != null)
          TextButton(
            onPressed: onMore,
            child: Text(tr('عرض المزيد'),
                style: TextStyle(color: AppStyle.primaryGreen)),
          ),
      ],
    );
  }
}

class _PrayerItem {
  final String name;
  final IconData icon;
  final DateTime? time;
  final bool isPrayer;

  _PrayerItem(this.name, this.icon, this.time, {this.isPrayer = true});
}

class _Action {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _Action(this.title, this.icon, this.color, this.onTap);
}
