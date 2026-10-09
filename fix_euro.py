with open('lib/screens/quotes_screen.dart', 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace("l.contains('Ã¢â€šÂ¬')", "l.contains('€')")
text = text.replace("[^\\w\\s\\(\\)\\Ã¢â€šÂ¬\\.\\,]", "[^\\w\\s\\(\\)€\\.\\,]")

with open('lib/screens/quotes_screen.dart', 'w', encoding='utf-8') as f:
    f.write(text)
