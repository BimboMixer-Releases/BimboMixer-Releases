with open('lib/database/database_helper.dart', 'r', encoding='utf-8') as f:
    content = f.read()

target = "FirebaseFirestore get _db => _mockDb ?? FirebaseFirestore.instance;"
replacement = "FirebaseFirestore get _db => _mockDb ?? FirebaseFirestore.instance;\n  FirebaseFirestore get db => _db;"

content = content.replace(target, replacement)

with open('lib/database/database_helper.dart', 'w', encoding='utf-8') as f:
    f.write(content)