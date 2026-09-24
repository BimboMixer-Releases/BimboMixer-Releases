import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:contabile_app/database/database_helper.dart';
import 'package:contabile_app/providers/app_theme_provider.dart';
import 'package:contabile_app/utils/date_utils_app.dart';
import 'package:contabile_app/utils/security_utils.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:contabile_app/screens/payment_form_screen.dart';

class PaymentSummaryScreen extends StatefulWidget {
  final String paymentId;

  const PaymentSummaryScreen({super.key, required this.paymentId});

  @override
  State<PaymentSummaryScreen> createState() => _PaymentSummaryScreenState();
}

class _PaymentSummaryScreenState extends State<PaymentSummaryScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  Map<String, dynamic>? _paymentData;
  String? _customerName;
  String? _categoryName;
  String? _serviceName;
  List<String> _attachments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);

    final pData = await _dbHelper.getPaymentById(widget.paymentId);
    if (pData != null) {
      _paymentData = pData;

      final custId = pData['customer_id'];
      if (custId != null) {
        final custList = await _dbHelper.getCustomers();
        final c = custList.cast<Map<String, dynamic>>().firstWhere(
          (e) => e['id'].toString() == custId.toString(),
          orElse: () => {},
        );
        _customerName = c['name'];
      }

      final catId = pData['category_id'];
      if (catId != null) {
        final catList = await _dbHelper.getCategories();
        final c = catList.cast<Map<String, dynamic>>().firstWhere(
          (e) => e['id'].toString() == catId.toString(),
          orElse: () => {},
        );
        _categoryName = c['name'];
      }

      final srvId = pData['service_id'];
      if (srvId != null) {
        final srvList = await _dbHelper.getServiceTypes();
        final s = srvList.cast<Map<String, dynamic>>().firstWhere(
          (e) => e['id'].toString() == srvId.toString(),
          orElse: () => {},
        );
        _serviceName = s['name'];
      }

      if (pData['attachments'] != null) {
        try {
          _attachments = List<String>.from(jsonDecode(pData['attachments']));
        } catch (_) {}
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0710),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED))),
      );
    }

    if (_paymentData == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0710),
        appBar: AppBar(title: const Text('Errore'), backgroundColor: Colors.transparent, elevation: 0),
        body: const Center(child: Text('Movimento non trovato', style: TextStyle(color: Colors.white))),
      );
    }

    final isIN = _paymentData!['type'] == 'IN';
    final amount = double.tryParse(_paymentData!['amount']?.toString() ?? '0') ?? 0.0;
    final displayId = _paymentData!['id'].toString().padLeft(4, '0');
    final theme = Provider.of<AppThemeProvider>(context);
    final dateStr = DateUtilsApp.formatDbDate(_paymentData!['date']?.toString(), theme.dateFormat);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0710),
      body: SafeArea(
        child: Column(
          children: [
            // ══════════ COMBINED HEADER + TITLE (full-width stage lights bg) ══════════
            Stack(
              children: [
                // Stage lights — covers the ENTIRE header+title area, full width
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
                // Dark left overlay for text readability
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
                // Foreground content
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Company header row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 10, 12, 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Back button
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                            onPressed: () => Navigator.pop(context),
                          ),
                          // B&W Logo
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
                          // Company info
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
                                Text(
                                  'SERVICE AUDIO  •  LUCI  •  VIDEO',
                                  style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 9, letterSpacing: 1.5, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on, color: Color(0xFF7C3AED), size: 11),
                                    const SizedBox(width: 3),
                                    Text('Vetralla (VT)', style: TextStyle(color: Colors.grey[400], fontSize: 10)),
                                    const SizedBox(width: 12),
                                    const Icon(Icons.email_outlined, color: Color(0xFF7C3AED), size: 11),
                                    const SizedBox(width: 3),
                                    Text('bimbomixer91@gmail.com', style: TextStyle(color: Colors.grey[400], fontSize: 10)),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(Icons.badge_outlined, color: Color(0xFF7C3AED), size: 11),
                                    const SizedBox(width: 3),
                                    Text('P.IVA 02494800564', style: TextStyle(color: Colors.grey[400], fontSize: 10)),
                                    const SizedBox(width: 12),
                                    const Icon(Icons.phone, color: Color(0xFF7C3AED), size: 11),
                                    const SizedBox(width: 3),
                                    Text('+39 380 7483998', style: TextStyle(color: Colors.grey[400], fontSize: 10)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // MODIFICA button
                          HoverEditButton(
                            onTap: () async {
                              bool authorized = await SecurityUtils.requireAdminAuth(context);
                              if (!authorized || !context.mounted) return;
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PaymentFormScreen(paymentId: widget.paymentId, isReadOnly: false),
                                ),
                              );
                              _loadData();
                            },
                          ),
                        ],
                      ),
                    ),
                    // Title row — also on top of the stage lights bg
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
                                      TextSpan(
                                        text: 'RICEVUTA DI ',
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                      TextSpan(
                                        text: isIN ? 'INCASSO' : 'PAGAMENTO',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF7C3AED),
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'N. ${DateTime.now().year}/$displayId',
                                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          // Date badge
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
                                    Text('Data registrazione', style: TextStyle(color: Colors.grey[400], fontSize: 9)),
                                    Text(dateStr, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ),
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
                          _buildRow(Icons.credit_card, 'Metodo di pagamento', _paymentData!['payment_method']?.toString() ?? '-'),
                          _buildDivider(),
                          _buildRow(Icons.folder_outlined, 'Categoria', _categoryName ?? '-'),
                          _buildDivider(),
                          _buildRow(Icons.description_outlined, 'Prestazione', _serviceName ?? '-'),
                          if ((_paymentData!['notes'] ?? '').toString().isNotEmpty) ...[
                            _buildDivider(),
                            _buildNoteRow(_paymentData!['notes']?.toString() ?? ''),
                          ],
                          if (_attachments.isNotEmpty) ...[
                            _buildDivider(),
                            _buildAttachmentsRow(),
                          ],
                          const SizedBox(height: 90),
                        ],
                      ),
                    ),
                    // Watermark logo — bottom right of the card
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
                        Text(
                          isIN ? 'RICEVUTA DI INCASSO' : 'RICEVUTA DI PAGAMENTO',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
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

  Widget _buildAttachmentsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3EEFF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.attach_file, color: Color(0xFF7C3AED), size: 18),
              ),
              const SizedBox(width: 14),
              const Text('Allegati', style: TextStyle(color: Color(0xFF555555), fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          ..._attachments.map((url) => GestureDetector(
            onTap: () => _launchUrl(url),
            child: Padding(
              padding: const EdgeInsets.only(left: 40, bottom: 6),
              child: Text(
                url.split('/').last,
                style: const TextStyle(color: Color(0xFF7C3AED), decoration: TextDecoration.underline, fontSize: 12),
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(color: Color(0xFFEEEEEE), height: 1, thickness: 1);
  }
}

// ──────────────────────────────────────────
// Shared Widgets (used by InvoiceSummaryScreen too)
// ──────────────────────────────────────────

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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: _isHovering ? const Color(0xFF7C3AED) : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(25),
            boxShadow: _isHovering
                ? [BoxShadow(color: const Color(0xFF7C3AED).withValues(alpha: 0.5), blurRadius: 12, spreadRadius: 2)]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit_rounded, color: _isHovering ? Colors.white : Colors.white70, size: 15),
              const SizedBox(width: 6),
              Text(
                'MODIFICA',
                style: TextStyle(
                  color: _isHovering ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DashedDivider extends StatelessWidget {
  const DashedDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dashWidth = 8.0;
        const dashSpace = 4.0;
        final dashCount = (constraints.maxWidth / (dashWidth + dashSpace)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(dashCount, (_) => Container(
            width: dashWidth,
            height: 1,
            color: Colors.grey[300],
          )),
        );
      },
    );
  }
}
