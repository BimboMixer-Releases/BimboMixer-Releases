# -*- coding: utf-8 -*-
import sys

with open('lib/screens/invoices_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add _filterStatus
if "String _filterStatus = 'Tutte';" not in content:
    content = content.replace("bool _isLoading = true;", "bool _isLoading = true;\n  String _filterStatus = 'Tutte';")

# 2. Add _buildFilterChip
chip_method = '''
  Widget _buildFilterChip(String label) {
    bool isSelected = _filterStatus == label;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        setState(() {
          _filterStatus = label;
        });
      },
      selectedColor: Colors.blueAccent.withValues(alpha: 0.3),
      checkmarkColor: Colors.blueAccent,
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? Colors.blueAccent : Colors.white.withValues(alpha: 0.2),
        ),
      ),
      labelStyle: TextStyle(
        color: isSelected ? Colors.blueAccent : Colors.white.withValues(alpha: 0.7),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
'''
if "_buildFilterChip" not in content:
    content = content.replace("Widget build(BuildContext context) {", chip_method + "\n  @override\n  Widget build(BuildContext context) {")

with open('lib/screens/invoices_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
