import 'dart:async';

import 'package:azkroh_app/features/core/appstyle.dart';
import 'package:azkroh_app/features/core/notification_service.dart';
import 'package:azkroh_app/features/core/prayer_notification_scheduler.dart';
import 'package:azkroh_app/features/core/services/azan_audio_service.dart';
import 'package:azkroh_app/features/core/services/prayer_times_service.dart';
import 'package:azkroh_app/features/presentation/cubit/cubit.dart';
import 'package:azkroh_app/l10n/app_locale.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';

/// Adhan settings: voice, per-prayer toggles, reminders, calculation, tests.
class AzanSettingsScreen extends StatefulWidget {
  const AzanSettingsScreen({super.key});

  @override
  State<AzanSettingsScreen> createState() => _AzanSettingsScreenState();
}

class _AzanSettingsScreenState extends State<AzanSettingsScreen> {
  final _azan = AzanAudioService();
  final _times = PrayerTimesService();
  final _scheduler = PrayerNotificationScheduler();

  bool _loading = true;
  bool _enabled = true;
  String _reciter = 'mishary';
  double _volume = 1;
  String _method = 'auto';
  String _madhab = 'auto';
  int _preReminder = 0;
  final Map<String, bool> _perPrayer = {};
  final Map<String, int> _adjust = {};

  /// Which preview is playing: "<reciter>|fajr" or "<reciter>|regular".
  String? _previewing;
  StreamSubscription<PlayerState>? _sub;

  static const _prayers = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
  static const _icons = {
    'fajr': Icons.nights_stay_outlined,
    'dhuhr': Icons.wb_sunny_outlined,
    'asr': Icons.sunny_snowing,
    'maghrib': Icons.brightness_4_outlined,
    'isha': Icons.dark_mode_outlined,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _azan.stopAzan();
    super.dispose();
  }

  Future<void> _load() async {
    await _azan.initialize();
    _enabled = await _azan.isAzanEnabled();
    _reciter = await _azan.getSelectedReciter();
    _volume = await _azan.getAzanVolume();
    _method = await _times.getMethodKey();
    _madhab = await _times.getMadhab();
    _preReminder = await _scheduler.getPreReminderMinutes();
    for (final k in _prayers) {
      final name = PrayerTimesService.arabicNames[k]!;
      _perPrayer[k] = await _azan.isAzanEnabledForPrayer(name);
      _adjust[k] = await _times.getAdjustment(k);
    }
    _sub = _azan.playerStateStream?.listen((s) {
      if (!mounted) return;
      if (s.processingState == ProcessingState.completed || !s.playing) {
        if (_previewing != null && !s.playing) {
          setState(() => _previewing = null);
        }
      }
    });
    if (mounted) setState(() => _loading = false);
  }

