import codecs

with codecs.open('lib/widgets/custom_3d_pie_chart.dart', 'r', 'utf-8') as f:
    content = f.read()

content = content.replace(
    "Widget _buildChart(List<MapEntry<String, double>> cats, double total, NumberFormat fmt) {",
    "Widget _buildChart(List<MapEntry<String, double>> cats, double total, NumberFormat fmt, {bool small = false}) {"
)

content = content.replace(
    "Widget _buildListLegend(List<MapEntry<String, double>> cats, double total, NumberFormat fmt) {",
    "Widget _buildListLegend(List<MapEntry<String, double>> cats, double total, NumberFormat fmt, {bool small = false}) {"
)

# In _buildChart, adjust radii and fonts based on 'small'
content = content.replace(
    "centerSpaceRadius: 60,",
    "centerSpaceRadius: small ? 35 : 60,"
)
content = content.replace(
    "radius: 40,",
    "radius: small ? 25 : 40,"
)
content = content.replace(
    "width: 200,",
    "width: small ? 110 : 200,"
)
content = content.replace(
    "height: 200,",
    "height: small ? 110 : 200,"
)
content = content.replace(
    "width: 220,",
    "width: small ? 130 : 220,"
)
content = content.replace(
    "height: 220,",
    "height: small ? 130 : 220,"
)
content = content.replace(
    "fontSize: 14",
    "fontSize: small ? 10 : 14"
)
content = content.replace(
    "fontSize: 22",
    "fontSize: small ? 14 : 22"
)
content = content.replace(
    "fontSize: 12",
    "fontSize: small ? 9 : 12"
)
content = content.replace(
    "fontSize: 13",
    "fontSize: small ? 10 : 13"
)
content = content.replace(
    "padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),",
    "padding: small ? const EdgeInsets.symmetric(horizontal: 8, vertical: 8) : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),"
)
content = content.replace(
    "Icon(_getIcon(entry.key), color: color, size: 24),",
    "Icon(_getIcon(entry.key), color: color, size: small ? 16 : 24),"
)


with codecs.open('lib/widgets/custom_3d_pie_chart.dart', 'w', 'utf-8') as f:
    f.write(content)
print("Updated parameters!")
