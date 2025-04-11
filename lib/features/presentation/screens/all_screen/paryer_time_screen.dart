import 'package:azkroh_app/features/core/appstyle.dart';
import 'package:azkroh_app/features/presentation/cubit/cubit.dart';
import 'package:azkroh_app/features/presentation/cubit/states.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

List<String> prayerName = [
  'الفجر',
  'الشروق',
  'الظهر',
  'العصر',
  'المغرب ',
  'العشاء',
];

class PrayerScreen extends StatelessWidget {
  const PrayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'مواقيت الصلاة',
            style: AppStyle.regularTextStyle.copyWith(fontSize: 25.0),
          ),
          backgroundColor: Colors.blueGrey,
          elevation: 0.0,
        ),
        body: BlocBuilder<AppCubit, Appstates>(
          bloc: AppCubit()..getPrayerTimeFromApi(),
          builder: (context, state) {
            if (state is GetPrayerTimeLoadingState) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is GetPrayersTimeState) {
               return Container(
                width: double.infinity,
                height: MediaQuery.of(context).size.height * .8,
                margin: const EdgeInsets.all(15.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25.0),
                  color: Colors.blueGrey,
                ),
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.asset(
                          'assets/images/pray-day-islam-svgrepo-com.svg',
                          height: 100.0,
                        ),
                        CustomListTile(
                          prayTime: state.azanEntity.data.timings.fajr,
                          prayerTextName: 'الفجر ',
                        ),
                        CustomListTile(
                          prayTime: state.azanEntity.data.timings.sunrise,
                          prayerTextName: 'الشروق',
                        ),
                        CustomListTile(
                          prayTime: state.azanEntity.data.timings.dhuhr,
                          prayerTextName: 'الظهر',
                        ),
                        CustomListTile(
                          prayTime: state.azanEntity.data.timings.asr,
                          prayerTextName: 'العصر',
                        ),
                        CustomListTile(
                          prayTime: state.azanEntity.data.timings.maghrib,
                          prayerTextName: 'المغرب',
                        ),
                        CustomListTile(
                          prayTime: state.azanEntity.data.timings.isha,
                          prayerTextName: 'العشاء',
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            if (state is GetPrayerTimeErrorState) {
              return Center(
                child: Text('Error in fetching data '),
              );
            }
            return const Center(child: Text('No Data'));
          },
        ),
      ),
    );
  }
}

class CustomListTile extends StatelessWidget {
  const CustomListTile({
    Key? key,
    required this.prayerTextName,
    required this.prayTime,
  }) : super(key: key);

  final String prayerTextName;
  final String prayTime;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Text(
            prayerTextName,
            style: AppStyle.regularTextStyle.copyWith(fontSize: 20.0),
          ),
          Text(
            prayTime,
            style: AppStyle.regularTextStyle.copyWith(fontSize: 20.0),
          ),
        ],
      ),
    );
  }
}
