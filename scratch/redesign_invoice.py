import os
import re

file_path = "lib/screens/invoice_summary_screen.dart"

with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

new_build_method = """  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0B1A),
        body: Center(child: CircularProgressIndicator(color: Colors.purpleAccent)),
      );
    }

    final pData = widget.invoice;
    final amount = double.tryParse(pData['amount']?.toString() ?? '0') ?? 0.0;
    final isPaid = pData['status']?.toString().toUpperCase() == 'PAGATO';
    final regDate = DateUtilsApp.formatDbDate(pData['date']?.toString(), 'dd MMMM yyyy');
    
    return Scaffold(
      backgroundColor: const Color(0xFF0F0B1A),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ],
                  ),
                  HoverEditButton(
                    onTap: () async {
                      bool authorized = await SecurityUtils.requireAdminAuth(context);
                      if (!authorized || !context.mounted) return;
                      Navigator.pop(context);
                      widget.onEdit(widget.invoice);
                    },
                  ),
                ],
              ),
            ),
            
            // Receipt Body
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 0),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF161129),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF322756), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purpleAccent.withValues(alpha: 0.1),
                        blurRadius: 30,
                        spreadRadius: 5,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Card (Darker)
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const LogoBimbomixer(width: 80, height: 80, baseColor: Colors.white),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'BIMBOMIXER',
                                    style: TextStyle(
                                      color: Color(0xFFB142F5),
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'SERVICE AUDIO • LUCI • VIDEO',
                                    style: TextStyle(color: Colors.grey[400], fontSize: 11, letterSpacing: 1.5),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.location_on, color: const Color(0xFFB142F5), size: 14),
                                      const SizedBox(width: 4),
                                      Text('Vetralla (VT)', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                                      const SizedBox(width: 16),
                                      Icon(Icons.email, color: const Color(0xFFB142F5), size: 14),
                                      const SizedBox(width: 4),
                                      Text('bimbomixer91@gmail.com', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.person, color: const Color(0xFFB142F5), size: 14),
                                      const SizedBox(width: 4),
                                      Text('P.IVA 02494800564', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                                      const SizedBox(width: 16),
                                      Icon(Icons.phone, color: const Color(0xFFB142F5), size: 14),
                                      const SizedBox(width: 4),
                                      Text('+39 3807483998', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Title & Date Banner
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RichText(
                                  text: const TextSpan(
                                    text: 'FATTURA ',
                                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                                    children: [
                                      TextSpan(
                                        text: 'COMMERCIALE',
                                        style: TextStyle(color: Color(0xFFB142F5)),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  pData['number']?.toString() ?? '-',
                                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E1736),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF322756)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_month, color: Color(0xFFB142F5), size: 20),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Data emissione', style: TextStyle(color: Colors.grey[400], fontSize: 10)),
                                      Text(regDate, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Main White Card Area
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Details Panel
                            Expanded(
                              flex: 7,
                              child: Column(
                                children: [
                                  // Attributes Container
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF6F5FC),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                      children: [
                                        _buildRowItem(Icons.person, 'Cliente', _customerName ?? '-'),
                                        const Divider(color: Color(0xFFE5E0F1), height: 24),
                                        _buildRowItem(Icons.layers, 'Importo', '€ ${amount.toStringAsFixed(2)}', isAmount: true),
                                        const Divider(color: Color(0xFFE5E0F1), height: 24),
                                        _buildRowItem(Icons.badge, 'Partita IVA', pData['client_vat']?.toString().isNotEmpty == true ? pData['client_vat'].toString() : '-'),
                                        const Divider(color: Color(0xFFE5E0F1), height: 24),
                                        _buildRowItem(Icons.fingerprint, 'Codice Fiscale', pData['client_tax_code']?.toString().isNotEmpty == true ? pData['client_tax_code'].toString() : '-'),
                                        const Divider(color: Color(0xFFE5E0F1), height: 24),
                                        _buildRowItem(Icons.home, 'Indirizzo', '${pData['client_address'] ?? ''} ${pData['client_city'] ?? ''}'.trim().isNotEmpty ? '${pData['client_address'] ?? ''} ${pData['client_city'] ?? ''}' : '-'),
                                        const Divider(color: Color(0xFFE5E0F1), height: 24),
                                        _buildRowItem(Icons.info_outline, 'Stato', pData['status']?.toString().toUpperCase() ?? 'PENDING'),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  // Note Container
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF6F5FC),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEBE6F5),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(Icons.chat_bubble_outline, color: Color(0xFF533876), size: 18),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('Note', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13)),
                                              const SizedBox(height: 4),
                                              Text(
                                                pData['notes']?.toString().isNotEmpty == true ? pData['notes'].toString() : 'Nessuna nota aggiuntiva.',
                                                style: TextStyle(color: Colors.grey[700], fontSize: 13),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Right Panel (Watermark Logo)
                            Expanded(
                              flex: 3,
                              child: Container(
                                height: 350,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF6F5FC),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Center(
                                  child: Opacity(
                                    opacity: 0.05,
                                    child: const LogoBimbomixer(width: 200, height: 200, baseColor: Colors.black),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Dark Footer
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                        decoration: const BoxDecoration(
                          color: Color(0xFF0F0B1A), // Dark bottom
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(24),
                            bottomRight: Radius.circular(24),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFB142F5).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.receipt_long, color: Color(0xFFB142F5), size: 24),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'FATTURA COMMERCIALE',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                    Text(
                                      'Documento generato tramite Contabile App',
                                      style: TextStyle(color: Colors.grey[500], fontSize: 10),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                const Text(
                                  'Grazie!',
                                  style: TextStyle(
                                    color: Color(0xFFB142F5),
                                    fontSize: 24,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Container(width: 1, height: 30, color: const Color(0xFF322756)),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Bimbomixer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                    Text('SERVICE AUDIO, LUCI E VIDEO', style: TextStyle(color: Colors.grey[500], fontSize: 9)),
                                  ],
                                ),
                              ],
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildRowItem(IconData icon, String label, String value, {bool isAmount = false}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFEBE6F5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF533876), size: 18),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        if (isAmount)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEBE6F5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: const TextStyle(color: Color(0xFF7F30D8), fontWeight: FontWeight.w900, fontSize: 18),
            ),
          )
        else
          Text(
            value,
            style: TextStyle(color: Colors.grey[800], fontSize: 13, fontWeight: FontWeight.w500),
          ),
      ],
    );
  }
"""

match = re.search(r'  @override\n  Widget build\(BuildContext context\) \{.*?\n  \}\n\n  Widget _buildReceiptRow.*?\}', content, re.DOTALL)
if match:
    new_content = content[:match.start()] + new_build_method + "\n" + content[match.end():]
    with open(file_path, "w", encoding="utf-8") as f:
        f.write(new_content)
    print("Success")
else:
    print("Not found")

