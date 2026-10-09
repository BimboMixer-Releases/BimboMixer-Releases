import re

with open('lib/screens/quotes_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

if "import 'package:contabile_app/utils/auth_fallback.dart';" not in content:
    content = content.replace("import 'package:flutter/material.dart';", 
                              "import 'package:flutter/material.dart';\nimport 'package:contabile_app/utils/auth_fallback.dart';")

old_auth = """      if (confirm == true) {
        final bioService = BiometricService();
        bool isAuth = await bioService.authenticate(reason: 'Autenticati per eliminare il preventivo');
        
        if (!isAuth) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Autenticazione fallita. Eliminazione annullata.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
        
        await _dbHelper.deleteQuote(id);"""

new_auth = """      if (confirm == true) {
        final bioService = BiometricService();
        bool isAuth = false;
        
        // Prova biometria se disponibile
        if (await bioService.isBiometricAvailable()) {
          isAuth = await bioService.authenticate(reason: 'Autenticati per eliminare il preventivo');
        }
        
        // Se biometria fallisce o non disponibile (es. emulatore), fallback su password
        if (!isAuth) {
          if (mounted) {
             isAuth = await promptForPasswordFallback(context);
          }
        }
        
        if (!isAuth) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Autenticazione fallita o annullata. Eliminazione annullata.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
        
        await _dbHelper.deleteQuote(id);"""

content = content.replace(old_auth, new_auth)

with open('lib/screens/quotes_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("Quotes patched")