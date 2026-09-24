import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:contabile_app/database/database_helper.dart';
import 'package:contabile_app/providers/app_theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:contabile_app/utils/date_utils_app.dart';
import 'package:contabile_app/utils/security_utils.dart';
import 'package:contabile_app/screens/payment_summary_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class InvoiceSummaryScreen extends StatefulWidget {
  final Map<String, dynamic> invoice;
  final Function(Map<String, dynamic>) onEdit;

  const InvoiceSummaryScreen({super.key, required this.invoice, required this.onEdit});

  @override
  State<InvoiceSummaryScreen> createState() => _InvoiceSummaryScreenState();
}

class _InvoiceSummaryScreenState extends State<InvoiceSummaryScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  String? _customerName;
  List<String> _attachments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);

    final pData = widget.invoice;
    final custId = pData['customer_id'];
    if (custId != null) {
      final custList = await _dbHelper.getCustomers();
      final c = custList.cast<Map<String, dynamic>>().firstWhere(
        (e) => e['id'].toString() == custId.toString(),
        orElse: () => {},
      );
      _customerName = c['name'];
    }

    if (pData['attachments'] != null) {
      try {
        if (pData['attachments'] is String) {
          _attachments = List<String>.from(jsonDecode(pData['attachments']));
        } else if (pData['attachments'] is List) {
          _attachments = List<String>.from(pData['attachments']);
        }
      } catch (_) {}
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0710),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED))),
      );
    }

    final pData = widget.invoice;
    final amount = double.tryParse(pData['amount']?.toString() ?? '0') ?? 0.0;
    final theme = Provider.of<AppThemeProvider>(context);
    final isPaid = pData['status']?.toString().toUpperCase() == 'PAGATO';
    final invoiceNumber = pData['number']?.toString() ?? '-';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0710),
      body: SafeArea(
        child: Column(
          children: [
            // ══════════ COMBINED HEADER + TITLE (full-width stage lights bg) ══════════
            Stack(
              children: [
                // Stage lights — covers ENTIRE header+title area
                Positioned.fill(
                  child: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Colors.transparent, Colors.white],
                      stops: [0.0, 0.55],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ).createShader(bounds),
                    blendMode: BlendMode.dstIn,
                    child: Image.asset(
                      'assets/images/stage_lights.jpg',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                // Dark left overlay
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0A0710), Colors.transparent],
                        stops: [0.3, 1.0],
                      ),
                    ),
                  ),
                ),
                // Foreground
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Company header row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 10, 12, 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                            onPressed: () => Navigator.pop(context),
                          ),
                          ClipOval(
                            child: Image.asset(
                              'assets/images/logo_bimbomixer_bw.jpg',
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFF7C3AED), width: 2),
                                ),
                                child: const Icon(Icons.music_note, color: Color(0xFF7C3AED)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(text: 'BIMBO', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                                      TextSpan(text: 'MIXER', style: GoogleFonts.inter(color: const Color(0xFF7C3AED), fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                                    ],
                                  ),
                                ),
                                Text('SERVICE AUDIO  •  LUCI  •  VIDEO', style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 9, letterSpacing: 1.5, fontWeight: FontWeight.w500)),
                                const SizedBox(height: 5),
                                Row(children: [
                                  const Icon(Icons.location_on, color: Color(0xFF7C3AED), size: 11),
                                  const SizedBox(width: 3),
                                  Text('Vetralla (VT)', style: TextStyle(color: Colors.grey[400], fontSize: 10)),
                                  const SizedBox(width: 12),
                                  const Icon(Icons.email_outlined, color: Color(0xFF7C3AED), size: 11),
                                  const SizedBox(width: 3),
                                  Text('bimbomixer91@gmail.com', style: TextStyle(color: Colors.grey[400], fontSize: 10)),
                                ]),
                                const SizedBox(height: 2),
                                Row(children: [
                                  const Icon(Icons.badge_outlined, color: Color(0xFF7C3AED), size: 11),
                                  const SizedBox(width: 3),
                                  Text('P.IVA 02494800564', style: TextStyle(color: Colors.grey[400], fontSize: 10)),
                                  const SizedBox(width: 12),
                                  const Icon(Icons.phone, color: Color(0xFF7C3AED), size: 11),
                                  const SizedBox(width: 3),
                                  Text('+39 380 7483998', style: TextStyle(color: Colors.grey[400], fontSize: 10)),
                                ]),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
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
                    // Title row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(text: 'FATTURA ', style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
                                      TextSpan(text: 'COMMERCIALE', style: GoogleFonts.inter(color: const Color(0xFF7C3AED), fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text('N. $invoiceNumber', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                              ],
                            ),
                          ),
                          // Date + status
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF2A2A4A), width: 1),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today, color: Color(0xFF7C3AED), size: 15),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Data emissione', style: TextStyle(color: Colors.grey[400], fontSize: 9)),
                                        Text(DateUtilsApp.formatDbDate(pData['date']?.toString(), theme.dateFormat), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isPaid ? const Color(0xFF0D2E1A) : const Color(0xFF2E1A0D),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: isPaid ? Colors.green[700]! : Colors.orange[700]!, width: 1),
                                ),
                                child: Text(
                                  pData['status']?.toString().toUpperCase() ?? 'PENDING',
                                  style: TextStyle(color: isPaid ? Colors.greenAccent : Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // ══════════ CONTENT CARD ══════════
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                            blurRadius: 30,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildRow(Icons.person_outline, 'Cliente', _customerName ?? '-'),
                          _buildDivider(),
                          _buildAmountRow(amount),
                          _buildDivider(),
                          _buildRow(
                            Icons.event,
                            'Data Operazione',
                            DateUtilsApp.formatDbDate(pData['event_date']?.toString(), theme.dateFormat),
                          ),
                          if ((pData['client_vat'] ?? '').toString().isNotEmpty) ...[
                            _buildDivider(),
                            _buildRow(Icons.badge_outlined, 'P.IVA Cliente', pData['client_vat'].toString()),
                          ],
                          if ((pData['client_pec'] ?? '').toString().isNotEmpty) ...[
                            _buildDivider(),
                            _buildRow(Icons.email_outlined, 'PEC', pData['client_pec'].toString()),
                          ],
                          if ((pData['client_sdi'] ?? '').toString().isNotEmpty) ...[
                            _buildDivider(),
                            _buildRow(Icons.qr_code, 'SDI', pData['client_sdi'].toString()),
                          ],
                          if ((pData['client_address'] ?? '').toString().isNotEmpty) ...[
                            _buildDivider(),
                            _buildRow(
                              Icons.location_on_outlined,
                              'Indirizzo',
                              '${pData['client_address']} ${pData['client_city'] ?? ''} ${pData['client_province'] ?? ''}',
                            ),
                          ],
                          if ((pData['notes'] ?? '').toString().isNotEmpty) ...[
                            _buildDivider(),
                            _buildNoteRow(pData['notes'].toString()),
                          ],
                          const SizedBox(height: 90),
                        ],
                      ),
                    ),
                    // Watermark logo
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: Opacity(
                        opacity: 0.07,
                        child: Image.asset(
                          'assets/images/logo_bimbomixer_bw.jpg',
                          width: 150,
                          height: 150,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ══════════ FOOTER ══════════
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF0D0D1A),
                border: Border(top: BorderSide(color: Color(0xFF1E1E3A), width: 1)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1230),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.receipt_long, color: Color(0xFF7C3AED), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'FATTURA COMMERCIALE',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                        RichText(
                          text: const TextSpan(
                            children: [
                              TextSpan(text: 'Documento generato tramite ', style: TextStyle(color: Color(0xFF777777), fontSize: 9)),
                              TextSpan(text: 'Contabile App', style: TextStyle(color: Color(0xFF7C3AED), fontSize: 9, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Grazie!',
                        style: GoogleFonts.dancingScript(
                          color: const Color(0xFF7C3AED),
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text('Bimbomixer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                      Text('SERVICE AUDIO, LUCI, VIDEO', style: TextStyle(color: Colors.grey[600], fontSize: 8, letterSpacing: 0.8)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF3EEFF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF7C3AED), size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label, style: const TextStyle(color: Color(0xFF555555), fontWeight: FontWeight.w600, fontSize: 14)),
          ),
          Text(value, style: const TextStyle(color: Color(0xFF222222), fontWeight: FontWeight.w500, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildAmountRow(double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF3EEFF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.euro, color: Color(0xFF7C3AED), size: 18),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text('Importo', style: TextStyle(color: Color(0xFF555555), fontWeight: FontWeight.w600, fontSize: 14)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF3EEFF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '€ ${amount.toStringAsFixed(2).replaceAll('.', ',')}',
              style: const TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.w900, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteRow(String note) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF3EEFF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.notes, color: Color(0xFF7C3AED), size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Note', style: TextStyle(color: Color(0xFF555555), fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 4),
                Text(note, style: const TextStyle(color: Color(0xFF666666), fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(color: Color(0xFFEEEEEE), height: 1, thickness: 1);
  }
}
