import re
p = 'lib/screens/dashboard_screen.dart'
s = open(p, encoding='utf-8', newline='').read()

on_old = re.compile(r"onSelected: \(value\) \{\r\n\s*if \(value == 'Fattura'\) \{.*?\r\n              \},\r\n              itemBuilder: \(context\) => \[.*?\r\n              \],", re.S)
new = """onSelected: (value) {
                if (value == 'Scadenza') {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => const MemoEventsScreen(openForm: true)));
                } else if (value == 'Tasse') {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => const DeadlinesScreen(openDialog: true)));
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: 'Scadenza', child: Row(children: [Icon(Icons.event, color: Colors.orangeAccent), SizedBox(width:8), Text('Nuova Scadenza', style: TextStyle(color: Colors.white))])),
                PopupMenuItem(value: 'Tasse', child: Row(children: [Icon(Icons.account_balance, color: Colors.redAccent), SizedBox(width:8), Text('Pagamento Tasse', style: TextStyle(color: Colors.white))])),
              ],""".replace('\n', '\r\n')
s, n = on_old.subn(lambda m: new, s)
print('menus replaced', n)
open(p, 'w', encoding='utf-8', newline='').write(s)

p = 'lib/screens/memo_events_screen.dart'
s = open(p, encoding='utf-8', newline='').read()
print(s[s.index('class MemoEventsScreen'):s.index('class _MemoEventsScreenState')])
