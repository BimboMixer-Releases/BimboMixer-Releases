import 'package:flutter/material.dart';

class CustomerDialog extends StatefulWidget {
  final String initialName;
  final Future<String> Function(Map<String, dynamic>) onSave;

  const CustomerDialog({
    super.key,
    required this.initialName,
    required this.onSave,
  });

  @override
  State<CustomerDialog> createState() => _CustomerDialogState();
}

class _CustomerDialogState extends State<CustomerDialog> {
  late TextEditingController _nameController;
  final _vatController = TextEditingController();
  final _cfController = TextEditingController();
  final _univocoController = TextEditingController();
  final _addressController = TextEditingController();
  final _emailController = TextEditingController();
  final _pecController = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _vatController.dispose();
    _cfController.dispose();
    _univocoController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _pecController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) return;
    
    setState(() => _isSaving = true);
    try {
      final newCustomer = {
        'name': _nameController.text.trim(),
        'vat_number': _vatController.text.trim(),
        'fiscal_code': _cfController.text.trim(),
        'unique_code': _univocoController.text.trim(),
        'address': _addressController.text.trim(),
        'email': _emailController.text.trim(),
        'pec': _pecController.text.trim(),
      };
      
      await widget.onSave(newCustomer);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E24),
      title: const Text('Nuovo Cliente', style: TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Nome Cliente', labelStyle: TextStyle(color: Colors.white70)),
            ),
            TextField(
              controller: _vatController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Partita IVA', labelStyle: TextStyle(color: Colors.white70)),
            ),
            TextField(
              controller: _univocoController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Codice Univoco', labelStyle: TextStyle(color: Colors.white70)),
            ),
            TextField(
              controller: _cfController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Codice Fiscale', labelStyle: TextStyle(color: Colors.white70)),
            ),
            TextField(
              controller: _addressController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Indirizzo (Via, civico, cap, città, prov)', labelStyle: TextStyle(color: Colors.white70)),
            ),
            TextField(
              controller: _emailController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Email', labelStyle: TextStyle(color: Colors.white70)),
            ),
            TextField(
              controller: _pecController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'PEC', labelStyle: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Annulla', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
          child: _isSaving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
              : const Text('Salva', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
