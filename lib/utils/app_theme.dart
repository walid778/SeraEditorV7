
import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // =================================================
  // Background
  // =================================================

  static const Color background = Color(0xFF0F1113);
  static const Color surface = Color(0xFF17191C);
  static const Color surfaceLight = Color(0xFF202328);

  // =================================================
  // Buttons
  // =================================================

  static const Color button = Color(0xFFC9A227);
  static const Color buttonHover = Color(0xFFE2C15A);
  static const Color buttonPressed = Color(0xFFA9821D);

  // =================================================
  // Borders
  // =================================================

  static const Color border = Color(0xFF665321);
  static const Color borderHover = Color(0xFFD6B447);

  // =================================================
  // Text
  // =================================================

  static const Color text = Color(0xFFF5F5F5);
  static const Color secondaryText = Color(0xFFB8A66A);

  // =================================================
  // Accent
  // =================================================

  static const Color accent = Color(0xFFC9A227);
  static const Color accentHover = Color(0xFFE2C15A);

  // =================================================
  // Gold
  // =================================================

  static const Color goldLight = Color(0xFFE5C766);
  static const Color goldBright = Color(0xFFFFE08A);

  // =================================================
  // Success
  // =================================================

  static const Color success = Color(0xFF4CAF70);
  static const Color successLight = Color(0xFF7AD696);

  // =================================================
  // Error
  // =================================================

  static const Color error = Color(0xFFE06666);
  static const Color closeHover = Color(0xFFE85D5D);

  // =================================================
  // Disabled / Muted
  // =================================================

  static const Color disabled = Color(0xFF55585C);
  static const Color mutedText = Color(0xFF777B80);

  // =================================================
  // Input Background
  // =================================================

  static const Color inputBackground = Color(0xFF121416);

  // =================================================
  // Divider
  // =================================================

  static const Color divider = Color(0xFF292C30);

  // =================================================
  // Application Theme
  // =================================================

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      canvasColor: surface,
      dividerColor: divider,

      colorScheme: const ColorScheme.dark(
        primary: accent,
        onPrimary: background,
        secondary: goldLight,
        onSecondary: background,
        surface: surface,
        onSurface: text,
        error: error,
        onError: background,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: text,
        elevation: 0,
        centerTitle: false,
      ),

      cardTheme: CardTheme(
  color: surface,
  elevation: 0,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
    side: const BorderSide(color: border),
  ),
),

      dividerTheme: const DividerThemeData(
        color: divider,
        thickness: 1,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputBackground,
        labelStyle: const TextStyle(color: secondaryText),
        hintStyle: const TextStyle(color: mutedText),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: borderHover,
            width: 1.5,
          ),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: button,
          foregroundColor: background,
          disabledBackgroundColor: disabled,
          disabledForegroundColor: mutedText,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),

      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: text),
        bodyMedium: TextStyle(color: text),
        bodySmall: TextStyle(color: secondaryText),
        titleLarge: TextStyle(
          color: goldBright,
          fontWeight: FontWeight.bold,
        ),
        titleMedium: TextStyle(
          color: goldLight,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
