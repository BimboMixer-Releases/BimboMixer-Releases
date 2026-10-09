lines = []
with open('test_syntax.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Remove the lines 780, 787, 791 (which are index 779, 786, 790)
# But wait, we have to do it in reverse order to not mess up indices.
del lines[790]
del lines[786]
del lines[779]

with open('test_syntax2.dart', 'w', encoding='utf-8') as f:
    f.writelines(lines)
