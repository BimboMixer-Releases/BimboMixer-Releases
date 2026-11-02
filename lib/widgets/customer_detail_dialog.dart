import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../database/database_helper.dart';
import '../providers/app_theme_provider.dart';
import '../utils/app_colors.dart';
import '../utils/currency_utils.dart';
import '../utils/date_utils_app.dart';

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
    try {
      final customerId = widget.customer['id']?.toString() ?? '';
      final payments = customerId.isNotEmpty
          ? await _dbHelper.getPaymentsByCustomer(customerId)
          : <Map<String, dynamic>>[];
      if (mounted) {
        setState(() {
          _payments = payments;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _payments = [];
          _isLoading = false;
        });
      }
    }
  }

  String _formatAddress(Map<String, dynamic> c) {
    final street = (c['address_street'] ?? c['address'] ?? '').toString().trim();
    final zip = (c['address_zip'] ?? '').toString().trim();
    final city = (c['address_city'] ?? '').toString().trim();
    final prov = (c['address_province'] ?? '').toString().trim();
    final parts = [
      if (street.isNotEmpty) street,
      if (zip.isNotEmpty || city.isNotEmpty)
        [zip, city].where((s) => s.isNotEmpty).join(' '),
      if (prov.isNotEmpty) '($prov)',
    ];
    return parts.isEmpty ? '-' : parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<AppThemeProvider>(context).currentColors;
    final c = widget.customer;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 720,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.panelBackground,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.primary.withValues(alpha: 0.1),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                  border: const Border(
                    bottom: BorderSide(color: AppColors.cardBorder),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: theme.primary.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        LucideIcons.user,
                        color: theme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c['name']?.toString() ?? 'Sconosciuto',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (c['type'] != null)
                            Text(
                              c['type'].toString().toUpperCase(),
                              style: TextStyle(
                                color: theme.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 560;
                    final anagraficaSection = SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ANAGRAFICA',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildDetailRow(
                            LucideIcons.mail,
                            'Email',
                            (c['email']?.toString().isNotEmpty == true)
                                ? c['email'].toString()
                                : '-',
                          ),
                          _buildDetailRow(
                            LucideIcons.phone,
                            'Telefono',
                            (c['phone']?.toString().isNotEmpty == true)
                                ? c['phone'].toString()
                                : '-',
                          ),
                          _buildDetailRow(
                            LucideIcons.mapPin,
                            'Indirizzo',
                            _formatAddress(c),
                          ),
                          _buildDetailRow(
                            LucideIcons.building,
                            'P.IVA',
                            (c['vat_number']?.toString().isNotEmpty == true)
                                ? c['vat_number'].toString()
                                : '-',
                          ),
                          _buildDetailRow(
                            LucideIcons.fileText,
                            'Cod. Fiscale',
                            ((c['tax_code'] ?? c['fiscal_code'])
                                        ?.toString()
                                        .isNotEmpty ==
                                    true)
                                ? (c['tax_code'] ?? c['fiscal_code']).toString()
                                : '-',
                          ),
                          _buildDetailRow(
                            LucideIcons.hash,
                            'Cod. Destinatario',
                            ((c['sdi_code'] ?? c['unique_code'])
                                        ?.toString()
                                        .isNotEmpty ==
                                    true)
                                ? (c['sdi_code'] ?? c['unique_code']).toString()
                                : '-',
                          ),
                          if (c['notes'] != null &&
                              c['notes'].toString().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            const Text(
                              'NOTE',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              c['notes'].toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );

                    final operationsSection = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(20).copyWith(bottom: 8),
                          child: const Text(
                            'ULTIME OPERAZIONI',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          child: _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : _payments.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'Nessuna operazione trovata',
                                        style: TextStyle(color: Colors.white54),
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.all(20)
                                          .copyWith(top: 0),
                                      itemCount: _payments.length,
                                      itemBuilder: (context, index) {
                                        final p = _payments[index];
                                        final isIn = p['type'] == 'IN';
                                        final amt = CurrencyUtils.parseCurrency(
                                          p['amount']?.toString(),
                                        );
                                        final label = (p['service_name']
                                                    ?.toString()
                                                    .isNotEmpty ==
                                                true)
                                            ? p['service_name'].toString()
                                            : ((p['title']
                                                        ?.toString()
                                                        .isNotEmpty ==
                                                    true)
                                                ? p['title'].toString()
                                                : (isIn ? 'Incasso' : 'Spesa'));
                                        return Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 12,
                                          ),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.white
                                                .withValues(alpha: 0.05),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: (isIn
                                                          ? AppColors
                                                              .incomeGreen
                                                          : AppColors
                                                              .expenseRed)
                                                      .withValues(alpha: 0.1),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  isIn
                                                      ? LucideIcons.arrowDown
                                                      : LucideIcons.arrowUp,
                                                  color: isIn
                                                      ? AppColors.incomeGreen
                                                      : AppColors.expenseRed,
                                                  size: 16,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      label,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    Text(
                                                      DateUtilsApp.formatDbDate(
                                                        p['date']?.toString(),
                                                      ),
                                                      style: const TextStyle(
                                                        color: Colors.white54,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '${isIn ? '+' : '-'} ${CurrencyUtils.formatEuro(amt)}',
                                                style: TextStyle(
                                                  color: isIn
                                                      ? AppColors.incomeGreen
                                                      : AppColors.expenseRed,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                        ),
                      ],
                    );

                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: anagraficaSection),
                          Container(width: 1, color: AppColors.cardBorder),
                          Expanded(flex: 3, child: operationsSection),
                        ],
                      );
                    }

                    return Column(
                      children: [
                        Expanded(flex: 5, child: anagraficaSection),
                        Container(height: 1, color: AppColors.cardBorder),
                        Expanded(flex: 5, child: operationsSection),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white54, size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
