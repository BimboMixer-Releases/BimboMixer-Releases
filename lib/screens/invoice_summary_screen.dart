import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:contabile_app/database/database_helper.dart';
import 'package:contabile_app/providers/app_theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:contabile_app/utils/date_utils_app.dart';
import 'package:contabile_app/utils/security_utils.dart';
import 'package:contabile_app/screens/payment_summary_screen.dart'; // To reuse HoverEditButton

class InvoiceSummaryScreen extends StatefulWidget {
  final Map<String, dynamic> invoice;
  final Function(Map<String, dynamic>) onEdit;

  const InvoiceSummaryScreen({super.key, required this.invoice, required this.onEdit});

  @override
  State<InvoiceSummaryScreen> createState() => _InvoiceSummaryScreenState();
}

class _InvoiceSummaryScreenState extends State<InvoiceSummaryScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  String? _customerName;
  List<String> _attachments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final pData = widget.invoice;
    final custId = pData['customer_id'];
    if (custId != null) {
      final custList = await _dbHelper.getCustomers();
      final c = custList.cast<Map<String,dynamic>>().firstWhere(
        (e) => e['id'].toString() == custId.toString(),
        orElse: () => {}
      );
      _customerName = c['name'];
    }

    if (pData['attachments'] != null) {
      try {
        if (pData['attachments'] is String) {
          _attachments = List<String>.from(jsonDecode(pData['attachments']));
        } else if (pData['attachments'] is List) {
          _attachments = List<String>.from(pData['attachments']);
        }
      } catch (_) {}
    }
    
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0E21),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final pData = widget.invoice;
    final amount = double.tryParse(pData['amount']?.toString() ?? '0') ?? 0.0;
    final theme = Provider.of<AppThemeProvider>(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Logo
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      SizedBox(width: 8),
                      Image.asset('assets/images/logo.png', height: 40, errorBuilder: (ctx, err, trace) {
                        return Icon(Icons.receipt_long, color: Colors.blueAccent, size: 40);
                      }),
                      SizedBox(width: 12),
                      Text(
                        'Riepilogo Fattura',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  // Bottone Modifica Illuminato
                  HoverEditButton(
                    onTap: () async {
                      bool authorized = await SecurityUtils.requireAdminAuth(context);
                      if (!authorized || !context.mounted) return;
                      
                      Navigator.pop(context);
                      widget.onEdit(widget.invoice);
                    },
                  ),
                ],
              ),
            ),
            
            // Corpo "Fattura"
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Text(
                          'FATTURA COMMERCIALE',
                          style: TextStyle(color: Colors.black87, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                        ),
                      ),
                      SizedBox(height: 32),
                      _buildInfoRow('Numero Fattura', pData['number']?.toString() ?? '-'),
                      const Divider(),
                      _buildInfoRow('Data Emissione', DateUtilsApp.formatDbDate(pData['date']?.toString(), theme.dateFormat)),
                      const Divider(),
                      _buildInfoRow('Data Operazione/Evento', DateUtilsApp.formatDbDate(pData['event_date']?.toString(), theme.dateFormat)),
                      const Divider(),
                      _buildInfoRow('Cliente', _customerName ?? '-'),
                      if ((pData['client_vat'] ?? '').toString().isNotEmpty) ...[
                        const Divider(),
                        _buildInfoRow('Partita IVA', pData['client_vat']),
                      ],
                      if ((pData['client_tax_code'] ?? '').toString().isNotEmpty) ...[
                        const Divider(),
                        _buildInfoRow('Codice Fiscale', pData['client_tax_code']),
                      ],
                      if ((pData['client_address'] ?? '').toString().isNotEmpty) ...[
                        const Divider(),
                        _buildInfoRow('Indirizzo', '${pData['client_address']} ${pData['client_city'] ?? ''} ${pData['client_province'] ?? ''} ${pData['client_zip'] ?? ''}'),
                      ],
                      if ((pData['client_pec'] ?? '').toString().isNotEmpty) ...[
                        const Divider(),
                        _buildInfoRow('PEC', pData['client_pec']),
                      ],
                      if ((pData['client_sdi'] ?? '').toString().isNotEmpty) ...[
                        const Divider(),
                        _buildInfoRow('SDI', pData['client_sdi']),
                      ],
                      if ((pData['client_phone'] ?? '').toString().isNotEmpty) ...[
                        const Divider(),
                        _buildInfoRow('Telefono', pData['client_phone']),
                      ],
                      if ((pData['client_email'] ?? '').toString().isNotEmpty) ...[
                        const Divider(),
                        _buildInfoRow('Email', pData['client_email']),
                      ],
                      const Divider(),
                      _buildInfoRow('Codice IVA', pData['vat_code']?.toString() ?? '-'),
                      const Divider(),
                      _buildInfoRow('Importo', '€ ${amount.toStringAsFixed(2)}', isAmount: true),
                      const Divider(),
                      _buildInfoRow('Stato', pData['status']?.toString() ?? 'PENDING'),
                      const Divider(),
                      SizedBox(height: 16),
                      Text('Note:', style: TextStyle(color: Colors.black54, fontSize: 14, fontWeight: FontWeight.w600)),
                      SizedBox(height: 8),
                      Text(
                        pData['notes']?.toString() ?? 'Nessuna nota presente.',
                        style: TextStyle(color: Colors.black87, fontSize: 16),
                      ),
                      SizedBox(height: 32),
                      if (_attachments.isNotEmpty) ...[
                        Text('Allegati:', style: TextStyle(color: Colors.black54, fontSize: 14, fontWeight: FontWeight.w600)),
                        SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _attachments.map((path) => Chip(
                            label: Text(path.split('/').last, style: TextStyle(fontSize: 12)),
                            avatar: Icon(Icons.attachment, size: 16),
                          )).toList(),
                        ),
                      ]
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isAmount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(color: Colors.black54, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: isAmount ? Colors.blue[800] : Colors.black87,
                fontSize: isAmount ? 20 : 16,
                fontWeight: isAmount ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


