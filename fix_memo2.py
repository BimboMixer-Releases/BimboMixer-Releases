import re

with open('lib/screens/memo_form_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

bad_payment_data = """            final paymentData = <String, dynamic>{
              'type': _transactionType == 'ENTRATA' ? 'IN' : 'OUT',
              'amount': data['amount'],
              'date': _dateType == 'SINGOLA' ? data['date'] : data['date_from'], // usa date_from se range
              'customer_id': data['customer_id'],
              'category_id': data['category_id'],
              'service_id': data['service_id'],
              'payment_method': data['payment_method'],
              'notes': data['notes'],
              'title': data['title'],
              'attachments': data['attachments'],
            };"""

good_payment_data = """            final paymentData = <String, dynamic>{
              'type': _transactionType == 'ENTRATA' ? 'IN' : 'OUT',
              'amount': data['amount'],
              'date': _dateType == 'SINGOLA' ? data['date'] : data['date_from'], // usa date_from se range
              'customer_id': data['customer_id'],
              'category_id': data['category_id'],
              'service_id': data['service_id'],
              'payment_method': data['payment_method'],
              'notes': data['notes'],
              'title': data['title'],
              'description': data['title'],
              'status': 'PAID',
              'attachments': data['attachments'],
            };"""

content = content.replace(bad_payment_data, good_payment_data)

with open('lib/screens/memo_form_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
