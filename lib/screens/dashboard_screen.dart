import 'package:audioplayers/audioplayers.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';
import 'package:provider/provider.dart';
import '../database/database_helper.dart';
import '../providers/app_theme_provider.dart';
import 'package:contabile_app/screens/deadlines_screen.dart';
import 'package:contabile_app/screens/invoice_summary_screen.dart';
import 'package:contabile_app/screens/invoices_screen.dart';
import 'package:contabile_app/screens/memo_events_screen.dart';
import 'package:contabile_app/screens/payment_summary_screen.dart';
import 'package:contabile_app/screens/payments_screen.dart';
import 'package:contabile_app/screens/security_center_screen.dart';
import 'package:contabile_app/services/update_service.dart';
import 'package:contabile_app/utils/calculation_engine.dart';
import 'package:contabile_app/utils/currency_utils.dart';
import 'package:contabile_app/utils/date_utils_app.dart';
import 'package:contabile_app/utils/sort_utils.dart';
import 'package:contabile_app/widgets/update_dialog.dart';

class DashboardScreen extends StatefulWidget {
  final String role;
  const DashboardScreen({super.key, this.role = 'User'});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  AudioPlayer? _audioPlayer;

  int _selectedYear = DateTime.now().year;
  List<int> _availableYears = _buildBaseYearRange(DateTime.now().year);

  bool _isLoading = true;
  double _totalIn = 0;
  double _totalOut = 0;
  double _totalInLastYear = 0;
  double _totalOutLastYear = 0;
  double _patrimonio = 0;

  List<Map<String, dynamic>> _allPayments = [];
  List<Map<String, dynamic>> _payments = [];
  List<Map<String, dynamic>> _deadlines = [];
  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> _memoEvents = [];
  Map<int, double> _monthlyIn = {};
  Map<int, double> _monthlyOut = {};
  Map<String, double> _chartDataCategoria = {};
  Map<String, double> _chartDataPrestazione = {};
  Map<String, double> _chartDataFatturatoContante = {};
  Map<String, String> _categoryNames = {};
  Map<String, String> _serviceNames = {};
  Map<String, Color> _categoryColors = {};
  double _totalDeadlinesPaid = 0;
  String _chartFilter = 'Categoria';

  static List<int> _buildBaseYearRange(int selectedYear) {
    final nowYear = DateTime.now().year;
    final Set<int> years = {
      for (int y = nowYear - 5; y <= nowYear + 1; y++) y,
      selectedYear,
    };
    return years.toList()..sort();
  }

