import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Poppins is locked across the entire AskEva app (per the design's
/// global font-lock rule). These helpers mirror the design's type scale.
class AppText {
  AppText._();

  static TextStyle poppins({
    double size = 14,
    FontWeight weight = FontWeight.w500,
    Color color = AppColors.ink,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: 'Poppins',
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  // Display / hero
  static TextStyle heroTitle(Color color) => TextStyle(
        fontFamily: 'Poppins',
        fontSize: 33,
        height: 0.96,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.3,
        color: color,
      );

  // Headings
  static TextStyle h3 = poppins(size: 24, weight: FontWeight.w700, letterSpacing: -0.24);
  static TextStyle screenTitle = poppins(size: 19, weight: FontWeight.w800, letterSpacing: 0.19);
  static TextStyle sectionTitle = poppins(size: 16.5, weight: FontWeight.w800, letterSpacing: -0.16);

  // Overline / labels
  static TextStyle overline = poppins(
    size: 11.5,
    weight: FontWeight.w800,
    color: AppColors.ink4,
    letterSpacing: 1.0,
  );

  static TextStyle body = poppins(size: 14.5, weight: FontWeight.w600, color: AppColors.ink2, height: 1.5);
  static TextStyle caption = poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink3);
}
