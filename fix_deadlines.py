import re

with open('lib/screens/deadlines_screen.dart', 'r', encoding='utf-8') as f:
    code = f.read()

# Trova _togglePaid
toggle_paid_pattern = re.compile(
    r'(Future<void> _togglePaid\(Map<String, dynamic> d\) async \{)(.*?)(await _dbHelper\.updateDeadline\(updated\);)',
    re.DOTALL
)

replacement = r'''\1
    final oldStatus = d['status'];
    final newStatus = oldStatus == 'PAID' ? 'PENDING' : 'PAID';
    final updated = Map<String, dynamic>.from(d)..['status'] = newStatus;
    
    if (newStatus == 'PAID') {
       bool wantsMovement = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E24),
            title: Text('Scadenza Pagata', style: TextStyle(color: Colors.white)),
            content: Text('Vuoi registrare automaticamente questo pagamento in uscita nei Movimenti?', style: TextStyle(color: Colors.white70)),
            actions: [
               TextButton(onPressed: () => Navigator.pop(c, false), child: Text('No', style: TextStyle(color: Colors.white54))),
               TextButton(onPressed: () => Navigator.pop(c, true), child: Text('Sì', style: TextStyle(color: Colors.blueAccent))),
            ],
          )
       ) ?? false;

       if (wantsMovement) {
          try {
             await _dbHelper.insertPayment({
                'type': 'OUT',
                'amount': double.tryParse(d['amount']?.toString() ?? '0') ?? 0.0,
                'date': d['date_from'] ?? d['date'] ?? DateTime.now().toIso8601String().split('T')[0],
                'title': 'Pagamento Scadenza: ',
                'notes': 'Generato automaticamente da Scadenze',
             });
             if (mounted) {
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Movimento registrato in uscita.')));
             }
          } catch (e) {
             print('Errore inserimento movimento: ');
          }
       }
    }

    \3'''

new_code = toggle_paid_pattern.sub(replacement, code)
with open('lib/screens/deadlines_screen.dart', 'w', encoding='utf-8') as f:
    f.write(new_code)
