import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:contabile_app/database/database_helper.dart';
import 'package:contabile_app/models/models.dart';
import 'package:contabile_app/screens/payment_form_screen.dart';
import 'package:contabile_app/services/attachment_service.dart';
import 'package:contabile_app/utils/calculation_engine.dart';
import 'package:contabile_app/utils/currency_utils.dart';
import 'package:contabile_app/utils/date_utils_app.dart';
import 'package:contabile_app/utils/security_utils.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentSummaryScreen extends StatefulWidget {
  final String paymentId;

  const PaymentSummaryScreen({super.key, required this.paymentId});

  @override
  State<PaymentSummaryScreen> createState() => _PaymentSummaryScreenState();
}

class _PaymentSummaryScreenState extends State<PaymentSummaryScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final AttachmentService _attachmentService = AttachmentService();

  Map<String, dynamic>? _data;
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

  static List<String> _parseAttachmentsSafely(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      return raw
          .map((e) => e?.toString().trim() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }
    final trimmed = raw.toString().trim();
    if (trimmed.isEmpty || trimmed == '[]') return [];
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is List) {
        return decoded
            .map((e) => e?.toString().trim() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
      }
      if (decoded is String && decoded.trim().isNotEmpty) {
        return [decoded.trim()];
      }
    } catch (_) {
      final inner = (trimmed.startsWith('[') && trimmed.endsWith(']'))
          ? trimmed.substring(1, trimmed.length - 1)
          : trimmed;
      return inner
          .split(',')
          .map((s) => s.replaceAll('"', '').replaceAll("'", '').trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return [];
  }

  String _resolveStatusLabel(Map<String, dynamic> data) {
    if (CalculationEngine.isPaymentSettled(data)) {
      return 'Saldato';
    }
    final raw = (data['status'] ?? '').toString().trim().toUpperCase();
    if (raw.contains('SOLLECIT') || raw == 'LATE') {
      return 'Da Sollecitare';
    }
    return 'In Attesa';
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final pData = await _dbHelper.getPaymentById(widget.paymentId);
      if (!mounted) return;

      String? custName;
      String? catName;
      String? srvName;
      List<String> parsedAttachments = [];

      if (pData != null) {
        final custId = pData['customer_id']?.toString();
        if (custId != null && custId.isNotEmpty) {
          final custList = await _dbHelper.getCustomers();
          final c = custList.cast<Map<String, dynamic>>().firstWhere(
            (e) => e['id']?.toString() == custId,
            orElse: () => <String, dynamic>{},
          );
          custName = c['name']?.toString();
        }

        final catId = pData['category_id']?.toString();
        if (catId != null && catId.isNotEmpty) {
          final catList = await _dbHelper.getCategories();
          final c = catList.cast<Map<String, dynamic>>().firstWhere(
            (e) => e['id']?.toString() == catId,
            orElse: () => <String, dynamic>{},
          );
          catName = c['name']?.toString();
        }

        final srvId = pData['service_id']?.toString();
        if (srvId != null && srvId.isNotEmpty) {
          final srvList = await _dbHelper.getServiceTypes();
          final s = srvList.cast<Map<String, dynamic>>().firstWhere(
            (e) => e['id']?.toString() == srvId,
            orElse: () => <String, dynamic>{},
          );
          srvName = s['name']?.toString();
        }

        parsedAttachments = _parseAttachmentsSafely(pData['attachments']);
      }

      if (!mounted) return;
      setState(() {
        _data = pData;
        _customerName = custName;
        _categoryName = catName;
        _serviceName = srvName;
        _attachments = parsedAttachments;
      });
    } catch (e) {
      debugPrint('Errore caricamento riepilogo movimento: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openAttachment(String pathOrUrl) async {
    final trimmed = pathOrUrl.trim();
    if (trimmed.isEmpty) return;

    final isRemote =
        trimmed.startsWith('http://') || trimmed.startsWith('https://');

    try {
      if (!isRemote) {
        final localFile = File(trimmed);
        if (await localFile.exists()) {
          await OpenFilex.open(localFile.path);
          return;
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File locale non trovato sul dispositivo.'),
            ),
          );
        }
        return;
      }

      final Uri url = Uri.parse(trimmed);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        await _attachmentService.downloadAttachment(context, trimmed);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossibile aprire l\'allegato: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0710),
        body: Center(
          child: CircularProgressIndicator(color: Colors.purpleAccent),
        ),
      );
    }

    if (_data == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0710),
        appBar: AppBar(
          title: const Text('Errore'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: const Center(
          child: Text(
            'Movimento non trovato',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final isIN =
        (_data!['type'] ?? 'IN').toString().trim().toUpperCase() == 'IN';
    final regDate = DateUtilsApp.formatDbDate(
      _data!['date']?.toString(),
      'dd MMMM yyyy',
    );
    final displayId = 'ID: ${_data!['id'] ?? ''}';
    final String title2 = isIN ? 'INCASSO' : 'PAGAMENTO';
    final bool isSettled = CalculationEngine.isPaymentSettled(_data!);
    final String statusLabel = _resolveStatusLabel(_data!);
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 800;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0710),
      body: Stack(
        children: [
          Container(color: const Color(0xFF0A0710)),
          Positioned(
            top: 0,
            right: 0,
            width: screenWidth * 0.5,
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
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          HoverEditButton(
                            onTap: () async {
                              final authorized =
                                  await SecurityUtils.requireAdminAuth(context);
                              if (!authorized || !context.mounted) return;
                              final currentData = _data;
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PaymentFormScreen(
                                    paymentId: widget.paymentId,
                                    payment: currentData != null
                                        ? Payment.fromMap(
                                            currentData,
                                            widget.paymentId,
                                          )
                                        : null,
                                    isReadOnly: false,
                                  ),
                                ),
                              );
                              if (mounted) {
                                await _loadData();
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                              ),
                              tooltip: 'Chiudi e torna alla Home',
                              onPressed: () => Navigator.popUntil(
                                context,
                                (route) => route.isFirst,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 14.0 : 24.0,
                      vertical: 10.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(isMobile),
                        SizedBox(height: isMobile ? 24 : 40),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0E0B16),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: const Color(0xFF261D42),
                              width: 1.5,
                            ),
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
                              _buildBannerHeader(
                                isMobile,
                                title2,
                                displayId,
                                regDate,
                                isSettled,
                                statusLabel,
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isMobile ? 14.0 : 24.0,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8F7FA),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  padding: EdgeInsets.all(isMobile ? 16 : 24),
                                  child: isMobile
                                      ? _buildDetailsContent(
                                          isSettled,
                                          statusLabel,
                                        )
                                      : Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              flex: 7,
                                              child: _buildDetailsContent(
                                                isSettled,
                                                statusLabel,
                                              ),
                                            ),
                                            const SizedBox(width: 24),
                                            Expanded(
                                              flex: 4,
                                              child: Container(
                                                height: 380,
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFF8F7FA),
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                                child: Center(
                                                  child: Opacity(
                                                    opacity: 0.15,
                                                    child: Image.asset(
                                                      'assets/images/logo_bimbomixer_bw.png',
                                                      width: 300,
                                                      height: 300,
                                                      fit: BoxFit.contain,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              _buildFooter(isMobile, title2),
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

  Widget _buildStatusBadge(bool isSettled, String statusLabel) {
    final Color badgeColor = isSettled
        ? const Color(0xFF10B981)
        : (statusLabel == 'Da Sollecitare'
            ? const Color(0xFFEF4444)
            : const Color(0xFFF59E0B));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSettled ? Icons.check_circle_outline : Icons.schedule,
            color: badgeColor,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            statusLabel.toUpperCase(),
            style: TextStyle(
              color: badgeColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFB142F5).withValues(alpha: 0.4),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
              image: const DecorationImage(
                image: AssetImage('assets/images/logo_bimbomixer_bw.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 12),
          RichText(
            textAlign: TextAlign.center,
            text: const TextSpan(
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
              ),
              children: [
                TextSpan(
                  text: 'BIMBO',
                  style: TextStyle(color: Colors.white),
                ),
                TextSpan(
                  text: 'MIXER',
                  style: TextStyle(color: Color(0xFFB142F5)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'SERVICE AUDIO • LUCI • VIDEO\nPRODUZIONI TEATRALI',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 11,
              letterSpacing: 1.5,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.location_on,
                    color: Color(0xFFB142F5),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Vetralla (VT)',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.email,
                    color: Color(0xFFB142F5),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'bimbomixer91@gmail.com',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.person,
                    color: Color(0xFFB142F5),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'P.IVA 02494800564',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.phone,
                    color: Color(0xFFB142F5),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '+39 3807483998',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
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
              ),
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
                    TextSpan(
                      text: 'BIMBO',
                      style: TextStyle(color: Colors.white),
                    ),
                    TextSpan(
                      text: 'MIXER',
                      style: TextStyle(color: Color(0xFFB142F5)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'SERVICE AUDIO • LUCI • VIDEO\nPRODUZIONI TEATRALI',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 13,
                  letterSpacing: 2.0,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    color: Color(0xFFB142F5),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Vetralla (VT)',
                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  ),
                  const SizedBox(width: 32),
                  const Icon(
                    Icons.email,
                    color: Color(0xFFB142F5),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'bimbomixer91@gmail.com',
                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.person,
                    color: Color(0xFFB142F5),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'P.IVA 02494800564',
                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  ),
                  const SizedBox(width: 32),
                  const Icon(
                    Icons.phone,
                    color: Color(0xFFB142F5),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '+39 3807483998',
                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBannerHeader(
    bool isMobile,
    String title2,
    String displayId,
    String regDate,
    bool isSettled,
    String statusLabel,
  ) {
    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                RichText(
                  text: TextSpan(
                    text: 'RICEVUTA DI ',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                    children: [
                      TextSpan(
                        text: title2,
                        style: const TextStyle(color: Color(0xFFB142F5)),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(isSettled, statusLabel),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              displayId,
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF161124),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF261D42)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_month,
                    color: Color(0xFFB142F5),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Data registrazione',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        regDate,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    RichText(
                      text: TextSpan(
                        text: 'RICEVUTA DI ',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                        children: [
                          TextSpan(
                            text: title2,
                            style: const TextStyle(color: Color(0xFFB142F5)),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(isSettled, statusLabel),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  displayId,
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF161124),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF261D42)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_month,
                  color: Color(0xFFB142F5),
                  size: 26,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Data registrazione',
                      style: TextStyle(color: Colors.grey[400], fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      regDate,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsContent(bool isSettled, String statusLabel) {
    final amount = CurrencyUtils.parseCurrency(_data!['amount']?.toString());
    final statusColor = isSettled
        ? const Color(0xFF059669)
        : (statusLabel == 'Da Sollecitare'
            ? const Color(0xFFDC2626)
            : const Color(0xFFD97706));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildRowItem(
          Icons.person_outline,
          'Cliente',
          _customerName ?? '-',
        ),
        const Divider(color: Color(0xFFE5E0F1), height: 24),
        _buildRowItem(
          Icons.layers_outlined,
          'Importo',
          CurrencyUtils.formatEuro(amount),
          isAmount: true,
        ),
        const Divider(color: Color(0xFFE5E0F1), height: 24),
        _buildRowItem(
          isSettled ? Icons.check_circle_outline : Icons.schedule,
          'Stato',
          statusLabel,
          valueColor: statusColor,
        ),
        const Divider(color: Color(0xFFE5E0F1), height: 24),
        _buildRowItem(
          Icons.credit_card_outlined,
          'Metodo di pagamento',
          _data!['payment_method']?.toString() ?? '-',
        ),
        const Divider(color: Color(0xFFE5E0F1), height: 24),
        _buildRowItem(
          Icons.folder_outlined,
          'Categoria',
          _categoryName ?? '-',
        ),
        const Divider(color: Color(0xFFE5E0F1), height: 24),
        _buildRowItem(
          Icons.receipt_long_outlined,
          'Prestazione',
          _serviceName ?? '-',
        ),
        const SizedBox(height: 24),
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
                child: const Icon(
                  Icons.chat_bubble_outline,
                  color: Color(0xFF322756),
                  size: 18,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Note',
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _data!['notes']?.toString().isNotEmpty == true
                          ? _data!['notes'].toString()
                          : 'Nessuna nota aggiuntiva.',
                      style: TextStyle(
                        color: Colors.grey[800],
                        fontSize: 13,
                      ),
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
                const Text(
                  'Allegati',
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _attachments.map((pathOrUrl) {
                    final cleanName =
                        AttachmentService.extractCleanFileName(pathOrUrl);
                    final isRemote = pathOrUrl.startsWith('http://') ||
                        pathOrUrl.startsWith('https://');
                    final isPdf = cleanName.toLowerCase().endsWith('.pdf');

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3DCF0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () => _openAttachment(pathOrUrl),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isPdf
                                      ? Icons.picture_as_pdf
                                      : Icons.insert_drive_file_outlined,
                                  size: 15,
                                  color: const Color(0xFF322756),
                                ),
                                const SizedBox(width: 6),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 180,
                                  ),
                                  child: Text(
                                    cleanName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF322756),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isRemote) ...[
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => _attachmentService
                                  .downloadAttachment(context, pathOrUrl),
                              child: const Tooltip(
                                message: 'Scarica allegato',
                                child: Icon(
                                  Icons.download_rounded,
                                  size: 16,
                                  color: Color(0xFF7F30D8),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFooter(bool isMobile, String title2) {
    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB142F5).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.receipt_long,
                    color: Color(0xFFB142F5),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RICEVUTA DI $title2',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      RichText(
                        text: TextSpan(
                          text: 'Documento generato tramite ',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 10,
                          ),
                          children: const [
                            TextSpan(
                              text: 'Contabile App',
                              style: TextStyle(
                                color: Color(0xFFB142F5),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFF261D42), height: 1),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Grazie!',
                  style: GoogleFonts.caveat(
                    color: const Color(0xFFB142F5),
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 1,
                  height: 36,
                  color: const Color(0xFF322756),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bimbomixer',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'SERVICE AUDIO, LUCI, VIDEO\nE PRODUZIONI TEATRALI',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 9,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Padding(
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
                child: const Icon(
                  Icons.receipt_long,
                  color: Color(0xFFB142F5),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RICEVUTA DI $title2',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  RichText(
                    text: TextSpan(
                      text: 'Documento generato tramite ',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 11,
                      ),
                      children: const [
                        TextSpan(
                          text: 'Contabile App',
                          style: TextStyle(
                            color: Color(0xFFB142F5),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
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
              Container(
                width: 1,
                height: 40,
                color: const Color(0xFF322756),
              ),
              const SizedBox(width: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bimbomixer',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'SERVICE AUDIO, LUCI, VIDEO\nE PRODUZIONI TEATRALI',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 10,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRowItem(
    IconData icon,
    String label,
    String value, {
    bool isAmount = false,
    Color? valueColor,
  }) {
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
        const SizedBox(width: 14),
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (isAmount)
          Flexible(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEBE6F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Color(0xFF7F30D8),
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
            ),
          )
        else
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor ?? Colors.grey[800],
                fontSize: 14,
                fontWeight: valueColor != null
                    ? FontWeight.bold
                    : FontWeight.w600,
              ),
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
            color: _isHovering
                ? Colors.cyanAccent
                : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(30),
            boxShadow: _isHovering
                ? [
                    BoxShadow(
                      color: Colors.cyanAccent.withValues(alpha: 0.5),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: Row(
            children: [
              Icon(
                Icons.edit_rounded,
                color: _isHovering ? Colors.black87 : Colors.white,
                size: 18,
              ),
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