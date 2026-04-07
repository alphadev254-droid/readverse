import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const primary = Color(0xFF6200EA);
  static const primaryLight = Color(0xFF9D46FF);
  static const primaryDark = Color(0xFF0a00b6);
  static const accent = Color(0xFFFFC107);
  static const success = Color(0xFF4CAF50);
  static const error = Color(0xFFF44336);
  static const warning = Color(0xFFFF9800);
  static const info = Color(0xFF2196F3);

  // Reading backgrounds
  static const readingWhite = Color(0xFFFFFFFF);
  static const readingSepia = Color(0xFFF5E6C8);
  static const readingDark = Color(0xFF2D2D2D);
  static const readingBlack = Color(0xFF000000);

  // Highlight colors
  static const highlightYellow = Color(0xFFFFEB3B);
  static const highlightGreen = Color(0xFF8BC34A);
  static const highlightPink = Color(0xFFF48FB1);
  static const highlightBlue = Color(0xFF90CAF9);

  // Bookmark colors
  static const bookmarkRed = Color(0xFFF44336);
  static const bookmarkBlue = Color(0xFF2196F3);
  static const bookmarkGreen = Color(0xFF4CAF50);
  static const bookmarkPurple = Color(0xFF9C27B0);

  static const List<Color> highlightColors = [
    highlightYellow,
    highlightGreen,
    highlightPink,
    highlightBlue,
  ];

  static const List<Color> bookmarkColors = [
    bookmarkRed,
    bookmarkBlue,
    bookmarkGreen,
    bookmarkPurple,
  ];
}
