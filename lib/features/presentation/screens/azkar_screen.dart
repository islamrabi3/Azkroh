import 'package:azkroh_app/features/core/appstyle.dart';
import 'package:azkroh_app/features/core/doaa_model.dart';
import 'package:azkroh_app/features/presentation/cubit/cubit.dart';
import 'package:azkroh_app/features/presentation/cubit/states.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/widgets/custom_azkar_card_widget.dart';

class AzkarScreen extends StatelessWidget {
  const AzkarScreen(
      {super.key, required this.pageTitle, required this.listOfDoaaModel});

  final String pageTitle;
  final List<DoaaModel> listOfDoaaModel;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AppCubit, Appstates>(
      builder: (context, state) {
        AppCubit cubit = context.read<AppCubit>();
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            appBar: AppBar(
              title: Text(
                pageTitle,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: AppStyle.primaryGreen,
              centerTitle: true,
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            body: ListView.builder(
              padding: EdgeInsets.symmetric(vertical: 8.h),
              itemBuilder: (context, index) => CustomAzkarCardWidget(
                  listOfDoaaModel: listOfDoaaModel, cubit: cubit, index: index),
              itemCount: listOfDoaaModel.length,
            ),
          ),
        );
      },
      listener: (context, state) {
        if (state is ToggleFavoriteButtonAddState) {
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
            final snackBar = SnackBar(
              content: Text(
                'تم الحذف بنجاح',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14.sp),
              ),
              backgroundColor: Colors.red,
              elevation: 10.0,
            );
            ScaffoldMessenger.of(context).showSnackBar(snackBar);
          }
        }
      },
    );
  }
}
