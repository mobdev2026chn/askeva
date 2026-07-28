import 'package:flutter/material.dart';

/// App color palette. Green primary/secondary used in both light and dark themes.
///
/// In widgets, prefer [Theme.of(context).colorScheme] for surfaces and text so
/// light/dark theme switch works: use [ColorScheme.surface], [ColorScheme.onSurface],
/// [ColorScheme.onSurfaceVariant], [ColorScheme.outline], [ColorScheme.primary],
/// [ColorScheme.onPrimary]. Use [AppColors.primary] for brand green when theme
/// does not need to change the color.
class AppColors {
  AppColors._();

  // ---------- Signature Gradient (AskEva Design System) ----------
  /// Signature gradient used in headers, dashboard, login/splash
  /// Applied at 135° angle: #3DC838 → #7FD63B → #C8FF4A
  static const Color signatureGradientStart = Color(0xFF3DC838);
  static const Color signatureGradientMid = Color(0xFF7FD63B);
  static const Color signatureGradientEnd = Color(0xFFC8FF4A);

  // ---------- Brand Primary Colors (same in light & dark) ----------
  static const Color primary = Color(0xFF3DC838); // Brand-500
  static const Color primaryDark = Color(0xFF2BA84A); // Brand-600, hover/pressed
  static const Color primaryDeep = Color(0xFF177A36); // Brand-700, deep
  static const Color primaryLight = Color(0xFF5BCC4A); // Brand-400 lime
  static const Color primaryGlow = Color(0xFF85D653); // Brand-300 lime glow
  static const Color secondary = Color(0xFF2BA84A);
  static const Color tertiary = Color(0xFF7FD63B);
  static const Color onPrimary = Colors.white;
  static const Color onSecondary = Colors.white;

  /// Signature gradient for headers (135° angle)
  static const List<Color> signatureGradient = [
    signatureGradientStart,
    signatureGradientMid,
    signatureGradientEnd,
  ];

  /// Gradient for primary accent (menu icon, FAB, buttons)
  static const List<Color> primaryGradient = [primary, primaryDark];
  static const List<Color> primaryGradientSoft = [primaryLight, primary];

  // ---------- Light theme (AskEva Design) ----------
  static const Color lightBackground = Color(0xFFF6F8F5); // Page background (faint green-tinted)
  static const Color lightSurface = Colors.white;
  static const Color lightSurfaceVariant = Color(0xFFECF0E8); // Surface-3
  static const Color lightPrimaryContainer = Color(0xFFEAF9E6); // Tint-50
  static const Color lightOnPrimaryContainer = Color(0xFF0F3D0E); // Green-900
  static const Color lightOnSurface = Color(0xFF15231A); // Ink (near-black with green undertone)
  static const Color lightOnSurfaceVariant = Color(0xFF5A7862);
  static const Color lightOutline = Color(0xFFCDEAC4); // Tint border
  static const Color lightError = Color(0xFFBA1A1A);
  static const Color lightOnError = Colors.white;

  // Tint colors for chips and pills
  static const Color tint50 = Color(0xFFEAF9E6);
  static const Color tint100 = Color(0xFFDCF3D6);
  static const Color tintBorder = Color(0xFFCDEAC4);

  // ---------- Dark theme ----------
  static const Color darkBackground = Color(0xFF0F3D0E); // Green-900
  static const Color darkSurface = Color(0xFF1A1A1A);
  static const Color darkSurfaceVariant = Color(0xFF2D2D2D);
  static const Color darkPrimaryContainer = Color(0xFF2BA84A);
  static const Color darkOnPrimaryContainer = Color(0xFFC8FF4A);
  static const Color darkOnSurface = Color(0xFFEAF9E6);
  static const Color darkOnSurfaceVariant = Color(0xFFCAC4D0);
  static const Color darkOutline = Color(0xFF85D653);
  static const Color darkError = Color(0xFFCF6679);
  static const Color darkOnError = Color(0xFF410002);
}
