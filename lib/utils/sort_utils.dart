import 'package:intl/intl.dart';

int compareDates(String? d1, String? d2, {bool descending = true}) {
  DateTime parseDate(String? d) {
    if (d == null || d.isEmpty) return DateTime(1970);
    // Usa DateFormat per provare dd/MM/yyyy prima
    try {
      return DateFormat('dd/MM/yyyy').parseStrict(d);
    } catch (_) {}
    try {
      return DateTime.parse(d);
    } catch (_) {
      return DateTime(1970);
    }
  }

  final dt1 = parseDate(d1);
  final dt2 = parseDate(d2);
  
  if (descending) {
    return dt2.compareTo(dt1);
  } else {
    return dt1.compareTo(dt2);
  }
}