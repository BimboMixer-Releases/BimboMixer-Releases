import 'dart:io';

void main() {
  var file = File('lib/screens/payments_screen.dart');
  var content = file.readAsStringSync();

  // Add SortUtils import correctly
  if (!content.contains('sort_utils.dart')) {
    content = content.replaceFirst(
      "import '../providers/app_theme_provider.dart';",
      "import '../providers/app_theme_provider.dart';\nimport '../utils/sort_utils.dart';"
    );
  }

  // Remove unused _formatInvoiceId
  var formatIdRegex = RegExp(r'String _formatInvoiceId\(int index\) \{.*?\n  \}', dotAll: true);
  content = content.replaceAll(formatIdRegex, "");

  file.writeAsStringSync(content);
  print("Fixed SortUtils and _formatInvoiceId in payments_screen");
}