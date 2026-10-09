import 'package:intl/intl.dart';
import 'dart:math';

/// Utility class for currency parsing, formatting, and mathematical rounding.
class CurrencyUtils {
  static final NumberFormat _euroFormat = NumberFormat.currency(
    locale: 'it_IT',
    symbol: '€',
    decimalDigits: 2,
  );

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
      if (cleaned.indexOf('.') < cleaned.lastIndexOf(',')) {
        // EU format: 1.234,56 -> 1234.56
        cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
      } else {
        // US format: 1,234.56 -> 1234.56
        cleaned = cleaned.replaceAll(',', '');
      }
    } else if (cleaned.contains(',')) {
      cleaned = cleaned.replaceAll(',', '.');
    }
    
    double? parsed = double.tryParse(cleaned);
    if (parsed == null) return 0.0;
    return roundMoney(parsed);
  }

  static String formatEuro(double amount) {
    bool isNegative = amount < 0;
    amount = amount.abs();
    
    // Arrotonda correttamente a due decimali usando toStringAsFixed
    String fixed = amount.toStringAsFixed(2); // e.g. '1234567.89'
    List<String> parts = fixed.split('.');
    String intStr = parts[0];
    String decStr = parts[1];
    
    // Aggiungi i punti per le migliaia
    String formattedInt = '';
    for (int i = 0; i < intStr.length; i++) {
      if (i > 0 && (intStr.length - i) % 3 == 0) {
        formattedInt += '.';
      }
      formattedInt += intStr[i];
    }
    
    String result = formattedInt + ',' + decStr;
    return '€ ' + (isNegative ? '-' : '') + result;
  }

  static String formatNumber(double amount) {
    // formatNumber historically used for other stuff, we can just return EU format
    // or string without symbol
    final f = NumberFormat('#,##0.00', 'it_IT');
    return f.format(amount);
  }

  static double roundMoney(double value) {
    double mod = pow(10.0, 2).toDouble();
    return ((value * mod).round().toDouble() / mod);
  }
}
