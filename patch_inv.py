import re

def migrate_build():
    with open('lib/screens/payments_screen.dart', 'r', encoding='utf-8') as f:
        payments_content = f.read()

    start_p = payments_content.find('Widget build(BuildContext context) {')
    end_p = payments_content.find('  Widget _buildTopHeaderBar() {')
    
    if start_p == -1 or end_p == -1:
        print("Could not find payments build method")
        return
        
    build_p = payments_content[start_p:end_p]
    
    # Transformations for invoices
    build_i = build_p
    build_i = build_i.replace('_filteredPayments', '_filteredInvoices')
    build_i = build_i.replace('Movimenti', 'Fatture')
    build_i = build_i.replace('_loadPayments', '_loadInvoices')
    build_i = build_i.replace('_editPayment', '_editInvoice')
    build_i = build_i.replace('_deletePayment', '_deleteInvoice')
    
    # We need to map the columns properly
    # In payments, columns are:
    # invoiceId, clientName, Date, Description, Amount, Status, Action
    # Wait, the Table Rows List mapping:
    #           final invoiceId = (p['id'] ?? '').toString();
    #           final clientName = (p['customer_name'] ?? '').toString();
    #           final dateStr = _formatDate(p['date']);
    #           final service = (p['service_name'] ?? '').toString();
    #           final amount = (p['amount'] ?? '0.00').toString();
    
    # In invoices, the variables might be different?
    # Let's check what the old invoices screen used in its ListView.
    
    with open('lib/screens/invoices_screen.dart', 'r', encoding='utf-8') as f:
        inv_content = f.read()
        
    start_i = inv_content.find('Widget build(BuildContext context) {')
    end_i = inv_content.find('  void _showCustomerSearchDialog')
    
    if start_i != -1 and end_i != -1:
        new_inv_content = inv_content[:start_i] + build_i + '\n' + inv_content[end_i:]
        with open('lib/screens/invoices_screen.dart', 'w', encoding='utf-8') as f:
            f.write(new_inv_content)
        print("Invoices patched!")

migrate_build()
