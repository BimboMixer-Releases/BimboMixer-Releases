import 'package:flutter/material.dart';

class ColorUtils {
  /// Ritorna nero o bianco a seconda della luminanza del colore di sfondo fornito,
  /// in modo da garantire sempre un buon contrasto.
  static Color getContrastTextColor(Color backgroundColor) {
    return backgroundColor.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }

  /// Restituisce la variante con opacità (utile per i testi secondari).
  static Color getContrastTextColorWithAlpha(Color backgroundColor, {double alpha = 0.54}) {
    return getContrastTextColor(backgroundColor).withValues(alpha: alpha);
  }
}
