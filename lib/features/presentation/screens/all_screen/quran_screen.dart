import 'package:azkroh_app/features/core/appstyle.dart';
import 'package:azkroh_app/features/core/methods/methods.dart';
import 'package:azkroh_app/features/presentation/cubit/cubit.dart';
import 'package:azkroh_app/features/presentation/cubit/states.dart';
import 'package:azkroh_app/features/presentation/screens/all_screen/surah_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class QuranScreen extends StatelessWidget {
  const QuranScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AppCubit, Appstates>(
      builder: (context, state) {
        var cubit = context.read<AppCubit>();
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            appBar: AppBar(
              backgroundColor: AppStyle.primaryGreen,
              centerTitle: true,
              iconTheme: const IconThemeData(color: Colors.white),
              title: Text(
                'القرءان الكريم',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            body: cubit.quranEntity != null
                ? ListView.separated(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    addAutomaticKeepAlives: true,
                    key: const PageStorageKey<String>('page'),
                    itemBuilder: (context, index) {
                      return Container(
                        decoration: AppStyle.islamicCardDecoration,
                        margin: EdgeInsets.symmetric(
                            vertical: 4.h, horizontal: 8.w),
                        child: ListTile(
                          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                          onTap: () => navigateTo(
                              context,
                              SurahScreen(
                                itemCount: cubit
                                    .quranEntity!
                                    .data
                                    .listOfSurahs[index]
                                    .listOfAyahEntity
                                    .length,
                                title: cubit
                                    .quranEntity!.data.listOfSurahs[index].name,
                                list: cubit.quranEntity!.data
                                    .listOfSurahs[index].listOfAyahEntity,
                              )),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                cubit
                                    .quranEntity!.data.listOfSurahs[index].name,
                                style: TextStyle(
                                    fontSize: 28.sp,
                                    fontFamily: 'Amiri-Quran',
                                    color: AppStyle.primaryGreen,
                                    fontWeight: FontWeight.bold),
                              ),
                              Text(
                                cubit.quranEntity!.data.listOfSurahs[index]
                                    .englishName,
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  color: AppStyle.textLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    separatorBuilder: (context, index) => Divider(
                      thickness: 2.0,
                      indent: 16.w,
                      endIndent: 16.w,
                    ),
                    itemCount: cubit.quranEntity!.data.listOfSurahs.length,
                  )
                : const Center(
                    child: CircularProgressIndicator(),
                  ),
          ),
        );
      },
      listener: (context, state) {},
    );
  }
}
