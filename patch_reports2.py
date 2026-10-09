import codecs
import re

with codecs.open('lib/screens/reports_screen.dart', 'r', 'utf-8') as f:
    content = f.read()

pattern = r'''                            Container\(\s*padding: const EdgeInsets\.symmetric\(\s*horizontal: 8,\s*vertical: 4,\s*\),\s*decoration: BoxDecoration\(\s*color:\s*status == 'Risolto' \|\|\s*status == 'Implementato'\s*\?\s*Colors\.green\.withValues\(alpha: 0\.15\)\s*:\s*Colors\.white\.withValues\(alpha: 0\.1\),\s*borderRadius: BorderRadius\.circular\(6\),\s*\),\s*child: Text\(\s*status\.toUpperCase\(\),\s*style: TextStyle\(\s*color:\s*status == 'Risolto' \|\|\s*status == 'Implementato'\s*\?\s*Colors\.greenAccent\s*:\s*Colors\.white60,\s*fontSize: 9,\s*fontWeight: FontWeight\.bold,\s*\),\s*\),\s*\),'''

new_block = '''                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        status == 'Risolto' ||
                                            status == 'Implementato'
                                        ? Colors.green.withValues(alpha: 0.15)
                                        : Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: TextStyle(
                                      color:
                                          status == 'Risolto' ||
                                              status == 'Implementato'
                                          ? Colors.greenAccent
                                          : Colors.white60,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    value: status == 'Risolto' || status == 'Implementato',
                                    onChanged: (val) {
                                      final newStatus = val == true 
                                          ? (collection == 'bug_reports' ? 'Risolto' : 'Implementato')
                                          : 'Nuovo';
                                      docs[index].reference.update({'status': newStatus});
                                    },
                                    activeColor: Colors.greenAccent,
                                    checkColor: Colors.black,
                                    side: const BorderSide(color: Colors.white54, width: 1.5),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  ),
                                ),
                              ],
                            ),'''

if re.search(pattern, content):
    content = re.sub(pattern, new_block, content)
    with codecs.open('lib/screens/reports_screen.dart', 'w', 'utf-8') as f:
        f.write(content)
    print("Replaced successfully via regex.")
else:
    print("Could not find the block.")
