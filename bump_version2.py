with open('lib/screens/changelog_screen.dart', 'r', encoding='utf-8') as f:
    changelog = f.read()

new_entry = """    {
      'version': '1.8.93',
      'date': '06/10/2026',
      'changes': [
        'Fix: Formattazione degli importi (es. 1.500,00) ora salvata correttamente in Agenda, Fatture, Preventivi e Pagamenti',
        'Fix: Risoluzione sovrascritture concorrenti e generazione codici progressivi sui Pagamenti (Firestore transactions)'
      ]
    },"""

insert_pos = changelog.find('final List<Map<String, dynamic>> _changelogs = [')
if insert_pos != -1:
    insert_pos = changelog.find('[', insert_pos) + 1
    changelog = changelog[:insert_pos] + '\n' + new_entry + changelog[insert_pos:]
    with open('lib/screens/changelog_screen.dart', 'w', encoding='utf-8') as f:
        f.write(changelog)
    print("Aggiornato changelog")