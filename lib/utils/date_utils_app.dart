import 'package:intl/intl.dart';

class DateUtilsApp {
  /// Default formato italiano richiesto
  static const String defaultFormat = 'dd/MM/yyyy';

  /// Prende la data nel formato yyyy-MM-dd del DB e restituisce la stringa adatta alla schermata in base al formato
  static String formatDbDate(String? dbDate, [String dateFormat = defaultFormat]) {
    if (dbDate == null || dbDate.isEmpty) return '';
    try {
      final dt = DateTime.parse(dbDate);
      return DateFormat(dateFormat).format(dt);
    } catch (_) {
      return dbDate; // Fallback
    }
  }

  /// Prende l'input dell'utente (mostrato nel textField) e lo converte in yyyy-MM-dd per il DB
  static String toDbDate(String? displayDate, [String dateFormat = defaultFormat]) {
    if (displayDate == null || displayDate.isEmpty) return '';
    try {
      final dt = DateFormat(dateFormat).parseStrict(displayDate);
      return DateFormat('yyyy-MM-dd').format(dt);
    } catch (_) {
      return displayDate; // Fallback
    }
  }
}
