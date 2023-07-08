import 'package:azkroh_app/features/core/appstyle.dart';
import 'package:azkroh_app/features/core/doaa_model.dart';
import 'package:azkroh_app/features/domain/entity/quran_entity.dart';
import 'package:azkroh_app/features/presentation/cubit/cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
        var cubit = context.read<AppCubit>();

        return Directionality(
          textDirection: TextDirection.rtl,
          child: DefaultTabController(
            length: 2,
            animationDuration: const Duration(seconds: 1),
            child: Scaffold(
              appBar: AppBar(
                title: const Text(
                  'المفضلة',
                ),
                bottom: TabBar(
                    indicatorColor: Colors.amber,
                    labelColor: Colors.white,
                    indicatorWeight: 5.0,
                    labelStyle: AppStyle.regularTextStyle,
                    unselectedLabelColor: Colors.yellow.shade300,
                    indicatorSize: TabBarIndicatorSize.label,
                    tabs: const [Text('الاّيات '), Text('الاذكار')]),
              ),
              body: TabBarView(children: [
                ValueListenableBuilder(
                  valueListenable: Hive.box<dynamic>('quran_box').listenable(),
                  builder: (context, value, child) => value.isNotEmpty
                      ? ListView.builder(
                          itemBuilder: (context, index) {
                            var getAyah = value.getAt(index) as AyahEntity;
                            return Dismissible(
                              background: const Icon(
                                Icons.delete,
                                color: Colors.red,
                                size: 40.0,
                              ),
                              key: UniqueKey(),
                              onDismissed: (direction) {
                                value.deleteAt(index);
                              },
                              child: SizedBox(
                                width: double.infinity,
                                child: Card(
                                  color: Colors.grey.shade300,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(15.0)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(15.0),
                                    child: Text(
                                      '${getAyah.ayahText} {${getAyah.ayahNumber}}',
                                      textAlign: TextAlign.center,
                                      style: AppStyle.regularTextStyle,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                          itemCount: value.length,
                        )
                      : const Center(
                          child: Text(
                          'لايوجد اّيات في المفضلة ',
                          style: AppStyle.regularTextStyle,
                        )),
                ),
                ValueListenableBuilder(
                  valueListenable: Hive.box<dynamic>('box_store').listenable(),
                  builder: (context, value, child) => value.isNotEmpty
                      ? ListView.builder(
                          itemBuilder: (context, index) {
                            var getFav = value.getAt(index) as DoaaModel;
                            return Dismissible(
                              background: const Icon(
                                Icons.delete,
                                color: Colors.red,
                                size: 40.0,
                              ),
                              key: UniqueKey(),
                              onDismissed: (direction) {
                                value.deleteAt(index);
                              },
                              child: Card(
                                color: Colors.grey.shade300,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15.0)),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    children: [
                                      Text(
                                        '${getFav.content}',
                                        style: AppStyle.regularTextStyle,
                                      ),
                                      Text(
                                        '${getFav.desc}',
                                        style: AppStyle.regularTextStyle,
                                      ),
                                      Container(
                                        height: 30.0,
                                        // width: 20.0,
                                        decoration: BoxDecoration(
                                            color: Colors.blueGrey,
                                            borderRadius:
                                                BorderRadius.circular(15.0)),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceAround,
                                          children: [
                                            Text(getFav.repeatTime == 0
                                                ? AppString.doneRepeatTimeString
                                                : AppString.repeatTimeString),
                                            Text(': ${getFav.repeatTime}')
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
                      : const Center(
                          child: Text(
                          'لايوجد اذكار في المفضلة ',
                          style: AppStyle.regularTextStyle,
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
