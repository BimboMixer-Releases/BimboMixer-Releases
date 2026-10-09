# -*- coding: utf-8 -*-
import sys

with open('lib/screens/invoice_summary_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix flex and wrapping in _buildRowItem
target_build_row = '''  Widget _buildRowItem(IconData icon, String label, String value, {bool isAmount = false}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFEBE6F5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF322756), size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
        if (isAmount)
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEBE6F5), // Light purple box
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  value,
                  style: const TextStyle(color: Color(0xFF7F30D8), fontWeight: FontWeight.w900, fontSize: 18),
                ),
              ),
            ),
          )
        else
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Color(0xFF4A4A4A), fontSize: 15),
            ),
          ),
      ],
    );
  }'''

replacement_build_row = '''  Widget _buildRowItem(IconData icon, String label, String value, {bool isAmount = false}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFEBE6F5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF322756), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
        if (isAmount)
          Expanded(
            flex: 5,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEBE6F5), // Light purple box
                  borderRadius: BorderRadius.circular(8),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: const TextStyle(color: Color(0xFF7F30D8), fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                ),
              ),
            ),
          )
        else
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Color(0xFF4A4A4A), fontSize: 15),
            ),
          ),
      ],
    );
  }'''

if target_build_row in content:
    content = content.replace(target_build_row, replacement_build_row)
else:
    print("Could not find _buildRowItem to replace!")
    sys.exit(1)

with open('lib/screens/invoice_summary_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print('Done patching invoice_summary_screen.dart!')
