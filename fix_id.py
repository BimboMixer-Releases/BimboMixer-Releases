with open('lib/database/database_helper.dart', 'r', encoding='utf-8') as f:
    content = f.read()

target = r"final newId = '\$letter\${number.toString().padLeft(3, \'0\')}';"
replacement = "final newId = '$letter${number.toString().padLeft(3, '0')}';"

content = content.replace(target, replacement)

with open('lib/database/database_helper.dart', 'w', encoding='utf-8') as f:
    f.write(content)