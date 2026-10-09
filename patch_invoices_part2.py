# -*- coding: utf-8 -*-
import sys

with open('lib/screens/invoices_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Make the title bigger
content = content.replace("Text('Fatture', style: TextStyle(color: Colors.white))", "Text('FATTURE', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 1.2))")

# Remove the add button from AppBar
remove_btn = '''            IconButton(
              icon: Icon(Icons.add, color: Colors.blueAccent),
              onPressed: () => _showInvoiceDialog())'''
content = content.replace(remove_btn, "")

with open('lib/screens/invoices_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
