# -*- coding: utf-8 -*-
import sys

with open('lib/screens/dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("for (var inv in invoices) {", "for (var inv in _invoices) {")
content = content.replace("for (var p in globalPayments) {", "for (var p in _globalRecentPayments) {")

with open('lib/screens/dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print('Done!')
