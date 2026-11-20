import 'package:adhan/adhan.dart';
import 'package:azkroh_app/features/core/services/global_location_service.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One prayer occurrence on a specific day (local device time).
class PrayerSlot {
  final String key; // fajr, sunrise, dhuhr, asr, maghrib, isha
  final String arabicName;
  final DateTime time;

  const PrayerSlot(this.key, this.arabicName, this.time);
}

/// Offline prayer time calculator.
///
/// Times are calculated on the device for any date with the `adhan` package,
/// so they follow the real calendar day (and DST changes such as Egypt's
/// summer time) instead of re-using one day's times forever.
class PrayerTimesService {
  static final PrayerTimesService _instance = PrayerTimesService._internal();
  factory PrayerTimesService() => _instance;
  PrayerTimesService._internal();

  static const String prefMethod = 'prayer_calc_method';
  static const String prefMadhab = 'prayer_madhab';
  static const String prefAdjustPrefix = 'prayer_adjust_';

  /// Methods shown in settings: key -> Arabic label.
  static const Map<String, String> methodLabels = {
    'auto': 'تلقائي حسب الدولة',
    'egyptian': 'الهيئة المصرية العامة للمساحة',
    'umm_al_qura': 'أم القرى - مكة المكرمة',
    'muslim_world_league': 'رابطة العالم الإسلامي',
    'karachi': 'جامعة العلوم الإسلامية - كراتشي',
    'dubai': 'دبي / الخليج',
    'kuwait': 'الكويت',
    'qatar': 'قطر',
    'turkey': 'رئاسة الشؤون الدينية - تركيا',
    'north_america': 'أمريكا الشمالية (ISNA)',
    'singapore': 'سنغافورة',
    'tehran': 'طهران',
    'morocco': 'وزارة الأوقاف المغربية',
    'algeria': 'وزارة الشؤون الدينية الجزائرية',
    'tunisia': 'وزارة الشؤون الدينية التونسية',
    'jordan': 'وزارة الأوقاف الأردنية',
    'indonesia': 'وزارة الشؤون الدينية الإندونيسية',
    'france': 'اتحاد المنظمات الإسلامية في فرنسا',
    'russia': 'الإدارة الدينية لمسلمي روسيا',
  };

  /// Calculation method by IANA time zone (reliable country signal).
  static const Map<String, String> _tzMethod = {
    'Africa/Cairo': 'egyptian',
    'Africa/Khartoum': 'egyptian',
    'Africa/Tripoli': 'egyptian',
    'Asia/Damascus': 'egyptian',
    'Asia/Beirut': 'egyptian',
    'Asia/Gaza': 'egyptian',
    'Asia/Hebron': 'egyptian',
    'Asia/Jerusalem': 'egyptian',
    'Asia/Amman': 'jordan',
    'Asia/Baghdad': 'muslim_world_league',
    'Asia/Riyadh': 'umm_al_qura',
    'Asia/Aden': 'umm_al_qura',
    'Asia/Bahrain': 'umm_al_qura',
    'Asia/Dubai': 'dubai',
    'Asia/Muscat': 'dubai',
    'Asia/Kuwait': 'kuwait',
    'Asia/Qatar': 'qatar',
    'Europe/Istanbul': 'turkey',
    'Asia/Istanbul': 'turkey',
    'Asia/Tehran': 'tehran',
    'Asia/Karachi': 'karachi',
    'Asia/Kolkata': 'karachi',
    'Asia/Calcutta': 'karachi',
    'Asia/Dhaka': 'karachi',
    'Asia/Kabul': 'karachi',
    'Asia/Kuala_Lumpur': 'singapore',
    'Asia/Kuching': 'singapore',
    'Asia/Singapore': 'singapore',
    'Asia/Brunei': 'singapore',
    'Asia/Jakarta': 'indonesia',
    'Asia/Makassar': 'indonesia',
    'Asia/Pontianak': 'indonesia',
    'Asia/Jayapura': 'indonesia',
    'Africa/Casablanca': 'morocco',
    'Africa/El_Aaiun': 'morocco',
    'Africa/Algiers': 'algeria',
    'Africa/Tunis': 'tunisia',
    'Europe/Paris': 'france',
    'Europe/Moscow': 'russia',
    'Europe/Kazan': 'russia',
    'Europe/Volgograd': 'russia',
    'Europe/Samara': 'russia',
    'Asia/Yekaterinburg': 'russia',
    'Asia/Omsk': 'russia',
    'Asia/Novosibirsk': 'russia',
  };

