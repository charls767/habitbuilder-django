import 'package:flutter/material.dart';

/// Colors lifted from the course artifacts' mockups/diagrams so the app
/// matches them from the first screen onward.
abstract final class AppColors {
  static const teal = Color(0xFF0F766E);
  static const blue = Color(0xFF1D4ED8);
  static const ink = Color(0xFF172033);
  static const softBackground = Color(0xFFF8FAFC);
}

abstract final class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.teal,
          primary: AppColors.teal,
          secondary: AppColors.blue,
        ),
        scaffoldBackgroundColor: AppColors.softBackground,
        textTheme: ThemeData.light().textTheme.apply(
              bodyColor: AppColors.ink,
              displayColor: AppColors.ink,
            ),
      );
}
