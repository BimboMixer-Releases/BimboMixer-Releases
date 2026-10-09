import codecs
import re

with codecs.open('lib/widgets/custom_3d_pie_chart.dart', 'r', 'utf-8') as f:
    content = f.read()

# Fix const TextStyle with small
content = content.replace("const TextStyle(color: Colors.white70, fontSize: small ? 10 : 14)", "TextStyle(color: Colors.white70, fontSize: small ? 10 : 14)")
content = content.replace("const TextStyle(color: Colors.white, fontSize: small ? 10 : 13, fontWeight: FontWeight.bold)", "TextStyle(color: Colors.white, fontSize: small ? 10 : 13, fontWeight: FontWeight.bold)")
content = content.replace("const TextStyle(color: Colors.white, fontSize: small ? 14 : 22, fontWeight: FontWeight.bold)", "TextStyle(color: Colors.white, fontSize: small ? 14 : 22, fontWeight: FontWeight.bold)")

# In _buildBottomSquares, remove small
start_idx = content.find("Widget _buildBottomSquares")
if start_idx != -1:
    top = content[:start_idx]
    bottom = content[start_idx:]
    bottom = bottom.replace("fontSize: small ? 10 : 13", "fontSize: 13")
    bottom = bottom.replace("fontSize: small ? 10 : 14", "fontSize: 14")
    # restore const if needed
    bottom = bottom.replace("TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)", "const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)")
    bottom = bottom.replace("TextStyle(color: Colors.white70, fontSize: 14)", "const TextStyle(color: Colors.white70, fontSize: 14)")
    content = top + bottom

# Also wait, what is line 71?
# It's probably in build() header
header_start = content.find("Widget header = Row(")
if header_start != -1:
    header_end = content.find("if (!isFullScreen)", header_start)
    if header_end != -1:
        head_part = content[header_start:header_end]
        head_part = head_part.replace("fontSize: small ? 10 : 14", "fontSize: 14")
        content = content[:header_start] + head_part + content[header_end:]

with codecs.open('lib/widgets/custom_3d_pie_chart.dart', 'w', 'utf-8') as f:
    f.write(content)
print("Fixed errors!")
