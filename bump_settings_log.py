with open('lib/screens/settings_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

target = '''                    _buildChangelogItem('Aggiunto filtro data ascendente/discendente su Movimenti e Fatture',),'''

replacement = '''                    _buildChangelogItem('Dashboard aggiornata in real-time all\\'ordinamento movimenti',),
                    _buildChangelogItem('Aggiunto ordinamento Fatture (Numero e Data)',),
                    _buildChangelogItem('Fix visibilità tasto PDF movimenti su dispositivi mobili',),
                    _buildChangelogItem('Risolto blocco scorrimento orizzontale sezione movimenti',),
                    _buildChangelogItem('Corretto errore di connessione in area Report e Idee',),
                    _buildChangelogItem('Aggiunto avviso di successo per lo scaricamento PDF singolo',),
                    _buildChangelogItem('Migliorato display ID nel riepilogo pagamento',),
                    _buildChangelogItem('Aggiunto filtro data ascendente/discendente su Movimenti e Fatture',),'''

content = content.replace(target, replacement)

with open('lib/screens/settings_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
