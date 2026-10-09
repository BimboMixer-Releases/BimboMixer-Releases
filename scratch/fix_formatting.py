# -*- coding: utf-8 -*-
import os
import re
import codecs

currency_utils_code = '''import 'package:intl/intl.dart';
import 'dart:math';

class CurrencyUtils {
  static final NumberFormat _euroFormat = NumberFormat.currency(
    locale: 'it_IT',
    symbol: '€',
    decimalDigits: 2,
  );

  static final NumberFormat _numberFormat = NumberFormat(
    '#,##0.00',
    'it_IT',
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
    if (cleaned.contains('.') && cleaned.contains(',')) {
      if (cleaned.indexOf('.') < cleaned.indexOf(',')) {
        cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
      } else {
        cleaned = cleaned.replaceAll(',', '');
      }
    } else if (cleaned.contains(',')) {
      cleaned = cleaned.replaceAll(',', '.');
    }
    cleaned = cleaned.replaceAll(RegExp(r'[^0-9\.-]'), '');
    double? parsed = double.tryParse(cleaned);
    if (parsed == null) return 0.0;
    return roundMoney(parsed);
  }

  static String formatEuro(double amount) {
    return _euroFormat.format(amount);
  }

  static String formatNumber(double amount) {
    return _numberFormat.format(amount);
  }

  static double roundMoney(double value) {
    double mod = pow(10.0, 2).toDouble();
    return ((value * mod).round().toDouble() / mod);
  }
}
'''
with codecs.open('lib/utils/currency_utils.dart', 'w', 'utf-8') as f:
    f.write(currency_utils_code)

print('currency_utils.dart updated.')
