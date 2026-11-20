import 'dart:io';
import 'package:azkroh_app/features/core/appstyle.dart';
import 'package:azkroh_app/features/core/dhikr_notification_scheduler.dart';
import 'package:azkroh_app/features/core/notification_service.dart';
import 'package:azkroh_app/features/core/prayer_notification_scheduler.dart';
import 'package:azkroh_app/features/core/services/app_store_service.dart';
import 'package:azkroh_app/features/core/services/global_location_service.dart';
import 'package:azkroh_app/features/core/services/quran_audio_service.dart';
import 'package:azkroh_app/features/presentation/cubit/cubit.dart';
import 'package:azkroh_app/features/presentation/screens/azan_settings_screen.dart';
import 'package:azkroh_app/features/presentation/screens/location_picker_sheet.dart';
import 'package:azkroh_app/l10n/app_locale.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App settings. Every change is applied immediately.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final _notifications = NotificationService();
  final _dhikr = DhikrNotificationScheduler();
  final _prayers = PrayerNotificationScheduler();

  bool _loading = true;
  bool _prayerOn = true;
  bool _morning = true;
  bool _evening = true;
  bool _periodic = true;
  int _interval = 2;
  int _hijriAdjust = 0;
  String _reciterLabel = '';
  String _cacheLabel = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await _notifications.loadNotificationPreferences();
    final prefs = await SharedPreferences.getInstance();
    _prayerOn = p['prayer_notifications'] ?? true;
    _morning = p['morning_azkar'] ?? true;
    _evening = p['evening_azkar'] ?? true;
    _periodic = p['dhikr_reminders'] ?? true;
    _interval = p['dhikr_interval'] ?? 2;
    _hijriAdjust = prefs.getInt('hijri_adjust') ?? 0;
    await _loadQuran();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadQuran() async {
    final audio = QuranAudioService();
    final r = await audio.selectedReciter();
    final size = await audio.cacheSize();
    _reciterLabel = '${tr(r.name)} • ${tr(r.style)}';
    _cacheLabel = size == 0
        ? tr('لا توجد تلاوات محفوظة')
        : '${AppLocale.digits((size / (1024 * 1024)).toStringAsFixed(1))} ${tr('ميجابايت • اضغط للحذف')}';
    if (mounted) setState(() {});
  }

  Future<void> _savePrefs() async {
    await _notifications.saveNotificationPreferences(
      prayerNotifications: _prayerOn,
      dhikrReminders: _periodic,
      qiblaReminders: false,
      dhikrInterval: _interval,
    );
  }

  void _toast(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------
  Future<void> _chooseLanguage() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppStyle.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (ctx, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(16),
          children: AppLocale.languages
              .map((l) => Card(
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    child: ListTile(
                      title: Text(l.nativeName,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      trailing: l.code == AppLocale.code.value
                          ? const Icon(Icons.check_circle_rounded,
                              color: AppStyle.primaryGreen)
                          : null,
                      onTap: () => Navigator.pop(ctx, l.code),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
    if (picked == null || picked == AppLocale.code.value) return;
    await AppLocale.set(picked);
    await GlobalLocationService().refreshCityName();
    _prayers.scheduleUpcoming();
    _dhikr.initializeAllDhikrReminders();
    await _loadQuran();
  }

  Future<void> _chooseReciter() async {
    final audio = QuranAudioService();
    final current = await audio.selectedReciter();
    if (!mounted) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppStyle.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (ctx, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(16),
          children: QuranAudioService.reciters
              .map((r) => Card(
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    child: ListTile(
                      leading: const Icon(Icons.mic_none_rounded,
                          color: AppStyle.primaryGreen),
                      title: Text(tr(r.name),
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(tr(r.style)),
                      trailing: r.id == current.id
                          ? const Icon(Icons.check_circle_rounded,
                              color: AppStyle.primaryGreen)
                          : null,
                      onTap: () => Navigator.pop(ctx, r.id),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
    if (picked == null) return;
    await audio.setReciter(picked);
    _loadQuran();
  }

  Future<void> _clearCache() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: AppLocale.direction,
        child: AlertDialog(
          title: Text(tr('حذف التلاوات المحفوظة؟')),
          content: Text(tr(
              'سيتم حذف كل التلاوات المحملة من جهازك، وستُحمَّل مرة أخرى عند الاستماع.')),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(tr('إلغاء'))),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(tr('حذف'),
                    style: const TextStyle(color: Colors.red))),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await QuranAudioService().clearCache();
    _loadQuran();
  }

  Future<void> _changeLocation() async {
    final changed = await showLocationPicker(context);
    if (changed == true && mounted) {
      context.read<AppCubit>().getPrayerTimeFromApi();
      setState(() {});
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLocale.direction,
      child: Scaffold(
        backgroundColor: AppStyle.background,
        appBar: AppBar(
          backgroundColor: AppStyle.primaryGreen,
          foregroundColor: Colors.white,
          centerTitle: true,
          title: Text(tr('الإعدادات'),
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppStyle.primaryGreen))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                children: [
                  _section(tr('عام'), [
                    _nav(Icons.translate_rounded, tr('لغة التطبيق'),
                        AppLocale.current.nativeName, _chooseLanguage),
                    _nav(
                        Icons.location_on_outlined,
                        tr('موقع مواقيت الصلاة'),
                        GlobalLocationService().cityName ??
                            tr('موقعك الحالي'),
                        _changeLocation),
                  ]),
                  _section(tr('الصلاة والأذان'), [
                    _switch(Icons.notifications_active_outlined,
                        tr('تذكير أوقات الصلاة'),
                        tr('إشعار عند دخول وقت كل صلاة'), _prayerOn, (v) async {
                      setState(() => _prayerOn = v);
                      await _savePrefs();
                      await _prayers.scheduleUpcoming();
                    }),
                    _nav(
                        Icons.campaign_outlined,
                        tr('إعدادات الأذان والمواقيت'),
                        tr('صوت الأذان، طريقة الحساب، التنبيه قبل الصلاة'),
                        () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AzanSettingsScreen()))),
                  ]),
                  _section(tr('الأذكار'), [
                    _switch(Icons.wb_twilight_rounded, tr('تذكير أذكار الصباح'),
                        tr('بعد صلاة الفجر بعشرين دقيقة'), _morning, (v) async {
                      setState(() => _morning = v);
                      await _dhikr.setMorningEveningEnabled(
                          morning: _morning, evening: _evening);
                    }),
                    _switch(Icons.nights_stay_outlined,
                        tr('تذكير أذكار المساء'),
                        tr('بعد صلاة العصر بربع ساعة'), _evening, (v) async {
                      setState(() => _evening = v);
                      await _dhikr.setMorningEveningEnabled(
                          morning: _morning, evening: _evening);
                    }),
                    _switch(Icons.repeat_rounded, tr('تذكيرات دورية'),
                        tr('تذكيرات متكررة للذكر والاستغفار'), _periodic,
                        (v) async {
                      setState(() => _periodic = v);
                      await _savePrefs();
                      await _dhikr.setDhikrRemindersEnabled(v);
                    }),
                    if (_periodic) _intervalRow(),
                  ]),
                  _section(tr('القرآن الكريم'), [
                    _nav(Icons.record_voice_over_outlined, tr('القارئ الافتراضي'),
                        _reciterLabel, _chooseReciter),
                    _nav(Icons.sd_storage_outlined,
                        tr('التلاوات المحفوظة على الجهاز'), _cacheLabel,
                        _clearCache),
                  ]),
                  _section(tr('التقويم الهجري'), [_hijriRow()]),
                  _section(tr('عن التطبيق'), [
                    _nav(Icons.star_rate_rounded, tr('قيّم التطبيق'),
                        tr('تقييمك يساعدنا على الوصول لعدد أكبر'),
                        () => AppStoreService().openRating()),
                    _nav(Icons.ios_share_rounded, tr('شارك التطبيق'),
                        tr('الدال على الخير كفاعله'), () {
                      Share.share(
                          '${tr('تطبيق أذكروه: القرآن الكريم والأذكار ومواقيت الصلاة')}\n'
                          '${Platform.isIOS ? 'https://apps.apple.com/app/id${AppStoreService.appStoreId}' : 'https://play.google.com/store/apps/details?id=com.islamsalemco.azkroh'}');
                    }),
                    _nav(Icons.notifications_outlined, tr('اختبار الإشعارات'),
                        tr('إشعار تجريبي'), () async {
                      HapticFeedback.lightImpact();
                      final ok = await _notifications.areNotificationsEnabled();
                      if (!ok) {
                        _toast(tr('الرجاء السماح بالإشعارات من إعدادات الجهاز'));
                        return;
                      }
                      await _notifications.showImmediateNotification(
                        id: 9990,
                        title: tr('أذكروه'),
                        body: tr('الإشعارات تعمل بشكل صحيح! الحمد لله'),
                      );
                      _toast(tr('تم إرسال إشعار تجريبي'));
                    }),
                  ]),
                ],
              ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(6, 20, 6, 8),
          child: Text(title,
              style: const TextStyle(
                  color: AppStyle.textLight,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5)),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppStyle.border),
          ),
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                if (i > 0)
                  const Divider(
                      height: 1, indent: 56, color: AppStyle.border),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _leading(IconData icon) => Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFFE7F2EE),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, size: 20, color: AppStyle.primaryGreen),
      );

  Widget _nav(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: _leading(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle.isEmpty
          ? null
          : Text(subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppStyle.textLight, fontSize: 12.5)),
      trailing: const Icon(Icons.chevron_right_rounded,
          color: AppStyle.textLight),
    );
  }

  Widget _switch(IconData icon, String title, String subtitle, bool value,
      ValueChanged<bool> onChanged) {
    return SwitchListTile.adaptive(
      secondary: _leading(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style: const TextStyle(color: AppStyle.textLight, fontSize: 12.5)),
      value: value,
      activeColor: AppStyle.primaryGreen,
      onChanged: (v) {
        HapticFeedback.selectionClick();
        onChanged(v);
      },
    );
  }

  Widget _intervalRow() {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 10),
      child: Row(
        children: [
          Text(tr('فترة التذكير'),
              style: const TextStyle(color: AppStyle.textLight)),
          Expanded(
            child: Slider(
              value: _interval.toDouble(),
              min: 1,
              max: 6,
              divisions: 5,
              activeColor: AppStyle.primaryGreen,
              onChanged: (v) => setState(() => _interval = v.round()),
              onChangeEnd: (v) async {
                await _savePrefs();
                await _dhikr.updateDhikrInterval(_interval);
              },
            ),
          ),
          Text('${AppLocale.digits(_interval)} ${tr('ساعة')}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _hijriRow() {
    final d =
        HijriCalendar.fromDate(DateTime.now().add(Duration(days: _hijriAdjust)));
    Future<void> set(int v) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('hijri_adjust', v);
      setState(() => _hijriAdjust = v);
    }

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('تعديل التاريخ الهجري حسب رؤية الهلال في بلدك'),
              style: const TextStyle(color: AppStyle.textLight, fontSize: 13)),
          const SizedBox(height: 6),
          Row(
            children: [
              IconButton(
                onPressed: _hijriAdjust <= -2 ? null : () => set(_hijriAdjust - 1),
                icon: const Icon(Icons.remove_circle_outline_rounded),
                color: AppStyle.primaryGreen,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                        '${AppLocale.digits(d.hDay)} ${d.longMonthName} ${AppLocale.digits(d.hYear)} ${tr('هـ')}',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    Text(
                        _hijriAdjust == 0
                            ? tr('بدون تعديل')
                            : '${_hijriAdjust > 0 ? '+' : ''}${AppLocale.digits(_hijriAdjust)} ${tr('يوم')}',
                        style: const TextStyle(
                            color: AppStyle.darkGold, fontSize: 12.5)),
                  ],
                ),
              ),
              IconButton(
                onPressed: _hijriAdjust >= 2 ? null : () => set(_hijriAdjust + 1),
                icon: const Icon(Icons.add_circle_outline_rounded),
                color: AppStyle.primaryGreen,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
