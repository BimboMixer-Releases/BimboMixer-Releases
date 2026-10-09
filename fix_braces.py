with open('lib/screens/payments_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

target = '''                      ),
                    ),
                  ],
                ),
              ),
            ),
                  ],
                ),
              ),
            );
           },
          ),
        ),
  );
  }'''

replacement = '''                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
    );
  }'''

content = content.replace(target, replacement)

with open('lib/screens/payments_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
