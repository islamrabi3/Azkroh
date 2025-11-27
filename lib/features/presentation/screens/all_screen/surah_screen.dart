import 'package:azkroh_app/features/core/appstyle.dart';
import 'package:azkroh_app/features/presentation/cubit/cubit.dart';
import 'package:azkroh_app/features/presentation/cubit/states.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../domain/entity/quran_entity.dart';

class SurahScreen extends StatelessWidget {
  const SurahScreen(
      {super.key,
      required this.title,
      required this.list,
      required this.itemCount});

  final String title;
  final List<AyahEntity> list;
  final int itemCount;

  String _convertToArabicNumbers(String number) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

    String result = number;
    for (int i = 0; i < english.length; i++) {
      result = result.replaceAll(english[i], arabic[i]);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
        textDirection: TextDirection.rtl,
        child: BlocConsumer<AppCubit, Appstates>(
          builder: (context, state) {
            var cubit = context.read<AppCubit>();
            return Scaffold(
              appBar: AppBar(
                title: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                centerTitle: true,
                backgroundColor: AppStyle.primaryGreen,
                iconTheme: const IconThemeData(color: Colors.white),
              ),
              body: ListView.builder(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                addAutomaticKeepAlives: true,
                key: const PageStorageKey<String>('page'),
                itemBuilder: (context, index) {
                  return InkWell(
                    onLongPress: () {
                      var dialog = Dialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(16.r),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              IconButton(
                                  onPressed: () {
                                    cubit
                                        .shareMethod(list[index].ayahText)
                                        .then(
                                            (value) => Navigator.pop(context));
                                  },
                                  icon: Icon(Icons.share, size: 24.sp)),
                              IconButton(
                                  onPressed: () {
                                    cubit
                                        .addQuranModelToQuranHiveBox(
                                            list, index)
                                        .then(
                                            (value) => Navigator.pop(context));
                                  },
                                  icon: Icon(
                                    Icons.favorite,
                                    color: Colors.blueGrey,
                                    size: 24.sp,
                                  )),
                            ],
                          ),
                        ),
                      );
                      showDialog(
                        context: context,
                        builder: (context) {
                          return dialog;
                        },
                      );
                    },
                    child: Container(
                      decoration: AppStyle.islamicCardDecoration,
                      margin: EdgeInsets.symmetric(
                          vertical: 4.h, horizontal: 8.w),
                      child: Padding(
                        padding: EdgeInsets.all(16.r),
                        child: RichText(
                          textAlign: TextAlign.right,
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: list[index].ayahText,
                                style: AppStyle.quranTextStyle.copyWith(fontSize: 22.sp),
                              ),
                              TextSpan(
                                text:
                                    ' ﴿${_convertToArabicNumbers(list[index].numberInSurah.toString())}﴾',
                                style: AppStyle.goldTextStyle.copyWith(
                                    fontSize: 18.sp,
                                    fontFamily: 'Amiri-Quran',
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
                itemCount: itemCount,
              ),
            );
          },
          listener: (context, state) {
            if (state is QuranFavoruiteBtnState) {
              if (state.isFavorite) {
                final snackBar = SnackBar(
                  content: Text(
                    'تمت الاضافة بنجاح',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14.sp),
                  ),
                  backgroundColor: Colors.green,
                  elevation: 10.0,
                );
                ScaffoldMessenger.of(context).showSnackBar(snackBar);
              } else {
                return;
              }
            }
          },
        ));
  }
}
