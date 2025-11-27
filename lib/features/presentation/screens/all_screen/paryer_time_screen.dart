import 'package:azkroh_app/features/core/appstyle.dart';
import 'package:azkroh_app/features/presentation/cubit/cubit.dart';
import 'package:azkroh_app/features/presentation/cubit/states.dart';
import 'package:azkroh_app/features/presentation/screens/azan_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hijri/hijri_calendar.dart';

class PrayerScreen extends StatefulWidget {
  const PrayerScreen({super.key});

  @override
  State<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends State<PrayerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
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

  String _getNextPrayer(Map<String, String> timings) {
    final now = DateTime.now();
    final prayers = [
      {'name': 'الفجر', 'time': timings['fajr']!},
      {'name': 'الشروق', 'time': timings['sunrise']!},
      {'name': 'الظهر', 'time': timings['dhuhr']!},
      {'name': 'العصر', 'time': timings['asr']!},
      {'name': 'المغرب', 'time': timings['maghrib']!},
      {'name': 'العشاء', 'time': timings['isha']!},
    ];

    for (var prayer in prayers) {
      final timeStr = prayer['time']!.split(' ')[0];
      final parts = timeStr.split(':');
      final prayerTime = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
      if (prayerTime.isAfter(now)) {
        return prayer['name']!;
      }
    }
    return 'الفجر';
  }

  Duration _getTimeUntilNextPrayer(Map<String, String> timings) {
    final now = DateTime.now();
    final prayers = [
      timings['fajr']!,
      timings['sunrise']!,
      timings['dhuhr']!,
      timings['asr']!,
      timings['maghrib']!,
      timings['isha']!,
    ];

    for (var time in prayers) {
      final timeStr = time.split(' ')[0];
      final parts = timeStr.split(':');
      final prayerTime = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
      if (prayerTime.isAfter(now)) {
        return prayerTime.difference(now);
      }
    }
    final fajrStr = timings['fajr']!.split(' ')[0];
    final fajrParts = fajrStr.split(':');
    final nextFajr = DateTime(
      now.year,
      now.month,
      now.day + 1,
      int.parse(fajrParts[0]),
      int.parse(fajrParts[1]),
    );
    return nextFajr.difference(now);
  }

