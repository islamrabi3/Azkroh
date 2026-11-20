import 'package:azkroh_app/l10n/app_locale.dart';
import 'package:azkroh_app/features/presentation/screens/location_picker_sheet.dart';
import 'dart:async';

import 'package:adhan/adhan.dart' as adhan;
import 'package:azkroh_app/features/core/appstyle.dart';
import 'package:azkroh_app/features/core/prayer_notification_scheduler.dart';
import 'package:azkroh_app/features/core/services/azan_audio_service.dart';
import 'package:azkroh_app/features/core/services/global_location_service.dart';
import 'package:azkroh_app/features/core/services/prayer_times_service.dart';
import 'package:azkroh_app/features/presentation/cubit/cubit.dart';
import 'package:azkroh_app/features/presentation/screens/azan_settings_screen.dart';
import 'package:azkroh_app/features/presentation/screens/homescreen.dart'
    show arNum;
import 'package:azkroh_app/features/presentation/screens/professional_splash_screen.dart'
    show IslamicStarPainter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:shared_preferences/shared_preferences.dart';

/// Prayer times: live countdown, any-day browsing and per-prayer Adhan toggle.
class PrayerScreen extends StatefulWidget {
  const PrayerScreen({super.key});

  @override
  State<PrayerScreen> createState() => _PrayerScreenState();
}

class _Row {
  final String key;
  final String name;
  final IconData icon;
  final DateTime time;
  final bool isPrayer;

  _Row(this.key, this.name, this.icon, this.time, {this.isPrayer = true});
}

class _PrayerScreenState extends State<PrayerScreen> {
  final _service = PrayerTimesService();
  final _azan = AzanAudioService();
  Timer? _ticker;
  DateTime _now = DateTime.now();
  int _dayOffset = 0;
  List<double>? _coords;
  List<_Row> _rows = [];
  List<_Row> _tomorrow = [];
  adhan.PrayerTimes? _times;
  String _methodLabel = '';
  final Map<String, bool> _azanOn = {};
  bool _loading = true;

  static const _icons = {
    'fajr': Icons.nights_stay_outlined,
    'sunrise': Icons.wb_twilight_rounded,
    'dhuhr': Icons.wb_sunny_outlined,
    'asr': Icons.sunny_snowing,
    'maghrib': Icons.brightness_4_outlined,
    'isha': Icons.dark_mode_outlined,
  };

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(Duration(seconds: 1), (_) {
      if (!mounted) return;
      final n = DateTime.now();
      final dayChanged = n.day != _now.day;
      setState(() => _now = n);
      if (dayChanged) _load();
    });
    _load();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final pos = GlobalLocationService().currentPosition;
    _coords = null;
    if (pos != null) {
      _coords = [pos.latitude, pos.longitude];
    } else {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble('cached_latitude');
      final lon = prefs.getDouble('cached_longitude');
      if (lat != null && lon != null) _coords = [lat, lon];
    }
    if (_coords == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    var key = await _service.getMethodKey();
    if (key == 'auto') key = _service.autoMethodFor(_coords![0], _coords![1]);
    _methodLabel = tr(PrayerTimesService.methodLabels[key] ?? '');

    for (final name in PrayerTimesService.arabicNames.values) {
      _azanOn[name] = await _azan.isAzanEnabledForPrayer(name);
    }
    await _loadDay();
  }

  Future<void> _loadDay() async {
    final base = DateTime(_now.year, _now.month, _now.day + _dayOffset);
    _times = await _service.timesFor(_coords![0], _coords![1], base);
    final slots = await _service.slotsFor(_coords![0], _coords![1], base,
        includeSunrise: true);
    final next = await _service.slotsFor(
        _coords![0], _coords![1], base.add(Duration(days: 1)));
    _rows = slots
        .map((s) => _Row(s.key, s.arabicName, _icons[s.key]!, s.time,
            isPrayer: s.key != 'sunrise'))
        .toList();
    _tomorrow = next
        .map((s) => _Row(s.key, s.arabicName, _icons[s.key]!, s.time))
        .toList();
    if (mounted) setState(() => _loading = false);
  }

  void _changeDay(int delta) {
    HapticFeedback.selectionClick();
    setState(() => _dayOffset += delta);
    _loadDay();
  }

