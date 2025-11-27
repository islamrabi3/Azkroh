import 'package:azkroh_app/features/core/appstyle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart' hide TextDirection;

class EnhancedHijriScreen extends StatefulWidget {
  const EnhancedHijriScreen({super.key});

  @override
  State<EnhancedHijriScreen> createState() => _EnhancedHijriScreenState();
}

class _EnhancedHijriScreenState extends State<EnhancedHijriScreen>
    with SingleTickerProviderStateMixin {
  late HijriCalendar _hijri;
  late DateTime _gregorian;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<Map<String, dynamic>> _islamicMonths = [
    {'name': 'محرم', 'description': 'شهر الله المحرم', 'isSpecial': true},
    {'name': 'صفر', 'description': 'شهر صفر', 'isSpecial': false},
    {'name': 'ربيع الأول', 'description': 'شهر المولد النبوي', 'isSpecial': true},
    {'name': 'ربيع الثاني', 'description': 'ربيع الآخر', 'isSpecial': false},
    {'name': 'جمادى الأولى', 'description': 'جمادى الأولى', 'isSpecial': false},
    {'name': 'جمادى الآخرة', 'description': 'جمادى الثانية', 'isSpecial': false},
    {'name': 'رجب', 'description': 'شهر الإسراء والمعراج', 'isSpecial': true},
    {'name': 'شعبان', 'description': 'شهر شعبان', 'isSpecial': false},
    {'name': 'رمضان', 'description': 'شهر الصيام', 'isSpecial': true},
    {'name': 'شوال', 'description': 'شهر العيد', 'isSpecial': true},
    {'name': 'ذو القعدة', 'description': 'من الأشهر الحرم', 'isSpecial': true},
    {'name': 'ذو الحجة', 'description': 'شهر الحج', 'isSpecial': true},
  ];

  final List<Map<String, dynamic>> _islamicEvents = [
    {'month': 1, 'day': 1, 'event': 'رأس السنة الهجرية'},
    {'month': 1, 'day': 10, 'event': 'يوم عاشوراء'},
    {'month': 3, 'day': 12, 'event': 'المولد النبوي الشريف'},
    {'month': 7, 'day': 27, 'event': 'الإسراء والمعراج'},
    {'month': 8, 'day': 15, 'event': 'ليلة النصف من شعبان'},
    {'month': 9, 'day': 1, 'event': 'بداية شهر رمضان'},
    {'month': 9, 'day': 27, 'event': 'ليلة القدر (المحتملة)'},
    {'month': 10, 'day': 1, 'event': 'عيد الفطر المبارك'},
    {'month': 12, 'day': 9, 'event': 'يوم عرفة'},
    {'month': 12, 'day': 10, 'event': 'عيد الأضحى المبارك'},
  ];

  @override
  void initState() {
    super.initState();
    _hijri = HijriCalendar.now();
    HijriCalendar.setLocal('ar');
    _gregorian = DateTime.now();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _getArabicDay(int day) {
    final arabicDays = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
    return arabicDays[day % 7];
  }

  List<Map<String, dynamic>> _getUpcomingEvents() {
    final currentMonth = _hijri.hMonth;
    final currentDay = _hijri.hDay;
    
    return _islamicEvents.where((event) {
      if (event['month'] > currentMonth) return true;
      if (event['month'] == currentMonth && event['day'] >= currentDay) return true;
      return false;
    }).take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(
              child: SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      _buildMainDateCard(),
                      _buildGregorianCard(),
                      _buildMonthInfo(),
                      _buildUpcomingEvents(),
                      _buildMonthsGrid(),
                      SizedBox(height: 24.h),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 160.h,
      floating: false,
      pinned: true,
      backgroundColor: AppStyle.darkGreen,
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: Text(
          'التقويم الهجري',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppStyle.darkGreen,
                AppStyle.primaryGreen,
                AppStyle.darkGreen.withOpacity(0.8),
              ],
            ),
          ),
          child: Stack(
            children: [
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
              Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 20.h),
                  child: Icon(
                    Icons.nightlight_round,
                    size: 50.sp,
                    color: Colors.white.withOpacity(0.3),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainDateCard() {
    return Container(
      margin: EdgeInsets.all(16.r),
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppStyle.primaryGreen,
            AppStyle.darkGreen,
          ],
        ),
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: AppStyle.primaryGreen.withOpacity(0.4),
            blurRadius: 20.r,
            offset: Offset(0, 10.h),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            _getArabicDay(_gregorian.weekday),
            style: TextStyle(
              color: Colors.white70,
              fontSize: 18.sp,
              fontFamily: 'Amiri',
            ),
          ),
          SizedBox(height: 8.h),
          Container(
            width: 100.r,
            height: 100.r,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 3.w,
              ),
            ),
            child: Center(
              child: Text(
                '${_hijri.hDay}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 48.sp,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Amiri',
                ),
              ),
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            _hijri.longMonthName,
            style: TextStyle(
              color: Colors.white,
              fontSize: 32.sp,
              fontFamily: 'Amiri',
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Text(
              '${_hijri.hYear} هـ',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20.sp,
                fontFamily: 'Amiri',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGregorianCard() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: AppStyle.lightGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              Icons.calendar_today_rounded,
              color: AppStyle.primaryGreen,
              size: 28.sp,
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'التاريخ الميلادي',
                  style: TextStyle(
                    color: AppStyle.textLight,
                    fontSize: 14.sp,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  DateFormat('dd MMMM yyyy', 'ar').format(_gregorian),
                  style: TextStyle(
                    color: AppStyle.textDark,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Amiri',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthInfo() {
    final monthInfo = _islamicMonths[_hijri.hMonth - 1];
    final isSpecial = monthInfo['isSpecial'] as bool;

    return Container(
      margin: EdgeInsets.all(16.r),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: isSpecial 
            ? AppStyle.goldColor.withOpacity(0.1)
            : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: isSpecial
            ? Border.all(color: AppStyle.goldColor.withOpacity(0.5), width: 2.w)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: isSpecial 
                  ? AppStyle.goldColor.withOpacity(0.2)
                  : AppStyle.lightGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              isSpecial ? Icons.star_rounded : Icons.info_outline_rounded,
              color: isSpecial ? AppStyle.goldColor : AppStyle.primaryGreen,
              size: 28.sp,
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSpecial ? 'شهر مبارك' : 'معلومات عن الشهر',
                  style: TextStyle(
                    color: isSpecial ? AppStyle.goldColor : AppStyle.textLight,
                    fontSize: 14.sp,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  monthInfo['description'] as String,
                  style: TextStyle(
                    color: AppStyle.textDark,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Amiri',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingEvents() {
    final events = _getUpcomingEvents();
    if (events.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            child: Text(
              'المناسبات القادمة',
              style: TextStyle(
                color: AppStyle.textDark,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                fontFamily: 'Amiri',
              ),
            ),
          ),
          ...events.map((event) => _buildEventCard(event)),
        ],
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8.r,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50.r,
            height: 50.r,
            decoration: BoxDecoration(
              gradient: AppStyle.islamicGradient,
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${event['day']}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _islamicMonths[event['month'] - 1]['name'].toString().split(' ').first,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10.sp,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Text(
              event['event'] as String,
              style: TextStyle(
                color: AppStyle.textDark,
                fontSize: 16.sp,
                fontFamily: 'Amiri',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthsGrid() {
    return Container(
      margin: EdgeInsets.all(16.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: Text(
              'الأشهر الهجرية',
              style: TextStyle(
                color: AppStyle.textDark,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                fontFamily: 'Amiri',
              ),
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.3,
              crossAxisSpacing: 8.w,
              mainAxisSpacing: 8.h,
            ),
            itemCount: 12,
            itemBuilder: (context, index) {
              final isCurrentMonth = index + 1 == _hijri.hMonth;
              final isSpecial = _islamicMonths[index]['isSpecial'] as bool;
              
              return Container(
                decoration: BoxDecoration(
                  color: isCurrentMonth 
                      ? AppStyle.primaryGreen 
                      : isSpecial 
                          ? AppStyle.goldColor.withOpacity(0.1)
                          : Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  border: isSpecial && !isCurrentMonth
                      ? Border.all(color: AppStyle.goldColor.withOpacity(0.5))
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: isCurrentMonth 
                          ? AppStyle.primaryGreen.withOpacity(0.3)
                          : Colors.black.withOpacity(0.03),
                      blurRadius: 8.r,
                      offset: Offset(0, 2.h),
                    ),
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: isCurrentMonth 
                              ? Colors.white70 
                              : AppStyle.textLight,
                          fontSize: 12.sp,
                        ),
                      ),
                      Text(
                        _islamicMonths[index]['name'] as String,
                        style: TextStyle(
                          color: isCurrentMonth 
                              ? Colors.white 
                              : AppStyle.textDark,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Amiri',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
