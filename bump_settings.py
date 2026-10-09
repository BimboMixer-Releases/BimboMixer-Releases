import re

with open('lib/screens/settings_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Update version string
content = re.sub(r'String _currentVersion = ''1\.8\.\d+''', 'String _currentVersion = ''1.8.91''', content)
content = re.sub(r'String _buildNumber = ''110''', 'String _buildNumber = ''111''', content)

# Add to changelog
changelog_new = '''  final List<Map<String, String>> _changelog = [
    {
      'version': '1.8.91',
      'date': '06/10/2026',
      'changes': '• Introdotto ordinamento avanzato Fatture e Movimenti per data\\n• L\\'ordinamento dei movimenti ora si riflette automaticamente sulla Dashboard in tempo reale\\n• Sistemata la visibilità del tasto PDF (Stampante) per gli schermi verticali (smartphone)\\n• Risolto blocco scorrimento della sezione movimenti nella visuale orizzontale (landscape)\\n• Corretto l\\'errore di connessione (index_error) nella sezione Segnalazioni/Idee\\n• Aggiunto avviso di successo/errore per lo scaricamento PDF del singolo movimento\\n• Visualizzazione ottimizzata dell\\'ID movimento nella schermata della singola ricevuta',
    },
    {'''

content = content.replace('''  final List<Map<String, String>> _changelog = [
    {''', changelog_new)

with open('lib/screens/settings_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
