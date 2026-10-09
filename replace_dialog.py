import codecs

with codecs.open('lib/screens/dashboard_screen.dart', 'r', 'utf-8') as f:
    content = f.read()

start_str = "class _PieChartFullScreenDialog extends StatefulWidget {"
start_idx = content.find(start_str)

# Find the end of _PieChartFullScreenDialogState
# It should be before "class NewOperationDialog extends StatefulWidget" or similar.
# Let's search for "class" after start_idx
end_idx = content.find("class ", start_idx + len(start_str))
if end_idx == -1:
    end_idx = len(content)

if start_idx != -1 and end_idx != -1:
    replacement = '''class _PieChartFullScreenDialog extends StatelessWidget {
  final List<MapEntry<String, double>> sortedCats;
  final Map<String, Color> categoryColors;
  final List<Color> palette;
  final String title;
  final List<Map<String, dynamic>> payments;
  final List<Map<String, dynamic>> invoices;
  final String chartFilter;
  final Map<String, String> categoryNames;
  final Map<String, String> serviceNames;

  const _PieChartFullScreenDialog({
    super.key,
    required this.sortedCats,
    required this.categoryColors,
    required this.palette,
    required this.title,
    required this.payments,
    required this.invoices,
    required this.chartFilter,
    required this.categoryNames,
    required this.serviceNames,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: Stack(
        children: [
          ModernPieChartPanel(
            sortedCats: sortedCats,
            categoryColors: categoryColors,
            palette: palette,
            categoryNames: categoryNames,
            isFullScreen: true,
            titleDropdown: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

'''
    new_content = content[:start_idx] + replacement + content[end_idx:]
    with codecs.open('lib/screens/dashboard_screen.dart', 'w', 'utf-8') as f:
        f.write(new_content)
    print("Replaced Dialog!")
else:
    print("Not found", start_idx, end_idx)
