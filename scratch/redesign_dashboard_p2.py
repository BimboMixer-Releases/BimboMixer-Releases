import re

file_path = "lib/screens/dashboard_screen.dart"

with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Imports
imports_to_add = """
import 'package:contabile_app/screens/payment_form_screen.dart';
import 'package:contabile_app/screens/invoice_form_screen.dart';
import 'package:contabile_app/screens/deadline_form_screen.dart';
import 'package:contabile_app/screens/quote_form_screen.dart';
import 'package:contabile_app/screens/deadlines_screen.dart';
import 'package:contabile_app/screens/payments_screen.dart';
"""
if "payment_form_screen.dart" not in content:
    content = content.replace("import 'package:contabile_app/screens/invoices_screen.dart';", "import 'package:contabile_app/screens/invoices_screen.dart';" + imports_to_add)

# 2. State variables
if "Map<int, double> _monthlyIn = {};" not in content:
    content = content.replace("Map<int, double> _monthlyNet = {};", "Map<int, double> _monthlyNet = {};\n  Map<int, double> _monthlyIn = {};\n  Map<int, double> _monthlyOut = {};")

# 3. _loadDashboardData
if "_monthlyIn = metrics.monthlyIn;" not in content:
    content = content.replace("_monthlyNet = metrics.monthlyNet;", "_monthlyNet = metrics.monthlyNet;\n      _monthlyIn = metrics.monthlyIn;\n      _monthlyOut = metrics.monthlyOut;")

# 4. AppBar Add Operation Button
add_op_button = """
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
            child: PopupMenuButton<String>(
              offset: const Offset(0, 45),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: const Color(0xFF1E1E24),
              onSelected: (value) {
                if (value == 'Fattura') {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoiceFormScreen()));
                } else if (value == 'SpesaIncasso') {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentFormScreen()));
                } else if (value == 'Scadenza') {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => const DeadlineFormScreen()));
                } else if (value == 'Preventivo') {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => const QuoteFormScreen()));
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: 'Fattura', child: Row(children: [Icon(Icons.receipt, color: Colors.blueAccent), SizedBox(width:8), Text('Nuova Fattura', style: TextStyle(color: Colors.white))])),
                PopupMenuItem(value: 'SpesaIncasso', child: Row(children: [Icon(Icons.swap_horiz, color: Colors.greenAccent), SizedBox(width:8), Text('Nuova Spesa / Incasso', style: TextStyle(color: Colors.white))])),
                PopupMenuItem(value: 'Scadenza', child: Row(children: [Icon(Icons.event, color: Colors.orangeAccent), SizedBox(width:8), Text('Nuova Scadenza', style: TextStyle(color: Colors.white))])),
                PopupMenuItem(value: 'Preventivo', child: Row(children: [Icon(Icons.description, color: Colors.purpleAccent), SizedBox(width:8), Text('Nuovo Preventivo', style: TextStyle(color: Colors.white))])),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Colors.purpleAccent, Colors.blueAccent]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.blueAccent.withValues(alpha: 0.3), blurRadius: 8, spreadRadius: 1),
                  ],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.add, color: Colors.white, size: 18),
                    SizedBox(width: 4),
                    Text('Nuova operazione', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
"""
if "Nuova operazione" not in content:
    content = content.replace("if (widget.role == 'admin')", add_op_button + "          if (widget.role == 'admin')")

# 5. Line Chart updates
old_line_chart_start = """    List<FlSpot> spots = [];
    for (int i = 1; i <= 12; i++) {
      spots.add(FlSpot(i.toDouble(), _monthlyNet[i] ?? 0.0));
    }

    // Calcola range asse Y
    final allValues = spots.map((s) => s.y).toList();
    double maxY = allValues.isEmpty ? 1000 : (allValues.reduce((a, b) => a > b ? a : b));
    double minY = allValues.isEmpty ? 0 : (allValues.reduce((a, b) => a < b ? a : b));
    maxY = maxY <= 0 ? 1000 : maxY * 1.2;
    minY = minY >= 0 ? 0 : minY * 1.2;"""

new_line_chart_start = """    List<FlSpot> spotsIn = [];
    List<FlSpot> spotsOut = [];
    for (int i = 1; i <= 12; i++) {
      spotsIn.add(FlSpot(i.toDouble(), _monthlyIn[i] ?? 0.0));
      spotsOut.add(FlSpot(i.toDouble(), _monthlyOut[i] ?? 0.0));
    }

    final allValues = [...spotsIn.map((s) => s.y), ...spotsOut.map((s) => s.y)];
    double maxY = allValues.isEmpty ? 1000 : (allValues.reduce((a, b) => a > b ? a : b));
    double minY = allValues.isEmpty ? 0 : (allValues.reduce((a, b) => a < b ? a : b));
    maxY = maxY <= 0 ? 1000 : maxY * 1.2;
    minY = minY >= 0 ? 0 : minY * 1.2;"""

