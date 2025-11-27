import 'package:azkroh_app/features/core/appstyle.dart';
import 'package:azkroh_app/features/core/doaa_model.dart';
import 'package:azkroh_app/features/domain/entity/quran_entity.dart';
import 'package:azkroh_app/features/presentation/cubit/cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive_flutter/adapters.dart';

import '../../../core/app_strings.dart';
import '../../cubit/states.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({Key? key, required this.fromSharedList})
      : super(key: key);

  final List<DoaaModel> fromSharedList;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AppCubit, Appstates>(
      builder: (context, state) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: DefaultTabController(
            length: 2,
            animationDuration: const Duration(seconds: 1),
            child: Scaffold(
              appBar: AppBar(
                backgroundColor: AppStyle.primaryGreen,
                centerTitle: true,
                iconTheme: const IconThemeData(color: Colors.white),
                title: Text(
                  'المفضلة',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                bottom: TabBar(
                    indicatorColor: AppStyle.goldColor,
                    labelColor: AppStyle.pureWhite,
                    indicatorWeight: 5.0,
                    labelStyle: TextStyle(fontSize: 18.sp, fontFamily: 'Amiri'),
                    unselectedLabelColor: AppStyle.lightGreen,
                    indicatorSize: TabBarIndicatorSize.label,
                    tabs: const [Text('الاّيات '), Text('الاذكار')]),
              ),
              body: TabBarView(children: [
                ValueListenableBuilder(
                  valueListenable: Hive.box<dynamic>('quran_box').listenable(),
                  builder: (context, value, child) => value.isNotEmpty
                      ? ListView.builder(
                          padding: EdgeInsets.symmetric(vertical: 8.h),
                          itemBuilder: (context, index) {
                            var getAyah = value.getAt(index) as AyahEntity;
                            return Dismissible(
                              background: Icon(
                                Icons.delete,
                                color: Colors.red,
                                size: 40.sp,
                              ),
                              key: UniqueKey(),
                              onDismissed: (direction) {
                                value.deleteAt(index);
                              },
                              child: SizedBox(
                                width: double.infinity,
                                child: Card(
                                  margin: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                  color: Colors.grey.shade300,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(15.r)),
                                  child: Padding(
                                    padding: EdgeInsets.all(15.r),
                                    child: Text(
                                      '${getAyah.ayahText} {${getAyah.ayahNumber}}',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 18.sp,
                                        fontFamily: 'Amiri',
                                        color: AppStyle.textDark,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                          itemCount: value.length,
                        )
                      : Center(
                          child: Text(
                          'لايوجد اّيات في المفضلة ',
                          style: TextStyle(fontSize: 16.sp, fontFamily: 'Amiri'),
                        )),
                ),
                ValueListenableBuilder(
                  valueListenable: Hive.box<dynamic>('box_store').listenable(),
                  builder: (context, value, child) => value.isNotEmpty
                      ? ListView.builder(
                          padding: EdgeInsets.symmetric(vertical: 8.h),
                          itemBuilder: (context, index) {
                            var getFav = value.getAt(index) as DoaaModel;
                            return Dismissible(
                              background: Icon(
                                Icons.delete,
                                color: Colors.red,
                                size: 40.sp,
                              ),
                              key: UniqueKey(),
                              onDismissed: (direction) {
                                value.deleteAt(index);
                              },
                              child: Card(
                                margin: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                color: Colors.grey.shade300,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15.r)),
                                child: Padding(
                                  padding: EdgeInsets.all(8.r),
                                  child: Column(
                                    children: [
                                      Text(
                                        '${getFav.content}',
                                        style: TextStyle(fontSize: 18.sp, fontFamily: 'Amiri'),
                                      ),
                                      SizedBox(height: 8.h),
                                      Text(
                                        '${getFav.desc}',
                                        style: TextStyle(fontSize: 14.sp, fontFamily: 'Amiri', color: AppStyle.textLight),
                                      ),
                                      SizedBox(height: 8.h),
                                      Container(
                                        height: 30.h,
                                        decoration: BoxDecoration(
                                            color: Colors.blueGrey,
                                            borderRadius:
                                                BorderRadius.circular(15.r)),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceAround,
                                          children: [
                                            Text(
                                              getFav.repeatTime == 0
                                                ? AppString.doneRepeatTimeString
                                                : AppString.repeatTimeString,
                                              style: TextStyle(fontSize: 12.sp, color: Colors.white),
                                            ),
                                            Text(
                                              ': ${getFav.repeatTime}',
                                              style: TextStyle(fontSize: 12.sp, color: Colors.white),
                                            )
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                          itemCount: value.length,
                        )
                      : Center(
                          child: Text(
                          'لايوجد اذكار في المفضلة ',
                          style: TextStyle(fontSize: 16.sp, fontFamily: 'Amiri'),
                        )),
                ),
              ]),
            ),
          ),
        );
      },
      listener: (context, state) {},
    );
  }
}
