import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/models.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/glass_container.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Category> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshCategories();
  }

  Future<void> _refreshCategories() async {
    setState(() => _isLoading = true);
    final data = await _dbHelper.getCategories();
    setState(() {
      _categories = data.map((e) => Category.fromMap(e)).toList();
      _isLoading = false;
    });
  }

  void _showCategoryDialog([Category? category]) {
    final nameController = TextEditingController(text: category?.name);
    String selectedType = category?.type ?? 'OUT'; // Default to Uscita
    String? selectedColorHex = category?.colorHex;

    final List<Color> palette = [
      Colors.redAccent, Colors.orangeAccent, Colors.yellowAccent,
      Colors.greenAccent, Colors.blueAccent, Colors.indigoAccent,
      Colors.purpleAccent, Colors.pinkAccent, Colors.tealAccent, Colors.grey
    ];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Colors.transparent,
              contentPadding: EdgeInsets.zero,
              content: GlassContainer(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      category == null ? 'Nuova Categoria' : 'Modifica Categoria',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Nome Categoria *',
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.7))),
                      ),
                    ),
                    SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      dropdownColor: Colors.blueGrey[900],
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Tipo',
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.7))),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'IN', child: Text('Entrata')),
                        DropdownMenuItem(value: 'OUT', child: Text('Uscita')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setStateDialog(() => selectedType = val);
                        }
                      },
                    ),
                    SizedBox(height: 16),
                    Text('Colore (per grafici):', style: TextStyle(color: Colors.white.withOpacity(0.7))),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: palette.map((color) {
                        String hex = color.toARGB32().toString();
                        bool isSelected = selectedColorHex == hex;
                        return GestureDetector(
                          onTap: () {
                            setStateDialog(() => selectedColorHex = hex);
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.transparent,
                                width: 3,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
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

                            final newCategory = Category(
                              id: category?.id,
                              name: nameController.text.trim(),
                              type: selectedType,
                              colorHex: selectedColorHex,
                            );

                            if (category == null) {
                              await _dbHelper.insertCategory(newCategory.toMap());
                            } else {
                              await _dbHelper.updateCategory(newCategory.toMap());
                            }
                            if (dialogContext.mounted) Navigator.pop(dialogContext);
                            _refreshCategories();
                          },
                          child: Text('SALVA'),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          }
        );
      },
    );
  }

  void _deleteCategory(String id) async {
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
              Text('Eliminando questa categoria, i pagamenti associati rimarranno senza categoria. Procedere?', style: TextStyle(color: Colors.white.withOpacity(0.7))),
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
      try {
        await _dbHelper.deleteCategory(id);
        _refreshCategories();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Categoria eliminata.'), backgroundColor: Colors.green));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore eliminazione: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        title: Text('Categorie Pagamenti', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.white))
          : _categories.isEmpty
              ? Center(child: Text('Nessuna categoria definita.', style: TextStyle(color: Colors.white.withOpacity(0.54))))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 350,
                    mainAxisExtent: 90, // Altezza fissa della casella
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    return GlassContainer(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Icon(
                            cat.type == 'IN' ? Icons.arrow_downward : Icons.arrow_upward,
                            color: cat.type == 'IN' ? Colors.greenAccent : Colors.redAccent,
                            size: 32,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  cat.name,
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  cat.type == 'IN' ? 'Entrata' : 'Uscita',
                                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (cat.colorHex != null)
                                    Container(
                                      margin: const EdgeInsets.only(right: 12),
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: Color(int.parse(cat.colorHex!)),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                    ),
                                  IconButton(
                                    icon: Icon(Icons.edit, color: Colors.blueAccent, size: 20),
                                    onPressed: () => _showCategoryDialog(cat),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  SizedBox(width: 8),
                                  IconButton(
                                    icon: Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                    onPressed: () => _deleteCategory(cat.id!),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategoryDialog(),
        backgroundColor: Colors.blueAccent,
        child: Icon(Icons.add),
      ),
    );
  }
}


