import 'package:azkroh_app/features/core/appstyle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HijriCalender extends StatelessWidget {
  const HijriCalender({super.key});

  @override
  Widget build(BuildContext context) {
    var hijri = HijriCalendar.now();
    HijriCalendar.setLocal('ar');
    return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              'التقويم الهجري',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: AppStyle.primaryGreen,
            centerTitle: true,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  'assets/images/date-svgrepo-com.svg',
                  // ignore: deprecated_member_use
                  color: Colors.blueGrey,
                  height: 100.r,
                  width: 100.r,
                ),
                Padding(
                  padding: EdgeInsets.all(10.r),
                  child: Container(
                      width: double.infinity,
                      height: 80.h,
                      decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.circular(15.r)),
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(8.r),
                          child: Text(
                            hijri.fullDate(),
                            style: TextStyle(
                              fontSize: 30.sp,
                              fontFamily: 'Amiri',
                              color: AppStyle.textDark,
                            ),
                          ),
                        ),
                      )),
                ),
              ],
            ),
          ),
        ));
  }
}
