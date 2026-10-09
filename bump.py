import sys
import re

with open('pubspec.yaml', 'r', encoding='utf-8') as f:
    content = f.read()

match = re.search(r'version: (\d+)\.(\d+)\.(\d+)\+(\d+)', content)
if match:
    major = match.group(1)
    minor = match.group(2)
    patch = int(match.group(3))
    build = int(match.group(4))
    
    new_version = f'version: {major}.{minor}.{patch+1}+{build+1}'
    content = content.replace(match.group(0), new_version)
    
    with open('pubspec.yaml', 'w', encoding='utf-8') as f:
        f.write(content)
    print(f'Bumped to {new_version}')
else:
    print('Version string not found')
