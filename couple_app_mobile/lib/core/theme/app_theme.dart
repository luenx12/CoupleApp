import 'package:flutter/material.dart';

class AppColors {
  static const primary         = Color(0xFFE91E8C);
  static const secondary       = Color(0xFF7C3AED);
  static const accent          = Color(0xFFFF6B9D);
  static const surface         = Color(0xFF1A1025);
  static const card            = Color(0xFF251535);
  static const cardBorder      = Color(0xFF3D2060);
  static const onSurface       = Color(0xFFF3E8FF);
  static const onSurfaceMuted  = Color(0xFF9D7FC4);
  static const success         = Color(0xFF10B981);
  static const error           = Color(0xFFEF4444);
}

class AppTheme {
  AppTheme._();

  static const primaryGradient = LinearGradient(
    colors: [AppColors.primary, AppColors.secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const backgroundGradient = LinearGradient(
    colors: [Color(0xFF0D0618), Color(0xFF1A0A2E), Color(0xFF16012B)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.surface,
    colorScheme: const ColorScheme.dark(
      primary:   AppColors.primary,
      secondary: AppColors.secondary,
      surface:   AppColors.surface,
      onPrimary: Colors.white,
      onSurface: AppColors.onSurface,
      error:     AppColors.error,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.onSurface,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.card,
      indicatorColor: AppColors.primary.withAlpha(51),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.onSurface),
      ),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: AppColors.primary, size: 26);
        }
        return const IconThemeData(color: AppColors.onSurfaceMuted, size: 24);
      }),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      labelStyle: const TextStyle(color: AppColors.onSurfaceMuted),
      hintStyle: const TextStyle(color: AppColors.onSurfaceMuted),
    ),
  );
}
