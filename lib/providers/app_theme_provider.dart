import 'dart:io';
import 'package:flutter/material.dart';
import '../utils/color_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum GlowEffectType {
  none,
  outerGlow,
  neonBorder,
  innerFill,
}

class AppThemeProvider extends ChangeNotifier {
  static const _keyBgImagePath = 'bg_image_path';
  static const _keyLogoPath = 'logo_path';
  static const _keyPrimaryColor = 'primary_color';
  static const _keyTextColor = 'text_color';
  static const _keyCardColor = 'card_color';
  static const _keyBorderColor = 'border_color';
  static const _keyButtonColor = 'button_color';
  static const _keyButtonTextColor = 'button_text_color';
  static const _keyGlowColor = 'glow_color';
  static const _keyGlowEffectType = 'glow_effect_type';
  static const _keyDateFormat = 'date_format';

  String? _backgroundImagePath;
  String? _logoImagePath;
  Color _primaryColor = const Color(0xFF3B82F6); // Blue
  Color _textColor = Colors.white;
  Color _cardColor = const Color(0xFF1E1E24);
  Color _borderColor = const Color(0xFF2C2C35);
  Color _buttonColor = const Color(0xFF3B82F6);
  Color _buttonTextColor = Colors.white;
  Color _glowColor = Colors.transparent;
  GlowEffectType _glowEffectType = GlowEffectType.none;
  String _dateFormat = 'yyyy-MM-dd';

  String? get backgroundImagePath => _backgroundImagePath;
  String? get logoImagePath => _logoImagePath;
  Color get primaryColor => _primaryColor;
  Color get textColor => _textColor;
  Color get cardColor => _cardColor;
  Color get borderColor => _borderColor;
  Color get buttonColor => _buttonColor;
  Color get buttonTextColor => _buttonTextColor; // For backward compatibility if explicitly set, but generally use contrast.
  
  // Colori testuali calcolati automaticamente per garantire il contrasto
  Color get cardTextColor => ColorUtils.getContrastTextColor(_cardColor);
  Color get primaryTextColor => ColorUtils.getContrastTextColor(_primaryColor);

  Color get glowColor => _glowColor;
  GlowEffectType get glowEffectType => _glowEffectType;
  String get dateFormat => _dateFormat;

  bool get hasValidBackground {
    if (_backgroundImagePath == null) return false;
    return File(_backgroundImagePath!).existsSync();
  }

  bool get hasValidLogo {
    if (_logoImagePath == null) return false;
    return File(_logoImagePath!).existsSync();
  }

  AppThemeProvider() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _backgroundImagePath = prefs.getString(_keyBgImagePath);
    _logoImagePath = prefs.getString(_keyLogoPath);
    final primaryVal = prefs.getInt(_keyPrimaryColor);
    if (primaryVal != null) _primaryColor = Color(primaryVal);
    final textVal = prefs.getInt(_keyTextColor);
    if (textVal != null) _textColor = Color(textVal);
    final cardVal = prefs.getInt(_keyCardColor);
    if (cardVal != null) _cardColor = Color(cardVal);
    final borderVal = prefs.getInt(_keyBorderColor);
    if (borderVal != null) _borderColor = Color(borderVal);
    final btnVal = prefs.getInt(_keyButtonColor);
    if (btnVal != null) _buttonColor = Color(btnVal);
    final btnTextVal = prefs.getInt(_keyButtonTextColor);
    if (btnTextVal != null) _buttonTextColor = Color(btnTextVal);
    final glowVal = prefs.getInt(_keyGlowColor);
    if (glowVal != null) _glowColor = Color(glowVal);
    final glowTypeVal = prefs.getInt(_keyGlowEffectType);
    if (glowTypeVal != null && glowTypeVal >= 0 && glowTypeVal < GlowEffectType.values.length) {
      _glowEffectType = GlowEffectType.values[glowTypeVal];
    }
    _dateFormat = prefs.getString(_keyDateFormat) ?? 'yyyy-MM-dd';
    notifyListeners();
  }

  Future<void> setBackgroundImage(String path) async {
    _backgroundImagePath = path;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBgImagePath, path);
    notifyListeners();
  }

  Future<void> removeBackgroundImage() async {
    _backgroundImagePath = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyBgImagePath);
    notifyListeners();
  }

  Future<void> setLogoImage(String path) async {
    _logoImagePath = path;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLogoPath, path);
    notifyListeners();
  }

  Future<void> removeLogoImage() async {
    _logoImagePath = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLogoPath);
    notifyListeners();
  }

  Future<void> setPrimaryColor(Color color) async {
    _primaryColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyPrimaryColor, color.toARGB32());
    notifyListeners();
  }

  Future<void> setTextColor(Color color) async {
    _textColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTextColor, color.toARGB32());
    notifyListeners();
  }

  Future<void> setCardColor(Color color) async {
    _cardColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCardColor, color.toARGB32());
    notifyListeners();
  }

  Future<void> setBorderColor(Color color) async {
    _borderColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyBorderColor, color.toARGB32());
    notifyListeners();
  }

  Future<void> setButtonColor(Color color) async {
    _buttonColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyButtonColor, color.toARGB32());
    notifyListeners();
  }

  Future<void> setButtonTextColor(Color color) async {
    _buttonTextColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyButtonTextColor, color.toARGB32());
    notifyListeners();
  }

  Future<void> setGlowColor(Color color) async {
    _glowColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyGlowColor, color.toARGB32());
    notifyListeners();
  }

  Future<void> setGlowEffectType(GlowEffectType type) async {
    _glowEffectType = type;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyGlowEffectType, type.index);
    notifyListeners();
  }

  Future<void> setDateFormat(String format) async {
    _dateFormat = format;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDateFormat, format);
    notifyListeners();
  }

  Future<void> resetAll() async {
    _backgroundImagePath = null;
    _logoImagePath = null;
    _primaryColor = const Color(0xFF3B82F6);
    _textColor = Colors.white;
    _cardColor = const Color(0xFF1E1E24);
    _borderColor = const Color(0xFF2C2C35);
    _buttonColor = const Color(0xFF3B82F6);
    _buttonTextColor = Colors.white;
    _glowColor = Colors.transparent;
    _glowEffectType = GlowEffectType.none;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }
}
