# -*- coding: utf-8 -*-
import sys
import re

with open('lib/screens/dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Add _fiscoWarningColor to state
if "Color? _fiscoWarningColor;" not in content:
    content = content.replace("List<Map<String, dynamic>> _scheduledPayments = [];", "List<Map<String, dynamic>> _scheduledPayments = [];\n  Color? _fiscoWarningColor;")

# Add calculation to _loadDashboardData
calc = '''
      double entrateF = 0;
      double usciteF = 0;
      for (var inv in invoices) {
        if (inv['status'] == 'PAID' || inv['status'] == 'Incassata') {
          entrateF += double.tryParse(inv['amount']?.toString() ?? '0') ?? 0;
        }
      }
      for (var p in globalPayments) {
        if (p['status'] == 'PAID' || p['status'] == 'Pagato') {
          final method = (p['payment_method']?.toString() ?? '').toLowerCase();
          if (method.contains('carta') || method.contains('credito')) {
            double amt = double.tryParse(p['amount']?.toString() ?? '0') ?? 0;
            if (p['type'] == 'IN') entrateF += amt;
            else if (p['type'] == 'OUT') usciteF += amt;
          }
        }
      }
      if (usciteF > entrateF) {
        _fiscoWarningColor = Colors.redAccent;
      } else if (usciteF > entrateF * 0.8) {
        _fiscoWarningColor = Colors.orangeAccent;
      } else if (entrateF > 0) {
        _fiscoWarningColor = Colors.greenAccent;
      } else {
        _fiscoWarningColor = null;
      }
'''
if "double entrateF = 0;" not in content:
    content = content.replace("setState(() {", calc + "\n      setState(() {")

# Update DesktopDashboardAppBar constructor and instantiation
content = content.replace(
    "const DesktopDashboardAppBar({Key? key, required this.role, required this.selectedYear, required this.onDataChanged}) : super(key: key);",
    "final Color? fiscoWarningColor;\n  const DesktopDashboardAppBar({Key? key, required this.role, required this.selectedYear, required this.onDataChanged, this.fiscoWarningColor}) : super(key: key);"
)

content = content.replace(
    "DesktopDashboardAppBar(role: widget.role, selectedYear: _selectedYear, onDataChanged: _loadDashboardData)",
    "DesktopDashboardAppBar(role: widget.role, selectedYear: _selectedYear, onDataChanged: _loadDashboardData, fiscoWarningColor: _fiscoWarningColor)"
)

# Update MobileDashboardAppBar constructor and instantiation
content = content.replace(
    "const MobileDashboardAppBar({Key? key, required this.role, required this.selectedYear, required this.onDataChanged}) : super(key: key);",
    "final Color? fiscoWarningColor;\n  const MobileDashboardAppBar({Key? key, required this.role, required this.selectedYear, required this.onDataChanged, this.fiscoWarningColor}) : super(key: key);"
)

content = content.replace(
    "MobileDashboardAppBar(role: widget.role, selectedYear: _selectedYear, onDataChanged: _loadDashboardData)",
    "MobileDashboardAppBar(role: widget.role, selectedYear: _selectedYear, onDataChanged: _loadDashboardData, fiscoWarningColor: _fiscoWarningColor)"
)

# Add icon near notifications in both AppBars
# Search for IconButton(icon: Icon(Icons.notifications_none
icon_bell = '''          if (fiscoWarningColor != null)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Icon(Icons.error_outline, color: fiscoWarningColor, size: 28),
            ),
          IconButton(
            icon: Icon(Icons.notifications_none'''

content = content.replace("          IconButton(\n            icon: Icon(Icons.notifications_none", icon_bell)

with open('lib/screens/dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print('Done!')
