import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:qcf_quran_plus/qcf_quran_plus.dart' as qcf;
import 'package:shared_preferences/shared_preferences.dart';

/// A supported UI language.
class AppLanguage {
  final String code;
  final String nativeName;
  final bool rtl;

  const AppLanguage(this.code, this.nativeName, {this.rtl = false});
}

/// App-wide language state. Arabic strings are the translation keys; every
/// other language lives in assets/l10n/<code>.json.
class AppLocale {
  AppLocale._();

  static const languages = <AppLanguage>[
    AppLanguage('ar', 'العربية', rtl: true),
    AppLanguage('en', 'English'),
    AppLanguage('fr', 'Français'),
    AppLanguage('es', 'Español'),
    AppLanguage('de', 'Deutsch'),
    AppLanguage('tr', 'Türkçe'),
    AppLanguage('ru', 'Русский'),
    AppLanguage('id', 'Bahasa Indonesia'),
    AppLanguage('ms', 'Bahasa Melayu'),
    AppLanguage('ur', 'اردو', rtl: true),
    AppLanguage('fa', 'فارسی', rtl: true),
    AppLanguage('zh', '中文'),
  ];

  static const _pref = 'app_language';

  /// Current language code; rebuilds MaterialApp when it changes.
  static final ValueNotifier<String> code = ValueNotifier('ar');

  static Map<String, String> _table = const {};
  static Map<String, String> _fallback = const {};

  static AppLanguage get current =>
      languages.firstWhere((l) => l.code == code.value,
          orElse: () => languages.first);

  static bool get isArabic => code.value == 'ar';
  static bool get isRtl => current.rtl;
  static TextDirection get direction =>
      isRtl ? TextDirection.rtl : TextDirection.ltr;

  static List<Locale> get supportedLocales =>
      languages.map((l) => Locale(l.code)).toList();

  /// Load the saved language (or the device language on first run).
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    var c = prefs.getString(_pref);
    if (c == null) {
      final device = ui.PlatformDispatcher.instance.locale.languageCode;
      c = languages.any((l) => l.code == device) ? device : 'en';
    }
    await _load(c);
  }

  static Future<void> set(String c) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pref, c);
    await _load(c);
  }

  static Future<void> _load(String c) async {
    _table = c == 'ar' ? const {} : await _read(c);
    _fallback = (c == 'ar' || c == 'en') ? const {} : await _read('en');
    HijriCalendar.setLocal(c == 'ar' ? 'ar' : 'en');
    code.value = c;
  }

  static Future<Map<String, String>> _read(String c) async {
    try {
      final raw = await rootBundle.loadString('assets/l10n/$c.json');
      return Map<String, String>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return const {};
    }
  }

  static String translate(String ar) {
    if (code.value == 'ar') return ar;
    return _table[ar] ?? _fallback[ar] ?? ar;
  }

  /// Digits in the script of the current language.
  static String digits(Object n) {
    final s = n.toString();
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    final List<String>? set = code.value == 'ar'
        ? arabic
        : (code.value == 'fa' || code.value == 'ur')
            ? persian
            : null;
    if (set == null) return s;
    return s.split('').map((ch) {
      final u = ch.codeUnitAt(0);
      return (u >= 48 && u <= 57) ? set[u - 48] : ch;
    }).join();
  }
}

/// Translate an Arabic UI string to the current language.
String tr(String ar) => AppLocale.translate(ar);

/// Surah name in the UI language (Arabic script for ar/ur/fa).
String surahName(int n) =>
    AppLocale.isRtl ? qcf.getSurahNameArabic(n) : qcf.getSurahName(n);

/// Locale code for intl DateFormat.
String get dateLocale => AppLocale.code.value;

/// Prayer-time formatting in the UI language: 12h with ص/م (Arabic), AM/PM
/// (English/Urdu/Persian/Chinese), 24h elsewhere.
String formatTime(DateTime t) {
  final c = AppLocale.code.value;
  if (c == 'ar' || c == 'en' || c == 'ur' || c == 'fa' || c == 'zh') {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final hm = '$h:${t.minute.toString().padLeft(2, '0')}';
    return '${AppLocale.digits(hm)} ${tr(t.hour < 12 ? 'ص' : 'م')}';
  }
  return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
