import re

with open('lib/widgets/app_sidebar.dart', 'r', encoding='utf-8') as f:
    code = f.read()

pattern = re.compile(
    r"\s*_buildNavItem\(\s*context,\s*9,\s*LucideIcons\.barChart2,\s*'Report'\s*\),"
)

code = pattern.sub("", code)

with open('lib/widgets/app_sidebar.dart', 'w', encoding='utf-8') as f:
    f.write(code)

