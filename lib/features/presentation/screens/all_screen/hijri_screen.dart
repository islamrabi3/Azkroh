import 'package:azkroh_app/features/core/appstyle.dart';
import 'package:flutter/material.dart';
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
            title: const Text('التقويم الهجري '),
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  'assets/images/date-svgrepo-com.svg',
                  color: Colors.blueGrey,
                  height: 100.0,
                  width: 100.0,
                ),
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Container(
                      width: double.infinity,
                      height: 80.0,
                      decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.circular(15.0)),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            hijri.fullDate(),
                            style: AppStyle.regularTextStyle.copyWith(
                              fontSize: 30,
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
