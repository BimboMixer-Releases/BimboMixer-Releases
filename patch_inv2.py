import re

def migrate_build():
    with open('lib/screens/payments_screen.dart', 'r', encoding='utf-8') as f:
        payments_content = f.read()
        
    start_p = payments_content.find('Widget build(BuildContext context) {')
    end_p = payments_content.find('String _formatDate(') # copy until the end to get all UI helpers!
    
    if start_p == -1 or end_p == -1:
        print("Could not find payments build method")
        return
        
    build_p = payments_content[start_p:end_p]
    
    build_i = build_p
    build_i = build_i.replace('_filteredPayments', '_filteredInvoices')
    build_i = build_i.replace('Invoices & Transactions', 'Fatture')
    build_i = build_i.replace('_loadPayments', '_loadData')
    build_i = build_i.replace('_editPayment', '_showInvoiceDialog')
    
    # Remove the "+" button from the top right (Nuovo Movimento -> remove entirely)
    # The user said "Togli il + della nuova fattura" and replace it with a filter? 
    # But payments_screen already has the PopupMenuButton filter inside the glass container!
    # Let's just remove the Nuovo Movimento button.
    # It is an ElevatedButton.icon with Icons.add.
    add_btn_pattern = r'ElevatedButton\.icon\([^;]+?\),'
    build_i = re.sub(add_btn_pattern, '', build_i)
    
    # Replace columns:
    build_i = build_i.replace("Text('Invoice ID'", "Text('Numero'")
    build_i = build_i.replace("Text('Client'", "Text('Cliente'")
    build_i = build_i.replace("Text('Date'", "Text('Data'")
    build_i = build_i.replace("Text('Description'", "Text('Note'")
    build_i = build_i.replace("Text('Amount'", "Text('Importo'")
    build_i = build_i.replace("Text('Status'", "Text('Stato'")
    build_i = build_i.replace("Text('Action'", "Text('Azioni'")
    
    # Replace row data mapping:
    # final invoiceId = (p['id'] ?? '').toString(); -> final number = (p['number'] ?? '').toString();
    build_i = build_i.replace("final invoiceId = (p['id'] ?? '').toString();", "final invoiceId = (p['number'] ?? '').toString();")
    
    # We will replace the entire row rendering to match invoices!
    
    with open('lib/screens/invoices_screen.dart', 'r', encoding='utf-8') as f:
        inv_content = f.read()
        
    start_i = inv_content.find('Widget build(BuildContext context) {')
    end_i = inv_content.find('void _showCustomerSearchDialog')
    
    if start_i != -1 and end_i != -1:
        new_inv_content = inv_content[:start_i] + build_i + '\n  ' + inv_content[end_i:]
        with open('lib/screens/invoices_screen.dart', 'w', encoding='utf-8') as f:
            f.write(new_inv_content)
        print("Invoices patched!")

migrate_build()
