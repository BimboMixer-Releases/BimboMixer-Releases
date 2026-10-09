import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:contabile_app/utils/date_utils_app.dart';
import 'package:contabile_app/widgets/glass_date_range_picker.dart';

class ReportUtils {
  static Future<DateTimeRange?> showDateRangeFilterDialog(BuildContext context) async {
    return GlassDateRangePicker.show(
      context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(
        start: DateTime(DateTime.now().year, DateTime.now().month, 1),
        end: DateTime.now(),
      ),
    );
  }

  static String formatDateRangeText(DateTimeRange range, [String format = 'dd/MM/yyyy']) {
    final dateFormat = DateFormat(format);
    return '${dateFormat.format(range.start)} - ${dateFormat.format(range.end)}';
  }

  static bool isDateInRange(String dateStr, DateTimeRange range) {
    try {
      final formatted = DateUtilsApp.formatDbDate(dateStr, 'yyyy-MM-dd');
      final date = DateTime.parse(formatted);
      final start = DateTime(range.start.year, range.start.month, range.start.day);
      final end = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59);
      return date.isAfter(start.subtract(const Duration(seconds: 1))) && 
             date.isBefore(end.add(const Duration(seconds: 1)));
    } catch (e) {
      return false;
    }
  }
}
