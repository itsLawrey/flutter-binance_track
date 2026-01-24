import 'package:flutter/material.dart';

/// Binance-themed dark theme configuration
/// Colors inspired by Binance's brand guidelines
class AppTheme {
  // Brand Colors
  static const Color sharkBlack = Color(0xFF1E2329);
  static const Color cardGray = Color(0xFF2B3139);
  static const Color brightSunYellow = Color(0xFFFCD535);
  static const Color binanceGreen = Color(0xFF0ECB81);
  static const Color binanceRed = Color(0xFFF6465D);

  static final ThemeData darkTheme = ThemeData.dark().copyWith(
    scaffoldBackgroundColor: sharkBlack,
    primaryColor: brightSunYellow,
    appBarTheme: const AppBarTheme(
      backgroundColor: sharkBlack,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 20,
      ),
      iconTheme: IconThemeData(color: brightSunYellow),
    ),
    cardTheme: CardThemeData(
      color: cardGray,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: brightSunYellow,
        foregroundColor: Colors.black,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cardGray,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: brightSunYellow),
      ),
      labelStyle: const TextStyle(color: Colors.grey),
    ),
    colorScheme: const ColorScheme.dark(
      primary: brightSunYellow,
      secondary: brightSunYellow,
      surface: cardGray,
      error: binanceRed,
    ),
  );
}
