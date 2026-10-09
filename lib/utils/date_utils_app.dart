import 'package:intl/intl.dart';

class DateUtilsApp {
  /// Default formato italiano richiesto
  static const String defaultFormat = 'dd/MM/yyyy';

  /// Prende la data dal DB in vari formati (yyyy-MM-dd, dd/MM/yyyy, ecc) e restituisce sempre dd/MM/yyyy
  static String formatDbDate(String? dbDate, [String dateFormat = defaultFormat]) {
    if (dbDate == null || dbDate.isEmpty) return '';
    dbDate = dbDate.trim();
    
    // Try ISO or yyyy-MM-dd
    try {
      final dt = DateTime.parse(dbDate);
      return DateFormat(dateFormat).format(dt);
    } catch (_) {}
    
    // Try dd/MM/yyyy
    try {
      final dt = DateFormat('dd/MM/yyyy').parseStrict(dbDate);
      return DateFormat(dateFormat).format(dt);
    } catch (_) {}
    
    try {
      final dt = DateFormat('d/M/yyyy').parseLoose(dbDate);
      return DateFormat(dateFormat).format(dt);
    } catch (_) {}

    // Try dd-MM-yyyy
    try {
      final dt = DateFormat('dd-MM-yyyy').parseStrict(dbDate);
      return DateFormat(dateFormat).format(dt);
    } catch (_) {}
    
    return dbDate; // Fallback
  }

  /// Prende l'input dell'utente (mostrato nel textField) e lo converte in dd/MM/yyyy per il DB
  static String toDbDate(String? displayDate, [String dateFormat = defaultFormat]) {
    if (displayDate == null || displayDate.isEmpty) return '';
    try {
      // Potrebbe già arrivare dal picker, o essere parsata. 
      // Noi salviamo su DB preferibilmente in yyyy-MM-dd per l'ordinamento se è testuale, ma 
      // il codice esistente forzava 'dd/MM/yyyy'. Manteniamo 'dd/MM/yyyy' per retrocompatibilità
      // o usiamo formatDbDate per assicurarci sia giusto.
      return formatDbDate(displayDate, 'dd/MM/yyyy');
    } catch (_) {
      return displayDate; // Fallback
    }
  }
}