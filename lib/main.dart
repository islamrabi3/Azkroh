import 'package:admob_flutter/admob_flutter.dart';
import 'package:azkroh_app/features/core/appstyle.dart';
import 'package:azkroh_app/features/core/cacheHelper.dart';
import 'package:azkroh_app/features/core/methods/get_location.dart';
import 'package:azkroh_app/features/presentation/cubit/bloc_observer.dart';
import 'package:azkroh_app/features/presentation/cubit/cubit.dart';
import 'package:azkroh_app/features/presentation/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:path_provider/path_provider.dart';

import 'features/core/doaa_model.dart';
import 'features/domain/entity/quran_entity.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Push notification

  // LocalNotificationHelper.scheduleNotification();

  await CacheHelper.init();
  await LocationHelper.getLocationMethod();
  final document = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(document.path);

  //Hive adapter
  Hive.registerAdapter(DoaaModelAdapter());
  Hive.registerAdapter(QuranEntityAdapter());
  Hive.registerAdapter(QuranDataEntityAdapter());
  Hive.registerAdapter(SuraEntityAdapter());
  Hive.registerAdapter(AyahEntityAdapter());

  // adMob initializatoin

  Admob.initialize();
  Bloc.observer = MyBlocObserver();
  runApp(const MyApp());
  //Hive Open Boxes

  await Hive.openBox('box_store');
  await Hive.openBox('fav');
  await Hive.openBox('quran_box');
  //
  //  print('${Hive.box('box_store').getAt(0)}');
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => AppCubit()
              ..getQuranDataTest()
              ..getPrayerTimeFromApi(),
          )
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Flutter Demo',
          theme: ThemeData(
            floatingActionButtonTheme: const FloatingActionButtonThemeData(
              backgroundColor: Colors.blueGrey,
            ),
            appBarTheme: AppBarTheme(
              centerTitle: true,
              titleTextStyle: AppStyle.regularTextStyle
                  .copyWith(color: Colors.white, fontSize: 25.0),
              elevation: 10.0,
              backgroundColor: Colors.blueGrey,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.0)),
            ),
            primarySwatch: Colors.blue,
          ),
          home: const SplashScreen(),
        ));
  }
}
