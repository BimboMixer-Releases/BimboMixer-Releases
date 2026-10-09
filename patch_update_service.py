# -*- coding: utf-8 -*-
import sys

with open('lib/services/update_service.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix _versionToInt
old_code = '''  int _versionToInt(String version) {
    String cleaned = version.replaceAll(RegExp(r'[^0-9.]'), '');
    List<String> parts = cleaned.split('.');
    int val = 0;
    if (parts.isNotEmpty) val += (int.tryParse(parts[0]) ?? 0) * 10000;
    if (parts.length > 1) val += (int.tryParse(parts[1]) ?? 0) * 100;
    if (parts.length > 2) val += (int.tryParse(parts[2]) ?? 0);
    return val;
  }'''

new_code = '''  int _versionToInt(String version) {
    String cleaned = version.replaceAll(RegExp(r'[^0-9.]'), '');
    List<String> parts = cleaned.split('.');
    int val = 0;
    if (parts.isNotEmpty) val += (int.tryParse(parts[0]) ?? 0) * 1000000;
    if (parts.length > 1) val += (int.tryParse(parts[1]) ?? 0) * 1000;
    if (parts.length > 2) val += (int.tryParse(parts[2]) ?? 0);
    return val;
  }'''

content = content.replace(old_code, new_code)

with open('lib/services/update_service.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("update_service.dart fixed")
