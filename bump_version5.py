import re
from datetime import datetime

with open('pubspec.yaml', 'r', encoding='utf-8') as f:
    pubspec = f.read()

match = re.search(r'version: 1\.8\.(\d+)\+(\d+)', pubspec)
if match:
    minor = int(match.group(1)) + 1
    build = int(match.group(2)) + 1
    new_version_str = f"version: 1.8.{minor}+{build}"
    pubspec = pubspec.replace(match.group(0), new_version_str)
    
    with open('pubspec.yaml', 'w', encoding='utf-8') as f:
        f.write(pubspec)
    
    new_version_code = f"1.8.{minor}"
    print(f"Aggiornato pubspec a {new_version_str}")

with open('lib/screens/settings_screen.dart', 'r', encoding='utf-8') as f:
    settings = f.read()
settings = re.sub(r"Versione: 1\.8\.\d+", f"Versione: {new_version_code}", settings)
with open('lib/screens/settings_screen.dart', 'w', encoding='utf-8') as f:
    f.write(settings)

with open('lib/screens/changelog_screen.dart', 'r', encoding='utf-8') as f:
    changelog = f.read()

today_str = datetime.now().strftime("%d/%m/%Y")
new_entry = f"""    {{
      'version': '{new_version_code}',
      'date': '{today_str}',
      'changes': [
        'Bugfix: Aggiunto fallback con password per l\\'eliminazione dei preventivi quando il lettore di impronte digitali non è disponibile (es. su emulatore o dispositivi senza PIN/biometria)',
      ]
    }},"""

insert_pos = changelog.find('final List<Map<String, dynamic>> _changelogs = [')
if insert_pos != -1:
    insert_pos = changelog.find('[', insert_pos) + 1
    changelog = changelog[:insert_pos] + '\n' + new_entry + changelog[insert_pos:]
    with open('lib/screens/changelog_screen.dart', 'w', encoding='utf-8') as f:
        f.write(changelog)
    print("Aggiornato changelog")