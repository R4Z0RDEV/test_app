import 'package:flutter/material.dart';

const kBackgroundColor = Color(0xFF000000);
const kSurfaceColor = Color(0xFF080910);
const kSurfaceElevatedColor = Color(0xFF111320);
const kFieldFillColor = Color(0xFF141621);
const kPurpleStart = Color(0xFF9B5CFF);
const kPurpleEnd = Color(0xFFDB5CFF);
const kDangerColor = Color(0xFFFF5C7A);
const kSuccessColor = Color(0xFF4ADE80);

class AppGradients {
  static const primary = LinearGradient(
    colors: [kPurpleStart, kPurpleEnd],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: kBackgroundColor,
    colorScheme: ColorScheme.fromSeed(
      seedColor: kPurpleStart,
      brightness: Brightness.dark,
    ).copyWith(
      primary: kPurpleStart,
      secondary: kPurpleEnd,
      error: kDangerColor,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      foregroundColor: Colors.white,
      titleTextStyle: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: Colors.white,
      ),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 38,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.1,
        color: Colors.white,
      ),
      headlineSmall: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: Colors.white,
      ),
      bodyMedium: TextStyle(
        fontSize: 15,
        height: 1.5,
        color: Colors.white70,
      ),
      labelLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        letterSpacing: 0.2,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kFieldFillColor,
      hintStyle: const TextStyle(color: Colors.white54),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: kPurpleEnd, width: 1.4),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: kSurfaceElevatedColor,
      contentTextStyle: TextStyle(color: Colors.white),
    ),
    dividerColor: Colors.white.withOpacity(0.08),
  );

  return base;
}
