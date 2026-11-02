import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../migration_helper.dart';
import '../providers/app_theme_provider.dart';
import '../services/update_service.dart';
import '../utils/app_colors.dart';
import '../utils/security_utils.dart';
import '../widgets/glass_container.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/update_dialog.dart';
import 'reports_screen.dart';
import 'users_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _versionLabel = '...';
  bool _isCheckingUpdates = false;
  bool _isMigrating = false;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _versionLabel = info.buildNumber.isNotEmpty
            ? 'v${info.version} (Build ${info.buildNumber})'
            : 'v${info.version}';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _versionLabel = 'v1.9.37';
      });
    }
  }

  Future<void> _handleCheckUpdates() async {
    if (_isCheckingUpdates) return;
    setState(() => _isCheckingUpdates = true);
    try {
      final updateService = UpdateService();
      final updateData = await updateService.checkForUpdate();
      if (!mounted) return;
      if (updateData != null) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => UpdateDialog(
            updateData: updateData,
            updateService: updateService,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'L\'applicazione è già aggiornata all\'ultima versione!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore controllo aggiornamenti: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCheckingUpdates = false);
      }
    }
  }

  Future<void> _handleMigration() async {
    if (_isMigrating) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: GlassContainer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_upload, color: Colors.orangeAccent, size: 42),
              const SizedBox(height: 12),
              const Text(
                'Conferma Migrazione Dati',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Questa operazione importerà i vecchi dati locali nel database Cloud. Eseguila solo una volta per evitare duplicati. Continuare?',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(
                      'ANNULLA',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('CONFERMA'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm != true || !mounted) return;

    final authorized = await SecurityUtils.requireAdminAuth(context);
    if (!authorized || !mounted) return;

    setState(() => _isMigrating = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Migrazione in corso... attendi...')),
    );

    try {
      await MigrationHelper.migrate();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Migrazione Completata! I tuoi vecchi dati sono ora nel Cloud.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore durante la migrazione: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 10),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isMigrating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppThemeProvider>();

    return GradientScaffold(
      appBar: AppBar(
        title: const Text(
          'Impostazioni',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── SEZIONE 1: Tema (Skins) ────────────────────────────────
            _sectionHeader(LucideIcons.palette, 'Tema Applicazione'),
            const SizedBox(height: 12),
            GlassContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Seleziona uno dei 7 preset di colore per personalizzare l\'aspetto.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
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
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.transparent,
                                  width: 3,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: colors.primary.withValues(
                                            alpha: 0.5,
                                          ),
                                          blurRadius: 10,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                    : [],
                              ),
                              child: isSelected
                                  ? const Icon(
                                      LucideIcons.check,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              preset.name.toUpperCase(),
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white54,
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
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

            const SizedBox(height: 24),

            // -- SEZIONE AMMINISTRATORI ------------------------------
            _sectionHeader(LucideIcons.users, 'Amministratori e Sicurezza'),
            const SizedBox(height: 12),
            GlassContainer(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Gestisci gli account amministratore, cambia le password e abilita il login tramite Fingerprint (impronta digitale/riconoscimento facciale).',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final authorized =
                          await SecurityUtils.requireAdminAuth(context);
                      if (!authorized || !context.mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const UsersScreen()),
                      );
                    },
                    icon: const Icon(LucideIcons.shield),
                    label: const Text('GESTIONE AMMINISTRATORI'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.currentColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── SEZIONE 2: Migrazione ────────────────────────────────
            _sectionHeader(LucideIcons.database, 'Migrazione Dati'),
            const SizedBox(height: 12),
            GlassContainer(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Usa questo strumento per recuperare i vecchi dati salvati in locale e portarli sul nuovo sistema in Cloud. Premi il pulsante solo una volta.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _isMigrating ? null : _handleMigration,
                    icon: const Icon(LucideIcons.uploadCloud),
                    label: Text(
                      _isMigrating
                          ? 'MIGRAZIONE IN CORSO...'
                          : 'MIGRA DATI LOCALI SUL CLOUD',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.currentColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── SEZIONE 3: Report e Feedback ────────────────────────────────
            _sectionHeader(LucideIcons.barChart2, 'Report e Feedback'),
            const SizedBox(height: 12),
            GlassContainer(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Invia feedback, segnala bug o proponi nuove idee per migliorare l\'applicazione.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ReportsScreen(),
                        ),
                      );
                    },
                    icon: const Icon(LucideIcons.messageSquare),
                    label: const Text('Apri Sezione Report'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── SEZIONE 4: Informazioni e Aggiornamenti ────────────────────────────────
            _sectionHeader(LucideIcons.info, 'Informazioni e Aggiornamenti'),
            const SizedBox(height: 12),
            GlassContainer(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Versione App',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: theme.currentColors.primary.withValues(
                              alpha: 0.2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.currentColors.primary.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                          child: Text(
                            _versionLabel,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: theme.currentColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: _isCheckingUpdates
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.yellowAccent,
                                ),
                              )
                            : const Icon(
                                Icons.notifications_active_outlined,
                                color: Colors.yellowAccent,
                              ),
                        tooltip: 'Controlla aggiornamenti',
                        onPressed:
                            _isCheckingUpdates ? null : _handleCheckUpdates,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Modifiche recenti (Changelog):',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildChangelogItem(
                    'Revisione completa del codice, allineamento motori di calcolo Dashboard/Fisco, sicurezza e stabilità',
                  ),
                  _buildChangelogItem(
                    'Nuova UI Fatture/Movimenti e modifica rapida dello stato',
                  ),
                  _buildChangelogItem(
                    'Aggiunto tasto eliminazione Preventivi con richiesta password/biometria',
                  ),
                  _buildChangelogItem(
                    'Risolto crash tasto download PDF singolo movimento',
                  ),
                  _buildChangelogItem(
                    'Aggiunto filtro data ascendente/discendente su Movimenti e Fatture',
                  ),
                  _buildChangelogItem(
                    'Ordinamento automatico per data più recente di default su tutto',
                  ),
                  _buildChangelogItem(
                    'Sincronizzazione Dashboard in tempo reale quando modifichi/aggiungi',
                  ),
                  _buildChangelogItem(
                    'Risolto Errore di Connessione Firestore sulla pagina Report e Idee',
                  ),
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
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
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
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


