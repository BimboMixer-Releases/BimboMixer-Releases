def extract_build():
    with open('lib/screens/payments_screen.dart', 'r', encoding='utf-8') as f:
        content = f.read()
    
    start = content.find('Widget build(BuildContext context) {')
    print(content[start:start+1000])

extract_build()