  /// Regions that follow the Hanafi Asr by default.
  static const Set<String> _hanafiTz = {
    'Asia/Karachi', 'Asia/Kolkata', 'Asia/Calcutta', 'Asia/Dhaka', //
    'Asia/Kabul', 'Asia/Tashkent', 'Asia/Samarkand', 'Asia/Almaty',
    'Asia/Bishkek', 'Asia/Dushanbe', 'Asia/Ashgabat',
  };

  String? get _tz => GlobalLocationService().timezoneName;

  static const List<String> prayerKeys = [
    'fajr',
    'dhuhr',
    'asr',
    'maghrib',
    'isha',
  ];

  static const Map<String, String> arabicNames = {
    'fajr': 'الفجر',
    'sunrise': 'الشروق',
    'dhuhr': 'الظهر',
    'asr': 'العصر',
    'maghrib': 'المغرب',
    'isha': 'العشاء',
  };

  /// Picks a sensible default method from coordinates.
  String autoMethodFor(double lat, double lon) {
    final tz = _tz;
    if (tz != null) {
      final m = _tzMethod[tz];
      if (m != null) return m;
      if (tz.startsWith('America/') || tz.startsWith('Canada/') ||
          tz.startsWith('US/')) {
        return 'north_america';
      }
    }
    // Egypt (incl. Sinai) uses the Egyptian General Authority of Survey.
    if (lat >= 21.5 && lat <= 31.8 && lon >= 24.7 && lon <= 34.9) {
      return 'egyptian';
    }
    // Kuwait
    if (lat >= 28.5 && lat <= 30.1 && lon >= 46.5 && lon <= 48.5) {
      return 'kuwait';
    }
    // Qatar
    if (lat >= 24.4 && lat <= 26.2 && lon >= 50.7 && lon <= 51.7) {
      return 'qatar';
    }
    // UAE
    if (lat >= 22.6 && lat <= 26.1 && lon >= 51.5 && lon <= 56.4) {
      return 'dubai';
    }
    // Saudi Arabia, Yemen, Bahrain, Oman
    if (lat >= 12 && lat <= 32.2 && lon >= 34.9 && lon <= 60) {
      return 'umm_al_qura';
    }
    // Turkey
    if (lat >= 35.8 && lat <= 42.2 && lon >= 25.6 && lon <= 44.9) {
      return 'turkey';
    }
    // Iran
    if (lat >= 25 && lat <= 40 && lon >= 44 && lon <= 63.4) {
      return 'tehran';
    }
    // Pakistan, India, Bangladesh, Afghanistan
    if (lat >= 5 && lat <= 38 && lon >= 60 && lon <= 93) {
      return 'karachi';
    }
    // Malaysia, Singapore, Indonesia, Brunei
    if (lat >= -11 && lat <= 8 && lon >= 95 && lon <= 141) {
      return 'singapore';
    }
    // North America
    if (lat >= 15 && lat <= 72 && lon >= -170 && lon <= -50) {
      return 'north_america';
    }
    return 'muslim_world_league';
  }

  CalculationMethod _methodFromKey(String key) {
    switch (key) {
      case 'egyptian':
        return CalculationMethod.egyptian;
      case 'umm_al_qura':
        return CalculationMethod.umm_al_qura;
      case 'karachi':
        return CalculationMethod.karachi;
      case 'dubai':
        return CalculationMethod.dubai;
      case 'kuwait':
        return CalculationMethod.kuwait;
      case 'qatar':
        return CalculationMethod.qatar;
      case 'turkey':
        return CalculationMethod.turkey;
      case 'north_america':
        return CalculationMethod.north_america;
      case 'singapore':
        return CalculationMethod.singapore;
      case 'tehran':
        return CalculationMethod.tehran;
      default:
        return CalculationMethod.muslim_world_league;
    }
  }

