import 'package:flutter_test/flutter_test.dart';
import 'package:contabile_app/utils/currency_utils.dart';

void main() {
  group('CurrencyUtils.formatEuro', () {
    test('Formattazione zero', () {
      expect(CurrencyUtils.formatEuro(0), '€ 0,00');
    });

    test('Formattazione positivi base', () {
      expect(CurrencyUtils.formatEuro(150.50), '€ 150,50');
      expect(CurrencyUtils.formatEuro(999.99), '€ 999,99');
    });

    test('Formattazione migliaia con punto', () {
      expect(CurrencyUtils.formatEuro(1000), '€ 1.000,00');
      expect(CurrencyUtils.formatEuro(10000), '€ 10.000,00');
      expect(CurrencyUtils.formatEuro(1234567.89), '€ 1.234.567,89');
    });

    test('Formattazione negativi', () {
      expect(CurrencyUtils.formatEuro(-150.50), '€ -150,50');
      expect(CurrencyUtils.formatEuro(-10000), '€ -10.000,00');
      expect(CurrencyUtils.formatEuro(-1234567.89), '€ -1.234.567,89');
    });

    test('Arrotondamento decimali', () {
      expect(CurrencyUtils.formatEuro(10.004), '€ 10,00');
      expect(CurrencyUtils.formatEuro(10.005), '€ 10,01'); // verifica come si comporta l'arrotondamento
    });
  });
}
