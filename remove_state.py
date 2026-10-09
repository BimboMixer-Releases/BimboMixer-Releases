import codecs
import re

with codecs.open('lib/screens/dashboard_screen.dart', 'r', 'utf-8') as f:
    content = f.read()

# We need to find class _PieChartFullScreenDialogState and delete it
start_str = "class _PieChartFullScreenDialogState extends State<_PieChartFullScreenDialog>"
start_idx = content.find(start_str)

if start_idx != -1:
    # Find the next class declaration to know where to stop
    end_idx = content.find("class ", start_idx + len(start_str))
    if end_idx == -1:
        end_idx = len(content)
        
    new_content = content[:start_idx] + content[end_idx:]
    with codecs.open('lib/screens/dashboard_screen.dart', 'w', 'utf-8') as f:
        f.write(new_content)
    print("Deleted State class!")
else:
    print("Not found")
