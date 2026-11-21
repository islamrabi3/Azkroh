import 'package:azkroh_app/features/core/services/media_handler.dart';
import 'package:azkroh_app/features/core/widgets/now_playing_bubble.dart';
import 'dart:io';

import 'package:azkroh_app/features/core/appstyle.dart';
import 'package:azkroh_app/features/core/notification_service.dart';
import 'package:azkroh_app/features/presentation/screens/professional_splash_screen.dart'
    show AppEmblem;
import 'package:azkroh_app/l10n/app_locale.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Full-screen adhan page: opened by the adhan notification (on Android it
/// wakes the locked screen). Lets the user stop / mute the adhan.
class AdhanScreen extends StatefulWidget {
  /// Arabic prayer name (الفجر، الظهر ...) or empty for a generic title.
  final String prayerName;

  const AdhanScreen({super.key, required this.prayerName});

  @override
  State<AdhanScreen> createState() => _AdhanScreenState();
}

class _AdhanScreenState extends State<AdhanScreen>
    with SingleTickerProviderStateMixin, SuppressNowPlayingBubble {
  static const _channel = MethodChannel('azkroh/adhan_screen');
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2200))
    ..repeat();
  bool _muted = false;

  static const _known = ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'];

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    // Pause the radio / recitation for the adhan.
    if (MediaHandler.instance.player.playing) MediaHandler.instance.pause();
  }

  @override
  void dispose() {
    _pulse.dispose();
    if (Platform.isAndroid) {
      _channel.invokeMethod('release').catchError((_) {});
    }
    super.dispose();
  }

  Future<void> _mute() async {
    HapticFeedback.selectionClick();
    await NotificationService().stopAzan();
    if (mounted) setState(() => _muted = true);
  }

  Future<void> _close() async {
    await NotificationService().stopAzan();
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final known = _known.contains(widget.prayerName);
    final title = known
        ? '${tr('حان الآن وقت صلاة')} ${tr(widget.prayerName)}'
        : tr('حان الآن وقت الصلاة');
    final now = TimeOfDay.now();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Directionality(
        textDirection: AppLocale.direction,
        child: Scaffold(
          body: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF13705A), Color(0xFF0B3D33), Color(0xFF06261F)],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    // Logo with pulsing rings while the adhan plays.
                    SizedBox.square(
                      dimension: 230,
                      child: AnimatedBuilder(
                        animation: _pulse,
                        builder: (_, child) => CustomPaint(
                          painter: _RingsPainter(_muted ? 0 : _pulse.value),
                          child: child,
                        ),
                        child: const Center(child: AppEmblem(size: 140)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                        AppLocale.digits(
                            '${now.hourOfPeriod == 0 ? 12 : now.hourOfPeriod}:${now.minute.toString().padLeft(2, '0')}'),
                        style: const TextStyle(
                            color: AppStyle.goldColor,
                            fontSize: 44,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            height: 1.4,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: AppStyle.goldColor.withOpacity(0.35)),
                      ),
                      child: Text(
                        'اللَّهُمَّ رَبَّ هَذِهِ الدَّعْوَةِ التَّامَّةِ، وَالصَّلَاةِ الْقَائِمَةِ، آتِ مُحَمَّدًا الْوَسِيلَةَ وَالْفَضِيلَةَ، وَابْعَثْهُ مَقَامًا مَحْمُودًا الَّذِي وَعَدْتَهُ',
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                            fontFamily: 'Amiri',
                            color: Colors.white.withOpacity(0.92),
                            fontSize: 17,
                            height: 1.9),
                      ),
                    ),
                    const Spacer(flex: 3),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white38),
                              minimumSize: const Size.fromHeight(54),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18)),
                            ),
                            onPressed: _muted ? null : _mute,
                            icon: Icon(_muted
                                ? Icons.volume_off_rounded
                                : Icons.volume_mute_rounded),
                            label: Text(
                                _muted ? tr('تم كتم الأذان') : tr('كتم الصوت'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppStyle.goldColor,
                              foregroundColor: const Color(0xFF0B3D33),
                              minimumSize: const Size.fromHeight(54),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18)),
                            ),
                            onPressed: _close,
                            icon: const Icon(Icons.close_rounded),
                            label: Text(tr('إيقاف وإغلاق'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  final double t;

  _RingsPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    if (t == 0) return;
    final c = size.center(Offset.zero);
    for (int i = 0; i < 3; i++) {
      final p = (t + i / 3) % 1.0;
      final r = 72 + p * (size.width / 2 - 72);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = AppStyle.goldColor.withOpacity((1 - p) * 0.6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingsPainter old) => old.t != t;
}
