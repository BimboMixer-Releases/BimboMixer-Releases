# -*- coding: utf-8 -*-
import sys

with open('lib/screens/invoices_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

bad_end = '''                  );
                          },
                        );
                      }
                    ),
                  ),
                ],
              ),
      );
    }
}'''

good_end = '''                  );
                          },
                        );
                      }
                    ),
                  ),
                ],
              ),
      );
    }'''

content = content.replace(bad_end, good_end)

with open('lib/screens/invoices_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
