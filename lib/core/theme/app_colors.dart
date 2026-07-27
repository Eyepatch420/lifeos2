import 'package:flutter/material.dart';

/// Colour palette lifted directly from the approved mockups so the built app
/// matches the designs one-to-one. Each module owns a brand colour used for its
/// top bar / accents.
class AppColors {
  AppColors._();

  // Module brand colours (from the mockups)
  static const Color home = Color(0xFF1A56A0);
  static const Color reminders = Color(0xFF1A56A0);
  static const Color planner = Color(0xFF1A56A0);
  static const Color expenses = Color(0xFF0F6E56);
  static const Color health = Color(0xFF534AB7);
  static const Color wellness = Color(0xFFD4537E);
  static const Color lists = Color(0xFF0F6E56);
  static const Color notes = Color(0xFF854F0B);
  static const Color memberships = Color(0xFF639922);
  static const Color bills = Color(0xFF185FA5);
  static const Color documents = Color(0xFF444441);
  static const Color progress = Color(0xFF26215C);
  static const Color clock = Color(0xFF3C3489);

  // Semantic status colours
  static const Color success = Color(0xFF3B6D11);
  static const Color successBg = Color(0xFFEAF3DE);
  static const Color successText = Color(0xFF27500A);

  static const Color warning = Color(0xFF854F0B);
  static const Color warningBg = Color(0xFFFAEEDA);
  static const Color warningText = Color(0xFF633806);

  static const Color danger = Color(0xFFA32D2D);
  static const Color dangerBg = Color(0xFFFCEBEB);
  static const Color dangerText = Color(0xFF791F1F);
  static const Color dangerBright = Color(0xFFE24B4A);

  static const Color info = Color(0xFF185FA5);
  static const Color infoBg = Color(0xFFE6F1FB);
  static const Color infoText = Color(0xFF0C447C);

  static const Color purple = Color(0xFF534AB7);
  static const Color purpleBg = Color(0xFFEEEDFE);
  static const Color purpleText = Color(0xFF3C3489);

  static const Color teal = Color(0xFF0F6E56);
  static const Color tealBg = Color(0xFFE1F5EE);
  static const Color tealText = Color(0xFF085041);

  static const Color checkGreen = Color(0xFF2E8B57);

  // Neutrals
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF5F5E5A);
  static const Color textTertiary = Color(0xFF888780);
  static const Color bgPrimary = Color(0xFFFFFFFF);
  static const Color bgSecondary = Color(0xFFF7F6F3);
  static const Color bgTertiary = Color(0xFFF1EFE8);
  static const Color borderTertiary = Color(0xFFE5E3DC);
  static const Color borderSecondary = Color(0xFFD3D1C7);

  /// Palette offered wherever the user picks a colour (habits, lists, tags).
  static const List<Color> picker = <Color>[
    Color(0xFF185FA5),
    Color(0xFF0F6E56),
    Color(0xFF534AB7),
    Color(0xFF854F0B),
    Color(0xFFA32D2D),
    Color(0xFF3B6D11),
    Color(0xFFD4537E),
    Color(0xFF888780),
  ];
}
