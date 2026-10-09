import codecs

with codecs.open('lib/screens/payments_screen.dart', 'r', 'utf-8') as f:
    content = f.read()

old_menu = '''        if (MediaQuery.of(context).size.width < 600)
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white70),
            onPressed: () => context.findRootAncestorStateOfType<ScaffoldState>()?.openDrawer(),
          )
        else
          const SizedBox(),'''

new_back = '''        if (MediaQuery.of(context).size.width < 600)
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white70),
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
          )
        else
          const SizedBox(),'''

content = content.replace(old_menu, new_back)

# Also fix the invoiceId search issue
# Find _formatInvoiceId
old_format = '''  String _formatInvoiceId(int index) {
    return (index + 1).toString().padLeft(3, '0');
  }'''
new_format = '''  String _formatInvoiceId(int index) {
    return (index + 1).toString().padLeft(3, '0');
  }

  String _formatRealInvoiceId(dynamic dbId) {
    int id = int.tryParse(dbId?.toString() ?? '0') ?? 0;
    return id.toString().padLeft(3, '0');
  }'''

content = content.replace(old_format, new_format)

# Now in the search block:
old_search = '''      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final id = (p['id'] ?? '').toString().toLowerCase();'''
new_search = '''      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final id = (p['id'] ?? '').toString().toLowerCase();
        final displayId = _formatRealInvoiceId(p['id']).toLowerCase();'''
content = content.replace(old_search, new_search)

# And in the return block:
old_ret = '''        return id.contains(q) ||
            client.contains(q) ||'''
new_ret = '''        return id.contains(q) ||
            displayId.contains(q) ||
            client.contains(q) ||'''
content = content.replace(old_ret, new_ret)

# Now in the builder, instead of index+1, let's use the real DB ID! Wait, if we change the ID shown to the real DB ID, the user might be confused if they were used to index? But real DB ID makes sense for "Movimenti" because it doesn't change when filtering!
# Actually, wait. I shouldn't change the visual ID if the user didn't ask for it. The user just said "la funzione di ricerca non riesce a filtrare se scrivo il numero dell'ID".
# So adding displayId.contains(q) to the search will ALSO match the _formatRealInvoiceId(p['id']).
# BUT wait! If the UI displays _formatInvoiceId(index) which is index + 1 of the FILTERED list, then when they search, the index changes, so the ID changes!
# So we MUST change the UI to display the real DB ID padding.
old_ui_id = '''                                                      final invoiceId =
                                                          _formatInvoiceId(
                                                            index,
                                                          );'''
new_ui_id = '''                                                      final invoiceId =
                                                          _formatRealInvoiceId(
                                                            p['id'],
                                                          );'''
content = content.replace(old_ui_id, new_ui_id)

with codecs.open('lib/screens/payments_screen.dart', 'w', 'utf-8') as f:
    f.write(content)

print("PaymentsScreen menu and search fixed!")
