import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../database/database_helper.dart';
import '../utils/app_colors.dart';
import '../providers/app_theme_provider.dart';
import 'package:provider/provider.dart';

class CustomerDetailDialog extends StatefulWidget {
  final Map<String, dynamic> customer;

  const CustomerDetailDialog({super.key, required this.customer});

  @override
  State<CustomerDetailDialog> createState() => _CustomerDetailDialogState();
}

class _CustomerDetailDialogState extends State<CustomerDetailDialog> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _payments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    final allPayments = await _dbHelper.getPayments();
    setState(() {
      _payments = allPayments.where((p) => p['customer_id']?.toString() == widget.customer['id']?.toString()).toList();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<AppThemeProvider>(context).currentColors;
    final c = widget.customer;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: 600,
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: AppColors.panelBackground,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.primary.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: theme.primary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(LucideIcons.user, color: theme.primary, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c['name'] ?? 'Sconosciuto',
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        if (c['type'] != null)
                          Text(
                            c['type'].toString().toUpperCase(),
                            style: TextStyle(color: theme.primary, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Colonna Sinistra (Anagrafica)
                  Expanded(
                    flex: 2,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('ANAGRAFICA', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          _buildDetailRow(LucideIcons.mail, 'Email', c['email'] ?? '-'),
                          _buildDetailRow(LucideIcons.phone, 'Telefono', c['phone'] ?? '-'),
                          _buildDetailRow(LucideIcons.mapPin, 'Indirizzo', c['address'] ?? '-'),
                          _buildDetailRow(LucideIcons.building, 'P.IVA', c['vat_number'] ?? '-'),
                          _buildDetailRow(LucideIcons.fileText, 'Cod. Fiscale', c['tax_code'] ?? '-'),
                          _buildDetailRow(LucideIcons.hash, 'Cod. Destinatario', c['sdi_code'] ?? '-'),
                          const SizedBox(height: 24),
                          if (c['notes'] != null && c['notes'].toString().isNotEmpty) ...[
                            const Text('NOTE', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text(c['notes'], style: const TextStyle(color: Colors.white, fontSize: 14)),
                          ]
                        ],
                      ),
                    ),
                  ),
                  
                  Container(width: 1, color: AppColors.cardBorder),

                  // Colonna Destra (Operazioni)
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(24).copyWith(bottom: 8),
                          child: const Text('ULTIME OPERAZIONI', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        Expanded(
                          child: _isLoading 
                            ? const Center(child: CircularProgressIndicator())
                            : _payments.isEmpty
                                ? const Center(child: Text('Nessuna operazione trovata', style: TextStyle(color: Colors.white54)))
                                : ListView.builder(
                                    padding: const EdgeInsets.all(24).copyWith(top: 0),
                                    itemCount: _payments.length,
                                    itemBuilder: (context, index) {
                                      final p = _payments[index];
                                      final isIn = p['type'] == 'IN';
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 12),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.05),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: (isIn ? AppColors.incomeGreen : AppColors.expenseRed).withValues(alpha: 0.1),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                isIn ? LucideIcons.arrowDown : LucideIcons.arrowUp,
                                                color: isIn ? AppColors.incomeGreen : AppColors.expenseRed,
                                                size: 16,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(p['service_name'] ?? (isIn ? 'Incasso' : 'Spesa'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                                  Text(p['date'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                                ],
                                              ),
                                            ),
                                            Text(
                                              '€ ',
                                              style: TextStyle(
                                                color: isIn ? AppColors.incomeGreen : Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            )
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                        )
                      ],
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white54, size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 14)),
              ],
            ),
          )
        ],
      ),
    );
  }
}
