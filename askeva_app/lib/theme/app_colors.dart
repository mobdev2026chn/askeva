import 'package:flutter/material.dart';

/// AskEva brand palette — unified primary color system.
/// Primary brand color: static const Color evaGreen = Color(0xFF3DC838);
class AppColors {
  AppColors._();

  // ---------- Brand greens ----------
  static const Color evaGreen = Color(0xFF3DC838); // brand primary (0xFF3DC838)
  static const Color evaGreenDark = Color(0xFF3DC838); // primary dark / pressed
  static const Color evaGreenDeep = Color(0xFF3DC838); // primary headings / active nav
  static const Color evaLime = Color(0xFF3DC838); // primary light
  static const Color evaLimeGlow = Color(0xFF3DC838); // primary glow
  static const Color evaGreen50 = Color(0xFFEBFCE8); // tint-50 — surfaces, pills
  static const Color evaGreen100 = Color(0xFFDCFBD8); // tint-100 — hover chips
  static const Color evaGreen200 = Color(0xFFC7F7C2); // tint border

  // Semantic accent aliases
  static const Color accent = evaGreen;
  static const Color accentDeep = evaGreen;
  static const Color accentSoft = evaGreen50;

  // ---------- Neutrals ----------
  static const Color ink = Color(0xFF15231A); // near-black, green undertone
  static const Color ink2 = Color(0xFF4D5D52); // body / secondary
  static const Color ink3 = Color(0xFF8A978D); // muted labels
  static const Color ink4 = Color(0xFF9AA39C); // faintest / disabled
  static const Color line = Color(0xFFEEF1EC); // hairline borders
  static const Color surface = Color(0xFFFFFFFF); // cards
  static const Color surface2 = Color(0xFFF6F8F5); // page background tint
  static const Color surface3 = Color(0xFFECF0E8);

  // ---------- WhatsApp / chat context ----------
  static const Color waHeader = Color(0xFF3DC838);
  static const Color waBg = Color(0xFFE5DDD5);
  static const Color waBubbleOut = Color(0xFFEBFCE8);
  static const Color waBubbleIn = Color(0xFFFFFFFF);
  static const Color waTickBlue = Color(0xFF3DC838);

  // ---------- Semantic ----------
  static const Color success = Color(0xFF3DC838);
  static const Color warning = Color(0xFFF5B829);
  static const Color danger = Color(0xFFEF5350);
  static const Color info = Color(0xFF3B82F6);

  // ---------- Primary Header Gradient ----------
  static const LinearGradient evaGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3DC838), Color(0xFF3DC838)],
  );

  // ---------- Lead status tints ----------
  static const Color hotFg = Color(0xFFC23A18);
  static const Color hotBg = Color(0xFFFDEAE3);
  static const Color warmFg = Color(0xFF9A6B05);
  static const Color warmBg = Color(0xFFFBF1D8);
  static const Color newFg = Color(0xFF2563EB);
  static const Color newBg = Color(0xFFE5EEFD);
  static const Color convertedFg = evaGreen;
  static const Color convertedBg = evaGreen50;
  static const Color coldFg = Color(0xFF1E7FB0);
  static const Color coldBg = Color(0xFFE3F2FB);

  // ---------- Shadows ----------
  static const List<BoxShadow> shadowXs = [
    BoxShadow(color: Color(0x0F0F1A0E), blurRadius: 2, offset: Offset(0, 1)),
  ];
  static const List<BoxShadow> shadowSm = [
    BoxShadow(color: Color(0x140F1A0E), blurRadius: 6, offset: Offset(0, 2)),
  ];
  static const List<BoxShadow> shadowMd = [
    BoxShadow(color: Color(0x1A0F1A0E), blurRadius: 20, offset: Offset(0, 8)),
  ];
  static const List<BoxShadow> shadowEva = [
    BoxShadow(color: Color(0x333DC838), blurRadius: 32, offset: Offset(0, 14)),
  ];
}
