p = 'lib/screens/invoices_screen.dart'
s = open(p, encoding='utf-8', newline='').read()
a = s.index("      appBar: AppBar(")
b = s.index("      body: _isLoading", a)
appbar = s[a:b]
# inner = "AppBar(...)," -> SliverAppBar
inner = appbar[len("      appBar: "):].rstrip()
assert inner.endswith(',')
inner = inner[:-1].replace("AppBar(", "SliverAppBar(\r\n        floating: true,\r\n        snap: true,", 1)

old_body_start = "          : SingleChildScrollView(\r\n              physics: const BouncingScrollPhysics(),\r\n              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),\r\n              child: Column("
assert old_body_start in s
# find the end of the scroll view: the closing right before ");\r\n  }\r\n\r\n  Widget _buildInvoiceRow"
end_marker = "            ),\r\n    );\r\n  }\r\n\r\n  Widget _buildInvoiceRow"
e = s.index(end_marker)

s = s[:a] + s[b:]  # remove appBar from scaffold
s = s.replace(old_body_start,
  "          : CustomScrollView(\r\n              physics: const BouncingScrollPhysics(),\r\n              slivers: [\r\n                " + inner.strip() + ",\r\n                SliverPadding(\r\n                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),\r\n                  sliver: SliverToBoxAdapter(\r\n              child: Column(", 1)
s = s.replace(end_marker, "            ),\r\n                ),\r\n              ],\r\n            ),\r\n    );\r\n  }\r\n\r\n  Widget _buildInvoiceRow", 1)
open(p, 'w', encoding='utf-8', newline='').write(s)
print('ok')
