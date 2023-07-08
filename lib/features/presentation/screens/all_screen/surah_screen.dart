import 'package:azkroh_app/features/core/appstyle.dart';
import 'package:azkroh_app/features/presentation/cubit/cubit.dart';
import 'package:azkroh_app/features/presentation/cubit/states.dart';
import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

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
                  style: AppStyle.regularTextStyle
                      .copyWith(color: Colors.white, fontSize: 25.0),
                ),
                centerTitle: true,
              ),
              body: ListView.builder(
                addAutomaticKeepAlives: true,
                key: const PageStorageKey<String>('page'),
                itemBuilder: (context, index) {
                  return InkWell(
                    onLongPress: () {
                      var dialog = Dialog(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
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
                                  icon: const Icon(Icons.share)),
                              IconButton(
                                  onPressed: () {
                                    // list[index].isfavorite =
                                    //     list[index].isfavorite;

                                    cubit
                                        .addQuranModelToQuranHiveBox(
                                            list, index)
                                        .then(
                                            (value) => Navigator.pop(context));
                                  },
                                  icon: const Icon(
                                    Icons.favorite,
                                    color: Colors.blueGrey,
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
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          '${list[index].ayahText} {${list[index].numberInSurah}}',
                          style: AppStyle.regularTextStyle.copyWith(
                              fontSize: 25.0, fontFamily: 'Amiri-Quran'),
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
                const snackBar = SnackBar(
                  content: Text(
                    'تمت الاضافة بنجاح',
                    textAlign: TextAlign.center,
                  ),
                  backgroundColor: Colors.green,
                  elevation: 10.0,
                );
                ScaffoldMessenger.of(context).showSnackBar(snackBar);
              } else {
                // const snackBar = SnackBar(
                //   content: Text(
                //     'تم الحذف',
                //     textAlign: TextAlign.center,
                //   ),
                //   backgroundColor: Colors.red,
                //   elevation: 10.0,
                // );
                // ScaffoldMessenger.of(context).showSnackBar(snackBar);
                return;
              }
            }
          },
        ));
  }
}
