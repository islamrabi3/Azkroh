import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:radio_player/radio_player.dart';

class RadioScreen extends StatefulWidget {
  const RadioScreen({super.key});

  @override
  State<RadioScreen> createState() => _RadioScreenState();
}

class _RadioScreenState extends State<RadioScreen>
    with TickerProviderStateMixin {
  RadioPlayer radioPlayer = RadioPlayer();
  bool isPlaying = false;
  bool isLoading = false;

  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _waveController;

  final List<Map<String, String>> radioStations = [
    {
      'name': 'إذاعة القرآن الكريم',
      'url':
          'http://n07.radiojar.com/8s5u5tpdtwzuv?rj-ttl=5&rj-tok=AAABhXglQt4AOpim4iZjKalTLg',
      'image': 'assets/images/R.jpg',
    },
  ];

  int currentStationIndex = 0;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initRadioPlayer();
  }

  void _initAnimations() {
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> _initRadioPlayer() async {
    setState(() => isLoading = true);
    try {
      await radioPlayer.setChannel(
        title: radioStations[currentStationIndex]['name']!,
        url: radioStations[currentStationIndex]['url']!,
        imagePath: radioStations[currentStationIndex]['image']!,
      );

      radioPlayer.stateStream.listen((value) {
        setState(() {
          isPlaying = value;
          if (value) {
            _rotationController.repeat();
            _pulseController.repeat(reverse: true);
            _waveController.repeat();
          } else {
            _rotationController.stop();
            _pulseController.stop();
            _waveController.stop();
          }
        });
      });
    } catch (e) {
      debugPrint('Radio init error: $e');
    }
    setState(() => isLoading = false);
  }

  void _togglePlay() {
    HapticFeedback.lightImpact();
    if (isPlaying) {
      radioPlayer.pause();
    } else {
      radioPlayer.play();
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _waveController.dispose();
    radioPlayer.stop();
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
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24.w),
                      child: Column(
                        children: [
                          SizedBox(height: 40.h),
                          _buildRadioVisualizer(),
                          SizedBox(height: 40.h),
                          _buildStationInfo(),
                          SizedBox(height: 40.h),
                          _buildPlayButton(),
                          SizedBox(height: 30.h),
                          _buildWaveAnimation(),
                          SizedBox(height: 40.h),
                          _buildInfoCard(),
                          SizedBox(height: 30.h),
                        ],
                      ),
                    ),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
          Text(
            'إذاعة القرآن الكريم',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: 48.w), // Balance the back button
        ],
      ),
    );
  }

  Widget _buildRadioVisualizer() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer glow rings
        ...List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = 1.0 +
                  (index * 0.15) +
                  (_pulseAnimation.value - 1.0) * (index + 1) * 0.5;
              return Container(
                width: (180 + index * 40).w * (isPlaying ? scale : 1.0),
                height: (180 + index * 40).w * (isPlaying ? scale : 1.0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1 - index * 0.03),
                    width: 2,
                  ),
                ),
              );
            },
          );
        }),
        // Rotating disc
        AnimatedBuilder(
          animation: _rotationController,
          builder: (context, child) {
            return Transform.rotate(
              angle: _rotationController.value * 2 * math.pi,
              child: child,
            );
          },
          child: Container(
            width: 200.w,
            height: 200.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [
                  Color(0xFF3E2723),
                  Color(0xFF1B0F0E),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 20.r,
                  offset: Offset(0, 10.h),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Vinyl grooves
                ...List.generate(5, (index) {
                  return Container(
                    width: (180 - index * 30).w,
                    height: (180 - index * 30).w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.05),
                        width: 1,
                      ),
                    ),
                  );
                }),
                // Center label
                Container(
                  width: 80.w,
                  height: 80.w,
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
                        color: const Color(0xFFFFD700).withOpacity(0.3),
                        blurRadius: 10.r,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.mosque_rounded,
                      color: const Color(0xFF1B5E20),
                      size: 35.sp,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStationInfo() {
    return Column(
      children: [
        Text(
          'إذاعة القرآن الكريم',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8.w,
                height: 8.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isPlaying ? Colors.greenAccent : Colors.grey,
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                isPlaying ? 'جاري البث المباشر' : 'متوقف',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14.sp,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlayButton() {
    return GestureDetector(
      onTap: isLoading ? null : _togglePlay,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 80.w,
        height: 80.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isPlaying
                ? [const Color(0xFFE53935), const Color(0xFFC62828)]
                : [const Color(0xFFFFD700), const Color(0xFFB8860B)],
          ),
          boxShadow: [
            BoxShadow(
              color: (isPlaying ? Colors.red : const Color(0xFFFFD700))
                  .withOpacity(0.4),
              blurRadius: 20.r,
              offset: Offset(0, 8.h),
            ),
          ],
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 30.w,
                  height: 30.w,
                  child: const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                )
              : Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: isPlaying ? Colors.white : const Color(0xFF1B5E20),
                  size: 40.sp,
                ),
        ),
      ),
    );
  }

  Widget _buildWaveAnimation() {
    return SizedBox(
      height: 60.h,
      child: AnimatedBuilder(
        animation: _waveController,
        builder: (context, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(20, (index) {
              final height = isPlaying
                  ? (20 +
                          math.sin((_waveController.value * 2 * math.pi) +
                                  (index * 0.3)) *
                              20)
                      .abs()
                  : 10.0;
              return Container(
                margin: EdgeInsets.symmetric(horizontal: 2.w),
                width: 4.w,
                height: height.h,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(isPlaying ? 0.8 : 0.3),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  color: Colors.white70, size: 20.sp),
              SizedBox(width: 10.w),
              Text(
                'عن الإذاعة',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            'إذاعة القرآن الكريم من القاهرة - بث مباشر على مدار الساعة لتلاوات القرآن الكريم بأصوات أشهر القراء.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14.sp,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            alignment: WrapAlignment.center,
            children: [
              _buildTag('بث مباشر'),
              _buildTag('24 ساعة'),
              _buildTag('القاهرة'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD700).withOpacity(0.2),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: const Color(0xFFFFD700),
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
