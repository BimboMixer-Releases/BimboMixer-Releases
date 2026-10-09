# -*- coding: utf-8 -*-
import codecs

with codecs.open('lib/widgets/custom_3d_pie_chart.dart', 'r', 'utf-8') as f:
    content = f.read()

# Add import for currency_utils if it doesn't exist
if "import 'package:contabile_app/utils/currency_utils.dart';" not in content:
    content = content.replace(
        "import 'package:intl/intl.dart';", 
        "import 'package:intl/intl.dart';\nimport 'package:contabile_app/utils/currency_utils.dart';"
    )

content = content.replace("fmt.format(total).replaceAll(',00', '')", "CurrencyUtils.formatNumber(total) + ' \u20ac'")
content = content.replace("fmt.format(entry.value).replaceAll(',00', '')", "CurrencyUtils.formatNumber(entry.value) + ' \u20ac'")

with codecs.open('lib/widgets/custom_3d_pie_chart.dart', 'w', 'utf-8') as f:
    f.write(content)
print("Updated currency formatting!")
