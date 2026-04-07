import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';
import '../config/app_colors.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  double _fontSize = AppConstants.defaultFontSize;
  String _fontFamily = 'Serif';
  String _lineHeight = 'Normal';
  Color _readingBackground = AppColors.readingWhite;
  Color _accentColor = AppColors.primary;

  ThemeMode get themeMode => _themeMode;
  double get fontSize => _fontSize;
  String get fontFamily => _fontFamily;
  String get lineHeight => _lineHeight;
  Color get readingBackground => _readingBackground;
  Color get accentColor => _accentColor;

  double get lineHeightValue {
    switch (_lineHeight) {
      case 'Compact': return 1.3;
      case 'Relaxed': return 1.8;
      default: return 1.5;
    }
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeIndex = prefs.getInt(AppConstants.themeModeKey) ?? 0;
    _themeMode = ThemeMode.values[themeModeIndex];
    _fontSize = prefs.getDouble(AppConstants.fontSizeKey) ?? AppConstants.defaultFontSize;
    _fontFamily = prefs.getString(AppConstants.fontFamilyKey) ?? 'Serif';
    _lineHeight = prefs.getString(AppConstants.lineHeightKey) ?? 'Normal';
    final bgValue = prefs.getInt(AppConstants.readingBgKey);
    if (bgValue != null) _readingBackground = Color(bgValue);
    final accentValue = prefs.getInt(AppConstants.accentColorKey);
    if (accentValue != null) _accentColor = Color(accentValue);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.themeModeKey, mode.index);
    notifyListeners();
  }

  Future<void> setFontSize(double size) async {
    _fontSize = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(AppConstants.fontSizeKey, size);
    notifyListeners();
  }

  Future<void> setFontFamily(String family) async {
    _fontFamily = family;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.fontFamilyKey, family);
    notifyListeners();
  }

  Future<void> setLineHeight(String height) async {
    _lineHeight = height;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.lineHeightKey, height);
    notifyListeners();
  }

  Future<void> setReadingBackground(Color color) async {
    _readingBackground = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.readingBgKey, color.toARGB32());
    notifyListeners();
  }

  Future<void> setAccentColor(Color color) async {
    _accentColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.accentColorKey, color.toARGB32());
    notifyListeners();
  }
}
