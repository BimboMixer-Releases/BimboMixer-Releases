# -*- coding: utf-8 -*-
import sys

with open('pubspec.yaml', 'r', encoding='utf-8') as f:
    content = f.read()

# find version
for line in content.split('\n'):
    if line.startswith('version: '):
        old_version_line = line
        parts = line.split(' ')[1].split('+')
        v_parts = parts[0].split('.')
        build_num = int(parts[1])
        
        major = int(v_parts[0])
        minor = int(v_parts[1])
        patch = int(v_parts[2])
        
        patch += 1
        if patch > 99:
            minor += 1
            patch = 1
        build_num += 1
        
        new_version_line = f"version: {major}.{minor}.{patch}+{build_num}"
        content = content.replace(old_version_line, new_version_line)
        print(f"Updated: {old_version_line} -> {new_version_line}")
        break

with open('pubspec.yaml', 'w', encoding='utf-8') as f:
    f.write(content)
