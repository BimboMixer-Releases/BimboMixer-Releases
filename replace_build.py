import codecs

with codecs.open('lib/widgets/custom_3d_pie_chart.dart', 'r', 'utf-8') as f:
    content = f.read()

start_str = "    return Container("
end_str = "  Color _getColor(String key, int index) {"

start_idx = content.find(start_str)
end_idx = content.find(end_str)

if start_idx != -1 and end_idx != -1:
    replacement = '''    Widget contentWidget = LayoutBuilder(
      builder: (context, constraints) {
        bool isWide = constraints.maxWidth > 600;
        
        Widget header = Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                  ),
                  child: Icon(LucideIcons.pieChart, color: Color(0xFF3B82F6)),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DefaultTextStyle(
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                      child: titleDropdown ?? const Text(
                        'RIPARTIZIONE',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                      ),
                    ),
                    Text(
                      'Tocca una sezione per i dettagli',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        );

        if (!isFullScreen) {
            // DASHBOARD LAYOUT (Side by side to fit in constrained height)
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                header,
                const SizedBox(height: 16),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: _buildChart(groupedCats, total, currencyFmt, small: true)),
                      const SizedBox(width: 8),
                      Expanded(flex: 3, child: SingleChildScrollView(child: _buildListLegend(groupedCats, total, currencyFmt, small: true))),
                    ],
                  ),
                ),
              ],
            );
        } else {
            // FULL SCREEN LAYOUT (Scrollable Column)
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  header,
                  const SizedBox(height: 32),
                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 1, child: _buildChart(groupedCats, total, currencyFmt, small: false)),
                        const SizedBox(width: 32),
                        Expanded(flex: 1, child: _buildListLegend(groupedCats, total, currencyFmt, small: false)),
                      ],
                    )
                  else
                    Column(
                      children: [
                        SizedBox(height: 250, child: _buildChart(groupedCats, total, currencyFmt, small: false)),
                        const SizedBox(height: 32),
                        _buildListLegend(groupedCats, total, currencyFmt, small: false),
                      ],
                    ),
                  const SizedBox(height: 32),
                  if (groupedCats.isNotEmpty)
                    _buildBottomSquares(groupedCats, total, currencyFmt),
                ],
              ),
            );
        }
      },
    );

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F111A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      padding: isFullScreen ? const EdgeInsets.all(24) : const EdgeInsets.all(12),
      child: contentWidget,
    );
  }

'''
    new_content = content[:start_idx] + replacement + content[end_idx:]
    with codecs.open('lib/widgets/custom_3d_pie_chart.dart', 'w', 'utf-8') as f:
        f.write(new_content)
    print("Replaced build method!")
else:
    print("Not found", start_idx, end_idx)
