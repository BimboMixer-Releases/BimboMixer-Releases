import 'package:intl/intl.dart';
import 'dart:math';

/// Utility class for currency parsing, formatting, and mathematical rounding.
/// Ensures that financial calculations use a consistent rounding approach
/// and that UI formatting is identical across the app.
class CurrencyUtils {
  static final NumberFormat _euroFormat = NumberFormat.currency(
    locale: 'it_IT',
    symbol: '€',
    decimalDigits: 2,
  );

  /// Parses a string into a double, handling both comma and dot decimal separators.
  /// If the input is empty or invalid, returns 0.0.
  /// Example: "1.234,56" -> 1234.56
  static double parseCurrency(String? input) {
    if (input == null || input.trim().isEmpty) {
      return 0.0;
    }

    String cleaned = input.trim();
    
    // Support division input like "1300/2"
    if (cleaned.contains('/')) {
      final parts = cleaned.split('/');
      if (parts.length == 2) {
        final num1 = parseCurrency(parts[0]);
        final num2 = parseCurrency(parts[1]);
        if (num2 != 0) {
          return roundMoney(num1 / num2);
        }
      }
      return 0.0;
    }

    // Handle Italian formatting (1.234,56 -> 1234.56)
    // First, check if both . and , are present
    if (cleaned.contains('.') && cleaned.contains(',')) {
      // If dot is before comma, it's likely thousand separator dot, decimal comma
      if (cleaned.indexOf('.') < cleaned.indexOf(',')) {
        cleaned = cleaned.replaceAll('.', '');
        cleaned = cleaned.replaceAll(',', '.');
      } else {
        // comma is before dot (e.g. 1,234.56)
        cleaned = cleaned.replaceAll(',', '');
      }
    } else if (cleaned.contains(',')) {
      // Only comma present, assume it's decimal comma
      cleaned = cleaned.replaceAll(',', '.');
    }

    // Remove any remaining characters that are not digits, dot, or minus sign
    cleaned = cleaned.replaceAll(RegExp(r'[^0-9\.-]'), '');

    double? parsed = double.tryParse(cleaned);
    if (parsed == null) return 0.0;
    
    return roundMoney(parsed);
  }

  /// Formats a double into a standard Euro string representation.
  /// Example: 1234.567 -> "€ 1.234,57"
  static String formatEuro(double amount) {
    return _euroFormat.format(amount);
  }

  /// Performs mathematical rounding to 2 decimal places to prevent floating-point accumulation errors.
  /// Example: 0.1 + 0.2 (0.30000000000000004) -> 0.30
  static double roundMoney(double value) {
    double mod = pow(10.0, 2).toDouble();
    return ((value * mod).round().toDouble() / mod);
  }
}
