import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../database/database_helper.dart';
import 'package:provider/provider.dart';
import '../providers/app_theme_provider.dart';
import 'package:marquee/marquee.dart';
import 'package:contabile_app/services/update_service.dart';
import 'package:contabile_app/widgets/update_dialog.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:contabile_app/screens/invoices_screen.dart';
import 'package:contabile_app/screens/security_center_screen.dart';
import 'package:contabile_app/utils/calculation_engine.dart';

class DashboardScreen extends StatefulWidget {
  final String role;
  const DashboardScreen({super.key, this.role = 'User'});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  int _selectedYear = DateTime.now().year;

  bool _isLoading = true;
  double _totalIn = 0;
  double _totalOut = 0;
  double _totalInLastYear = 0;
  double _totalOutLastYear = 0;

  List<Map<String, dynamic>> _payments = [];
  List<Map<String, dynamic>> _deadlines = [];
  List<Map<String, dynamic>> _invoices = [];
  Map<int, double> _monthlyNet = {};
  Map<String, double> _chartDataCategoria = {};
  Map<String, double> _chartDataPrestazione = {};
  Map<String, double> _chartDataFatturatoContante = {};
  Map<String, String> _categoryNames = {};
  Map<String, String> _serviceNames = {};
  Map<String, Color> _categoryColors = {};
  double _totalDeadlinesPaid = 0;
  String _chartFilter = 'Categoria'; // 'Categoria', 'Prestazione', 'Fatturato vs Contante'

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    final payments = await _dbHelper.getPayments(year: _selectedYear);
    final paymentsLastYear = await _dbHelper.getPayments(
      year: _selectedYear - 1,
    );

    final deadlines = await _dbHelper.getDeadlines();
    final invoices = await _dbHelper.getInvoices();

    final categories = await _dbHelper.getCategories();
    Map<String, String> categoryNames = {};
    Map<String, String> categoryColorsHex = {};
    for (var c in categories) {
      categoryNames[c['id']] = c['name'];
      if (c['color_hex'] != null) {
        categoryColorsHex[c['id']] = c['color_hex'];
      }
    }
    
    final services = await _dbHelper.getServiceTypes();
    Map<String, String> serviceNames = {};
    Map<String, String> serviceColorsHex = {};
    for (var s in services) {
      serviceNames[s['id']] = s['name'];
      if (s['color_hex'] != null) {
        serviceColorsHex[s['id']] = s['color_hex'];
      }
    }

    final metrics = CalculationEngine.computeDashboardMetrics(
      payments: payments,
      paymentsLastYear: paymentsLastYear,
      invoices: invoices,
      deadlines: deadlines,
      categoryNames: categoryNames,
      serviceNames: serviceNames,
      selectedYear: _selectedYear,
    );

    final metricsLastYear = CalculationEngine.computeDashboardMetrics(
      payments: paymentsLastYear,
      paymentsLastYear: [],
      invoices: invoices,
      deadlines: deadlines,
      categoryNames: categoryNames,
      serviceNames: serviceNames,
      selectedYear: _selectedYear - 1,
    );

    Map<String, Color> tempColors = {};
    for (var catName in metrics.categoryBreakdown.keys) {
      var categoryId = categoryNames.entries.firstWhere((e) => e.value == catName, orElse: () => const MapEntry('', '')).key;
      if (categoryId.isNotEmpty && categoryColorsHex[categoryId] != null) {
        tempColors[catName] = Color(int.parse(categoryColorsHex[categoryId]!));
      }
    }
    for (var srvName in metrics.serviceBreakdown.keys) {
      var serviceId = serviceNames.entries.firstWhere((e) => e.value == srvName, orElse: () => const MapEntry('', '')).key;
      if (serviceId.isNotEmpty && serviceColorsHex[serviceId] != null) {
        tempColors[srvName] = Color(int.parse(serviceColorsHex[serviceId]!));
      }
    }
    tempColors['Fatturato'] = Colors.blueAccent;
    tempColors['Contante'] = Colors.greenAccent;

