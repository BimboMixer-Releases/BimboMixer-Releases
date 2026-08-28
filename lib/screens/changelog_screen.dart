import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../providers/app_theme_provider.dart';

class ChangelogScreen extends StatefulWidget {
  const ChangelogScreen({super.key});

  @override
  State<ChangelogScreen> createState() => _ChangelogScreenState();
}

class _ChangelogScreenState extends State<ChangelogScreen> {
  String _currentVersion = '...';
  
  // Hardcoded changelog for previous and current versions
  final List<Map<String, dynamic>> _changelogs = [
    {
      'version': '1.8.36',
      'date': '25 Agosto 2026',
      'changes': [
        'Aggiunta sezione "Versione & Changelog" per visualizzare le note di rilascio.',
        "Aggiornato il nome visualizzato dell'app in \"Contabilità BM Music\".",
      ]
    },
    {
      'version': '1.8.35',
      'date': '24 Agosto 2026',
      'changes': [
        "Risolto il problema della scomparsa del simbolo dell'Euro nei report PDF esportati.",
        'Impostato font predefinito (Roboto) per supportare nativamente i caratteri speciali nei PDF.',
      ]
    },
    {
      'version': '1.8.34',
      'date': '24 Agosto 2026',
      'changes': [
        'Rimossa la tabella doppia delle memo attive dalla dashboard.',
        "Cliccando sulla tabella delle memo si accede direttamente all'area Memo.",
        'Aggiunta la nuova sezione "Note Generali" con checklist customizzabili e strumenti di formattazione completi.',
      ]
    },
    {
      'version': '1.8.33',
      'date': '24 Agosto 2026',
      'changes': [
        'Miglioramenti generali alle performance.',
        "Fix minori per l'interfaccia utente (UI).",
      ]
    },
    {
      'version': '1.8.32',
      'date': '20 Agosto 2026',
      'changes': [
        'Aggiunta esportazione CSV per le sezioni principali (Clienti, Scadenze, Movimenti).',
        'Integrazione delle conferme di eliminazione con stile unificato (Security Center).',
      ]
    },
    {
      'version': '1.8.31',
      'date': 'Agosto 2026',
      'changes': [
        'Semplificato il design della Dashboard.',
        'Aggiunte funzionalità di personalizzazione del tema visivo e dei colori.',
      ]
    }
  ];

  @override
  void initState() {
    super.initState();
    _initPackageInfo();
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _currentVersion = info.version;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppThemeProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Info & Changelog', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.cardColor,
              border: Border(bottom: BorderSide(color: theme.borderColor)),
            ),
            child: Column(
              children: [
                Icon(Icons.info_outline, size: 64, color: theme.primaryColor),
                SizedBox(height: 16),
                Text(
                  'Contabile App',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Versione corrente: $_currentVersion',
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
                ),
              ],
            ),
          ),
          
          // Changelog list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _changelogs.length,
              itemBuilder: (context, index) {
                final log = _changelogs[index];
                final bool isCurrent = log['version'] == _currentVersion;
                final changes = log['changes'] as List<String>;
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isCurrent ? theme.primaryColor.withValues(alpha: 0.1) : theme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCurrent ? theme.primaryColor.withValues(alpha: 0.5) : theme.borderColor,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Versione ${log['version']}',
                              style: TextStyle(
                                color: isCurrent ? theme.primaryColor : Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              log['date'],
                              style: TextStyle(color: Colors.white.withOpacity(0.54), fontSize: 12),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        ...changes.map((c) => Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('• ', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14)),
                              Expanded(
                                child: Text(c, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14)),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


