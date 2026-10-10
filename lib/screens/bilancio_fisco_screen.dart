import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/glass_container.dart';
import 'package:provider/provider.dart';
import '../providers/app_theme_provider.dart';
import '../utils/currency_utils.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';

/// Formatta il rapporto in % (it_IT). null = non calcolabile.
String formatFiscoRatio(double? percent) {
  if (percent == null) return 'N/D';
  return '${NumberFormat('#,##0.##', 'it_IT').format(percent)}%';
}

class BilancioFiscoScreen extends StatefulWidget {
  const BilancioFiscoScreen({super.key});

  @override
  State<BilancioFiscoScreen> createState() => _BilancioFiscoScreenState();
}

class _BilancioFiscoScreenState extends State<BilancioFiscoScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isLoading = true;
  double _entrateFisco = 0;
  double _usciteFisco = 0;
  bool _hasError = false;

  /// Rapporto uscite/entrate in %. null = non calcolabile (entrate = 0).
  double? get _ratioPercent => _entrateFisco > 0 ? (_usciteFisco / _entrateFisco) * 100 : null;

  static String formatRatio(double? percent) => formatFiscoRatio(percent);
@override
  void initState() {
    super.initState();
    _loadDatiFisco();
  }

  Future<void> _loadDatiFisco() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final invoices = await _dbHelper.getInvoices();
      final payments = await _dbHelper.getPayments();

      double entrateF = 0;
      double usciteF = 0;
      Set<String> paidInvoiceIds = {};

      for (var inv in invoices) {
        String status = (inv['status'] ?? '').toString().toUpperCase();
        if (status == 'PAID' || status == 'INCASSATA' || status == 'SALDATO') {
          entrateF += double.tryParse(inv['amount']?.toString() ?? '0') ?? 0;
          if (inv['id'] != null) {
            paidInvoiceIds.add(inv['id'].toString());
          }
        }
      }

      for (var p in payments) {
        String status = (p['status'] ?? '').toString().toUpperCase();
        if (status == 'PAID' || status == 'SALDATO' || status == 'PAGATO') {
          String? invId = p['invoice_id']?.toString();
          if (invId != null && invId.isNotEmpty && paidInvoiceIds.contains(invId)) {
            continue; // Evita doppio conteggio
          }

          final method = (p['payment_method']?.toString() ?? '').toLowerCase();
          if (method.contains('carta') || method.contains('credito') || method.contains('bancomat')) {
            double amt = double.tryParse(p['amount']?.toString() ?? '0') ?? 0;
            if (p['type'] == 'IN') entrateF += amt;
            else if (p['type'] == 'OUT') usciteF += amt;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _entrateFisco = entrateF;
        _usciteFisco = usciteF;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppThemeProvider>();
    
    final ratio = _ratioPercent;
    Color ratioColor = Colors.grey;
    String? message;
    Color messageColor = Colors.white54;
    if (ratio == null) {
      message = _usciteFisco > 0
          ? 'Rapporto non calcolabile: nessuna entrata fiscale.'
          : 'Nessun movimento fiscale: rapporto non calcolabile.';
    } else if (_usciteFisco > _entrateFisco) {
      ratioColor = Colors.redAccent;
      message = 'ATTENZIONE: Uscite superiori alle entrate!';
      messageColor = Colors.redAccent;
    } else if (_usciteFisco > _entrateFisco * 0.8) {
      ratioColor = Colors.orangeAccent;
      message = 'Parita vicina, attenzione alle spese.';
      messageColor = Colors.orangeAccent;
    } else {
      ratioColor = Colors.greenAccent;
      message = 'Bilancio positivo.';
      messageColor = Colors.greenAccent;
    }

    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Bilancio Fisco', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : _hasError
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                  const SizedBox(height: 12),
                  const Text('Impossibile caricare i dati fiscali.', style: TextStyle(color: Colors.white)),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: _loadDatiFisco, child: const Text('Riprova')),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GlassContainer(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(LucideIcons.landmark, color: theme.currentColors.primary, size: 48),
                        const SizedBox(height: 16),
                        const Text(
                          'Entrate e Uscite Fiscali',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Conteggia le fatture incassate e i movimenti pagati esclusivamente con Carta.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          'Entrate',
                          CurrencyUtils.formatEuro(_entrateFisco),
                          Icons.arrow_downward,
                          Colors.greenAccent,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildMetricCard(
                          'Uscite',
                          CurrencyUtils.formatEuro(_usciteFisco),
                          Icons.arrow_upward,
                          Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  GlassContainer(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Text(
                          'Rapporto Uscite su Entrate',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          formatRatio(ratio),
                          style: TextStyle(
                            color: ratioColor,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(message, textAlign: TextAlign.center, style: TextStyle(color: messageColor, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricCard(String title, String amount, IconData icon, Color color) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: Colors.white70, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          Text(amount, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