    setState(() {
      _totalIn = metrics.totalIn;
      _totalOut = metrics.totalOut;
      _totalInLastYear = metricsLastYear.totalIn;
      _totalOutLastYear = metricsLastYear.totalOut;
      _payments = payments;
      _deadlines = deadlines;
      _invoices = invoices;
      _monthlyNet = metrics.monthlyNet;
      _chartDataCategoria = metrics.categoryBreakdown;
      _chartDataPrestazione = metrics.serviceBreakdown;
      _chartDataFatturatoContante = metrics.paymentMethodBreakdown;
      _categoryNames = categoryNames;
      _serviceNames = serviceNames;
      _categoryColors = tempColors;
      _totalDeadlinesPaid = metrics.totalDeadlinesPaid;
      _isLoading = false;
    });
  }

  String _calculatePercentageChange(double current, double previous) {
    return CalculationEngine.computePercentageChange(current, previous);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppThemeProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: Colors.white),
            onPressed: () {
              context.findRootAncestorStateOfType<ScaffoldState>()?.openDrawer();
            },
          ),
        ),
        title: Row(
          children: [
            Icon(Icons.account_balance_wallet, color: Colors.blueAccent),
            SizedBox(width: 8),
            Expanded(
              child: AutoScrollText(
                text: 'BIMBOMIXER CONTABILITÀ $_selectedYear',
                style: TextStyle(
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
          if (widget.role == 'admin')
            IconButton(
              icon: Icon(Icons.security, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SecurityCenterScreen()),
                );
              },
            ),
          IconButton(
            icon: Icon(Icons.notifications_none, color: Colors.white),
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Controllo aggiornamenti in corso..."), duration: Duration(seconds: 1)),
              );
              final updateService = UpdateService();
              final updateData = await updateService.checkForUpdate();
              if (updateData != null && context.mounted) {
                try {
                  final player = AudioPlayer();
                  await player.play(AssetSource('audio/notification.mp3'));
                } catch (e) {
                  print("Errore riproduzione suono: $e");
                }
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => UpdateDialog(updateData: updateData, updateService: updateService),
                );
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Nessun aggiornamento disponibile.")),
                );
              }
            },
          ),
          SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            )
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildPatrimonioCard(theme),
                    SizedBox(height: 16),
                    _buildMetricsGrid(theme),
                    SizedBox(height: 16),
                    _buildChartsSection(theme),
                    SizedBox(height: 16),
                    _buildListsSection(theme),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPatrimonioCard(AppThemeProvider theme) {
    double netto = _totalIn - _totalOut - _totalDeadlinesPaid;
    double nettoLastYear = _totalInLastYear - _totalOutLastYear;
    String change = _calculatePercentageChange(netto, nettoLastYear);
    bool isPositive = !change.startsWith('-');

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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PATRIMONIO NETTO',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.54),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '€ ${netto.toStringAsFixed(2)}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                    color: isPositive ? Colors.greenAccent : Colors.redAccent,
                    size: 16,
                  ),
                  SizedBox(width: 4),
                  Text(
                    '$change rispetto all\'anno scorso',
                    style: TextStyle(
                      color: isPositive ? Colors.greenAccent : Colors.redAccent,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              if (_totalDeadlinesPaid > 0) ...[
                SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.event_busy, color: Colors.orangeAccent, size: 13),
                    SizedBox(width: 4),
                    Text(
                      '- € ${_totalDeadlinesPaid.toStringAsFixed(2)} scadenze pagate',
                      style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(20),
            ),
            child: DropdownButton<int>(
              value: _selectedYear,
              dropdownColor: const Color(0xFF1E1E24),
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              underline: SizedBox(),
              icon: Icon(Icons.keyboard_arrow_down, color: Colors.white),
              items: [2023, 2024, 2025, 2026, 2027, 2028].map((int value) {
                return DropdownMenuItem<int>(
                  value: value,
                  child: Text(value.toString()),
                );
              }).toList(),
              onChanged: (int? newValue) {
                if (newValue != null) {
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
    String inChange = _calculatePercentageChange(_totalIn, _totalInLastYear);
    String outChange = _calculatePercentageChange(_totalOut, _totalOutLastYear);

    double margin = _totalIn > 0
        ? ((_totalIn - _totalOut) / _totalIn) * 100
        : 0;

    int unpaidInvoices = _invoices.where((i) => i['status'] != 'PAID').length;

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = constraints.maxWidth > 800 ? 4 : 2;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.5,
          children: [
            _metricCard(
              theme,
              "INCASSATO QUEST'ANNO",
              '€ ${_totalIn.toStringAsFixed(2)}',
              inChange,
              Icons.arrow_downward,
              Colors.greenAccent,
            ),
            _metricCard(
              theme,
              "SPESO QUEST'ANNO",
              '€ ${_totalOut.toStringAsFixed(2)}',
              outChange,
              Icons.arrow_upward,
              Colors.redAccent,
            ),
            _metricCard(
              theme,
              "FATTURE DA INCASSARE",
              '$unpaidInvoices',
              '$unpaidInvoices fatture in sospeso',
              Icons.receipt,
              Colors.orangeAccent,
              isAmount: false,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const InvoicesScreen()),
                );
              },
            ),
            _metricCard(
              theme,
              "MARGINE NETTO",
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
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 14,
                  child: AutoScrollText(
                    text: title,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.54),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(height: 4),
                SizedBox(
                  height: 24,
                  child: AutoScrollText(
                    text: value,
                    style: TextStyle(
                      color: color,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(height: 2),
                SizedBox(
                  height: 14,
                  child: AutoScrollText(
                    text: isAmount ? '$subtitle vs ${_selectedYear - 1}' : subtitle,
                    style: TextStyle(color: Colors.white.withOpacity(0.54), fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildChartsSection(AppThemeProvider theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isWide = constraints.maxWidth > 800;

        if (isWide) {
          return SizedBox(
            height: 350,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 2, child: _buildLineChartCard(theme)),
                SizedBox(width: 16),
                Expanded(flex: 1, child: _buildPieChartCard(theme)),
              ],
            ),
          );
        } else {
          return Column(
            children: [
              SizedBox(height: 300, child: _buildLineChartCard(theme)),
              SizedBox(height: 16),
              SizedBox(height: 300, child: _buildPieChartCard(theme)),
            ],
          );
        }
      },
    );
  }

  Widget _buildLineChartCard(AppThemeProvider theme) {
    List<FlSpot> spots = [];
    for (int i = 1; i <= 12; i++) {
      spots.add(FlSpot(i.toDouble(), _monthlyNet[i] ?? 0.0));
    }

    // Calcola range asse Y
    final allValues = spots.map((s) => s.y).toList();
    double maxY = allValues.isEmpty ? 1000 : (allValues.reduce((a, b) => a > b ? a : b));
    double minY = allValues.isEmpty ? 0 : (allValues.reduce((a, b) => a < b ? a : b));
    maxY = maxY <= 0 ? 1000 : maxY * 1.2;
    minY = minY >= 0 ? 0 : minY * 1.2;

    String formatEuro(double v) {
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
          Text(
            'ANDAMENTO MENSILE',
            style: TextStyle(
              color: Colors.white.withOpacity(0.54),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 24),
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
                        const months = ['Gen','Feb','Mar','Apr','Mag','Giu','Lug','Ago','Set','Ott','Nov','Dic'];
                        final month = spot.x.toInt() >= 1 && spot.x.toInt() <= 12
                            ? months[spot.x.toInt() - 1]
                            : '';
                        final euroVal = spot.y >= 0
                            ? '€ ${spot.y.toStringAsFixed(2)}'
                            : '- € ${spot.y.abs().toStringAsFixed(2)}';
                        return LineTooltipItem(
                          '$month\n$euroVal',
                          TextStyle(
                            color: Colors.white,
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
                      FlLine(color: Colors.white10, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (value, meta) {
                        const months = [
                          'Gen','Feb','Mar','Apr','Mag','Giu',
                          'Lug','Ago','Set','Ott','Nov','Dic',
                        ];
                        if (value.toInt() >= 1 && value.toInt() <= 12) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              months[value.toInt() - 1],
                              style: TextStyle(color: Colors.white.withOpacity(0.54), fontSize: 10),
                            ),
                          );
                        }
                        return SizedBox();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 52,
                      getTitlesWidget: (value, meta) {
                        if (value == meta.min || value == meta.max) return SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            formatEuro(value),
                            style: TextStyle(color: Colors.white38, fontSize: 9),
                            textAlign: TextAlign.right,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Dati torta condivisi ─────────────────────────────────────────────────
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

  IconData _getIconForCategory(String category) {
    final c = category.toLowerCase();
    if (c.contains('acquisti') || c.contains('spes') || c.contains('uscit') || c.contains('costi')) return Icons.shopping_cart;
    if (c.contains('incass') || c.contains('entrat') || c.contains('vendit') || c.contains('ricavi')) return Icons.attach_money;
    if (c.contains('tass') || c.contains('impost') || c.contains('iva')) return Icons.account_balance;
    if (c.contains('personale') || c.contains('dipendent') || c.contains('stipendi')) return Icons.people;
    if (c.contains('bollett') || c.contains('utenze') || c.contains('luce') || c.contains('gas')) return Icons.lightbulb;
    if (c.contains('affitt') || c.contains('locazion')) return Icons.home;
    if (c.contains('manutenzion') || c.contains('riparazion')) return Icons.build;
    if (c.contains('banca') || c.contains('commission') || c.contains('finanz')) return Icons.account_balance_wallet;
    if (c.contains('auto') || c.contains('trasport') || c.contains('carburant') || c.contains('viaggi')) return Icons.directions_car;
    if (c.contains('ristorant') || c.contains('past') || c.contains('vitto')) return Icons.restaurant;
    if (c.contains('assicu') || c.contains('polizz')) return Icons.security;
    if (c.contains('telefon') || c.contains('internet')) return Icons.phone_android;
    if (c.contains('softwar') || c.contains('abbonament') || c.contains('licenz')) return Icons.computer;
    if (c.contains('cancell') || c.contains('ufficio')) return Icons.print;
    return Icons.category;
  }

  Widget _buildBadge(IconData icon, double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
        ]
      ),
      child: Icon(icon, size: size * 0.6, color: Colors.black87),
    );
  }

  // ─── Card sulla dashboard ─────────────────────────────────────────────────
  Widget _buildPieChartCard(AppThemeProvider theme) {
    final sortedCats = _getSortedCats();
    final palette = _piePalette();

    List<PieChartSectionData> sections = [];
    final total = sortedCats.fold<double>(0, (s, e) => s + e.value);
    for (int i = 0; i < sortedCats.length; i++) {
      final entry = sortedCats[i];
      final color = _categoryColors[entry.key] ?? palette[i % palette.length];
      final pct = total > 0 ? (entry.value / total * 100) : 0.0;
      final badgeSize = pct > 10 ? 28.0 : 20.0; // Icona più piccola per sezioni piccole
      
      sections.add(PieChartSectionData(
        color: color,
        value: entry.value,
        showTitle: false,
        radius: 65,
      ));
    }
    if (sections.isEmpty) {
      sections.add(PieChartSectionData(color: Colors.white12, value: 1, title: '', radius: 65));
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
                      icon: Icon(Icons.arrow_drop_down, color: Colors.white.withOpacity(0.54)),
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      items: const [
                        DropdownMenuItem(value: 'Categoria', child: Text('RIPARTIZIONE CATEGORIE')),
                        DropdownMenuItem(value: 'Prestazione', child: Text('RIPARTIZIONE PRESTAZIONI')),
                        DropdownMenuItem(value: 'Fatturato vs Contante', child: Text('FATTURATO VS CONTANTE')),
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
                  Icon(Icons.open_in_full, color: Colors.white24, size: 14),
              ],
            ),
            SizedBox(height: 12),
            Expanded(
              child: Row(
                children: [
                  // Torta (non interattiva nella card)
                  Expanded(
                    flex: 2,
                    child: IgnorePointer(
                      child: PieChart(
                        PieChartData(
                          pieTouchData: PieTouchData(enabled: false),
                          sectionsSpace: 2,
                          centerSpaceRadius: 0,
                          sections: sections,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  // Legenda — Column invece di ListView così è sempre visibile su APK
                  Expanded(
                    flex: 3,
                    child: LayoutBuilder(
                      builder: (ctx, constraints) {
                        // Se c'è spazio sufficiente per tutti gli item: Column statica
                        // Se non c'è: ListView scrollabile
                        const itemH = 22.0;
                        final totalH = showItems * itemH;
                        final needsScroll = totalH > constraints.maxHeight;

                        final items = List.generate(showItems, (index) {
                          final entry = sortedCats[index];
                          final color = _categoryColors[entry.key] ?? palette[index % palette.length];
                          final total = sortedCats.fold<double>(0, (s, e) => s + e.value);
                          final pct = total > 0 ? (entry.value / total * 100) : 0;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Container(
                                  width: 10, height: 10,
                                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                ),
                                SizedBox(width: 6),
                                Expanded(
                                  child: AutoScrollText(
                                    text: entry.key,
                                    style: TextStyle(color: Colors.white, fontSize: 10),
                                  ),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  '${pct.toStringAsFixed(0)}%',
                                  style: TextStyle(color: Colors.white.withOpacity(0.54), fontSize: 10),
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

  // ─── Finestra full-screen torta interattiva ────────────────────────────────
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
        invoices: _invoices,
        chartFilter: _chartFilter,
        categoryNames: _categoryNames,
        serviceNames: _serviceNames,
      ),
    );
  }

  Widget _buildListsSection(AppThemeProvider theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isWide = constraints.maxWidth > 800;
        Widget movimenti = _buildRecentPayments(theme);
        Widget scadenze = _buildUpcomingDeadlines(theme);
        Widget fatture = _buildRecentInvoices(theme);

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: movimenti),
              SizedBox(width: 16),
              Expanded(child: scadenze),
              SizedBox(width: 16),
              Expanded(child: fatture),
            ],
          );
        } else {
          return Column(
            children: [movimenti, SizedBox(height: 16), scadenze, SizedBox(height: 16), fatture],
          );
        }
      },
    );
  }

  Widget _buildRecentInvoices(AppThemeProvider theme) {
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
          Text(
            'ULTIME FATTURE',
            style: TextStyle(
              color: Colors.white.withOpacity(0.54),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          if (_invoices.isEmpty)
            Center(child: Text('Nessuna fattura registrata', style: TextStyle(color: Colors.white.withOpacity(0.54)))),
          ..._invoices.take(5).map((inv) {
            String status = inv['status']?.toString() ?? '';
            String displayStatus = status == 'PAID' ? 'Incassata' : status == 'LATE' ? 'In Ritardo' : 'Da Incassare';
            Color statusColor = status == 'PAID' ? Colors.greenAccent : status == 'LATE' ? Colors.redAccent : Colors.orangeAccent;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(inv['number']?.toString() ?? 'Senza Numero', 
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Text(
                          displayStatus,
                          style: TextStyle(color: statusColor, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '€ ${inv['amount']?.toString() ?? '0.00'}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRecentPayments(AppThemeProvider theme) {
    // Ordina per data discendente (ultimi prima)
    final sortedPayments = List<Map<String, dynamic>>.from(_payments)
      ..sort((a, b) {
        final da = a['date']?.toString() ?? '';
        final db = b['date']?.toString() ?? '';
        final comp = db.compareTo(da);
        if (comp != 0) return comp;
        final idA = int.tryParse(a['id']?.toString() ?? '0') ?? 0;
        final idB = int.tryParse(b['id']?.toString() ?? '0') ?? 0;
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
          Text(
            'ULTIMI MOVIMENTI',
            style: TextStyle(
              color: Colors.white.withOpacity(0.54),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          if (sortedPayments.isEmpty)
            Text(
              'Nessun movimento.',
              style: TextStyle(color: Colors.white.withOpacity(0.54)),
            )
          else
            ...sortedPayments.take(5).map((p) {
              bool isIN = p['type'] == 'IN';
              final customerName = p['customer_name']?.toString() ?? '';
              final serviceName = p['service_name']?.toString() ?? '';
              final subtitle = [p['date'], if (customerName.isNotEmpty) customerName, if (serviceName.isNotEmpty) serviceName].join(' • ');
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
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
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p['payment_method'] ?? (isIN ? 'Incasso' : 'Spesa'),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.54),
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '€ ${p['amount'].toStringAsFixed(2)}',
                      style: TextStyle(
                        color: isIN ? Colors.greenAccent : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildUpcomingDeadlines(AppThemeProvider theme) {
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
          Text(
            'SCADENZE IN ARRIVO',
            style: TextStyle(
              color: Colors.white.withOpacity(0.54),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          if (_deadlines.isEmpty)
            Text(
              'Nessuna scadenza a breve.',
              style: TextStyle(color: Colors.white.withOpacity(0.54)),
            )
          else
            ..._deadlines.take(5).map((d) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.event_note,
                        color: Colors.orangeAccent,
                        size: 16,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d['title'],
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            d['date'],
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.54),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '€ ${d['amount'].toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
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
          return Marquee(
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

Color _darkenColor(Color c, [double amount = 0.25]) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
}

// ═══════════════════════════════════════════════════════════════════════════════
// Dialogo full-screen torta interattiva
// ═══════════════════════════════════════════════════════════════════════════════
class _PieChartFullScreenDialog extends StatefulWidget {
  final List<MapEntry<String, double>> sortedCats;
  final Map<String, Color> categoryColors;
  final List<Color> palette;
  final String title;
  final List<Map<String, dynamic>> payments;
  final List<Map<String, dynamic>> invoices;
  final String chartFilter;
  final Map<String, String> categoryNames;
  final Map<String, String> serviceNames;

  const _PieChartFullScreenDialog({
    required this.sortedCats,
    required this.categoryColors,
    required this.palette,
    required this.title,
    required this.payments,
    required this.invoices,
    required this.chartFilter,
    required this.categoryNames,
    required this.serviceNames,
  });

  @override
  State<_PieChartFullScreenDialog> createState() => _PieChartFullScreenDialogState();
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
    final selected = _selectedIndex >= 0 ? widget.sortedCats[_selectedIndex] : null;
    final selectedColor = _selectedIndex >= 0 ? _colorFor(_selectedIndex) : Colors.transparent;
    final selectedPct = selected != null && total > 0
        ? (selected.value / total * 100)
        : 0.0;

    // Costruisci sezioni senza raggio fisso qui (lo calcoleremo nel LayoutBuilder)
    
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
              // ── AppBar custom ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.pie_chart, color: Colors.blueAccent, size: 20),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.title.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.white.withOpacity(0.54)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              if (_selectedIndex < 0)
                Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Tocca una sezione per i dettagli',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),

              // ── Contenuto principale ──
              Expanded(
                child: LayoutBuilder(
                  builder: (ctx, constraints) {
                    final isWide = constraints.maxWidth > 600;

                    // Calcolo dinamico raggio (almeno 200% più grande e si adatta alla pagina)
                    double maxAvailableRadius = (isWide ? constraints.maxHeight : constraints.maxWidth) * 0.45;
                    if (maxAvailableRadius > 350) maxAvailableRadius = 350;
                    
                    // Se cliccata (pannello visibile), la torta si rimpicciolisce
                    double currentRadius = selected != null ? maxAvailableRadius * 0.65 : maxAvailableRadius;

                    final sections = List<PieChartSectionData>.generate(widget.sortedCats.length, (i) {
                      final entry = widget.sortedCats[i];
                      final color = _colorFor(i);
                      final isSelected = i == _selectedIndex;
                      final pct = total > 0 ? (entry.value / total * 100) : 0.0;
                      final badgeSize = pct > 10 ? 36.0 : (pct > 4 ? 24.0 : 18.0);
                      
                      IconData getIconForCategory(String category) {
                        final c = category.toLowerCase();
                        if (c.contains('acquisti') || c.contains('spes') || c.contains('uscit') || c.contains('costi')) return Icons.shopping_cart;
                        if (c.contains('incass') || c.contains('entrat') || c.contains('vendit') || c.contains('ricavi')) return Icons.attach_money;
                        if (c.contains('tass') || c.contains('impost') || c.contains('iva')) return Icons.account_balance;
                        if (c.contains('personale') || c.contains('dipendent') || c.contains('stipendi')) return Icons.people;
                        if (c.contains('bollett') || c.contains('utenze') || c.contains('luce') || c.contains('gas')) return Icons.lightbulb;
                        if (c.contains('affitt') || c.contains('locazion')) return Icons.home;
                        if (c.contains('manutenzion') || c.contains('riparazion')) return Icons.build;
                        if (c.contains('banca') || c.contains('commission') || c.contains('finanz')) return Icons.account_balance_wallet;
                        if (c.contains('auto') || c.contains('trasport') || c.contains('carburant') || c.contains('viaggi')) return Icons.directions_car;
                        if (c.contains('ristorant') || c.contains('past') || c.contains('vitto')) return Icons.restaurant;
                        if (c.contains('assicu') || c.contains('polizz')) return Icons.security;
                        if (c.contains('telefon') || c.contains('internet')) return Icons.phone_android;
                        if (c.contains('softwar') || c.contains('abbonament') || c.contains('licenz')) return Icons.computer;
                        if (c.contains('cancell') || c.contains('ufficio')) return Icons.print;
                        return Icons.category;
                      }

                      Widget buildBadge(IconData icon, double size) {
                        return Container(
                          width: size,
                          height: size,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
                            ]
                          ),
                          child: Icon(icon, size: size * 0.6, color: Colors.black87),
                        );
                      }

                      final textColor = color.computeLuminance() > 0.5 ? Colors.black : Colors.white;

                      return PieChartSectionData(
                        color: isSelected ? color : color.withValues(alpha: 0.75),
                        value: entry.value,
                        title: '${pct.toStringAsFixed(1)}%',
                        titleStyle: TextStyle(
                          color: textColor,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: isSelected ? 18 : 12,
                          shadows: textColor == Colors.white 
                            ? const [Shadow(color: Colors.black54, blurRadius: 4)] 
                            : null,
                        ),
                        titlePositionPercentageOffset: 0.75,
                        radius: isSelected ? currentRadius * 1.1 : currentRadius,
                        badgeWidget: pct > 2 ? buildBadge(getIconForCategory(entry.key), badgeSize) : null,
                        badgePositionPercentageOffset: 0.45,
                      );
                    });

                    final pieWidget = PieChart(
                      PieChartData(
                        sectionsSpace: 3,
                        centerSpaceRadius: 0,
                        sections: sections,
                        pieTouchData: PieTouchData(
                          enabled: true,
                          touchCallback: (event, response) {
                            if (event is FlTapUpEvent) {
                              final idx = response?.touchedSection?.touchedSectionIndex ?? -1;
                              if (idx >= 0) _selectSlice(idx);
                            }
                          },
                        ),
                      ),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOutCubic,
                    );

                    // Pannello dettaglio sezione selezionata
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
                                    color: selectedColor.withValues(alpha: 0.15),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header categoria
                                  Row(
                                    children: [
                                      Container(
                                        width: 14, height: 14,
                                        decoration: BoxDecoration(
                                          color: selectedColor,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: selectedColor.withValues(alpha: 0.5),
                                              blurRadius: 8,
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(width: 10),
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
                                  SizedBox(height: 16),

                                  // Importo totale
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: selectedColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Totale', style: TextStyle(color: Colors.white.withOpacity(0.54), fontSize: 13)),
                                        Text(
                                          '€ ${selected.value.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            color: selectedColor,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 12),

                                  // Percentuale sul totale
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('% sul totale', style: TextStyle(color: Colors.white.withOpacity(0.54), fontSize: 13)),
                                        Text(
                                          '${selectedPct.toStringAsFixed(1)}%',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 16),

                                  const Divider(color: Colors.white12),
                                  SizedBox(height: 8),
                                  Text(
                                    selected != null 
                                      ? 'TRANSAZIONI: ${selected.key.toUpperCase()}'
                                      : 'RIEPILOGO TUTTE LE CATEGORIE',
                                    style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(height: 10),

                                  // Lista (Categorie o Transazioni filtrate)
                                  Expanded(
                                    child: selected != null 
                                      ? _buildFilteredTransactionsList(selected.key, selectedColor)
                                      : ListView.builder(
                                          itemCount: widget.sortedCats.length,
                                          itemBuilder: (_, idx) {
                                            final e = widget.sortedCats[idx];
                                            final c = _colorFor(idx);
                                            final pct = total > 0 ? (e.value / total * 100) : 0.0;
                                            return Container(
                                              margin: const EdgeInsets.only(bottom: 6),
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(alpha: 0.04),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 10, height: 10,
                                                    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                                                  ),
                                                  SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      e.key,
                                                      style: TextStyle(
                                                        color: Colors.white70,
                                                        fontSize: 12,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    '€ ${e.value.toStringAsFixed(0)}',
                                                    style: TextStyle(
                                                      color: Colors.white54,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                  SizedBox(width: 6),
                                                  Text(
                                                    '${pct.toStringAsFixed(0)}%',
                                                    style: TextStyle(color: Colors.white38, fontSize: 10),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
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

              // ── Legenda scrollabile in fondo (se nessuna selezione) ──
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
                      final pct = total > 0 ? (entry.value / total * 100) : 0.0;
                      return GestureDetector(
                        onTap: () => _selectSlice(i),
                        child: Container(
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: color.withValues(alpha: 0.4)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8, height: 8,
                                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    entry.key.length > 14 ? '${entry.key.substring(0, 12)}…' : entry.key,
                                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4),
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
    if (widget.chartFilter == 'Categoria') {
      return widget.payments.where((p) {
        final catId = p['category_id']?.toString();
        if (catId == null) return false;
        final name = widget.categoryNames[catId] ?? 'Sconosciuta';
        return name == sliceKey;
      }).toList();
    } else if (widget.chartFilter == 'Prestazione') {
      return widget.payments.where((p) {
        final srvId = p['service_id']?.toString();
        if (srvId == null) return false;
        final name = widget.serviceNames[srvId] ?? 'Sconosciuta';
        return name == sliceKey;
      }).toList();
    } else if (widget.chartFilter == 'Fatturato vs Contante') {
      if (sliceKey.toLowerCase().contains('contant')) {
        return widget.payments.where((p) {
          final isIN = p['type'] == 'IN';
          final method = (p['payment_method']?.toString() ?? '').toLowerCase();
          return isIN && method.contains('contant');
        }).toList();
      } else {
        return widget.invoices.toList();
      }
    }
    return [];
  }

  Widget _buildFilteredTransactionsList(String sliceKey, Color color) {
    final list = _getFilteredTransactions(sliceKey);
    
    if (list.isEmpty) {
      return Center(
        child: Text('Nessuna transazione trovata.', style: TextStyle(color: Colors.white54)),
      );
    }

    list.sort((a, b) {
      final da = a['date']?.toString() ?? '';
      final db = b['date']?.toString() ?? '';
      return db.compareTo(da);
    });

    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        final isInvoice = item.containsKey('number');
        
        String title = '';
        String subtitle = '';
        String amount = '';

        if (isInvoice) {
          title = 'Fattura n. ${item['number'] ?? '-'}';
          subtitle = item['date'] ?? '';
          amount = '€ ${item['amount']?.toString() ?? '0.00'}';
        } else {
          bool isIN = item['type'] == 'IN';
          title = item['payment_method'] ?? (isIN ? 'Incasso' : 'Spesa');
          final customerName = item['customer_name']?.toString() ?? '';
          final serviceName = item['service_name']?.toString() ?? '';
          subtitle = [item['date'], if (customerName.isNotEmpty) customerName, if (serviceName.isNotEmpty) serviceName].join(' • ');
          amount = '€ ${item['amount']?.toString() ?? '0.00'}';
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
                    Text(title, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(color: Colors.white54, fontSize: 11)),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Text(amount, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        );
      },
    );
  }
}
