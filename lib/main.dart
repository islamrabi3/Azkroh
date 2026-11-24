import 'package:azkroh_app/features/core/services/remote_content_service.dart';
import 'package:azkroh_app/features/core/services/backend.dart';
import 'package:azkroh_app/features/core/widgets/now_playing_bubble.dart';
import 'package:azkroh_app/features/core/notification_router.dart';
import 'package:azkroh_app/features/core/appstyle.dart';
import 'package:azkroh_app/features/core/cacheHelper.dart';
import 'package:azkroh_app/features/core/methods/hive_helper.dart';
import 'package:azkroh_app/features/core/notification_service.dart';
import 'package:azkroh_app/features/core/services/global_location_service.dart';
import 'package:azkroh_app/features/presentation/cubit/bloc_observer.dart';
import 'package:azkroh_app/features/presentation/cubit/cubit.dart';
import 'package:azkroh_app/features/presentation/screens/professional_splash_screen.dart';
import 'package:azkroh_app/l10n/app_locale.dart';
import 'package:azkroh_app/features/core/services/media_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hijri/hijri_calendar.dart';
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
  await initializeDateFormatting();
  HijriCalendar.setLocal('ar');
  await AppLocale.init();

  // Initialize notification service
  await NotificationService().initialize();
  // App launched by tapping a notification: open its screen after the splash.
  NotificationRouter.handle(await NotificationService().launchPayload());

  await CacheHelper.init();

  // Initialize global location service (will also init timezone)
  // Location is initialised by the splash screen (after the UI is visible).

  final document = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(document.path);

  //Hive adapter
  HiveHelper.registerHiveMethod();

  Bloc.observer = MyBlocObserver();

  //Hive Open Boxes
  await Hive.openBox('box_store');
  await Hive.openBox('fav');
  await Hive.openBox('quran_box');

  // Lock-screen / notification media controls for radio and Listen.
  await MediaHandler.init();

  // Backend (quiz game, dashboard content). Offline-safe.
  await Backend.init();
  RemoteContentService.instance.load();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final AppCubit _cubit = AppCubit()..getPrayerTimeFromApi();
  DateTime _lastRefresh = DateTime.now();
  Duration _lastOffset = DateTime.now().timeZoneOffset;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cubit.close();
    super.dispose();
  }

  /// A link opened while the app is running.
  @override
  Future<bool> didPushRouteInformation(RouteInformation info) async =>
      _handleLink(info.uri.toString());

  static bool _handleLink(String route) {
    final uri = Uri.tryParse(route);
    if (uri == null || !uri.path.endsWith('/book')) return false;
    NotificationRouter.handle('book:${uri.query}');
    return true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state != AppLifecycleState.resumed) return;
    final now = DateTime.now();
    final dayChanged = now.day != _lastRefresh.day ||
        now.difference(_lastRefresh).inHours >= 6;
    // Device clock / time zone / DST may have changed while in background.
    await GlobalLocationService().refreshTimezone();
    if (dayChanged || _lastOffset != now.timeZoneOffset) {
      _lastRefresh = now;
      _lastOffset = now.timeZoneOffset;
      // The user may have travelled: refresh GPS (no-op for a manual city).
      await GlobalLocationService().getCurrentLocation();
      _cubit.getPrayerTimeFromApi();
    }
  }

  /// Tablets / foldables / desktop: render the phone-designed UI in a centred
  /// column so every screen keeps its proportions.
  static const double _maxContentWidth = 600;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQueryData.fromView(View.of(context));
    final app = _buildApp();
    if (mq.size.width <= _maxContentWidth + 120) return app;
    return ColoredBox(
      color: const Color(0xFF0B3D33),
      child: Center(
        child: SizedBox(
          width: _maxContentWidth,
          child: MediaQuery(
            data: mq.copyWith(
                size: Size(_maxContentWidth, mq.size.height)),
            child: app,
          ),
        ),
      ),
    );
  }

  Widget _buildApp() {
    return ScreenUtilInit(
      designSize: const Size(393, 852), // iPhone 14 Pro design size
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        // Scale against the (possibly constrained) width this app renders at,
        // not the full window (ScreenUtilInit reads the raw window size).
        ScreenUtil.configure(
          data: MediaQuery.of(context),
          designSize: const Size(393, 852),
          minTextAdapt: true,
          splitScreenMode: true,
        );
        return BlocProvider.value(
          value: _cubit,
          child: ValueListenableBuilder<String>(
            valueListenable: AppLocale.code,
            builder: (context, code, _) => MaterialApp(
              navigatorKey: NotificationRouter.navigatorKey,
              debugShowCheckedModeBanner: false,
              title: 'أذكروه',
              locale: Locale(code),
              supportedLocales: AppLocale.supportedLocales,
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              theme: AppStyle.islamicTheme,
              // The first screen comes from onGenerateInitialRoutes (no
              // `home`): a shared book link (azkroh://open/book?id=…)
              // starts the app normally and opens the book once home is
              // ready.
              // A shared book link (azkroh://open/book?id=…) opening the app:
              // start normally and open the book once home is ready.
              onGenerateRoute: (settings) => settings.name == '/'
                  ? MaterialPageRoute(
                      builder: (_) => const ProfessionalSplashScreen())
                  : null,
              onGenerateInitialRoutes: (initial) {
                _handleLink(initial);
                return [
                  MaterialPageRoute(
                      builder: (_) => const ProfessionalSplashScreen()),
                ];
              },
              // Light status bar by default (most screens have dark headers);
              // screens like the Mushaf override it with their own region.
              builder: (context, child) =>
                  AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle.light
                    .copyWith(statusBarColor: Colors.transparent),
                child: Stack(
                  children: [
                    child!,
                    // App-wide "now playing" bubble (radio / recitations).
                    const NowPlayingBubble(),
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
