with open('lib/screens/payments_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

target = '''          // Right side: Search Box + Bell + AXION Brand
          Row(
            children: [
              // Search Box Capsule
              Container(
                width: 240,'''

replacement = '''          // Right side: Search Box + Bell + AXION Brand
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Search Box Capsule
                Flexible(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 240),'''

content = content.replace(target, replacement)

target2 = '''                        decoration: const InputDecoration(
                          hintText: 'Search',
                          hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
  
              const SizedBox(width: 16),
  
  
            ],
      );'''

replacement2 = '''                        decoration: const InputDecoration(
                          hintText: 'Search',
                          hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );'''

content = content.replace(target2, replacement2)

with open('lib/screens/payments_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
