import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:contabile_app/providers/app_theme_provider.dart';
import 'package:contabile_app/widgets/glass_date_picker.dart';

class DatePickerUtil {
  static Future<void> selectDate(
      BuildContext context, TextEditingController controller) async {
    final theme = Provider.of<AppThemeProvider>(context, listen: false);
    final dateFormat = theme.dateFormat;
    DateTime initial = DateTime.now();
    if (controller.text.isNotEmpty) {
      try {
        initial = DateFormat(dateFormat).parseStrict(controller.text);
      } catch (_) {
        try {
          initial = DateFormat('dd/MM/yyyy').parseStrict(controller.text);
        } catch (_) {}
      }
    }
    final picked = await GlassDatePicker.show(
      context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      controller.text = DateFormat(dateFormat).format(picked);
    }
  }
}
