# -*- coding: utf-8 -*-
import sys

with open('.agents/AGENTS.md', 'r', encoding='utf-8') as f:
    content = f.read()

rule = "\n## Regola Versione\n- **Nuova regola (Ottobre 2026)**: Il terzo numero della versione non deve mai superare il 99. Se si arriva a 1.x.99, l'aggiornamento successivo dovrà incrementare il numero centrale e azzerare l'ultimo a 1 (es. da 1.8.99 si passa a 1.9.1, NON a 1.8.100). Il build number dopo il + continua a salire progressivamente sempre.\n"

if "Regola Versione" not in content:
    content += rule
    with open('.agents/AGENTS.md', 'w', encoding='utf-8') as f:
        f.write(content)
    print("Rule added to AGENTS.md")
