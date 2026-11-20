import 'package:adhan/adhan.dart';
import 'package:azkroh_app/features/core/doaa_model.dart';
import 'package:azkroh_app/features/core/notification_service.dart';
import 'package:azkroh_app/features/core/prayer_notification_scheduler.dart';
import 'package:azkroh_app/features/core/dhikr_notification_scheduler.dart';
import 'package:azkroh_app/features/core/services/global_location_service.dart';
import 'package:azkroh_app/features/core/services/prayer_times_service.dart';
import 'package:azkroh_app/features/data/models/azan_data_model.dart';
import 'package:azkroh_app/features/data/datasource/remota_data_source/quran_remote_data.dart';
import 'package:azkroh_app/features/data/repo/quran_repo_impl.dart';
import 'package:azkroh_app/features/domain/entity/azan_entity.dart';
import 'package:azkroh_app/features/domain/entity/quran_entity.dart';
import 'package:azkroh_app/features/domain/repo/quran_base_repo.dart';
import 'package:azkroh_app/features/domain/usecase/get_quran_data_use_case.dart';
import 'package:azkroh_app/features/presentation/cubit/states.dart';
import 'package:azkroh_app/features/presentation/screens/all_screen/enhanced_hijri_screen.dart';
import 'package:azkroh_app/features/presentation/screens/hadith/hadith_screen.dart';
import 'package:azkroh_app/features/presentation/screens/all_screen/paryer_time_screen.dart';
import 'package:azkroh_app/features/presentation/screens/all_screen/qibla_screen.dart';
import 'package:azkroh_app/features/presentation/screens/all_screen/radio_screen.dart';
import 'package:azkroh_app/features/presentation/screens/all_screen/sebha.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/methods/get_location.dart';
import '../screens/quran_screen_locally/enhanced_quran_screen.dart';

class AppCubit extends Cubit<Appstates> {
  AppCubit() : super(AppInitState());

  static BlocProvider get(BuildContext context) => BlocProvider.of(context);

  List<Map<String, dynamic>> azkarMap = [
    {
      'image': 'assets/images/morning.jpg',
      'title': 'أذكار الصباح',
      'zekr_contetnt': morningZeker,
    },
    {
      'image': 'assets/images/evening.jpg',
      'title': 'أذكار المساء',
      'zekr_contetnt': eveningAzkar,
    },
    {
      'image': 'assets/images/prayer.jpg',
      'title': 'أذكار الصلاة',
      'zekr_contetnt': prayerZeker,
    },
    {
      'image': 'assets/images/dead.jpg',
      'title': 'أذكار المتوفى',
      'zekr_contetnt': deadPray,
    },
    {
      'image': 'assets/images/roqya.jpg',
      'title': ' الرقية الشرعية',
      'zekr_contetnt': roqya,
    },

    // 'roqya': roqya,
  ];

  azkarCountIncremeantMethod(List<DoaaModel> list, int index) {
    if (list[index].repeatTime != 0) {
      list[index].repeatTime--;
      emit(AzkarCountState());
    } else {
      return null;
    }
  }

  int sebhaCount = 0;

  List<Widget> screens = [
    const EnhancedQuranScreen(),
    Sebha(),
    const PrayerScreen(),
    const RadioScreen(),
    const QibalScreen(),
    const EnhancedHijriScreen(),
    const HadithScreen(),
  ];

  void sebhaIncrement() async {
    try {
      sebhaCount++;
      emit(AppSuccessState());
    } catch (error) {
      debugPrint(error.toString());
      emit(AppErrorState());
    }
  }

  void sebhaDecrement() async {
    try {
      if (sebhaCount > 0) {
        sebhaCount--;
        emit(AppSuccessState());
      }
    } catch (error) {
      debugPrint(error.toString());
      emit(AppErrorState());
    }
  }

  List<String> sebhaList = [
    'سبحان الله وبحمده',
    'استغفر الله',
    'اللهم صل وسلم وبارك علي نبينا محمد ',
    'لا اله الا الله',
  ];

  String sebhaInitValue = 'سبحان الله وبحمده';

  void sebhaDropDownValue(String? value) {
    sebhaInitValue = value!;
    resetSebha();
    emit(AppSuccessState());
  }

  void resetSebha() async {
    try {
      sebhaCount = 0;
      emit(AppSuccessState());
    } catch (error) {
      debugPrint(error.toString());
      emit(AppErrorState());
    }
  }

  QuranEntity? quranEntity;
  List<AyahEntity>? ayahList;

  getQuranDataTest() {
    try {
      final QuranRemotaData quranRemotaData = QuranRemotaData();
      final QuranBaseRepo quranBaseRepo =
          QuranRepoImplementaion(quranRemotaData: quranRemotaData);
      final GetQuranDataUseCase getQuranDataUseCase =
          GetQuranDataUseCase(quranBaseRepo: quranBaseRepo);
      getQuranDataUseCase.call().then((value) {
        quranEntity = value;

        emit(QuranDataFromApiState());
      });
    } catch (e) {
      debugPrint(e.toString());
      emit(QuranGettingDataError());
    }
  }

  // getTimePrayers method
  String? locationError;
  PrayerTimes? prayerTimes;

