import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/models.dart';
import '../utils/security_utils.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/glass_container.dart';

Color _parseCategoryColor(String? raw, [Color fallback = Colors.grey]) {
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
    if (!mounted) {
      return;
    }
    setState(() => _isLoading = true);
    try {
      final data = await _dbHelper.getCategories();
      if (!mounted) {
        return;
      }
      setState(() {
        _categories = data.map((e) => Category.fromMap(e)).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore caricamento categorie: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showCategoryDialog([Category? category]) async {
    if (category != null) {
      final authorized = await SecurityUtils.requireAdminAuth(context);
      if (!authorized || !mounted) {
        return;
      }
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _CategoryFormDialog(
        dbHelper: _dbHelper,
        category: category,
      ),
    );
    if (saved == true && mounted) {
      await _refreshCategories();
    }
  }

  Future<void> _deleteCategory(String id) async {
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
                'Eliminando questa categoria, i pagamenti associati rimarranno senza categoria. Procedere?',
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
        await _dbHelper.deleteCategory(id);
        if (!mounted) {
          return;
        }
        await _refreshCategories();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Categoria eliminata.'),
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
          'Categorie Pagamenti',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _categories.isEmpty
          ? Center(
              child: Text(
                'Nessuna categoria definita.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.54)),
              ),
            )
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        cat.type == 'IN'
                            ? Icons.arrow_downward
                            : Icons.arrow_upward,
                        color: cat.type == 'IN'
                            ? Colors.greenAccent
                            : Colors.redAccent,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              cat.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              cat.type == 'IN' ? 'Entrata' : 'Uscita',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 12,
                              ),
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
                              if (cat.colorHex != null &&
                                  cat.colorHex!.trim().isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(right: 12),
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: _parseCategoryColor(cat.colorHex),
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
                                  size: 20,
                                ),
                                onPressed: () => _showCategoryDialog(cat),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.redAccent,
                                  size: 20,
                                ),
                                onPressed: cat.id == null
                                    ? null
                                    : () => _deleteCategory(cat.id!),
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
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _CategoryFormDialog extends StatefulWidget {
  final DatabaseHelper dbHelper;
  final Category? category;

  const _CategoryFormDialog({
    required this.dbHelper,
    this.category,
  });

  @override
  State<_CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<_CategoryFormDialog> {
  late final TextEditingController _nameController;
  late String _selectedType;
  String? _selectedColorHex;
  bool _isSaving = false;

  static const List<Color> _palette = [
    Colors.redAccent,
    Colors.orangeAccent,
    Colors.yellowAccent,
    Colors.greenAccent,
    Colors.blueAccent,
    Colors.indigoAccent,
    Colors.purpleAccent,
    Colors.pinkAccent,
    Colors.tealAccent,
    Colors.grey,
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name);
    final rawType = widget.category?.type;
    _selectedType = (rawType == 'IN' || rawType == 'OUT') ? rawType! : 'OUT';
    _selectedColorHex = widget.category?.colorHex;
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
      final newCategory = Category(
        id: widget.category?.id,
        name: name,
        type: _selectedType,
        colorHex: _selectedColorHex,
      );

      if (widget.category == null) {
        await widget.dbHelper.insertCategory(newCategory.toMap());
      } else {
        await widget.dbHelper.updateCategory(newCategory.toMap());
      }
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore salvataggio categoria: $e'),
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
              widget.category == null
                  ? 'Nuova Categoria'
                  : 'Modifica Categoria',
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
                labelText: 'Nome Categoria *',
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
            DropdownButtonFormField<String>(
              initialValue: _selectedType,
              dropdownColor: Colors.blueGrey[900],
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Tipo',
                labelStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'IN', child: Text('Entrata')),
                DropdownMenuItem(value: 'OUT', child: Text('Uscita')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedType = val);
                }
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Colore (per grafici):',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _palette.map((color) {
                final hex = color.toARGB32().toString();
                final isSelected = _selectedColorHex == hex;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedColorHex = hex);
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
