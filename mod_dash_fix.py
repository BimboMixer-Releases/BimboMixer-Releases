with open('lib/screens/dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

target = '''        if(dtA != null && dtB != null) return _sortPaymentsAscending ? dtA.compareTo(dtB) : dtB.compareTo(dtA);
        return widget.sortAscending ? da.compareTo(db) : db.compareTo(da);'''

replacement = '''        if(dtA != null && dtB != null) return _sortPaymentsAscending ? dtA.compareTo(dtB) : dtB.compareTo(dtA);
        return _sortPaymentsAscending ? da.compareTo(db) : db.compareTo(da);'''

content = content.replace(target, replacement)

with open('lib/screens/dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
