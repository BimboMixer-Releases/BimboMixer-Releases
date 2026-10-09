# -*- coding: utf-8 -*-
import sys

with open('lib/screens/invoice_summary_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# I want to find the exact text: "N. " or something like that.
target = "'N. \'"
if target in content:
    replacement = "'N. \'"
    content = content.replace(target, replacement)
    print("Replaced invoice number!")
else:
    target2 = "N. \"
    if target2 in content:
        content = content.replace(target2, "N. \")
        print("Replaced invoice number (2)!")
    else:
        print("Could not find invoiceId usage for N.")

with open('lib/screens/invoice_summary_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
