import re

with open('lib/screens/memo_events_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix _updateMemoStatus
old_update = """  Future<void> _updateMemoStatus(Map<String, dynamic> memo, String newStatus) async {
    final theme = context.read<AppThemeProvider>();
    
    if (newStatus != 'PAGATO') {"""

new_update = """  bool _isTransferring = false;
  Future<void> _updateMemoStatus(Map<String, dynamic> memo, String newStatus) async {
    if (_isTransferring) return;
    final theme = context.read<AppThemeProvider>();
    
    if (newStatus != 'PAGATO' && newStatus != 'SALDATO') {"""

content = content.replace(old_update, new_update)

old_confirm = """    if (!confirm) {
      _loadData();
      return;
    }"""
new_confirm = """    if (!confirm) {
      _loadData();
      return;
    }
    setState(() => _isTransferring = true);
    try {"""
content = content.replace(old_confirm, new_confirm)


bad_payment = """      final paymentData = <String, dynamic>{
        'type': transactionType == 'ENTRATA' ? 'IN' : 'OUT',
        'amount': memo['amount'],
        'date': memo['date_type'] == 'SINGOLA' ? memo['date'] : memo['date_from'],
        'customer_id': memo['customer_id'],
        'category_id': memo['category_id'],
        'service_id': memo['service_id'],
        'payment_method': memo['payment_method'],
        'notes': memo['notes'],
        'title': memo['title'],
        'attachments': memo['attachments'],
      };"""

good_payment = """      final paymentData = <String, dynamic>{
        'type': transactionType == 'ENTRATA' ? 'IN' : 'OUT',
        'amount': memo['amount'],
        'date': memo['date_type'] == 'SINGOLA' ? memo['date'] : memo['date_from'],
        'customer_id': memo['customer_id'],
        'category_id': memo['category_id'],
        'service_id': memo['service_id'],
        'payment_method': memo['payment_method'],
        'notes': memo['notes'],
        'title': memo['title'],
        'description': memo['title'],
        'status': 'PAID',
        'attachments': memo['attachments'],
      };"""
content = content.replace(bad_payment, good_payment)

bad_invoice = """      final invoiceData = <String, dynamic>{
        'id': (memo['invoice_number']?.toString().isNotEmpty == true) ? memo['invoice_number'] : DateTime.now().millisecondsSinceEpoch.toString(),
        'amount': memo['amount'],
        'date': memo['invoice_date']?.toString().isNotEmpty == true ? memo['invoice_date'] : DateUtilsApp.toDbDate(DateTime.now().toIso8601String(), theme.dateFormat),
        'customer_id': memo['customer_id'],
        'category_id': memo['category_id'],
        'service_id': memo['service_id'],
        'notes': memo['notes'],
        'title': memo['title'],
        'attachments': memo['attachments'],
      };"""

good_invoice = """      final invoiceData = <String, dynamic>{
        'id': (memo['invoice_number']?.toString().isNotEmpty == true) ? memo['invoice_number'] : DateTime.now().millisecondsSinceEpoch.toString(),
        'amount': memo['amount'],
        'date': memo['invoice_date']?.toString().isNotEmpty == true ? memo['invoice_date'] : DateUtilsApp.toDbDate(DateTime.now().toIso8601String(), theme.dateFormat),
        'status': 'PAID',
        'customer_id': memo['customer_id'],
        'category_id': memo['category_id'],
        'service_id': memo['service_id'],
        'notes': memo['notes'],
        'title': memo['title'],
        'attachments': memo['attachments'],
      };"""
content = content.replace(bad_invoice, good_invoice)

old_finally = """    await _dbHelper.deleteMemoEvent(memo['id']);
    _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Memo trasferito in ${type == 'MOVIMENTO' ? 'Movimenti' : 'Fatture'}'),
      ));
    }
  }"""
new_finally = """    await _dbHelper.deleteMemoEvent(memo['id']);
    _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Memo trasferito in ${type == 'MOVIMENTO' ? 'Movimenti' : 'Fatture'}'),
      ));
    }
    } finally {
      if (mounted) setState(() => _isTransferring = false);
    }
  }"""
content = content.replace(old_finally, new_finally)

content = content.replace("'PAGATO'", "'SALDATO'")
content = content.replace("Nuova programmazione", "Nuovo pagamento")

with open('lib/screens/memo_events_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
