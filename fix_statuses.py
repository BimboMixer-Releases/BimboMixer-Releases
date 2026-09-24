import re

file_path = "lib/screens/customers_screen.dart"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# Replace any variant of Priorità Alta
content = re.sub(r"case 'Priorit[^']+':", "case 'Priorità Alta':", content)
content = re.sub(r"case 'Priorità alta':", "case 'Priorità Alta':", content)
content = re.sub(r"case 'In revisione':", "case 'In Revisione':", content)

# Replace the array elements
content = re.sub(r"'Priorit[^']+'", "'Priorità Alta'", content)
content = re.sub(r"'Priorità alta'", "'Priorità Alta'", content)
content = re.sub(r"'In revisione'", "'In Revisione'", content)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

print("Replaced successfully")
