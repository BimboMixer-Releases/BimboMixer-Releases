with open('lib/screens/dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix the invalid await
target1 = '''    final prefs = await SharedPreferences.getInstance();
    final bool sortAscending = prefs.getBool('payments_sort_ascending') ?? false;'''
replacement1 = ''

content = content.replace(target1, replacement1)

target2 = '''return sortAscending ? da.compareTo(db) : db.compareTo(da);'''
replacement2 = '''return _sortPaymentsAscending ? da.compareTo(db) : db.compareTo(da);'''

content = content.replace(target2, replacement2)

# Add _sortPaymentsAscending
target3 = '''  bool _isLoading = true;'''
replacement3 = '''  bool _isLoading = true;
  bool _sortPaymentsAscending = false;'''

content = content.replace(target3, replacement3)

# Add reading preferences in _loadDashboardData
target4 = '''    final paymentsLastYear = await _dbHelper.getPayments(
      year: _selectedYear - 1,
    );'''
replacement4 = '''    final paymentsLastYear = await _dbHelper.getPayments(
      year: _selectedYear - 1,
    );
    final prefs = await SharedPreferences.getInstance();
    _sortPaymentsAscending = prefs.getBool('payments_sort_ascending') ?? false;'''

content = content.replace(target4, replacement4)

# Modify _buildRecentPayments
target5 = '''// Ordina per data discendente (ultimi prima)
    final sortedPayments = List<Map<String, dynamic>>.from(_globalRecentPayments)
      ..sort((a, b) {
        final da = a['date']?.toString() ?? '';
        final db = b['date']?.toString() ?? '';
        DateTime? dtA, dtB;
        try {
            final pA = da.split('/');
            if(pA.length==3) dtA = DateTime(int.parse(pA[2]), int.parse(pA[1]), int.parse(pA[0]));
        }catch(_){}
        try {
            final pB = db.split('/');
            if(pB.length==3) dtB = DateTime(int.parse(pB[2]), int.parse(pB[1]), int.parse(pB[0]));
        }catch(_){}
        if(dtA != null && dtB != null) return dtB.compareTo(dtA);
        return db.compareTo(da);
      });'''

replacement5 = '''// Ordina per data in base alle preferenze
    final sortedPayments = List<Map<String, dynamic>>.from(_globalRecentPayments)
      ..sort((a, b) {
        final da = a['date']?.toString() ?? '';
        final db = b['date']?.toString() ?? '';
        DateTime? dtA, dtB;
        try {
            final pA = da.split('/');
            if(pA.length==3) dtA = DateTime(int.parse(pA[2]), int.parse(pA[1]), int.parse(pA[0]));
        }catch(_){}
        try {
            final pB = db.split('/');
            if(pB.length==3) dtB = DateTime(int.parse(pB[2]), int.parse(pB[1]), int.parse(pB[0]));
        }catch(_){}
        if(dtA != null && dtB != null) return _sortPaymentsAscending ? dtA.compareTo(dtB) : dtB.compareTo(dtA);
        return _sortPaymentsAscending ? da.compareTo(db) : db.compareTo(da);
      });'''

content = content.replace(target5, replacement5)

with open('lib/screens/dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
