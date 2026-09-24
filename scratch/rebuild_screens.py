import os

def rewrite_file(file_path, is_invoice=False):
    import re

    title_part1 = 'FATTURA ' if is_invoice else 'RICEVUTA DI '
    title_part2 = 'COMMERCIALE' if is_invoice else (r"${isIN ? 'INCASSO' : 'PAGAMENTO'}")

    # Note: we use raw strings to avoid escaping issues
    content = f"""import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:contabile_app/database/database_helper.dart';
import 'package:contabile_app/utils/date_utils_app.dart';
import 'package:contabile_app/utils/security_utils.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:contabile_app/screens/payment_form_screen.dart';
import 'package:contabile_app/screens/invoice_form_screen.dart';

class {'InvoiceSummaryScreen' if is_invoice else 'PaymentSummaryScreen'} extends StatefulWidget {{
  final String {'invoiceId' if is_invoice else 'paymentId'};

  const {'InvoiceSummaryScreen' if is_invoice else 'PaymentSummaryScreen'}({{super.key, required this.{'invoiceId' if is_invoice else 'paymentId'}}});

  @override
  State<{'InvoiceSummaryScreen' if is_invoice else 'PaymentSummaryScreen'}> createState() => _{'InvoiceSummaryScreen' if is_invoice else 'PaymentSummaryScreen'}State();
}}

class _{'InvoiceSummaryScreen' if is_invoice else 'PaymentSummaryScreen'}State extends State<{'InvoiceSummaryScreen' if is_invoice else 'PaymentSummaryScreen'}> {{
  final DatabaseHelper _dbHelper = DatabaseHelper();
  Map<String, dynamic>? _data;
  String? _customerName;
  String? _categoryName;
  String? _serviceName;
  List<String> _attachments = [];
  bool _isLoading = true;

  @override
  void initState() {{
    super.initState();
    _loadData();
  }}

  Future<void> _loadData() async {{
    setState(() => _isLoading = true);
    
    final pData = await _dbHelper.get{'Invoice' if is_invoice else 'Payment'}ById(widget.{'invoiceId' if is_invoice else 'paymentId'});
    if (pData != null) {{
      _data = pData;
      
      final custId = pData['customer_id'];
      if (custId != null) {{
        final custList = await _dbHelper.getCustomers();
        final c = custList.cast<Map<String,dynamic>>().firstWhere((e) => e['id'].toString() == custId.toString(), orElse: () => {{}});
        _customerName = c['name'];
      }}

      final catId = pData['category_id'];
      if (catId != null) {{
        final catList = await _dbHelper.getCategories();
        final c = catList.cast<Map<String,dynamic>>().firstWhere((e) => e['id'].toString() == catId.toString(), orElse: () => {{}});
        _categoryName = c['name'];
      }}

      final srvId = pData['service_id'];
      if (srvId != null) {{
        final srvList = await _dbHelper.getServiceTypes();
        final s = srvList.cast<Map<String,dynamic>>().firstWhere((e) => e['id'].toString() == srvId.toString(), orElse: () => {{}});
        _serviceName = s['name'];
      }}

      if (pData['attachments'] != null) {{
        try {{
          _attachments = List<String>.from(jsonDecode(pData['attachments']));
        }} catch (_) {{}}
      }}
    }}
    
    setState(() => _isLoading = false);
  }}

  Future<void> _launchUrl(String urlString) async {{
    final Uri url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {{
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }} else {{
      if (mounted) {{
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impossibile aprire l\\'allegato')));
      }}
    }}
  }}

  @override
  Widget build(BuildContext context) {{
    if (_isLoading) {{
      return const Scaffold(
        backgroundColor: Color(0xFF0A0710),
        body: Center(child: CircularProgressIndicator(color: Colors.purpleAccent)),
      );
    }}

    if (_data == null) {{
      return Scaffold(
        backgroundColor: const Color(0xFF0A0710),
        appBar: AppBar(title: const Text('Errore'), backgroundColor: Colors.transparent, elevation: 0),
        body: const Center(child: Text('{'Fattura' if is_invoice else 'Movimento'} non trovato', style: TextStyle(color: Colors.white))),
      );
    }}
    
    final isIN = _data!['type'] == 'IN';
    final amount = double.tryParse(_data!['amount']?.toString() ?? '0') ?? 0.0;
    final regDate = DateUtilsApp.formatDbDate(_data!['date']?.toString(), 'dd MMMM yyyy');
    final displayId = 'N. 2026/0' + _data!['id'].toString().padLeft(3, '0');
    final String title2 = {'"COMMERCIALE"' if is_invoice else "isIN ? 'INCASSO' : 'PAGAMENTO'"};

    return Scaffold(
      backgroundColor: const Color(0xFF0A0710), // Solid dark blue/black background
      body: Stack(
        children: [
          // Background Gradient (Dark solid)
          Container(
            color: const Color(0xFF0A0710),
          ),
          
          // Stage Lights only at top right, fading out
          Positioned(
            top: 0,
            right: 0,
            width: MediaQuery.of(context).size.width * 0.5,
            height: 350,
            child: ShaderMask(
              shaderCallback: (rect) {{
                return const LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [Colors.black, Colors.black87, Colors.transparent],
                  stops: [0.0, 0.4, 1.0],
                ).createShader(rect);
              }},
              blendMode: BlendMode.dstIn,
              child: Image.asset(
                'assets/images/stage_lights.jpg',
                fit: BoxFit.cover,
                alignment: Alignment.topRight,
              ),
            ),
          ),
          
          // Content
          SafeArea(
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
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => {'InvoiceFormScreen(invoiceId: widget.invoiceId' if is_invoice else 'PaymentFormScreen(paymentId: widget.paymentId'}, isReadOnly: false))); 
                          _loadData();
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
                            // Logo Image
                            Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFB142F5).withValues(alpha: 0.4),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  )
                                ],
                                image: const DecorationImage(
                                  image: AssetImage('assets/images/logo_bimbomixer_bw.png'),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RichText(
                                    text: const TextSpan(
                                      style: TextStyle(
                                        fontSize: 42,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 2.0,
                                      ),
                                      children: [
                                        TextSpan(text: 'BIMBO', style: TextStyle(color: Colors.white)),
                                        TextSpan(text: 'MIXER', style: TextStyle(color: Color(0xFFB142F5))),
                                      ]
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'SERVICE AUDIO • LUCI • VIDEO\\nPRODUZIONI TEATRALI',
                                    style: TextStyle(color: Colors.grey[400], fontSize: 13, letterSpacing: 2.0, fontWeight: FontWeight.bold, height: 1.4),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on, color: Color(0xFFB142F5), size: 16),
                                      const SizedBox(width: 8),
                                      Text('Vetralla (VT)', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                                      const SizedBox(width: 32),
                                      const Icon(Icons.email, color: Color(0xFFB142F5), size: 16),
                                      const SizedBox(width: 8),
                                      Text('bimbomixer91@gmail.com', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.person, color: Color(0xFFB142F5), size: 16),
                                      const SizedBox(width: 8),
                                      Text('P.IVA 02494800564', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                                      const SizedBox(width: 32),
                                      const Icon(Icons.phone, color: Color(0xFFB142F5), size: 16),
                                      const SizedBox(width: 8),
                                      Text('+39 3807483998', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 40),
                        
                        // The Bordered Container for Receipt
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0E0B16), // very dark inside
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFF261D42), width: 1.5),
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
                                            text: '{title_part1}',
                                            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
                                            children: [
                                              TextSpan(
                                                text: title2,
                                                style: const TextStyle(color: Color(0xFFB142F5)),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          displayId,
                                          style: TextStyle(color: Colors.grey[400], fontSize: 14),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF161124),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: const Color(0xFF261D42)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.calendar_month, color: Color(0xFFB142F5), size: 26),
                                          const SizedBox(width: 12),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Data registrazione', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                                              const SizedBox(height: 2),
                                              Text(regDate, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
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
                                            _buildRowItem(Icons.person_outline, 'Cliente', _customerName ?? '-'),
                                            const Divider(color: Color(0xFFE5E0F1), height: 24),
                                            _buildRowItem(Icons.layers_outlined, 'Importo', '€ ${{amount.toStringAsFixed(2)}}', isAmount: true),
                                            const Divider(color: Color(0xFFE5E0F1), height: 24),
                                            _buildRowItem(Icons.credit_card_outlined, 'Metodo di pagamento', _data!['payment_method']?.toString() ?? '-'),
                                            const Divider(color: Color(0xFFE5E0F1), height: 24),
                                            _buildRowItem(Icons.folder_outlined, 'Categoria', _categoryName ?? '-'),
                                            const Divider(color: Color(0xFFE5E0F1), height: 24),
                                            _buildRowItem(Icons.receipt_long_outlined, 'Prestazione', _serviceName ?? '-'),
                                            
                                            const SizedBox(height: 24),
                                            
                                            // Note Container inside white card
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF0EDF6),
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
                                                          _data!['notes']?.toString().isNotEmpty == true ? _data!['notes'].toString() : 'Nessuna nota aggiuntiva.',
                                                          style: TextStyle(color: Colors.grey[800], fontSize: 13),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            
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
                                            ]
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 24),
                                      // Right Panel (Watermark Logo)
                                      Expanded(
                                        flex: 4,
                                        child: Container(
                                          height: 380,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8F7FA),
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Center(
                                            child: Opacity(
                                              opacity: 0.15,
                                              child: Image.asset(
                                                'assets/images/logo_bimbomixer_bw.png',
                                                width: 300,
                                                height: 300,
                                                fit: BoxFit.contain,
                                              )
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
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFB142F5).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Icon(Icons.receipt_long, color: Color(0xFFB142F5), size: 28),
                                        ),
                                        const SizedBox(width: 16),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '{title_part1}' + (title2.contains("COMMERCIALE") ? title2 : title2 == "isIN ? 'INCASSO' : 'PAGAMENTO'" ? (isIN ? 'INCASSO' : 'PAGAMENTO') : title2),
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                            const SizedBox(height: 4),
                                            RichText(
                                              text: TextSpan(
                                                text: 'Documento generato tramite ',
                                                style: TextStyle(color: Colors.grey[500], fontSize: 11),
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
                                        Text(
                                          'Grazie!',
                                          style: GoogleFonts.caveat(
                                            color: const Color(0xFFB142F5),
                                            fontSize: 42,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 24),
                                        Container(width: 1, height: 40, color: const Color(0xFF322756)),
                                        const SizedBox(width: 24),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Bimbomixer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                            const SizedBox(height: 4),
                                            Text('SERVICE AUDIO, LUCI, VIDEO\\nE PRODUZIONI TEATRALI', style: TextStyle(color: Colors.grey[500], fontSize: 10, height: 1.3)),
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
        ],
      ),
    );
  }}

  Widget _buildRowItem(IconData icon, String label, String value, {{bool isAmount = false}}) {{
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEBE6F5), // Light purple box
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: const TextStyle(color: Color(0xFF7F30D8), fontWeight: FontWeight.w900, fontSize: 22),
            ),
          )
        else
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(color: Colors.grey[800], fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }}
}}

class HoverEditButton extends StatefulWidget {{
  final VoidCallback onTap;
  
  const HoverEditButton({{super.key, required this.onTap}});

  @override
  State<HoverEditButton> createState() => _HoverEditButtonState();
}}

class _HoverEditButtonState extends State<HoverEditButton> {{
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {{
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: _isHovering ? Colors.cyanAccent : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(30),
            boxShadow: _isHovering ? [
              BoxShadow(color: Colors.cyanAccent.withValues(alpha: 0.5), blurRadius: 15, spreadRadius: 2)
            ] : [],
          ),
          child: Row(
            children: [
              Icon(Icons.edit_rounded, color: _isHovering ? Colors.black87 : Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                'MODIFICA',
                style: TextStyle(
                  color: _isHovering ? Colors.black87 : Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }}
}}
"""
    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)

rewrite_file("lib/screens/payment_summary_screen.dart", is_invoice=False)
rewrite_file("lib/screens/invoice_summary_screen.dart", is_invoice=True)
