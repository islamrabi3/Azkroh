import 'package:azkroh_app/features/core/appstyle.dart';
import 'package:azkroh_app/features/core/methods/methods.dart';
import 'package:azkroh_app/features/core/services/azkar_state_service.dart';
import 'package:azkroh_app/features/presentation/cubit/cubit.dart';
import 'package:azkroh_app/features/presentation/cubit/states.dart';
import 'package:azkroh_app/features/presentation/screens/enhanced_azkar_screen.dart';
import 'package:azkroh_app/features/presentation/screens/notification_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hijri/hijri_calendar.dart';

class HomePageScreen extends StatefulWidget {
  const HomePageScreen({super.key});

  @override
  State<HomePageScreen> createState() => _HomePageScreenState();
}

class _HomePageScreenState extends State<HomePageScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final AzkarStateService _azkarService = AzkarStateService();
  late HijriCalendar _hijri;

  @override
  void initState() {
    super.initState();
    _hijri = HijriCalendar.now();
    HijriCalendar.setLocal('ar');

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'صباح الخير';
    } else if (hour < 17) {
      return 'مساء الخير';
    } else {
      return 'مساء النور';
    }
  }

  String _getAzkarStatus() {
    final period = _azkarService.getCurrentPeriod();
    if (period == AzkarPeriod.morning) {
      return 'وقت أذكار الصباح';
    } else if (period == AzkarPeriod.evening) {
      return 'وقت أذكار المساء';
    }
    return 'اذكر الله';
  }

  String _formatTime12Hour(String time24) {
    try {
      final timeStr = time24.split(' ')[0];
      final parts = timeStr.split(':');
      int hour = int.parse(parts[0]);
      final minute = parts[1];

      String period = hour < 12 ? 'ص' : 'م';
      if (hour == 0) {
        hour = 12;
      } else if (hour > 12) {
        hour = hour - 12;
      }

      return '$hour:$minute $period';
    } catch (e) {
      return time24;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AppCubit, Appstates>(
      builder: (context, state) {
        AppCubit cubit = context.read<AppCubit>();

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: const Color(0xFFF8F9FA),
            body: FadeTransition(
              opacity: _fadeAnimation,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _buildAppBar(cubit),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 20.h),
                          _buildPrayerTimeCard(cubit),
                          SizedBox(height: 24.h),
                          _buildSectionHeader(
                              'الأذكار اليومية', Icons.auto_awesome_rounded),
                          SizedBox(height: 12.h),
                          _buildAzkarCards(cubit),
                          SizedBox(height: 24.h),
                          _buildSectionHeader('الخدمات', Icons.apps_rounded),
                          SizedBox(height: 12.h),
                          _buildServicesGrid(cubit),
                          SizedBox(height: 30.h),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      listener: (context, state) {},
    );
  }

  Widget _buildAppBar(AppCubit cubit) {
    return SliverAppBar(
      expandedHeight: 250.h,
      floating: false,
      pinned: true,
      backgroundColor: AppStyle.primaryGreen,
      elevation: 0,
      actions: [
        IconButton(
          icon: Container(
            padding: EdgeInsets.all(8.r),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(Icons.share_rounded, color: Colors.white, size: 20.sp),
          ),
          onPressed: () => cubit.shareMethod(
            'https://play.google.com/store/apps/details?id=com.islamsalemco.azkroh',
          ),
        ),
        IconButton(
          icon: Container(
            padding: EdgeInsets.all(8.r),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child:
                Icon(Icons.settings_rounded, color: Colors.white, size: 20.sp),
          ),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const NotificationSettingsScreen()),
          ),
        ),
        SizedBox(width: 8.w),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1B5E20),
                Color(0xFF2E7D32),
                Color(0xFF388E3C),
              ],
            ),
          ),
          child: Stack(
            children: [
              // Decorative patterns
              Positioned(
                top: -50.h,
                right: -50.w,
                child: Container(
                  width: 200.r,
                  height: 200.r,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
              ),
              Positioned(
                bottom: -80.h,
                left: -80.w,
                child: Container(
                  width: 250.r,
                  height: 250.r,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
              ),
              // Moon decoration
              Positioned(
                top: 60.h,
                left: 30.w,
                child: Icon(
                  Icons.nightlight_round,
                  size: 40.sp,
                  color: Colors.white.withOpacity(0.15),
                ),
              ),
              // Content
              SafeArea(
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Spacer(),
                      // Greeting
                      Text(
                        _getGreeting(),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14.sp,
                          fontFamily: 'Amiri',
                        ),
                      ),
                      SizedBox(height: 2.h),
                      // App name
                      Text(
                        'أذكروه',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32.sp,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Amiri',
                        ),
                      ),
                      SizedBox(height: 6.h),
                      // Hijri date and status in a row
                      Wrap(
                        spacing: 8.w,
                        runSpacing: 8.h,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 5.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.calendar_month_rounded,
                                  color: Colors.white70,
                                  size: 14.sp,
                                ),
                                SizedBox(width: 6.w),
                                Text(
                                  '${_hijri.hDay} ${_hijri.longMonthName} ${_hijri.hYear} هـ',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.sp,
                                    fontFamily: 'Amiri',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Status badge
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 5.h,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFD700), Color(0xFFB8860B)],
                              ),
                              borderRadius: BorderRadius.circular(16.r),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFFFFD700).withOpacity(0.3),
                                  blurRadius: 6.r,
                                  offset: Offset(0, 2.h),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.auto_awesome,
                                  color: const Color(0xFF1B5E20),
                                  size: 14.sp,
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  _getAzkarStatus(),
                                  style: TextStyle(
                                    color: const Color(0xFF1B5E20),
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Amiri',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrayerTimeCard(AppCubit cubit) {
    final hasData = cubit.azanEntityData != null;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2E7D32),
            Color(0xFF1B5E20),
          ],
        ),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: AppStyle.primaryGreen.withOpacity(0.3),
            blurRadius: 12.r,
            offset: Offset(0, 6.h),
          ),
        ],
      ),
      child: hasData
          ? _buildPrayerContent(cubit)
          : Center(
              child: Padding(
                padding: EdgeInsets.all(16.r),
                child: const CircularProgressIndicator(color: Colors.white),
              ),
            ),
    );
  }

  Widget _buildPrayerContent(AppCubit cubit) {
    final timings = cubit.azanEntityData!.data.timings;
    final now = DateTime.now();

    final prayers = [
      {'name': 'الفجر', 'time': timings.fajr},
      {'name': 'الظهر', 'time': timings.dhuhr},
      {'name': 'العصر', 'time': timings.asr},
      {'name': 'المغرب', 'time': timings.maghrib},
      {'name': 'العشاء', 'time': timings.isha},
    ];

    String nextPrayer = prayers[0]['name'] as String;
    String nextTime = prayers[0]['time'] as String;

    for (var prayer in prayers) {
      final timeStr = (prayer['time'] as String).split(' ')[0];
      final parts = timeStr.split(':');
      final prayerTime = DateTime(now.year, now.month, now.day,
          int.parse(parts[0]), int.parse(parts[1]));
      if (prayerTime.isAfter(now)) {
        nextPrayer = prayer['name'] as String;
        nextTime = prayer['time'] as String;
        break;
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'الصلاة القادمة',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12.sp,
                    fontFamily: 'Amiri',
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  nextPrayer,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24.sp,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Amiri',
                  ),
                ),
              ],
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: Text(
                _formatTime12Hour(nextTime),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildMiniPrayerTime('الفجر', _formatTime12Hour(timings.fajr)),
            _buildMiniPrayerTime('الظهر', _formatTime12Hour(timings.dhuhr)),
            _buildMiniPrayerTime('العصر', _formatTime12Hour(timings.asr)),
            _buildMiniPrayerTime('المغرب', _formatTime12Hour(timings.maghrib)),
            _buildMiniPrayerTime('العشاء', _formatTime12Hour(timings.isha)),
          ],
        ),
      ],
    );
  }

  Widget _buildMiniPrayerTime(String name, String time) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 10.sp,
            fontFamily: 'Amiri',
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          time,
          style: TextStyle(
            color: Colors.white,
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8.r),
          decoration: BoxDecoration(
            color: AppStyle.primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Icon(icon, color: AppStyle.primaryGreen, size: 20.sp),
        ),
        SizedBox(width: 12.w),
        Text(
          title,
          style: TextStyle(
            color: AppStyle.textDark,
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            fontFamily: 'Amiri',
          ),
        ),
      ],
    );
  }

  Widget _buildAzkarCards(AppCubit cubit) {
    return SizedBox(
      height: 150.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 4.w),
        separatorBuilder: (context, index) => SizedBox(width: 16.w),
        itemCount: cubit.azkarMap.length,
        itemBuilder: (context, index) {
          final azkar = cubit.azkarMap[index];
          String azkarType = 'other';
          if (azkar['title'] == 'أذكار الصباح') {
            azkarType = 'morning';
          } else if (azkar['title'] == 'أذكار المساء') {
            azkarType = 'evening';
          }

          final isMorning = azkarType == 'morning';
          final isEvening = azkarType == 'evening';
          final isCurrentPeriod =
              (isMorning && _azkarService.isMorningAzkarTime()) ||
                  (isEvening && _azkarService.isEveningAzkarTime());

          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 400 + (index * 100)),
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(30 * (1 - value), 0),
                child: Opacity(opacity: value, child: child),
              );
            },
            child: GestureDetector(
              onTap: () => navigateTo(
                context,
                EnhancedAzkarScreen(
                  pageTitle: azkar['title'],
                  listOfDoaaModel: azkar['zekr_contetnt'],
                  azkarType: azkarType,
                ),
              ),
              child: Container(
                width: 170.w,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20.r),
                  image: DecorationImage(
                    image: AssetImage(azkar['image']),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                      Colors.black.withOpacity(0.4),
                      BlendMode.darken,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 10.r,
                      offset: Offset(0, 4.h),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20.r),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                      ),
                    ),
                    if (isCurrentPeriod)
                      Positioned(
                        top: 12.h,
                        right: 12.w,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFD700), Color(0xFFB8860B)],
                            ),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.access_time_rounded,
                                  color: const Color(0xFF1B5E20), size: 12.sp),
                              SizedBox(width: 4.w),
                              Text(
                                'الآن',
                                style: TextStyle(
                                  color: const Color(0xFF1B5E20),
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 16.h,
                      right: 16.w,
                      left: 16.w,
                      child: Text(
                        azkar['title'],
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Amiri',
                          shadows: const [
                            Shadow(color: Colors.black45, blurRadius: 4),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildServicesGrid(AppCubit cubit) {
    final services = [
      {
        'title': 'المصحف',
        'icon': 'assets/images/quran-rehal-svgrepo-com.svg',
        'color': AppStyle.primaryGreen,
        'bgColor': const Color(0xFFE8F5E9),
      },
      {
        'title': 'السبحة',
        'icon': 'assets/images/necklace-svgrepo-com.svg',
        'color': AppStyle.goldColor,
        'bgColor': const Color(0xFFFFF8E1),
      },
      {
        'title': 'الصلاة',
        'icon': 'assets/images/mosque-svgrepo-com.svg',
        'color': AppStyle.darkGreen,
        'bgColor': const Color(0xFFE0F2F1),
      },
      {
        'title': 'الإذاعة',
        'icon': 'assets/images/radio-svgrepo-com.svg',
        'color': const Color(0xFF5C6BC0),
        'bgColor': const Color(0xFFE8EAF6),
      },
      {
        'title': 'القبلة',
        'icon': 'assets/images/kaaba-svgrepo-com.svg',
        'color': const Color(0xFF8D6E63),
        'bgColor': const Color(0xFFEFEBE9),
      },
      {
        'title': 'التقويم',
        'icon': 'assets/images/date-svgrepo-com.svg',
        'color': const Color(0xFF26A69A),
        'bgColor': const Color(0xFFE0F2F1),
      },
    ];

    return Wrap(
      spacing: 12.w,
      runSpacing: 12.h,
      children: List.generate(services.length, (index) {
        final service = services[index];

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 400 + (index * 80)),
          builder: (context, value, child) {
            return Transform.scale(
              scale: 0.8 + (0.2 * value),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: GestureDetector(
            onTap: () => navigateTo(context, cubit.screens[index]),
            child: Container(
              width: 110.w,
              height: 110.h,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
                boxShadow: [
                  BoxShadow(
                    color: (service['color'] as Color).withOpacity(0.1),
                    blurRadius: 10.r,
                    offset: Offset(0, 4.h),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16.r),
                  onTap: () => navigateTo(context, cubit.screens[index]),
                  child: Padding(
                    padding: EdgeInsets.all(12.r),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          flex: 3,
                          child: Container(
                            padding: EdgeInsets.all(10.r),
                            decoration: BoxDecoration(
                              color: service['bgColor'] as Color,
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: SvgPicture.asset(
                              service['icon'] as String,
                              width: 26.w,
                              height: 26.h,
                              color: service['color'] as Color,
                            ),
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Flexible(
                          flex: 1,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              service['title'] as String,
                              style: TextStyle(
                                color: AppStyle.textDark,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Amiri',
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
