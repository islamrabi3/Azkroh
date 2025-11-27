import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_qiblah/flutter_qiblah.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';

class QibalScreen extends StatefulWidget {
  const QibalScreen({super.key});

  @override
  State<QibalScreen> createState() => _QibalScreenState();
}

class _QibalScreenState extends State<QibalScreen>
    with TickerProviderStateMixin {
  final _locationStreamController =
      StreamController<LocationStatus>.broadcast();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isAligned = false;

  Stream<LocationStatus> get _stream => _locationStreamController.stream;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _checkLocationStatus();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _checkLocationStatus() async {
    final locationStatus = await FlutterQiblah.checkLocationStatus();
    if (locationStatus.enabled &&
        locationStatus.status == LocationPermission.denied) {
      await FlutterQiblah.requestPermissions();
      final s = await FlutterQiblah.checkLocationStatus();
      _locationStreamController.add(s);
    } else {
      _locationStreamController.add(locationStatus);
    }
  }

  @override
  void dispose() {
    _locationStreamController.close();
    _pulseController.dispose();
    FlutterQiblah().dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
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
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: StreamBuilder<LocationStatus>(
                    stream: _stream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return _buildLoadingState();
                      }

                      if (!snapshot.hasData) {
                        return _buildLoadingState();
                      }

                      if (snapshot.data!.enabled == true) {
                        switch (snapshot.data!.status) {
                          case LocationPermission.always:
                          case LocationPermission.whileInUse:
                            return _buildCompassContent();
                          case LocationPermission.denied:
                            return _buildErrorState(
                              'الرجاء السماح بالوصول للموقع',
                              Icons.location_off_rounded,
                            );
                          case LocationPermission.deniedForever:
                            return _buildErrorState(
                              'تم رفض إذن الموقع نهائياً\nالرجاء تفعيله من الإعدادات',
                              Icons.location_disabled_rounded,
                            );
                          default:
                            return _buildLoadingState();
                        }
                      } else {
                        return _buildErrorState(
                          'الرجاء تفعيل خدمة الموقع',
                          Icons.location_off_rounded,
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Container(
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 20.sp,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'اتجاه القبلة',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22.sp,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(width: 48.w),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60.r,
            height: 60.r,
            child: const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 3,
            ),
          ),
          SizedBox(height: 20.h),
          Text(
            'جاري تحديد الاتجاه...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message, IconData icon) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.r),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24.r),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Colors.orange,
                size: 60.sp,
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              message,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _checkLocationStatus();
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 14.h),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFB8860B)],
                  ),
                  borderRadius: BorderRadius.circular(30.r),
                ),
                child: Text(
                  'إعادة المحاولة',
                  style: TextStyle(
                    color: const Color(0xFF1B5E20),
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompassContent() {
    return StreamBuilder<QiblahDirection>(
      stream: FlutterQiblah.qiblahStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (!snapshot.hasData) {
          return _buildLoadingState();
        }

        final qiblahDirection = snapshot.data!;
        final offset = qiblahDirection.offset;

        // Check if aligned (within 5 degrees)
        final newIsAligned = offset.abs() < 5;
        if (newIsAligned != _isAligned) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _isAligned = newIsAligned);
              if (newIsAligned) {
                HapticFeedback.mediumImpact();
              }
            }
          });
        }

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              children: [
                SizedBox(height: 20.h),
                _buildInfoCard(),
                SizedBox(height: 30.h),
                _buildCompass(qiblahDirection),
                SizedBox(height: 30.h),
                _buildDirectionInfo(qiblahDirection),
                SizedBox(height: 20.h),
                _buildInstructions(),
                SizedBox(height: 30.h),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFB8860B)],
              ),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              Icons.mosque_rounded,
              color: const Color(0xFF1B5E20),
              size: 24.sp,
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الكعبة المشرفة',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'مكة المكرمة، المملكة العربية السعودية',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompass(QiblahDirection direction) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer glow when aligned
        if (_isAligned)
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 300.r * _pulseAnimation.value,
                height: 300.r * _pulseAnimation.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withOpacity(0.4),
                      blurRadius: 40.r,
                      spreadRadius: 10.r,
                    ),
                  ],
                ),
              );
            },
          ),
        // Compass background
        Container(
          width: 280.r,
          height: 280.r,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.1),
            border: Border.all(
              color: _isAligned
                  ? const Color(0xFFFFD700)
                  : Colors.white.withOpacity(0.3),
              width: 3.w,
            ),
          ),
        ),
        // Compass ring with degrees
        Transform.rotate(
          angle: (direction.direction * (math.pi / 180) * -1),
          child: CustomPaint(
            size: Size(260.r, 260.r),
            painter: CompassPainter(),
          ),
        ),
        // Direction indicator (Qibla needle)
        Transform.rotate(
          angle: (direction.qiblah * (math.pi / 180) * -1),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 4.w,
                height: 100.h,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFFFFD700),
                      const Color(0xFFB8860B).withOpacity(0.5),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              Container(
                width: 20.r,
                height: 20.r,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFB8860B)],
                  ),
                ),
              ),
              Container(
                width: 4.w,
                height: 100.h,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ],
          ),
        ),
        // Kaaba icon in center
        Container(
          width: 60.r,
          height: 60.r,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: _isAligned
                ? const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFB8860B)],
                  )
                : LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.2),
                      Colors.white.withOpacity(0.1),
                    ],
                  ),
          ),
          child: Icon(
            Icons.mosque_rounded,
            color: _isAligned ? const Color(0xFF1B5E20) : Colors.white,
            size: 30.sp,
          ),
        ),
      ],
    );
  }

  Widget _buildDirectionInfo(QiblahDirection direction) {
    final offset = direction.offset;
    String statusText;
    Color statusColor;

    if (offset.abs() < 5) {
      statusText = 'أنت في الاتجاه الصحيح! ✓';
      statusColor = const Color(0xFFFFD700);
    } else if (offset > 0) {
      statusText = 'أدر لليسار ${offset.toStringAsFixed(1)}°';
      statusColor = Colors.orange;
    } else {
      statusText = 'أدر لليمين ${offset.abs().toStringAsFixed(1)}°';
      statusColor = Colors.orange;
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: _isAligned
              ? const Color(0xFFFFD700).withOpacity(0.5)
              : Colors.white.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isAligned
                    ? Icons.check_circle_rounded
                    : Icons.navigation_rounded,
                color: statusColor,
                size: 28.sp,
              ),
              SizedBox(width: 10.w),
              Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildInfoItem(
                'الاتجاه',
                '${direction.direction.toStringAsFixed(1)}°',
                Icons.explore_rounded,
              ),
              Container(
                width: 1.w,
                height: 40.h,
                color: Colors.white.withOpacity(0.2),
              ),
              _buildInfoItem(
                'القبلة',
                '${direction.qiblah.toStringAsFixed(1)}°',
                Icons.mosque_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20.sp),
        SizedBox(height: 6.h),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 12.sp,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildInstructions() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: Colors.white70,
                size: 18.sp,
              ),
              SizedBox(width: 8.w),
              Text(
                'تعليمات الاستخدام',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          _buildInstructionItem(
            '1',
            'أمسك الهاتف بشكل أفقي ومستوٍ',
          ),
          _buildInstructionItem(
            '2',
            'أدر جسمك حتى يصبح السهم الذهبي للأعلى',
          ),
          _buildInstructionItem(
            '3',
            'عندما يتوهج البوصلة، أنت في الاتجاه الصحيح',
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(String number, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20.r,
            height: 20.r,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.1),
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 13.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CompassPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Draw circle
    canvas.drawCircle(center, radius - 10, paint);

    // Draw direction markers
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    final arabicDirections = ['ش', 'شر', 'ج', 'غ'];

    for (int i = 0; i < 4; i++) {
      final angle = (i * 90) * (math.pi / 180) - (math.pi / 2);
      final x = center.dx + (radius - 25) * math.cos(angle);
      final y = center.dy + (radius - 25) * math.sin(angle);

      textPainter.text = TextSpan(
        text: arabicDirections[i],
        style: TextStyle(
          color: i == 0 ? const Color(0xFFFFD700) : Colors.white70,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, y - textPainter.height / 2),
      );
    }

    // Draw tick marks
    for (int i = 0; i < 36; i++) {
      final angle = (i * 10) * (math.pi / 180) - (math.pi / 2);
      final isMajor = i % 9 == 0;
      final startRadius = radius - (isMajor ? 12 : 8);
      final endRadius = radius - 2;

      final startX = center.dx + startRadius * math.cos(angle);
      final startY = center.dy + startRadius * math.sin(angle);
      final endX = center.dx + endRadius * math.cos(angle);
      final endY = center.dy + endRadius * math.sin(angle);

      final tickPaint = Paint()
        ..color = Colors.white.withOpacity(isMajor ? 0.5 : 0.2)
        ..strokeWidth = isMajor ? 2 : 1;

      canvas.drawLine(
        Offset(startX, startY),
        Offset(endX, endY),
        tickPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
