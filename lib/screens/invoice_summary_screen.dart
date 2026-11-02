import 'dart:convert';
import 'dart:io';
import 'package:contabile_app/database/database_helper.dart';
import 'package:contabile_app/services/attachment_service.dart';
import 'package:contabile_app/utils/calculation_engine.dart';
import 'package:contabile_app/utils/currency_utils.dart';
import 'package:contabile_app/utils/date_utils_app.dart';
import 'package:contabile_app/utils/security_utils.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

class InvoiceSummaryScreen extends StatefulWidget {
  final String invoiceId;
  final Function(Map<String, dynamic>)? onEdit;

  const InvoiceSummaryScreen({
    super.key,
    required this.invoiceId,
    this.onEdit,
  });

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

  static List<String> _parseAttachments(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      return raw
          .map((e) => e?.toString().trim() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return [];
      if (trimmed.startsWith('[')) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is List) {
            return decoded
                .map((e) => e?.toString().trim() ?? '')
                .where((s) => s.isNotEmpty)
                .toList();
          }
        } catch (_) {
          final stripped = trimmed
              .substring(1, trimmed.endsWith(']') ? trimmed.length - 1 : trimmed.length);
          return stripped
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
        }
      }
      return trimmed
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return [];
  }

  String _firstNonEmpty(List<dynamic> values) {
    for (final v in values) {
      final s = v?.toString().trim() ?? '';
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final pData = await _dbHelper.getInvoiceById(widget.invoiceId);
      if (pData != null) {
        _data = pData;

        final custId = (pData['customer_id'] ?? pData['client_id'])?.toString();
        if (custId != null && custId.trim().isNotEmpty) {
          final custList = await _dbHelper.getCustomers();
          for (final c in custList) {
            if (c['id']?.toString() == custId) {
              _customerData = c;
              break;
            }
          }
        }

        _attachments = _parseAttachments(pData['attachments']);
      }
    } catch (e) {
      debugPrint('Errore caricamento riepilogo fattura: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openAttachment(String pathOrUrl) async {
    final trimmed = pathOrUrl.trim();
    if (trimmed.isEmpty) return;

    try {
      final isHttp =
          trimmed.startsWith('http://') || trimmed.startsWith('https://');
      if (!isHttp) {
        final localFile = File(trimmed);
        if (localFile.existsSync()) {
          await OpenFilex.open(localFile.path);
          return;
        }
      }

      final Uri? url = Uri.tryParse(trimmed);
      if (url != null && await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossibile aprire l\'allegato')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore apertura allegato: $e')),
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
            'Fattura non trovata',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 600;
    final isNarrow = screenWidth < 380;

    final invType =
        (_data!['type'] ?? 'IN').toString().trim().toUpperCase();
    final isOut = invType == 'OUT';
    final amount = CurrencyUtils.parseCurrency(_data!['amount']?.toString());
    final regDate = DateUtilsApp.formatDbDate(
      _data!['date']?.toString(),
      'dd MMMM yyyy',
    );
    final eventDateRaw = _data!['event_date']?.toString() ?? '';
    final eventDate = DateUtilsApp.formatDbDate(eventDateRaw);
    final vatCode = _firstNonEmpty([_data!['vat_code']]);
    final invTitle = _firstNonEmpty([_data!['title']]);

    final isSettled = CalculationEngine.isInvoiceSettled(_data!);
    final rawStatus =
        (_data!['status'] ?? '').toString().trim().toUpperCase();
    final isLate = !isSettled && rawStatus == 'LATE';
    final String statusLabel = isSettled
        ? (isOut ? 'Pagata' : 'Saldata')
        : (isLate ? 'In Ritardo' : (isOut ? 'Da Pagare' : 'Da Incassare'));
    final Color statusColor = isSettled
        ? const Color(0xFF10B981)
        : (isLate ? const Color(0xFFEF4444) : const Color(0xFFF59E0B));

    final invoiceNumber = _firstNonEmpty([_data!['number']]);
    final displayId = invoiceNumber.isNotEmpty
        ? 'N. $invoiceNumber'
        : 'N. ${_data!['id']}';
    final String docSubtitle = isOut ? 'PASSIVA' : 'COMMERCIALE';

    // Customer & fallback fields from invoice
    final clientName = _firstNonEmpty([
      _customerData?['name'],
      _data!['client_name'],
    ]);

    final street = _firstNonEmpty([
      _customerData?['address_street'],
      _customerData?['address'],
      _data!['client_street'],
      _data!['client_address'],
    ]);
    final zip = _firstNonEmpty([
      _customerData?['address_zip'],
      _data!['client_zip'],
    ]);
    final city = _firstNonEmpty([
      _customerData?['address_city'],
      _data!['client_city'],
    ]);
    final province = _firstNonEmpty([
      _customerData?['address_province'],
      _data!['client_province'],
    ]);

    final localityParts = <String>[
      if (zip.isNotEmpty) zip,
      if (city.isNotEmpty) city,
      if (province.isNotEmpty) '($province)',
    ];
    final locality = localityParts.join(' ');
    final addressParts = <String>[
      if (street.isNotEmpty) street,
      if (locality.isNotEmpty) locality,
    ];
    final fullAddress = addressParts.join(', ');

    final vatNumber = _firstNonEmpty([
      _customerData?['vat_number'],
      _data!['client_vat'],
    ]);
    final taxCode = _firstNonEmpty([
      _customerData?['tax_code'],
      _customerData?['fiscal_code'],
      _data!['client_tax_code'],
    ]);
    final String vatAndTax;
    if (vatNumber.isNotEmpty &&
        taxCode.isNotEmpty &&
        vatNumber.toLowerCase() != taxCode.toLowerCase()) {
      vatAndTax = '$vatNumber / $taxCode';
    } else {
      vatAndTax = vatNumber.isNotEmpty ? vatNumber : taxCode;
    }

    final sdiCode = _firstNonEmpty([
      _customerData?['sdi_code'],
      _customerData?['unique_code'],
      _data!['client_sdi'],
    ]);
    final pec = _firstNonEmpty([
      _customerData?['pec'],
      _data!['client_pec'],
    ]);
    final email = _firstNonEmpty([
      _customerData?['email'],
      _data!['client_email'],
    ]);
    final phone = _firstNonEmpty([
      _customerData?['phone'],
      _data!['client_phone'],
    ]);
    final paymentMethod = _firstNonEmpty([_data!['payment_method']]);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0710),
      body: Stack(
        children: [
          Container(color: const Color(0xFF0A0710)),

          // Stage Lights at top right, fading out
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
                // Top Bar with back button and conditional edit button
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
                          onPressed: () => Navigator.maybePop(context),
                        ),
                      ),
                      if (widget.onEdit != null)
                        HoverEditButton(
                          onTap: () async {
                            final authorized =
                                await SecurityUtils.requireAdminAuth(context);
                            if (!authorized || !context.mounted) return;
                            final invoiceCopy =
                                Map<String, dynamic>.from(_data!);
                            Navigator.pop(context, true);
                            widget.onEdit!(invoiceCopy);
                          },
                        ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: isNarrow ? 12.0 : 24.0,
                      vertical: 10.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header (Logo and Company Details)
                        Flex(
                          direction: isWide ? Axis.horizontal : Axis.vertical,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: isNarrow ? 90 : 110,
                              height: isNarrow ? 90 : 110,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFB142F5)
                                        .withValues(alpha: 0.4),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                                image: const DecorationImage(
                                  image: AssetImage(
                                    'assets/images/logo_bimbomixer_bw.png',
                                  ),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(width: 24, height: 16),
                            Builder(
                              builder: (context) {
                                final Widget col = Column(
                                  crossAxisAlignment: isWide
                                      ? CrossAxisAlignment.start
                                      : CrossAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: RichText(
                                        text: TextSpan(
                                          style: TextStyle(
                                            fontSize: isNarrow ? 32 : 42,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 2.0,
                                          ),
                                          children: const [
                                            TextSpan(
                                              text: 'BIMBO',
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                            TextSpan(
                                              text: 'MIXER',
                                              style: TextStyle(
                                                color: Color(0xFFB142F5),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'SERVICE AUDIO • LUCI • VIDEO\nPRODUZIONI TEATRALI',
                                      textAlign: isWide
                                          ? TextAlign.left
                                          : TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: isNarrow ? 11 : 13,
                                        letterSpacing: 1.8,
                                        fontWeight: FontWeight.bold,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Wrap(
                                      spacing: 16,
                                      runSpacing: 8,
                                      alignment: isWide
                                          ? WrapAlignment.start
                                          : WrapAlignment.center,
                                      children: [
                                        Text.rich(
                                          TextSpan(
                                            children: [
                                              const WidgetSpan(
                                                child: Padding(
                                                  padding: EdgeInsets.only(
                                                    right: 6,
                                                  ),
                                                  child: Icon(
                                                    Icons.location_on,
                                                    color: Color(0xFFB142F5),
                                                    size: 16,
                                                  ),
                                                ),
                                              ),
                                              TextSpan(
                                                text: 'Vetralla (VT)',
                                                style: TextStyle(
                                                  color: Colors.grey[400],
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text.rich(
                                          TextSpan(
                                            children: [
                                              const WidgetSpan(
                                                child: Padding(
                                                  padding: EdgeInsets.only(
                                                    right: 6,
                                                  ),
                                                  child: Icon(
                                                    Icons.email,
                                                    color: Color(0xFFB142F5),
                                                    size: 16,
                                                  ),
                                                ),
                                              ),
                                              TextSpan(
                                                text: 'bimbomixer91@gmail.com',
                                                style: TextStyle(
                                                  color: Colors.grey[400],
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 16,
                                      runSpacing: 8,
                                      alignment: isWide
                                          ? WrapAlignment.start
                                          : WrapAlignment.center,
                                      children: [
                                        Text.rich(
                                          TextSpan(
                                            children: [
                                              const WidgetSpan(
                                                child: Padding(
                                                  padding: EdgeInsets.only(
                                                    right: 6,
                                                  ),
                                                  child: Icon(
                                                    Icons.person,
                                                    color: Color(0xFFB142F5),
                                                    size: 16,
                                                  ),
                                                ),
                                              ),
                                              TextSpan(
                                                text: 'P.IVA 02494800564',
                                                style: TextStyle(
                                                  color: Colors.grey[400],
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text.rich(
                                          TextSpan(
                                            children: [
                                              const WidgetSpan(
                                                child: Padding(
                                                  padding: EdgeInsets.only(
                                                    right: 6,
                                                  ),
                                                  child: Icon(
                                                    Icons.phone,
                                                    color: Color(0xFFB142F5),
                                                    size: 16,
                                                  ),
                                                ),
                                              ),
                                              TextSpan(
                                                text: '+39 3807483998',
                                                style: TextStyle(
                                                  color: Colors.grey[400],
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                                return isWide ? Flexible(child: col) : col;
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // Bordered Container for Receipt
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
                              // Title, Status Badge & Date Banner
                              Padding(
                                padding: EdgeInsets.all(isNarrow ? 16.0 : 24.0),
                                child: Wrap(
                                  spacing: 16,
                                  runSpacing: 16,
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        RichText(
                                          text: TextSpan(
                                            text: 'FATTURA ',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: isNarrow ? 20 : 26,
                                              fontWeight: FontWeight.w900,
                                            ),
                                            children: [
                                              TextSpan(
                                                text: docSubtitle,
                                                style: const TextStyle(
                                                  color: Color(0xFFB142F5),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 10,
                                          runSpacing: 6,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            Text(
                                              displayId,
                                              style: TextStyle(
                                                color: Colors.grey[400],
                                                fontSize: 14,
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: statusColor.withValues(
                                                  alpha: 0.15,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: statusColor,
                                                  width: 1.2,
                                                ),
                                              ),
                                              child: Text(
                                                statusLabel.toUpperCase(),
                                                style: TextStyle(
                                                  color: statusColor,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (invTitle.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            invTitle,
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF161124),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: const Color(0xFF261D42),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.calendar_month,
                                            color: Color(0xFFB142F5),
                                            size: 24,
                                          ),
                                          const SizedBox(width: 10),
                                          Flexible(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  'Data registrazione',
                                                  style: TextStyle(
                                                    color: Colors.grey[400],
                                                    fontSize: 11,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  regDate.isNotEmpty
                                                      ? regDate
                                                      : '-',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 13,
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
                              ),

                              // Main White Card Area
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isNarrow ? 12.0 : 24.0,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8F7FA),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  padding: EdgeInsets.all(
                                    isNarrow ? 14.0 : 24.0,
                                  ),
                                  child: Flex(
                                    direction: isWide
                                        ? Axis.horizontal
                                        : Axis.vertical,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Builder(
                                        builder: (context) {
                                          final Widget col = Column(
                                            children: [
                                              _buildRowItem(
                                                Icons.person_outline,
                                                'Cliente',
                                                clientName.isNotEmpty
                                                    ? clientName
                                                    : '-',
                                              ),
                                              const Divider(
                                                color: Color(0xFFE5E0F1),
                                                height: 24,
                                              ),
                                              if (fullAddress.isNotEmpty) ...[
                                                _buildRowItem(
                                                  Icons.location_on_outlined,
                                                  'Indirizzo',
                                                  fullAddress,
                                                ),
                                                const Divider(
                                                  color: Color(0xFFE5E0F1),
                                                  height: 24,
                                                ),
                                              ],
                                              if (vatAndTax.isNotEmpty) ...[
                                                _buildRowItem(
                                                  Icons.badge_outlined,
                                                  'P.IVA / C.F.',
                                                  vatAndTax,
                                                ),
                                                const Divider(
                                                  color: Color(0xFFE5E0F1),
                                                  height: 24,
                                                ),
                                              ],
                                              if (sdiCode.isNotEmpty) ...[
                                                _buildRowItem(
                                                  Icons
                                                      .markunread_mailbox_outlined,
                                                  'Codice SDI',
                                                  sdiCode,
                                                ),
                                                const Divider(
                                                  color: Color(0xFFE5E0F1),
                                                  height: 24,
                                                ),
                                              ],
                                              if (pec.isNotEmpty) ...[
                                                _buildRowItem(
                                                  Icons.verified_user_outlined,
                                                  'PEC',
                                                  pec,
                                                ),
                                                const Divider(
                                                  color: Color(0xFFE5E0F1),
                                                  height: 24,
                                                ),
                                              ],
                                              if (email.isNotEmpty) ...[
                                                _buildRowItem(
                                                  Icons.email_outlined,
                                                  'Email',
                                                  email,
                                                ),
                                                const Divider(
                                                  color: Color(0xFFE5E0F1),
                                                  height: 24,
                                                ),
                                              ],
                                              if (phone.isNotEmpty) ...[
                                                _buildRowItem(
                                                  Icons.phone_outlined,
                                                  'Telefono',
                                                  phone,
                                                ),
                                                const Divider(
                                                  color: Color(0xFFE5E0F1),
                                                  height: 24,
                                                ),
                                              ],
                                              _buildRowItem(
                                                Icons.layers_outlined,
                                                'Importo',
                                                CurrencyUtils.formatEuro(
                                                  amount,
                                                ),
                                                isAmount: true,
                                              ),
                                              if (vatCode.isNotEmpty) ...[
                                                const Divider(
                                                  color: Color(0xFFE5E0F1),
                                                  height: 24,
                                                ),
                                                _buildRowItem(
                                                  Icons.percent_outlined,
                                                  'Codice IVA',
                                                  vatCode,
                                                ),
                                              ],
                                              if (eventDate.isNotEmpty) ...[
                                                const Divider(
                                                  color: Color(0xFFE5E0F1),
                                                  height: 24,
                                                ),
                                                _buildRowItem(
                                                  Icons.event_outlined,
                                                  'Data Evento',
                                                  eventDate,
                                                ),
                                              ],
                                              if (paymentMethod.isNotEmpty) ...[
                                                const Divider(
                                                  color: Color(0xFFE5E0F1),
                                                  height: 24,
                                                ),
                                                _buildRowItem(
                                                  Icons.credit_card_outlined,
                                                  'Metodo di pagamento',
                                                  paymentMethod,
                                                ),
                                              ],
                                              const Divider(
                                                color: Color(0xFFE5E0F1),
                                                height: 24,
                                              ),
                                              _buildRowItem(
                                                Icons.check_circle_outline,
                                                'Stato',
                                                statusLabel,
                                              ),

                                              const SizedBox(height: 24),

                                              // Note Container
                                              Container(
                                                width: double.infinity,
                                                padding: const EdgeInsets.all(
                                                  16,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFF0EDF6,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            8,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                          0xFFE3DCF0,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                      child: const Icon(
                                                        Icons
                                                            .chat_bubble_outline,
                                                        color: Color(
                                                          0xFF322756,
                                                        ),
                                                        size: 18,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          const Text(
                                                            'Note',
                                                            style: TextStyle(
                                                              color: Colors
                                                                  .black87,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 13,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            height: 4,
                                                          ),
                                                          Text(
                                                            _data!['notes']
                                                                        ?.toString()
                                                                        .trim()
                                                                        .isNotEmpty ==
                                                                    true
                                                                ? _data!['notes']
                                                                      .toString()
                                                                : 'Nessuna nota aggiuntiva.',
                                                            style: TextStyle(
                                                              color: Colors
                                                                  .grey[800],
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
                                                  padding: const EdgeInsets.all(
                                                    16,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFFF0EDF6,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          16,
                                                        ),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      const Text(
                                                        'Allegati',
                                                        style: TextStyle(
                                                          color: Colors.black87,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Wrap(
                                                        spacing: 8,
                                                        runSpacing: 8,
                                                        children: _attachments
                                                            .map((path) {
                                                              final cleanName =
                                                                  AttachmentService.extractCleanFileName(
                                                                    path,
                                                                  );
                                                              return InkWell(
                                                                onTap: () =>
                                                                    _openAttachment(
                                                                      path,
                                                                    ),
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      8,
                                                                    ),
                                                                child: ConstrainedBox(
                                                                  constraints:
                                                                      const BoxConstraints(
                                                                        maxWidth:
                                                                            220,
                                                                      ),
                                                                  child: Container(
                                                                    padding: const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          12,
                                                                      vertical:
                                                                          8,
                                                                    ),
                                                                    decoration: BoxDecoration(
                                                                      color: const Color(
                                                                        0xFFE3DCF0,
                                                                      ),
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                            8,
                                                                          ),
                                                                    ),
                                                                    child: Row(
                                                                      mainAxisSize:
                                                                          MainAxisSize
                                                                              .min,
                                                                      children: [
                                                                        const Icon(
                                                                          Icons
                                                                              .attach_file,
                                                                          size:
                                                                              14,
                                                                          color: Color(
                                                                            0xFF322756,
                                                                          ),
                                                                        ),
                                                                        const SizedBox(
                                                                          width:
                                                                              6,
                                                                        ),
                                                                        Flexible(
                                                                          child: Text(
                                                                            cleanName,
                                                                            maxLines:
                                                                                1,
                                                                            overflow:
                                                                                TextOverflow.ellipsis,
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
                                                                ),
                                                              );
                                                            })
                                                            .toList(),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ],
                                          );
                                          return isWide
                                              ? Flexible(flex: 7, child: col)
                                              : col;
                                        },
                                      ),
                                      if (isWide) ...[
                                        const SizedBox(width: 24, height: 24),
                                        Flexible(
                                          flex: 4,
                                          child: Container(
                                            height: 380,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF8F7FA),
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
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Dark Footer inside container
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 24,
                                ),
                                child: Flex(
                                  direction: isWide
                                      ? Axis.horizontal
                                      : Axis.vertical,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFB142F5)
                                                .withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.receipt_long,
                                            color: Color(0xFFB142F5),
                                            size: 28,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Flexible(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'FATTURA $docSubtitle',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              RichText(
                                                text: TextSpan(
                                                  text:
                                                      'Documento generato tramite ',
                                                  style: TextStyle(
                                                    color: Colors.grey[500],
                                                    fontSize: 11,
                                                  ),
                                                  children: const [
                                                    TextSpan(
                                                      text: 'Contabile App',
                                                      style: TextStyle(
                                                        color: Color(
                                                          0xFFB142F5,
                                                        ),
                                                        fontWeight:
                                                            FontWeight.bold,
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
                                    if (!isWide) const SizedBox(height: 16),
                                    Wrap(
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      alignment: WrapAlignment.center,
                                      spacing: 16,
                                      runSpacing: 12,
                                      children: [
                                        Text(
                                          'Grazie!',
                                          style: GoogleFonts.caveat(
                                            color: const Color(0xFFB142F5),
                                            fontSize: isNarrow ? 34 : 42,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (isWide)
                                          Container(
                                            width: 1,
                                            height: 40,
                                            color: const Color(0xFF322756),
                                          ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
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
                              ),
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

  Widget _buildRowItem(
    IconData icon,
    String label,
    String value, {
    bool isAmount = false,
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
        const SizedBox(width: 12),
        Expanded(
          flex: 4,
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
          Expanded(
            flex: 5,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEBE6F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Color(0xFF7F30D8),
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
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
              style: TextStyle(
                color: Colors.grey[800],
                fontSize: 14,
                fontWeight: FontWeight.w600,
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
                : const [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
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
