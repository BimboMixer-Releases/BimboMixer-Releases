import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/models.dart';
import '../utils/security_utils.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/glass_container.dart';

Color _parseServiceColor(String? raw, [Color fallback = Colors.grey]) {
  if (raw == null || raw.trim().isEmpty) {
    return fallback;
  }
  final s = raw.trim();
  if (s.startsWith('#')) {
    final hex = s.substring(1);
    final normalized = hex.length == 6 ? 'FF$hex' : hex;
    final val = int.tryParse(normalized, radix: 16);
    if (val != null) {
      return Color(val);
    }
  } else if (s.toLowerCase().startsWith('0x')) {
    final val = int.tryParse(s.substring(2), radix: 16);
    if (val != null) {
      return Color(val);
    }
  }
  final dec = int.tryParse(s);
  if (dec != null) {
    return Color(dec);
  }
  return fallback;
}

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<ServiceType> _services = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshServices();
  }

  Future<void> _refreshServices() async {
    if (!mounted) {
      return;
    }
    setState(() => _isLoading = true);
    try {
      final data = await _dbHelper.getServiceTypes();
      if (!mounted) {
        return;
      }
      setState(() {
        _services = data.map((e) => ServiceType.fromMap(e)).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore caricamento servizi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showServiceDialog([ServiceType? service]) async {
    if (service != null) {
      final authorized = await SecurityUtils.requireAdminAuth(context);
      if (!authorized || !mounted) {
        return;
      }
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ServiceFormDialog(
        dbHelper: _dbHelper,
        service: service,
      ),
    );
    if (saved == true && mounted) {
      await _refreshServices();
    }
  }

  Future<void> _deleteService(String id) async {
    final authorized = await SecurityUtils.requireAdminAuth(context);
    if (!authorized || !mounted) {
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: GlassContainer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Conferma Eliminazione',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Eliminando questo servizio, i pagamenti associati rimarranno senza servizio. Procedere?',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text(
                      'ANNULLA',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('ELIMINA'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true && mounted) {
      try {
        await _dbHelper.deleteServiceType(id);
        if (!mounted) {
          return;
        }
        await _refreshServices();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Servizio eliminato.'),
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

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        title: const Text(
          'Servizi Erogati',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _services.isEmpty
          ? Center(
              child: Text(
                'Nessun servizio definito.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.54)),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _services.length,
              itemBuilder: (context, index) {
                final srv = _services[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: GlassContainer(
                    child: Material(
                      type: MaterialType.transparency,
                      child: ListTile(
                        leading: const Icon(
                          Icons.design_services,
                          color: Colors.blueAccent,
                        ),
                        title: Text(
                          srv.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (srv.colorHex != null &&
                                srv.colorHex!.trim().isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(right: 12),
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: _parseServiceColor(srv.colorHex),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                              ),
                            IconButton(
                              icon: const Icon(
                                Icons.edit,
                                color: Colors.blueAccent,
                              ),
                              onPressed: () => _showServiceDialog(srv),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.redAccent,
                              ),
                              onPressed: srv.id == null
                                  ? null
                                  : () => _deleteService(srv.id!),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showServiceDialog(),
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ServiceFormDialog extends StatefulWidget {
  final DatabaseHelper dbHelper;
  final ServiceType? service;

  const _ServiceFormDialog({
    required this.dbHelper,
    this.service,
  });

  @override
  State<_ServiceFormDialog> createState() => _ServiceFormDialogState();
}

class _ServiceFormDialogState extends State<_ServiceFormDialog> {
  late final TextEditingController _nameController;
  late Color _selectedColor;
  bool _isSaving = false;

  static const List<Color> _palette = [
    Colors.redAccent,
    Colors.pinkAccent,
    Colors.purpleAccent,
    Colors.deepPurpleAccent,
    Colors.indigoAccent,
    Colors.blueAccent,
    Colors.lightBlueAccent,
    Colors.cyanAccent,
    Colors.tealAccent,
    Colors.greenAccent,
    Colors.lightGreenAccent,
    Colors.limeAccent,
    Colors.yellowAccent,
    Colors.amberAccent,
    Colors.orangeAccent,
    Colors.deepOrangeAccent,
    Colors.grey,
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.service?.name);
    _selectedColor = _parseServiceColor(widget.service?.colorHex);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      final newService = ServiceType(
        id: widget.service?.id,
        name: name,
        colorHex: _selectedColor.toARGB32().toString(),
      );

      if (widget.service == null) {
        await widget.dbHelper.insertServiceType(newService.toMap());
      } else {
        await widget.dbHelper.updateServiceType(newService.toMap());
      }
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore salvataggio servizio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.transparent,
      contentPadding: EdgeInsets.zero,
      content: GlassContainer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.service == null ? 'Nuovo Servizio' : 'Modifica Servizio',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Nome Servizio *',
                labelStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Colore (per grafico)',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _palette
                      .map(
                        (c) => GestureDetector(
                          onTap: () => setState(() => _selectedColor = c),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    _selectedColor.toARGB32() == c.toARGB32()
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSaving
                      ? null
                      : () => Navigator.pop(context, false),
                  child: Text(
                    'ANNULLA',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: const Text('SALVA'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
