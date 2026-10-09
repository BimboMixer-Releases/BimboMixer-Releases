import sys

with open('lib/database/database_helper.dart', 'r', encoding='utf-8') as f:
    content = f.read()

if "import '../utils/sort_utils.dart';" not in content:
    content = content.replace("import 'package:cloud_firestore/cloud_firestore.dart';", "import 'package:cloud_firestore/cloud_firestore.dart';\nimport '../utils/sort_utils.dart';")

with open('lib/database/database_helper.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print('Done!')
