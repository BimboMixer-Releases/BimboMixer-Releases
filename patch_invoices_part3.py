# -*- coding: utf-8 -*-
import sys

with open('lib/screens/invoices_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace body: _isLoading ? Center(...) : ListView.builder(...)
old_body = '''        body: _isLoading
            ? Center(
                child: CircularProgressIndicator(color: Colors.blueAccent))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _invoices.length,
                itemBuilder: (context, index) {
                  final invoice = _invoices[index];'''

new_body = '''        body: _isLoading
            ? Center(
                child: CircularProgressIndicator(color: Colors.blueAccent))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        _buildFilterChip('Tutte'),
                        _buildFilterChip('Da Incassare'),
                        _buildFilterChip('Incassata'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final filteredList = _invoices.where((i) {
                          if (_filterStatus == 'Tutte') return true;
                          if (_filterStatus == 'Da Incassare') return i['status'] != 'PAID' && i['status'] != 'Pagato' && i['status'] != 'Incassata';
                          if (_filterStatus == 'Incassata') return i['status'] == 'PAID' || i['status'] == 'Pagato' || i['status'] == 'Incassata';
                          return true;
                        }).toList();
                        
                        if (filteredList.isEmpty) {
                          return Center(child: Text('Nessuna fattura', style: TextStyle(color: Colors.white54)));
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredList.length,
                          itemBuilder: (context, index) {
                            final invoice = filteredList[index];'''

content = content.replace(old_body, new_body)

# We need to add the closing tags for Expanded and Column
old_end = '''                  );
                },
              ),
      );
    }
}'''

new_end = '''                  );
                          },
                        );
                      }
                    ),
                  ),
                ],
              ),
      );
    }
}'''

content = content.replace(old_end, new_end)

with open('lib/screens/invoices_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
