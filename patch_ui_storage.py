import re

with open('lib/screens/payment_form_screen.dart', 'r', encoding='utf-8') as f:
    code = f.read()

# Trova dove viene rimosso l'allegato
pattern = re.compile(r'_attachments\.removeAt\(idx\);')
replacement = r'''String urlToRemove = _attachments[idx];
                                              _attachments.removeAt(idx);
                                              AttachmentService().deleteAttachment(urlToRemove);'''
code = pattern.sub(replacement, code)

with open('lib/screens/payment_form_screen.dart', 'w', encoding='utf-8') as f:
    f.write(code)

with open('lib/screens/invoices_screen.dart', 'r', encoding='utf-8') as f:
    code2 = f.read()

pattern2 = re.compile(r'attachments\.removeAt\(idx\);')
replacement2 = r'''String urlToRemove = attachments[idx];
                                        attachments.removeAt(idx);
                                        AttachmentService().deleteAttachment(urlToRemove);'''
code2 = pattern2.sub(replacement2, code2)

with open('lib/screens/invoices_screen.dart', 'w', encoding='utf-8') as f:
    f.write(code2)

with open('lib/screens/deadlines_screen.dart', 'r', encoding='utf-8') as f:
    code3 = f.read()

code3 = pattern2.sub(replacement2, code3)

with open('lib/screens/deadlines_screen.dart', 'w', encoding='utf-8') as f:
    f.write(code3)

