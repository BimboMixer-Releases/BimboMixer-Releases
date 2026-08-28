import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/models.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/glass_container.dart';

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
    setState(() => _isLoading = true);
    final data = await _dbHelper.getServiceTypes();
    setState(() {
      _services = data.map((e) => ServiceType.fromMap(e)).toList();
      _isLoading = false;
    });
  }

  void _showServiceDialog([ServiceType? service]) {
    final nameController = TextEditingController(text: service?.name);
    
    // Default color if none is set
    Color selectedColor = service?.colorHex != null 
        ? Color(int.parse(service!.colorHex!)) 
        : Colors.grey;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.transparent,
          contentPadding: EdgeInsets.zero,
          content: GlassContainer(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  service == null ? 'Nuovo Servizio' : 'Modifica Servizio',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Nome Servizio *',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.7))),
                  ),
                ),
                SizedBox(height: 16),
                StatefulBuilder(
                  builder: (context, setStateSB) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Colore (per grafico)', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                        SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Colors.redAccent, Colors.pinkAccent, Colors.purpleAccent, Colors.deepPurpleAccent,
                            Colors.indigoAccent, Colors.blueAccent, Colors.lightBlueAccent, Colors.cyanAccent,
                            Colors.tealAccent, Colors.greenAccent, Colors.lightGreenAccent, Colors.limeAccent,
                            Colors.yellowAccent, Colors.amberAccent, Colors.orangeAccent, Colors.deepOrangeAccent,
                            Colors.grey
                          ].map((c) => GestureDetector(
                            onTap: () => setStateSB(() => selectedColor = c),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: selectedColor.toARGB32() == c.toARGB32() ? Colors.white : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                          )).toList(),
                        ),
                      ],
                    );
                  }
                ),
                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text('ANNULLA', style: TextStyle(color: Colors.white.withOpacity(0.7))),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        if (nameController.text.trim().isEmpty) return;

                        final newService = ServiceType(
                          id: service?.id,
                          name: nameController.text.trim(),
                          colorHex: selectedColor.toARGB32().toString(),
                        );

                        if (service == null) {
                          await _dbHelper.insertServiceType(newService.toMap());
                        } else {
                          await _dbHelper.updateServiceType(newService.toMap());
                        }
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        _refreshServices();
                      },
                      child: Text('SALVA'),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  void _deleteService(String id) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: GlassContainer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Conferma Eliminazione', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
              SizedBox(height: 16),
              Text('Eliminando questo servizio, i pagamenti associati rimarranno senza servizio. Procedere?', style: TextStyle(color: Colors.white.withOpacity(0.7))),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text('ANNULLA', style: TextStyle(color: Colors.white.withOpacity(0.7))),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () => Navigator.pop(context, true),
                    child: Text('ELIMINA'),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );

    if (confirm == true) {
      await _dbHelper.deleteServiceType(id);
      _refreshServices();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        title: Text('Servizi Erogati', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.white))
          : _services.isEmpty
              ? Center(child: Text('Nessun servizio definito.', style: TextStyle(color: Colors.white.withOpacity(0.54))))
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
                          leading: Icon(Icons.design_services, color: Colors.blueAccent),
                          title: Text(srv.name, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (srv.colorHex != null)
                                Container(
                                  margin: const EdgeInsets.only(right: 12),
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: Color(int.parse(srv.colorHex!)),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                ),
                              IconButton(
                                icon: Icon(Icons.edit, color: Colors.blueAccent),
                                onPressed: () => _showServiceDialog(srv),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.redAccent),
                                onPressed: () => _deleteService(srv.id!),
                              ),
                            ],
                          ),
                        )),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showServiceDialog(),
        backgroundColor: Colors.blueAccent,
        child: Icon(Icons.add),
      ),
    );
  }
}


