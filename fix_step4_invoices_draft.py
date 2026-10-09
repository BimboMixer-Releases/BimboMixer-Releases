import re

with open('lib/screens/invoices_screen.dart', 'r', encoding='utf-8') as f:
    code = f.read()

pattern = re.compile(
    r'(if \(effectiveId == null\) \{\s*final newId = await _dbHelper\.insertInvoice\(data\);\s*data\[\'id\'\] = newId; // capture new ID for movement link\s*\} else \{\s*await _dbHelper\.updateInvoice\(data\);\s*\})',
    re.DOTALL
)

replacement = r'''try {
                            \1
                            // ... movement logic continues here, ma dobbiamo wrappare anche quello? 
                            // Meglio includere anche il wantsMovement nel try-catch? No, wantsMovement Ã¨ gia trycatched internamente.
                            // Lasciamo il pop alla fine.'''

# It's better to just manually inject try catch in invoices_screen.dart since there's complex wantsMovement logic.
