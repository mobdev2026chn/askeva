import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

/// Material theme wiring for AskEva. Light-only (the design is light).
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'Poppins',
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.surface2,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.evaGreen,
        primary: AppColors.evaGreen,
        secondary: AppColors.evaGreenDeep,
        surface: AppColors.surface,
        brightness: Brightness.light,
      ),
    );

    return base.copyWith(
      splashColor: AppColors.evaGreen.withValues(alpha: 0.08),
      highlightColor: AppColors.evaGreen.withValues(alpha: 0.04),
      dividerColor: AppColors.line,
      iconTheme: const IconThemeData(color: AppColors.ink2),
    );
  }

  static ThemeData get dark {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'Poppins',
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF121813),
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.evaGreen,
        primary: AppColors.evaGreen,
        secondary: AppColors.evaLimeGlow,
        brightness: Brightness.dark,
      ),
    );
    return base.copyWith(
      splashColor: AppColors.evaGreen.withValues(alpha: 0.10),
    );
  }

  /// Light icons (for the green header) vs dark icons (for white sheets).
  static const SystemUiOverlayStyle statusLight = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  );

  static const SystemUiOverlayStyle statusDark = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  );
}
