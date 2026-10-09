import codecs
import re

with codecs.open('lib/screens/reports_screen.dart', 'r', 'utf-8') as f:
    content = f.read()

# We need to find the Container that wraps the status text.
old_block = '''                            Container(
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
                            ),'''

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
                                    side: BorderSide(color: Colors.white54, width: 1.5),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  ),
                                ),
                              ],
                            ),'''

if old_block in content:
    content = content.replace(old_block, new_block)
    with codecs.open('lib/screens/reports_screen.dart', 'w', 'utf-8') as f:
        f.write(content)
    print("Replaced successfully.")
else:
    print("Could not find the block.")
