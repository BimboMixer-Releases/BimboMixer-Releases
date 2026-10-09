import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:contabile_app/database/database_helper.dart';
import 'package:contabile_app/utils/date_utils_app.dart';
import 'package:contabile_app/utils/security_utils.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:contabile_app/screens/payment_form_screen.dart';

class InvoiceSummaryScreen extends StatefulWidget {
  final String invoiceId;
  final Function(Map<String, dynamic>)? onEdit;

  const InvoiceSummaryScreen({super.key, required this.invoiceId, this.onEdit});

  @override
  State<InvoiceSummaryScreen> createState() => _InvoiceSummaryScreenState();
}

class _InvoiceSummaryScreenState extends State<InvoiceSummaryScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  Map<String, dynamic>? _data;
  Map<String, dynamic>? _customerData;
  List<String> _attachments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final pData = await _dbHelper.getInvoiceById(widget.invoiceId);
    if (pData != null) {
      _data = pData;
      
      final custId = pData['customer_id'];
      if (custId != null) {
        final custList = await _dbHelper.getCustomers();
        final c = custList.cast<Map<String,dynamic>>().firstWhere((e) => e['id'].toString() == custId.toString(), orElse: () => {});
        _customerData = c;
      }

      if (pData['attachments'] != null) {
        try {
          _attachments = List<String>.from(jsonDecode(pData['attachments']));
        } catch (_) {}
      }
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impossibile aprire l\'allegato')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0710),
        body: Center(child: CircularProgressIndicator(color: Colors.purpleAccent)),
      );
    }

    if (_data == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0710),
        appBar: AppBar(title: const Text('Errore'), backgroundColor: Colors.transparent, elevation: 0),
        body: const Center(child: Text('Fattura non trovato', style: TextStyle(color: Colors.white))),
      );
    }
    
    final isIN = _data!['type'] == 'IN';
    final amount = double.tryParse(_data!['amount']?.toString() ?? '0') ?? 0.0;
    final regDate = DateUtilsApp.formatDbDate(_data!['date']?.toString(), 'dd MMMM yyyy');
    final invoiceNumber = _data!['number']?.toString() ?? '';
    final displayId = invoiceNumber.isNotEmpty ? 'N. ' + invoiceNumber : 'N. ' + _data!['id'].toString();
    final String title2 = "COMMERCIALE";

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
              shaderCallback: (rect) {
                return const LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [Colors.black, Colors.black87, Colors.transparent],
                  stops: [0.0, 0.4, 1.0],
                ).createShader(rect);
              },
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
                        onTap: () async {
                          bool authorized = await SecurityUtils.requireAdminAuth(context);
                          if (!authorized || !context.mounted) return;
                          if (widget.onEdit != null) widget.onEdit!(_data!); Navigator.pop(context, true);
                        },
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
                        Flex(
                          direction: MediaQuery.of(context).size.width > 600 ? Axis.horizontal : Axis.vertical,
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
                            SizedBox(width: 24, height: 16),
                            Builder(
                              builder: (context) {
                                Widget col = Column(
                                  crossAxisAlignment: MediaQuery.of(context).size.width > 600 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
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
                                    'SERVICE AUDIO • LUCI • VIDEO\nPRODUZIONI TEATRALI',
                                    style: TextStyle(color: Colors.grey[400], fontSize: 13, letterSpacing: 2.0, fontWeight: FontWeight.bold, height: 1.4),
                                  ),
                                  const SizedBox(height: 16),
                                  Wrap(
                                    spacing: 16,
                                    runSpacing: 8,
                                    alignment: MediaQuery.of(context).size.width > 600 ? WrapAlignment.start : WrapAlignment.center,
                                    children: [
                                      Text.rich(
                                        TextSpan(
                                          children: [
                                            WidgetSpan(child: Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.location_on, color: Color(0xFFB142F5), size: 16))),
                                            TextSpan(text: 'Vetralla (VT)', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                                          ]
                                        )
                                      ),
                                      Text.rich(
                                        TextSpan(
                                          children: [
                                            WidgetSpan(child: Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.email, color: Color(0xFFB142F5), size: 16))),
                                            TextSpan(text: 'bimbomixer91@gmail.com', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                                          ]
                                        )
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 16,
                                    runSpacing: 8,
                                    alignment: MediaQuery.of(context).size.width > 600 ? WrapAlignment.start : WrapAlignment.center,
                                    children: [
                                      Text.rich(
                                        TextSpan(
                                          children: [
                                            WidgetSpan(child: Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.person, color: Color(0xFFB142F5), size: 16))),
                                            TextSpan(text: 'P.IVA 02494800564', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                                          ]
                                        )
                                      ),
                                      Text.rich(
                                        TextSpan(
                                          children: [
                                            WidgetSpan(child: Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.phone, color: Color(0xFFB142F5), size: 16))),
                                            TextSpan(text: '+39 3807483998', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                                          ]
                                        )
                                      ),
                                    ],
                                  ),
                                ],
                              );
                              return MediaQuery.of(context).size.width > 600 ? Flexible(child: col) : col;
                              }
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
                                child: Wrap(
                                  spacing: 16,
                                  runSpacing: 16,
                                  alignment: WrapAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        RichText(
                                          text: TextSpan(
                                            text: 'FATTURA ',
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
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF161124),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: const Color(0xFF261D42)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.calendar_month, color: Color(0xFFB142F5), size: 26),
                                          const SizedBox(width: 12),
                                          Flexible(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text('Data registrazione', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                                                const SizedBox(height: 2),
                                                Text(regDate, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
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
                                  child: Flex(
                                    direction: MediaQuery.of(context).size.width > 600 ? Axis.horizontal : Axis.vertical,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Left Details Panel
                                      Builder(
                                        builder: (context) {
                                          Widget col = Column(
                                          children: [
                                            _buildRowItem(Icons.person_outline, 'Cliente', _customerData?['name']?.toString() ?? '-'),
                                            const Divider(color: Color(0xFFE5E0F1), height: 24),
                                            if (_customerData?['addressStreet']?.toString().isNotEmpty == true || _customerData?['addressCity']?.toString().isNotEmpty == true) ...[
                                              _buildRowItem(Icons.location_on_outlined, 'Indirizzo', ',   '.replaceAll(RegExp(r'\s+'), ' ').trim()),
                                              const Divider(color: Color(0xFFE5E0F1), height: 24),
                                            ],
                                            if (_customerData?['vatNumber']?.toString().isNotEmpty == true) ...[
                                              _buildRowItem(Icons.badge_outlined, 'P.IVA/C.F.', _customerData!['vatNumber'].toString()),
                                              const Divider(color: Color(0xFFE5E0F1), height: 24),
                                            ],
                                            if (_customerData?['sdiCode']?.toString().isNotEmpty == true) ...[
                                              _buildRowItem(Icons.markunread_mailbox_outlined, 'Codice SDI', _customerData!['sdiCode'].toString()),
                                              const Divider(color: Color(0xFFE5E0F1), height: 24),
                                            ],
                                            _buildRowItem(Icons.layers_outlined, 'Importo', NumberFormat.currency(locale: 'it_IT', symbol: '€ ').format(amount), isAmount: true),
                                            const Divider(color: Color(0xFFE5E0F1), height: 24),
                                            _buildRowItem(Icons.credit_card_outlined, 'Metodo di pagamento', _data!['payment_method']?.toString() ?? '-'),
                                            
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
                                        );
                                        return MediaQuery.of(context).size.width > 600 ? Flexible(flex: 7, child: col) : col;
                                        }
                                      ),
                                      const SizedBox(width: 24, height: 24),
                                      // Right Panel (Watermark Logo)
                                      if (MediaQuery.of(context).size.width > 600) Flexible(
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
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                                child: Flex(
                                  direction: MediaQuery.of(context).size.width > 600 ? Axis.horizontal : Axis.vertical,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
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
                                        Flexible(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'FATTURA ' + (title2.contains("COMMERCIALE") ? title2 : title2 == "isIN ? 'INCASSO' : 'PAGAMENTO'" ? (isIN ? 'INCASSO' : 'PAGAMENTO') : title2),
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
                                        ),
                                      ],
                                    ),
                                    Wrap(
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      spacing: 16,
                                      runSpacing: 16,
                                      children: [
                                        Text(
                                          'Grazie!',
                                          style: GoogleFonts.caveat(
                                            color: const Color(0xFFB142F5),
                                            fontSize: 42,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (MediaQuery.of(context).size.width > 600)
                                          Container(width: 1, height: 40, color: const Color(0xFF322756)),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text('Bimbomixer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                            const SizedBox(height: 4),
                                            Text('SERVICE AUDIO, LUCI, VIDEO\nE PRODUZIONI TEATRALI', style: TextStyle(color: Colors.grey[500], fontSize: 10, height: 1.3)),
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
  }

  Widget _buildRowItem(IconData icon, String label, String value, {bool isAmount = false}) {
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
              style: TextStyle(color: Colors.grey[800], fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }
}

class HoverEditButton extends StatefulWidget {
  final VoidCallback onTap;
  
  const HoverEditButton({super.key, required this.onTap});

  @override
  State<HoverEditButton> createState() => _HoverEditButtonState();
}

class _HoverEditButtonState extends State<HoverEditButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
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
  }
}



