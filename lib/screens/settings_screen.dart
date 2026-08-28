import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:image/image.dart' as img_pkg;
import '../providers/app_theme_provider.dart';
import '../widgets/glass_container.dart';
import '../widgets/gradient_scaffold.dart';
import '../migration_helper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isProcessing = false;
  bool _isDirty = false;

  String? _tempBgImage;
  String? _tempLogoImage;
  late Color _tempPrimaryColor;
  late Color _tempTextColor;
  late Color _tempCardColor;
  late Color _tempBorderColor;
  late Color _tempButtonColor;
  late Color _tempButtonTextColor;
  late Color _tempGlowColor;
  late GlowEffectType _tempGlowEffectType;
  late String _tempDateFormat;

  @override
  void initState() {
    super.initState();
    // Inizializza i valori temporanei leggendo dal provider attuale
    final theme = Provider.of<AppThemeProvider>(context, listen: false);
    _tempBgImage = theme.backgroundImagePath;
    _tempLogoImage = theme.logoImagePath;
    _tempPrimaryColor = theme.primaryColor;
    _tempTextColor = Colors.white;
    _tempCardColor = theme.cardColor;
    _tempBorderColor = theme.borderColor;
    _tempButtonColor = theme.buttonColor;
    _tempButtonTextColor = theme.buttonTextColor;
    _tempGlowColor = theme.glowColor;
    _tempGlowEffectType = theme.glowEffectType;
    _tempDateFormat = theme.dateFormat;
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  Future<String?> _pickAndCompressImage(String targetName) async {
    setState(() => _isProcessing = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return null;

      final sourcePath = result.files.single.path!;
      final dir = await getApplicationDocumentsDirectory();
      final destPath = p.join(dir.path, 'contabile_assets', '$targetName.jpg');
      await Directory(p.dirname(destPath)).create(recursive: true);

      // Su Windows usiamo la libreria 'image' puramente Dart per comprimere,
      // altrimenti flutter_image_compress crascia non essendo supportato nativamente
      if (Platform.isWindows || Platform.isLinux) {
        final bytes = await File(sourcePath).readAsBytes();
        final imageDecoded = img_pkg.decodeImage(bytes);
        if (imageDecoded != null) {
          var resized = imageDecoded;
          if (imageDecoded.width > 1280 || imageDecoded.height > 1280) {
            resized = img_pkg.copyResize(
              imageDecoded,
              width: imageDecoded.width > imageDecoded.height ? 1280 : null,
              height: imageDecoded.height >= imageDecoded.width ? 1280 : null,
            );
          }
          final jpg = img_pkg.encodeJpg(resized, quality: 75);
          await File(destPath).writeAsBytes(jpg);
          return destPath;
        } else {
          return sourcePath; // Fallback
        }
      } else {
        final compressed = await FlutterImageCompress.compressAndGetFile(
          sourcePath,
          destPath,
          quality: 75,
          minWidth: 1280,
          minHeight: 1280,
        );
        return compressed?.path;
      }
    } catch (e) {
      debugPrint('Errore durante la compressione: $e');
      return null;
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showColorPicker(
    BuildContext context,
    String title,
    Color currentColor,
    void Function(Color) onChanged,
  ) {
    Color picked = currentColor;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B2838),
        title: Text(title, style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: _ColorPickerGrid(
            current: currentColor,
            onColorSelected: (c) => picked = c,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('ANNULLA', style: TextStyle(color: Colors.white.withOpacity(0.54))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: picked),
            onPressed: () {
              onChanged(picked);
              Navigator.pop(ctx);
            },
            child: Text('APPLICA'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSettings() async {
    final theme = Provider.of<AppThemeProvider>(context, listen: false);
    
    if (_tempBgImage == null) {
      await theme.removeBackgroundImage();
    } else {
      await theme.setBackgroundImage(_tempBgImage!);
    }

    if (_tempLogoImage == null) {
      await theme.removeLogoImage();
    } else {
      await theme.setLogoImage(_tempLogoImage!);
    }

    await theme.setPrimaryColor(_tempPrimaryColor);
    await theme.setTextColor(_tempTextColor);
    await theme.setCardColor(_tempCardColor);
    await theme.setBorderColor(_tempBorderColor);
    await theme.setButtonColor(_tempButtonColor);
    await theme.setButtonTextColor(_tempButtonTextColor);
    await theme.setGlowColor(_tempGlowColor);
    await theme.setGlowEffectType(_tempGlowEffectType);
    await theme.setDateFormat(_tempDateFormat);

    setState(() => _isDirty = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impostazioni salvate con successo!')),
      );
      Navigator.pop(context); // Torna alla dashboard o chiudi settings
    }
  }

  bool _hasValidFile(String? path) {
    if (path == null) return false;
    return File(path).existsSync();
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        title: Text('Impostazioni', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          TextButton.icon(
            onPressed: () {
              setState(() {
                _tempBgImage = null;
                _tempLogoImage = null;
                _tempPrimaryColor = Colors.blueAccent;
                _tempTextColor = Colors.white;
                _tempCardColor = const Color(0x26FFFFFF);
                _tempBorderColor = const Color(0x33FFFFFF);
                _tempButtonColor = Colors.blueAccent;
                _tempButtonTextColor = Colors.white;
                _tempGlowColor = Colors.lightBlueAccent;
                _tempGlowEffectType = GlowEffectType.outerGlow;
                _isDirty = true;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Valori di default impostati. Premi Salva per applicare.')),
              );
            },
            icon: Icon(Icons.restore, color: Colors.white.withOpacity(0.7)),
            label: Text('Reset', style: TextStyle(color: Colors.white.withOpacity(0.7))),
          ),
        ],
      ),
      // Il FloatingActionButton appare solo se ci sono modifiche non salvate
      floatingActionButton: _isDirty
          ? FloatingActionButton.extended(
              onPressed: _saveSettings,
              backgroundColor: Colors.greenAccent,
              icon: Icon(Icons.save, color: Colors.black87),
              label: Text('Salva Modifiche', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
            )
          : null,
      body: _isProcessing
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text('Compressione immagine in corso...', style: TextStyle(color: Colors.white.withOpacity(0.7))),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── SEZIONE 1: Sfondo ────────────────────────────────
                  _sectionHeader(Icons.wallpaper, 'Sfondo Applicazione'),
                  SizedBox(height: 12),
                  GlassContainer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Carica un\'immagine come sfondo per tutta l\'app.',
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                        ),
                        SizedBox(height: 16),
                        if (_hasValidFile(_tempBgImage)) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(_tempBgImage!),
                              height: 140,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          SizedBox(height: 12),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _tempButtonColor,
                                  foregroundColor: _tempButtonTextColor,
                                ),
                                icon: Icon(Icons.upload_file, color: _tempButtonTextColor),
                                label: Text(_hasValidFile(_tempBgImage) ? 'Cambia Sfondo' : 'Scegli Immagine', style: TextStyle(color: _tempButtonTextColor)),
                                onPressed: () async {
                                  final path = await _pickAndCompressImage('bg_image_temp');
                                  if (path != null) {
                                    setState(() {
                                      _tempBgImage = path;
                                      _isDirty = true;
                                    });
                                  }
                                },
                              ),
                            ),
                            if (_hasValidFile(_tempBgImage)) ...[
                              SizedBox(width: 8),
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.redAccent),
                                tooltip: 'Rimuovi sfondo',
                                onPressed: () {
                                  setState(() {
                                    _tempBgImage = null;
                                    _isDirty = true;
                                  });
                                },
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 24),

                  // ── SEZIONE 2: Logo APK ─────────────────────────────
                  _sectionHeader(Icons.image_outlined, 'Logo Applicazione'),
                  SizedBox(height: 12),
                  GlassContainer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Carica il logo da mostrare nell\'app.',
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                        ),
                        SizedBox(height: 16),
                        if (_hasValidFile(_tempLogoImage)) ...[
                          Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.file(
                                File(_tempLogoImage!),
                                height: 100,
                                width: 100,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          SizedBox(height: 12),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _tempButtonColor,
                                  foregroundColor: _tempButtonTextColor,
                                ),
                                icon: Icon(Icons.upload, color: _tempButtonTextColor),
                                label: Text(_hasValidFile(_tempLogoImage) ? 'Cambia Logo' : 'Carica Logo', style: TextStyle(color: _tempButtonTextColor)),
                                onPressed: () async {
                                  final path = await _pickAndCompressImage('app_logo_temp');
                                  if (path != null) {
                                    setState(() {
                                      _tempLogoImage = path;
                                      _isDirty = true;
                                    });
                                  }
                                },
                              ),
                            ),
                            if (_hasValidFile(_tempLogoImage)) ...[
                              SizedBox(width: 8),
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.redAccent),
                                tooltip: 'Rimuovi logo',
                                onPressed: () {
                                  setState(() {
                                    _tempLogoImage = null;
                                    _isDirty = true;
                                  });
                                },
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 24),

                  // ── SEZIONE 3: Colori ────────────────────────────────
                  _sectionHeader(Icons.palette_outlined, 'Colori Applicazione'),
                  SizedBox(height: 12),
                  GlassContainer(
                    child: Column(
                      children: [
                        Text(
                          'Personalizza i colori. L\'anteprima qui sotto mostra i valori scelti, ma devi premere "Salva" per applicarli all\'intera app.',
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                        ),
                        SizedBox(height: 16),
                        _colorRow(
                          context,
                          Icons.format_color_text,
                          'Colore Primario / Accenti',
                          _tempPrimaryColor,
                          (c) => setState(() { _tempPrimaryColor = c; _isDirty = true; }),
                        ),
                        const Divider(color: Colors.white12, height: 24),
                        _colorRow(
                          context,
                          Icons.text_fields,
                          'Colore Testo',
                          _tempTextColor,
                          (c) => setState(() { _tempTextColor = c; _isDirty = true; }),
                        ),
                        const Divider(color: Colors.white12, height: 24),
                        _colorRow(
                          context,
                          Icons.grid_view,
                          'Colore Caselle (Glass)',
                          _tempCardColor,
                          (c) => setState(() { _tempCardColor = c; _isDirty = true; }),
                        ),
                        const Divider(color: Colors.white12, height: 24),
                        _colorRow(
                          context,
                          Icons.border_style,
                          'Colore Bordature',
                          _tempBorderColor,
                          (c) => setState(() { _tempBorderColor = c; _isDirty = true; }),
                        ),
                        const Divider(color: Colors.white12, height: 24),
                        _colorRow(
                          context,
                          Icons.smart_button,
                          'Colore Pulsanti',
                          _tempButtonColor,
                          (c) => setState(() { _tempButtonColor = c; _isDirty = true; }),
                        ),
                        const Divider(color: Colors.white12, height: 24),
                        _colorRow(
                          context,
                          Icons.text_format,
                          'Colore Testo Pulsanti',
                          _tempButtonTextColor,
                          (c) => setState(() { _tempButtonTextColor = c; _isDirty = true; }),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 24),

                  // ── SEZIONE 4: Formato Data ─────────────────────────────
                  _sectionHeader(Icons.calendar_today, 'Formato Data'),
                  SizedBox(height: 12),
                  GlassContainer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scegli il formato in cui verranno mostrate e salvate le date nell\'app.',
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                        ),
                        SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _tempDateFormat,
                          dropdownColor: const Color(0xFF1B2838),
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Colors.white24),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'yyyy-MM-dd', child: Text('AAAA-MM-GG (2024-12-31)')),
                            DropdownMenuItem(value: 'dd/MM/yyyy', child: Text('GG/MM/AAAA (31/12/2024)')),
                            DropdownMenuItem(value: 'MM/dd/yyyy', child: Text('MM/GG/AAAA (12/31/2024)')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _tempDateFormat = val;
                                _isDirty = true;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 24),

                  // ── SEZIONE 5: Effetti Visivi ─────────────────────────────
                  _sectionHeader(Icons.flare, 'Effetti Visivi (Glow)'),
                  SizedBox(height: 12),
                  GlassContainer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scegli l\'effetto luce al passaggio del mouse o al tocco.',
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                        ),
                        SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(Icons.animation, size: 20, color: Colors.white.withOpacity(0.7)),
                            SizedBox(width: 12),
                            Expanded(child: Text('Tipo di Effetto', style: TextStyle(color: Colors.white, fontSize: 14))),
                            Expanded(
                              flex: 2,
                              child: DropdownButton<GlowEffectType>(
                                value: _tempGlowEffectType,
                                isExpanded: true,
                                dropdownColor: const Color(0xFF203A43),
                                style: TextStyle(color: Colors.white, fontSize: 14),
                                underline: Container(height: 1, color: Colors.white38),
                                items: const [
                                  DropdownMenuItem(value: GlowEffectType.none, child: Text('Nessuno')),
                                  DropdownMenuItem(value: GlowEffectType.outerGlow, child: Text('Bagliore Esterno')),
                                  DropdownMenuItem(value: GlowEffectType.neonBorder, child: Text('Bordo Neon')),
                                  DropdownMenuItem(value: GlowEffectType.innerFill, child: Text('Luce Interna')),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _tempGlowEffectType = val;
                                      _isDirty = true;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const Divider(color: Colors.white12, height: 24),
                        _colorRow(
                          context,
                          Icons.color_lens,
                          'Colore Luce',
                          _tempGlowColor,
                          (c) => setState(() { _tempGlowColor = c; _isDirty = true; }),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 24),
                  GlassContainer(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _sectionHeader(Icons.save_alt, 'Migrazione Dati'),
                        SizedBox(height: 16),
                        Text(
                          'Usa questo strumento per recuperare i vecchi dati salvati in locale e portarli sul nuovo sistema in Cloud. Premi il pulsante solo una volta.',
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                        ),
                        SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () async {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Migrazione in corso... attendi...')),
                            );
                            try {
                              await MigrationHelper.migrate();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Migrazione Completata! I tuoi vecchi dati sono ora nel Cloud.'), backgroundColor: Colors.green),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Errore migrazione: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 10)),
                                );
                              }
                            }
                          },
                          icon: Icon(Icons.cloud_upload),
                          label: Text('MIGRA DATI LOCALI SUL CLOUD'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 80), // Padding extra per il floating action button
                ],
              ),
            ),
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.7), size: 20),
        SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ],
    );
  }

  Widget _colorRow(
    BuildContext context,
    IconData icon,
    String label,
    Color current,
    void Function(Color) onChanged,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.white.withOpacity(0.7)),
        SizedBox(width: 12),
        Expanded(child: Text(label, style: TextStyle(color: Colors.white, fontSize: 14))),
        GestureDetector(
          onTap: () => _showColorPicker(context, label, current, onChanged),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: current,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white38, width: 2),
              boxShadow: [BoxShadow(color: current.withValues(alpha: 0.5), blurRadius: 8)],
            ),
          ),
        ),
      ],
    );
  }
}