  @override
  Widget build(BuildContext context) {
    final hijri = HijriCalendar.now();
    HijriCalendar.setLocal('ar');

    return BlocConsumer<AppCubit, Appstates>(
      builder: (context, state) {
        var cubit = context.read<AppCubit>();

        if (cubit.azanEntityData == null) {
          return Scaffold(
            backgroundColor: const Color(0xFFF5F5F5),
            appBar: AppBar(
              backgroundColor: AppStyle.primaryGreen,
              title: Text(
                'مواقيت الصلاة',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              centerTitle: true,
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            body: const Center(
              child: CircularProgressIndicator(color: AppStyle.primaryGreen),
            ),
          );
        }

        final timings = {
          'fajr': cubit.azanEntityData!.data.timings.fajr,
          'sunrise': cubit.azanEntityData!.data.timings.sunrise,
          'dhuhr': cubit.azanEntityData!.data.timings.dhuhr,
          'asr': cubit.azanEntityData!.data.timings.asr,
          'maghrib': cubit.azanEntityData!.data.timings.maghrib,
          'isha': cubit.azanEntityData!.data.timings.isha,
        };

        final nextPrayer = _getNextPrayer(timings);
        final timeUntil = _getTimeUntilNextPrayer(timings);

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: const Color(0xFFF5F5F5),
            body: FadeTransition(
              opacity: _fadeAnimation,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _buildAppBar(hijri, nextPrayer, timeUntil),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(16.r),
                      child: Column(
                        children: [
                          _buildPrayerCard(
                            'الفجر',
                            timings['fajr']!,
                            Icons.nightlight_round,
                            const Color(0xFF1A237E),
                            nextPrayer == 'الفجر',
                            0,
                          ),
                          _buildPrayerCard(
                            'الشروق',
                            timings['sunrise']!,
                            Icons.wb_sunny_outlined,
                            const Color(0xFFFF6F00),
                            nextPrayer == 'الشروق',
                            1,
                          ),
                          _buildPrayerCard(
                            'الظهر',
                            timings['dhuhr']!,
                            Icons.wb_sunny_rounded,
                            const Color(0xFFFFC107),
                            nextPrayer == 'الظهر',
                            2,
                          ),
                          _buildPrayerCard(
                            'العصر',
                            timings['asr']!,
                            Icons.sunny_snowing,
                            const Color(0xFFFF9800),
                            nextPrayer == 'العصر',
                            3,
                          ),
                          _buildPrayerCard(
                            'المغرب',
                            timings['maghrib']!,
                            Icons.wb_twilight_rounded,
                            const Color(0xFFE65100),
                            nextPrayer == 'المغرب',
                            4,
                          ),
                          _buildPrayerCard(
                            'العشاء',
                            timings['isha']!,
                            Icons.nights_stay_rounded,
                            const Color(0xFF311B92),
                            nextPrayer == 'العشاء',
                            5,
                          ),
                          SizedBox(height: 20.h),
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

  Widget _buildAppBar(
    HijriCalendar hijri,
    String nextPrayer,
    Duration timeUntil,
  ) {
    final hours = timeUntil.inHours;
    final minutes = timeUntil.inMinutes % 60;

    // Fixed minimum height to ensure content is never cropped
    final expandedHeight = 280.h.clamp(260.0, 320.0);

    return SliverAppBar(
      expandedHeight: expandedHeight,
      floating: false,
      pinned: true,
      backgroundColor: AppStyle.primaryGreen,
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AzanSettingsScreen(),
              ),
            );
          },
          icon: Icon(Icons.volume_up_rounded, color: Colors.white, size: 24.sp),
          tooltip: 'إعدادات الأذان',
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF1B5E20),
                Color(0xFF2E7D32),
                Color(0xFF388E3C),
              ],
            ),
          ),
          child: Stack(
            children: [
              // Decorative circles
              Positioned(
                top: -30.h,
                right: -30.w,
                child: Container(
                  width: 150.r,
                  height: 150.r,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
              ),
              Positioned(
                bottom: -50.h,
                left: -50.w,
                child: Container(
                  width: 200.r,
                  height: 200.r,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
              ),
              // Content
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: 20.h),
                      // Title
                      Text(
                        'مواقيت الصلاة',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      // Date
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14.w,
                          vertical: 6.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Text(
                          '${hijri.hDay} ${hijri.longMonthName} ${hijri.hYear} هـ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.sp,
                          ),
                        ),
                      ),
                      SizedBox(height: 16.h),
                      // Next Prayer Card
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(14.r),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Next Prayer Info
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'الصلاة القادمة',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 12.sp,
                                    ),
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    nextPrayer,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Time Remaining
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'متبقي',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 12.sp,
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildTimeUnit(hours.toString(), 'س'),
                                    SizedBox(width: 6.w),
                                    _buildTimeUnit(
                                      minutes.toString().padLeft(2, '0'),
                                      'د',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
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

  Widget _buildTimeUnit(String value, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: 3.w),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerCard(
    String name,
    String time,
    IconData icon,
    Color color,
    bool isNext,
    int index,
  ) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 100)),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30.h * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        decoration: BoxDecoration(
          color: isNext ? color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: isNext
              ? Border.all(color: color, width: 2.w)
              : Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: isNext
                  ? color.withOpacity(0.2)
                  : Colors.black.withOpacity(0.05),
              blurRadius: 10.r,
              offset: Offset(0, 4.h),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          leading: Container(
            width: 48.r,
            height: 48.r,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(icon, color: color, size: 24.sp),
          ),
          title: Text(
            name,
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: isNext ? FontWeight.bold : FontWeight.w600,
              color: isNext ? color : AppStyle.textDark,
            ),
          ),
          subtitle: isNext
              ? Text(
                  'الصلاة القادمة',
                  style: TextStyle(
                    color: AppStyle.primaryGreen,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                  ),
                )
              : null,
          trailing: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: isNext ? color : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Text(
              _formatTime12Hour(time),
              style: TextStyle(
                color: isNext ? Colors.white : AppStyle.textDark,
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
