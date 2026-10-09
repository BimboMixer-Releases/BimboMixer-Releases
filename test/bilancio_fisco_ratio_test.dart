import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:contabile_app/screens/bilancio_fisco_screen.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('it_IT'));

  test('rapporto normale con formato italiano', () {
    expect(formatFiscoRatio(50), '50%');
    expect(formatFiscoRatio(12.5), '12,5%');
  });
  test('oltre 100%', () {
    expect(formatFiscoRatio(1234.5), '1.234,5%');
  });
  test('entrate zero: non calcolabile (neutro)', () {
    expect(formatFiscoRatio(null), 'N/D');
  });
}
