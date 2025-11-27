import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AppStyle {
  // Islamic Color Palette
  static const Color primaryGreen = Color(0xFF2E7D32); // Islamic Green
  static const Color darkGreen = Color(0xFF1B5E20);
  static const Color lightGreen = Color(0xFF66BB6A);
  static const Color goldColor = Color(0xFFFFD700); // Islamic Gold
  static const Color darkGold = Color(0xFFB8860B);
  static const Color creamColor = Color(0xFFF5F5DC);
  static const Color darkBrown = Color(0xFF3E2723);
  static const Color lightBrown = Color(0xFF8D6E63);
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color softGray = Color(0xFFF5F5F5);
  static const Color textDark = Color(0xFF212121);
  static const Color textLight = Color(0xFF757575);

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
    elevation: 2,
    centerTitle: true,
    titleTextStyle: const TextStyle(
      color: pureWhite,
      fontFamily: 'Amiri',
      fontSize: 22.0,
      fontWeight: FontWeight.bold,
    ),
  );

  // Theme Data
  static ThemeData islamicTheme = ThemeData(
    primarySwatch: Colors.green,
    primaryColor: primaryGreen,
    scaffoldBackgroundColor: softGray,
    appBarTheme: islamicAppBarTheme,
    fontFamily: 'Amiri',
    textTheme: const TextTheme(
      headlineLarge: headingTextStyle,
      headlineMedium: titleTextStyle,
      bodyLarge: regularTextStyle,
      bodyMedium: arabicTextStyle,
      labelLarge: buttonTextStyle,
      bodySmall: captionTextStyle,
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
