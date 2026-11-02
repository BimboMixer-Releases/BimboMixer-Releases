import 'package:contabile_app/providers/app_theme_provider.dart';
import 'package:contabile_app/utils/date_utils_app.dart';
import 'package:contabile_app/widgets/glass_date_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class DatePickerUtil {
  static Future<void> selectDate(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final theme = Provider.of<AppThemeProvider>(context, listen: false);
    final dateFormat = theme.dateFormat;
    final firstDate = DateTime(2000);
    final lastDate = DateTime(2101);

    DateTime initial = DateUtilsApp.tryParseDate(controller.text) ?? DateTime.now();
    if (initial.isBefore(firstDate)) initial = firstDate;
    if (initial.isAfter(lastDate)) initial = lastDate;

    final picked = await GlassDatePicker.show(
      context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked != null) {
      controller.text = DateFormat(dateFormat).format(picked);
    }
  }
}
