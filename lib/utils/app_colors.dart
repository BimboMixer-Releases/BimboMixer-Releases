import 'package:flutter/material.dart';

enum ThemePreset {
  viola,
  bluTech,
  rossoAmaranto,
  verdeEmerald,
  arancioneAmbra,
  rosaFuxia,
  ciano,
  oroPremium,
  neroBianco,
}

class AppColors {
  // --- BASE BACKGROUNDS (Constant across themes for consistency) ---
  static const Color backgroundMain = Color(0xFF080812);
  static const Color backgroundSecondary = Color(0xFF0A0A15);
  static const Color panelBackground = Color(0xFF13132B);
  static const Color panelBackgroundLight = Color(0xFF1C1C3D);
  
  static const Color cardBorder = Color(0x33FFFFFF); // Generic border
  
  // --- TEXT COLORS ---
  static const Color textMain = Color(0xFFF7F7FB);
  static const Color textSecondary = Color(0xFFA9A9B8);
  static const Color textDisabled = Color(0xFF666779);

  // --- SEMANTIC COLORS ---
  static const Color incomeGreen = Color(0xFF40E6A1);
  static const Color expenseRed = Color(0xFFFF4D65);
  static const Color pendingOrange = Color(0xFFFFB020);

  // --- THEME PRESETS ---
  static final Map<ThemePreset, ThemeColors> presets = {
    ThemePreset.viola: const ThemeColors(
      name: 'Viola (Attuale)',
      primary: Color(0xFF8B5CF6),
      secondary: Color(0xFFEC4899),
      accent: Color(0xFFA855F7),
      blueNeon: Color(0xFF6366F1),
    ),
    ThemePreset.bluTech: const ThemeColors(
      name: 'Blu Tech',
      primary: Color(0xFF0EA5E9),
      secondary: Color(0xFF3B82F6),
      accent: Color(0xFF2563EB),
      blueNeon: Color(0xFF1E40AF),
    ),
    ThemePreset.rossoAmaranto: const ThemeColors(
      name: 'Rosso Amaranto',
      primary: Color(0xFF991B1B),
      secondary: Color(0xFFDC2626),
      accent: Color(0xFFEF4444),
      blueNeon: Color(0xFF7F1D1D),
    ),
    ThemePreset.verdeEmerald: const ThemeColors(
      name: 'Verde Emerald',
      primary: Color(0xFF10B981),
      secondary: Color(0xFF34D399),
      accent: Color(0xFF059669),
      blueNeon: Color(0xFF047857),
    ),
    ThemePreset.arancioneAmbra: const ThemeColors(
      name: 'Arancione Ambra',
      primary: Color(0xFFF59E0B),
      secondary: Color(0xFFFB923C),
      accent: Color(0xFFF97316),
      blueNeon: Color(0xFFEA580C),
    ),
    ThemePreset.rosaFuxia: const ThemeColors(
      name: 'Rosa Fuxia',
      primary: Color(0xFFF472B6),
      secondary: Color(0xFFEC4899),
      accent: Color(0xFFDB2777),
      blueNeon: Color(0xFFBE185D),
    ),
    ThemePreset.ciano: const ThemeColors(
      name: 'Ciano',
      primary: Color(0xFF22D3EE),
      secondary: Color(0xFF06B6D4),
      accent: Color(0xFF0891B2),
      blueNeon: Color(0xFF0E7490),
    ),
    ThemePreset.oroPremium: const ThemeColors(
      name: 'Oro Premium',
      primary: Color(0xFFFCD34D),
      secondary: Color(0xFFF59E0B),
      accent: Color(0xFFD97706),
      blueNeon: Color(0xFFB45309),
    ),
    ThemePreset.neroBianco: const ThemeColors(
      name: 'Nero Bianco',
      primary: Color(0xFFFFFFFF),
      secondary: Color(0xFFE5E7EB),
      accent: Color(0xFF9CA3AF),
      blueNeon: Color(0xFF6B7280),
    ),
  };
}

class ThemeColors {
  final String name;
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color blueNeon; // Using this as the 4th color slot

  const ThemeColors({
    required this.name,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.blueNeon,
  });
}
