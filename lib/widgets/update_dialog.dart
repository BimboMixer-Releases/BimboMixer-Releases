import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:contabile_app/services/update_service.dart';

class UpdateDialog extends StatefulWidget {
  final Map<String, dynamic> updateData;
  final UpdateService updateService;

  const UpdateDialog(
      {super.key, required this.updateData, required this.updateService});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String _status = '';
  bool _hasError = false;
  String _downloadUrl = '';

  @override
  void initState() {
    super.initState();
    _downloadUrl = Platform.isWindows
        ? widget.updateData['windowsUrl'] ?? ''
        : widget.updateData['androidUrl'] ?? '';
  }

  Future<void> _startUpdate() async {
    if (_downloadUrl.isEmpty) {
      setState(() {
        _hasError = true;
        _status =
            'Nessun file di aggiornamento disponibile per questa piattaforma.\n'
            'Contatta l\'amministratore.';
      });
      return;
    }

    // Su Windows: apri direttamente il browser per scaricare e installare
    if (Platform.isWindows) {
      await _openInBrowser();
      return;
    }

    setState(() {
      _isDownloading = true;
      _hasError = false;
      _status = 'Avvio download...';
      _progress = 0.0;
    });

    try {
      await widget.updateService.downloadAndInstallUpdate(
        _downloadUrl,
        (progress) {
          if (mounted) {
            setState(() {
              _progress = progress;
              _status =
                  'Download: ${(progress * 100).toStringAsFixed(0)}% completato';
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _progress = 1.0;
          _status = 'Download completato!\nAvvio installazione...';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _hasError = true;
          _status = 'Errore: ${e.toString().replaceAll('Exception: ', '')}';
        });
      }
    }
  }

  Future<void> _openInBrowser() async {
    if (_downloadUrl.isEmpty) return;
    final uri = Uri.parse(_downloadUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Error launching url: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final versionName =
        widget.updateData['versionName']?.toString() ?? 'Nuova versione';
    final notes =
        widget.updateData['releaseNotes']?.toString() ??
        widget.updateData['notes']?.toString() ??
        '';

    final isWindows = Platform.isWindows;

    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.system_update, color: Colors.blueAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Aggiornamento Disponibile',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Versione
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '🆕 Versione $versionName',
                style: const TextStyle(
                    color: Colors.blueAccent, fontWeight: FontWeight.bold),
              ),
            ),

            // Note di rilascio
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Novità:',
                  style: TextStyle(
                      color: Colors.white70, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(notes,
                  style:
                      const TextStyle(color: Colors.white54, fontSize: 13)),
            ],

            const SizedBox(height: 16),

            // Messaggio specifico per Windows
            if (isWindows && !_hasError) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.2)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.laptop_windows, color: Colors.blueAccent, size: 16),
                        SizedBox(width: 6),
                        Text('Aggiornamento PC',
                            style: TextStyle(
                                color: Colors.blueAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      '1. Clicca "Scarica Aggiornamento"\n'
                      '2. Apri il file .msix scaricato\n'
                      '3. Segui le istruzioni di installazione',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],

            // Stato / progresso (solo Android)
            if (_isDownloading) ...[
              Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  backgroundColor: Colors.white12,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _progress > 0
                    ? '${((_progress) * 100).toStringAsFixed(0)}%'
                    : 'Connessione...',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ] else if (_hasError) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.error_outline,
                            color: Colors.redAccent, size: 16),
                        SizedBox(width: 6),
                        Text('Errore aggiornamento',
                            style: TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _status,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ] else if (!isWindows) ...[
              const Text(
                'Vuoi scaricare e installare l\'aggiornamento?',
                style: TextStyle(color: Colors.white70),
              ),
              if (_downloadUrl.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    '⚠️ File non ancora disponibile per questa piattaforma.',
                    style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
                  ),
                ),
            ],
          ],
        ),
      ),
      actions: [
        // Più tardi (sempre disponibile a meno che download in corso)
        if (!_isDownloading)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Più Tardi',
                style: TextStyle(color: Colors.white54)),
          ),

        // In caso di errore, mostra "Apri nel Browser" come fallback
        if (_hasError && _downloadUrl.isNotEmpty)
          TextButton.icon(
            onPressed: _openInBrowser,
            icon: const Icon(Icons.open_in_browser,
                size: 16, color: Colors.blueAccent),
            label: const Text('Scarica dal Browser',
                style: TextStyle(color: Colors.blueAccent)),
          ),

        // Pulsante principale Windows: apre browser direttamente
        if (isWindows && !_isDownloading && _downloadUrl.isNotEmpty)
          ElevatedButton.icon(
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Scarica Aggiornamento'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _openInBrowser,
          ),

        // Pulsante principale Android
        if (!isWindows && !_isDownloading && !_hasError)
          ElevatedButton.icon(
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Aggiorna Ora'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _downloadUrl.isNotEmpty ? _startUpdate : null,
          ),

        // Dopo errore: riprova
        if (_hasError && !isWindows)
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Riprova'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _startUpdate,
          ),
      ],
    );
  }
}
