with open('lib/screens/changelog_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

target = '''    {
      'version': '1.8.90','''

replacement = '''    {
      'version': '1.8.91',
      'date': '06 Ottobre 2026',
      'changes': [
        'Aggiunto ordinamento Fatture per Numero e Data',
        'Sincronizzazione in tempo reale dell\\'ordinamento movimenti con la Dashboard',
        'Risolto problema di visibilità del tasto stampa PDF su schermi ristretti',
        'Corretto blocco scorrimento della sezione movimenti nella visualizzazione estesa',
        'Risolto errore di connessione Firebase per assenza index in Report e Idee',
        'Aggiunta notifica visiva per conferma scaricamento PDF singolo',
        'Aggiornato formato ID nella ricevuta pagamento',
      ]
    },
    {
      'version': '1.8.90','''

content = content.replace(target, replacement)

with open('lib/screens/changelog_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
