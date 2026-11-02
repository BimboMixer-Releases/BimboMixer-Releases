import 'package:intl/intl.dart';

class DateUtilsApp {
  /// Default formato italiano richiesto
  static const String defaultFormat = 'dd/MM/yyyy';

  static DateTime _normalizeYear(DateTime dt) {
    if (dt.year >= 0 && dt.year < 100) {
      return DateTime(
        dt.year + 2000,
        dt.month,
        dt.day,
        dt.hour,
        dt.minute,
        dt.second,
      );
    }
    return dt;
  }

  /// Tenta il parsing di una data in qualsiasi formato supportato (ISO, dd/MM/yyyy, d/M/yyyy, dd-MM-yyyy).
  static DateTime? tryParseDate(String? raw) {
    if (raw == null) return null;
    final cleaned = raw.trim();
    if (cleaned.isEmpty) return null;

    // 1. dd/MM/yyyy o d/M/yyyy
    if (cleaned.contains('/')) {
      try {
        return _normalizeYear(DateFormat('dd/MM/yyyy').parseStrict(cleaned));
      } catch (_) {}
      try {
        return _normalizeYear(DateFormat('d/M/yyyy').parseLoose(cleaned));
      } catch (_) {}
    }

    // 2. ISO o yyyy-MM-dd
    try {
      return _normalizeYear(DateTime.parse(cleaned));
    } catch (_) {}

    // 3. dd-MM-yyyy o d-M-yyyy
    if (cleaned.contains('-')) {
      try {
        return _normalizeYear(DateFormat('dd-MM-yyyy').parseStrict(cleaned));
      } catch (_) {}
      try {
        return _normalizeYear(DateFormat('d-M-yyyy').parseLoose(cleaned));
      } catch (_) {}
    }

    return null;
  }

  /// Prende la data dal DB in vari formati (yyyy-MM-dd, dd/MM/yyyy, ecc) e restituisce il formato richiesto
  static String formatDbDate(String? dbDate, [String dateFormat = defaultFormat]) {
    if (dbDate == null || dbDate.trim().isEmpty) return '';
    final parsed = tryParseDate(dbDate);
    if (parsed != null) {
      return DateFormat(dateFormat).format(parsed);
    }
    return dbDate.trim();
  }

  /// Prende l'input dell'utente (mostrato nel textField) e lo converte in dd/MM/yyyy per il DB
  static String toDbDate(String? displayDate, [String dateFormat = defaultFormat]) {
    if (displayDate == null || displayDate.trim().isEmpty) return '';
    final parsed = tryParseDate(displayDate);
    if (parsed != null) {
      return DateFormat('dd/MM/yyyy').format(parsed);
    }
    return displayDate.trim();
  }
}