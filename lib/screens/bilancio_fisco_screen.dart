import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../database/database_helper.dart';
import '../providers/app_theme_provider.dart';
import '../utils/calculation_engine.dart';
import '../utils/currency_utils.dart';
import '../utils/date_utils_app.dart';
import '../utils/sort_utils.dart';
import '../widgets/glass_container.dart';
import '../widgets/gradient_scaffold.dart';

/// Formatta il rapporto in % (it_IT). null = non calcolabile.
String formatFiscoRatio(double? ratio) {
  if (ratio == null) return 'N/D';
  return '${NumberFormat('#,##0.##', 'it_IT').format(ratio)}%';
}

class BilancioFiscoScreen extends StatefulWidget {
  const BilancioFiscoScreen({super.key});

  @override
  State<BilancioFiscoScreen> createState() => _BilancioFiscoScreenState();
}

class _BilancioFiscoScreenState extends State<BilancioFiscoScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  bool _isLoading = true;
  bool _hasError = false;
  int? _selectedYear;

  List<Map<String, dynamic>> _allPayments = [];
  List<Map<String, dynamic>> _allInvoices = [];
  List<int> _availableYears = [];

  double _entrateFisco = 0.0;
  double _usciteFisco = 0.0;
  double _utileFisco = 0.0;
  List<Map<String, dynamic>> _fiscalRecords = [];

  /// Rapporto uscite/entrate in %. null = non calcolabile (entrate = 0).
  double? get _ratioPercent =>
      _entrateFisco > 0 ? (_usciteFisco / _entrateFisco) * 100 : null;

  static String formatRatio(double? percent) => formatFiscoRatio(percent);

  @override
  void initState() {
    super.initState();
    _loadDatiFisco();
  }

  List<int> _computeAvailableYears(
    List<Map<String, dynamic>> payments,
    List<Map<String, dynamic>> invoices,
  ) {
    final Set<int> years = {DateTime.now().year};
    if (_selectedYear != null) {
      years.add(_selectedYear!);
    }
    for (final p in payments) {
      final y = CalculationEngine.extractYear(p['date']?.toString());
      if (y >= 1900 && y <= 2200) years.add(y);
    }
    for (final inv in invoices) {
      final y = CalculationEngine.extractYear(inv['date']?.toString());
      if (y >= 1900 && y <= 2200) years.add(y);
    }
    final sorted = years.toList()..sort((a, b) => b.compareTo(a));
    return sorted;
  }

  void _recalculateMetrics() {
    final metrics = CalculationEngine.computeFiscalMetrics(
      payments: _allPayments,
      invoices: _allInvoices,
      selectedYear: _selectedYear,
    );

    final sortedRecords = List<Map<String, dynamic>>.from(metrics.fiscalRecords)
      ..sort((a, b) {
        final cmp = compareDates(
          a['date']?.toString(),
          b['date']?.toString(),
          descending: true,
        );
        if (cmp != 0) return cmp;
        final idA = a['id']?.toString() ?? '';
        final idB = b['id']?.toString() ?? '';
        return idB.compareTo(idA);
      });

    _entrateFisco = metrics.entrateFiscale;
    _usciteFisco = metrics.usciteFiscale;
    _utileFisco = metrics.utileFiscale;
    _fiscalRecords = sortedRecords;
  }

  Future<void> _loadDatiFisco() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final results = await Future.wait([
        _dbHelper.getInvoices(),
        _dbHelper.getPayments(),
      ]);
      if (!mounted) return;

      final invoices = results[0];
      final payments = results[1];

      setState(() {
        _allInvoices = invoices;
        _allPayments = payments;
        _availableYears = _computeAvailableYears(payments, invoices);
        _recalculateMetrics();
      });
    } catch (e) {
      debugPrint('Errore caricamento Bilancio Fisco: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppThemeProvider>();
    final outerScaffold = Scaffold.maybeOf(context);
    final hasShellDrawer = outerScaffold?.hasDrawer ?? false;
    final canPopRoute = Navigator.of(context).canPop();

    final ratio = _ratioPercent;
    Color ratioColor = Colors.grey;
    String message;
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
      message = 'Parità vicina, attenzione alle spese.';
      messageColor = Colors.orangeAccent;
    } else {
      ratioColor = Colors.greenAccent;
      message = 'Bilancio positivo.';
      messageColor = Colors.greenAccent;
    }

    final yearsForDropdown = _availableYears.isNotEmpty
        ? _availableYears
        : <int>[DateTime.now().year];

    return GradientScaffold(
      appBar: AppBar(
        leading: canPopRoute
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : (hasShellDrawer
                ? IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onPressed: () => outerScaffold?.openDrawer(),
                  )
                : null),
        title: const Text(
          'Bilancio Fisco',
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    value: (_selectedYear == null ||
                            yearsForDropdown.contains(_selectedYear))
                        ? _selectedYear
                        : null,
                    dropdownColor: const Color(0xFF1E1E24),
                    icon: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white,
                      size: 18,
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Tutti'),
                      ),
                      ...yearsForDropdown.map(
                        (int y) => DropdownMenuItem<int?>(
                          value: y,
                          child: Text(y.toString()),
                        ),
                      ),
                    ],
                    onChanged: (int? newYear) {
                      setState(() {
                        _selectedYear = newYear;
                        _recalculateMetrics();
                      });
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            )
          : _hasError
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.redAccent,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Impossibile caricare i dati fiscali.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _loadDatiFisco,
                          child: const Text('Riprova'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDatiFisco,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        GlassContainer(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Icon(
                                LucideIcons.landmark,
                                color: theme.currentColors.primary,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _selectedYear == null
                                    ? 'Entrate e Uscite Fiscali (Tutti gli anni)'
                                    : 'Entrate e Uscite Fiscali $_selectedYear',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Conteggia le fatture saldate e i movimenti saldati con metodi tracciati (escluso il Contante e i pagamenti in attesa).',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isNarrow = constraints.maxWidth < 380;
                            if (isNarrow) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildMetricCard(
                                    'Entrate',
                                    CurrencyUtils.formatEuro(_entrateFisco),
                                    Icons.arrow_downward,
                                    Colors.greenAccent,
                                  ),
                                  const SizedBox(height: 12),
                                  _buildMetricCard(
                                    'Uscite',
                                    CurrencyUtils.formatEuro(_usciteFisco),
                                    Icons.arrow_upward,
                                    Colors.redAccent,
                                  ),
                                  const SizedBox(height: 12),
                                  _buildMetricCard(
                                    'Utile Fiscale',
                                    CurrencyUtils.formatEuro(_utileFisco),
                                    Icons.account_balance_wallet_outlined,
                                    _utileFisco >= 0
                                        ? Colors.cyanAccent
                                        : Colors.orangeAccent,
                                  ),
                                ],
                              );
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
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
                                const SizedBox(height: 16),
                                _buildMetricCard(
                                  'Utile Fiscale',
                                  CurrencyUtils.formatEuro(_utileFisco),
                                  Icons.account_balance_wallet_outlined,
                                  _utileFisco >= 0
                                      ? Colors.cyanAccent
                                      : Colors.orangeAccent,
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        GlassContainer(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              const Text(
                                'Rapporto Uscite su Entrate',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 12),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  formatRatio(ratio),
                                  style: TextStyle(
                                    color: ratioColor,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                message,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: messageColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        GlassContainer(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Movimenti Fiscali (${_fiscalRecords.length})',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (_fiscalRecords.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Nessun movimento fiscale registrato nel periodo selezionato.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: 0.6),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _fiscalRecords.length,
                                  separatorBuilder: (_, _) => const Divider(
                                    color: Colors.white12,
                                    height: 16,
                                  ),
                                  itemBuilder: (context, index) =>
                                      _buildFiscalRecordTile(
                                    _fiscalRecords[index],
                                    theme.dateFormat,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildFiscalRecordTile(Map<String, dynamic> r, String dateFormat) {
    final isIN = (r['type'] ?? 'IN').toString().trim().toUpperCase() == 'IN';
    final amount = CurrencyUtils.parseCurrency(r['amount']?.toString());
    final method = r['payment_method']?.toString() ??
        (isIN ? 'Entrata Fiscale' : 'Uscita Fiscale');
    final title = (r['title']?.toString().trim().isNotEmpty == true)
        ? r['title'].toString().trim()
        : method;
    final client = r['customer_name']?.toString().trim() ?? '';
    final dateFormatted =
        DateUtilsApp.formatDbDate(r['date']?.toString(), dateFormat);
    final subtitleParts = <String>[
      if (dateFormatted.isNotEmpty) dateFormatted,
      if (client.isNotEmpty) client,
      if (method.isNotEmpty && method != title) method,
    ];

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (isIN ? Colors.greenAccent : Colors.redAccent)
                .withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isIN ? Icons.arrow_downward : Icons.arrow_upward,
            color: isIN ? Colors.greenAccent : Colors.redAccent,
            size: 16,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              if (subtitleParts.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitleParts.join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          CurrencyUtils.formatEuro(isIN ? amount : -amount),
          style: TextStyle(
            color: isIN ? Colors.greenAccent : Colors.redAccent,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    String title,
    String amount,
    IconData icon,
    Color color,
  ) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
