import 'dart:async';
import 'dart:math';
import 'package:azkroh_app/features/core/services/global_location_service.dart';
import 'package:azkroh_app/features/presentation/screens/homescreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ProfessionalSplashScreen extends StatefulWidget {
  const ProfessionalSplashScreen({super.key});

  @override
  State<ProfessionalSplashScreen> createState() =>
      _ProfessionalSplashScreenState();
}

class _ProfessionalSplashScreenState extends State<ProfessionalSplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _pulseController;
  late AnimationController _particleController;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;
  late Animation<double> _progressOpacity;
  late Animation<double> _pulseAnimation;

  String _loadingText = 'جاري التحميل...';
  double _loadingProgress = 0.0;

  final List<_Particle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _initializeAnimations();
    _generateParticles();
    _startLoading();
  }

  void _initializeAnimations() {
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
      ),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.4, 0.7, curve: Curves.easeIn),
      ),
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.4, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _progressOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.6, 0.8, curve: Curves.easeIn),
      ),
    );

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    _mainController.forward();
  }

  void _generateParticles() {
    for (int i = 0; i < 30; i++) {
      _particles.add(_Particle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: _random.nextDouble() * 4 + 2,
        speed: _random.nextDouble() * 0.3 + 0.1,
        opacity: _random.nextDouble() * 0.5 + 0.2,
      ));
    }
  }

  Future<void> _startLoading() async {
    await _loadStep('تهيئة التطبيق...', 0.2);
    await _loadStep('جاري تحديد الموقع...', 0.4);

    try {
      await GlobalLocationService().initialize();
    } catch (e) {
      debugPrint('Location initialization error: $e');
    }

    await _loadStep('تحميل البيانات...', 0.6);
    await _loadStep('جاري التحضير...', 0.8);
    await _loadStep('تم!', 1.0);

    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const HomePageScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  Future<void> _loadStep(String text, double progress) async {
    setState(() {
      _loadingText = text;
    });

    final startProgress = _loadingProgress;
    const steps = 20;
    final increment = (progress - startProgress) / steps;

    for (int i = 0; i < steps; i++) {
      await Future.delayed(const Duration(milliseconds: 30));
      if (mounted) {
        setState(() {
          _loadingProgress = startProgress + (increment * (i + 1));
        });
      }
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    _pulseController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1B5E20),
              Color(0xFF2E7D32),
              Color(0xFF1B5E20),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            AnimatedBuilder(
              animation: _particleController,
              builder: (context, child) {
                return CustomPaint(
                  size: size,
                  painter: _ParticlePainter(
                    particles: _particles,
                    progress: _particleController.value,
                  ),
                );
              },
            ),
            Positioned(
              top: -100.h,
              right: -100.w,
              child: _buildDecorativeCircle(250.r, 0.05),
            ),
            Positioned(
              bottom: -150.h,
              left: -150.w,
              child: _buildDecorativeCircle(350.r, 0.03),
            ),
            Positioned(
              top: size.height * 0.3,
              left: -80.w,
              child: _buildDecorativeCircle(180.r, 0.04),
            ),
            SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 2),
                    AnimatedBuilder(
                      animation:
                          Listenable.merge([_mainController, _pulseController]),
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _logoScale.value * _pulseAnimation.value,
                          child: Opacity(
                            opacity: _logoOpacity.value,
                            child: _buildLogo(),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 40.h),
                    AnimatedBuilder(
                      animation: _mainController,
                      builder: (context, child) {
                        return SlideTransition(
                          position: _textSlide,
                          child: Opacity(
                            opacity: _textOpacity.value,
                            child: _buildAppName(),
                          ),
                        );
                      },
                    ),
                    const Spacer(),
                    AnimatedBuilder(
                      animation: _mainController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _progressOpacity.value,
                          child: _buildLoadingSection(),
                        );
                      },
                    ),
                    SizedBox(height: 60.h),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDecorativeCircle(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(opacity),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 160.r,
      height: 160.r,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFD700),
            Color(0xFFB8860B),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withOpacity(0.4),
            blurRadius: 30.r,
            spreadRadius: 5.r,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20.r,
            offset: Offset(0, 10.h),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 140.r,
            height: 140.r,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 2.w,
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CustomPaint(
                size: Size(60.r, 60.r),
                painter: _IslamicStarPainter(),
              ),
              SizedBox(height: 8.h),
              Text(
                'أذكروه',
                style: TextStyle(
                  color: const Color(0xFF1B5E20),
                  fontSize: 22.sp,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Amiri',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppName() {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Colors.white, Color(0xFFE0E0E0)],
          ).createShader(bounds),
          child: Text(
            'أذكروه',
            style: TextStyle(
              fontSize: 48.sp,
              fontWeight: FontWeight.bold,
              fontFamily: 'Amiri',
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Colors.black26,
                  blurRadius: 10.r,
                  offset: Offset(2.w, 2.h),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 12.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
            ),
          ),
          child: Text(
            'تطبيق الأذكار والقرآن الكريم',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16.sp,
              fontFamily: 'Amiri',
            ),
          ),
        ),
        SizedBox(height: 20.h),
        Text(
          '﴿ فَاذْكُرُونِي أَذْكُرْكُمْ ﴾',
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 20.sp,
            fontFamily: 'Amiri-Quran',
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingSection() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 50.w),
      child: Column(
        children: [
          Text(
            _loadingText,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14.sp,
              fontFamily: 'Amiri',
            ),
          ),
          SizedBox(height: 16.h),
          Container(
            height: 6.h,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(3.r),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3.r),
              child: LinearProgressIndicator(
                value: _loadingProgress,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(
                  const Color(0xFFFFD700).withOpacity(0.8),
                ),
              ),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            '${(_loadingProgress * 100).toInt()}%',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12.sp,
            ),
          ),
        ],
      ),
    );
  }
}

class _Particle {
  double x;
  double y;
  final double size;
  final double speed;
  final double opacity;

  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ParticlePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      particle.y = (particle.y - particle.speed * 0.01) % 1.0;
      if (particle.y < 0) particle.y = 1.0;

      final paint = Paint()
        ..color = Colors.white.withOpacity(particle.opacity * 0.5)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(particle.x * size.width, particle.y * size.height),
        particle.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}

class _IslamicStarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = const Color(0xFF1B5E20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final radius = size.width / 2;
    final innerRadius = radius * 0.4;
    final path = Path();

    for (int i = 0; i < 8; i++) {
      final outerAngle = (i * 45 - 90) * pi / 180;
      final innerAngle = ((i * 45) + 22.5 - 90) * pi / 180;

      final outerX = center.dx + radius * cos(outerAngle);
      final outerY = center.dy + radius * sin(outerAngle);
      final innerX = center.dx + innerRadius * cos(innerAngle);
      final innerY = center.dy + innerRadius * sin(innerAngle);

      if (i == 0) {
        path.moveTo(outerX, outerY);
      } else {
        path.lineTo(outerX, outerY);
      }
      path.lineTo(innerX, innerY);
    }
    path.close();

    canvas.drawPath(path, paint);
    canvas.drawCircle(center, innerRadius * 0.7, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
