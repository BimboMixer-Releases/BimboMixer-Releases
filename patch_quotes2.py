with open('lib/screens/quotes_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

if "import 'package:contabile_app/utils/auth_fallback.dart';" not in content:
    content = content.replace("import 'package:flutter/material.dart';", 
                              "import 'package:flutter/material.dart';\nimport 'package:contabile_app/utils/auth_fallback.dart';")

import re
old_auth = r"final bioService = BiometricService\(\);\s*bool isAuth = await bioService\.authenticate\(reason: 'Autenticati per eliminare il preventivo'\);\s*if \(!isAuth\) \{\s*if \(mounted\) \{\s*ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*const SnackBar\(\s*content: Text\('Autenticazione fallita\. Eliminazione annullata\.'\),\s*backgroundColor: Colors\.red,\s*\),\s*\);\s*\}\s*return;\s*\}"

new_auth = """final bioService = BiometricService();
      bool isAuth = false;
      if (await bioService.isBiometricAvailable()) {
        isAuth = await bioService.authenticate(reason: 'Autenticati per eliminare il preventivo');
      }
      if (!isAuth && mounted) {
        isAuth = await promptForPasswordFallback(context);
      }
      if (!isAuth) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Autenticazione fallita o annullata. Eliminazione annullata.'), backgroundColor: Colors.red),
          );
        }
        return;
      }"""

content = re.sub(old_auth, new_auth, content, flags=re.DOTALL)

with open('lib/screens/quotes_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("Quotes patched")