  static Color? _tryParseColor(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    String cleaned = raw.trim();
    if (cleaned.startsWith('#')) {
      cleaned = cleaned.substring(1);
      if (cleaned.length == 6) {
        cleaned = 'FF$cleaned';
      }
      final parsed = int.tryParse(cleaned, radix: 16);
      return parsed != null ? Color(parsed) : null;
    }
    if (cleaned.toLowerCase().startsWith('0x')) {
      final parsed = int.tryParse(cleaned.substring(2), radix: 16);
      return parsed != null ? Color(parsed) : null;
    }
    final dec = int.tryParse(cleaned);
    if (dec != null) return Color(dec);
    final hex = int.tryParse(cleaned, radix: 16);
    return hex != null ? Color(hex) : null;
  }

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();
    super.dispose();
  }

  Future<void> _playNotificationSound() async {
    try {
      final player = _audioPlayer ??= AudioPlayer();
      await player.play(AssetSource('audio/notification.mp3'));
    } catch (e) {
      debugPrint('Errore riproduzione suono: $e');
    }
  }

  Future<void> _pushAndReload(Widget page) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
    if (mounted) {
      await _loadDashboardData();
    }
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _dbHelper.getPayments(),
        _dbHelper.getInvoices(),
        _dbHelper.getDeadlines(),
        _dbHelper.getScheduledPayments(),
        _dbHelper.getCategories(),
        _dbHelper.getServiceTypes(),
        _dbHelper.getMemoEvents(),
      ]);

      if (!mounted) return;

      final allPayments = results[0];
      final allInvoices = results[1];
      final deadlines = results[2];
      final allScheduled = results[3];
      final categories = results[4];
      final services = results[5];
      final memoEvents = results[6];

      final paymentsThisYear = allPayments
          .where(
            (p) =>
                CalculationEngine.extractYear(p['date']?.toString()) ==
                _selectedYear,
          )
          .toList();
      final paymentsLastYear = allPayments
          .where(
            (p) =>
                CalculationEngine.extractYear(p['date']?.toString()) ==
                _selectedYear - 1,
          )
          .toList();

      final scheduledThisYear = allScheduled
          .where(
            (s) =>
                CalculationEngine.extractYear(s['date']?.toString()) ==
                _selectedYear,
          )
          .toList();
      final scheduledLastYear = allScheduled
          .where(
            (s) =>
                CalculationEngine.extractYear(s['date']?.toString()) ==
                _selectedYear - 1,
          )
          .toList();

      final Set<int> dynamicYears = {
        ..._buildBaseYearRange(_selectedYear),
      };
      void addYearFrom(String? dateStr) {
        final y = CalculationEngine.extractYear(dateStr);
        if (y >= 1900 && y <= 2200) {
          dynamicYears.add(y);
        }
      }

      for (final p in allPayments) {
        addYearFrom(p['date']?.toString());
      }
      for (final inv in allInvoices) {
        addYearFrom(inv['date']?.toString());
      }
      for (final d in deadlines) {
        final dStr = (d['date_from']?.toString().trim().isNotEmpty == true)
            ? d['date_from']?.toString()
            : d['date']?.toString();
        addYearFrom(dStr);
      }
      for (final s in allScheduled) {
        addYearFrom(s['date']?.toString());
      }
      final sortedYears = dynamicYears.toList()..sort();

      final Map<String, String> categoryNames = {};
      final Map<String, String> categoryColorsHex = {};
      for (final c in categories) {
        final id = c['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        categoryNames[id] = c['name']?.toString() ?? 'Altro';
        if (c['color_hex'] != null) {
          categoryColorsHex[id] = c['color_hex'].toString();
        }
      }

      final Map<String, String> serviceNames = {};
      final Map<String, String> serviceColorsHex = {};
      for (final s in services) {
        final id = s['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        serviceNames[id] = s['name']?.toString() ?? 'Altro';
        if (s['color_hex'] != null) {
          serviceColorsHex[id] = s['color_hex'].toString();
        }
      }

      final metrics = CalculationEngine.computeDashboardMetrics(
        payments: paymentsThisYear,
        paymentsLastYear: paymentsLastYear,
        invoices: allInvoices,
        deadlines: deadlines,
        scheduledPayments: scheduledThisYear,
        scheduledPaymentsLastYear: scheduledLastYear,
        categoryNames: categoryNames,
        serviceNames: serviceNames,
        selectedYear: _selectedYear,
        allPayments: allPayments,
        allInvoices: allInvoices,
      );

      final metricsLastYear = CalculationEngine.computeDashboardMetrics(
        payments: paymentsLastYear,
        paymentsLastYear: const [],
        invoices: allInvoices,
        deadlines: deadlines,
        scheduledPayments: scheduledLastYear,
        scheduledPaymentsLastYear: const [],
        categoryNames: categoryNames,
        serviceNames: serviceNames,
        selectedYear: _selectedYear - 1,
        allPayments: allPayments,
        allInvoices: allInvoices,
      );

      final Map<String, Color> tempColors = {};
      for (final catName in metrics.categoryBreakdown.keys) {
        final categoryId = categoryNames.entries
            .firstWhere(
              (e) => e.value == catName,
              orElse: () => const MapEntry('', ''),
            )
            .key;
        if (categoryId.isNotEmpty) {
          final parsedColor = _tryParseColor(categoryColorsHex[categoryId]);
          if (parsedColor != null) {
            tempColors[catName] = parsedColor;
          }
        }
      }
      for (final srvName in metrics.serviceBreakdown.keys) {
        final serviceId = serviceNames.entries
            .firstWhere(
              (e) => e.value == srvName,
              orElse: () => const MapEntry('', ''),
            )
            .key;
        if (serviceId.isNotEmpty) {
          final parsedColor = _tryParseColor(serviceColorsHex[serviceId]);
          if (parsedColor != null) {
            tempColors[srvName] = parsedColor;
          }
        }
      }
      tempColors['Fatturato'] = Colors.blueAccent;
      tempColors['Contante'] = Colors.greenAccent;

      if (!mounted) return;
      setState(() {
        _availableYears = sortedYears;
        _totalIn = metrics.totalIn;
        _totalOut = metrics.totalOut;
        _totalInLastYear = metricsLastYear.totalIn;
        _totalOutLastYear = metricsLastYear.totalOut;
        _patrimonio = metrics.patrimonio;
        _allPayments = allPayments;
        _payments = paymentsThisYear;
        _deadlines = deadlines;
        _invoices = allInvoices;
        _memoEvents = memoEvents;
        _monthlyIn = metrics.monthlyIn;
        _monthlyOut = metrics.monthlyOut;
        _chartDataCategoria = metrics.categoryBreakdown;
        _chartDataPrestazione = metrics.serviceBreakdown;
        _chartDataFatturatoContante = metrics.paymentMethodBreakdown;
        _categoryNames = categoryNames;
        _serviceNames = serviceNames;
        _categoryColors = tempColors;
        _totalDeadlinesPaid = metrics.totalDeadlinesPaid;
      });
    } catch (e) {
      debugPrint('Errore caricamento dashboard: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _calculatePercentageChange(double current, double previous) {
    return CalculationEngine.computePercentageChange(current, previous);
  }

  void _triggerReloadIfMounted() {
    if (mounted) {
      _loadDashboardData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppThemeProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
          ? MobileDashboardAppBar(
              role: widget.role,
              selectedYear: _selectedYear,
              onDataChanged: _triggerReloadIfMounted,
              onPlayNotification: _playNotificationSound,
            )
          : DesktopDashboardAppBar(
              role: widget.role,
              selectedYear: _selectedYear,
              onDataChanged: _triggerReloadIfMounted,
              onPlayNotification: _playNotificationSound,
            ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            )
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildPatrimonioCard(theme),
                    const SizedBox(height: 16),
                    _buildMetricsGrid(theme),
                    const SizedBox(height: 16),
                    _buildChartsSection(theme),
                    const SizedBox(height: 16),
                    _buildListsSection(theme),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPatrimonioCard(AppThemeProvider theme) {
    final double netto = _patrimonio;
    final double nettoLastYear = _totalInLastYear - _totalOutLastYear;
    final String change = _calculatePercentageChange(
      _totalIn - _totalOut,
      nettoLastYear,
    );
    final bool isPositive = !change.startsWith('-');

    final yearsList = _availableYears.contains(_selectedYear)
        ? _availableYears
        : _buildBaseYearRange(_selectedYear);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PATRIMONIO NETTO',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.54),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    CurrencyUtils.formatEuro(netto),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                      color:
                          isPositive ? Colors.greenAccent : Colors.redAccent,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '$change rispetto all\'anno scorso',
                        style: TextStyle(
                          color: isPositive
                              ? Colors.greenAccent
                              : Colors.redAccent,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_totalDeadlinesPaid > 0) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.event_busy,
                        color: Colors.orangeAccent,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '- ${CurrencyUtils.formatEuro(_totalDeadlinesPaid)} scadenze pagate',
                          style: const TextStyle(
                            color: Colors.orangeAccent,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(20),
            ),
            child: DropdownButton<int>(
              value: _selectedYear,
              dropdownColor: const Color(0xFF1E1E24),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              underline: const SizedBox(),
              icon: const Icon(
                Icons.keyboard_arrow_down,
                color: Colors.white,
              ),
              items: yearsList.map((int value) {
                return DropdownMenuItem<int>(
                  value: value,
                  child: Text(value.toString()),
                );
              }).toList(),
              onChanged: (int? newValue) {
                if (newValue != null && newValue != _selectedYear) {
                  setState(() => _selectedYear = newValue);
                  _loadDashboardData();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(AppThemeProvider theme) {
    final String inChange =
        _calculatePercentageChange(_totalIn, _totalInLastYear);
    final String outChange =
        _calculatePercentageChange(_totalOut, _totalOutLastYear);

    final double margin =
        _totalIn > 0 ? ((_totalIn - _totalOut) / _totalIn) * 100 : 0;

    final int baseUnpaidInvoices =
        _invoices.where((i) => !CalculationEngine.isInvoiceSettled(i)).length;
    final int memoUnpaidFatture = _memoEvents.where((m) {
      final memoType = m['memo_type']?.toString().toUpperCase();
      final memoStatus = m['memo_status']?.toString().toUpperCase();
      return memoType == 'FATTURA' &&
          memoStatus != 'PAGATO' &&
          memoStatus != 'SALDATO';
    }).length;
    final int unpaidInvoices = baseUnpaidInvoices + memoUnpaidFatture;

    return LayoutBuilder(
      builder: (context, constraints) {
        final int crossAxisCount = constraints.maxWidth > 800 ? 4 : 2;
        final double aspectRatio = constraints.maxWidth > 800
            ? 2.5
            : (constraints.maxWidth < 400 ? 1.3 : 2.0);
        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: aspectRatio,
          children: [
            _metricCard(
              theme,
              "INCASSATO QUEST'ANNO",
              CurrencyUtils.formatEuro(_totalIn),
              inChange,
              Icons.arrow_downward,
              Colors.greenAccent,
            ),
            _metricCard(
              theme,
              "SPESO QUEST'ANNO",
              CurrencyUtils.formatEuro(_totalOut),
              outChange,
              Icons.arrow_upward,
              Colors.redAccent,
            ),
            _metricCard(
              theme,
              'FATTURE DA INCASSARE',
              '$unpaidInvoices',
              '$baseUnpaidInvoices normali, $memoUnpaidFatture programmate',
              Icons.receipt,
              Colors.orangeAccent,
              isAmount: false,
              onTap: () => _pushAndReload(const MemoEventsScreen()),
            ),
            _metricCard(
              theme,
              'MARGINE NETTO',
              '${margin.toStringAsFixed(1)}%',
              'sull\'incassato',
              Icons.pie_chart,
              Colors.purpleAccent,
              isAmount: false,
            ),
          ],
        );
      },
    );
  }

  Widget _metricCard(
    AppThemeProvider theme,
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color, {
    bool isAmount = true,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.borderColor),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: AutoScrollText(
                      text: title,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.54),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Flexible(
                    flex: 2,
                    child: AutoScrollText(
                      text: value,
                      style: TextStyle(
                        color: color,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Flexible(
                    child: AutoScrollText(
                      text: isAmount
                          ? '$subtitle vs ${_selectedYear - 1}'
                          : subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.54),
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartsSection(AppThemeProvider theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth > 800;

        if (isWide) {
          return SizedBox(
            height: 350,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 2, child: _buildLineChartCard(theme)),
                const SizedBox(width: 16),
                Expanded(flex: 1, child: _buildPieChartCard(theme)),
              ],
            ),
          );
        } else {
          return Column(
            children: [
              SizedBox(height: 300, child: _buildLineChartCard(theme)),
              const SizedBox(height: 16),
              SizedBox(height: 300, child: _buildPieChartCard(theme)),
            ],
          );
        }
      },
    );
  }

  Widget _buildLineChartCard(AppThemeProvider theme) {
    final List<FlSpot> spotsIn = [];
    final List<FlSpot> spotsOut = [];
    for (int i = 1; i <= 12; i++) {
      spotsIn.add(FlSpot(i.toDouble(), _monthlyIn[i] ?? 0.0));
      spotsOut.add(FlSpot(i.toDouble(), _monthlyOut[i] ?? 0.0));
    }

    final allValues = [
      ...spotsIn.map((s) => s.y),
      ...spotsOut.map((s) => s.y),
    ];
    double maxY =
        allValues.isEmpty ? 1000 : allValues.reduce((a, b) => a > b ? a : b);
    double minY =
        allValues.isEmpty ? 0 : allValues.reduce((a, b) => a < b ? a : b);
    maxY = maxY <= 0 ? 1000 : maxY * 1.2;
    minY = minY >= 0 ? 0 : minY * 1.2;

    String formatAxisEuro(double v) {
      if (v.abs() >= 1000) {
        return '€${(v / 1000).toStringAsFixed(1)}k';
      }
      return '€${v.toStringAsFixed(0)}';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'ANDAMENTO MENSILE',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.54),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Icon(Icons.circle, color: Colors.blueAccent, size: 10),
                  const SizedBox(width: 4),
                  Text(
                    'Incassi',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(
                    Icons.circle,
                    color: Colors.purpleAccent,
                    size: 10,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Spese',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF1E2A3A),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        const months = [
                          'Gen',
                          'Feb',
                          'Mar',
                          'Apr',
                          'Mag',
                          'Giu',
                          'Lug',
                          'Ago',
                          'Set',
                          'Ott',
                          'Nov',
                          'Dic',
                        ];
                        final month =
                            spot.x.toInt() >= 1 && spot.x.toInt() <= 12
                                ? months[spot.x.toInt() - 1]
                                : '';
                        final isIncasso = spot.barIndex == 0;
                        final title = isIncasso ? 'Incassi' : 'Spese';
                        final color = isIncasso
                            ? Colors.blueAccent
                            : Colors.purpleAccent;

                        return LineTooltipItem(
                          '$month\n$title: ${CurrencyUtils.formatEuro(spot.y)}',
                          TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                  handleBuiltInTouches: true,
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) =>
                      const FlLine(color: Colors.white10, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (value, meta) {
                        const months = [
                          'Gen',
                          'Feb',
                          'Mar',
                          'Apr',
                          'Mag',
                          'Giu',
                          'Lug',
                          'Ago',
                          'Set',
                          'Ott',
                          'Nov',
                          'Dic',
                        ];
                        if (value.toInt() >= 1 && value.toInt() <= 12) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              months[value.toInt() - 1],
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.54),
                                fontSize: 10,
                              ),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 52,
                      getTitlesWidget: (value, meta) {
                        if (value == meta.min || value == meta.max) {
                          return const SizedBox();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            formatAxisEuro(value),
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 9,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spotsIn,
                    isCurved: true,
                    color: Colors.blueAccent,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          Colors.blueAccent.withValues(alpha: 0.3),
                          Colors.transparent,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  LineChartBarData(
                    spots: spotsOut,
                    isCurved: true,
                    color: Colors.purpleAccent,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          Colors.purpleAccent.withValues(alpha: 0.3),
                          Colors.transparent,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<MapEntry<String, double>> _getSortedCats() {
    Map<String, double> targetMap;
    if (_chartFilter == 'Prestazione') {
      targetMap = _chartDataPrestazione;
    } else if (_chartFilter == 'Fatturato vs Contante') {
      targetMap = _chartDataFatturatoContante;
    } else {
      targetMap = _chartDataCategoria;
    }

    return (targetMap.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .where((e) => e.value > 0)
        .toList();
  }

  List<Color> _piePalette() => [
        Colors.redAccent,
        Colors.orangeAccent,
        Colors.yellowAccent,
        Colors.purpleAccent,
        Colors.tealAccent,
        Colors.pinkAccent,
        Colors.lightBlueAccent,
        Colors.grey,
      ];

  Widget _buildPieChartCard(AppThemeProvider theme) {
    final sortedCats = _getSortedCats();
    final palette = _piePalette();

    final List<PieChartSectionData> sections = [];
    final total = sortedCats.fold<double>(0, (s, e) => s + e.value);
    for (int i = 0; i < sortedCats.length; i++) {
      final entry = sortedCats[i];
      final color = _categoryColors[entry.key] ?? palette[i % palette.length];
      sections.add(
        PieChartSectionData(
          color: color,
          value: entry.value,
          showTitle: false,
          radius: 30,
        ),
      );
    }
    if (sections.isEmpty) {
      sections.add(
        PieChartSectionData(
          color: Colors.white12,
          value: 1,
          title: '',
          radius: 65,
        ),
      );
    }

    final showItems = sortedCats.length > 5 ? 5 : sortedCats.length;

    return GestureDetector(
      onTap: sortedCats.isNotEmpty
          ? () => _showPieChartFullScreen(sortedCats, palette)
          : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _chartFilter,
                      isExpanded: true,
                      dropdownColor: theme.cardColor,
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: Colors.white.withValues(alpha: 0.54),
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Categoria',
                          child: Text('RIPARTIZIONE CATEGORIE'),
                        ),
                        DropdownMenuItem(
                          value: 'Prestazione',
                          child: Text('RIPARTIZIONE PRESTAZIONI'),
                        ),
                        DropdownMenuItem(
                          value: 'Fatturato vs Contante',
                          child: Text('FATTURATO VS CONTANTE'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _chartFilter = val);
                        }
                      },
                    ),
                  ),
                ),
                if (sortedCats.isNotEmpty)
                  const Icon(
                    Icons.open_in_full,
                    color: Colors.white24,
                    size: 14,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: IgnorePointer(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          PieChart(
                            PieChartData(
                              pieTouchData: PieTouchData(enabled: false),
                              sectionsSpace: 2,
                              centerSpaceRadius: 35,
                              sections: sections,
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Totale',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 10,
                                ),
                              ),
                              Text(
                                '€ ${total.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: LayoutBuilder(
                      builder: (ctx, constraints) {
                        const itemH = 22.0;
                        final totalH = showItems * itemH;
                        final needsScroll = totalH > constraints.maxHeight;

                        final items = List.generate(showItems, (index) {
                          final entry = sortedCats[index];
                          final color = _categoryColors[entry.key] ??
                              palette[index % palette.length];
                          final pct =
                              total > 0 ? (entry.value / total * 100) : 0;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: AutoScrollText(
                                    text: entry.key,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${pct.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.54),
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          );
                        });

                        if (needsScroll) {
                          return ListView(children: items);
                        } else {
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: items,
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPieChartFullScreen(
    List<MapEntry<String, double>> sortedCats,
    List<Color> palette,
  ) {
    String title;
    if (_chartFilter == 'Prestazione') {
      title = 'RIPARTIZIONE PRESTAZIONI';
    } else if (_chartFilter == 'Fatturato vs Contante') {
      title = 'FATTURATO VS CONTANTE';
    } else {
      title = 'RIPARTIZIONE CATEGORIE';
    }

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => _PieChartFullScreenDialog(
        sortedCats: sortedCats,
        categoryColors: _categoryColors,
        palette: palette,
        title: title,
        payments: _payments,
        allPayments: _allPayments,
        invoices: _invoices,
        selectedYear: _selectedYear,
        chartFilter: _chartFilter,
        categoryNames: _categoryNames,
        serviceNames: _serviceNames,
      ),
    );
  }

  Widget _buildListsSection(AppThemeProvider theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth > 800;
        final Widget movimenti = _buildRecentPayments(theme);
        final Widget scadenze = _buildUpcomingDeadlines(theme);
        final Widget fatture = _buildRecentInvoices(theme);

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: movimenti),
              const SizedBox(width: 16),
              Expanded(child: scadenze),
              const SizedBox(width: 16),
              Expanded(child: fatture),
            ],
          );
        } else {
          return Column(
            children: [
              movimenti,
              const SizedBox(height: 16),
              scadenze,
              const SizedBox(height: 16),
              fatture,
            ],
          );
        }
      },
    );
  }

  Widget _buildRecentInvoices(AppThemeProvider theme) {
    final sortedInvoices = List<Map<String, dynamic>>.from(_invoices)
      ..sort(
        (a, b) => compareDates(
          a['date']?.toString(),
          b['date']?.toString(),
          descending: true,
        ),
      );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'ULTIME FATTURE',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.54),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              InkWell(
                onTap: () => _pushAndReload(const InvoicesScreen()),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Vedi tutti',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward,
                        color: Colors.white.withValues(alpha: 0.7),
                        size: 12,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (sortedInvoices.isEmpty)
            Center(
              child: Text(
                'Nessuna fattura registrata',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.54)),
              ),
            )
          else
            ...sortedInvoices.take(5).map((inv) {
              final bool isSettled = CalculationEngine.isInvoiceSettled(inv);
              final String rawStatus =
                  (inv['status'] ?? '').toString().trim().toUpperCase();
              final String displayStatus = isSettled
                  ? 'Incassata'
                  : (rawStatus == 'LATE' ? 'In Ritardo' : 'Da Incassare');
              final Color statusColor = isSettled
                  ? Colors.greenAccent
                  : (rawStatus == 'LATE'
                      ? Colors.redAccent
                      : Colors.orangeAccent);
              final double amt =
                  CurrencyUtils.parseCurrency(inv['amount']?.toString());
              final String invId = inv['id']?.toString() ?? '';

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: invId.isEmpty
                      ? null
                      : () => _pushAndReload(
                            InvoiceSummaryScreen(invoiceId: invId),
                          ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              inv['number']?.toString() ?? 'Senza Numero',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              displayStatus,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        CurrencyUtils.formatEuro(amt),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildRecentPayments(AppThemeProvider theme) {
    final sortedPayments = List<Map<String, dynamic>>.from(_payments)
      ..sort((a, b) {
        final comp = compareDates(
          a['date']?.toString(),
          b['date']?.toString(),
          descending: true,
        );
        if (comp != 0) return comp;
        final idA = a['id']?.toString() ?? '';
        final idB = b['id']?.toString() ?? '';
        return idB.compareTo(idA);
      });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'ULTIMI MOVIMENTI',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.54),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              InkWell(
                onTap: () => _pushAndReload(const PaymentsScreen()),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Vedi tutti',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward,
                        color: Colors.white.withValues(alpha: 0.7),
                        size: 12,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (sortedPayments.isEmpty)
            Text(
              'Nessun movimento.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.54)),
            )
          else
            ...sortedPayments.take(5).map((p) {
              final bool isIN =
                  (p['type'] ?? 'IN').toString().trim().toUpperCase() == 'IN';
              final String customerName = p['customer_name']?.toString() ?? '';
              final String serviceName = p['service_name']?.toString() ?? '';
              final String dateLabel = DateUtilsApp.formatDbDate(
                p['date']?.toString(),
                theme.dateFormat,
              );
              final String subtitle = [
                if (dateLabel.isNotEmpty) dateLabel,
                if (customerName.isNotEmpty) customerName,
                if (serviceName.isNotEmpty) serviceName,
              ].join(' • ');
              final double amt =
                  CurrencyUtils.parseCurrency(p['amount']?.toString());
              final String pId = p['id']?.toString() ?? '';

              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: pId.isEmpty
                      ? null
                      : () => _pushAndReload(
                            PaymentSummaryScreen(paymentId: pId),
                          ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (isIN ? Colors.greenAccent : Colors.redAccent)
                              .withValues(alpha: 0.1),
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
                              p['payment_method']?.toString() ??
                                  (isIN ? 'Incasso' : 'Spesa'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              subtitle,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.54),
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        CurrencyUtils.formatEuro(amt),
                        style: TextStyle(
                          color: isIN ? Colors.greenAccent : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildUpcomingDeadlines(AppThemeProvider theme) {
    final upcomingDeadlines = _deadlines
        .where((d) => !CalculationEngine.isDeadlineSettled(d))
        .toList();
    final sortedDeadlines = List<Map<String, dynamic>>.from(upcomingDeadlines)
      ..sort((a, b) {
        final dA = (a['date']?.toString().trim().isNotEmpty == true)
            ? a['date']?.toString()
            : a['date_from']?.toString();
        final dB = (b['date']?.toString().trim().isNotEmpty == true)
            ? b['date']?.toString()
            : b['date_from']?.toString();
        return compareDates(dA, dB, descending: false);
      });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'SCADENZE IN ARRIVO',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.54),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              InkWell(
                onTap: () => _pushAndReload(const DeadlinesScreen()),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Vedi tutti',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward,
                        color: Colors.white.withValues(alpha: 0.7),
                        size: 12,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (sortedDeadlines.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.calendar_month,
                      color: Colors.purpleAccent.withValues(alpha: 0.8),
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Nessuna scadenza a breve.',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Quando ci saranno scadenze, le troverai qui\nper tenerle sempre sotto controllo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.54),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.purpleAccent, Colors.blueAccent],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.purpleAccent.withValues(alpha: 0.3),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () => _pushAndReload(
                          const MemoEventsScreen(openForm: true),
                        ),
                        icon: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 18,
                        ),
                        label: const Text(
                          'Nuova Scadenza',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...sortedDeadlines.take(5).map((d) {
              final String dTitle =
                  (d['title']?.toString().trim().isNotEmpty == true)
                      ? d['title'].toString().trim()
                      : 'Scadenza';
              final String rawDate =
                  (d['date']?.toString().trim().isNotEmpty == true)
                      ? d['date'].toString()
                      : (d['date_from']?.toString() ?? '');
              final String formattedDate =
                  DateUtilsApp.formatDbDate(rawDate, theme.dateFormat);
              final double dAmt =
                  CurrencyUtils.parseCurrency(d['amount']?.toString());

              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _pushAndReload(const DeadlinesScreen()),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orangeAccent.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.event_note,
                          color: Colors.orangeAccent,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dTitle,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              formattedDate,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.54),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        CurrencyUtils.formatEuro(dAmt),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class AutoScrollText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const AutoScrollText({super.key, required this.text, this.style});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: TextSpan(text: text, style: style),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: double.infinity);

        if (textPainter.width > constraints.maxWidth) {
          return SizedBox(
            height: textPainter.height,
            child: Marquee(
              text: text,
              style: style,
              scrollAxis: Axis.horizontal,
              crossAxisAlignment: CrossAxisAlignment.center,
              blankSpace: 20.0,
              velocity: 30.0,
              pauseAfterRound: const Duration(seconds: 1),
              startPadding: 0.0,
              accelerationDuration: const Duration(seconds: 1),
              accelerationCurve: Curves.linear,
              decelerationDuration: const Duration(milliseconds: 500),
              decelerationCurve: Curves.easeOut,
            ),
          );
        } else {
          return Text(
            text,
            style: style,
            overflow: TextOverflow.ellipsis,
          );
        }
      },
    );
  }
}

class _PieChartFullScreenDialog extends StatefulWidget {
  final List<MapEntry<String, double>> sortedCats;
  final Map<String, Color> categoryColors;
  final List<Color> palette;
  final String title;
  final List<Map<String, dynamic>> payments;
  final List<Map<String, dynamic>> allPayments;
  final List<Map<String, dynamic>> invoices;
  final int selectedYear;
  final String chartFilter;
  final Map<String, String> categoryNames;
  final Map<String, String> serviceNames;

  const _PieChartFullScreenDialog({
    required this.sortedCats,
    required this.categoryColors,
    required this.palette,
    required this.title,
    required this.payments,
    required this.allPayments,
    required this.invoices,
    required this.selectedYear,
    required this.chartFilter,
    required this.categoryNames,
    required this.serviceNames,
  });

  @override
  State<_PieChartFullScreenDialog> createState() =>
      _PieChartFullScreenDialogState();
}

class _PieChartFullScreenDialogState extends State<_PieChartFullScreenDialog>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = -1;
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scaleAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutBack);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Color _colorFor(int index) =>
      widget.categoryColors[widget.sortedCats[index].key] ??
      widget.palette[index % widget.palette.length];

  void _selectSlice(int index) {
    setState(() {
      if (_selectedIndex == index) {
        _selectedIndex = -1;
        _animCtrl.reverse();
      } else {
        _selectedIndex = index;
        _animCtrl.forward(from: 0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.sortedCats.fold<double>(0, (s, e) => s + e.value);
    final selected =
        _selectedIndex >= 0 ? widget.sortedCats[_selectedIndex] : null;
    final selectedColor =
        _selectedIndex >= 0 ? _colorFor(_selectedIndex) : Colors.transparent;
    final selectedPct =
        selected != null && total > 0 ? (selected.value / total * 100) : 0.0;

    return Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1B2A), Color(0xFF1A1A2E), Color(0xFF16213E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.pie_chart,
                        color: Colors.blueAccent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.title.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: Colors.white.withValues(alpha: 0.54),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              if (_selectedIndex < 0)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Tocca una sezione per i dettagli',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
              Expanded(
                child: LayoutBuilder(
                  builder: (ctx, constraints) {
                    final isWide = constraints.maxWidth > 600;
                    double maxAvailableRadius = (isWide
                            ? constraints.maxHeight
                            : constraints.maxWidth) *
                        0.45;
                    if (maxAvailableRadius > 350) maxAvailableRadius = 350;

                    final double currentRadius = selected != null
                        ? maxAvailableRadius * 0.65
                        : maxAvailableRadius;

                    final sections = List<PieChartSectionData>.generate(
                      widget.sortedCats.length,
                      (i) {
                        final entry = widget.sortedCats[i];
                        final color = _colorFor(i);
                        final isSelected = i == _selectedIndex;

                        return PieChartSectionData(
                          color: isSelected
                              ? color
                              : color.withValues(alpha: 0.75),
                          value: entry.value,
                          showTitle: false,
                          radius: isSelected
                              ? (currentRadius * 0.45) * 1.1
                              : currentRadius * 0.45,
                        );
                      },
                    );

                    final pieWidget = Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            sectionsSpace: 3,
                            centerSpaceRadius: currentRadius * 0.55,
                            sections: sections,
                            pieTouchData: PieTouchData(
                              enabled: true,
                              touchCallback: (event, response) {
                                if (event is FlTapUpEvent) {
                                  final idx = response
                                          ?.touchedSection
                                          ?.touchedSectionIndex ??
                                      -1;
                                  if (idx >= 0) _selectSlice(idx);
                                }
                              },
                            ),
                          ),
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOutCubic,
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Totale',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: currentRadius * 0.12,
                              ),
                            ),
                            Text(
                              '€ ${total.toStringAsFixed(0)}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: currentRadius * 0.15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );

                    final detailPanel = selected != null
                        ? ScaleTransition(
                            scale: _scaleAnim,
                            child: Container(
                              margin: EdgeInsets.only(
                                left: isWide ? 24 : 0,
                                top: isWide ? 0 : 16,
                              ),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: selectedColor.withValues(alpha: 0.4),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        selectedColor.withValues(alpha: 0.15),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 14,
                                        height: 14,
                                        decoration: BoxDecoration(
                                          color: selectedColor,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: selectedColor
                                                  .withValues(alpha: 0.5),
                                              blurRadius: 8,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          selected.key,
                                          style: TextStyle(
                                            color: selectedColor,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: selectedColor
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Totale',
                                          style: TextStyle(
                                            color: Colors.white
                                                .withValues(alpha: 0.54),
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          CurrencyUtils.formatEuro(
                                            selected.value,
                                          ),
                                          style: TextStyle(
                                            color: selectedColor,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '% sul totale',
                                          style: TextStyle(
                                            color: Colors.white
                                                .withValues(alpha: 0.54),
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          '${selectedPct.toStringAsFixed(1)}%',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Divider(color: Colors.white12),
                                  const SizedBox(height: 8),
                                  Text(
                                    'TRANSAZIONI: ${selected.key.toUpperCase()}',
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Expanded(
                                    child: _buildFilteredTransactionsList(
                                      selected.key,
                                      selectedColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : null;

                    if (isWide) {
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          children: [
                            Expanded(flex: 1, child: pieWidget),
                            if (detailPanel != null)
                              Expanded(flex: 1, child: detailPanel),
                          ],
                        ),
                      );
                    } else {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            SizedBox(
                              height: detailPanel != null
                                  ? constraints.maxHeight * 0.42
                                  : constraints.maxHeight * 0.7,
                              child: pieWidget,
                            ),
                            if (detailPanel != null)
                              Expanded(child: detailPanel),
                          ],
                        ),
                      );
                    }
                  },
                ),
              ),
              if (_selectedIndex < 0)
                Container(
                  height: 80,
                  margin: const EdgeInsets.only(bottom: 16, top: 8),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: widget.sortedCats.length,
                    itemBuilder: (_, i) {
                      final entry = widget.sortedCats[i];
                      final color = _colorFor(i);
                      final pct =
                          total > 0 ? (entry.value / total * 100) : 0.0;
                      return GestureDetector(
                        onTap: () => _selectSlice(i),
                        child: Container(
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: color.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    entry.key.length > 14
                                        ? '${entry.key.substring(0, 12)}…'
                                        : entry.key,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '€ ${entry.value.toStringAsFixed(0)}  •  ${pct.toStringAsFixed(1)}%',
                                style: TextStyle(color: color, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
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

  List<Map<String, dynamic>> _getFilteredTransactions(String sliceKey) {
    final effectiveAllPayments =
        widget.allPayments.isNotEmpty ? widget.allPayments : widget.payments;

    final Set<String> paidInvoiceIds = CalculationEngine.findPaidInvoiceIds(
      effectiveAllPayments,
      widget.invoices,
    );

    bool isValidSettledYearPayment(Map<String, dynamic> p) {
      if (!CalculationEngine.isPaymentSettled(p)) return false;
      final amt = CurrencyUtils.parseCurrency(p['amount']?.toString());
      if (amt == 0) return false;
      final dateStr = (p['date'] ?? '').toString().trim();
      if (dateStr.isEmpty) return false;
      return CalculationEngine.extractYear(dateStr) == widget.selectedYear;
    }

    if (widget.chartFilter == 'Categoria') {
      return widget.payments.where((p) {
        if (!isValidSettledYearPayment(p)) return false;
        final catId = p['category_id']?.toString() ?? '';
        final name = widget.categoryNames[catId] ?? 'Altro';
        return name == sliceKey;
      }).toList();
    } else if (widget.chartFilter == 'Prestazione') {
      return widget.payments.where((p) {
        if (!isValidSettledYearPayment(p)) return false;
        final srvId = p['service_id']?.toString() ?? '';
        final name = widget.serviceNames[srvId] ?? 'Altro';
        return name == sliceKey;
      }).toList();
    } else if (widget.chartFilter == 'Fatturato vs Contante') {
      if (CalculationEngine.isCashMethod(sliceKey)) {
        return widget.payments.where((p) {
          if (!isValidSettledYearPayment(p)) return false;
          final isIN = (p['type'] ?? 'IN').toString().trim().toUpperCase() == 'IN';
          if (!isIN) return false;
          return CalculationEngine.isCashMethod(
            p['payment_method']?.toString(),
          );
        }).toList();
      } else {
        final List<Map<String, dynamic>> result = [];
        for (final p in widget.payments) {
          if (!isValidSettledYearPayment(p)) continue;
          final isIN = (p['type'] ?? 'IN').toString().trim().toUpperCase() == 'IN';
          if (!isIN) continue;
          if (!CalculationEngine.isCashMethod(
            p['payment_method']?.toString(),
          )) {
            result.add(p);
          }
        }
        for (final inv in widget.invoices) {
          if (!CalculationEngine.isInvoiceSettled(inv)) continue;
          final isOut = (inv['type'] ?? 'IN').toString().trim().toUpperCase() == 'OUT';
          if (isOut) continue;
          final invId = inv['id']?.toString() ?? '';
          if (invId.isNotEmpty && paidInvoiceIds.contains(invId)) continue;
          final dateStr = (inv['date'] ?? '').toString().trim();
          if (dateStr.isEmpty) continue;
          if (CalculationEngine.extractYear(dateStr) != widget.selectedYear) {
            continue;
          }
          final amt = CurrencyUtils.parseCurrency(inv['amount']?.toString());
          if (amt <= 0) continue;
          final copy = Map<String, dynamic>.from(inv);
          copy['_is_invoice_record'] = true;
          result.add(copy);
        }
        return result;
      }
    }
    return [];
  }

  Widget _buildFilteredTransactionsList(String sliceKey, Color color) {
    final list = _getFilteredTransactions(sliceKey);

    if (list.isEmpty) {
      return const Center(
        child: Text(
          'Nessuna transazione trovata.',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    list.sort(
      (a, b) => compareDates(
        a['date']?.toString(),
        b['date']?.toString(),
        descending: true,
      ),
    );

    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        final isInvoice =
            item['_is_invoice_record'] == true || item.containsKey('number');

        final double parsedAmt =
            CurrencyUtils.parseCurrency(item['amount']?.toString());
        final String formattedAmt = CurrencyUtils.formatEuro(parsedAmt);
        String title;
        String subtitle;

        if (isInvoice) {
          title = 'Fattura n. ${item['number'] ?? item['id'] ?? '-'}';
          subtitle = DateUtilsApp.formatDbDate(item['date']?.toString());
        } else {
          final bool isIN =
              (item['type'] ?? 'IN').toString().trim().toUpperCase() == 'IN';
          title = item['payment_method']?.toString() ??
              (isIN ? 'Incasso' : 'Spesa');
          final customerName = item['customer_name']?.toString() ?? '';
          final serviceName = item['service_name']?.toString() ?? '';
          final formattedDate =
              DateUtilsApp.formatDbDate(item['date']?.toString());
          subtitle = [
            if (formattedDate.isNotEmpty) formattedDate,
            if (customerName.isNotEmpty) customerName,
            if (serviceName.isNotEmpty) serviceName,
          ].join(' • ');
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formattedAmt,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

Future<void> _handleAppBarUpdateCheck(
  BuildContext context, {
  Future<void> Function()? onPlayNotification,
  VoidCallback? onDataChanged,
}) async {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Controllo aggiornamenti in corso...'),
      duration: Duration(seconds: 1),
    ),
  );
  final updateService = UpdateService();
  final updateData = await updateService.checkForUpdate();
  if (!context.mounted) return;

  if (updateData != null) {
    if (onPlayNotification != null) {
      await onPlayNotification();
    } else {
      final fallbackPlayer = AudioPlayer();
      try {
        fallbackPlayer.onPlayerComplete.first.then(
          (_) => fallbackPlayer.dispose(),
        );
        await fallbackPlayer.play(AssetSource('audio/notification.mp3'));
      } catch (e) {
        fallbackPlayer.dispose();
        debugPrint('Errore riproduzione suono: $e');
      }
    }
    if (!context.mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => UpdateDialog(
        updateData: updateData,
        updateService: updateService,
      ),
    );
    onDataChanged?.call();
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nessun aggiornamento disponibile.')),
    );
  }
}

class MobileDashboardAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String role;
  final int selectedYear;
  final VoidCallback? onDataChanged;
  final Future<void> Function()? onPlayNotification;

  const MobileDashboardAppBar({
    super.key,
    required this.role,
    required this.selectedYear,
    this.onDataChanged,
    this.onPlayNotification,
  });

  @override
  Size get preferredSize => const Size.fromHeight(116);

  @override
  Widget build(BuildContext context) {
    final isAdmin = role.trim().toLowerCase() == 'admin';

    return AppBar(
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () {
            context.findRootAncestorStateOfType<ScaffoldState>()?.openDrawer();
          },
        ),
      ),
      title: Row(
        children: [
          const CircleAvatar(
            radius: 14,
            backgroundColor: Color(0xFF2A2D34),
            backgroundImage: AssetImage(
              'assets/images/logo_bimbomixer_neon.jpg',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AutoScrollText(
              text: 'BIMBOMIXER CONTABILITÀ $selectedYear',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      actions: const [],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8.0, right: 8.0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10.0,
                    horizontal: 8.0,
                  ),
                  child: PopupMenuButton<String>(
                    offset: const Offset(0, 45),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    color: const Color(0xFF1E1E24),
                    onSelected: (value) async {
                      if (value == 'Scadenza') {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const MemoEventsScreen(openForm: true),
                          ),
                        );
                        onDataChanged?.call();
                      } else if (value == 'Tasse') {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const DeadlinesScreen(openDialog: true),
                          ),
                        );
                        onDataChanged?.call();
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'Scadenza',
                        child: Row(
                          children: [
                            Icon(Icons.event, color: Colors.orangeAccent),
                            SizedBox(width: 8),
                            Text(
                              'Nuova Scadenza',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'Tasse',
                        child: Row(
                          children: [
                            Icon(
                              Icons.account_balance,
                              color: Colors.redAccent,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Pagamento Tasse',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.purpleAccent, Colors.blueAccent],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blueAccent.withValues(alpha: 0.3),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.add, color: Colors.white, size: 18),
                          SizedBox(width: 4),
                          Text(
                            'Nuova operazione',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (isAdmin)
                  IconButton(
                    icon: const Icon(Icons.security, color: Colors.white),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SecurityCenterScreen(),
                        ),
                      );
                      onDataChanged?.call();
                    },
                  ),
                IconButton(
                  icon: const Icon(
                    Icons.notifications_none,
                    color: Colors.white,
                  ),
                  onPressed: () => _handleAppBarUpdateCheck(
                    context,
                    onPlayNotification: onPlayNotification,
                    onDataChanged: onDataChanged,
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DesktopDashboardAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String role;
  final int selectedYear;
  final VoidCallback? onDataChanged;
  final Future<void> Function()? onPlayNotification;

  const DesktopDashboardAppBar({
    super.key,
    required this.role,
    required this.selectedYear,
    this.onDataChanged,
    this.onPlayNotification,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final isAdmin = role.trim().toLowerCase() == 'admin';

    return AppBar(
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () {
            context.findRootAncestorStateOfType<ScaffoldState>()?.openDrawer();
          },
        ),
      ),
      title: Row(
        children: [
          const CircleAvatar(
            radius: 14,
            backgroundColor: Color(0xFF2A2D34),
            backgroundImage: AssetImage(
              'assets/images/logo_bimbomixer_neon.jpg',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AutoScrollText(
              text: 'BIMBOMIXER CONTABILITÀ $selectedYear',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
          child: PopupMenuButton<String>(
            offset: const Offset(0, 45),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: const Color(0xFF1E1E24),
            onSelected: (value) async {
              if (value == 'Scadenza') {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MemoEventsScreen(openForm: true),
                  ),
                );
                onDataChanged?.call();
              } else if (value == 'Tasse') {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DeadlinesScreen(openDialog: true),
                  ),
                );
                onDataChanged?.call();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'Scadenza',
                child: Row(
                  children: [
                    Icon(Icons.event, color: Colors.orangeAccent),
                    SizedBox(width: 8),
                    Text(
                      'Nuova Scadenza',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'Tasse',
                child: Row(
                  children: [
                    Icon(Icons.account_balance, color: Colors.redAccent),
                    SizedBox(width: 8),
                    Text(
                      'Pagamento Tasse',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.purpleAccent, Colors.blueAccent],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueAccent.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.add, color: Colors.white, size: 18),
                  SizedBox(width: 4),
                  Text(
                    'Nuova operazione',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isAdmin)
          IconButton(
            icon: const Icon(Icons.security, color: Colors.white),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SecurityCenterScreen(),
                ),
              );
              onDataChanged?.call();
            },
          ),
        IconButton(
          icon: const Icon(Icons.notifications_none, color: Colors.white),
          onPressed: () => _handleAppBarUpdateCheck(
            context,
            onPlayNotification: onPlayNotification,
            onDataChanged: onDataChanged,
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
