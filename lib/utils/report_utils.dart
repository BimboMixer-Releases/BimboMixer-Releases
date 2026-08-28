import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReportUtils {
  static Future<DateTimeRange?> showDateRangeFilterDialog(BuildContext context) async {
    return showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(
        start: DateTime(DateTime.now().year, DateTime.now().month, 1),
        end: DateTime.now(),
      ),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.blueAccent,
              onPrimary: Colors.white,
              surface: Color(0xFF1E1E24),
              onSurface: Colors.white,
            ), dialogTheme: DialogThemeData(backgroundColor: const Color(0xFF1E1E24)),
          ),
          child: child!,
        );
      },
    );
  }

  static String formatDateRangeText(DateTimeRange range, [String format = 'dd/MM/yyyy']) {
    final dateFormat = DateFormat(format);
    return '${dateFormat.format(range.start)} - ${dateFormat.format(range.end)}';
  }

  static bool isDateInRange(String dateStr, DateTimeRange range) {
    try {
      final date = DateTime.parse(dateStr);
      final start = DateTime(range.start.year, range.start.month, range.start.day);
      final end = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59);
      return date.isAfter(start.subtract(const Duration(seconds: 1))) && 
             date.isBefore(end.add(const Duration(seconds: 1)));
    } catch (e) {
      return false;
    }
  }
}