content = content.replace(old_line_chart_start, new_line_chart_start)

old_line_chart_title = """          Text(
            'ANDAMENTO MENSILE',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.54),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 24),"""

new_line_chart_title = """          Row(
            children: [
              Text(
                'ANDAMENTO MENSILE',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.54),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Spacer(),
              Icon(Icons.circle, color: Colors.blueAccent, size: 10),
              SizedBox(width: 4),
              Text('Incassi', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
              SizedBox(width: 16),
              Icon(Icons.circle, color: Colors.purpleAccent, size: 10),
              SizedBox(width: 4),
              Text('Spese', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
              SizedBox(width: 8),
            ],
          ),
          SizedBox(height: 24),"""

content = content.replace(old_line_chart_title, new_line_chart_title)


old_line_bars = """                lineBarsData: [
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
                ],"""

new_line_bars = """                lineBarsData: [
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
                ],"""

content = content.replace(old_line_bars, new_line_bars)


# Update tooltip to show both
old_tooltip = """                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        const months = ['Gen','Feb','Mar','Apr','Mag','Giu','Lug','Ago','Set','Ott','Nov','Dic'];
                        final month = spot.x.toInt() >= 1 && spot.x.toInt() <= 12
                            ? months[spot.x.toInt() - 1]
                            : '';
                        final euroVal = spot.y >= 0
                            ? '€ ${spot.y.toStringAsFixed(2)}'
                            : '- € ${spot.y.abs().toStringAsFixed(2)}';
                        return LineTooltipItem(
                          '$month\\n$euroVal',
                          TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },"""

new_tooltip = """                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        const months = ['Gen','Feb','Mar','Apr','Mag','Giu','Lug','Ago','Set','Ott','Nov','Dic'];
                        final month = spot.x.toInt() >= 1 && spot.x.toInt() <= 12
                            ? months[spot.x.toInt() - 1]
                            : '';
                        final isIncasso = spot.barIndex == 0;
                        final title = isIncasso ? 'Incassi' : 'Spese';
                        final color = isIncasso ? Colors.blueAccent : Colors.purpleAccent;
                        
                        return LineTooltipItem(
                          '$month\\n$title: € ${spot.y.toStringAsFixed(2)}',
                          TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },"""

content = content.replace(old_tooltip, new_tooltip)


# 6. "Vedi tutti" buttons in lists headers
def replace_header(title, action):
    old_h = f"""          Text(
            '{title}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.54),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),"""
    new_h = f"""          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '{title}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.54),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              InkWell(
                onTap: () {{
                  {action}
                }},
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    children: [
                      Text('Vedi tutti', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward, color: Colors.white.withValues(alpha: 0.7), size: 12),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),"""
    return old_h, new_h

old_m, new_m = replace_header('ULTIMI MOVIMENTI', 'Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentsScreen()));')
content = content.replace(old_m, new_m)

old_s, new_s = replace_header('SCADENZE IN ARRIVO', 'Navigator.push(context, MaterialPageRoute(builder: (_) => const DeadlinesScreen()));')
content = content.replace(old_s, new_s)

old_f, new_f = replace_header('ULTIME FATTURE', 'Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoicesScreen()));')
content = content.replace(old_f, new_f)


# 7. Empty state per Scadenze
old_empty_scadenze = """          if (_deadlines.isEmpty)
            Text(
              'Nessuna scadenza a breve.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.54)),
            )
          else"""

new_empty_scadenze = """          if (_deadlines.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Column(
                  children: [
                    Icon(Icons.calendar_month, color: Colors.purpleAccent.withValues(alpha: 0.8), size: 48),
                    SizedBox(height: 16),
                    Text('Nessuna scadenza a breve.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(height: 8),
                    Text('Quando ci saranno scadenze, le troverai qui\\nper tenerle sempre sotto controllo.', 
                         textAlign: TextAlign.center, 
                         style: TextStyle(color: Colors.white.withValues(alpha: 0.54), fontSize: 12)),
                    SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Colors.purpleAccent, Colors.blueAccent]),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: Colors.purpleAccent.withValues(alpha: 0.3), blurRadius: 8, spreadRadius: 1),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const DeadlineFormScreen()));
                        },
                        icon: Icon(Icons.add, color: Colors.white, size: 18),
                        label: Text('Nuova Scadenza', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else"""

content = content.replace(old_empty_scadenze, new_empty_scadenze)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)
print("File dashboard_screen.dart aggiornato!")
