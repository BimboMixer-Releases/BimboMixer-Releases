import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../database/database_helper.dart';
import '../models/models.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/glass_container.dart';
import '../services/pdf_report_service.dart';
import '../utils/report_utils.dart';
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

  Customer? _selectedCustomer;
  List<Map<String, dynamic>> _customerPayments = [];
  bool _isLoadingPayments = false;

  // Ricerca operazioni
  final TextEditingController _opsSearchCtrl = TextEditingController();
  String _opsSearchQuery = '';

  List<Map<String, dynamic>> get _filteredPayments {
    if (_opsSearchQuery.isEmpty) return _customerPayments;
    final q = _opsSearchQuery.toLowerCase();
    return _customerPayments.where((p) {
      final service = (p['service_name'] ?? p['category_name'] ?? '').toString().toLowerCase();
      final desc = (p['description'] ?? p['notes'] ?? '').toString().toLowerCase();
      final method = (p['payment_method'] ?? '').toString().toLowerCase();
      final date = (p['date'] ?? '').toString().toLowerCase();
      return service.contains(q) || desc.contains(q) || method.contains(q) || date.contains(q);
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

  Widget _buildDialogTextField(TextEditingController controller, String label, {int flex = 1}) {
    final field = TextField(
      controller: controller,
      style: TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
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
    
    final streetController = TextEditingController(text: customer?.addressStreet);
    final zipController = TextEditingController(text: customer?.addressZip);
    final cityController = TextEditingController(text: customer?.addressCity);
    final provController = TextEditingController(text: customer?.addressProvince);
    
    final pecController = TextEditingController(text: customer?.pec);
    final cigController = TextEditingController(text: customer?.cig);
    final cupController = TextEditingController(text: customer?.cup);
    final paRefController = TextEditingController(text: customer?.paReference);
    final paContractController = TextEditingController(text: customer?.paContract);

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

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setStateSB) {
          Future<void> pickLogo() async {
            try {
              final ImagePicker picker = ImagePicker();
              final XFile? photo = await picker.pickImage(source: ImageSource.gallery);
              
              if (photo != null) {
                final directory = await getApplicationDocumentsDirectory();
                final String targetPath = path.join(
                  directory.path, 
                  'contabile_logos', 
                  'logo_${DateTime.now().millisecondsSinceEpoch}.jpg'
                );
                
                final targetDir = Directory(path.dirname(targetPath));
                if (!await targetDir.exists()) {
                  await targetDir.create(recursive: true);
                }

                if (photo.name.toLowerCase().endsWith('.png')) {
                  final File file = File(photo.path);
                  final File savedFile = await file.copy(targetPath.replaceAll('.jpg', '.png'));
                  setStateSB(() {
                    logoPath = savedFile.path;
                  });
                } else {
                  final XFile? compressedImage = await FlutterImageCompress.compressAndGetFile(
                    photo.path,
                    targetPath,
                    quality: 60,
                    minWidth: 500,
                    minHeight: 500,
                  );

                  if (compressedImage != null) {
                    setStateSB(() {
                      logoPath = compressedImage.path;
                    });
                  }
                }
              }
            } catch (e) {
              debugPrint("Errore fotocamera/compressione logo: $e");
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
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 16),
                      GestureDetector(
                        onTap: pickLogo,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            shape: BoxShape.circle,
                            image: logoPath != null && File(logoPath!).existsSync()
                                ? DecorationImage(
                                    image: FileImage(File(logoPath!)),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                            border: Border.all(color: Colors.white.withOpacity(0.54)),
                          ),
                          child: logoPath == null || !File(logoPath!).existsSync()
                              ? Icon(Icons.add_a_photo, color: Colors.white.withOpacity(0.54), size: 30)
                              : null,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text('Aggiungi Logo', style: TextStyle(color: Colors.white.withOpacity(0.54), fontSize: 12)),
                      
                      _buildSectionTitle('Dati Principali', Icons.business),
                      Row(
                        children: [
                          _buildDialogTextField(nameController, 'Ragione Sociale / Nome Azienda *', flex: 2),
                          SizedBox(width: 16),
                          _buildDialogTextField(vatController, 'Partita IVA', flex: 1),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          _buildDialogTextField(sdiController, 'Codice Univoco (SDI)'),
                          SizedBox(width: 16),
                          _buildDialogTextField(taxCodeController, 'Codice Fiscale'),
                        ],
                      ),
                      
                      _buildSectionTitle('Sede Legale / Operativa', Icons.location_on),
                      Row(
                        children: [
                          _buildDialogTextField(streetController, 'Via/Piazza e N° Civico', flex: 3),
                          SizedBox(width: 16),
                          _buildDialogTextField(zipController, 'CAP', flex: 1),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          _buildDialogTextField(cityController, 'Città', flex: 2),
                          SizedBox(width: 16),
                          _buildDialogTextField(provController, 'Provincia (Sigla)', flex: 1),
                        ],
                      ),

                      _buildSectionTitle('Recapiti e Contatti', Icons.contact_mail),
                      Row(
                        children: [
                          _buildDialogTextField(emailController, 'Email', flex: 1),
                          SizedBox(width: 16),
                          _buildDialogTextField(pecController, 'Indirizzo PEC', flex: 1),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          _buildDialogTextField(phoneController, 'Cellulare / Telefono', flex: 1),
                          SizedBox(width: 16),
                          Expanded(child: Container()), // Spazio vuoto
                        ],
                      ),

                      _buildSectionTitle('Codici Pubblica Amministrazione', Icons.account_balance),
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
                          _buildDialogTextField(paRefController, 'Riferimento Amministrazione (es. N° Ordine)'),
                          SizedBox(width: 16),
                          _buildDialogTextField(paContractController, 'Codice Commessa / Convenzione'),
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
                              style: TextStyle(color: Colors.white.withOpacity(0.7)),
                            ),
                          ),
                          SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () async {
                              if (nameController.text.trim().isEmpty) return;

                              final newCustomer = Customer(
                                id: customer?.id,
                                name: nameController.text.trim(),
                                vatNumber: vatController.text.trim().isEmpty ? null : vatController.text.trim(),
                                sdiCode: sdiController.text.trim().isEmpty ? null : sdiController.text.trim(),
                                taxCode: taxCodeController.text.trim().isEmpty ? null : taxCodeController.text.trim(),
                                addressStreet: streetController.text.trim().isEmpty ? null : streetController.text.trim(),
                                addressZip: zipController.text.trim().isEmpty ? null : zipController.text.trim(),
                                addressCity: cityController.text.trim().isEmpty ? null : cityController.text.trim(),
                                addressProvince: provController.text.trim().isEmpty ? null : provController.text.trim(),
                                email: emailController.text.trim().isEmpty ? null : emailController.text.trim(),
                                pec: pecController.text.trim().isEmpty ? null : pecController.text.trim(),
                                phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                                // Il vecchio campo contacts lo lasciamo null per i nuovi o lo ereditiamo se era l'unico
                                contacts: customer?.contacts, 
                                cig: cigController.text.trim().isEmpty ? null : cigController.text.trim(),
                                cup: cupController.text.trim().isEmpty ? null : cupController.text.trim(),
                                paReference: paRefController.text.trim().isEmpty ? null : paRefController.text.trim(),
                                paContract: paContractController.text.trim().isEmpty ? null : paContractController.text.trim(),
                                logoPath: logoPath,
                              );

                              if (customer == null) {
                                await _dbHelper.insertCustomer(newCustomer.toMap());
                              } else {
                                await _dbHelper.updateCustomer(newCustomer.toMap());
                              }

                              if (dialogContext.mounted) Navigator.pop(dialogContext);
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
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
              ),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(
                      'ANNULLA',
                      style: TextStyle(color: Colors.white.withOpacity(0.7)),
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
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(Icons.filter_alt, color: Colors.white.withOpacity(0.7)),
          SizedBox(width: 12),
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
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Cerca Cliente (Tutti i Clienti)',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.54)),
                        border: InputBorder.none,
                        suffixIcon: IconButton(
                          icon: Icon(Icons.clear, color: Colors.white.withOpacity(0.54)),
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
        ],
      ),
    );
  }

  Widget _buildCustomerCard(Customer customer) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blueAccent,
              image: customer.logoPath != null && File(customer.logoPath!).existsSync()
                  ? DecorationImage(
                      image: FileImage(File(customer.logoPath!)),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: customer.logoPath == null || !File(customer.logoPath!).existsSync()
                ? Icon(Icons.person, color: Colors.white, size: 28)
                : null,
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12),
                
                // Dati Principali
                if (customer.vatNumber?.isNotEmpty == true || customer.taxCode?.isNotEmpty == true || customer.sdiCode?.isNotEmpty == true)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (customer.vatNumber?.isNotEmpty == true)
                          Text('P.IVA: ${customer.vatNumber}', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16)),
                        if (customer.taxCode?.isNotEmpty == true)
                          Text('C.F.: ${customer.taxCode}', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16)),
                        if (customer.sdiCode?.isNotEmpty == true)
                          Text('SDI: ${customer.sdiCode}', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16)),
                      ],
                    ),
                  ),

                // Sede
                if (customer.addressStreet?.isNotEmpty == true || customer.addressCity?.isNotEmpty == true)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.location_on, color: Colors.white.withOpacity(0.54), size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            [
                              customer.addressStreet,
                              if (customer.addressZip?.isNotEmpty == true) customer.addressZip,
                              customer.addressCity,
                              if (customer.addressProvince?.isNotEmpty == true) '(${customer.addressProvince})'
                            ].where((e) => e != null && e.toString().isNotEmpty).join(' '),
                            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Contatti
                if (customer.email?.isNotEmpty == true || customer.pec?.isNotEmpty == true || customer.phone?.isNotEmpty == true || customer.contacts?.isNotEmpty == true)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (customer.email?.isNotEmpty == true)
                          Row(children: [Icon(Icons.email, color: Colors.white.withOpacity(0.54), size: 20), SizedBox(width: 8), Expanded(child: Text(customer.email!, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16)))]),
                        if (customer.pec?.isNotEmpty == true)
                          Row(children: [Icon(Icons.mark_email_read, color: Colors.white.withOpacity(0.54), size: 20), SizedBox(width: 8), Expanded(child: Text('PEC: ${customer.pec}', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16)))]),
                        if (customer.phone?.isNotEmpty == true)
                          Row(children: [Icon(Icons.phone, color: Colors.white.withOpacity(0.54), size: 20), SizedBox(width: 8), Expanded(child: Text(customer.phone!, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16)))]),
                        if (customer.contacts?.isNotEmpty == true && customer.email?.isEmpty == true && customer.phone?.isEmpty == true)
                          Row(children: [Icon(Icons.contact_mail, color: Colors.white.withOpacity(0.54), size: 20), SizedBox(width: 8), Expanded(child: Text(customer.contacts!, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16)))]),
                      ],
                    ),
                  ),

                // Codici PA
                if (customer.cig?.isNotEmpty == true || customer.cup?.isNotEmpty == true || customer.paReference?.isNotEmpty == true || customer.paContract?.isNotEmpty == true)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (customer.cig?.isNotEmpty == true || customer.cup?.isNotEmpty == true)
                          Text(
                            'CIG: ${customer.cig ?? "-"} | CUP: ${customer.cup ?? "-"}',
                            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
                          ),
                        if (customer.paReference?.isNotEmpty == true)
                          Text('Rif. Ammin.: ${customer.paReference}', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16)),
                        if (customer.paContract?.isNotEmpty == true)
                          Text('Commessa/Conv.: ${customer.paContract}', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                icon: Icon(Icons.edit, color: Colors.blueAccent),
                onPressed: () => _showCustomerDialog(customer),
                tooltip: 'Modifica',
              ),
              IconButton(
                icon: Icon(Icons.delete, color: Colors.redAccent),
                onPressed: () => _deleteCustomer(customer.id!),
                tooltip: 'Elimina',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAllCustomersList() {
    if (_customers.isEmpty) {
      return Center(
        child: Text(
          'Nessun cliente in anagrafica.',
          style: TextStyle(color: Colors.white.withOpacity(0.54)),
        ),
      );
    }
    return ListView.builder(
      itemCount: _customers.length,
      itemBuilder: (context, index) {
        final customer = _customers[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: GlassContainer(
            child: Material(
              type: MaterialType.transparency,
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.blueAccent,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                title: Text(
                  customer.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  customer.vatNumber?.isNotEmpty == true
                      ? 'P.IVA: ${customer.vatNumber}'
                      : 'Nessuna P.IVA specificata',
                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit, color: Colors.blueAccent),
                      onPressed: () => _showCustomerDialog(customer),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () => _deleteCustomer(customer.id!),
                    ),
                  ],
                ),
                onTap: () => _onCustomerSelected(customer),
              ),
            ),
          ),
        );
      },
    );
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
                        icon: Icon(Icons.clear, color: Colors.white38, size: 18),
                        onPressed: () => setState(() {
                          _opsSearchQuery = '';
                          _opsSearchCtrl.clear();
                        }),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              
              final range = await ReportUtils.showDateRangeFilterDialog(context);
              if (range == null) return;
              
              final filteredByDate = _filteredPayments.where((p) {
                final date = p['date'] as String?;
                if (date == null || date.isEmpty) return true;
                return ReportUtils.isDateInRange(date, range);
              }).toList();
              
              if (filteredByDate.isEmpty) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nessuna operazione nel periodo selezionato.')),
                  );
                }
                return;
              }
              
              final List<List<String>> data = filteredByDate.map<List<String>>((p) {
                final serviceName = p['service_name'] ?? p['category_name'] ?? '';
                final notes = p['description'] ?? p['notes'] ?? '';
                final List<String> descParts = [];
                if (serviceName.toString().isNotEmpty) descParts.add(serviceName.toString());
                if (notes.toString().isNotEmpty) descParts.add(notes.toString());
                final descrizione = descParts.isNotEmpty ? descParts.join(' - ') : 'N/D';
                
                final cliente = _selectedCustomer?.name ?? 'N/D';
                final dataStr = p['date']?.toString() ?? '';
                final tipo = p['type'] == 'IN' ? 'E' : 'U';
                
                String metodo = p['payment_method']?.toString() ?? '';
                if (metodo.toLowerCase() == 'bonifico') {
                  metodo = 'BON';
                } else if (metodo.toLowerCase() == 'contanti') metodo = 'C/C';
                else if (metodo.toLowerCase() == 'assegno') metodo = 'ASS';
                else if (metodo.toLowerCase() == 'pos') metodo = 'POS';
                
                final importo = '${double.tryParse(p['amount']?.toString() ?? '0')?.toStringAsFixed(2) ?? '0.00'} €';
                
                final hasAtt = p['attachments'] != null && p['attachments'] != '[]';
                final allegati = hasAtt ? 'S' : 'N';
                
                return [cliente, descrizione, dataStr, tipo, metodo, importo, allegati];
              }).toList();
              
              await PDFReportService.generateAndDownloadReport(
                title: 'Storico Operazioni - ${_selectedCustomer?.name ?? ''}',
                headers: ['Cliente', 'Descrizione', 'Dt.', 'Tp.', 'Met.', 'Imp.', 'All.'],
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
                }
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerPayments() {
    if (_isLoadingPayments) {
      return Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    if (_customerPayments.isEmpty) {
      return Center(
        child: Text(
          'Nessuna operazione registrata per questo cliente.',
          style: TextStyle(color: Colors.white.withOpacity(0.54)),
        ),
      );
    }
    final filtered = _filteredPayments;
    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'Nessun risultato per questa ricerca.',
          style: TextStyle(color: Colors.white.withOpacity(0.54)),
        ),
      );
    }
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final payment = filtered[index];
        final isIncome = payment['type'] == 'IN';
        final serviceName = payment['service_name'] ?? payment['category_name'] ?? '';
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
                      '€ ${payment['amount'].toStringAsFixed(2)}',
                      style: TextStyle(
                        color: isIncome ? Colors.greenAccent : Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    if (serviceName.isNotEmpty) ...
                    [
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          serviceName,
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
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
                      style: TextStyle(color: Colors.white.withOpacity(0.54), fontSize: 12),
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
                        style: TextStyle(color: Colors.white.withOpacity(0.54), fontSize: 11),
                      )
                    : null,
              ),
            ),
          ),
        );
      },
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