class _ColorPickerGrid extends StatefulWidget {
  final Color current;
  final void Function(Color) onColorSelected;

  const _ColorPickerGrid({required this.current, required this.onColorSelected});

  @override
  State<_ColorPickerGrid> createState() => _ColorPickerGridState();
}

class _ColorPickerGridState extends State<_ColorPickerGrid> {
  late Color _selected;

  static const _presets = [
    Colors.white,
    Colors.black,
    Colors.blueAccent,
    Colors.lightBlueAccent,
    Colors.cyanAccent,
    Colors.tealAccent,
    Colors.greenAccent,
    Colors.lightGreenAccent,
    Colors.yellowAccent,
    Colors.orangeAccent,
    Colors.deepOrangeAccent,
    Colors.redAccent,
    Colors.pinkAccent,
    Colors.purpleAccent,
    Colors.deepPurpleAccent,
    Colors.indigoAccent,
    Color(0xFF0F2027),
    Color(0xFF203A43),
    Color(0xFF2C5364),
    Color(0xFF1B2838),
    Color(0xff26ffffff),
    Color(0xff33ffffff),
    Color(0x33000000), // added transparent dark
    Colors.grey,
    Colors.blueGrey,
  ];

  @override
  void initState() {
    super.initState();
    _selected = widget.current;
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _presets.map((c) {
        final isSelected = _selected.toARGB32() == c.toARGB32();
        return GestureDetector(
          onTap: () {
            setState(() => _selected = c);
            widget.onColorSelected(c);
          },
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.lightBlueAccent : Colors.white24,
                width: isSelected ? 3 : 1.5,
              ),
            ),
            child: isSelected
                ? Icon(Icons.check, color: (c.computeLuminance() > 0.5 && c.alpha > 200) ? Colors.black : Colors.white, size: 20)
                : null,
          ),
        );
      }).toList(),
    );
  }
}


