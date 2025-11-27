import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../presentation/cubit/cubit.dart';
import '../app_strings.dart';
import '../appstyle.dart';

import '../doaa_model.dart';

class CustomAzkarCardWidget extends StatelessWidget {
  const CustomAzkarCardWidget({
    Key? key,
    this.listOfDoaaModel,
    required this.cubit,
    required this.index,
  }) : super(key: key);

  final List<DoaaModel>? listOfDoaaModel;
  final AppCubit cubit;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r)),
      child: Padding(
        padding: EdgeInsets.all(12.r),
        child: Column(
          children: [
            Text(
              '${listOfDoaaModel![index].content}',
              style: TextStyle(
                fontFamily: 'Amiri',
                fontSize: 18.sp,
                color: AppStyle.textDark,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8.h),
            Text(
              '${listOfDoaaModel![index].desc}',
              style: TextStyle(
                fontFamily: 'Amiri',
                fontSize: 14.sp,
                color: AppStyle.lightGreen,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: Container(
                    height: 36.h,
                    decoration: BoxDecoration(
                        color: AppStyle.primaryGreen,
                        borderRadius: BorderRadius.circular(18.r)),
                    child: InkWell(
                      onTap: () => cubit.azkarCountIncremeantMethod(
                          listOfDoaaModel!, index),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Text(
                            listOfDoaaModel![index].repeatTime == 0
                                ? AppString.doneRepeatTimeString
                                : AppString.repeatTimeString,
                            style: TextStyle(
                                fontFamily: 'Amiri',
                                fontSize: 16.sp,
                                color: AppStyle.pureWhite),
                          ),
                          Text(
                            ': ${listOfDoaaModel![index].repeatTime}',
                            style: TextStyle(
                                fontFamily: 'Amiri',
                                fontSize: 16.sp,
                                color: AppStyle.pureWhite),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