  void _toast(String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  void _reschedule() => _scheduler.scheduleUpcoming();

  void _applyTiming() {
    try {
      context.read<AppCubit>().getPrayerTimeFromApi();
    } catch (_) {
      _reschedule();
    }
  }

  Future<void> _preview(String reciter, bool fajr) async {
    HapticFeedback.selectionClick();
    final key = '$reciter|${fajr ? 'fajr' : 'regular'}';
    if (_previewing == key) {
      await _azan.stopAzan();
      setState(() => _previewing = null);
      return;
    }
    setState(() => _previewing = key);
    await _azan.playAzan(
        prayerName: fajr ? 'الفجر' : 'الظهر',
        isFajr: fajr,
        force: true,
        reciter: reciter);
  }

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
          title: Text(tr('إعدادات الأذان'),
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppStyle.primaryGreen))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                children: [
                  _masterCard(),
                  if (_enabled) ...[
                    _title(tr('صوت المؤذن'), Icons.record_voice_over_outlined),
                    ...AzanAudioService.azanReciters.entries.map(_voiceCard),
                    _title(tr('تخصيص الأذان لكل صلاة'), Icons.tune_rounded),
                    _card(Column(children: _prayers.map(_prayerToggle).toList())),
                    _title(tr('مستوى الصوت'), Icons.volume_up_outlined),
                    _card(_volumeSlider()),
                  ],
                  _title(tr('تنبيه قبل الأذان'), Icons.alarm_rounded),
                  _card(_chips<int>(
                    {
                      0: tr('إيقاف'),
                      5: tr('5 د'),
                      10: tr('10 د'),
                      15: tr('15 د'),
                      30: tr('30 د'),
                    },
                    _preReminder,
                    (v) async {
                      setState(() => _preReminder = v);
                      await _scheduler.setPreReminderMinutes(v);
                    },
                  )),
                  _title(tr('طريقة حساب المواقيت'), Icons.calculate_outlined),
                  _card(_calculation()),
                  _title(tr('ضبط يدوي للمواقيت (بالدقائق)'),
                      Icons.more_time_rounded),
                  _card(Column(children: _prayers.map(_adjustRow).toList())),
                  _title(tr('اختبار الأذان'), Icons.science_outlined),
                  _card(_tests()),
                ],
              ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  Widget _title(String t, IconData icon) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(4, 22, 4, 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppStyle.goldColor),
            const SizedBox(width: 8),
            Text(t,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppStyle.textDark)),
          ],
        ),
      );

  Widget _card(Widget child) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppStyle.border),
        ),
        child: child,
      );

  Widget _masterCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [Color(0xFF0F5C4A), Color(0xFF0B3D33)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _enabled
                  ? AppStyle.goldColor
                  : Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.campaign_rounded,
                color: _enabled ? const Color(0xFF0B3D33) : Colors.white,
                size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('تشغيل الأذان'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                    _enabled
                        ? tr('سيتم تشغيل الأذان عند دخول وقت الصلاة')
                        : tr('الأذان معطل'),
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.75), fontSize: 12.5)),
              ],
            ),
          ),
          Switch.adaptive(
            value: _enabled,
            activeColor: AppStyle.goldColor,
            onChanged: (v) async {
              HapticFeedback.selectionClick();
              await _azan.setAzanEnabled(v);
              setState(() => _enabled = v);
              _reschedule();
            },
          ),
        ],
      ),
    );
  }

  Widget _voiceCard(MapEntry<String, Map<String, String>> e) {
    final selected = _reciter == e.key;
    Widget previewBtn(bool fajr) {
      final playing = _previewing == '${e.key}|${fajr ? 'fajr' : 'regular'}';
      return Expanded(
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor:
                playing ? Colors.white : AppStyle.primaryGreen,
            backgroundColor:
                playing ? AppStyle.primaryGreen : Colors.transparent,
            side: const BorderSide(color: AppStyle.primaryGreen),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
          onPressed: () => _preview(e.key, fajr),
          icon: Icon(playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
              size: 18),
          label: Text(fajr ? tr('أذان الفجر') : tr('الأذان العادي'),
              style: const TextStyle(fontSize: 12.5)),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            HapticFeedback.selectionClick();
            await _azan.setSelectedReciter(e.key);
            setState(() => _reciter = e.key);
            _reschedule();
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: selected ? AppStyle.primaryGreen : AppStyle.border,
                  width: selected ? 2 : 1),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                        selected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        color: selected
                            ? AppStyle.primaryGreen
                            : AppStyle.textLight),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr(e.value['name']!),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15)),
                          Text(tr(e.value['desc'] ?? ''),
                              style: const TextStyle(
                                  color: AppStyle.textLight, fontSize: 12.5)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    previewBtn(true),
                    const SizedBox(width: 8),
                    previewBtn(false),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _prayerToggle(String k) {
    final name = PrayerTimesService.arabicNames[k]!;
    final on = _perPrayer[k] ?? true;
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      secondary: Icon(_icons[k],
          color: on ? AppStyle.primaryGreen : AppStyle.textLight),
      title: Text(tr(name),
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(on ? tr('الأذان') : tr('الأذان مكتوم'),
          style: const TextStyle(fontSize: 12, color: AppStyle.textLight)),
      value: on,
      activeColor: AppStyle.primaryGreen,
      onChanged: (v) async {
        await _azan.setAzanEnabledForPrayer(name, v);
        setState(() => _perPrayer[k] = v);
        _reschedule();
      },
    );
  }

  Widget _volumeSlider() {
    return Row(
      children: [
        const Icon(Icons.volume_mute_rounded, color: AppStyle.textLight),
        Expanded(
          child: Slider(
            value: _volume,
            activeColor: AppStyle.primaryGreen,
            onChanged: (v) {
              setState(() => _volume = v);
              _azan.setAzanVolume(v);
            },
          ),
        ),
        Text(AppLocale.digits('${(_volume * 100).round()}%'),
            style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }

  /// Readable choice chips (selected = emerald, others = light grey).
  Widget _chips<T>(Map<T, String> options, T value, ValueChanged<T> onPick) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.entries.map((e) {
        final sel = e.key == value;
        return ChoiceChip(
          label: Text(e.value),
          selected: sel,
          showCheckmark: false,
          selectedColor: AppStyle.primaryGreen,
          backgroundColor: const Color(0xFFF1EEE5),
          side: BorderSide(
              color: sel ? AppStyle.primaryGreen : AppStyle.border),
          labelStyle: TextStyle(
            color: sel ? Colors.white : AppStyle.textDark,
            fontWeight: FontWeight.w600,
          ),
          onSelected: (_) {
            HapticFeedback.selectionClick();
            onPick(e.key);
          },
        );
      }).toList(),
    );
  }

  Widget _calculation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          value: _method,
          isExpanded: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF6F4EE),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          items: PrayerTimesService.methodLabels.entries
              .map((e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(tr(e.value), overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: (v) async {
            if (v == null) return;
            setState(() => _method = v);
            await _times.setMethodKey(v);
            _applyTiming();
          },
        ),
        const SizedBox(height: 14),
        Text(tr('حساب العصر'),
            style: const TextStyle(color: AppStyle.textLight, fontSize: 13)),
        const SizedBox(height: 8),
        _chips<String>(
          {'auto': tr('تلقائي'), 'shafi': tr('الجمهور'), 'hanafi': tr('الحنفي')},
          _madhab,
          (v) async {
            setState(() => _madhab = v);
            await _times.setMadhab(v);
            _applyTiming();
          },
        ),
      ],
    );
  }

  Widget _adjustRow(String k) {
    final v = _adjust[k] ?? 0;
    Future<void> change(int nv) async {
      final c = nv.clamp(-30, 30);
      setState(() => _adjust[k] = c);
      await _times.setAdjustment(k, c);
      _applyTiming();
    }

    return Row(
      children: [
        Icon(_icons[k], size: 20, color: AppStyle.primaryGreen),
        const SizedBox(width: 10),
        Expanded(
          child: Text(tr(PrayerTimesService.arabicNames[k]!),
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline_rounded),
          color: AppStyle.textLight,
          onPressed: () => change(v - 1),
        ),
        SizedBox(
          width: 40,
          child: Text(
            AppLocale.digits(v > 0 ? '+$v' : '$v'),
            textAlign: TextAlign.center,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: v == 0 ? AppStyle.textDark : AppStyle.darkGold),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline_rounded),
          color: AppStyle.textLight,
          onPressed: () => change(v + 1),
        ),
      ],
    );
  }

  Widget _tests() {
    Widget btn(IconData icon, String label, VoidCallback onTap,
            {bool primary = false}) =>
        SizedBox(
          width: double.infinity,
          child: primary
              ? FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppStyle.primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: onTap,
                  icon: Icon(icon),
                  label: Text(label),
                )
              : OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppStyle.primaryGreen,
                    side: const BorderSide(color: AppStyle.primaryGreen),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: onTap,
                  icon: Icon(icon),
                  label: Text(label),
                ),
        );

    return Column(
      children: [
        btn(Icons.schedule_send_rounded, tr('أذان تجريبي بعد دقيقة'), () async {
          await NotificationService().schedulePrayerNotification(
            id: 9997,
            prayerName: 'الظهر',
            scheduledTime: DateTime.now().add(const Duration(minutes: 1)),
            title: tr('اختبار الأذان'),
            customMessage: tr('هذا أذان تجريبي في موعده كما سيحدث وقت الصلاة'),
          );
          _toast(tr('سيُرفع أذان تجريبي بعد دقيقة، يمكنك قفل الشاشة'));
        }, primary: true),
        const SizedBox(height: 8),
        btn(Icons.notifications_active_outlined, tr('تجربة إشعار الأذان'),
            () async {
          await _azan.stopAzan();
          await NotificationService().showTestAzanNotification();
          _toast(tr('تم إرسال إشعار أذان تجريبي'));
        }),
        const SizedBox(height: 8),
        btn(Icons.stop_circle_outlined, tr('إيقاف'), () async {
          await _azan.stopAzan();
          setState(() => _previewing = null);
        }),
      ],
    );
  }
}
