import 'dart:io';

void main() {
  final file = File('lib/screens/dashboard_screen.dart');
  var content = file.readAsStringSync();
  content = content.replaceAll('â‚¬', '€');
  content = content.replaceAll('â€¢', '•');
  file.writeAsStringSync(content);
  print('Fixed encoding in dashboard_screen.dart');
}
