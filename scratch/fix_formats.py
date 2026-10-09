import os
import re

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    original = content
    
    if '.toStringAsFixed(2)' in content:
        if 'package:contabile_app/utils/currency_utils.dart' not in content and 'utils/currency_utils.dart' not in content:
            content = 'import \'package:contabile_app/utils/currency_utils.dart\';\n' + content

    content = re.sub(r'€\s*\$\{\{?([\w\.\?\(\)\[\]\'\"]+?)\.toStringAsFixed\(2\)\}?\}', r'${CurrencyUtils.formatEuro(\g<1>)}', content)
    content = re.sub(r'€\s*([\w\.\?\(\)\[\]\'\"]+?)\.toStringAsFixed\(2\)', r'${CurrencyUtils.formatEuro(\g<1>)}', content)
    
    # Fix bug: replace double.tryParse(... ?? '0')?.toStringAsFixed(2)
    # Be careful not to replace it with CurrencyUtils.formatNumber('0')?) ?? '0.00'
    # Actually, we can just replace .toStringAsFixed(2) with CurrencyUtils.formatNumber(...)
    # but handle the '0' case explicitly if needed, or simply not match things ending in `?`
    content = re.sub(r'([\w\.\(\)\[\]\'\"]+)\.toStringAsFixed\(2\)', r'CurrencyUtils.formatNumber(\g<1>)', content)
    
    content = content.replace('\'dd MMM yyyy\'', '\'dd/MM/yyyy\'')
    content = content.replace('\'dd MMM yyyy, HH:mm\'', '\'dd/MM/yyyy, HH:mm\'')
    content = content.replace('yyyy-MM-dd', 'dd/MM/yyyy') # For dateFormat temporarily fixed format

    if content != original:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print('Updated ' + filepath)

def main():
    for root, dirs, files in os.walk('lib'):
        for file in files:
            if file.endswith('.dart'):
                process_file(os.path.join(root, file))

if __name__ == '__main__':
    main()
