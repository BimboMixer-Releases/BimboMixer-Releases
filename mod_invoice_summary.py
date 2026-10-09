# -*- coding: utf-8 -*-
with open('lib/screens/invoice_summary_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

target1 = '''  String? _customerName;
  String? _categoryName;
  String? _serviceName;'''

replacement1 = '''  Map<String, dynamic>? _customerData;
  String? _categoryName;
  String? _serviceName;'''
content = content.replace(target1, replacement1)

target2 = '''      if (custId != null) {
        final custList = await _dbHelper.getCustomers();
        final c = custList.cast<Map<String,dynamic>>().firstWhere((e) => e['id'].toString() == custId.toString(), orElse: () => {});
        _customerName = c['name'];
      }'''

replacement2 = '''      if (custId != null) {
        final custList = await _dbHelper.getCustomers();
        final c = custList.cast<Map<String,dynamic>>().firstWhere((e) => e['id'].toString() == custId.toString(), orElse: () => {});
        _customerData = c;
      }'''
content = content.replace(target2, replacement2)

target3 = '''    final displayId = 'N. 2026/0' + _data!['id'].toString().padLeft(3, '0');'''

replacement3 = '''    final invoiceNumber = _data!['number']?.toString() ?? '';
    final displayId = invoiceNumber.isNotEmpty ? 'N. ' + invoiceNumber : 'N. ' + _data!['id'].toString();'''
content = content.replace(target3, replacement3)

target4 = '''                                          Widget col = Column(
                                          children: [
                                            _buildRowItem(Icons.person_outline, 'Cliente', _customerName ?? '-'),
                                            const Divider(color: Color(0xFFE5E0F1), height: 24),
                                            _buildRowItem(Icons.layers_outlined, 'Importo', NumberFormat.currency(locale: 'it_IT', symbol: '€ ').format(amount), isAmount: true),
                                            const Divider(color: Color(0xFFE5E0F1), height: 24),
                                            _buildRowItem(Icons.credit_card_outlined, 'Metodo di pagamento', _data!['payment_method']?.toString() ?? '-'),
                                            const Divider(color: Color(0xFFE5E0F1), height: 24),
                                            _buildRowItem(Icons.folder_outlined, 'Categoria', _categoryName ?? '-'),
                                            const Divider(color: Color(0xFFE5E0F1), height: 24),
                                            _buildRowItem(Icons.receipt_long_outlined, 'Prestazione', _serviceName ?? '-'),'''

replacement4 = '''                                          Widget col = Column(
                                          children: [
                                            _buildRowItem(Icons.person_outline, 'Cliente', _customerData?['name']?.toString() ?? '-'),
                                            const Divider(color: Color(0xFFE5E0F1), height: 24),
                                            if (_customerData?['addressStreet']?.toString().isNotEmpty == true || _customerData?['addressCity']?.toString().isNotEmpty == true) ...[
                                              _buildRowItem(Icons.location_on_outlined, 'Indirizzo', ',   '.replaceAll(RegExp(r'\s+'), ' ').trim()),
                                              const Divider(color: Color(0xFFE5E0F1), height: 24),
                                            ],
                                            if (_customerData?['vatNumber']?.toString().isNotEmpty == true) ...[
                                              _buildRowItem(Icons.badge_outlined, 'P.IVA/C.F.', _customerData!['vatNumber'].toString()),
                                              const Divider(color: Color(0xFFE5E0F1), height: 24),
                                            ],
                                            if (_customerData?['sdiCode']?.toString().isNotEmpty == true) ...[
                                              _buildRowItem(Icons.markunread_mailbox_outlined, 'Codice SDI', _customerData!['sdiCode'].toString()),
                                              const Divider(color: Color(0xFFE5E0F1), height: 24),
                                            ],
                                            _buildRowItem(Icons.layers_outlined, 'Importo', NumberFormat.currency(locale: 'it_IT', symbol: '€ ').format(amount), isAmount: true),
                                            const Divider(color: Color(0xFFE5E0F1), height: 24),
                                            _buildRowItem(Icons.credit_card_outlined, 'Metodo di pagamento', _data!['payment_method']?.toString() ?? '-'),'''
content = content.replace(target4, replacement4)

with open('lib/screens/invoice_summary_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)