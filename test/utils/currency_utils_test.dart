import 'package:flutter_test/flutter_test.dart';
import 'package:contabile_app/utils/currency_utils.dart';
import 'package:intl/intl.dart';

void main() {
  group('CurrencyUtils.parseCurrency', () {
    group('formati standard', () {
      test('formato anglosassone con punto decimale', () {
        expect(CurrencyUtils.parseCurrency('1200.50'), 1200.50);
      });

      test('formato italiano con virgola decimale', () {
        expect(CurrencyUtils.parseCurrency('1200,50'), 1200.50);
      });

      test('formato italiano con punto migliaia e virgola decimale', () {
        expect(CurrencyUtils.parseCurrency('1.200,50'), 1200.50);
      });

      test('formato con spazio come separatore migliaia', () {
        expect(CurrencyUtils.parseCurrency('1 200,50'), 1200.50);
      });

      test('intero senza decimali', () {
        expect(CurrencyUtils.parseCurrency('1200'), 1200.0);
      });

      test('formato anglosassone con virgola migliaia e punto decimale', () {
        expect(CurrencyUtils.parseCurrency('1,234.56'), 1234.56);
      });

      test('valore con molte migliaia (milioni)', () {
        expect(CurrencyUtils.parseCurrency('1.234.567,89'), 1234567.89);
      });

      test('valore zero', () {
        expect(CurrencyUtils.parseCurrency('0'), 0.0);
      });

      test('valore zero virgola zero', () {
        expect(CurrencyUtils.parseCurrency('0,00'), 0.0);
      });

      test('solo decimali (es. 0,99)', () {
        expect(CurrencyUtils.parseCurrency('0,99'), 0.99);
      });

      test('un singolo centesimo', () {
        expect(CurrencyUtils.parseCurrency('0,01'), 0.01);
      });
    });

    group('input invalidi e edge cases', () {
      test('null restituisce 0.0', () {
        expect(CurrencyUtils.parseCurrency(null), 0.0);
      });

      test('stringa vuota restituisce 0.0', () {
        expect(CurrencyUtils.parseCurrency(''), 0.0);
      });

      test('stringa di soli spazi restituisce 0.0', () {
        expect(CurrencyUtils.parseCurrency('   '), 0.0);
      });

      test('testo non numerico restituisce 0.0', () {
        expect(CurrencyUtils.parseCurrency('abc'), 0.0);
      });

      test('testo misto: estrae i numeri', () {
        expect(CurrencyUtils.parseCurrency('12abc.50'), 12.50);
      });

      test('spazi iniziali e finali vengono gestiti', () {
        expect(CurrencyUtils.parseCurrency('  1200.50  '), 1200.50);
      });
    });

    group('divisioni', () {
      test('divisione semplice', () {
        expect(CurrencyUtils.parseCurrency('1300/2'), 650.0);
      });

      test('divisione che produce decimali', () {
        expect(CurrencyUtils.parseCurrency('100/3'), 33.33);
      });

      test('divisione per zero restituisce 0.0', () {
        expect(CurrencyUtils.parseCurrency('100/0'), 0.0);
      });

      test('divisione con virgola', () {
        expect(CurrencyUtils.parseCurrency('1000,50/2'), 500.25);
      });
    });

    group('valori negativi', () {
      test('negativo semplice', () {
        expect(CurrencyUtils.parseCurrency('-500'), -500.0);
      });

      test('negativo con decimali', () {
        expect(CurrencyUtils.parseCurrency('-1200.50'), -1200.50);
      });
    });

    group('valori molto grandi e molto piccoli', () {
      test('valore grande', () {
        expect(CurrencyUtils.parseCurrency('9999999.99'), 9999999.99);
      });

      test('valore molto piccolo', () {
        expect(CurrencyUtils.parseCurrency('0.01'), 0.01);
      });
    });
  });

  group('CurrencyUtils.formatEuro', () {
    final formatter = NumberFormat.currency(
      locale: 'it_IT',
      symbol: '\u20AC',
      decimalDigits: 2,
    );

    test('formatta importo positivo', () {
      expect(CurrencyUtils.formatEuro(1200.5), formatter.format(1200.5));
    });

    test('formatta intero', () {
      expect(CurrencyUtils.formatEuro(1200), formatter.format(1200));
    });

    test('formatta zero', () {
      expect(CurrencyUtils.formatEuro(0), formatter.format(0));
    });

    test('formatta importo negativo', () {
      expect(CurrencyUtils.formatEuro(-50.25), formatter.format(-50.25));
    });

    test('formatta importo con molti decimali (troncati a 2)', () {
      expect(CurrencyUtils.formatEuro(123.456), formatter.format(123.456));
    });

    test('formatta milioni', () {
      expect(CurrencyUtils.formatEuro(1234567.89), formatter.format(1234567.89));
    });

    test('contiene il simbolo euro', () {
      expect(CurrencyUtils.formatEuro(100), contains('\u20AC'));
    });
  });

  group('CurrencyUtils.roundMoney', () {
    test('arrotonda a 2 decimali per eccesso', () {
      expect(CurrencyUtils.roundMoney(10.005), 10.01);
    });

    test('arrotonda a 2 decimali per difetto', () {
      expect(CurrencyUtils.roundMoney(10.004), 10.00);
    });

    test('corregge errore IEEE 754 classico (0.1 + 0.2)', () {
      expect(CurrencyUtils.roundMoney(0.1 + 0.2), 0.30);
    });

    test('zero rimane zero', () {
      expect(CurrencyUtils.roundMoney(0.0), 0.0);
    });

    test('valore negativo', () {
      expect(CurrencyUtils.roundMoney(-10.005), -10.01);
    });

    test('valore gia arrotondato rimane invariato', () {
      expect(CurrencyUtils.roundMoney(1234.56), 1234.56);
    });

    test('molte cifre decimali', () {
      expect(CurrencyUtils.roundMoney(99.999), 100.0);
    });

    test('stress: somma ripetuta di 0.1 cento volte', () {
      double sum = 0.0;
      for (int i = 0; i < 100; i++) {
        sum += 0.1;
      }
      expect(CurrencyUtils.roundMoney(sum), 10.0);
    });

    test('stress: somma ripetuta di 0.01 mille volte', () {
      double sum = 0.0;
      for (int i = 0; i < 1000; i++) {
        sum += 0.01;
      }
      expect(CurrencyUtils.roundMoney(sum), 10.0);
    });
  });
}