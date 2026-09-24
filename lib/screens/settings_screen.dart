import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_theme_provider.dart';
import '../widgets/glass_container.dart';
import '../widgets/gradient_scaffold.dart';
import '../migration_helper.dart';
import '../utils/app_colors.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppThemeProvider>();

    return GradientScaffold(
      appBar: AppBar(
        title: Text('Impostazioni', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── SEZIONE 1: Tema (Skins) ────────────────────────────────
            _sectionHeader(LucideIcons.palette, 'Tema Applicazione'),
            SizedBox(height: 12),
            GlassContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Seleziona uno dei 7 preset di colore per personalizzare l\'aspetto.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                  ),
                  SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: ThemePreset.values.map((preset) {
                      final isSelected = theme.currentPreset == preset;
                      final colors = AppColors.presets[preset]!;
                      
                      return GestureDetector(
                        onTap: () {
                          theme.setPreset(preset);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Tema aggiornato!')),
                          );
                        },
                        child: Column(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: colors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? Colors.white : Colors.transparent,
                                  width: 3,
                                ),
                                boxShadow: isSelected ? [
                                  BoxShadow(
                                    color: colors.primary.withValues(alpha: 0.5),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  )
                                ] : [],
                              ),
                              child: isSelected 
                                  ? Icon(LucideIcons.check, color: Colors.white)
                                  : null,
                            ),
                            SizedBox(height: 8),
                            Text(
                              preset.name.toUpperCase(),
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white54,
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 24),
            
            // ── SEZIONE 2: Migrazione ────────────────────────────────
            _sectionHeader(LucideIcons.database, 'Migrazione Dati'),
            SizedBox(height: 12),
            GlassContainer(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Usa questo strumento per recuperare i vecchi dati salvati in locale e portarli sul nuovo sistema in Cloud. Premi il pulsante solo una volta.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
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
                            SnackBar(content: Text('Errore migrazione: '), backgroundColor: Colors.red, duration: const Duration(seconds: 10)),
                          );
                        }
                      }
                    },
                    icon: Icon(LucideIcons.uploadCloud),
                    label: Text('MIGRA DATI LOCALI SUL CLOUD'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.currentColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 24),

            // ── SEZIONE 3: Informazioni e Aggiornamenti ────────────────────────────────
            _sectionHeader(LucideIcons.info, 'Informazioni e Aggiornamenti'),
            SizedBox(height: 12),
            GlassContainer(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Versione App',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: theme.currentColors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.currentColors.primary.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          'v1.0.3 (Build 42)',
                          style: TextStyle(color: theme.currentColors.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Modifiche recenti (Changelog):',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  _buildChangelogItem('Dashboard ridisegnata con stile Axion (Glassmorphism e neon)'),
                  _buildChangelogItem('Aggiunta la sezione Feedback/Bug Report avanzata'),
                  _buildChangelogItem('Fix calcolo Utile Netto (evitate doppie sottrazioni per fatture pagate e scadenze)'),
                  _buildChangelogItem('Migliorato sistema di Login con sicurezza avanzata (SHA-256 e lockout)'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.7), size: 20),
        SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildChangelogItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: Colors.white, fontSize: 16)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
