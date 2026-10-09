import re

with open('lib/screens/invoice_summary_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = re.sub(r'\s*String\?\s*_categoryName;', '', content)
content = re.sub(r'\s*String\?\s*_serviceName;', '', content)

content = re.sub(r'\s*final catId = pData\[\'category_id\'\];.*?(?=\s*if \(pData\[\'attachments\'\])', '', content, flags=re.DOTALL)

with open('lib/screens/invoice_summary_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)