import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_colors.dart';

class AppThemeProvider extends ChangeNotifier {
  static const _keyPreset = 'theme_preset_index';

  ThemePreset _currentPreset = ThemePreset.viola;

  ThemePreset get currentPreset => _currentPreset;

  ThemeColors get currentColors => AppColors.presets[_currentPreset]!;

  AppThemeProvider() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final presetIndex = prefs.getInt(_keyPreset);
    if (presetIndex != null && presetIndex >= 0 && presetIndex < ThemePreset.values.length) {
      _currentPreset = ThemePreset.values[presetIndex];
    }
    notifyListeners();
  }

  Future<void> setPreset(ThemePreset preset) async {
    _currentPreset = preset;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyPreset, preset.index);
    notifyListeners();
  }

  // --- BACKWARD COMPATIBILITY GETTERS ---
  Color get primaryColor => currentColors.primary;
  Color get textColor => AppColors.textMain;
  Color get cardColor => panelBackground;
  Color get borderColor => AppColors.cardBorder;
  Color get buttonColor => currentColors.primary;
  Color get buttonTextColor => Colors.white;
  Color get glowColor => currentColors.primary;
  Color get cardTextColor => AppColors.textMain;
  Color get primaryTextColor => Colors.white;
  
  // DYNAMIC BACKGROUNDS
  Color get backgroundMain => Color.lerp(const Color(0xFF080812), currentColors.primary, 0.05)!;
  Color get panelBackground => Color.lerp(Color(0xFF13132B), currentColors.primary, 0.05)!;

  String? get backgroundImagePath => null;
  String? get logoImagePath => null;
  bool get hasValidLogo => false;
  String get dateFormat => 'yyyy-MM-dd'; // Temporarily fixed format
}
