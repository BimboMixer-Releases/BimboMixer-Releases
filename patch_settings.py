# -*- coding: utf-8 -*-
import sys

with open('lib/screens/settings_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Add import
import_target = "import 'reports_screen.dart';"
import_replacement = "import 'reports_screen.dart';\nimport 'users_screen.dart';"
content = content.replace(import_target, import_replacement)

# Add section
section_target = "            // -- SEZIONE 2: Migrazione ------------------------------"
new_section = '''            // -- SEZIONE AMMINISTRATORI ------------------------------
            _sectionHeader(LucideIcons.users, 'Amministratori e Sicurezza'),
            SizedBox(height: 12),
            GlassContainer(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Gestisci gli account amministratore, cambia le password e abilita il login tramite Fingerprint (impronta digitale/riconoscimento facciale).',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const UsersScreen()),
                      );
                    },
                    icon: Icon(LucideIcons.shield),
                    label: Text('GESTIONE AMMINISTRATORI'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.currentColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 24),

'''

if section_target in content:
    content = content.replace(section_target, new_section + section_target)
else:
    # If the exact comment dashes are different
    print("Could not find section_target")
    # Let's search for just the text
    backup_target = "// ── SEZIONE 2: Migrazione"
    
    if "SEZIONE 2: Migrazione" in content:
        # We find the index of "SEZIONE 2: Migrazione" and insert before the preceding "            //"
        idx = content.find("SEZIONE 2: Migrazione")
        idx = content.rfind("            //", 0, idx)
        
        content = content[:idx] + new_section + content[idx:]
        print("Replaced using fallback!")
    else:
        sys.exit(1)

with open('lib/screens/settings_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print('Done!')
