import 'package:azkroh_app/features/core/appstyle.dart';
import 'package:azkroh_app/features/core/cacheHelper.dart';
import 'package:azkroh_app/features/core/methods/hive_helper.dart';
import 'package:azkroh_app/features/core/notification_service.dart';
import 'package:azkroh_app/features/core/services/global_location_service.dart';
import 'package:azkroh_app/features/presentation/cubit/bloc_observer.dart';
import 'package:azkroh_app/features/presentation/cubit/cubit.dart';
import 'package:azkroh_app/features/presentation/screens/professional_splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize date formatting for Arabic
  await initializeDateFormatting('ar', null);

  // Initialize notification service
  await NotificationService().initialize();

  await CacheHelper.init();

  // Initialize global location service (will also init timezone)
  await GlobalLocationService().initialize();

  final document = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(document.path);

  //Hive adapter
  HiveHelper.registerHiveMethod();

  Bloc.observer = MyBlocObserver();

  //Hive Open Boxes
  await Hive.openBox('box_store');
  await Hive.openBox('fav');
  await Hive.openBox('quran_box');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(393, 852), // iPhone 14 Pro design size
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (context) => AppCubit()..getPrayerTimeFromApi(),
            )
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'أذكروه - تطبيق الأذكار والقرآن الكريم',
            locale: const Locale('ar'),
            theme: AppStyle.islamicTheme,
            home: const ProfessionalSplashScreen(),
          ),
        );
      },
    );
  }
}
