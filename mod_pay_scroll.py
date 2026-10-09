with open('lib/screens/payments_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

target1 = '''                  return SingleChildScrollView(
                    child: Padding('''
replacement1 = '''                  return Padding('''
content = content.replace(target1, replacement1)

target2 = '''                      // 3. MAIN GLASS CONTAINER: "Transactions Overview"
                      SizedBox(
                        height: glassHeight,'''
replacement2 = '''                      // 3. MAIN GLASS CONTAINER: "Transactions Overview"
                      Expanded('''
content = content.replace(target2, replacement2)

target4 = '''                    ]
                  ),
                  ),
                );
              },
            ),'''

replacement4 = '''                    ]
                  ),
                );
              },
            ),'''
content = content.replace(target4, replacement4)

with open('lib/screens/payments_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
