# -*- coding: utf-8 -*-
import sys

with open('lib/screens/users_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

old_title = '''                          title: Text(
                            user['username']?.toString() ?? 'Utente',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),'''

new_title = '''                          title: Text(
                            user['username']?.toString() ?? 'Utente',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),'''

old_subtitle = '''                          subtitle: Text(
                            'Ruolo: \',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),'''

new_subtitle = '''                          subtitle: Text(
                            'Ruolo: \',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),'''

content = content.replace(old_title, new_title)
content = content.replace(old_subtitle, new_subtitle)

with open('lib/screens/users_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("users_screen updated")
