import re

with open('lib/screens/payments_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Add to initState
init_state_target = '''  void initState() {
    super.initState();
    _loadData();'''

init_state_replacement = '''  void initState() {
    super.initState();
    _loadPrefsAndData();
  }

  Future<void> _loadPrefsAndData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _sortAscending = prefs.getBool('payments_sort_ascending') ?? false;
    });
    _loadData();'''

content = content.replace(init_state_target, init_state_replacement)

# Update the onPressed handler
on_pressed_target = '''onPressed: () { setState(() { _sortAscending = !_sortAscending; }); }'''

on_pressed_replacement = '''onPressed: () async { 
                                            final newValue = !_sortAscending;
                                            setState(() { _sortAscending = newValue; }); 
                                            final prefs = await SharedPreferences.getInstance();
                                            await prefs.setBool('payments_sort_ascending', newValue);
                                          }'''

content = content.replace(on_pressed_target, on_pressed_replacement)

with open('lib/screens/payments_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
