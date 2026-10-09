# -*- coding: utf-8 -*-
import sys

with open('lib/screens/users_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

old_subtitle = "                            'Ruolo: \',\n"
new_subtitle = "                            'Ruolo: \',\n                            maxLines: 1,\n                            overflow: TextOverflow.ellipsis,\n"
content = content.replace(old_subtitle, new_subtitle)

with open('lib/screens/users_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
