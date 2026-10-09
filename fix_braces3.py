with open('lib/screens/payments_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

idx_listview = content.find('ListView.separated(')
idx_build_end = content.find('  String _getShortId(String? id) {')

if idx_listview != -1 and idx_build_end != -1:
    # find the end of ListView.separated
    idx_listview_end = content.find('                                    ),', idx_listview)
    if idx_listview_end != -1:
        replacement = '''                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
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
        
        # Replace everything from the end of the ListView up to _getShortId
        content = content[:idx_listview_end] + replacement + '\n\n  // Top Header Bar: Welcome text, Search input, notification bell, AXION logo\n' + content[idx_build_end:]
        
        with open('lib/screens/payments_screen.dart', 'w', encoding='utf-8') as f:
            f.write(content)
