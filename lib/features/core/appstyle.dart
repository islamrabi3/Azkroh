import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AppStyle {
  // Design tokens (emerald + gold)
  static const Color surface = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF6F4EE);
  static const Color border = Color(0xFFE6E1D3);
  static const double radius = 20;
  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: const Color(0xFF0B3D33).withOpacity(0.06),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];

  // Islamic Color Palette
  static const Color primaryGreen = Color(0xFF0F5C4A); // Islamic Green
  static const Color darkGreen = Color(0xFF0B3D33);
  static const Color lightGreen = Color(0xFF4FA38C);
  static const Color goldColor = Color(0xFFD4AF37); // Islamic Gold
  static const Color darkGold = Color(0xFFA8842C);
  static const Color creamColor = Color(0xFFFAF6EC);
  static const Color darkBrown = Color(0xFF3E2723);
  static const Color lightBrown = Color(0xFF8D6E63);
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color softGray = Color(0xFFF6F4EE);
  static const Color textDark = Color(0xFF1C2B27);
  static const Color textLight = Color(0xFF6B7772);

  // Gradient Colors
  static const LinearGradient islamicGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [primaryGreen, darkGreen],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [goldColor, darkGold],
  );

  static const LinearGradient creamGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [pureWhite, creamColor],
  );

  // Text Styles
  static const TextStyle regularTextStyle = TextStyle(
    color: textDark,
    fontFamily: 'Amiri',
    fontSize: 18.0,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle headingTextStyle = TextStyle(
    color: primaryGreen,
    fontFamily: 'Amiri',
    fontSize: 24.0,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle titleTextStyle = TextStyle(
    color: darkGreen,
    fontFamily: 'Amiri',
    fontSize: 20.0,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle quranTextStyle = TextStyle(
    color: textDark,
    fontFamily: 'Amiri-Quran',
    fontSize: 22.0,
    fontWeight: FontWeight.w400,
    height: 1.8,
  );

  static const TextStyle arabicTextStyle = TextStyle(
    color: textDark,
    fontFamily: 'Amiri',
    fontSize: 20.0,
    fontWeight: FontWeight.w500,
    height: 1.6,
  );

  static const TextStyle buttonTextStyle = TextStyle(
    color: pureWhite,
    fontFamily: 'Amiri',
    fontSize: 16.0,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle captionTextStyle = TextStyle(
    color: textLight,
    fontFamily: 'Amiri',
    fontSize: 14.0,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle goldTextStyle = TextStyle(
    color: goldColor,
    fontFamily: 'Amiri',
    fontSize: 18.0,
    fontWeight: FontWeight.bold,
  );

  // Card Styles
  static BoxDecoration islamicCardDecoration = BoxDecoration(
    color: pureWhite,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: primaryGreen.withOpacity(0.1),
        spreadRadius: 2,
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
    border: Border.all(
      color: lightGreen.withOpacity(0.3),
      width: 1,
    ),
  );

  static BoxDecoration gradientCardDecoration = BoxDecoration(
    gradient: creamGradient,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: primaryGreen.withOpacity(0.15),
        spreadRadius: 3,
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
    ],
  );

  // Button Styles
  static ButtonStyle islamicButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: primaryGreen,
    foregroundColor: pureWhite,
    elevation: 4,
    shadowColor: primaryGreen.withOpacity(0.3),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
  );

  static ButtonStyle goldButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: goldColor,
    foregroundColor: textDark,
    elevation: 4,
    shadowColor: goldColor.withOpacity(0.3),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
  );

  // App Bar Theme
  static AppBarTheme islamicAppBarTheme = AppBarTheme(
    backgroundColor: primaryGreen,
    foregroundColor: pureWhite,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: const TextStyle(
      color: pureWhite,
      fontFamily: 'AppSans',
      fontSize: 22.0,
      fontWeight: FontWeight.bold,
    ),
  );

  // Theme Data
  static ThemeData islamicTheme = ThemeData(
    primarySwatch: Colors.green,
    primaryColor: primaryGreen,
    scaffoldBackgroundColor: background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryGreen,
      primary: primaryGreen,
      secondary: goldColor,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: darkGreen,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      contentTextStyle: const TextStyle(fontFamily: 'AppSans', color: pureWhite),
    ),
    appBarTheme: islamicAppBarTheme,
    fontFamily: 'AppSans',
    // UI text uses the sans font; scripture/azkar widgets set Amiri explicitly.
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
          fontFamily: 'AppSans', fontWeight: FontWeight.w700, color: textDark),
      headlineMedium: TextStyle(
          fontFamily: 'AppSans', fontWeight: FontWeight.w700, color: textDark),
      titleLarge: TextStyle(
          fontFamily: 'AppSans', fontWeight: FontWeight.w700, color: textDark),
      titleMedium: TextStyle(
          fontFamily: 'AppSans', fontWeight: FontWeight.w600, color: textDark),
      bodyLarge: TextStyle(fontFamily: 'AppSans', color: textDark),
      bodyMedium: TextStyle(fontFamily: 'AppSans', color: textDark),
      bodySmall: TextStyle(fontFamily: 'AppSans', color: textLight),
      labelLarge: TextStyle(fontFamily: 'AppSans', fontWeight: FontWeight.w600),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: islamicButtonStyle,
    ),
    cardTheme: CardThemeData(
      color: pureWhite,
      elevation: 4,
      shadowColor: primaryGreen.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );
}
