import 'package:flutter/material.dart';
import 'package:q_task/presentation/providers/settings_provider.dart';
import 'package:q_task/presentation/theme/outline_styles.dart';

class AppTheme {
  static ThemeData lightTheme(SettingsModel settings) {
    return _buildTheme(Brightness.light, settings);
  }

  static ThemeData darkTheme(SettingsModel settings) {
    return _buildTheme(Brightness.dark, settings);
  }

  static ThemeData _buildTheme(Brightness brightness, SettingsModel settings) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: Color(settings.primaryColor),
      brightness: brightness,
    );

    final baseFontSize = settings.baseFontSize;
    final basePadding = settings.basePadding;
    final cornerRadius = settings.cornerRadius;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: baseFontSize * 2.0, // 32 if base is 16
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
        titleLarge: TextStyle(
          fontSize: baseFontSize * 1.25, // 20 if base is 16
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
        ),
        bodyLarge: TextStyle(
          fontSize: baseFontSize, // 16 if base is 16
          fontWeight: FontWeight.w400,
          letterSpacing: 0.5,
        ),
        bodyMedium: TextStyle(
          fontSize: baseFontSize * 0.875, // 14 if base is 16
          fontWeight: FontWeight.w400,
          letterSpacing: 0.25,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cornerRadius),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineStyles.inputBorder(radius: cornerRadius),
        enabledBorder: OutlineStyles.inputBorder(radius: cornerRadius),
        focusedBorder: OutlineStyles.inputBorder(radius: cornerRadius),
        contentPadding: EdgeInsets.all(basePadding),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(
              horizontal: basePadding * 1.5, vertical: basePadding * 0.75),
          minimumSize: Size.fromHeight(basePadding * 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(cornerRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
            side: OutlineStyles.borderSide,
            padding: EdgeInsets.symmetric(
                horizontal: basePadding * 1.5, vertical: basePadding * 1.5),
            minimumSize: Size.fromHeight(basePadding * 3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(cornerRadius),
            )),
      ),
    );
  }
}
