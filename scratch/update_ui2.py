import os
import re

def update_file(file_path, is_invoice=False):
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    if is_invoice:
        title_word1 = "FATTURA "
        title_word2 = "COMMERCIALE"
        is_in_code = "final isIN = true; // Not used for invoice"
        status_code = "final pData = widget.invoice; final isPaid = pData['status']?.toString().toUpperCase() == 'PAGATO';"
        amount_code = "final amount = double.tryParse(pData['amount']?.toString() ?? '0') ?? 0.0;"
        reg_date_code = "final regDate = DateUtilsApp.formatDbDate(pData['date']?.toString(), 'dd MMMM yyyy');"
        display_id_code = "final displayId = pData['number']?.toString() ?? '-';"
        check_null = ""
        footer_text = "FATTURA COMMERCIALE"
    else:
        title_word1 = "RICEVUTA DI "
        title_word2 = "isIN ? 'INCASSO' : 'PAGAMENTO'"
        is_in_code = "final isIN = _paymentData!['type'] == 'IN';"
        status_code = ""
        amount_code = "final amount = double.tryParse(_paymentData!['amount']?.toString() ?? '0') ?? 0.0;"
        reg_date_code = "final regDate = DateUtilsApp.formatDbDate(_paymentData!['date']?.toString(), 'dd MMMM yyyy');"
        display_id_code = "final displayId = 'N. 2026/0' + _paymentData!['id'].toString().padLeft(3, '0');"
        check_null = """
    if (_paymentData == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF07040D),
        appBar: AppBar(title: const Text('Errore'), backgroundColor: Colors.transparent, elevation: 0),
        body: const Center(child: Text('Movimento non trovato', style: TextStyle(color: Colors.white))),
      );
    }"""
        footer_text = "isIN ? 'RICEVUTA DI INCASSO' : 'RICEVUTA DI PAGAMENTO'"

    new_build_method = f"""  @override
  Widget build(BuildContext context) {{
    if (_isLoading) {{
      return const Scaffold(
        backgroundColor: Color(0xFF07040D),
        body: Center(child: CircularProgressIndicator(color: Colors.purpleAccent)),
      );
    }}
{check_null}
    {status_code}
    {is_in_code}
    {amount_code}
    {reg_date_code}
    {display_id_code}

    return Scaffold(
      backgroundColor: const Color(0xFF07040D), // Very dark background
      body: Container(
        // The background stage lighting effect
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.8, -1.0),
            radius: 1.5,
            colors: [
              Color(0xFF6B1BFF), // Strong purple spotlight
              Color(0xFF2A0A73),
              Color(0xFF07040D),
              Color(0xFF07040D),
            ],
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar with back button and edit button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                    HoverEditButton(
                      onTap: () async {{
                        bool authorized = await SecurityUtils.requireAdminAuth(context);
                        if (!authorized || !context.mounted) return;
                        { "Navigator.pop(context); widget.onEdit(widget.invoice);" if is_invoice else "await Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentFormScreen(paymentId: widget.paymentId, isReadOnly: false))); _loadData();" }
                      }},
                    ),
                  ],
                ),
              ),
              
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header (Logo and Company Details) OVER the background
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Glow effect behind logo
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFB142F5).withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: const LogoBimbomixer(width: 90, height: 90, baseColor: Colors.white),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'BIMBOMIXER',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2.0,
                                    shadows: [
                                      Shadow(color: Color(0xFFB142F5), blurRadius: 10),
                                    ]
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'SERVICE AUDIO • LUCI • VIDEO',
                                  style: TextStyle(color: Colors.grey[400], fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on, color: Color(0xFFB142F5), size: 14),
                                    const SizedBox(width: 6),
                                    Text('Vetralla (VT)', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                                    const SizedBox(width: 24),
                                    const Icon(Icons.email, color: Color(0xFFB142F5), size: 14),
                                    const SizedBox(width: 6),
                                    Text('bimbomixer91@gmail.com', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.person, color: Color(0xFFB142F5), size: 14),
                                    const SizedBox(width: 6),
                                    Text('P.IVA 02494800564', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                                    const SizedBox(width: 24),
                                    const Icon(Icons.phone, color: Color(0xFFB142F5), size: 14),
                                    const SizedBox(width: 6),
                                    Text('+39 3807483998', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // The Bordered Container for Receipt
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E0B16), // very dark inside
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFF322756), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Title & Date Banner inside the container
                            Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      RichText(
                                        text: TextSpan(
                                          text: '{title_word1}',
                                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                                          children: [
                                            TextSpan(
                                              text: {title_word2},
                                              style: const TextStyle(color: Color(0xFFB142F5)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        {display_id_code.split('=')[1].strip(' ;')},
                                        style: TextStyle(color: Colors.grey[400], fontSize: 13),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E1736),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFF322756)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.calendar_month, color: Color(0xFFB142F5), size: 24),
                                        const SizedBox(width: 12),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Data registrazione', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                                            const SizedBox(height: 2),
                                            Text(regDate, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            ),
                            
                            // Main White Card Area
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8F7FA), // The white card background
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.all(24),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Left Details Panel
                                    Expanded(
                                      flex: 7,
                                      child: Column(
                                        children: [
                                          _buildRowItem(Icons.person, 'Cliente', _customerName ?? '-'),
                                          const Divider(color: Color(0xFFE5E0F1), height: 24),
                                          _buildRowItem(Icons.layers, 'Importo', '€ ${{amount.toStringAsFixed(2)}}', isAmount: true),
                                          const Divider(color: Color(0xFFE5E0F1), height: 24),
                                          {
                                              f'''_buildRowItem(Icons.badge, 'Partita IVA', pData['client_vat']?.toString().isNotEmpty == true ? pData['client_vat'].toString() : '-'),
                                          const Divider(color: Color(0xFFE5E0F1), height: 24),
                                          _buildRowItem(Icons.fingerprint, 'Codice Fiscale', pData['client_tax_code']?.toString().isNotEmpty == true ? pData['client_tax_code'].toString() : '-'),
                                          const Divider(color: Color(0xFFE5E0F1), height: 24),
                                          _buildRowItem(Icons.home, 'Indirizzo', '${{pData['client_address'] ?? ''}} ${{pData['client_city'] ?? ''}}'.trim().isNotEmpty ? '${{pData['client_address'] ?? ''}} ${{pData['client_city'] ?? ''}}' : '-'),
                                          const Divider(color: Color(0xFFE5E0F1), height: 24),
                                          _buildRowItem(Icons.info_outline, 'Stato', pData['status']?.toString().toUpperCase() ?? 'PENDING'),''' if is_invoice else 
                                              f'''_buildRowItem(Icons.credit_card, 'Metodo di pagamento', _paymentData!['payment_method']?.toString() ?? '-'),
                                          const Divider(color: Color(0xFFE5E0F1), height: 24),
                                          _buildRowItem(Icons.folder, 'Categoria', _categoryName ?? '-'),
                                          const Divider(color: Color(0xFFE5E0F1), height: 24),
                                          _buildRowItem(Icons.receipt_long, 'Prestazione', _serviceName ?? '-'),'''
                                          }
                                          
                                          const SizedBox(height: 24),
                                          
                                          // Note Container inside white card
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF0EDF6), // slightly darker grey-purple
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFE3DCF0),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: const Icon(Icons.chat_bubble_outline, color: Color(0xFF322756), size: 18),
                                                ),
                                                const SizedBox(width: 16),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      const Text('Note', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13)),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        { "pData['notes']?.toString().isNotEmpty == true ? pData['notes'].toString() : 'Nessuna nota aggiuntiva.'" if is_invoice else "_paymentData!['notes']?.toString().isNotEmpty == true ? _paymentData!['notes'].toString() : 'Nessuna nota aggiuntiva.'" },
                                                        style: TextStyle(color: Colors.grey[800], fontSize: 13),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          
                                          { "" if is_invoice else """
                                          if (_attachments.isNotEmpty) ...[
                                            const SizedBox(height: 16),
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF0EDF6),
                                                borderRadius: BorderRadius.circular(16),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text('Allegati', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13)),
                                                  const SizedBox(height: 8),
                                                  Wrap(
                                                    spacing: 8,
                                                    runSpacing: 8,
                                                    children: _attachments.map((path) => InkWell(
                                                      onTap: () => _launchUrl(path),
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFFE3DCF0),
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            const Icon(Icons.picture_as_pdf, size: 14, color: Color(0xFF322756)),
                                                            const SizedBox(width: 6),
                                                            Text(
                                                              path.split('/').last.length > 15 ? path.split('/').last.substring(0, 15) + '...' : path.split('/').last,
                                                              style: const TextStyle(fontSize: 11, color: Color(0xFF322756), fontWeight: FontWeight.bold),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    )).toList(),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ]""" }
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                    // Right Panel (Watermark Logo)
                                    Expanded(
                                      flex: 3,
                                      child: Container(
                                        height: 350,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8F7FA),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Center(
                                          child: Opacity(
                                            opacity: 0.04,
                                            child: const LogoBimbomixer(width: 220, height: 220, baseColor: Colors.black),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Dark Footer inside container
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFB142F5).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(Icons.receipt_long, color: Color(0xFFB142F5), size: 24),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            {footer_text},
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                          const SizedBox(height: 2),
                                          RichText(
                                            text: TextSpan(
                                              text: 'Documento generato tramite ',
                                              style: TextStyle(color: Colors.grey[500], fontSize: 10),
                                              children: const [
                                                TextSpan(
                                                  text: 'Contabile App',
                                                  style: TextStyle(color: Color(0xFFB142F5), fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                          )
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
                                          fontSize: 28,
                                          fontStyle: FontStyle.italic,
                                          fontFamily: 'Caveat', // Assuming a cursive font, fallback to italic
                                        ),
                                      ),
                                      const SizedBox(width: 20),
                                      Container(width: 1, height: 40, color: const Color(0xFF322756)),
                                      const SizedBox(width: 20),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Bimbomixer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                          const SizedBox(height: 2),
                                          Text('SERVICE AUDIO, LUCI, VIDEO', style: TextStyle(color: Colors.grey[500], fontSize: 9)),
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
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }}

  Widget _buildRowItem(IconData icon, String label, String value, {{bool isAmount = false}}) {{
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFEBE6F5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF322756), size: 18),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        if (isAmount)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEBE6F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              value,
              style: const TextStyle(color: Color(0xFF7F30D8), fontWeight: FontWeight.w900, fontSize: 20),
            ),
          )
        else
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(color: Colors.grey[800], fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }}
"""

    match = re.search(r'  @override\n  Widget build\(BuildContext context\) \{.*?\n  \}\n\n  Widget _buildRowItem.*?\}', content, re.DOTALL)
    if not match:
        match = re.search(r'  @override\n  Widget build\(BuildContext context\) \{.*?\}\n', content, re.DOTALL)
        
    if match:
        new_content = content[:match.start()] + new_build_method + "\n" + content[match.end():]
        with open(file_path, "w", encoding="utf-8") as f:
            f.write(new_content)
        print(f"Success {file_path}")
    else:
        print(f"Not found in {file_path}")

update_file("lib/screens/payment_summary_screen.dart", is_invoice=False)
update_file("lib/screens/invoice_summary_screen.dart", is_invoice=True)
