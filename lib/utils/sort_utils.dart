import 'date_utils_app.dart';

int compareDates(String? d1, String? d2, {bool descending = true}) {
  final dt1 = DateUtilsApp.tryParseDate(d1) ?? DateTime(1970);
  final dt2 = DateUtilsApp.tryParseDate(d2) ?? DateTime(1970);

  if (descending) {
    return dt2.compareTo(dt1);
  } else {
    return dt1.compareTo(dt2);
  }
}