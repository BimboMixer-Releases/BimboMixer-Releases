import re

with open('lib/screens/invoices_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

target = r'''          actions: \[
            IconButton\(
              icon: Icon\(Icons.print, color: Colors.blueAccent\),
              tooltip: 'Esporta in PDF','''

replacement = '''          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.sort, color: Colors.blueAccent),
              tooltip: 'Ordina',
              color: const Color(0xFF16192B),
              onSelected: (val) {
                setState(() {
                  if (val == 'Numero (Decrescente)') {
                    _sortType = InvoiceSortType.number;
                    _sortAscending = false;
                  } else if (val == 'Numero (Crescente)') {
                    _sortType = InvoiceSortType.number;
                    _sortAscending = true;
                  } else if (val == 'Data Piu Recente') {
                    _sortType = InvoiceSortType.date;
                    _sortAscending = false; 
                  } else if (val == 'Data Meno Recente') {
                    _sortType = InvoiceSortType.date;
                    _sortAscending = true;
                  }
                });
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'Numero (Decrescente)', child: Text('Numero (Decrescente)', style: TextStyle(color: Colors.white))),
                const PopupMenuItem(value: 'Numero (Crescente)', child: Text('Numero (Crescente)', style: TextStyle(color: Colors.white))),
                const PopupMenuItem(value: 'Data Piu Recente', child: Text('Data Più Recente', style: TextStyle(color: Colors.white))),
                const PopupMenuItem(value: 'Data Meno Recente', child: Text('Data Meno Recente', style: TextStyle(color: Colors.white))),
              ],
            ),
            IconButton(
              icon: Icon(Icons.print, color: Colors.blueAccent),
              tooltip: 'Esporta in PDF','''

content = re.sub(target, replacement, content)

with open('lib/screens/invoices_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
