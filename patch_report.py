import re

with open('lib/utils/report_utils.dart', 'r', encoding='utf-8') as f:
    content = f.read()

if "import 'package:contabile_app/utils/date_utils_app.dart';" not in content:
    content = content.replace("import 'package:intl/intl.dart';", "import 'package:intl/intl.dart';\nimport 'package:contabile_app/utils/date_utils_app.dart';")

old_func = """  static bool isDateInRange(String dateStr, DateTimeRange range) {
    try {
      final date = DateTime.parse(dateStr);
      final start = DateTime(range.start.year, range.start.month, range.start.day);
      final end = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59);
      return date.isAfter(start.subtract(const Duration(seconds: 1))) && 
             date.isBefore(end.add(const Duration(seconds: 1)));
    } catch (e) {
      return false;
    }
  }"""

new_func = """  static bool isDateInRange(String dateStr, DateTimeRange range) {
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
  }"""

content = content.replace(old_func, new_func)

with open('lib/utils/report_utils.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("Fix report_utils")