  Future<void> _toggleAzan(String name) async {
    HapticFeedback.selectionClick();
    final v = !(_azanOn[name] ?? true);
    setState(() => _azanOn[name] = v);
    await _azan.setAzanEnabledForPrayer(name, v);
    PrayerNotificationScheduler().scheduleUpcoming();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text(v
              ? '${tr('سيُرفع الأذان لصلاة')} $name'
              : '${tr('تم كتم أذان')} $name (${tr('سيصلك تنبيه صامت')})')));
  }

  String _fmt(DateTime t) => formatTime(t).split(' ').first;

  // ignore: unused_element
  String _fmtOld(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '${arNum(h)}:${arNum(t.minute.toString().padLeft(2, '0'))}';
  }

  

  _Row? get _nextRow {
    final today = _dayOffset == 0 ? _rows : <_Row>[];
    for (final r in today) {
      if (r.isPrayer && r.time.isAfter(_now)) return r;
    }
    if (_dayOffset == 0 && _tomorrow.isNotEmpty) return _tomorrow.first;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLocale.direction,
      child: Scaffold(
        backgroundColor: AppStyle.background,
        body: _loading
            ? Center(
                child: CircularProgressIndicator(color: AppStyle.primaryGreen))
            : _coords == null
                ? _noLocation()
                : CustomScrollView(
                    physics: const ClampingScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(child: _header()),
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 32),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            _daySelector(),
                            SizedBox(height: 12),
                            ..._rows.map(_prayerTile),
                            SizedBox(height: 14),
                            _nightCard(),
                            SizedBox(height: 14),
                            _settingsTile(),
                          ]),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _noLocation() {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_off_outlined,
                  size: 56, color: AppStyle.textLight),
              SizedBox(height: 12),
              Text(tr('نحتاج إلى موقعك لحساب مواقيت الصلاة بدقة'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  setState(() => _loading = true);
                  await GlobalLocationService().getCurrentLocation();
                  await _load();
                  if (mounted) {
                    context.read<AppCubit>().getPrayerTimeFromApi();
                  }
                },
                icon: Icon(Icons.my_location),
                label: Text(tr('تحديد الموقع')),
              ),
              SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _changeLocation,
                icon: Icon(Icons.location_city_rounded),
                label: Text(tr('اختيار المدينة يدوياً')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final next = _nextRow;
    final remaining = next?.time.difference(_now);
    String two(int n) => arNum(n.toString().padLeft(2, '0'));

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
            right: -60,
            bottom: -80,
            child: Opacity(
              opacity: 0.08,
              child: CustomPaint(
                size: Size.square(240),
                painter:
                    IslamicStarPainter(color: Colors.white, stroke: true),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(8, 4, 8, 26),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white),
                        onPressed: () => Navigator.maybePop(context),
                      ),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _changeLocation,
                          child: Column(
                            children: [
                              Text(tr('مواقيت الصلاة'),
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700)),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.location_on_outlined,
                                      size: 14, color: AppStyle.goldColor),
                                  SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      GlobalLocationService().cityName ??
                                          tr('موقعك الحالي'),
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: Colors.white.withOpacity(0.8),
                                          fontSize: 12.5),
                                    ),
                                  ),
                                  Icon(Icons.expand_more_rounded,
                                      size: 16,
                                      color: Colors.white.withOpacity(0.8)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.tune_rounded,
                            color: Colors.white),
                        onPressed: _openSettings,
                      ),
                    ],
                  ),
                  SizedBox(height: 14),
                  if (next != null && remaining != null) ...[
                    Text(tr('الصلاة القادمة'),
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 13)),
                    SizedBox(height: 2),
                    Text('${tr(next.name)} • ${formatTime(next.time)}',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700)),
                    SizedBox(height: 10),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _timeBox(two(remaining.inHours), tr('ساعة')),
                          _colon(),
                          _timeBox(two(remaining.inMinutes % 60), tr('دقيقة')),
                          _colon(),
                          _timeBox(two(remaining.inSeconds % 60), tr('ثانية')),
                        ],
                      ),
                    ),
                  ],
                  SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calculate_outlined,
                          size: 15, color: Colors.white.withOpacity(0.6)),
                      SizedBox(width: 4),
                      Flexible(
                        child: Text(_methodLabel,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeBox(String v, String label) {
    return Container(
      width: 74,
      padding: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        children: [
          Text(v,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()])),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.6), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _colon() => Padding(
        padding: EdgeInsets.symmetric(horizontal: 6),
        child: Text(':',
            style: TextStyle(
                color: AppStyle.goldColor,
                fontSize: 24,
                fontWeight: FontWeight.w700)),
      );

  Widget _daySelector() {
    final date = DateTime(_now.year, _now.month, _now.day + _dayOffset);
    final hijri = HijriCalendar.fromDate(date);
    final label = _dayOffset == 0
        ? tr('اليوم')
        : _dayOffset == 1
            ? tr('غداً')
            : _dayOffset == -1
                ? tr('أمس')
                : DateFormat('EEEE', dateLocale).format(date);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left_rounded,
                color: AppStyle.primaryGreen),
            onPressed: () => _changeDay(-1),
          ),
          Expanded(
            child: GestureDetector(
              onTap: _dayOffset == 0
                  ? null
                  : () {
                      setState(() => _dayOffset = 0);
                      _loadDay();
                    },
              child: Column(
                children: [
                  Text(label,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppStyle.textDark)),
                  Text(
                      '${arNum(hijri.hDay)} ${hijri.longMonthName} ${arNum(hijri.hYear)} • ${DateFormat('d MMMM', dateLocale).format(date)}',
                      style: TextStyle(
                          fontSize: 12, color: AppStyle.textLight)),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right_rounded,
                color: AppStyle.primaryGreen),
            onPressed: () => _changeDay(1),
          ),
        ],
      ),
    );
  }

  Widget _prayerTile(_Row r) {
    final next = _nextRow;
    final isNext = _dayOffset == 0 && next != null && next.key == r.key &&
        next.time == r.time;
    final passed = _dayOffset < 0 || (_dayOffset == 0 && r.time.isBefore(_now));
    final azanOn = _azanOn[r.name] ?? true;

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isNext ? AppStyle.primaryGreen : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: isNext ? null : Border.all(color: AppStyle.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isNext
                  ? Colors.white.withOpacity(0.12)
                  : Color(0xFFE7F2EE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(r.icon,
                color: isNext ? AppStyle.goldColor : AppStyle.primaryGreen,
                size: 22),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(tr(r.name),
                style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    color: isNext
                        ? Colors.white
                        : passed
                            ? AppStyle.textLight
                            : AppStyle.textDark)),
          ),
          Text('${formatTime(r.time)}',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: isNext
                      ? Colors.white
                      : passed
                          ? AppStyle.textLight
                          : AppStyle.textDark)),
          SizedBox(width: 6),
          if (r.isPrayer)
            IconButton(
              tooltip: azanOn ? tr('الأذان مفعل') : tr('الأذان مكتوم'),
              onPressed: () => _toggleAzan(r.name),
              icon: Icon(
                azanOn
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_off_outlined,
                color: isNext
                    ? AppStyle.goldColor
                    : azanOn
                        ? AppStyle.primaryGreen
                        : AppStyle.textLight,
              ),
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _nightCard() {
    final t = _times;
    if (t == null || _tomorrow.isEmpty) return SizedBox.shrink();
    final maghrib = t.maghrib.toLocal();
    final fajr = _tomorrow.first.time;
    final night = fajr.difference(maghrib);
    final midnight = maghrib.add(night ~/ 2);
    final lastThird = maghrib.add(night * 2 ~/ 3);

    Widget item(String title, DateTime time, IconData icon) => Expanded(
          child: Column(
            children: [
              Icon(icon, color: AppStyle.goldColor, size: 20),
              SizedBox(height: 4),
              Text(title,
                  style: TextStyle(
                      color: Colors.white70, fontSize: 12)),
              Text('${formatTime(time)}',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
            ],
          ),
        );

    return Container(
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Color(0xFF1E2A55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          item(tr('منتصف الليل'), midnight, Icons.bedtime_outlined),
          Container(width: 1, height: 40, color: Colors.white12),
          item(tr('الثلث الأخير'), lastThird, Icons.auto_awesome_outlined),
        ],
      ),
    );
  }

  Widget _settingsTile() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        leading: Icon(Icons.volume_up_outlined,
            color: AppStyle.primaryGreen),
        title: Text(tr('إعدادات الأذان وطريقة الحساب'),
            style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(tr('صوت الأذان، التنبيه قبل الصلاة، الضبط اليدوي')),
        trailing: Icon(Icons.chevron_right_rounded),
        onTap: _openSettings,
      ),
    );
  }

  Future<void> _changeLocation() async {
    final changed = await showLocationPicker(context);
    if (changed != true || !mounted) return;
    setState(() => _loading = true);
    _coords = null;
    await _load();
    if (mounted) context.read<AppCubit>().getPrayerTimeFromApi();
  }

  Future<void> _openSettings() async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => AzanSettingsScreen()));
    setState(() => _loading = true);
    await _load();
  }
}
