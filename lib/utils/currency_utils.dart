import 'dart:math';
import 'package:intl/intl.dart';

/// Utility class for currency parsing, formatting, and mathematical rounding.
class CurrencyUtils {
  static double parseCurrency(String? input) {
    if (input == null || input.trim().isEmpty) return 0.0;
    String cleaned = input.trim();

    if (cleaned.contains('/')) {
      final parts = cleaned.split('/');
      if (parts.length == 2) {
        final num1 = parseCurrency(parts[0]);
        final num2 = parseCurrency(parts[1]);
        if (num2 != 0) return roundMoney(num1 / num2);
      }
      return 0.0;
    }

    // Rimuovi caratteri non ammessi (tieni solo cifre, punto, virgola e meno)
    cleaned = cleaned.replaceAll(RegExp(r'[^\d\.,\-]'), '');

    if (cleaned.contains('.') && cleaned.contains(',')) {
      if (cleaned.lastIndexOf('.') < cleaned.lastIndexOf(',')) {
        // EU format: 1.234,56 -> 1234.56
        cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
      } else {
        // US format: 1,234.56 -> 1234.56
        cleaned = cleaned.replaceAll(',', '');
      }
    } else if (cleaned.contains(',')) {
      final commaCount = ','.allMatches(cleaned).length;
      if (commaCount > 1) {
        // Multiple commas: 1,000,000 -> thousands separators
        cleaned = cleaned.replaceAll(',', '');
      } else {
        cleaned = cleaned.replaceAll(',', '.');
      }
    } else if (cleaned.contains('.')) {
      final dotCount = '.'.allMatches(cleaned).length;
      if (dotCount > 1) {
        // Multiple dots: 1.000.000 -> EU thousands separators
        cleaned = cleaned.replaceAll('.', '');
      }
    }

    final parsed = double.tryParse(cleaned);
    if (parsed == null) return 0.0;
    return roundMoney(parsed);
  }

  static String formatEuro(double amount) {
    final bool isNegative = amount < 0;
    amount = roundMoney(amount.abs());

    final String fixed = amount.toStringAsFixed(2);
    final List<String> parts = fixed.split('.');
    final String intStr = parts[0];
    final String decStr = parts[1];

    final StringBuffer formattedInt = StringBuffer();
    for (int i = 0; i < intStr.length; i++) {
      if (i > 0 && (intStr.length - i) % 3 == 0) {
        formattedInt.write('.');
      }
      formattedInt.write(intStr[i]);
    }

    final String sign = isNegative ? '-' : '';
    return '€ $sign$formattedInt,$decStr';
  }

  static String formatNumber(double amount) {
    final f = NumberFormat('#,##0.00', 'it_IT');
    return f.format(amount);
  }

  static double roundMoney(double value) {
    final double mod = pow(10.0, 2).toDouble();
    return ((value * mod).round().toDouble() / mod);
  }
}
