import 'package:azkroh_app/l10n/app_locale.dart';
// ignore_for_file: implementation_imports
import 'dart:async';
import 'dart:math' as math;

import 'package:azkroh_app/features/core/services/global_location_service.dart';
import 'package:azkroh_app/features/presentation/screens/homescreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qcf_quran_plus/qcf_quran_plus.dart' as qcf;
import 'package:qcf_quran_plus/src/widgets/quran_page/quran_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Splash screen. Does the real start-up work (location, Mushaf data and the
/// fonts of the last read page) so the Quran opens instantly afterwards.
class ProfessionalSplashScreen extends StatefulWidget {
  const ProfessionalSplashScreen({super.key});

  @override
  State<ProfessionalSplashScreen> createState() =>
      _ProfessionalSplashScreenState();
}

class _ProfessionalSplashScreenState extends State<ProfessionalSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final AnimationController _spin;

  static const _emerald = Color(0xFF0B3D33);
  static const _emerald2 = Color(0xFF0F5C4A);
  static const _gold = Color(0xFFD4AF37);

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _intro = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..forward();
    _spin =
        AnimationController(vsync: this, duration: const Duration(seconds: 40))
          ..repeat();
    _start();
  }

  Future<void> _start() async {
    final minDelay = Future.delayed(const Duration(milliseconds: 2600));
    Future<void> guard(Future<void> f) => f
        .timeout(const Duration(seconds: 6), onTimeout: () {})
        .catchError((_) {});

    final prefs = await SharedPreferences.getInstance();
    final lastPage = (prefs.getInt('mushaf_last_page') ?? 1).clamp(1, 604);

    await Future.wait([
      minDelay,
      guard(GlobalLocationService().initialize()),
      guard(QuranRepository.instance.ensureLoaded(qcf.totalPagesCount)),
      guard(qcf.QcfFontLoader.ensureFontLoaded(lastPage)),
    ]);
    // Warm the neighbouring pages in the background.
    qcf.QcfFontLoader.preloadPages(lastPage, radius: 2);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (_, __, ___) => const HomePageScreen(),
      transitionsBuilder: (_, a, __, child) =>
          FadeTransition(opacity: a, child: child),
    ));
  }

  @override
  void dispose() {
    _intro.dispose();
    _spin.dispose();
    super.dispose();
  }

  Animation<double> _interval(double a, double b) => CurvedAnimation(
      parent: _intro, curve: Interval(a, b, curve: Curves.easeOutCubic));

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final emblemFade = _interval(0.0, 0.55);
    final titleFade = _interval(0.3, 0.8);
    final ayahFade = _interval(0.4, 0.85);

    return Scaffold(
      backgroundColor: _emerald,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.25),
            radius: 1.1,
            colors: [_emerald2, _emerald],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Center(
                child: AnimatedBuilder(
                  animation: _spin,
                  builder: (_, child) => Transform.rotate(
                    angle: _spin.value * 2 * math.pi,
                    child: child,
                  ),
                  child: Opacity(
                    opacity: 0.07,
                    child: CustomPaint(
                      size: Size.square(size.width * 1.4),
                      painter: const IslamicStarPainter(
                          color: Colors.white, stroke: true),
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Directionality(
                textDirection: AppLocale.direction,
                child: Column(
                  children: [
                    const Spacer(flex: 3),
                    FadeTransition(
                      opacity: emblemFade,
                      child: ScaleTransition(
                        scale:
                            Tween(begin: 0.85, end: 1.0).animate(emblemFade),
                        child: const AppEmblem(size: 132),
                      ),
                    ),
                    const SizedBox(height: 28),
                    FadeTransition(
                      opacity: titleFade,
                      child: SlideTransition(
                        position: Tween(
                                begin: const Offset(0, 0.25), end: Offset.zero)
                            .animate(titleFade),
                        child: Column(
                          children: [
                            Text(
                              tr('أذكروه'),
                              style: TextStyle(
                                fontFamily: 'AppSans',
                                fontWeight: FontWeight.w700,
                                fontSize: 44,
                                color: Colors.white,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              tr('القرآن • الأذكار • الصلاة'),
                              style: TextStyle(
                                fontFamily: 'AppSans',
                                fontSize: 15,
                                color: Colors.white.withOpacity(0.65),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(flex: 2),
                    FadeTransition(opacity: ayahFade, child: _ayah()),
                    const Spacer(flex: 2),
                    SizedBox(
                      width: 120,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          minHeight: 3,
                          backgroundColor: Colors.white.withOpacity(0.12),
                          valueColor: const AlwaysStoppedAnimation(_gold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _bracketStyle = TextStyle(
    fontFamily: 'Amiri-Quran',
    fontSize: 34,
    color: _gold,
    height: 1.4,
  );

  Widget _ayah() {
    // Uthmani (Hafs) text of Al-Baqarah 2:152 from the Mushaf data.
    String text =
        'فَٱذۡكُرُونِيٓ أَذۡكُرۡكُمۡ وَٱشۡكُرُواْ لِي وَلَا تَكۡفُرُونِ';
    try {
      text = qcf
          .getVerse(2, 152)
          .replaceAll(RegExp(r'[\s٠-٩۰-۹0-9]+$'), '')
          .replaceAll(RegExp(r'\s*\n\s*'), ' ')
          .trim();
    } catch (_) {}
    // «فَٱذۡكُرُونِيٓ أَذۡكُرۡكُمۡ» — first two words, on a single line.
    text = text.split(RegExp(r'\s+')).take(2).join(' ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _gold.withOpacity(0.35)),
            ),
            // Brackets laid out explicitly (left/right) so bidi mirroring of
            // the ornate parentheses can't flip them.
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Transform.translate(
                      offset: const Offset(0, -10),
                      child: Text('\uFD3E', style: _bracketStyle)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      text,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: qcf.QuranTextStyles.hafsStyle(
                        color: Colors.white,
                        fontSize: 34,
                        height: 1.7,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Transform.translate(
                      offset: const Offset(0, -10),
                      child: Text('\uFD3F', style: _bracketStyle)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            tr('سورة البقرة • الآية ١٥٢'),
            style: TextStyle(
              fontFamily: 'AppSans',
              fontSize: 13,
              color: _gold.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }
}

/// App emblem: gold eight-pointed star with an open book.
class AppEmblem extends StatelessWidget {
  final double size;
  final Color background;

  const AppEmblem(
      {super.key, this.size = 96, this.background = const Color(0xFF0B3D33)});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: const IslamicStarPainter(color: Color(0xFFD4AF37)),
          ),
          Container(
            width: size * 0.64,
            height: size * 0.64,
            decoration: BoxDecoration(color: background, shape: BoxShape.circle),
          ),
          Icon(Icons.menu_book_rounded,
              color: const Color(0xFFD4AF37), size: size * 0.3),
        ],
      ),
    );
  }
}

/// Eight-pointed Islamic star (two overlapping squares).
class IslamicStarPainter extends CustomPainter {
  final Color color;
  final bool stroke;

  const IslamicStarPainter({required this.color, this.stroke = false});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final paint = Paint()
      ..color = color
      ..style = stroke ? PaintingStyle.stroke : PaintingStyle.fill
      ..strokeWidth = stroke ? 2 : 0
      ..isAntiAlias = true;

    Path square(double rot, double radius) {
      final p = Path();
      for (int i = 0; i < 4; i++) {
        final a = rot + i * math.pi / 2;
        final pt = c + Offset(math.cos(a), math.sin(a)) * radius;
        i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
      }
      return p..close();
    }

    canvas.drawPath(
        Path.combine(
            PathOperation.union, square(0, r), square(math.pi / 4, r)),
        paint);
    if (stroke) {
      canvas.drawCircle(c, r * 0.72, paint);
      canvas.drawPath(
          Path.combine(PathOperation.union, square(math.pi / 8, r * 0.72),
              square(math.pi / 8 + math.pi / 4, r * 0.72)),
          paint);
      canvas.drawCircle(c, r * 0.4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant IslamicStarPainter old) =>
      old.color != color || old.stroke != stroke;
}
