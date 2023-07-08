import 'package:flutter/material.dart';

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
    // var fav = Hive.box('fav').get(index) as bool;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            // if(listOfDoaaModel![index].isFavorite!)
            Text(
              '${listOfDoaaModel![index].content}',
              style: AppStyle.regularTextStyle,
            ),
            Text(
              '${listOfDoaaModel![index].desc}',
              style:
                  AppStyle.regularTextStyle.copyWith(color: Colors.lightGreen),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: Container(
                    height: 30.0,
                    // width: 20.0,
                    decoration: BoxDecoration(
                        color: Colors.blueGrey,
                        borderRadius: BorderRadius.circular(15.0)),
                    child: InkWell(
                      onTap: () => cubit.azkarCountIncremeantMethod(
                          listOfDoaaModel!, index),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Text(listOfDoaaModel![index].repeatTime == 0
                              ? AppString.doneRepeatTimeString
                              : AppString.repeatTimeString),
                          Text(': ${listOfDoaaModel![index].repeatTime}')
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                    child: IconButton(
                        onPressed: () {
                          cubit.addingDoaaModelToHiveDbAndToggleFavoriteBtn(
                              listOfDoaaModel!, index);
                        },
                        icon: Icon(
                          Icons.favorite,
                          color: listOfDoaaModel![index].isFavorite!
                              ? Colors.yellow
                              : Colors.blueGrey,
                        )))
              ],
            ),
          ],
        ),
      ),
    );
  }
}