  Future<String> getMethodKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(prefMethod) ?? 'auto';
  }

  Future<void> setMethodKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefMethod, key);
  }

  /// 'shafi' (الجمهور) or 'hanafi'.
  Future<String> getMadhab() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(prefMadhab) ?? 'auto';
  }

  Future<void> setMadhab(String madhab) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefMadhab, madhab);
  }

  /// Manual minute offset for a prayer key (can be negative).
  Future<int> getAdjustment(String prayerKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$prefAdjustPrefix$prayerKey') ?? 0;
  }

  Future<void> setAdjustment(String prayerKey, int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$prefAdjustPrefix$prayerKey', minutes);
  }

  CalculationParameters _custom(double fajr, double isha) =>
      CalculationParameters(fajrAngle: fajr, ishaAngle: isha);

  CalculationParameters _paramsFor(String key) {
    switch (key) {
      case 'morocco':
        return _custom(19, 17);
      case 'algeria':
        return _custom(18, 17);
      case 'tunisia':
        return _custom(18, 18);
      case 'jordan':
        return _custom(18, 18);
      case 'indonesia':
        return _custom(20, 18);
      case 'france':
        return _custom(12, 12);
      case 'russia':
        return _custom(16, 15);
      default:
        return _methodFromKey(key).getParameters();
    }
  }

  /// 'auto' resolves to Hanafi in South / Central Asia, otherwise Shafi.
  String resolveMadhab(String stored) {
    if (stored != 'auto') return stored;
    return _hanafiTz.contains(_tz) ? 'hanafi' : 'shafi';
  }

  Future<CalculationParameters> _buildParams(double lat, double lon,
      {DateTime? date}) async {
    final prefs = await SharedPreferences.getInstance();
    var key = prefs.getString(prefMethod) ?? 'auto';
    if (key == 'auto') key = autoMethodFor(lat, lon);

    final params = _paramsFor(key);
    params.madhab =
        resolveMadhab(prefs.getString(prefMadhab) ?? 'auto') == 'hanafi'
            ? Madhab.hanafi
            : Madhab.shafi;
    // Umm al-Qura: Isha is 30 minutes later during Ramadan.
    if (key == 'umm_al_qura' && date != null) {
      final h = HijriCalendar.fromDate(date);
      if (h.hMonth == 9) params.methodAdjustments.isha += 30;
    }
    // High latitudes (Europe, Canada, Russia…): keep Fajr/Isha sensible.
    if (lat.abs() > 48) {
      params.highLatitudeRule = HighLatitudeRule.seventh_of_the_night;
    }
    params.adjustments.fajr = prefs.getInt('${prefAdjustPrefix}fajr') ?? 0;
    params.adjustments.sunrise =
        prefs.getInt('${prefAdjustPrefix}sunrise') ?? 0;
    params.adjustments.dhuhr = prefs.getInt('${prefAdjustPrefix}dhuhr') ?? 0;
    params.adjustments.asr = prefs.getInt('${prefAdjustPrefix}asr') ?? 0;
    params.adjustments.maghrib =
        prefs.getInt('${prefAdjustPrefix}maghrib') ?? 0;
    params.adjustments.isha = prefs.getInt('${prefAdjustPrefix}isha') ?? 0;
    return params;
  }

  /// Prayer times for [date] in the device's local time zone.
  Future<PrayerTimes> timesFor(double lat, double lon, DateTime date) async {
    final params = await _buildParams(lat, lon, date: date);
    return PrayerTimes(
      Coordinates(lat, lon),
      DateComponents(date.year, date.month, date.day),
      params,
    );
  }

  /// The five daily prayers (+ sunrise when [includeSunrise]) for [date].
  Future<List<PrayerSlot>> slotsFor(
    double lat,
    double lon,
    DateTime date, {
    bool includeSunrise = false,
  }) async {
    final t = await timesFor(lat, lon, date);
    return [
      PrayerSlot('fajr', arabicNames['fajr']!, t.fajr.toLocal()),
      if (includeSunrise)
        PrayerSlot('sunrise', arabicNames['sunrise']!, t.sunrise.toLocal()),
      PrayerSlot('dhuhr', arabicNames['dhuhr']!, t.dhuhr.toLocal()),
      PrayerSlot('asr', arabicNames['asr']!, t.asr.toLocal()),
      PrayerSlot('maghrib', arabicNames['maghrib']!, t.maghrib.toLocal()),
      PrayerSlot('isha', arabicNames['isha']!, t.isha.toLocal()),
    ];
  }

  static String hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
