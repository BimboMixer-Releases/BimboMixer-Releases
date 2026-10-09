import re

with open('lib/screens/quotes_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add import
if 'package:syncfusion_flutter_pdf/pdf.dart' not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:syncfusion_flutter_pdf/pdf.dart';")

# 2. Update _extractDataFromPdf to use syncfusion
old_extract_start = '''    // Try reading raw text from PDF file to find patterns
    try {
      final bytes = file.readAsBytesSync();
      final text = String.fromCharCodes(bytes);'''

new_extract_start = '''    // Try reading raw text from PDF file to find patterns
    try {
      final bytes = file.readAsBytesSync();
      final document = PdfDocument(inputBytes: bytes);
      final text = PdfTextExtractor(document).extractText();
      document.dispose();'''

content = content.replace(old_extract_start, new_extract_start)

# 3. Update Total regex to better match 'totale di € 1300'
old_total_regex = '''      // 3. Check for Total (Ã¢â€šÂ¬ 1.200,00 o Totale: 1200)
      final totalMatch = RegExp(
        r'(?:Totale|Total|Importo|EUR|Ã¢â€šÂ¬)\s*:?\s*([\d\.\,]+)',
        caseSensitive: false,
      ).firstMatch(text);'''

new_total_regex = '''      // 3. Check for Total (€ 1.200,00 o Totale: 1200 o totale di € 1300)
      final totalMatch = RegExp(
        r'(?:Totale|Total|Importo|EUR|€|totale\s+di\s*€?)\s*:?\s*([\d\.\,]+)',
        caseSensitive: false,
      ).firstMatch(text);'''

content = content.replace(old_total_regex, new_total_regex)

# 4. Update Client regex to better capture the name after 'Spett.le' until newline
old_client_regex = '''      // 4. Check for Client
      final clientMatch = RegExp(
        r'(?:Spett\.le|Cliente|Client|A:)\s*:?\s*([A-Za-z0-9\s\.\,\-]+)',
        caseSensitive: false,
      ).firstMatch(text);'''

new_client_regex = '''      // 4. Check for Client
      final clientMatch = RegExp(
        r'(?:Spett\.le|Cliente|Client|A:)\s*:?\s*([^\n]+)',
        caseSensitive: false,
      ).firstMatch(text);'''

content = content.replace(old_client_regex, new_client_regex)

# 5. Fix € symbol in items loop (Ã¢â€šÂ¬ was an encoding artifact)
content = content.replace("l.contains('Ã¢â€šÂ¬')", "l.contains('€')")
content = content.replace("[^\\w\\s\\(\\)\\Ã¢â€šÂ¬\\.\\,]", "[^\\w\\s\\(\\)€\\.\\,]")

with open('lib/screens/quotes_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
