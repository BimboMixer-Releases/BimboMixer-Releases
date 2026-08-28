import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:contabile_app/database/database_helper.dart';
import 'package:contabile_app/providers/app_theme_provider.dart';
import 'package:contabile_app/utils/date_utils_app.dart';
import 'package:contabile_app/utils/security_utils.dart';
import 'package:provider/provider.dart';
import 'package:contabile_app/screens/payment_form_screen.dart';

class PaymentSummaryScreen extends StatefulWidget {
  final String paymentId;

  const PaymentSummaryScreen({super.key, required this.paymentId});

  @override
  State<PaymentSummaryScreen> createState() => _PaymentSummaryScreenState();
}

class _PaymentSummaryScreenState extends State<PaymentSummaryScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  Map<String, dynamic>? _paymentData;
  String? _customerName;
  String? _categoryName;
  String? _serviceName;
  List<String> _attachments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final pData = await _dbHelper.getPaymentById(widget.paymentId);
    if (pData != null) {
      _paymentData = pData;
      
      final custId = pData['customer_id'];
      if (custId != null) {
        final custList = await _dbHelper.getCustomers();
        final c = custList.cast<Map<String,dynamic>>().firstWhere((e) => e['id'].toString() == custId.toString(), orElse: () => {});
        _customerName = c['name'];
      }

      final catId = pData['category_id'];
      if (catId != null) {
        final catList = await _dbHelper.getCategories();
        final c = catList.cast<Map<String,dynamic>>().firstWhere((e) => e['id'].toString() == catId.toString(), orElse: () => {});
        _categoryName = c['name'];
      }

      final srvId = pData['service_id'];
      if (srvId != null) {
        final srvList = await _dbHelper.getServiceTypes();
        final s = srvList.cast<Map<String,dynamic>>().firstWhere((e) => e['id'].toString() == srvId.toString(), orElse: () => {});
        _serviceName = s['name'];
      }

      if (pData['attachments'] != null) {
        try {
          _attachments = List<String>.from(jsonDecode(pData['attachments']));
        } catch (_) {}
      }
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impossibile aprire l\'allegato')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<AppThemeProvider>(context);

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0E21),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_paymentData == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0E21),
        appBar: AppBar(title: Text('Errore'), backgroundColor: Colors.transparent),
        body: Center(child: Text('Movimento non trovato', style: TextStyle(color: Colors.white))),
      );
    }

    final isIN = _paymentData!['type'] == 'IN';
    final amount = double.tryParse(_paymentData!['amount']?.toString() ?? '0') ?? 0.0;
    
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
                        return Icon(Icons.account_balance_wallet, color: Colors.blueAccent, size: 40);
                      }),
                      SizedBox(width: 12),
                      Text(
                        'Riepilogo Movimento',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  HoverEditButton(
                    onTap: () async {
                      bool authorized = await SecurityUtils.requireAdminAuth(context);
                      if (!authorized || !context.mounted) return;
                      
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PaymentFormScreen(paymentId: widget.paymentId, isReadOnly: false),
                        ),
                      );
                      _loadData(); // Ricarica dopo la modifica
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
                          isIN ? 'RICEVUTA DI INCASSO' : 'RICEVUTA DI PAGAMENTO',
                          style: TextStyle(color: Colors.black87, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                        ),
                      ),
                      SizedBox(height: 32),
                      _buildInfoRow('Data Registrazione', DateUtilsApp.formatDbDate(_paymentData!['date']?.toString(), theme.dateFormat)),
                      const Divider(),
                      _buildInfoRow('Cliente', _customerName ?? '-'),
                      const Divider(),
                      _buildInfoRow('Importo', '€ ${amount.toStringAsFixed(2)}', isAmount: true, isIN: isIN),
                      const Divider(),
                      _buildInfoRow('Metodo di Pagamento', _paymentData!['payment_method']?.toString() ?? '-'),
                      const Divider(),
                      _buildInfoRow('Categoria', _categoryName ?? '-'),
                      const Divider(),
                      _buildInfoRow('Prestazione', _serviceName ?? '-'),
                      const Divider(),
                      SizedBox(height: 16),
                      Text('Note:', style: TextStyle(color: Colors.black54, fontSize: 14, fontWeight: FontWeight.w600)),
                      SizedBox(height: 8),
                      Text(
                        _paymentData!['notes']?.toString() ?? 'Nessuna nota presente.',
                        style: TextStyle(color: Colors.black87, fontSize: 16),
                      ),
                      SizedBox(height: 32),
                      if (_attachments.isNotEmpty) ...[
                        Text('Allegati:', style: TextStyle(color: Colors.black54, fontSize: 14, fontWeight: FontWeight.w600)),
                        SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _attachments.map((path) => ActionChip(
                            label: Text(path.split('/').last, style: TextStyle(fontSize: 12)),
                            avatar: Icon(Icons.attachment, size: 16),
                            onPressed: () => _launchUrl(path),
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

  Widget _buildInfoRow(String label, String value, {bool isAmount = false, bool isIN = false}) {
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
                color: isAmount ? (isIN ? Colors.green[700] : Colors.red[700]) : Colors.black87,
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

class HoverEditButton extends StatefulWidget {
  final VoidCallback onTap;
  
  const HoverEditButton({super.key, required this.onTap});

  @override
  State<HoverEditButton> createState() => _HoverEditButtonState();
}

class _HoverEditButtonState extends State<HoverEditButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _isHovering ? Colors.blueAccent : Colors.white10,
            borderRadius: BorderRadius.circular(8),
            boxShadow: _isHovering ? [
              const BoxShadow(color: Colors.blueAccent, blurRadius: 10, spreadRadius: 2)
            ] : [],
          ),
          child: Row(
            children: [
              Icon(Icons.edit, color: _isHovering ? Colors.white : Colors.white70, size: 18),
              SizedBox(width: 8),
              Text(
                'Modifica',
                style: TextStyle(
                  color: _isHovering ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



