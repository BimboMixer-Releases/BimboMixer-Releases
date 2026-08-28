import 'package:flutter_test/flutter_test.dart';
import 'package:contabile_app/utils/currency_utils.dart';
import 'package:intl/intl.dart';

void main() {
  group('CurrencyUtils Tests', () {
    test('parseCurrency should parse standard formats correctly', () {
      expect(CurrencyUtils.parseCurrency('1200.50'), 1200.50);
      expect(CurrencyUtils.parseCurrency('1200,50'), 1200.50);
      expect(CurrencyUtils.parseCurrency('1.200,50'), 1200.50);
      expect(CurrencyUtils.parseCurrency('1 200,50'), 1200.50);
      expect(CurrencyUtils.parseCurrency('1200'), 1200.0);
    });

    test('parseCurrency should handle invalid inputs gracefully', () {
      expect(CurrencyUtils.parseCurrency(null), 0.0);
      expect(CurrencyUtils.parseCurrency(''), 0.0);
      expect(CurrencyUtils.parseCurrency('abc'), 0.0);
      expect(CurrencyUtils.parseCurrency('12abc.50'), 12.50);
    });

    test('formatEuro should format with correct decimals using Italian locale', () {
      final formatter = NumberFormat.currency(locale: 'it_IT', symbol: '€', decimalDigits: 2);
      expect(CurrencyUtils.formatEuro(1200.5), formatter.format(1200.5));
      expect(CurrencyUtils.formatEuro(1200), formatter.format(1200));
      expect(CurrencyUtils.formatEuro(0), formatter.format(0));
      expect(CurrencyUtils.formatEuro(-50.25), formatter.format(-50.25));
    });

    test('roundMoney should round to 2 decimals accurately', () {
      expect(CurrencyUtils.roundMoney(10.005), 10.01);
      expect(CurrencyUtils.roundMoney(10.004), 10.00);
      expect(CurrencyUtils.roundMoney(0.1 + 0.2), 0.30);
    });
  });
}