  getTimePrayersMethod() async {
    emit(GetPrayerTimeLoadingState());
    final params = CalculationMethod.egyptian.getParameters();
    params.madhab = Madhab.shafi;

    LocationHelper.getLocationMethod().then((value) {
      if (value != null) {
        prayerTimes = PrayerTimes.today(
          Coordinates(value.latitude, value.longitude),
          params,
        );
        debugPrint(DateFormat.jm().format(prayerTimes!.fajr));
        debugPrint(DateFormat.jm().format(prayerTimes!.dhuhr));
        debugPrint(DateFormat.jm().format(prayerTimes!.asr));
        debugPrint(DateFormat.jm().format(prayerTimes!.maghrib));
        debugPrint(DateFormat.jm().format(prayerTimes!.isha));

        emit(GetPrayersTimeState());
      } else {
        locationError = 'No pryer Time has been came yet ';
        emit(GetPrayerTimeErrorState());
      }
    });
  }

  AzanEntity? azanEntityData;
  List<String> prayerTimeList = [];
  final PrayerNotificationScheduler _prayerScheduler =
      PrayerNotificationScheduler();
  final DhikrNotificationScheduler _dhikrScheduler =
      DhikrNotificationScheduler();
  final GlobalLocationService _locationService = GlobalLocationService();

  /// Loads today's prayer times. Times are calculated on the device for the
  /// current date (works offline and follows DST changes), then every
  /// upcoming Adhan notification is rescheduled.
  getPrayerTimeFromApi() async {
    try {
      emit(GetPrayerTimeLoadingState());

      await _locationService.initialize();

      double? lat = _locationService.currentPosition?.latitude;
      double? lon = _locationService.currentPosition?.longitude;
      if (lat == null || lon == null) {
        final position = await LocationHelper.getLocationMethod();
        lat = position?.latitude;
        lon = position?.longitude;
      }
      if (lat == null || lon == null) {
        emit(GetPrayerTimeErrorState());
        return;
      }

      final service = PrayerTimesService();
      final now = DateTime.now();
      final t = await service.timesFor(lat, lon, now);
      final tomorrow = await service.timesFor(
          lat, lon, DateTime(now.year, now.month, now.day + 1));

      String f(DateTime d) => PrayerTimesService.hhmm(d.toLocal());
      final maghrib = t.maghrib.toLocal();
      final nextFajr = tomorrow.fajr.toLocal();
      final night = nextFajr.difference(maghrib);

      azanEntityData = AzanModel(
        code: 200,
        status: 'OK',
        data: DataModel(
          timings: TimingModel(
            fajr: f(t.fajr),
            sunrise: f(t.sunrise),
            dhuhr: f(t.dhuhr),
            asr: f(t.asr),
            sunset: f(t.maghrib),
            maghrib: f(t.maghrib),
            isha: f(t.isha),
            imsak: f(t.fajr.subtract(const Duration(minutes: 10))),
            midnight: f(maghrib.add(night ~/ 2)),
            firstthird: f(maghrib.add(night ~/ 3)),
            lastthird: f(maghrib.add(night * 2 ~/ 3)),
          ),
        ),
      );

      emit(GetPrayersTimeState());

      // Reschedule notifications in the background.
      _rescheduleNotifications();
    } catch (e) {
      debugPrint(e.toString());
      emit(GetPrayerTimeErrorState());
    }
  }

  Future<void> _rescheduleNotifications() async {
    try {
      await _prayerScheduler.scheduleUpcoming();
      await _dhikrScheduler.initializeAllDhikrReminders();
      await NotificationService().logPendingNotifications();
    } catch (e) {
      debugPrint('❌ خطأ في جدولة الإشعارات: $e');
    }
  }

  // Adding DoaaModel to Hive Database and toggle the favorite Button.

  List<DoaaModel> listoFromShared = [];
  List<bool> favList = [];

  addingDoaaModelToHiveDbAndToggleFavoriteBtn(
      List<DoaaModel> list, int index) async {
    list[index].isFavorite = !list[index].isFavorite!;
    if (list[index].isFavorite!) {
      Hive.box('box_store').add(list[index]);

      emit(ToggleFavoriteButtonAddState(list[index].isFavorite!));
    } else {
      Hive.box('box_store').deleteAt(index);

      emit(ToggleFavoriteButtonAddState(list[index].isFavorite!));
    }
  }

  bool isQuranFavoriteClicked = false;

  Future<void> addQuranModelToQuranHiveBox(List<AyahEntity> list, index) async {
    isQuranFavoriteClicked = true;

    if (isQuranFavoriteClicked) {
      Hive.box('quran_box')
          .add(list[index])
          .then((value) => isQuranFavoriteClicked = false);
      emit(QuranFavoruiteBtnState(isQuranFavoriteClicked));
    } else {
      debugPrint('Is Existed ');
      emit(QuranFavoruiteBtnState(isQuranFavoriteClicked));
    }
  }

  Future<void> shareMethod(shareText) async {
    try {
      await Share.share(shareText);
      emit(ShareTextState());
    } catch (e) {
      throw e.toString();
    }
  }

  // url launcer method --->
  launchTo() async {
    await launchUrl(Uri.parse(
        'mailto:islamsalemdev@gmail.com?subject=<subject>&body=<body>'));
    emit(UrlLauncherState());
  }
}
