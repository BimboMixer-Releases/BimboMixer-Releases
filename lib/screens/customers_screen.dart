import 'package:contabile_app/utils/currency_utils.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../database/database_helper.dart';
import '../models/models.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/glass_container.dart';
import '../services/pdf_report_service.dart';
import '../utils/report_utils.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/widgets.dart' as pw;

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Customer> _customers = [];
  bool _isLoading = true;
  bool _showArchive = false;
  bool _isCompactView = false;
  final TextEditingController _mainSearchCtrl = TextEditingController();
  String _mainSearchQuery = '';
  String _statusFilter = 'Tutti';

  Customer? _selectedCustomer;
  List<Map<String, dynamic>> _customerPayments = [];
  bool _isLoadingPayments = false;

  // Ricerca operazioni
  final TextEditingController _opsSearchCtrl = TextEditingController();
  String _opsSearchQuery = '';

  List<Customer> get _filteredCustomers {
    var list = _customers;

    if (_showArchive) {
      list = list.where((c) => c.status == 'Archiviato').toList();
    } else {
      list = list.where((c) => c.status != 'Archiviato').toList();
      if (_statusFilter != 'Tutti') {
        list = list
            .where((c) => (c.status ?? 'Nuovo') == _statusFilter)
            .toList();
      }
    }

    if (_mainSearchQuery.isNotEmpty) {
      final q = _mainSearchQuery.toLowerCase();
      list = list
          .where(
            (c) =>
                c.name.toLowerCase().contains(q) ||
                (c.vatNumber?.toLowerCase().contains(q) ?? false),
          )
          .toList();
    }
    return list;
  }

  List<Map<String, dynamic>> get _filteredPayments {
    if (_opsSearchQuery.isEmpty) return _customerPayments;
    final q = _opsSearchQuery.toLowerCase();
    return _customerPayments.where((p) {
      final service = (p['service_name'] ?? p['category_name'] ?? '')
          .toString()
          .toLowerCase();
      final desc = (p['description'] ?? p['notes'] ?? '')
          .toString()
          .toLowerCase();
      final method = (p['payment_method'] ?? '').toString().toLowerCase();
      final date = (p['date'] ?? '').toString().toLowerCase();
      return service.contains(q) ||
          desc.contains(q) ||
          method.contains(q) ||
          date.contains(q);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _refreshCustomers();
  }

  Future<void> _refreshCustomers() async {
    setState(() => _isLoading = true);
    final data = await _dbHelper.getCustomers();
    setState(() {
      _customers = data.map((e) => Customer.fromMap(e)).toList();
      _isLoading = false;
    });

    if (_selectedCustomer != null) {
      // Aggiorna il cliente selezionato se modificato
      final idx = _customers.indexWhere((c) => c.id == _selectedCustomer!.id);
      if (idx != -1) {
        _selectedCustomer = _customers[idx];
      } else {
        _selectedCustomer = null;
        _customerPayments = [];
      }
    }
  }

  Future<void> _loadCustomerPayments(String customerId) async {
    setState(() => _isLoadingPayments = true);
    final payments = await _dbHelper.getPaymentsByCustomer(customerId);
    setState(() {
      _customerPayments = payments;
      _isLoadingPayments = false;
    });
  }

  void _onCustomerSelected(Customer? customer) {
    setState(() {
      _selectedCustomer = customer;
      _opsSearchQuery = '';
      _opsSearchCtrl.clear();
    });
    if (customer != null) {
      _loadCustomerPayments(customer.id!);
    } else {
      _customerPayments = [];
    }
  }

  @override
  void dispose() {
    _opsSearchCtrl.dispose();
    _mainSearchCtrl.dispose();
    super.dispose();
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.blueAccent, size: 20),
          SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blueAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogTextField(
    TextEditingController controller,
    String label, {
    int flex = 1,
  }) {
    final field = TextField(
      controller: controller,
      style: TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: 13,
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white38),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.blueAccent),
        ),
      ),
    );
    return flex > 0 ? Expanded(flex: flex, child: field) : field;
  }

  void _showCustomerDialog([Customer? customer]) {
    final nameController = TextEditingController(text: customer?.name);
    final vatController = TextEditingController(text: customer?.vatNumber);
    final sdiController = TextEditingController(text: customer?.sdiCode);
    final taxCodeController = TextEditingController(text: customer?.taxCode);

    final streetController = TextEditingController(
      text: customer?.addressStreet,
    );
    final zipController = TextEditingController(text: customer?.addressZip);
    final cityController = TextEditingController(text: customer?.addressCity);
    final provController = TextEditingController(
      text: customer?.addressProvince,
    );

    final pecController = TextEditingController(text: customer?.pec);
    final cigController = TextEditingController(text: customer?.cig);
    final cupController = TextEditingController(text: customer?.cup);
    final paRefController = TextEditingController(text: customer?.paReference);
    final paContractController = TextEditingController(
      text: customer?.paContract,
    );

    // Parsare email e cellulare dalla stringa contacts se combinati (retrocompatibilità)
    String emailText = customer?.email ?? '';
    String phoneText = customer?.phone ?? '';

    if (emailText.isEmpty && phoneText.isEmpty && customer?.contacts != null) {
      final contacts = customer!.contacts!;
      if (contacts.contains('|')) {
        final parts = contacts.split('|');
        for (var part in parts) {
          part = part.trim();
          if (part.startsWith('Email:')) {
            emailText = part.replaceFirst('Email:', '').trim();
          } else if (part.startsWith('Tel:')) {
            phoneText = part.replaceFirst('Tel:', '').trim();
          }
        }
      } else {
        emailText = contacts; // Fallback legacy
      }
    }

    final emailController = TextEditingController(text: emailText);
    final phoneController = TextEditingController(text: phoneText);

    String? logoPath = customer?.logoPath;
    String selectedStatus = customer?.status ?? 'Nuovo';
    if (![
      'Attivo',
      'In Sospeso',
      'Priorità Alta',
      'In Revisione',
      'Nuovo',
      'Chiuso',
      'Archiviato',
    ].contains(selectedStatus)) {
      selectedStatus = 'Nuovo';
    }

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setStateSB) {
          Future<void> pickLogo() async {
            try {
              String? chosenPath;
              final result = await FilePicker.platform.pickFiles(
                type: FileType.image,
              );
              if (result != null &&
                  result.files.isNotEmpty &&
                  result.files.single.path != null) {
                chosenPath = result.files.single.path!;
              } else {
                try {
                  final ImagePicker picker = ImagePicker();
                  final XFile? photo = await picker.pickImage(
                    source: ImageSource.gallery,
                  );
                  if (photo != null) {
                    chosenPath = photo.path;
                  }
                } catch (_) {}
              }

              if (chosenPath != null) {
                String finalPath = chosenPath;
                try {
                  final directory = await getApplicationDocumentsDirectory();
                  final ext = path.extension(chosenPath).toLowerCase().isEmpty
                      ? '.png'
                      : path.extension(chosenPath).toLowerCase();
                  final String targetPath = path.join(
                    directory.path,
                    'contabile_logos',
                    'logo_${DateTime.now().millisecondsSinceEpoch}$ext',
                  );

                  final targetDir = Directory(path.dirname(targetPath));
                  if (!await targetDir.exists()) {
                    await targetDir.create(recursive: true);
                  }

                  final File file = File(chosenPath);
                  final File savedFile = await file.copy(targetPath);
                  finalPath = savedFile.path;
                } catch (copyErr) {
                  debugPrint("Errore copia logo: $copyErr");
                }

                setStateSB(() {
                  logoPath = finalPath;
                });
              }
            } catch (e) {
              debugPrint("Errore selezione logo: $e");
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: Text('Errore selezione logo: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          }

          return AlertDialog(
            backgroundColor: Colors.transparent,
            contentPadding: EdgeInsets.zero,
            content: Container(
              constraints: const BoxConstraints(maxWidth: 800),
              child: GlassContainer(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        customer == null ? 'Nuovo Cliente' : 'Modifica Cliente',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: pickLogo,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.white12,
                                shape: BoxShape.circle,
                                image:
                                    logoPath != null &&
                                        File(logoPath!).existsSync()
                                    ? DecorationImage(
                                        image: FileImage(File(logoPath!)),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                                border: Border.all(
                                  color: const Color(0xFF38BDF8),
                                  width: 1.5,
                                ),
                              ),
                              child:
                                  logoPath == null ||
                                      !File(logoPath!).existsSync()
                                  ? const Icon(
                                      Icons.add_a_photo,
                                      color: Colors.white70,
                                      size: 28,
                                    )
                                  : null,
                            ),
                          ),
                          if (logoPath != null &&
                              File(logoPath!).existsSync()) ...[
                            const SizedBox(width: 12),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                                size: 22,
                              ),
                              tooltip: 'Rimuovi logo',
                              onPressed: () {
                                setStateSB(() {
                                  logoPath = null;
                                });
                              },
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        logoPath != null && File(logoPath!).existsSync()
                            ? 'Clicca sul logo per cambiarlo'
                            : 'Aggiungi Logo / Immagine',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),

                      _buildSectionTitle('Dati Principali', Icons.business),
                      Row(
                        children: [
                          _buildDialogTextField(
                            nameController,
                            'Ragione Sociale / Nome Azienda *',
                            flex: 2,
                          ),
                          SizedBox(width: 16),
                          _buildDialogTextField(
                            vatController,
                            'Partita IVA',
                            flex: 1,
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedStatus,
                              dropdownColor: const Color(0xFF1E1E2C),
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Stato Cliente',
                                labelStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 13,
                                ),
                                enabledBorder: const UnderlineInputBorder(
                                  borderSide: BorderSide(color: Colors.white38),
                                ),
                                focusedBorder: const UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Colors.blueAccent,
                                  ),
                                ),
                              ),
                              items:
                                  [
                                        'Attivo',
                                        'In Sospeso',
                                        'Priorità Alta',
                                        'In Revisione',
                                        'Nuovo',
                                        'Chiuso',
                                        'Archiviato',
                                      ]
                                      .map(
                                        (s) => DropdownMenuItem(
                                          value: s,
                                          child: Text(s),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (val) {
                                if (val != null)
                                  setStateSB(() => selectedStatus = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          _buildDialogTextField(
                            sdiController,
                            'Codice Univoco (SDI)',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildDialogTextField(
                            taxCodeController,
                            'Codice Fiscale',
                          ),
                        ],
                      ),

                      _buildSectionTitle(
                        'Sede Legale / Operativa',
                        Icons.location_on,
                      ),
                      Row(
                        children: [
                          _buildDialogTextField(
                            streetController,
                            'Via/Piazza e N° Civico',
                            flex: 3,
                          ),
                          SizedBox(width: 16),
                          _buildDialogTextField(zipController, 'CAP', flex: 1),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          _buildDialogTextField(
                            cityController,
                            'Città',
                            flex: 2,
                          ),
                          SizedBox(width: 16),
                          _buildDialogTextField(
                            provController,
                            'Provincia (Sigla)',
                            flex: 1,
                          ),
                        ],
                      ),

                      _buildSectionTitle(
                        'Recapiti e Contatti',
                        Icons.contact_mail,
                      ),
                      Row(
                        children: [
                          _buildDialogTextField(
                            emailController,
                            'Email',
                            flex: 1,
                          ),
                          SizedBox(width: 16),
                          _buildDialogTextField(
                            pecController,
                            'Indirizzo PEC',
                            flex: 1,
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          _buildDialogTextField(
                            phoneController,
                            'Cellulare / Telefono',
                            flex: 1,
                          ),
                          SizedBox(width: 16),
                          Expanded(child: Container()), // Spazio vuoto
                        ],
                      ),

                      _buildSectionTitle(
                        'Codici Pubblica Amministrazione',
                        Icons.account_balance,
                      ),
                      Row(
                        children: [
                          _buildDialogTextField(cigController, 'Codice CIG'),
                          SizedBox(width: 16),
                          _buildDialogTextField(cupController, 'Codice CUP'),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          _buildDialogTextField(
                            paRefController,
                            'Riferimento Amministrazione (es. N° Ordine)',
                          ),
                          SizedBox(width: 16),
                          _buildDialogTextField(
                            paContractController,
                            'Codice Commessa / Convenzione',
                          ),
                        ],
                      ),

                      SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: Text(
                              'ANNULLA',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () async {
                              if (nameController.text.trim().isEmpty) return;

                              final newCustomer = Customer(
                                id: customer?.id,
                                name: nameController.text.trim(),
                                vatNumber: vatController.text.trim().isEmpty
                                    ? null
                                    : vatController.text.trim(),
                                sdiCode: sdiController.text.trim().isEmpty
                                    ? null
                                    : sdiController.text.trim(),
                                taxCode: taxCodeController.text.trim().isEmpty
                                    ? null
                                    : taxCodeController.text.trim(),
                                addressStreet:
                                    streetController.text.trim().isEmpty
                                    ? null
                                    : streetController.text.trim(),
                                addressZip: zipController.text.trim().isEmpty
                                    ? null
                                    : zipController.text.trim(),
                                addressCity: cityController.text.trim().isEmpty
                                    ? null
                                    : cityController.text.trim(),
                                addressProvince:
                                    provController.text.trim().isEmpty
                                    ? null
                                    : provController.text.trim(),
                                email: emailController.text.trim().isEmpty
                                    ? null
                                    : emailController.text.trim(),
                                pec: pecController.text.trim().isEmpty
                                    ? null
                                    : pecController.text.trim(),
                                phone: phoneController.text.trim().isEmpty
                                    ? null
                                    : phoneController.text.trim(),
                                // Il vecchio campo contacts lo lasciamo null per i nuovi o lo ereditiamo se era l'unico
                                contacts: customer?.contacts,
                                cig: cigController.text.trim().isEmpty
                                    ? null
                                    : cigController.text.trim(),
                                cup: cupController.text.trim().isEmpty
                                    ? null
                                    : cupController.text.trim(),
                                paReference: paRefController.text.trim().isEmpty
                                    ? null
                                    : paRefController.text.trim(),
                                paContract:
                                    paContractController.text.trim().isEmpty
                                    ? null
                                    : paContractController.text.trim(),
                                logoPath: logoPath,
                                status: selectedStatus,
                              );

                              if (customer == null) {
                                await _dbHelper.insertCustomer(
                                  newCustomer.toMap(),
                                );
                              } else {
                                await _dbHelper.updateCustomer(
                                  newCustomer.toMap(),
                                );
                              }

                              if (dialogContext.mounted)
                                Navigator.pop(dialogContext);
                              _refreshCustomers();
                            },
                            child: Text('SALVA'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _deleteCustomer(String id) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: GlassContainer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Conferma Eliminazione',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Eliminando questo cliente, i pagamenti associati rimarranno senza cliente. Procedere?',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(
                      'ANNULLA',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: Text('ELIMINA'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true) {
      if (_selectedCustomer?.id == id) {
        setState(() {
          _selectedCustomer = null;
          _customerPayments = [];
        });
      }
      try {
        await _dbHelper.deleteCustomer(id);
        _refreshCustomers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cliente eliminato.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Errore eliminazione: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // --- WIDGETS ---

  Widget _buildFilterBar() {
    final statusList = [
      'Tutti',
      'Attivo',
      'In Sospeso',
      'Priorità Alta',
      'In Revisione',
      'Nuovo',
      'Chiuso',
      'Archivio',
    ];

    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.filter_alt,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Autocomplete<Customer>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return _customers;
                    }
                    return _customers.where((Customer customer) {
                      return customer.name.toLowerCase().contains(
                        textEditingValue.text.toLowerCase(),
                      );
                    });
                  },
                  displayStringForOption: (Customer option) => option.name,
                  onSelected: (Customer selection) {
                    _onCustomerSelected(selection);
                  },
                  fieldViewBuilder:
                      (
                        BuildContext context,
                        TextEditingController textEditingController,
                        FocusNode focusNode,
                        VoidCallback onFieldSubmitted,
                      ) {
                        if (_selectedCustomer != null &&
                            textEditingController.text.isEmpty) {
                          textEditingController.text = _selectedCustomer!.name;
                        }
                        return TextField(
                          controller: textEditingController,
                          focusNode: focusNode,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Cerca Cliente (Tutti i Clienti)',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.54),
                            ),
                            border: InputBorder.none,
                            suffixIcon: IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: Colors.white.withValues(alpha: 0.54),
                              ),
                              onPressed: () {
                                textEditingController.clear();
                                _onCustomerSelected(null);
                              },
                            ),
                          ),
                          onSubmitted: (String value) {
                            onFieldSubmitted();
                          },
                        );
                      },
                ),
              ),
              IconButton(
                icon: Icon(
                  _isCompactView
                      ? Icons.view_agenda_outlined
                      : Icons.table_rows_outlined,
                  color: Colors.white70,
                ),
                tooltip: _isCompactView ? 'Vista a schede' : 'Vista compatta',
                onPressed: () {
                  setState(() {
                    _isCompactView = !_isCompactView;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: statusList.map((status) {
                final isSelected =
                    (_showArchive && status == 'Archivio') ||
                    (!_showArchive && _statusFilter == status);
                Color activeColor = Colors.blueAccent;
                if (status == 'Attivo') {
                  activeColor = Colors.green;
                } else if (status == 'In Sospeso') {
                  activeColor = Colors.orange;
                } else if (status == 'Priorità Alta') {
                  activeColor = Colors.redAccent;
                } else if (status == 'In Revisione') {
                  activeColor = Colors.blue;
                } else if (status == 'Nuovo') {
                  activeColor = Colors.purpleAccent;
                } else if (status == 'Chiuso') {
                  activeColor = Colors.blueGrey;
                } else if (status == 'Archivio') {
                  activeColor = Colors.amber;
                }

                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(status),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (status == 'Archivio') {
                          _showArchive = selected;
                        } else {
                          _showArchive = false;
                          _statusFilter = selected ? status : 'Tutti';
                        }
                      });
                    },
                    selectedColor: activeColor.withValues(alpha: 0.25),
                    checkmarkColor: activeColor,
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    labelStyle: TextStyle(
                      color: isSelected ? activeColor : Colors.white70,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isSelected
                            ? activeColor
                            : Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(Customer customer) {
    Color statusColor = Colors.green;
    switch (customer.status) {
      case 'Attivo':
        statusColor = Colors.green;
        break;
      case 'In Sospeso':
        statusColor = Colors.orange;
        break;
      case 'Priorità Alta':
        statusColor = Colors.redAccent;
        break;
      case 'In Revisione':
        statusColor = Colors.blueAccent;
        break;
      case 'Nuovo':
        statusColor = Colors.purpleAccent;
        break;
      case 'Chiuso':
      case 'Archiviato':
        statusColor = Colors.grey;
        break;
    }

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar, Name, Status & Actions
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blueAccent.withValues(alpha: 0.2),
                  border: Border.all(
                    color: Colors.blueAccent.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  image:
                      customer.logoPath != null &&
                          File(customer.logoPath!).existsSync()
                      ? DecorationImage(
                          image: FileImage(File(customer.logoPath!)),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child:
                    customer.logoPath == null ||
                        !File(customer.logoPath!).existsSync()
                    ? const Icon(Icons.person, color: Colors.white, size: 24)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (customer.status != null &&
                        customer.status!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      PopupMenuButton<String>(
                        initialValue: customer.status,
                        tooltip: 'Cambia stato',
                        color: const Color(0xFF1E1E2C),
                        onSelected: (newStatus) async {
                          if (newStatus != customer.status) {
                            final updatedCustomer = Customer(
                              id: customer.id,
                              name: customer.name,
                              vatNumber: customer.vatNumber,
                              sdiCode: customer.sdiCode,
                              taxCode: customer.taxCode,
                              addressStreet: customer.addressStreet,
                              addressZip: customer.addressZip,
                              addressCity: customer.addressCity,
                              addressProvince: customer.addressProvince,
                              email: customer.email,
                              pec: customer.pec,
                              phone: customer.phone,
                              contacts: customer.contacts,
                              cig: customer.cig,
                              cup: customer.cup,
                              paReference: customer.paReference,
                              paContract: customer.paContract,
                              logoPath: customer.logoPath,
                              status: newStatus,
                            );
                            await _dbHelper.updateCustomer(
                              updatedCustomer.toMap(),
                            );
                            _refreshCustomers();
                          }
                        },
                        itemBuilder: (context) =>
                            [
                                  'Attivo',
                                  'In Sospeso',
                                  'Priorità Alta',
                                  'In Revisione',
                                  'Nuovo',
                                  'Chiuso',
                                  'Archiviato',
                                ]
                                .map(
                                  (s) => PopupMenuItem(
                                    value: s,
                                    child: Text(
                                      s,
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                customer.status!,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_drop_down,
                                size: 14,
                                color: statusColor,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: Colors.cyanAccent,
                      size: 20,
                    ),
                    onPressed: () => _showCustomerDialog(customer),
                    tooltip: 'Modifica',
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent.shade100,
                      size: 20,
                    ),
                    onPressed: () => _deleteCustomer(customer.id!),
                    tooltip: 'Elimina',
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Colors.white12, height: 1),
          ),

          // Dati Fiscali (P.IVA, C.F., SDI)
          if (customer.vatNumber?.isNotEmpty == true ||
              customer.taxCode?.isNotEmpty == true ||
              customer.sdiCode?.isNotEmpty == true)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (customer.vatNumber?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Text(
                        'P.IVA: ${customer.vatNumber}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  if (customer.taxCode?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Text(
                        'C.F.: ${customer.taxCode}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  if (customer.sdiCode?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Text(
                        'SDI: ${customer.sdiCode}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // Sede
          if (customer.addressStreet?.isNotEmpty == true ||
              customer.addressCity?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    color: Colors.white54,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      [
                            customer.addressStreet,
                            if (customer.addressZip?.isNotEmpty == true)
                              customer.addressZip,
                            customer.addressCity,
                            if (customer.addressProvince?.isNotEmpty == true)
                              '(${customer.addressProvince})',
                          ]
                          .where((e) => e != null && e.toString().isNotEmpty)
                          .join(' '),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Contatti
          if (customer.email?.isNotEmpty == true ||
              customer.pec?.isNotEmpty == true ||
              customer.phone?.isNotEmpty == true ||
              customer.contacts?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (customer.email?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.email_outlined,
                            color: Colors.white54,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              customer.email!,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (customer.pec?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.mark_email_read_outlined,
                            color: Colors.white54,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'PEC: ${customer.pec}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (customer.phone?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.phone_outlined,
                            color: Colors.white54,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              customer.phone!,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (customer.contacts?.isNotEmpty == true &&
                      customer.email?.isEmpty == true &&
                      customer.phone?.isEmpty == true)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.contact_mail_outlined,
                            color: Colors.white54,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              customer.contacts!,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

          // Codici PA
          if (customer.cig?.isNotEmpty == true ||
              customer.cup?.isNotEmpty == true ||
              customer.paReference?.isNotEmpty == true ||
              customer.paContract?.isNotEmpty == true)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (customer.cig?.isNotEmpty == true ||
                      customer.cup?.isNotEmpty == true)
                    Text(
                      'CIG: ${customer.cig ?? "-"} | CUP: ${customer.cup ?? "-"}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  if (customer.paReference?.isNotEmpty == true)
                    Text(
                      'Rif. Ammin.: ${customer.paReference}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  if (customer.paContract?.isNotEmpty == true)
                    Text(
                      'Commessa/Conv.: ${customer.paContract}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAllCustomersList() {
    final sortedCustomers = _filteredCustomers;
    if (sortedCustomers.isEmpty) {
      return Center(
        child: Text(
          'Nessun cliente in anagrafica.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.54)),
        ),
      );
    }
    if (_isCompactView) {
      return ListView.builder(
        itemCount: sortedCustomers.length,
        itemBuilder: (context, index) {
          return _buildCompactClientRow(sortedCustomers[index]);
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 850;

        return ListView.builder(
          itemCount: sortedCustomers.length,
          itemBuilder: (context, index) {
            // First 2 cards in a row if wide screen, matching reference image
            if (isWide && index == 0 && sortedCustomers.length >= 2) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildNeonClientCard(
                      sortedCustomers[0],
                      0,
                      isCompact: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildNeonClientCard(
                      sortedCustomers[1],
                      1,
                      isCompact: true,
                    ),
                  ),
                ],
              );
            }
            if (isWide && index == 1 && sortedCustomers.length >= 2) {
              return const SizedBox.shrink();
            }

            return _buildNeonClientCard(sortedCustomers[index], index);
          },
        );
      },
    );
  }

  Widget _buildNeonClientCard(
    Customer customer,
    int index, {
    bool isCompact = false,
  }) {
    // Alternating electric cyan and neon purple borders
    final neonColor = index % 2 == 0
        ? const Color(0xFF38BDF8)
        : const Color(0xFFC084FC);

    Color statusColor = const Color(0xFF4ADE80);
    switch (customer.status) {
      case 'Attivo':
        statusColor = const Color(0xFF4ADE80);
        break;
      case 'In Sospeso':
        statusColor = const Color(0xFFFBBF24);
        break;
      case 'Priorità Alta':
        statusColor = const Color(0xFFF87171);
        break;
      case 'In Revisione':
        statusColor = const Color(0xFF818CF8);
        break;
      case 'Nuovo':
        statusColor = const Color(0xFFC084FC);
        break;
      case 'Chiuso':
      case 'Archiviato':
        statusColor = Colors.grey;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF101322).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: neonColor.withValues(alpha: 0.45),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: neonColor.withValues(alpha: 0.12),
            blurRadius: 16,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _onCustomerSelected(customer),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Avatar, Name & Subtitle, Status Pill
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: neonColor.withValues(alpha: 0.15),
                        border: Border.all(color: neonColor, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: neonColor.withValues(alpha: 0.4),
                            blurRadius: 8,
                          ),
                        ],
                        image:
                            customer.logoPath != null &&
                                File(customer.logoPath!).existsSync()
                            ? DecorationImage(
                                image: FileImage(File(customer.logoPath!)),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child:
                          customer.logoPath == null ||
                              !File(customer.logoPath!).existsSync()
                          ? const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 24,
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            customer.addressCity?.isNotEmpty == true
                                ? customer.addressCity!
                                : (customer.vatNumber?.isNotEmpty == true
                                      ? 'P.IVA: ${customer.vatNumber}'
                                      : 'Cliente registrato'),
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.7),
                          width: 1.2,
                        ),
                      ),
                      child: Text(
                        customer.status ?? 'Attivo',
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Metrics Row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'P.IVA / ID',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            customer.vatNumber?.isNotEmpty == true
                                ? customer.vatNumber!
                                : (customer.taxCode?.isNotEmpty == true
                                      ? customer.taxCode!
                                      : '-'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Sede',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            customer.addressCity?.isNotEmpty == true
                                ? customer.addressCity!
                                : '-',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Stato Account',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            customer.status ?? 'Attivo',
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (!isCompact)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Contatto',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              customer.phone?.isNotEmpty == true
                                  ? customer.phone!
                                  : (customer.email?.isNotEmpty == true
                                        ? customer.email!
                                        : '-'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(color: Colors.white10, height: 1),
                const SizedBox(height: 8),

                // Bottom Action Bar
                Wrap(
                  alignment: WrapAlignment.spaceAround,
                  spacing: 4,
                  runSpacing: 8,
                  children: [
                    _buildCardActionBtn(
                      icon: Icons.person_search_outlined,
                      label: 'Vedi Storico',
                      onTap: () => _onCustomerSelected(customer),
                    ),
                    _buildCardActionBtn(
                      icon: Icons.email_outlined,
                      label: 'Invia Email',
                      onTap: () => _sendEmail(customer),
                    ),
                    _buildCardActionBtn(
                      icon: Icons.phone_outlined,
                      label: 'Chiama',
                      onTap: () => _makeCall(customer),
                    ),
                    _buildCardActionBtn(
                      icon: Icons.edit_outlined,
                      label: 'Modifica',
                      onTap: () => _showCustomerDialog(customer),
                    ),
                    _buildCardActionBtn(
                      icon: Icons.delete_outline,
                      label: 'Elimina',
                      onTap: () => _deleteCustomer(customer.id!),
                      color: Colors.redAccent.shade100,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardActionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color ?? Colors.white70),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color ?? Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendEmail(Customer customer) async {
    if (customer.email != null && customer.email!.isNotEmpty) {
      if (Platform.isWindows) {
        try {
          await Process.start('cmd', [
            '/c',
            'start',
            'outlook',
            '/c',
            'ipm.note',
            '/m',
            customer.email!,
          ]);
        } catch (e) {
          final Uri emailLaunchUri = Uri(
            scheme: 'mailto',
            path: customer.email,
          );
          if (await canLaunchUrl(emailLaunchUri))
            await launchUrl(emailLaunchUri);
        }
      } else {
        final Uri emailLaunchUri = Uri(scheme: 'mailto', path: customer.email);
        if (await canLaunchUrl(emailLaunchUri)) {
          await launchUrl(emailLaunchUri);
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nessuna email salvata per questo cliente.'),
          ),
        );
      }
    }
  }

  Future<void> _makeCall(Customer customer) async {
    if (customer.phone != null && customer.phone!.isNotEmpty) {
      final Uri phoneUri = Uri(scheme: 'tel', path: customer.phone);
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nessun numero di telefono salvato.')),
        );
      }
    }
  }

  Widget _buildOperationsSearchBar() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _opsSearchCtrl,
              style: TextStyle(color: Colors.white, fontSize: 13),
              onChanged: (v) => setState(() => _opsSearchQuery = v),
              decoration: InputDecoration(
                hintText: 'Cerca prestazione, data, metodo...',
                hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                prefixIcon: Icon(Icons.search, color: Colors.white38, size: 18),
                suffixIcon: _opsSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: Colors.white38,
                          size: 18,
                        ),
                        onPressed: () => setState(() {
                          _opsSearchQuery = '';
                          _opsSearchCtrl.clear();
                        }),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.print, color: Colors.blueAccent),
            tooltip: 'Esporta Storico Operazioni',
            onPressed: () async {
              if (_filteredPayments.isEmpty) return;

              final range = await ReportUtils.showDateRangeFilterDialog(
                context,
              );
              if (range == null) return;

              final filteredByDate = _filteredPayments.where((p) {
                final date = p['date'] as String?;
                if (date == null || date.isEmpty) return true;
                return ReportUtils.isDateInRange(date, range);
              }).toList();

              if (filteredByDate.isEmpty) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Nessuna operazione nel periodo selezionato.',
                      ),
                    ),
                  );
                }
                return;
              }

              final List<List<String>> data = filteredByDate.map<List<String>>((
                p,
              ) {
                final serviceName =
                    p['service_name'] ?? p['category_name'] ?? '';
                final notes = p['description'] ?? p['notes'] ?? '';
                final List<String> descParts = [];
                if (serviceName.toString().isNotEmpty)
                  descParts.add(serviceName.toString());
                if (notes.toString().isNotEmpty)
                  descParts.add(notes.toString());
                final descrizione = descParts.isNotEmpty
                    ? descParts.join(' - ')
                    : 'N/D';

                final cliente = _selectedCustomer?.name ?? 'N/D';
                final dataStr = p['date']?.toString() ?? '';
                final tipo = p['type'] == 'IN' ? 'E' : 'U';

                String metodo = p['payment_method']?.toString() ?? '';
                if (metodo.toLowerCase() == 'bonifico') {
                  metodo = 'BON';
                } else if (metodo.toLowerCase() == 'contanti')
                  metodo = 'C/C';
                else if (metodo.toLowerCase() == 'assegno')
                  metodo = 'ASS';
                else if (metodo.toLowerCase() == 'pos')
                  metodo = 'POS';

                final importo =
                    '${CurrencyUtils.formatEuro(double.tryParse(p['amount']?.toString() ?? '0') ?? 0.0)}';

                final hasAtt =
                    p['attachments'] != null && p['attachments'] != '[]';
                final allegati = hasAtt ? 'S' : 'N';

                return [
                  cliente,
                  descrizione,
                  dataStr,
                  tipo,
                  metodo,
                  importo,
                  allegati,
                ];
              }).toList();

              await PDFReportService.generateAndDownloadReport(
                title: 'Storico Operazioni - ${_selectedCustomer?.name ?? ''}',
                headers: [
                  'Cliente',
                  'Descrizione',
                  'Dt.',
                  'Tp.',
                  'Met.',
                  'Imp.',
                  'All.',
                ],
                data: data,
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(3),
                  2: const pw.FixedColumnWidth(55),
                  3: const pw.FixedColumnWidth(30),
                  4: const pw.FixedColumnWidth(40),
                  5: const pw.FixedColumnWidth(55),
                  6: const pw.FixedColumnWidth(30),
                },
                dateRangeText: ReportUtils.formatDateRangeText(range),
                landscape: true,
                legend: {
                  'Dt.': 'Data',
                  'Tp.': 'Tipo (E=Entrata, U=Uscita)',
                  'Met.': 'Metodo (BON=Bonifico, C/C=Contanti, ASS=Assegno)',
                  'Imp.': 'Importo',
                  'All.': 'Allegati Presenti (S=Si, N=No)',
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerPayments() {
    if (_isLoadingPayments) {
      return Center(child: CircularProgressIndicator(color: Colors.white));
    }
    if (_customerPayments.isEmpty) {
      return Center(
        child: Text(
          'Nessuna operazione registrata per questo cliente.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.54)),
        ),
      );
    }
    final filtered = _filteredPayments;
    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'Nessun risultato per questa ricerca.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.54)),
        ),
      );
    }
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final payment = filtered[index];
        final isIncome = payment['type'] == 'IN';
        final serviceName =
            payment['service_name'] ?? payment['category_name'] ?? '';
        final description = payment['description'] ?? payment['notes'] ?? '';
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: GlassContainer(
            child: Material(
              type: MaterialType.transparency,
              child: ListTile(
                leading: Icon(
                  isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                  color: isIncome ? Colors.greenAccent : Colors.redAccent,
                ),
                title: Row(
                  children: [
                    Text(
                      '${CurrencyUtils.formatEuro(payment['amount'])}',
                      style: TextStyle(
                        color: isIncome ? Colors.greenAccent : Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    if (serviceName.isNotEmpty) ...[
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          serviceName,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payment['date'] ?? '',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.54),
                        fontSize: 12,
                      ),
                    ),
                    if (description.isNotEmpty)
                      Text(
                        description,
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
                trailing: payment['payment_method'] != null
                    ? Text(
                        payment['payment_method'],
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.54),
                          fontSize: 11,
                        ),
                      )
                    : null,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompactClientRow(Customer customer) {
    Color statusColor = Colors.white;
    switch (customer.status) {
      case 'Attivo':
        statusColor = Colors.green;
        break;
      case 'In Sospeso':
        statusColor = Colors.orange;
        break;
      case 'Priorità Alta':
        statusColor = Colors.redAccent;
        break;
      case 'In Revisione':
        statusColor = Colors.blueAccent;
        break;
      case 'Nuovo':
        statusColor = Colors.purpleAccent;
        break;
      case 'Chiuso':
      case 'Archiviato':
        statusColor = Colors.grey;
        break;
    }

    return InkWell(
      onTap: () => _onCustomerSelected(customer),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor,
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withValues(alpha: 0.5),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: Text(
                customer.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                customer.email ?? 'N/A',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                customer.phone ?? 'N/A',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                customer.vatNumber ?? 'N/A',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white54, size: 20),
              onPressed: () => _showCustomerDialog(customer),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        
        title: Text(
          'Anagrafica Clienti',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.white))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Se schermo largo (PC) e c'è un cliente selezionato, metti card in alto a destra
                  final isWide = constraints.maxWidth > 700;

                  return Column(
                    children: [
                      // 1. Barra di ricerca / filtro (Sempre in alto)
                      _buildFilterBar(),

                      // 2. Contenuto dinamico
                      Expanded(
                        child: _selectedCustomer == null
                            ? _buildAllCustomersList()
                            : isWide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Colonna sinistra: Lista pagamenti
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Storico Operazioni',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        _buildOperationsSearchBar(),
                                        Expanded(
                                          child: _buildCustomerPayments(),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 24),
                                  // Colonna destra: Dati Cliente
                                  Expanded(
                                    flex: 1,
                                    child: _buildCustomerCard(
                                      _selectedCustomer!,
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Su mobile: prima i dati cliente in alto
                                  _buildCustomerCard(_selectedCustomer!),
                                  const Divider(
                                    color: Colors.white24,
                                    height: 24,
                                  ),
                                  Text(
                                    'Storico Operazioni',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  _buildOperationsSearchBar(),
                                  Expanded(child: _buildCustomerPayments()),
                                ],
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCustomerDialog(),
        backgroundColor: Colors.blueAccent,
        child: Icon(Icons.add),
      ),
    );
  }
}
