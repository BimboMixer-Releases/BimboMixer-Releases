import re

files = [
    'lib/screens/calendar_screen.dart',
    'lib/screens/deadlines_screen.dart',
    'lib/screens/memo_form_screen.dart',
    'lib/screens/payment_form_screen.dart',
]

glass_import = "import 'package:contabile_app/widgets/glass_date_picker.dart';"
flutter_import = "import 'package:flutter/material.dart';"

for fpath in files:
    with open(fpath, 'r', encoding='utf-8') as f:
        content = f.read()

    if 'showDatePicker' not in content:
        print(f'Skip (nessun showDatePicker): {fpath}')
        continue

    # Aggiungi import se mancante
    if 'glass_date_picker' not in content:
        content = content.replace(flutter_import, flutter_import + '\n' + glass_import)

    # 1. Rimuovi blocco builder se presente
    content = re.sub(
        r',\s*builder:\s*\(context,\s*child\)\s*\{.*?\},\s*(?=\))',
        '',
        content,
        flags=re.DOTALL
    )
    
    # 2. Rinomina la chiamata
    content = content.replace('showDatePicker(', 'GlassDatePicker.show(')
    
    # 3. context: -> posizionale
    content = re.sub(r'GlassDatePicker\.show\(\s*context:\s*context,', 'GlassDatePicker.show(context,', content)

    with open(fpath, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f'Aggiornato: {fpath}')
