import 'package:azkroh_app/features/core/appstyle.dart';
import 'package:azkroh_app/features/core/methods/methods.dart';
import 'package:azkroh_app/features/presentation/cubit/cubit.dart';
import 'package:azkroh_app/features/presentation/cubit/states.dart';
import 'package:azkroh_app/features/presentation/screens/all_screen/surah_screen.dart';
import 'package:flutter/material.dart';

import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
              centerTitle: true,
              title: Text('القرءان الكريم ',
                  style: AppStyle.regularTextStyle
                      .copyWith(fontSize: 25.0, color: Colors.white)),
            ),
            body: cubit.quranEntity != null
                ? ListView.separated(
                    addAutomaticKeepAlives: true,
                    key: const PageStorageKey<String>('page'),
                    itemBuilder: (context, index) {
                      return ListTile(
                        onTap: () => navigateTo(
                            context,
                            SurahScreen(
                              itemCount: cubit.quranEntity!.data
                                  .listOfSurahs[index].listOfAyahEntity.length,
                              title: cubit
                                  .quranEntity!.data.listOfSurahs[index].name,
                              list: cubit.quranEntity!.data.listOfSurahs[index]
                                  .listOfAyahEntity,
                            )),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              cubit.quranEntity!.data.listOfSurahs[index].name,
                              style: AppStyle.regularTextStyle.copyWith(
                                  fontSize: 30.0, fontFamily: 'Amiri-Quran'),
                            ),
                            Text(
                              cubit.quranEntity!.data.listOfSurahs[index]
                                  .englishName,
                              style: AppStyle.regularTextStyle.copyWith(
                                fontSize: 20.0,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    separatorBuilder: (context, index) => const Divider(
                      thickness: 2.0,
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
