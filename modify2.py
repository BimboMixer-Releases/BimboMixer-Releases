import re

with open('lib/screens/invoices_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

target = '''    invoices.sort((a, b) {
      // Prioritize status: LATE > PENDING > PAID
      int pA = a['status'] == 'LATE' ? 1 : a['status'] == 'PAID' ? 3 : 2;
      int pB = b['status'] == 'LATE' ? 1 : b['status'] == 'PAID' ? 3 : 2;

      if (pA != pB) return pA.compareTo(pB);

      // Natural sort by number (e.g. "FPR 1/26" before "FPR 10/26")
      String numStrA = a['number']?.toString() ?? '';
      String numStrB = b['number']?.toString() ?? '';
      final matchA = RegExp(r'\d+').firstMatch(numStrA);
      final matchB = RegExp(r'\d+').firstMatch(numStrB);
      
      int numA = matchA != null ? int.parse(matchA.group(0)!) : 0;
      int numB = matchB != null ? int.parse(matchB.group(0)!) : 0;
      
      return numA.compareTo(numB);
    });

    setState(() {
      _invoices = invoices;
      _customers = customers;
      _isLoading = false;
    });
  }'''

replacement = '''    setState(() {
      _invoices = invoices;
      _customers = customers;
      _isLoading = false;
    });
  }

  int _compareInvoiceNumbers(String a, String b) {
    final regex = RegExp(r'^([a-zA-Z]+)?\s*(\d+)\s*(?:/|-)?\s*(\d+)?$');
    final matchA = regex.firstMatch(a.trim());
    final matchB = regex.firstMatch(b.trim());

    if (matchA != null && matchB != null) {
      final yearA = int.tryParse(matchA.group(3) ?? '0') ?? 0;
      final yearB = int.tryParse(matchB.group(3) ?? '0') ?? 0;
      if (yearA != yearB) return yearB.compareTo(yearA);

      final numA = int.tryParse(matchA.group(2) ?? '0') ?? 0;
      final numB = int.tryParse(matchB.group(2) ?? '0') ?? 0;
      if (numA != numB) return numB.compareTo(numA);

      final prefixA = matchA.group(1) ?? '';
      final prefixB = matchB.group(1) ?? '';
      return prefixA.compareTo(prefixB);
    }
    return b.compareTo(a);
  }

  List<Map<String, dynamic>> get _filteredInvoices {
    var filtered = List<Map<String, dynamic>>.from(_invoices);
    
    if (_sortType == InvoiceSortType.number) {
      filtered.sort((a, b) {
        String numA = a['number']?.toString() ?? '';
        String numB = b['number']?.toString() ?? '';
        return _compareInvoiceNumbers(numA, numB);
      });
      if (_sortAscending) {
        filtered = filtered.reversed.toList();
      }
    } else {
      if (_sortAscending) {
        filtered = filtered.reversed.toList();
      }
    }
    return filtered;
  }'''

content = content.replace(target, replacement)

with open('lib/screens/invoices_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
