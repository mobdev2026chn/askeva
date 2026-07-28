import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    const cs = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onSecondary,
      tertiary: AppColors.tertiary,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightOnSurface,
      surfaceContainerHighest: AppColors.lightSurfaceVariant,
      onSurfaceVariant: AppColors.lightOnSurfaceVariant,
      outline: AppColors.lightOutline,
      error: AppColors.lightError,
      onError: AppColors.lightOnError,
      primaryContainer: AppColors.lightPrimaryContainer,
      onPrimaryContainer: AppColors.lightOnPrimaryContainer,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: AppColors.lightBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        foregroundColor: AppColors.lightOnSurface,
        elevation: 0,
        scrolledUnderElevation: 3,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 20,
          color: AppColors.lightOnSurface,
        ),
        iconTheme: const IconThemeData(color: AppColors.lightOnSurface),
        actionsIconTheme: const IconThemeData(color: AppColors.lightOnSurface),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withOpacity(0.06),
      ),
      cardTheme: CardThemeData(
        color: cs.surface,
        elevation: 3,
        shadowColor: Colors.black.withOpacity(0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        clipBehavior: Clip.antiAlias,
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: cs.onSurface),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: cs.onSurface),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: cs.onSurface),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: cs.onSurface),
        bodyLarge: TextStyle(fontSize: 16, color: cs.onSurface),
        bodyMedium: TextStyle(fontSize: 14, color: cs.onSurface),
        bodySmall: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.lightOnSurfaceVariant,
        indicatorColor: AppColors.primary,
      ),
      listTileTheme: ListTileThemeData(
        textColor: cs.onSurface,
        iconColor: cs.onSurfaceVariant,
      ),
      dividerTheme: DividerThemeData(color: cs.outline.withOpacity(0.5)),
      drawerTheme: DrawerThemeData(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(right: Radius.circular(20))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cs.surface,
        elevation: 12,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: cs.onSurface),
        contentTextStyle: TextStyle(fontSize: 14, color: cs.onSurface),
        alignment: Alignment.center,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerHighest,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.outline.withOpacity(0.5)),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        labelStyle: TextStyle(color: cs.onSurfaceVariant),
        hintStyle: TextStyle(color: cs.onSurfaceVariant),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size(double.infinity, 48),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          elevation: 0,
          shadowColor: AppColors.primary.withOpacity(0.2),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: cs.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: cs.onSurfaceVariant,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: cs.surfaceContainerHighest,
        contentTextStyle: TextStyle(fontSize: 14, color: cs.onSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static ThemeData get dark {
    const cs = ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onSecondary,
      tertiary: AppColors.tertiary,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkOnSurface,
      surfaceContainerHighest: AppColors.darkSurfaceVariant,
      onSurfaceVariant: AppColors.darkOnSurfaceVariant,
      outline: AppColors.darkOutline,
      error: AppColors.darkError,
      onError: AppColors.darkOnError,
      primaryContainer: AppColors.darkPrimaryContainer,
      onPrimaryContainer: AppColors.darkOnPrimaryContainer,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: AppColors.darkBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 3,
        centerTitle: true,
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cs.onSurface),
        iconTheme: IconThemeData(color: cs.onSurface),
        actionsIconTheme: IconThemeData(color: cs.onSurface),
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: cs.surface,
        elevation: 3,
        shadowColor: Colors.black45,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        clipBehavior: Clip.antiAlias,
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: cs.onSurface),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: cs.onSurface),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: cs.onSurface),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: cs.onSurface),
        bodyLarge: TextStyle(fontSize: 16, color: cs.onSurface),
        bodyMedium: TextStyle(fontSize: 14, color: cs.onSurface),
        bodySmall: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: cs.onSurfaceVariant,
        indicatorColor: AppColors.primary,
      ),
      listTileTheme: ListTileThemeData(
        textColor: cs.onSurface,
        iconColor: cs.onSurfaceVariant,
      ),
      dividerTheme: DividerThemeData(color: cs.outline.withOpacity(0.5)),
      drawerTheme: DrawerThemeData(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(right: Radius.circular(20))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cs.surface,
        elevation: 8,
        shadowColor: Colors.black45,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: cs.onSurface),
        contentTextStyle: TextStyle(fontSize: 14, color: cs.onSurface),
        alignment: Alignment.center,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerHighest,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.outline.withOpacity(0.5)),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        labelStyle: TextStyle(color: cs.onSurfaceVariant),
        hintStyle: TextStyle(color: cs.onSurfaceVariant),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size(double.infinity, 48),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          elevation: 0,
          shadowColor: AppColors.primary.withOpacity(0.2),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: cs.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: cs.onSurfaceVariant,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: cs.surfaceContainerHighest,
        contentTextStyle: TextStyle(fontSize: 14, color: cs.onSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
