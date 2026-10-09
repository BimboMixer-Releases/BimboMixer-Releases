with open('lib/screens/payments_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

target = '''    Future<void> _downloadSinglePayment(Map<String, dynamic> p) async {
      final dt = p['date']?.toString() ?? '';
      final amountDouble = double.tryParse(p['amount']?.toString() ?? '0') ?? 0.0;
      final imp = CurrencyUtils.formatEuro(amountDouble);
      final cliente = p['customer_name']?.toString() ?? 'N/D';
      final descr = p['description']?.toString() ?? 'N/D';
      final tipo = p['type']?.toString() ?? 'N/D';
      final metodo = p['payment_method']?.toString() ?? 'N/D';
      
      await PDFReportService.generateAndDownloadReport(
        title: 'Dettaglio Movimento',
        headers: ['Campo', 'Valore'],
        data: [
          ['Data', dt],
          ['Cliente', cliente],
          ['Descrizione', descr],
          ['Importo', imp],
          ['Tipo', tipo],
          ['Metodo', metodo],
        ],
      );
    }'''

replacement = '''    Future<void> _downloadSinglePayment(Map<String, dynamic> p) async {
      final dt = p['date']?.toString() ?? '';
      final amountDouble = double.tryParse(p['amount']?.toString() ?? '0') ?? 0.0;
      final imp = CurrencyUtils.formatEuro(amountDouble);
      final cliente = p['customer_name']?.toString() ?? 'N/D';
      final descr = p['description']?.toString() ?? 'N/D';
      final tipo = p['type']?.toString() ?? 'N/D';
      final metodo = p['payment_method']?.toString() ?? 'N/D';
      
      try {
        await PDFReportService.generateAndDownloadReport(
          title: 'Dettaglio Movimento',
          headers: ['Campo', 'Valore'],
          data: [
            ['Data', dt],
            ['Cliente', cliente],
            ['Descrizione', descr],
            ['Importo', imp],
            ['Tipo', tipo],
            ['Metodo', metodo],
          ],
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PDF generato e scaricato con successo.'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Errore durante il salvataggio del PDF: '), backgroundColor: Colors.red),
          );
        }
      }
    }'''

content = content.replace(target, replacement)

with open('lib/screens/payments_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
