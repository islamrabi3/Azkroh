import 'package:azkroh_app/features/core/appstyle.dart';
import 'package:azkroh_app/features/presentation/cubit/states.dart';

import '../../cubit/cubit.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class Sebha extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AppCubit, Appstates>(
      listener: (context, state) {},
      builder: (context, state) {
        var cubit = context.read<AppCubit>();
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            appBar: AppBar(
              title: const Text(
                'السبحة الالكترونية',
              ),
            ),
            body: Center(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.blueGrey,
                          width: 2.0,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          '${cubit.sebhaCount}',
                          style: AppStyle.regularTextStyle,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 17.0,
                    ),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.blueGrey,
                          width: 2.0,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: DropdownButton<String>(
                          value: cubit.sebhaInitValue,
                          icon: const Icon(Icons.arrow_downward),
                          elevation: 16,
                          style: AppStyle.regularTextStyle,
                          alignment: Alignment.center,
                          onChanged: (String? value) {
                            cubit.sebhaDropDownValue(value);
                          },
                          items: cubit.sebhaList
                              .map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 17.0,
                    ),
                    MaterialButton(
                      shape: CircleBorder(),
                      height: 230,
                      animationDuration: Duration(seconds: 1),
                      minWidth: 100.0,
                      color: Colors.blueGrey,
                      onPressed: () {
                        cubit.sebhaIncrement();
                      },
                      child: Center(
                          child: Text(
                        '${cubit.sebhaInitValue}',
                        style: const TextStyle(
                          fontSize: 13.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )),
                    ),
                    SizedBox(
                      height: 17.0,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: Align(
                        alignment: Alignment.topRight,
                        child: MaterialButton(
                          shape: CircleBorder(),
                          height: 50.0,
                          animationDuration: Duration(seconds: 1),
                          minWidth: 50.0,
                          color: Colors.red,
                          onPressed: () {
                            cubit.resetSebha();
                          },
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
