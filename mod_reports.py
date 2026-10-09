import re

with open('lib/screens/reports_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

target = '''      return StreamBuilder<QuerySnapshot>(
        stream: DatabaseHelper().db
            .collection(collection)
            .orderBy('timestamp', descending: true)
            .snapshots(),'''

replacement = '''      return StreamBuilder<QuerySnapshot>(
        stream: DatabaseHelper().db
            .collection(collection)
            .snapshots(),'''

content = content.replace(target, replacement)

target2 = '''          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {'''

replacement2 = '''          final docs = snapshot.data?.docs.toList() ?? [];
          docs.sort((a, b) {
            final Map<String, dynamic>? dataA = a.data() as Map<String, dynamic>?;
            final Map<String, dynamic>? dataB = b.data() as Map<String, dynamic>?;
            final tA = dataA != null && dataA.containsKey('timestamp') ? dataA['timestamp'] : null;
            final tB = dataB != null && dataB.containsKey('timestamp') ? dataB['timestamp'] : null;
            if (tA == null && tB == null) return 0;
            if (tA == null) return 1;
            if (tB == null) return -1;
            return tB.compareTo(tA);
          });
          
          if (docs.isEmpty) {'''

content = content.replace(target2, replacement2)

with open('lib/screens/reports_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
